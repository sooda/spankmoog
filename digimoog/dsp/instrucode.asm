BassInit:
	lua (r1+ChDataIdx_FiltState),r0
	lua (r4+InstruBassIdx_Lp),r5
	bsr FiltTrivialLpInit

	lua (r1+ChDataIdx_OscState),r0
	move n2,r4
	bsr OscDpwsawInit

	rts

BassFilt:
	; LFO-like effect: simply replace the coefficient with probably newly updated value from the panel
	; could use Instrument_Bass etc. in all of these instead of r4, as we know what instrument we're dealing with
	; but let's be nice and generic anyway
	move Y:(r4+InstruBassIdx_Lp+FiltTrivialLpParamsIdx_Coef),x1
	move x1,X:(r0+FiltTrivialLpStateIdx_Coef)
	bra FiltTrivialLpEval

Noise4Init:
	lua (r1+ChDataIdx_FiltState),r0
	lua (r4+InstruParamIdx_End),r5
	bsr Filt4Init

	lua (r1+ChDataIdx_OscState),r0
	bsr NoiseInit

	rts

Noise4Filt:
	move Y:(r4+InstruParamIdx_End+Filt4ParamsIdx_Coef),x1
	move x1,X:(r0+Filt4StateIdx_Coef)
	lua (r4+InstruParamIdx_End),r5
	bsr Filt4Eval
	asl #4,a,a ; hp coefs attenuate a * 1/8
	rts

Bass4Init:
	lua (r1+ChDataIdx_FiltState),r0
	lua (r4+InstruParamIdx_End),r5
	bsr Filt4Init

	lua (r1+ChDataIdx_OscState),r0
	move n2,r4
	bsr OscDpwsawInit

	rts

Bass4Filt:
	move Y:(r4+InstruParamIdx_End+Filt4ParamsIdx_Coef),x1
	move x1,X:(r0+Filt4StateIdx_Coef)
	lua (r4+InstruParamIdx_End),r5
	bra Filt4Eval

; indices inside the filter state
BassLfoStateIdx_LpFilt equ 0
BassLfoStateIdx_Lfo    equ FiltTrivialLpStateSize

BassSinLfoInit:
	lua (r1+ChDataIdx_FiltState),r0
	lua (r4+InstruBassIdx_Lp),r5
	bsr FiltTrivialLpInit

	lua (r1+ChDataIdx_FiltState+BassLfoStateIdx_Lfo),r0
	move #(5.0*SinTableSize/RATE),x0
	bsr LFOSinInitState

	lua (r1+ChDataIdx_OscState),r0
	move n2,r4
	bsr OscDpwsawInit

	rts

; Remap original coef to filter with some lfo value in x1
; replace the state coefficient with a taylor approximated one
DoLfoLp macro
	; TODO(?): c(f) ~= c(a) + c'(a) * (f - a) + c''(a)/2 * (f - a)^2
	; currently: c(f) ~= c(a) + c'(a) * (f - a)

	; c(f) ~= c(a) + c'(a) * (f - a)
	;       = c(a) + c'(a) * m * lfo [m = amplitude]
	;       = c(a) + 2048*c'(a) * m/2048 * lfo
	;       = K1   + K2         * K3     * lfo
	; K2 and K3 combined into lp param lfo.
	move Y:(r4+InstruBassIdx_Lp+FiltTrivialLpParamsIdx_Lfo),x0 ; K2*K3
	move Y:(r4+InstruBassIdx_Lp+FiltTrivialLpParamsIdx_Coef),b ; K1 = c(a)
	mac x0,x1,b
	move b,X:(r0+FiltTrivialLpStateIdx_Coef)
	endm

BassSinLfoFilt:
	; use the sin as an LFO:
	lua (r0+BassLfoStateIdx_Lfo),r2
	bsr LFOSinEval
	DoLfoLp
	bra FiltTrivialLpEval

; indices inside the filter state
BassAdsrStateIdx_LpFilt equ 0
BassAdsrStateIdx_Adsr   equ FiltTrivialLpStateSize

BassAdsrLfoInit:
	lua (r1+ChDataIdx_FiltState),r0
	lua (r4+InstruBassIdx_Lp),r5
	bsr FiltTrivialLpInit

	lua (r1+ChDataIdx_FiltState+BassAdsrStateIdx_Adsr),r0
	bsr AdsrInitState

	lua (r1+ChDataIdx_OscState),r0
	move n2,r4
	bsr OscDpwsawInit

	rts

BassAdsrLfoFilt:
	bsr FiltTrivialLpEval
	; use the ADSR as an LFO:
	; the ADSR needs the A register, and also r0 and r4 are swapped
	; "push" and "pop" the state to registers temporarily
	move a,r6
	move r4,n4
	lua (r0+BassAdsrStateIdx_Adsr),r2
	move r0,n0

	lua (r4+InstruBassAdsrIdx_FiltAdsr),r0
	move r2,r4
	move #>0,r2 ; don't kill the note
	bsr AdsrEval

	move r6,a
	move n0,r0
	move n4,r4
	move r3,x1

	DoLfoLp
	rts

; indices inside the oscillator state
PulseBassStateIdx_Adsr   equ PlsDpwSize

PulseBassInit:
	lua (r1+ChDataIdx_FiltState),r0
	lua (r4+InstruBassIdx_Lp),r5
	bsr FiltTrivialLpInit

	lua (r1+ChDataIdx_OscState+PulseBassStateIdx_Adsr),r0
	bsr AdsrInitState

	lua (r1+ChDataIdx_OscState),r0
	move n2,r4
	move Y:(Instrument_PulseBass+InstruPulseBassIdx_DutyBase),x1
	bsr PlsDpwInit

	rts

PulseBassOsc:
	; use the ADSR as an LFO: tune the duty cycle
	; r0 and r4 are swapped for adsr
	; "push" and "pop" the state to registers temporarily
	move r4,n4
	lua (r0+PulseBassStateIdx_Adsr),r2
	move r0,n0

	lua (r4+InstruPulseBassIdx_FiltAdsr),r0
	move r2,r4
	move #>0,r2 ; don't kill the note
	bsr AdsrEval
	SimulatorMove r3,OutputHax


	move n4,r4
	move r3,x1
	move Y:(r4+InstruPulseBassIdx_DutyBase),a
	move Y:(r4+InstruPulseBassIdx_DutyAmpl),x0
	mac x0,x1,a
	move n0,r0
	move a,X:(r1+ChDataIdx_OscState+PlsDpwIdx_Duty)

	bra OscDpwplsEval

PulseBassFilt:
	rts

NoiseInstInit:
	lua (r1+ChDataIdx_FiltState),r0
	lua (r4+InstruNoiseIdx_Hp),r5
	bsr FiltTrivialHpInit

	lua (r1+ChDataIdx_OscState),r0
	bra NoiseInit

NoiseInstFilt:
	move Y:(r4+InstruNoiseIdx_Hp+FiltTrivialHpParamsIdx_Coef),x1
	move x1,X:(r0+FiltTrivialHpStateIdx_Coef)
	bra FiltTrivialHpEval
