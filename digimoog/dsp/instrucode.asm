; dummy jumps, same data pointers, do something clever later after this even works

; args: r1: workspace, r2: instrument, n2: note number
BassInit:
	lua (r1+ChDataIdx_OscState+OscStateCapacity),r0
	lua (r2+InstruBassIdx_Lp),r4
	bsr FiltTrivialLpInit

	lua (r1+ChDataIdx_OscState),r0
	move n2,r4
	bsr OscDpwsawInit

	rts

BassOsc:
	bra OscDpwsawEval

BassFilt:
	bra FiltTrivialLpEval
