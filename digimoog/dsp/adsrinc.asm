; natural constants
E	equ	2.718281828
TGTCOEF	equ	E/(E-1) ; ~1,58, ~1/0.63, decay target multiplier to get to actual target in a time constant

; use this in instrument definitions
; params: A=time, D=time, S=level, R=time
; NOTE: time 0 gives division by zero, but use some really small value instead
; NOTE: D is meaningless if S is 1, obviously
; times in seconds
AdsrParamBlock	macro	At,Dt,Sl,Rt
	dc	(1-@POW(E,-1.0/(At*RATE)))
	dc	(1-@POW(E,-1.0/(Dt*RATE)))
	dc	Sl
	dc	(1-@POW(E,-1.0/(Rt*RATE)))
	endm

AdsrStateSize     equ	4
AdsrParamsSize  equ	4
