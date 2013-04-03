; oscillator struct defs

SawOscIdx_Tick	equ	0
SawOscIdx_Val	equ	1
SawOscSize	equ	2

DpwOscIdx_Saw	equ	0
DpwOscIdx_Val	equ	SawOscSize
DpwOscIdx_Coef	equ	SawOscSize+1
DpwOscSize	equ	SawOscSize+2

PlsOscIdx_Saw0	equ	0
PlsOscIdx_Saw1	equ	SawOscSize
PlsOscIdx_Duty	equ	2*SawOscSize
PlsOscSize	equ	2*SawOscSize+1 ; TODO: optimize into using just one saw and differentiating the second one locally?

PlsDpwIdx_Saw0	equ	0
PlsDpwIdx_Saw1	equ	DpwOscSize
PlsDpwIdx_Duty	equ	2*DpwOscSize
PlsDpwSize	equ	2*DpwOscSize+1 ; don't optimize this, too much copypasta in dpw
