; freq / (rate / 2), midi notes 0..127
; freq = 2^((midinote-69)/12) * 440
SawTicks:
	dupf note,0,127
	dc (@pow(2,(note-69)/12.0)*440/(RATE/2))
	endm
