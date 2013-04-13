SinTableSize equ 32 ; NOTE: this must be a power of two

SinTable:
	dupf Index,0,SinTableSize-1
	dc @SIN(Index*2*PI/SinTableSize)
	endm
