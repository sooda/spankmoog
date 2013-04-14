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
InstruParamIdx_Adsr	equ	3
InstruParamIdx_End	equ	3+AdsrStateSize
; no size constant needed

InstruBassIdx_Lp	equ	InstruParamIdx_End

Instrument_Bass:
	dc BassInit-ChAlloc_InitInstruState
	dc BassOsc-ChEval_OscEvalBranch
	dc BassFilt-ChEval_FiltEvalBranch
	if !simulator
vankka	AdsrParamBlock 0.1,0.1,0.5,0.1
	else
vankka	AdsrParamBlock 0.005,0.005,0.5,0.005
	endif
ankka	FiltTrivialLpParams 5000 ; TODO: a better way to tune these via the panel

Instrument_BassLfo:
	dc BassLfoInit-ChAlloc_InitInstruState
	dc BassOsc-ChEval_OscEvalBranch
	dc BassLfoFilt-ChEval_FiltEvalBranch
	if !simulator
	AdsrParamBlock 0.1,0.1,0.5,0.1
	else
	AdsrParamBlock 0.005,0.005,0.5,0.005
	endif
	FiltTrivialLpParamsLfo 1200,1000

AllInstruments:
	dc Instrument_Bass
	dc Instrument_BassLfo
NumInstruments dc 2

; CALLING CONVENTION
; Init:
; 	args:
;		X:r1: channel workspace pointer
;		Y:r4: instrument
;		n2: note number
; Osc and filt:
;	as with plain oscillators, and then some
;	args:
;		X:r0: state pointer
;		X:r1: channel pointer
;		Y:r4: instrument pointer
	; input and output: A

