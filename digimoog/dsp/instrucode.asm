; dummy jumps, same data pointers, do something clever later after this even works

; args: r1: workspace, r2: instrument, n2: note number
BassInit:
	lua (r1+ChDataIdx_OscState+OscStateCapacity),r0
	move #>300,x0 ; NOTE: this (cutoff for lowpass) is currently ignored, must fix the lowpass init routine
	bsr InitLowpassFilter

	lua (r1+ChDataIdx_OscState),r0
	move n2,r4
	bsr OscTrivialsawInit

	rts

BassOsc:
	bra OscTrivialsawEval

BassFilt:
	bra EvalLowpassFilter
