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

;**********************************************************************
; Memory allocations
;**********************************************************************
	org	X:$000000	;Denotes the the memory location where the contents of the following lines will be stored 
;Do your own allocations of X-memory here

	
	org	Y:$000000
;Do your own allocations of Y-memory here

OutputSaw ds 1
OutputDpw ds 1
OutputPulse ds 1
OutputPulseSaw1 ds 1
OutputPulseSaw2 ds 1
OutputPulseDpw ds 1


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

	; OSCS: parameters
	; saw generation at the bottom, others computed from it
freq	equ	400.0
rate	equ	48000
	move #>(freq/(rate/2.0)),r0 ; raw tick (delta) for naive saw, 2.0 because -1..1 range is 2
	move #>-1.0,r1 ; counter (-1..1)

	move #>1.0,r2 ; previous state of dpw
	move #(rate/(4*freq*(1-freq/rate))/2048),r3 ; c coefficient for dpw, shift by 11 (max amount 1500, for freq 8Hz)

	move #>0,r4 ; pulse saw counter [0,1), same tick as r0
	move #>0.345,r5 ; pulse duty cycle

	move #>1,r6 ; pulse dpw prev state
	move #>(freq/(rate)),r7 ; raw tick (delta) for naive saw, [0,1)
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
	

	; *** OSCS: CODE START
trivialsaw:
	move r1,a	; get counter
	move r0,x0
	add x0,a	; counter += tick
	cmp #>1.0,a
	ble _notoverflow
		add #>-1.0,a ; "modulo" 1, wrap to around -1
		add #>-1.0,a
_notoverflow:
	move a,r1	;
	move r1,Y:OutputSaw

dpwsaw:
	move r1,x0
	mpy x0,x0,a	; a = counter ^ 2
	move a,b
	move r2,x1
	move a,r2	; store new state
	sub x1,b	; differentiate
	move b,x0
	move r3,x1
	mpy x0,x1,a	; out = c * dsq
	asl #11,a,a	; fixpt coef
	move a,Y:OutputDpw

trivialpulse:
	move r4,a	; get counter
	move r7,x0
	add x0,a	; counter += tick
	cmp #>1.0,a
	ble _notoverflow
		add #>-1.0,a ; "modulo" 1, wrap to around 0
_notoverflow:
	move a,r4
	move a,Y:OutputPulseSaw1
	move a,b
	move r5,x0	; duty cycle
	add x0,b	; shifted saw generator
	cmp #>1.0,b
	ble _notoverflow2
		add #>-1.0,b
_notoverflow2:
	move b,Y:OutputPulseSaw2
	move b,x0
	sub x0,a	; pulse = saw difference
	move a,Y:OutputPulse
	
dpwpulse:
	move a,Y:OutputPulseDpw

	; *** OSCS: CODE END

	
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
