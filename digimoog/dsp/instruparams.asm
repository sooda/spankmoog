; Instrument parameters, never changed by DSP code
; These live in the Y memory space
; Runtime state lives in X inside the channel workspaces

; would be easy and handy to rely on that init routines are not needed and the
; states would just get zeroed when initializing, but oscillators still need at
; least some period magic number - init function for instruments.
; calling convention docs in main.asm so far

InstruParamIdx_InitFunc	equ	0
InstruParamIdx_OscFunc	equ	1
InstruParamIdx_FiltFunc	equ	2
InstruParamIdx_MidiNum	equ	3
InstruParamIdx_Adsr	equ	4

Instrument_Bass:
	; TODO: subtract caller address from these
	; because these are called only from a single point
	; (bsr is pc-relative)
	dc BassInit
	dc BassOsc
	dc BassFilt
	dc 1 ; TODO: midi number
	if !simulator
	AdsrParamBlock 0.5,0.5,0.5,0.5
	else
	AdsrParamBlock 0.005,0.005,0.5,0.005
	endif
