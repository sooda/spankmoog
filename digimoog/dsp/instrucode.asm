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

BassSinLfoInit:
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

; Remap original coef to filter with some lfo value in x1
; replace the state coefficient with a taylor approximated one
DoLfoLp macro
	; TODO(?): c(f) ~= c(a) + c'(a) * (f - a) + c''(a)/2 * (f - a)^2
	; currently: c(f) ~= c(a) + c'(a) * (f - a)

	; c(f) ~= c(a) + c'(a) * (f - a)
	;       = c(a) + c'(a) * m * lfo [m = amplitude]
	;       = c(a) + 2048*c'(a) * m/2048 * lfo
	;       = K1   + K2         * K3     * lfo
	; K2 and K3 combined into lp param lfo.
	move Y:(r4+InstruBassIdx_Lp+FiltTrivialLpParamsIdx_Lfo),x0 ; K2*K3
	move Y:(r4+InstruBassIdx_Lp+FiltTrivialLpParamsIdx_Coef),b ; K1 = c(a)
	mac x0,x1,b
	move b,X:(r0+FiltTrivialLpStateIdx_Coef)
	endm

BassSinLfoFilt:
	; use the sin as an LFO:
	lua (r0+BassLfoStateIdx_Lfo),r2
	bsr LFOSinEval
	DoLfoLp
	bra FiltTrivialLpEval

; indices inside the filter state
BassAdsrStateIdx_LpFilt equ 0
BassAdsrStateIdx_Adsr   equ FiltTrivialLpStateSize

BassAdsrLfoInit:
	lua (r1+ChDataIdx_FiltState),r0
	lua (r4+InstruBassIdx_Lp),r5
	bsr FiltTrivialLpInit

	lua (r1+ChDataIdx_FiltState+BassAdsrStateIdx_Adsr),r0
	bsr AdsrInitState

	lua (r1+ChDataIdx_OscState),r0
	move n2,r4
	bsr OscDpwsawInit

	rts

BassAdsrLfoFilt:
	bsr FiltTrivialLpEval
	; use the ADSR as an LFO:
	; the ADSR needs the A register, and also r0 and r4 are swapped
	; "push" and "pop" the state to registers temporarily
	; TODO: do something more clever with this
	move a,r6
	move r4,n4
	move r0,n0

	lua (r0+BassAdsrStateIdx_Adsr),r2
	lua (r4+InstruBassAdsrIdx_FiltAdsr),r0
	move r2,r4
	move #>0,r2 ; don't kill the note
	bsr AdsrEval

	move r6,a
	move n0,r0
	move n4,r4
	move r3,x1

	DoLfoLp
	rts
