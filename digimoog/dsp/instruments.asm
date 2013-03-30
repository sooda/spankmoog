; build instruments like so:
; (maybe bass.asm and include it here)

Instrument_Bass:
	dc BassOsc
	dc BassFilt
	dc 1 ; TODO: midi number
	AdsrParamBlock 0.01,0.2,0.8,0.1

BassOsc:
	rts

BassFilt:
	rts
