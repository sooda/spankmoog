; ADSR envelope (attack-decay-sustain-release)
; ============================================
; A: rise up to 1 in a specified time, using a lowpass constant
; D: fall (after infinite time) to sustain level, using a lowpass constant
; S: just a volume level, not a separate state (D handles this too)
; R: fall to 0 in a specified time, using a lowpass constant
;
; * A single instrument contains parameters for its ADSR
; * Each channel then contains a single ADSR state
; * The channels also contain a pointer/index/something to instrument table
;   to be able to reference the parameters
;
; Parameters
; ----------
; A: precalculated magic coefficient constant (see below)
; D: magic constant
; S: sustain volume level
; R: magic constant
; Params are kind of constant, this dsp code never changes them
; They may be tuned from the rtems side from the control panel or pc terminal
;
; magic constants: g = 1 - exp(-1 / (T * fs))
; T = time to reach ~63% for decaying, A and R are hacked to reach 1 and 0
;
; State
; -----
; mode: attack/decay/release/killed
; value: previous value, because we're computing lowpass

; struct indices
AdsrParamIdx_A	equ	0
AdsrParamIdx_D	equ	1
AdsrParamIdx_S	equ	2
AdsrParamIdx_R	equ	3

AdsrParamsSize  equ	4

; struct indices
AdsrStateIdx_Mode equ	0 ; a/d/r
AdsrStateIdx_Val  equ	1 ; previous value
AdsrStateIdx_Tgt  equ	2 ; release target value


; NOTE: these are bit numbers, so that we don't need to compare with accumulators
ADSR_MODE_ATTACK_BIT	equ 0
ADSR_MODE_DECAY_BIT	equ 1
ADSR_MODE_RELEASE_BIT	equ 2
ADSR_MODE_KILLED_BIT	equ 3

ADSR_MODE_ATTACK	equ (1<<ADSR_MODE_ATTACK_BIT)
ADSR_MODE_DECAY		equ (1<<ADSR_MODE_DECAY_BIT)
ADSR_MODE_RELEASE	equ (1<<ADSR_MODE_RELEASE_BIT)
ADSR_MODE_KILLED	equ (1<<ADSR_MODE_KILLED_BIT)

; Initialize ASDR state
; Input:
; 	X:(r0): state pointer
; Work registers:
;	r2
AdsrInitState:
	move	#>ADSR_MODE_ATTACK,r2
	move	r2,X:(r0+AdsrStateIdx_Mode)
	move	#>0,r2
	move	r2,X:(r0+AdsrStateIdx_Val)
	rts

; lowpassing decayer with stuff divided by 2
; a: value
; b: target (already divided by 2)
; r4: X state struct pointer
; x0: lp coefficient
AdsrLpCareful macro
	asr #1,a,a	; value /= 2
	sub a,b		; tgt - value
	nop		; stall :-(
	move b,x1	; move to temp to be able to MAC
	mac x0,x1,a	; a = 0.5*value + coeff * (0.5*tgt - 0.5*value)
	asl #1,a,a	; multiply back by 2
	nop		; stall :--(
	move a,r3	; outval = a
	move a,X:(r4+AdsrStateIdx_Val) ; can I combine these?
	endm
; Evaluate the ASDR
; Input:
;	Y:(r0): param pointer
;	X:(r4): state pointer
;	r2: note number with key off bit included
; Output:
;	r3: envelope value, or -1 if killed
; Work registers:
;	r3, a, b
AdsrEval:
	move X:(r4+AdsrStateIdx_Mode),r3
	brset #ChNoteKeyoffBit,r2,_gateoff
_gateon:
	brset #ADSR_MODE_ATTACK_BIT,r3,_attack ; TODO: can I hack the A reg loading here?
	brset #ADSR_MODE_DECAY_BIT,r3,_decay
	bra _gotresult
_attack:
	; NOTE: everything divided by 2 so that we can actually reach 1
	; exponentially decaying things never actually reach the target,
	; only 63% of it in the time constant, so we trick it by
	; specifying a different target, which might be >1
	; also, when decaying, the target could be 1 + -1/0.63 = -0,59,
	; and then "target - value" would overflow.
	; value += coef * (target - value) [ideally]
	; value = 2 * (value/2 + coef * (target/2 - value/2)) [here]
	;                                ^^^^^^^^ precalc'd constant
	; same thing in release state

	move X:(r4+AdsrStateIdx_Val),a
	move #>(TGTCOEF/2),b
	move Y:(r0+AdsrParamIdx_A),x0
	AdsrLpCareful
	brclr #23,a1,_gotresult ; didn't overflow yet
_gotodecay:
	move #>ADSR_MODE_DECAY,r3
	move r3,X:(r4+AdsrStateIdx_Mode)
	; when clipped, we should already be decaying (should we interpolate somehow?)
_decay:
	move X:(r4+AdsrStateIdx_Val),a
	move Y:(r0+AdsrParamIdx_S),b
	move Y:(r0+AdsrParamIdx_D),x0
	sub a,b		; b = sustlevel - val
	nop		; stall :-(
	move b,x1	; b to temp
	mac x0,x1,a	; value += coeff * (sust - value)
	nop		; stall :--(
	move a,r3	; outval = a
	move a,X:(r4+AdsrStateIdx_Val) ; see above
	bra _gotresult
_gateoff:
	brset #ADSR_MODE_RELEASE_BIT,r3,_relinited
	brset #ADSR_MODE_KILLED_BIT,r3,_gotresult ; TODO: can this be ever called if the note is killed?
_relinit: ; start release state from whatever state we are in (a/d/s)
	; compute release target:
	;   current + (0 - current) * targetcoef
	; = (1 - targetcoef) * current
	move X:(r4+AdsrStateIdx_Val),x0
	mpyi #((1-TGTCOEF)/2),x0,a ; NOTE: /2
	move #>ADSR_MODE_RELEASE,r3
	move a,X:(r4+AdsrStateIdx_Tgt)
	move r3,X:(r4+AdsrStateIdx_Mode)
_relinited:
	; this divide by 2 hax again because we might
	; roll from 1 to -0.58 which again does not fit in a register
	; copypasta from attack stage
	move X:(r4+AdsrStateIdx_Val),a
	move X:(r4+AdsrStateIdx_Tgt),b
	move Y:(r0+AdsrParamIdx_R),x0
	AdsrLpCareful
	brclr #23,a1,_gotresult ; didn't overflow yet
_gotokilled:
	move #>ADSR_MODE_KILLED,x0
	move x0,X:(r4+AdsrStateIdx_Mode)
	move #>0,x0
	move x0,X:(r4+AdsrStateIdx_Val) ; TODO: is this needed after we've killed the thing?
	move #>-1.0,r3 ; kill signal
_gotresult:
	rts


