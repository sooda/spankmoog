; dummy jumps, same data pointers, do something clever later after this even works

BassInit:
	bra InitPulseOscillator

BassOsc:
	bra EvalPulseOscillator

BassFilt:
	bra EvalLowpassFilter
