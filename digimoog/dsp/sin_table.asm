; NOTE: the sine table must be located in Y memory, and its start address must
; be a multiple of 2**k, k is an integer such that 2**k >= SinTableSize.
; For example, this is trivially satisfied by placing the table to start at Y:0.

SinTableSize equ 32 ; NOTE: this must be a power of two

SinTable:
	dupf Index,0,SinTableSize-1
	dc @SIN(Index*2*PI/SinTableSize)
	endm
