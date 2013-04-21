Filt4PartStateIdx_x0	equ 0
Filt4PartStateIdx_y0	equ 1
Filt4PartStateSize	equ 2

Filt4StateIdx_Part0	equ 0
Filt4StateIdx_Part1	equ 1*Filt4PartStateSize
Filt4StateIdx_Part2	equ 2*Filt4PartStateSize
Filt4StateIdx_Part3	equ 3*Filt4PartStateSize
Filt4StateIdx_Mem	equ 4*Filt4PartStateSize
Filt4StateIdx_Gres	equ 4*Filt4PartStateSize+1
Filt4StateIdx_Coef	equ 4*Filt4PartStateSize+2

Filt4ParamsIdx_A	equ 0
Filt4ParamsIdx_B	equ 1
Filt4ParamsIdx_C	equ 2
Filt4ParamsIdx_D	equ 3
Filt4ParamsIdx_E	equ 4
Filt4ParamsIdx_Coef	equ 5
Filt4ParamsIdx_Gres	equ 6
Filt4ParamsIdx_Gcomp	equ 7
Filt4ParamsSize		equ 8

Filt4CoefResComp macro coef,res,comp
	dc coef
	dc res
	dc comp
	endm

Filt4LP4Coefs macro
	dc 0
	dc 0
	dc 0
	dc 0
	dc 1.0
	endm

Filt4HP4Coefs macro
	dc  1/8.0
	dc -4/8.0
	dc  6/8.0
	dc -4/8.0
	dc  1/8.0
	endm


