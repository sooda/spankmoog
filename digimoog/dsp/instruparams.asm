; Instrument parameters, never changed by DSP code
; These live in the Y memory space
; Runtime state lives in X inside the channel workspaces

; would be easy and handy to rely on that init routines are not needed and the
; states would just get zeroed when initializing, but oscillators still need at
; least some period magic number - thus, init function for instruments.
; calling convention docs in main.asm so far

; these are used for each instrument always
InstruParamIdx_InitFunc	equ	0
InstruParamIdx_OscFunc	equ	1
InstruParamIdx_FiltFunc	equ	2
InstruParamIdx_Adsr	equ	3
InstruParamIdx_End	equ	3+AdsrStateSize
; no size constant needed

InstruBassIdx_Lp	equ	InstruParamIdx_End

; pretty stupid to call almost every instrument a bass, but whatever
; this is also quite copy-pasta

; a simple lp-filtered dpw saw
Instrument_Bass:
	dc BassInit-ChAlloc_InitInstruState
	dc OscDpwsawEval-ChEval_OscEvalBranch
	dc BassFilt-ChEval_FiltEvalBranch
	if !simulator
tune1	AdsrParamBlock 0.1,0.1,0.5,0.1
	else
tune1	AdsrParamBlock 0.005,0.005,0.5,0.005 ; faster to debug with smaller values
	endif
tune2	FiltTrivialLpParams 5000


; dpw saw, filter cutoff tuned by a sine lfo
Instrument_BassSinLfo:
	dc BassSinLfoInit-ChAlloc_InitInstruState
	dc OscDpwsawEval-ChEval_OscEvalBranch
	dc BassSinLfoFilt-ChEval_FiltEvalBranch
	if !simulator
	AdsrParamBlock 0.1,0.1,0.5,0.1
	else
	AdsrParamBlock 0.005,0.005,0.5,0.005
	endif
tune3	FiltTrivialLpParamsLfo 1200,1000
tune31	dc 0.1

; as above but sine replaced with an adsr
Instrument_BassAdsrLfo:
	dc BassAdsrLfoInit-ChAlloc_InitInstruState
	dc OscDpwsawEval-ChEval_OscEvalBranch
	dc BassAdsrLfoFilt-ChEval_FiltEvalBranch
	AdsrParamBlock 0.1,0.1,0.5,0.1
	FiltTrivialLpParamsLfo 500,3500
	; NOTE: R phase >= main adsr R so that gets killed appropriately
	;AdsrParamBlock 2.5,0.1,1.0,1.0
tune4	AdsrParamBlock 0.001,0.2,0.0,1.0

InstruBassAdsrIdx_FiltAdsr	equ	InstruParamIdx_End+FiltTrivialLpParamsLfoSize

; pulse wave, no filters, duty cycle adsr'd
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

; hp-filtered noise, like a hihat drum
Instrument_Noise:
	dc NoiseInstInit-ChAlloc_InitInstruState
	dc NoiseEval-ChEval_OscEvalBranch
	dc NoiseInstFilt-ChEval_FiltEvalBranch
	if !simulator
	AdsrParamBlock 0.0001,0.3,0.0,0.3
	else
	AdsrParamBlock 0.005,0.005,0.5,0.005
	endif
tune6	FiltTrivialHpParams 5000

; 4-pole version of the first instrument
Instrument_Bass4:
	dc Bass4Init-ChAlloc_InitInstruState
	dc OscDpwsawEval-ChEval_OscEvalBranch
	dc Bass4Filt-ChEval_FiltEvalBranch
	if !simulator
	AdsrParamBlock 0.1,0.1,0.5,0.1
	else
	AdsrParamBlock 0.005,0.005,0.5,0.005
	endif
filt4p	Filt4LP4Coefs
tune7	Filt4CoefResComp 500.0*2*PI/RATE,0.5,0.5

; 4-pole version of the hihat
Instrument_Noise4:
	dc Noise4Init-ChAlloc_InitInstruState
	dc NoiseEval-ChEval_OscEvalBranch
	dc Noise4Filt-ChEval_FiltEvalBranch
	if !simulator
	AdsrParamBlock 0.0001,0.3,0.0,0.3
	else
	AdsrParamBlock 0.005,0.005,0.5,0.005
	endif
	Filt4HP4Coefs
tune8	Filt4CoefResComp 5000.0*2*PI/RATE,0,0

; pointer lookup table for indexing the instrument structures
AllInstruments:
	dc Instrument_Bass
	dc Instrument_BassSinLfo
	dc Instrument_BassAdsrLfo
	dc Instrument_PulseBass
	dc Instrument_Noise
	dc Instrument_Bass4
	dc Instrument_Noise4

; addresses of tunable parameters
; these shall come with an accompanying manual with number mappings (see pdf)
InstruTunables:
	dc tune1	; 0: 1st instru adsr A
	dc tune1+1	; 1: 1st instru adsr D
	dc tune1+3	; 2: 1st instru adsr R
	dc tune2	; 3: 1st instru filt cutoff
	dc tune3	; 4: 2nd instru filt base
	dc tune31	; 5: 2nd instru filt sin freq
	dc tune4	; 6: 3rd instru filt adsr A
	dc tune4+1	; 7: 3rd instru filt adsr D
	dc tune4+3	; 8: 3rd instru filt adsr R
	dc tune5	; 9: 4th instru dutycycle base
	dc tune5+1	; a: 4th instru dutycycle amplitude
	dc tune6	; b: 5th instru filt cutoff
	dc tune7	; c: 6th instru filt cutoff
	dc tune7+1	; d: 6th instru filt resonance
	dc tune8	; e: 7th instru filt cutoff


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

