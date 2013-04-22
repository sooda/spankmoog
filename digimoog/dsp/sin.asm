; Sin approximator
; ================
; This sin approximator approximates the sin function by interpolating values
; in a precalculated table (in sin_table.asm). Like oscillators and filters, the
; sin approximator has a state. The state contains three 24-bit numbers:
; - M+SinTable where M is the index to the lookup table
; - f, a fixed-point number, fractional part for interpolation
; - c, a fixed-point number, a constant added to f on every evaluation step
; such that the current approximation is calculated with
;   (1-f)*rawSin(M) + f*rawSin(M+1)
; where rawSin(i) is the entry in the lookup table at index i % SinTableSize.
; At each step, f is increased by c = frequency*SinTableSize/RATE. If f then
; exceeds (or equals) 1.0, M is incremented by one and 1.0 is subtracted from
; f. Note that the frequency must be less than RATE/SinTableSize; otherwise c
; would exceed 1.0. With LFOs this shouldn't be a problem, since e.g. with
; SinTableSize=32 this frequency threshold is 1500 Hz.

LFOSinStateIdx_MPlusSinTable equ 0
LFOSinStateIdx_f equ 1
LFOSinStateIdx_c equ 2

; Initialize sin state
; Input:
; 	X:(r0): state
; 	x0: c (see above for explanation)
; Work registers:
; 	x0
LFOSinInitState:
	move x0,X:(r0+LFOSinStateIdx_c)             ; state.c = c
	move #>SinTable,x0
	move x0,X:(r0+LFOSinStateIdx_MPlusSinTable) ; state.MPlusSinTable = SinTable, i.e. M = 0, i.e. start at the beginning
	move #>0,x0
	move x0,X:(r0+LFOSinStateIdx_f)             ; state.f = 0.0
	rts

; Compute next value of sin
; Input:
; 	X:(r2): state
; Output:
; 	x1: approximate sin value
; Work registers:
; 	b, x0, y0, y1, r3, r6
LFOSinEval:
	; compute result
	; in the comments here, let's abbreviate SinTable by T and SinTableSize by N.

	move X:(r2+LFOSinStateIdx_MPlusSinTable),r6 ; r6 = &T[M]
	move #>(SinTableSize-1),m6

	move Y:(r6)+,x0					; x0 = T[M % N]
	move Y:(r6)-,b					; b = T[(M+1) % N]
	sub x0,b                        ; b  = T[(M+1) % N] - T[M % N]
	move X:(r2+LFOSinStateIdx_c),y1 ; y1 = c
	move b,y0                       ; y0 = T[(M+1) % N] - T[M % N]
	move x0,b                       ; b = T[M % N]
	move X:(r2+LFOSinStateIdx_f),x0 ; x0 = f
	mac x0,y0,b                     ; b  = T[M % N] + f*(T[(M+1) % N] - T[M % N])  (this is the interpolated result)

	lua (r6)+,r3                    ; r3 = &T[M+1]

	move b,x1 ; result

	; advance the state

	move x0,b                        ; b = f
	add y1,b                         ; b = f+c
	move b,x0
	and #>$7fffff,b                  ; if f+c > 1.0, this wraps it back to f+c - 1.0
	move b,X:(r2+LFOSinStateIdx_f)
	cmp x0,b                         ; if wrapped around, this yields not-equal...
	tne r3,r6                        ; ...and r3, i.e. the address of the next table entry, goes to r6
	move r6,X:(r2+LFOSinStateIdx_MPlusSinTable)

	rts
