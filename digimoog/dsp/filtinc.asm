FiltTrivLpK	equ	(DT*2*PI) ; just a shorthand constant

; magic coefficient to multiply with
FiltTrivialLpParams	macro	fc
	dc	((FiltTrivLpK*fc)/(FiltTrivLpK*fc+1))
	endm

; the coefficient for a frequency, and a derivarive of the magic coef function
; at the same point - multiplied by the lfo amplitude.

; the second derivative is really small, let's not bother ; using 2nd order
; taylor (yet)
FiltTrivialLpParamsLfo	macro	fc,lfo
	dc	((FiltTrivLpK*fc)/(FiltTrivLpK*fc+1))
	dc	(FiltTrivLpK/@pow(FiltTrivLpK*fc+1,2))*lfo
	;dc	(-pow(FiltTrivLpK,2)/@pow(FiltTrivLpK*fc+1,3))
	endm

FiltTrivialLpParamsSize equ 1
FiltTrivialLpParamsLfoSize equ 2

FiltTrivialLpStateSize equ 2
