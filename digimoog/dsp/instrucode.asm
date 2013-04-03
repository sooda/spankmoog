; dummy jumps, same data pointers, do something clever later after this even works

BassInit:
	bra OscTrivialsawInit

BassOsc:
	bra OscTrivialsawEval

BassFilt:
	bra EvalLowpassFilter
