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
InstruParamIdx_End	equ	4+AdsrStateSize
; no size constant needed

InstruBassIdx_Lp	equ	InstruParamIdx_End

Instrument_Bass:
	; TODO: subtract caller address from these
	; because these are called only from a single point
	; (bsr is pc-relative)
	dc BassInit-ChAlloc_InitInstruState
	dc BassOsc-ChEval_OscEvalBranch
	dc BassFilt-ChEval_FiltEvalBranch
	dc 1 ; TODO: midi number
	if !simulator
	AdsrParamBlock 0.1,0.2,0.5,0.1
	else
	AdsrParamBlock 0.005,0.005,0.5,0.005
	endif
ankka	FiltTrivialLpParams 5000 ; TODO: a better way to tune these via the panel

; CALLING CONVENTION
; Init:
; 	args:
;		X:r1: workspace
;		Y:r4: instrument
;		n2: note number
; Osc:
;	as with plain oscillators, and then some
;	args:
;		X:r0: state
;		X:r1: channel pointer
;		X:r4: instrument pointer
	; input and output: A

