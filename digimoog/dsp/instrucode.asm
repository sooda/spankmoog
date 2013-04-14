BassInit:
	lua (r1+ChDataIdx_FiltState),r0
	lua (r4+InstruBassIdx_Lp),r5
	bsr FiltTrivialLpInit

	lua (r1+ChDataIdx_OscState),r0
	move n2,r4
	bsr OscDpwsawInit

	rts

BassOsc:
	bra OscDpwsawEval

BassFilt:
	; LFO-like effect: simply replace the coefficient with probably newly updated value from the panel
	move Y:(r4+InstruBassIdx_Lp+FiltTrivialLpParamsIdx_Coef),x1
	move x1,X:(r0+FiltTrivialLpStateIdx_Coef)
	bra FiltTrivialLpEval

; indices inside the filter state
BassLfoStateIdx_LpFilt equ 0
BassLfoStateIdx_Lfo    equ FiltTrivialLpStateSize

BassLfoInit:
	lua (r1+ChDataIdx_FiltState),r0
	lua (r4+InstruBassIdx_Lp),r5
	bsr FiltTrivialLpInit

	lua (r1+ChDataIdx_FiltState+BassLfoStateIdx_Lfo),r0
	move #(5.0*SinTableSize/RATE),x0
	bsr LFOSinInitState

	lua (r1+ChDataIdx_OscState),r0
	move n2,r4
	bsr OscDpwsawInit

	rts

BassLfoFilt:
	; use the sin as an LFO:
	; replace the coefficient with a taylor approximated one
	lua (r0+BassLfoStateIdx_Lfo),r2
	bsr LFOSinEval

	; TODO(?): c(f) ~= c(a) + c'(a) * (f - a) + c''(a)/2 * (f - a)^2
	; currently: c(f) ~= c(a) + c'(a) * (f - a)

	; r3 = sin(lfo*t)
	; c(f) ~= c(a) + c'(a) * (f - a)
	;       = c(a) + c'(a) * m * lfo [m = amplitude]
	;       = c(a) + 2048*c'(a) * m/2048 * lfo
	;       = K1   + K2         * K3     * lfo
	; K2 and K3 combined into lp param lfo.
	move Y:(r4+InstruBassIdx_Lp+FiltTrivialLpParamsIdx_Lfo),x0
	move Y:(r4+InstruBassIdx_Lp+FiltTrivialLpParamsIdx_Coef),b ; c(a)
	mac x0,x1,b ; x1: sin retval
	move b,X:(r0+FiltTrivialLpStateIdx_Coef)

	bra FiltTrivialLpEval
