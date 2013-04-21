; workspace: X:(r0), params Y:(r5)
Filt4Init:
	move #>0,x0
	move x0,X:(r0+Filt4StateIdx_Part0+Filt4PartStateIdx_x0)
	move x0,X:(r0+Filt4StateIdx_Part0+Filt4PartStateIdx_y0)
	move x0,X:(r0+Filt4StateIdx_Part1+Filt4PartStateIdx_x0)
	move x0,X:(r0+Filt4StateIdx_Part1+Filt4PartStateIdx_y0)
	move x0,X:(r0+Filt4StateIdx_Part2+Filt4PartStateIdx_x0)
	move x0,X:(r0+Filt4StateIdx_Part2+Filt4PartStateIdx_y0)
	move x0,X:(r0+Filt4StateIdx_Part3+Filt4PartStateIdx_x0)
	move x0,X:(r0+Filt4StateIdx_Part3+Filt4PartStateIdx_y0)
	move x0,X:(r0+Filt4StateIdx_Mem)
	move Y:(r5+Filt4ParamsIdx_Coef),x0
	;move #0.06544984694978735914,x0 ;Y:(r5+Filt4ParamsIdx_Coef),x0
	bsr Filt4SetCoef
	;bsr Filt4SetRes
	rts

; workspace: X:(r0)
; input: w in x0
; work regs: b, x0, x1
; self.g = 0.9892 * w - 0.4342 * w**2 + 0.1381 * w**3 - 0.0202 * w**4
Filt4SetCoef:
				; x0 = w
	mpy #0.9892,x0,b	; b = 0.9892 * w
	mpy x0,x0,a
	move a,x1		; x1 = w^2
	mac #-0.4342,x1,b	; b -= 0.4342 * w^2
	mpy x0,x1,a
	move a,x1		; x1 = w^3
	mac #0.1381,x1,b	; b += 0.1381 * w^3
	mpy x0,x1,a
	move a,x1		; x1 = w^4
	mac -#0.0202,x1,b	; b -= 0.0202 * w^4
	move b,X:(r0+Filt4StateIdx_Coef)
	rts

; input: w (0..1) in x0, c_res in y0
; self.g_res = c_res * (1.0029 + 0.0526 * w - 0.0926 * w**2 + 0.0218 * w**3)
Filt4SetRes:
				; x0 = w
	mpy #0.0526,x0,b	; b = 0.0526 * w
	mpy x0,x0,a
	move a,x1		; x1 = w^2
	mac #-0.0926,x1,b	; b -= 0.0926 * w^2
	mpy x0,x1,a
	move a,x1		; x1 = w^3
	mac #0.0218,x1,b	; b += 0.0218 * w^3
	mpy #1.0029/2,y0,a	; a = 1.0029 * c_res
	move b,y1
	asl a			; a = c_res * 1.0029
	mpy y0,y1,b		; b = c_res * b
	add a,b			; b = c_res * (1.0029 + f(w))
	move b,X:(r0+Filt4StateIdx_Gres)
	rts

; one lowpass part of the whole 4-pole system
; input: x1, output: y1
; q = (x1 + 0.3 * self.x0) / 1.3
; self.x0 = x1
; self.y0 += self.g * (q - self.y0) # y = g * a + (1 - g) * y
Filt4RunPart macro
	move X:(r2+Filt4PartStateIdx_x0),x0
	move x1,X:(r2+Filt4PartStateIdx_x0)
	mpy #0.3,x0,a		; q = 0.3 * x0
	add x1,a		; q = x1 + 0.3 * x0
	move a,x0
	mpy #(1.0/1.3),x0,a	; q = (x1 + 0.3 * x0) / 1.3
	move X:(r2+Filt4PartStateIdx_y0),y0
	move X:(r0+Filt4StateIdx_Coef),y1
	sub y0,a		; a = q - y0
	move a,x0
	mpy x0,y1,a		; a = g * (q - y0)
	add y0,a		; a = y0 + g * (q - y0)
	move a,y1
	move a,X:(r2+Filt4PartStateIdx_y0)
	endm

; workspace: X:(r0), params Y:(r5)
; input: a
; output: a
; work regs: monta
Filt4Eval:
; TODO: resonance
	move a,x1
	move Y:(r5+Filt4ParamsIdx_A),x0
	mpy x0,x1,b			; b = A * x1

	lea (r0+Filt4StateIdx_Part0),r2
filt41	Filt4RunPart
	move Y:(r5+Filt4ParamsIdx_B),x0
	mac x0,y1,b			; b = B * lp1 + A * x1

	lea (r0+Filt4StateIdx_Part1),r2
filt42	Filt4RunPart
	move Y:(r5+Filt4ParamsIdx_C),x0
	mac x0,y1,b			; b = C * lp2 + B * lp1 + A * x1

	lea (r0+Filt4StateIdx_Part2),r2
filt43	Filt4RunPart
	move Y:(r5+Filt4ParamsIdx_D),x0
	mac x0,y1,b

	lea (r0+Filt4StateIdx_Part3),r2
filt44	Filt4RunPart
	move Y:(r5+Filt4ParamsIdx_E),x0
	mac x0,y1,b
	; TODO: resonance
filt4o	move b,a
	rts


