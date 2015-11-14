FiltTrivialLpParamsIdx_Coef	equ	0
FiltTrivialLpParamsIdx_Lfo	equ	1

FiltTrivialLpStateIdx_Val	equ	0
FiltTrivialLpStateIdx_Coef	equ	1
FiltTrivialLpState_Size		equ	2

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
	asr #1,b,b	; value /= 2
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

FiltTrivialHpParamsIdx_Coef	equ	0

FiltTrivialHpStateIdx_Prevdiff2	equ	0
FiltTrivialHpStateIdx_Coef	equ	1
FiltTrivialHpState_Size		equ	2

; args: workspace at X:(r0), params at Y:(r5)
; work regs: x1
FiltTrivialHpInit:
	move Y:(r5+FiltTrivialHpParamsIdx_Coef),x1
	move x1,X:(r0+FiltTrivialHpStateIdx_Coef)
	move #>0,x1 ; just assume something. will this work or give nasty transients?
	move x1,X:(r0+FiltTrivialHpStateIdx_Prevdiff2)
	rts

; args: workspace at X:(r0), input at a
; output: a
; work regs: a, b, x0, x1

; y1 = g * (y0 + x1 - x0)
;    = g * y0 + g * (x1 - x0)
;    = g * (x1 + (y0 - x0))
;    = 2 * g * (x1/2 + (y0 - x0) / 2)
; store: (y0-x0)/2
FiltTrivialHpEval:
	move X:(r0+FiltTrivialHpStateIdx_Prevdiff2),b ; b = (y0-x0) / 2
	asr a ; x1 /= 2
	add a,b ; b = (x1/2 + (y0-x0)/2)
	move X:(r0+FiltTrivialHpStateIdx_Coef),x0
	move b,x1
	mpy x0,x1,b ; b = g * (x1 / 2 + (y0-x0) / 2) = y1 / 2
	sub b,a ; a = x1 / 2 - y1 / 2 = (x1 - y1) / 2
	neg a ; a = (y1 - x1) / 2
	move a,X:(r0+FiltTrivialHpStateIdx_Prevdiff2) ; b = new (y0-x0) / 2
	asl #1,b,a ; output
	rts
