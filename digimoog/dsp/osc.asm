; == OSCILLATORS ==
; - trivial saw wave,
; - dpw corrected saw wave,
; - trivial pulse wave (difference of two saws),
; - dpw'd pulse wave (difference of two dpw saws)
; - noise


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
	move x1,X:(r0+DpwOscIdx_Coef) ; c coefficient, shifted by 11 (max amount 1500, for freq 8Hz)
	rts

; args: workspace at X:(r0), note number at r4, duty cycle (0=0%, 1=50%) at x1
; work regs: x1, a, r0, x0
; could use triangles in range [0,1) instead of [-1,1)
; would be easier to scale this thing then
; NOTE: high value is at duty cycle, low at duty cycle - 1
; maybe sum it so that high is at 0.5 or at 1?
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
PlsDpwInit:
	move x1,X:(r0+PlsDpwIdx_Duty)
	move x1,x0
	; saw0 is at the beginning
	bsr OscDpwsawInit
	lea (r0+PlsDpwIdx_Saw1),r0
	bsr OscDpwsawInit
	move X:(r0+SawOscIdx_Val),a
	add x0,a
	move a,X:(r0+SawOscIdx_Val)
	rts

; args: workspace at X:(r0)
; work regs: x1
NoiseInit:
	; seed = 1
	move #>1,x1
	move x1,X:(r0+NoiseOscIdx_Current)
	rts


; EVALUATION ROUTINES

; params: X:r0 = state pointer
; work regs: x0, a
; output in: a (value range [-1,1)
OscTrivialsawEval:
	move X:(r0+SawOscIdx_Val),a
	move X:(r0+SawOscIdx_Tick),x0
	add x0,a
	asl #8,a,a ; sneaky! 1+x -> -1+x if x >= 0
	asr #8,a,a ; (copy the highest bit and sign-extend back)
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
	move X:(r0+DpwOscIdx_Coef),x1
	move a,x0
	mpy x0,x1,a	; out = c * dsq
	asl #11,a,a	; fixpt coef
	rts

; params: X:r0 = state pointer
; work regs: x0, a, b
; output in: a (see value range docs above in init)
; NOTE: this is not really used anymore
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
; NOTE: ugly copypasta from above, PlsOsc -> PlsDpw, OscTrivial -> Oscdpw
OscDpwplsEval:
	move X:(r0+PlsDpwIdx_Saw0+DpwOscIdx_Saw+SawOscIdx_Val),a
	move X:(r0+PlsDpwIdx_Duty),y0
	add y0,a
	asl #8,a,a ; sneaky! 1+x -> -1+x if x >= 0
	asr #8,a,a ; (copy the highest bit and sign-extend back)
	move a,x0
	move a,X:(r0+PlsDpwIdx_Saw1+DpwOscIdx_Saw+SawOscIdx_Val)
	mpy x0,x0,a
	move a,X:(r0+PlsDpwIdx_Saw1+DpwOscIdx_Val)
	; FIXME: saw 1 does not need bsr osctrivialsaweval?

	bsr OscDpwsawEval
	asr #1,a,b	; /2

	lea (r0+PlsDpwIdx_Saw1),r0
	bsr OscDpwsawEval

	asr a		; /2
	sub b,a		; pulse = saw difference
	add #0.5,a	; originally -1+duty..duty, shift to
	mac #-0.5,y0,a	; between -1..1 (but half, dpw inaccuracies)
	;asl a
	rts

; params: workspace at X:(r0)
; work regs: a, x0
; output in: a (see value range docs above in init)
NoiseEval:
	; 24-bit xorshift, period length 2**24-1
	; pseudocode (v is 24-bit):
	;   v = previous value (or seed)
	;   v ^= v<<8
	;   v ^= v>>1
	;   v ^= v<<11
	;   new previous value = v
	;   return v

	move X:(r0+NoiseOscIdx_Current),a1

	move a1,x0
	lsl #8,a
	eor x0,a

	move a1,x0
	lsr a
	eor x0,a

	move a1,x0
	lsl #11,a
	eor x0,a

	move a1,X:(r0+NoiseOscIdx_Current)

	; sign-extend to a2
	move a1,x0
	move x0,a

	rts
