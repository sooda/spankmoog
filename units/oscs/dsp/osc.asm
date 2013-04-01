; == OSCILLATORS ==
; - trivial saw wave,
; - dpw corrected saw wave,
; - trivial pulse wave (difference of two saws),
; - dpw'd saw wave (difference of two dpw saws)


; INITIALIZATION ROUTINES

; args: workspace at X:(r0), note number at r4
; work regs: x1
OscTrivialsawInit:
	move Y:(r4+SawTicks),x1
	move x1,X:(r0+SawOscIdx_Tick)
	move #>-1.0,x1
	move x1,X:(r0+SawOscIdx_Val) ; counter (-1..1)
	rts

; args: workspace at X:(r0), note number at r4
; work regs: x1
OscDpwsawInit:
	bsr OscTrivialsawInit ; trivial saw on top of this
	move #>1.0,x1
	move x1,X:(r0+DpwOscIdx_Val)
	move Y:(r4+DpwCoefs),x1
	move x1,X:(r0+DpwOscIdx_Coef) ; c coefficient, shifted by 11 (max amount 1500, for freq 8Hz) (TODO: we don't need that low freqs really, get more bits without them)
	rts

; args: workspace at X:(r0), note number at r4, duty cycle (0=0%, 1=50%) at x1
; work regs: x1, a, r0, x0
; TODO: maybe use triangles in range [0,1) instead of [-1,1)
; would be easier to scale this thing then
; NOTE: high value is at duty cycle, low at duty cycle - 1
; maybe sum it so that high is at 0.5 or at 1?
; TODO: duty cycle isn't used in runtime, how do I update it?
PlsTrivialInit:
	move x1,X:(r0+PlsOscIdx_Duty)
	move x1,x0
	; saw0 is at the beginning
	bsr OscTrivialsawInit
	lea (r0+PlsOscIdx_Saw1),r0
	bsr OscTrivialsawInit
	move X:(r0+SawOscIdx_Val),a
	add x0,a
	move a,X:(r0+SawOscIdx_Val)
	rts

; args: workspace at X:(r0), note number at r4, duty cycle (0=0%, 1=50%) at x1
; work regs: x1, a, r0, x0
; TODO, NOTE: same as above
PlsDpwInit:
	move x1,X:(r0+PlsDpwIdx_Duty)
	move x1,x0
	; saw0 is at the beginning
	bsr OscDpwsawInit
	lea (r0+PlsDpwIdx_Saw1),r0
	bsr OscDpwsawInit
	move X:(r0+SawOscIdx_Val),a ; TODO: update dpwval to be a^2
	add x0,a
	move a,X:(r0+SawOscIdx_Val)
	rts


; EVALUATION ROUTINES

; params: X:r0 = state pointer
; work regs: x0, a
; output in: a (value range [-1,1)
OscTrivialsawEval:
	move X:(r0+SawOscIdx_Val),a
	move X:(r0+SawOscIdx_Tick),x0
	add x0,a
	cmp #>1.0,a
	ble _notovf
		add #>-1.0,a ; "modulo" 1, wrap to near -1
		add #>-1.0,a
_notovf:
	move a,X:(r0+SawOscIdx_Val)
	rts

; params: X:r0 = state pointer
; work regs: x0, a
; output in: a (value range [-1,1)
OscDpwsawEval:
	bsr OscTrivialsawEval
	move a,x0
	mpy x0,x0,a	; a = val ^ 2
	move X:(r0+DpwOscIdx_Val),x1
	move a,X:(r0+DpwOscIdx_Val)
	sub x1,a	; dsq = val^2 - old^2
	move a,x0
	move X:(r0+DpwOscIdx_Coef),x1
	mpy x0,x1,a	; out = c * dsq
	asl #11,a,a	; fixpt coef
	rts

; params: X:r0 = state pointer
; work regs: x0, a, b
; output in: a (see value range docs above in init)
; TODO: live duty cycle changes? get value of first, add dc, put to second val
OscTrivialplsEval:
	bsr OscTrivialsawEval
	move a,b
	lea (r0+PlsOscIdx_Saw1),r0
	bsr OscTrivialsawEval
	move b,x0
	sub x0,a	; pulse = saw difference
	cmp #>-1.0,a
	blt _ovf	; 0.6-0.1=0.5 ok, -0.9-0.6=-1.5 notok
	rts
_ovf:	add #>1.0,a	; fix <-1 condition
	rts

; params: X:r0 = state pointer
; work regs: x0, a, b
; output in: a (see value range docs above in init)
; TODO: live duty cycle changes? get value of first, add dc, put to second val
; NOTE: ugly copypasta from above, PlsOsc -> PlsDpw, OscTrivial -> Oscdpw
OscDpwplsEval:
	bsr OscDpwsawEval
	move a,b
	lea (r0+PlsDpwIdx_Saw1),r0
	bsr OscDpwsawEval
	move b,x0
	sub x0,a	; pulse = saw difference
	cmp #>-1.0,a
	blt _ovf	; 0.6-0.1=0.5 ok, -0.9-0.6=-1.5 notok
	rts
_ovf:	add #>1.0,a	; fix <-1 condition
	rts
