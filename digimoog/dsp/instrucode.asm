; dummy jumps, same data pointers, do something clever later after this even works

BassInit:
	lua (r1+ChDataIdx_OscState+OscStateCapacity),r0
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
