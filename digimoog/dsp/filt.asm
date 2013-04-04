FiltTrivialLpParamsIdx_Coef	equ	0

FiltTrivialLpStateIdx_Val	equ	0
FiltTrivialLpStateIdx_Coef	equ	1

; args: workspace at X:(r0), params at Y:(r5)
; work regs: x1
FiltTrivialLpInit:
	move Y:(r5+FiltTrivialLpParamsIdx_Coef),x1
	move x1,X:(r0+FiltTrivialLpStateIdx_Coef)
	move #>0,x1
	move x1,X:(r0+FiltTrivialLpStateIdx_Val)
	rts

; args: workspace at X:(r0), input at a
; output: a
; work regs: a, b, x0, x1
FiltTrivialLpEval:
	move X:(r0+FiltTrivialLpStateIdx_Val),b
	move X:(r0+FiltTrivialLpStateIdx_Coef),x0
	asr #1,b,b	; value /= 2 (TODO: store /2 to eliminate this)
	asr #1,a,a	; target /= 2
	sub b,a		; a = 0.5*(tgt - value)
	nop		; stall :(
	move a,x1	; temp for mac
	mac x0,x1,b	; b = 0.5*value + coeff * (0.5*val - 0.5*value)
	asl #1,b,a	; shift back to output
	nop		; stall
	move a,X:(r0+FiltTrivialLpStateIdx_Val)
	rts

	move a,b
	move X:(r0+FiltTrivialLpStateIdx_Val),x0 ; a = previous, a = current
	sub x0,b	; b = (inp - x)
	move X:(r0+FiltTrivialLpStateIdx_Coef),x0
	move b,x1
	mac x0,x1,a	;a = x + c * (inp - x)
	nop		; stall :(
	move a,X:(r0+FiltTrivialLpStateIdx_Val)
	rts
