;**********************************************************************
; C H A M E L E O N   DSP Assembler file                              *
;**********************************************************************
; S-89.3510 Assignment: Virtual analog synthesizer                    *
;                                                                     *
; By Konsta Hölttä and Nuutti Hölttä                                  *
;                                                                     *
; Current state:                                                      *
; - initial structure for channel freeing and allocation and note     *
;   playing                                                           *
; - chameleon's panel buttons play some notes, encoder changes octave *
;   (somewhat buggy and such, but will be removed anyway)             *
; - midi key on and key off input (velocity currently ignored)        *
; - Some oscillators (saw, dpw, pulse, dpw pulse)                     *
; - framework for implementing several filters/effects                *
;                                                                     *
; Non-exhaustive list of TODOs in no particular order:                *
; - get rid of the current panel interface                            *
; - way to specify the instrument at runtime                          *
; - ADSR and LFO for filters                                          *
; - more interesting instruments                                      *
; - fix, optimize and prettify all the things                         *
;                                                                     *
; Some basic stuff based on:                                          *
; Project work template for sample-based audio I/O (polling)          *
; Based on the example dspthru by Soundart                            *
; Hannu Pulakka, March 2006, February 2007                            *
; Modified by Antti Pakarinen, February 2012, update in March 2012    *
; Register r7 is reserved for interrupt routines as default           *
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

	define	simulator	'0'

;**********************************************************************

PI	equ	3.14159265
RATE	equ	48000
DT	equ	1.0/RATE

	include 'oscinc.asm'
	include 'filtinc.asm'
	include 'adsrinc.asm'

; ChannelCapacity is the fixed size for each channel.
; Depending on the actual oscillator and filter state sizes, this may be
; more than needed, but doesn't matter. NOTE: this must be increased
; if it's not enough for some oscillator+filter combination.
ChannelCapacity  equ 64
OscStateCapacity equ 20 ; FIXME: just a constant sized block, hope that no one is bigger
NumChannels      equ 5

; Channel data format:
; [0]                      note number (if highest bit is set, the channel is not alive)
; [1]                      oscillator eval function address
; [2]                      filter eval function address
; [3]                      filter state start address
; [4 and forward]          adsr state
; [4 + AdsrStateSize]      instrument pointer
; [4 + AdsrStateSize + 1]  oscillator state
; [after osc state]        filter state (this is where [3] points to)
ChDataIdx_Note          equ 0
ChDataIdx_OscEval       equ 1
ChDataIdx_FiltEval      equ 2
ChDataIdx_FiltStateAddr equ 3
ChDataIdx_AdsrState     equ 4
ChDataIdx_InstruPtr     equ (4+AdsrStateSize)
ChDataIdx_OscState      equ (4+AdsrStateSize+1)

ChNoteDeadBit           equ 23
ChNoteKeyoffBit         equ 22

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

KeyBit_Edit      equ 8
KeyBit_PartUp    equ 9
KeyBit_Shift     equ 10
KeyBit_PartDown  equ 11
KeyBit_GroupUp   equ 16
KeyBit_PageUp    equ 17
KeyBit_GroupDown equ 18
KeyBit_PageDown  equ 19
KeyBit_ParamUp   equ 20
KeyBit_ValueUp   equ 21
KeyBit_ParamDown equ 22
KeyBit_ValueDown equ 23


;**********************************************************************
; Memory allocations
;**********************************************************************
	org	X:$000000

; Starting at ChannelData, there is data for NumChannels channels; each has a ChannelCapacity-sized block of memory.
ChannelData: ds NumChannels*ChannelCapacity
AccumBackup ds 3
AccumBackup2 ds 3
LolTimer ds 1

	org	Y:$000000

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
PrevKeypadState:
	ds	1

NoteThatWentDown: ; If a key just went down, this holds the note value. Otherwise, this has highest bit set.
	ds	1
NoteThatWentUp:   ; If a key just went up, this holds the note value. Otherwise, this has highest bit set.
	ds	1

; TODO: the above NoteThatWentDown end NoteThatWentUp currently don't support it when several keys
; go down (or up) at about the same time (before the last one has been processed).
; Might want to fix this if trouble ensues.

PanelKeys_NoteOffset:
	dc 0

;For debug and simulation
OutputL:
	ds	1
OutputR:
	ds	1
OutputMiddle:
	ds 1
OutputAdsr:
	ds 1
OutputOsc:
	ds 1

	include 'instruparams.asm'
	include 'dpw_coefs.asm'
	include 'saw_ticks.asm'
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
VecHostCommandMidiKeyOn:
	JSR >MidiKeyOn
VecHostCommandMidiKeyOff:
	JSR >MidiKeyOff

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
	MOVE	A,Y:MasterVolume
	; Channel synchronization
	if !simulator
	  BRSET	#SSISR_RFS,X:<<SSISR0,*		; Wait while receiving left frame
	  BRCLR	#SSISR_RFS,X:<<SSISR0,*		; Wait while receiving right frame
	endif

	; initialize all channels as dead

	move #>(1<<ChNoteDeadBit),x0
	move #>ChannelData,a

	do #NumChannels,DeadChannelInitLoopEnd
		move a1,r1
		move x0,X:(r1+ChDataIdx_Note)
		add #>ChannelCapacity,a
	DeadChannelInitLoopEnd:

	; no note has just went up or down

	move x0,Y:NoteThatWentUp
	move x0,Y:NoteThatWentDown

	move #>0,x0
	move x0,Y:PrevKeypadState
	move x0,Y:KeypadState
	move x0,X:LolTimer

MainLoop:
	; temporary, ugly code for converting chameleon panel key presses to note values.
	; the encoder modifies an offset added to every note (note that you need only turn the knob
	; slightly to get to the higher notes)

	move Y:KeypadState,x0

	if simulator
		; simulate a keypress
		move X:LolTimer,a
		add #>1,a
		move a,X:LolTimer
		cmp #>500,a
		bge _keyoff
	_keyon:
		move #>(1<<KeyBit_Edit),x0
	_keyoff:
		; keypadstate is 0
	endif
	move Y:PrevKeypadState,a
	cmp x0,a
	beq NoKeysChanged
		move a,b
		eor x0,b

		; can't bother prettifying this.. we'll remove this soon anyway, right?

		brclr #KeyBit_Edit,b1,PanelKeys_NotEdit
			move #>0,b
			jmp PanelKeyIdentified
		PanelKeys_NotEdit:

		brclr #KeyBit_PartUp,b1,PanelKeys_NotPartUp
			move #>1,b
			jmp PanelKeyIdentified
		PanelKeys_NotPartUp:

		brclr #KeyBit_GroupUp,b1,PanelKeys_NotGroupUp
			move #>2,b
			jmp PanelKeyIdentified
		PanelKeys_NotGroupUp:

		brclr #KeyBit_PageUp,b1,PanelKeys_NotPageUp
			move #>3,b
			jmp PanelKeyIdentified
		PanelKeys_NotPageUp:

		brclr #KeyBit_ParamUp,b1,PanelKeys_NotParamUp
			move #>4,b
			jmp PanelKeyIdentified
		PanelKeys_NotParamUp:

		brclr #KeyBit_ValueUp,b1,PanelKeys_NotValueUp
			move #>5,b
			jmp PanelKeyIdentified
		PanelKeys_NotValueUp:

		brclr #KeyBit_Shift,b1,PanelKeys_NotShift
			move #>6,b
			jmp PanelKeyIdentified
		PanelKeys_NotShift:

		brclr #KeyBit_PartDown,b1,PanelKeys_NotPartDown
			move #>7,b
			jmp PanelKeyIdentified
		PanelKeys_NotPartDown:

		brclr #KeyBit_GroupDown,b1,PanelKeys_NotGroupDown
			move #>8,b
			jmp PanelKeyIdentified
		PanelKeys_NotGroupDown:

		brclr #KeyBit_PageDown,b1,PanelKeys_NotPageDown
			move #>9,b
			jmp PanelKeyIdentified
		PanelKeys_NotPageDown:

		brclr #KeyBit_ParamDown,b1,PanelKeys_NotParamDown
			move #>10,b
			jmp PanelKeyIdentified
		PanelKeys_NotParamDown:

		brclr #KeyBit_ValueDown,b1,PanelKeys_NotValueDown
			move #>11,b
			jmp PanelKeyIdentified
		PanelKeys_NotValueDown:

		PanelKeyIdentified:

		move Y:PanelKeys_NoteOffset,y0
		if simulator
			move #>100,y0
		endif
		add y0,b

		cmpu x0,a
		bgt KeyUp
			move b,Y:NoteThatWentDown
			jmp DoneKeyDown
		KeyUp:
			move b,Y:NoteThatWentUp
		DoneKeyDown:
		move x0,Y:PrevKeypadState
	NoKeysChanged:

	; check if a key just went up

	brset #23,Y:NoteThatWentUp,NoNoteWentUp
		move Y:NoteThatWentUp,x0
		move #>$ffffff,y0
		move y0,Y:NoteThatWentUp

		; find and kill the channel
		; (don't actually kill, but turn up the key off bit)
		; this starts the decay phase, and the ADSR kills this channel after having decayed to silence

		move #>ChannelData,a
		do #NumChannels,ChannelKillLoopEnd
			move a1,r1

			move X:(r1+ChDataIdx_Note),b
			cmp x0,b
			bne NotTheNoteToKill
				bset #ChNoteKeyoffBit,b1
				move b1,X:(r1+ChDataIdx_Note)
				enddo
			NotTheNoteToKill:

			add #>ChannelCapacity,a
		ChannelKillLoopEnd:
	NoNoteWentUp:

	; check if a key just went down

	brset #23,Y:NoteThatWentDown,NoNoteWentDown
		move Y:NoteThatWentDown,n2
		move #>$ffffff,y0
		move y0,Y:NoteThatWentDown

		; find a free channel and initialize there
		; NOTE: if no free channels are available, the new note is just ignored.
		; TODO: the following code assumes that instrument (or oscillator and filter) init routines
		;   never modify the A, r1 or r4 registers. Nobody probably cares about r1/r4, but
		;   A might be nice, so if that comes up, modify this code appropriately.
	AllocChannel:
		move #>ChannelData,a
		do #NumChannels,ChannelAllocationLoopEnd
			move a1,r1

			move X:(r1+ChDataIdx_Note),y0
			brclr #ChNoteDeadBit,y0,NotFreeChannel
				move n2,X:(r1+ChDataIdx_Note)
				; r1: workspace pointer
				; r4: instrument pointer
				lua (r1+ChDataIdx_AdsrState),r0
				bsr AdsrInitState

				move #>Instrument_Bass,r4 ; TODO: select instrument somehow
				move r4,X:(r1+ChDataIdx_InstruPtr)

				; eliminate another pointer indirection in eval loop
				; cache oscillator and filter eval functions
				move Y:(r4+InstruParamIdx_OscFunc),x0
				move x0,X:(r1+ChDataIdx_OscEval)
				move Y:(r4+InstruParamIdx_FiltFunc),x0
				move x0,X:(r1+ChDataIdx_FiltEval)

				lua (r1+ChDataIdx_OscState+OscStateCapacity),r0
				move r0,X:(r1+ChDataIdx_FiltStateAddr)

				move Y:(r4+InstruParamIdx_InitFunc),r0
				ChAlloc_InitInstruState:
				bsr r0

				enddo
			NotFreeChannel:

			add #>ChannelCapacity,a

		ChannelAllocationLoopEnd:
	NoNoteWentDown:

	; evaluate channels, sum into b

	RenderSample:
	clr b
	move #>ChannelData,r1

	do #NumChannels,ChannelEvaluateLoopEnd
		move X:(r1+ChDataIdx_Note),y0
		brset #ChNoteDeadBit,y0,DeadChannel
			; save value of b so far
			; TODO: come up with a nicer way. This is slow.
			move b0,X:(AccumBackup)
			move b1,X:(AccumBackup+1)
			move b2,X:(AccumBackup+2)

			move X:(r1+ChDataIdx_InstruPtr),r4
		
			; evaluate oscillator
			lua (r1+ChDataIdx_OscState),r0
			move X:(r1+ChDataIdx_OscEval),r2
			ChEval_OscEvalBranch:
			bsr r2
			move a,Y:OutputOsc

			; evaluate filter
			move X:(r1+ChDataIdx_FiltStateAddr),r0
			move X:(r1+ChDataIdx_FiltEval),r2
			ChEval_FiltEvalBranch:
			bsr r2
			move a,Y:OutputMiddle

			; save a, as it's used in adsr
			move a0,X:(AccumBackup2)
			move a1,X:(AccumBackup2+1)
			move a2,X:(AccumBackup2+2)

			; compute adsr envelope and apply (multiply by) it
			lua (r4+InstruParamIdx_Adsr),r0
			lua (r1+ChDataIdx_AdsrState),r4
			move X:(r1+ChDataIdx_Note),r2
			bsr AdsrEval
			move r3,Y:OutputAdsr

			move X:(AccumBackup2),a0
			move X:(AccumBackup2+1),a1
			move X:(AccumBackup2+2),a2

			brclr #23,r3,_notkilled ; negative -> killed?
		_killthischannel:
			move #>0,r3
			bset #ChNoteDeadBit,r2
			move r2,X:(r1+ChDataIdx_Note)

		_notkilled:
			move a,x0
			move r3,x1 ; TODO: return adsr value in x1?
			mpy x0,x1,a ; a *= adsr

			; restore b's value and sum the new sample from a (though scaled by 1/NumChannels)
			move X:(AccumBackup),b0
			move X:(AccumBackup+1),b1
			move X:(AccumBackup+2),b2
			move a,x0
			maci #1.0/NumChannels,x0,b
		DeadChannel:

		move r1,a
		add #>ChannelCapacity,a
		move a,r1
	ChannelEvaluateLoopEnd:

	move b,y0
	
	;Output routines for left Ch
	MOVE	Y:MasterVolume,X0		; Current volume value from memory to X0
	MOVE	Y0,Y:OutputL			; Move the output value to memory for simulator use
	MPYR	X0,Y0,B				; Multiply the current output sample with the current volume value
	NOP
	if !simulator
	BRCLR	#SSISR_TDE,X:<<SSISR0,*		; Wait for transmit register
	endif 
	MOVEP	B,X:<<TX00			; Write new output sample to the DAC	
	
	;Output routines for right Ch
	MOVE	Y:MasterVolume,X1		; Current volume value from memory to X0
	MOVE	Y0,Y:OutputR			; Move the output value from Y1 to memory for simulator use
	MPYR	X1,Y0,B				; Scale the input sample according to the volume curve
	NOP
	if !simulator
	BRCLR	#SSISR_TDE,X:<<SSISR0,*		; Wait for transmit register
	endif 
	MOVEP	B,X:<<TX00			; Write new output sample to the DAC


	BRA	MainLoop

	include 'instrucode.asm'
	include 'adsr.asm'
	include 'osc.asm'
	include 'filt.asm'

;*******************************************	
;INTERRUPT ROUTINES
;*******************************************	
UpdateVolume:
	BRCLR	#HSR_HRDF,X:<<HSR,*	; Make sure that data is available
	MOVEP	X:<<HRX,r7		; Read the data to r7	
	MOVE	r7,Y:MasterVolume	; Write the data to memory
	MOVEP	r7,X:<<HTX		; Write the read value back to the MCU	
	RTI				; Return from interrupt
UpdateCTRL1:
	BRCLR	#HSR_HRDF,X:<<HSR,*
	MOVEP	X:<<HRX,r7
	MOVE	r7,Y:CTRL1Value
	move	r7,y:ankka
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
	move	Y:OutputL,r7
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

	move Y:PanelKeys_NoteOffset,r7
	lua (r7+12),r7
	move r7,Y:PanelKeys_NoteOffset

	RTI
EncoderDown:
	;Write your encoder down handler here

	move Y:PanelKeys_NoteOffset,r7
	lua (r7-12),r7
	move r7,Y:PanelKeys_NoteOffset

	RTI	

MidiKeyOn:
	BRCLR	#HSR_HRDF,X:<<HSR,*
	MOVEP	X:<<HRX,r7
	MOVE	r7,Y:NoteThatWentDown
	RTI
MidiKeyOff:
	BRCLR	#HSR_HRDF,X:<<HSR,*
	MOVEP	X:<<HRX,r7
	MOVE	r7,Y:NoteThatWentUp
	RTI

	end	Start
