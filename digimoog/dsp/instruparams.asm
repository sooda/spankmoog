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
tune1	AdsrParamBlock 0.1,0.1,0.5,0.1
	else
tune1	AdsrParamBlock 0.005,0.005,0.5,0.005
	endif
tune2	FiltTrivialLpParams 5000

Instrument_BassSinLfo:
	dc BassSinLfoInit-ChAlloc_InitInstruState
	dc BassOsc-ChEval_OscEvalBranch
	dc BassSinLfoFilt-ChEval_FiltEvalBranch
	if !simulator
	AdsrParamBlock 0.1,0.1,0.5,0.1
	else
	AdsrParamBlock 0.005,0.005,0.5,0.005
	endif
tune3	FiltTrivialLpParamsLfo 1200,1000

Instrument_BassAdsrLfo:
	dc BassAdsrLfoInit-ChAlloc_InitInstruState
	dc BassOsc-ChEval_OscEvalBranch
	dc BassAdsrLfoFilt-ChEval_FiltEvalBranch
	AdsrParamBlock 0.1,0.1,0.5,0.1
	FiltTrivialLpParamsLfo 500,3500
	; NOTE: R phase >= main adsr R so that gets killed appropriately
	;AdsrParamBlock 2.5,0.1,1.0,1.0
tune4	AdsrParamBlock 0.001,0.2,0.0,1.0

InstruBassAdsrIdx_FiltAdsr	equ	InstruParamIdx_End+FiltTrivialLpParamsLfoSize

Instrument_PulseBass:
	dc PulseBassInit-ChAlloc_InitInstruState
	dc PulseBassOsc-ChEval_OscEvalBranch
	dc PulseBassFilt-ChEval_FiltEvalBranch
	AdsrParamBlock 0.1,0.1,0.5,0.1
	; NOTE: R phase >= main adsr R so that gets killed appropriately
	if !simulator
	AdsrParamBlock 3,0.00000001,1.0,1.0
	else
	AdsrParamBlock 0.03,0.00000001,1.0,1.0
	endif
tune5	dc 0.1 ; base lfo duty cycle
	dc 0.9 ; adsr amplitude

InstruPulseBassIdx_FiltAdsr	equ	InstruParamIdx_End
; base value = where we add lfo stuff to.
InstruPulseBassIdx_DutyBase	equ	InstruParamIdx_End+AdsrParamsSize
InstruPulseBassIdx_DutyAmpl	equ	InstruParamIdx_End+AdsrParamsSize+1

InstruNoiseIdx_Hp	equ	InstruParamIdx_End

Instrument_Noise:
	dc NoiseInstInit-ChAlloc_InitInstruState
	dc NoiseInstOsc-ChEval_OscEvalBranch
	dc NoiseInstFilt-ChEval_FiltEvalBranch
	if !simulator
	AdsrParamBlock 0.0001,0.3,0.0,0.3
	else
	AdsrParamBlock 0.005,0.005,0.5,0.005
	endif
tune6	FiltTrivialHpParams 5000

AllInstruments:
	dc Instrument_Bass
	dc Instrument_BassSinLfo
	dc Instrument_BassAdsrLfo
	dc Instrument_PulseBass
	dc Instrument_Noise

; addresses of tunable parameters
; these shall come with an accompanying manual with number mappings
InstruTunables:
	dc tune1	; 0: 1st instru adsr A
	dc tune1+1	; 1: 1st instru adsr D
	dc tune1+3	; 2: 1st instru adsr R
	dc tune2	; 3: 1st instru filt cutoff
	dc tune3	; 4: 2nd instru filt base
	dc tune3+1	; 5: 2nd instru filt amplitude
	dc tune4	; 6: 3rd instru filt adsr A
	dc tune4+1	; 7: 3rd instru filt adsr D
	dc tune4+3	; 8: 3rd instru filt adsr R
	dc tune5	; 9: 4th instru dutycycle base
	dc tune5+1	; a: 4th instru dutycycle amplitude
	dc tune6	; b: 5th instru filt cutoff


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

