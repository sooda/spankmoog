SinTableSize equ 32 ; NOTE: this must be a power of two

SinTableCoeff macro Index
	dc	@SIN(Index*2*PI/SinTableSize)
	endm

SinTable:
	SinTableCoeff 0
	SinTableCoeff 1
	SinTableCoeff 2
	SinTableCoeff 3
	SinTableCoeff 4
	SinTableCoeff 5
	SinTableCoeff 6
	SinTableCoeff 7
	SinTableCoeff 8
	SinTableCoeff 9
	SinTableCoeff 10
	SinTableCoeff 11
	SinTableCoeff 12
	SinTableCoeff 13
	SinTableCoeff 14
	SinTableCoeff 15
	SinTableCoeff 16
	SinTableCoeff 17
	SinTableCoeff 18
	SinTableCoeff 19
	SinTableCoeff 20
	SinTableCoeff 21
	SinTableCoeff 22
	SinTableCoeff 23
	SinTableCoeff 24
	SinTableCoeff 25
	SinTableCoeff 26
	SinTableCoeff 27
	SinTableCoeff 28
	SinTableCoeff 29
	SinTableCoeff 30
	SinTableCoeff 31
