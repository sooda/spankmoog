;**********************************************************************
; C H A M E L E O N   DSP Assembler file                              *
;**********************************************************************
; Project work template for sample-based audio I/O (polling)          *
; Based on the example dspthru by Soundart                            *
; Hannu Pulakka, March 2006, February 2007                            *
; Modified by Antti Pakarinen, February 2012, update in March 2012    *
; Register r7 is reserved for interrupt routines as default	      *
;**********************************************************************

 	nolist
	page	255,0
	opt	MU,S,CC,CEX,MEX,MD
	list

	nolist
	include	"SDK\include\dsp\dsp_equ.asm"
	list

;**********************************************************************
; The following definition switches between a simulator version and 
; a real-time version of the program. Set this to '1' if you are 
; analyzing the program with the simulator, and to '0' if you are 
; running the program in Chameleon.
; 
; The definition is used later in this assembly file to skip or 
; include sample synchronization, which does not work in the simulator
; but is essential for correct operation in Chameleon. 

	define	simulator	'1'

;**********************************************************************
; ADSR: natural constants for beautiful sound
E	equ	2.718281828
TGTCOEF	equ	E/(E-1) ; ~1,58, ~1/0.63, decay target multiplier to get to actual target in a time constant

;**********************************************************************
; Memory allocations
;**********************************************************************
	org	X:$000000	;Denotes the the memory location where the contents of the following lines will be stored 
;Do your own allocations of X-memory here


	
	org	Y:$000000
;Do your own allocations of Y-memory here



;Template related memory allocations
MasterVolumeTarget:	;Holds the current value of volume pot (log scale $0-$7FFFFF)
	ds	1	
MasterVolume:		
	ds	1		
CTRL1Value:		;Holds the current value of control pot 1 (lin scale $0-$7FFFFF)
	ds	1	
CTRL2Value:		;Holds the current value of control pot 2 (lin scale $0-$7FFFFF)
	ds	1	
CTRL3Value:		;Holds the current value of control pot 3 (lin scale $0-$7FFFFF)
	ds	1
KeypadState:		;Holds the current state of buttons. Bit values represent the states (1=down, 0=up)
	ds	1	
;Bit numbers in "KeypadState" for each button:
;#8:  Edit
;#9:  Part up
;#10: Shift
;#11; Part down 
;#16: Group up
;#17: Page up
;#18: Group down
;#19: Page down
;#20: Param up
;#21: Value up
;#22: Param down
;#23: Value down	

;For debug and simulation
OutputL:
	ds	1
OutputR:
	ds	1
	




;**********************************************************************
; Interrupt vectors
;**********************************************************************
	org	P:VecHostCommandDefault
VecHostCommandUpdateVolume:
	JSR	>UpdateVolume
VecHostCommandUpdateCTRL1:
	JSR	>UpdateCTRL1
VecHostCommandUpdateCTRL2:
	JSR	>UpdateCTRL2
VecHostCommandUpdateCTRL3:
	JSR	>UpdateCTRL3
VecHostCommandEncoderUp:
	JSR	>EncoderUp
VecHostCommandEncoderDown:
	JSR	>EncoderDown
VecHostCommandKeyEvent:
	JSR	>KeyEvent

;**********************************************************************
; Program code
;**********************************************************************
	org	P:$000100

Start:
	CLR	A
	; Enable ESSI0 transmit and receive
	BSET	#CRB_TE0,X:<<CRB0		; Enable Transmit 0
	BSET	#CRB_RE,X:<<CRB0		; Enable Receive  0
	;Interrupt enable
	ANDI	#<$FC,MR			; Enable interrupts
	BCLR	#SR_I0,SR			; Unmask interrupts
	BCLR	#SR_I1,SR
	BSET	#HCR_HCIE,X:<<HCR  		; Enable Host command interrupt
	; Initialize Master Volume variables
	MOVE	A,Y:MasterVolumeTarget
	MOVE	A,Y:MasterVolume
	; Channel synchronization
	if !simulator
	  BRSET	#SSISR_RFS,X:<<SSISR0,*		; Wait while receiving left frame
	  BRCLR	#SSISR_RFS,X:<<SSISR0,*		; Wait while receiving right frame
	endif

	; ADSR: Parameters.
	; r0 reserved for release target
	move #>0,r1 ; state (a/d/r)
	move #>0,r2 ; value
	move #(1-@POW(E,-1.0/200)),r3 ; a/d/r speed coefficient, same for each step so far in this demo
	move #>0,r4 ; gate timer
	move #0.5,r5 ; sustain level
MainLoop:

	; *** Audio input and output are processed here ***
	; 
	; The following default code
	; - copies data from input to output and multiplies with the current gain
	; - smooths master volume changes
	;
	; Note: If you want to work in mono, just use the left channel and copy the output to right channel also
	
	
	;*** LEFT CHANNEL ********************************************************
	;Input routines for left Ch	
	if !simulator
	BRCLR	#SSISR_RDF,X:<<SSISR0,*		; Wait until receive register is full
	endif
	MOVEP	X:<<RX0,Y0			; Read new input sample

	; *** Do the processing here for left ch, Y0 holds the sample ****	
	

	; *** ADSR: CODE START
adsr:
	; this demo uses a simple timer to emulate a keypad key that triggers this adsr
	; ++gatetime >= finish? goto gateoff
	move r4,a1 ; r4: gate timer
	add #>1,a
	cmp #>1000,a
	move a1,r4
	bge gateoff
gateon:
	move r1,a
	cmp #<0,a
	bne test1
state0:	; attack
	; NOTE: everything divided by 2 so that we can actually reach 1
	; (exponentially decaying things never actually reach the target,
	; only 63% of it in the time constant, so we trick it by
	; specifying a different target, which might be >1
	; also, when decaying, the target could be 1 + -1/0.63 = -0,59,
	; and then "target - value" would overflow.
	; value += coef * (target - value) [ideally]
	; value = 2 * (value/2 + coef * (target/2 - value/2))
	;                                ^^^^^^^^ precalc'd constant
	; same thing in release state
	move r2,a ; r2: value
	move #(TGTCOEF/2),b ; target to get to 1
	asr #1,a,a ; value /= 2
	sub a,b ; tgt - value
	move r3,x0 ; r3: coeff
	move b,x1 ; move to temp
	mac x0,x1,a ; a = 0.5*(value + coeff * (top - value))
	asl #1,a,a ; multiply back by 2
	nop ; stall :--(
	move a,r2 ; value = a
	brclr #23,a1,gotresult ; didn't overflow yet
gotodecay:
	move #<1,r1 ; state = decay
	bra state1 ; when clipped, we should already be decaying (should we interpolate somehow?) ; outswitch
test1:	cmp #<1,a ; TODO: only states 0 or 1,
	bne gotresult ; should never get here currently?
state1: ; decay, no need to hack magical targets here yet when decaying in IIR mode
	move r2,a ; r2: value
	move r5,b ; r5: sustain level
	sub a,b ; b = tgt - val
	move r3,x0 ; r3: coeff
	move b,x1 ; b to temp
	mac x0,x1,a ; value += coef * diff
	nop ; stall :--(
	move a,r2 ; r2 = value
	bra gotresult

gateoff:
	move r1,a
	cmp #<2,a
	beq relinited
	cmp #<3,a
	beq gotresult ; killed note
relinit: ; start release state from whatever state we are in (a/d/s)
	; compute release target: current + (0 - current) * targetcoef = (1-targetcoef) * current
	move r2,x0
	mpyi #((1-TGTCOEF)/2),x0,a
	move a,r0
	move #2,r1
relinited:
	; this divide by 2 hax again because we might roll from 1 to -0.58 which again does not fit
	; copypasta from attack stage
	move r2,a ; r2: value
	move r0,b ; r0: target
	asr #1,a,a ; value /= 2
	sub a,b ; tgt - value
	move r3,x0 ; r3: coeff
	move b,x1 ; move to temp
	mac x0,x1,a ; a = 0.5*(value + coeff * (top - value))
	asl #1,a,a ; multiply back by 2
	nop ; stall :--(
	move a,r2 ; value = a
	brclr #23,a1,gotresult ; didn't overflow yet
gotokilled:
	move #3,r1 ; state
	move #0,r2 ; value
gotresult:
	; finished, just output the value somewhere
	move r2,y0
	; *** ADSR: CODE END

	
	;Output routines for left Ch
	MOVE	Y:MasterVolume,X0		; Current volume value from memory to X0
	MOVE	Y0,Y:OutputL			; Move the output value to memory for simulator use
	MPYR	X0,Y0,B				; Multiply the current output sample with the current volume value
	NOP
	if !simulator
	BRCLR	#SSISR_TDE,X:<<SSISR0,*		; Wait for transmit register
	endif 
	MOVEP	B,X:<<TX00			; Write new output sample to the DAC
	
	;;*** RIGHT CHANNEL ********************************************************
	;;Input routines for right Ch
	;if !simulator
	;BRCLR	#SSISR_RDF,X:<<SSISR0,*		; Wait until receive register is full
	;endif
	;MOVEP	X:<<RX0,Y1			; Read new input sample

	; *** Do the processing here for right ch, Y1 holds the sample ****	
	 
	  
	
	;Output routines for right Ch
	MOVE	Y:MasterVolume,X0		; Current volume value from memory to X0
	MOVE	Y0,Y:OutputR			; Move the output value from Y0 to memory for simulator use
	MPYR	X0,Y0,B				; Scale the input sample according to the volume curve
	NOP
	if !simulator
	BRCLR	#SSISR_TDE,X:<<SSISR0,*		; Wait for transmit register
	endif 
	MOVEP	B,X:<<TX00			; Write new output sample to the DAC
	
	
	;** Volume smoothing ******************************************************
	
	MOVE	Y:MasterVolumeTarget,B		; target volume value
	MOVE	Y:MasterVolume,A		; current volume value
	SUB	A,B				
	ASR	#10,B,B				; increment
	ADD	A,B				; current volume value += increment
	NOP
	MOVE	B,Y:MasterVolume

	; *** End of audio input and output processing ***

	BRA	MainLoop
	

;*******************************************	
;INTERRUPT ROUTINES
;*******************************************	
UpdateVolume:
	BRCLR	#HSR_HRDF,X:<<HSR,*	; Make sure that data is available
	MOVEP	X:<<HRX,r7		; Read the data to r7	
	MOVE	r7,Y:MasterVolumeTarget	; Write the data to memory
	MOVEP	r7,X:<<HTX		; Write the read value back to the MCU	
	RTI				; Return from interrupt
UpdateCTRL1:
	BRCLR	#HSR_HRDF,X:<<HSR,*
	MOVEP	X:<<HRX,r7
	MOVE	r7,Y:CTRL1Value
	MOVEP	r7,X:<<HTX
	RTI
UpdateCTRL2:
	BRCLR	#HSR_HRDF,X:<<HSR,*
	MOVEP	X:<<HRX,r7
	MOVE	r7,Y:CTRL2Value
	MOVEP	r7,X:<<HTX
	RTI
UpdateCTRL3:
	BRCLR	#HSR_HRDF,X:<<HSR,*
	MOVEP	X:<<HRX,r7
	MOVE	r7,Y:CTRL3Value
	MOVEP	r7,X:<<HTX
	RTI
KeyEvent:
	BRCLR	#HSR_HRDF,X:<<HSR,*
	MOVEP	X:<<HRX,r7
	MOVE	r7,Y:KeypadState
	MOVEP	r7,X:<<HTX
	RTI
EncoderUp:
	;Write your encoder up handler here

	RTI
EncoderDown:
	;Write your encoder down handler here

	RTI	
	
	end	Start

