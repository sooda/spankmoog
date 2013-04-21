;**********************************************************************
; C H A M E L E O N   DSP Assembler file                              *
;**********************************************************************
; S-89.3510 Assignment: Virtual analog synthesizer                    *
;                                                                     *
; By Konsta Hölttä and Nuutti Hölttä 2013                             *
;                                                                     *
; Current state: pretty much everything here and there                *
;                                                                     *
; Non-exhaustive list of TODOs in no particular order:                *
; - A better way to handle the midi events in a queue or something    *
; - more interesting instruments                                      *
; - fix, optimize and prettify all the things                         *
; - rewrite the current state documentation above                     *
;                                                                     *
; Some basic stuff based on:                                          *
; Project work template for sample-based audio I/O (polling)          *
; Based on the example dspthru by Soundart                            *
; Hannu Pulakka, March 2006, February 2007                            *
; Modified by Antti Pakarinen, February 2012, update in March 2012    *
; Registers r7+n7 are reserved for interrupt routines as default      *
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
	include 'sininc.asm'

; ChannelCapacity is the fixed size for each channel.
; Depending on the actual oscillator and filter state sizes, this may be
; more than needed, but doesn't matter. NOTE: this must be increased
; if it's not enough for some oscillator+filter combination.
ChannelCapacity  equ 63
OscStateCapacity equ 25 ; FIXME: just a constant sized block, hope that no one is bigger
NumChannels      equ 10

ChDataIdx_Note          equ 0
ChDataIdx_FiltStateAddr equ 1
ChDataIdx_AdsrState     equ 2
ChDataIdx_InstruPtr     equ (2+AdsrStateSize)
ChDataIdx_InstruIdx     equ (2+AdsrStateSize+1)
ChDataIdx_Velocity      equ (2+AdsrStateSize+2)
ChDataIdx_OscState      equ (2+AdsrStateSize+3)

ChDataIdx_FiltState     equ (ChDataIdx_OscState+OscStateCapacity)

ChNoteDeadBit           equ 23
ChNoteKeyoffBit         equ 22

;**********************************************************************
; Memory allocations
;**********************************************************************
	org	X:$000000

; Starting at ChannelData, there is data for NumChannels channels; each has a ChannelCapacity-sized block of memory.
ChannelData: ds NumChannels*ChannelCapacity
AccumBackup ds 3
AccumBackup2 ds 3
AccumBackupLfo ds 3

	org	Y:$000000

MasterVolume:		
	ds	1		
NoteThatWentDown: ; If a key just went down, this holds the note value. Otherwise, this has highest bit set.
	ds	1
InstrumentThatWentDown: ; If a key just went down, this holds the new instrument index for that
	ds	1
NoteThatWentUp:   ; If a key just went up, this holds the note value. Otherwise, this has highest bit set.
	ds	1
InstrumentThatWentUp: ; If a key just went up, this holds the instrument index for that
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
PanicState:
	ds 1
OutputHax ds 1

	include 'instruparams.asm'
	include 'dpw_coefs.asm'
	include 'saw_ticks.asm'
	include 'sin_table.asm'
;**********************************************************************
; Interrupt vectors
;**********************************************************************
	org	P:VecHostCommandDefault
VecHostCommandUpdateVolume:
	JSR	>UpdateVolume
VecHostCommandUpdateTunable:
	JSR	>UpdateTunable
VecHostCommandEncoderUp:
	JSR	>EncoderUp
VecHostCommandEncoderDown:
	JSR	>EncoderDown
VecHostCommandKeyEvent:
	JSR	>KeyEvent
VecHostCommandMidiKeyOn:
	JSR	>MidiKeyOn
VecHostCommandMidiKeyOff:
	JSR	>MidiKeyOff
VecHostCommandPanic:
	JSR	>Panic

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

	; The cycle count is computed with a free-running timer in the background
	; The counter increments by one every 2 cycles

	; timer prescale load: just in case, reset the source to clk/2
	move #>0,x0
	move x0,X:TPLR
	; load reg, start counting from here
	move x0,X:TLR0

	move x0,Y:PanicState

	; simulate just one keypress
	if simulator
		move #>100,x0
		move x0,Y:NoteThatWentDown
		move #>$7fff03,x0
		move x0,Y:InstrumentThatWentDown
	endif

MainLoop:
	; reset the counter control reg first
	move #>0,x0
	move x0,X:TCSR0
	; TRM bit (restart mode) cleared -> free running counter
	; tc0|tc1: mode 3 = event counter (just count clock cycles)
	move #>(TCSR_TC0|TCSR_TC1|TCSR_TE),x0
	move x0,X:TCSR0 ; mode 3, enable
	; it seems that we need these nops first to correctly count the work cycles
	; (could as well just add 4 to the counter when displaying it)
	nop
	nop
	nop
	nop
	; timed code seems to start from here
	; for example, with these nops we get the number 1 out of TCR0 (with 1 nop, value 0, with 3, value 1 again)
	;nop
	;nop
	;move X:TCR0,a
	;asl #1,a,a
	;move a,X:<<HTX

	; check if a key just went up

	brset #23,Y:NoteThatWentUp,NoNoteWentUp
		move Y:NoteThatWentUp,x0
		move Y:InstrumentThatWentUp,x1
		move #>$ffffff,y0
		move y0,Y:NoteThatWentUp

		; find and kill the channel
		; (don't actually kill, but turn up the key off bit)
		; this starts the decay phase, and the ADSR kills this channel after having decayed to silence

		move #>ChannelData,r1
		do #NumChannels,ChannelKillLoopEnd
			move X:(r1+ChDataIdx_InstruIdx),b
			cmp x1,b
			bne NotTheNoteToKill
			move X:(r1+ChDataIdx_Note),b
			cmp x0,b
			bne NotTheNoteToKill
				bset #ChNoteKeyoffBit,b1
				move b1,X:(r1+ChDataIdx_Note)
				enddo
			NotTheNoteToKill:
			nop ; enddo too close
			lua (r1+ChannelCapacity),r1
		ChannelKillLoopEnd:
	NoNoteWentUp:

	brclr #0,Y:PanicState,PanicLoopEnd
		move #>ChannelData,r1
		do #NumChannels,PanicLoopEnd
			bset #ChNoteDeadBit,b1
			move b1,X:(r1+ChDataIdx_Note)
			lua (r1+ChannelCapacity),r1
	PanicLoopEnd:
	bclr #0,Y:PanicState ; not needed anymore (don't bother checking if it was on, just clear)
	; check if a key just went down

	brset #23,Y:NoteThatWentDown,NoNoteWentDown
		move Y:NoteThatWentDown,n2
		move #>$ffffff,y0
		move y0,Y:NoteThatWentDown

		; find a free channel and initialize there
		; NOTE: if no free channels are available, the new note is just ignored.
		; NOTE: the inits must not edit r1 or r4. (FIXME: is this true anymore?)
	AllocChannel:
		move #>ChannelData,r1
		do #NumChannels,ChannelAllocationLoopEnd
			move X:(r1+ChDataIdx_Note),y0
			brclr #ChNoteDeadBit,y0,NotFreeChannel
				move n2,X:(r1+ChDataIdx_Note)
				; r1: workspace pointer
				; r4: instrument pointer
				lua (r1+ChDataIdx_AdsrState),r0
				bsr AdsrInitState

				move Y:InstrumentThatWentDown,a
				and #>$ff,a
				move Y:InstrumentThatWentDown,b
				and #>~$ff,b
				move a,r4
				move b,X:(r1+ChDataIdx_Velocity)
				move r4,X:(r1+ChDataIdx_InstruIdx)
				move Y:(r4+AllInstruments),r4
				move r4,X:(r1+ChDataIdx_InstruPtr)

				lua (r1+ChDataIdx_OscState+OscStateCapacity),r0 ; FIXME: filtstate renders this useless
				move r0,X:(r1+ChDataIdx_FiltStateAddr)

				move Y:(r4+InstruParamIdx_InitFunc),r0
				ChAlloc_InitInstruState:
				bsr r0

				enddo ; too near the loop end
				nop
			NotFreeChannel:
			lua (r1+ChannelCapacity),r1
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

			; TODO: maybe read this and r1 always before calling
			; those so they don't need to backup these. it's just a
			; couple of cycles.
			move X:(r1+ChDataIdx_InstruPtr),r4
		
			; evaluate oscillator
			lua (r1+ChDataIdx_OscState),r0
			move Y:(r4+InstruParamIdx_OscFunc),r2
			nop
			ChEval_OscEvalBranch:
			bsr r2
			move a,Y:OutputOsc

			; evaluate filter
			move X:(r1+ChDataIdx_FiltStateAddr),r0
			move Y:(r4+InstruParamIdx_FiltFunc),r2
			nop
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

			move X:(r1+ChDataIdx_Velocity),x1
			move a,x0
			mpy x0,x1,a

			; restore b's value and sum the new sample from a (though scaled by 1/NumChannels)
			move X:(AccumBackup),b0
			move X:(AccumBackup+1),b1
			move X:(AccumBackup+2),b2
			move a,x0
			maci #1.0/NumChannels,x0,b
		DeadChannel:

		lua (r1+ChannelCapacity),r1
	ChannelEvaluateLoopEnd:

	move b,y0
	
	; display the clock ticks on the panel
	; FIXME: this replaces the pot readings - bind printing to a panel button?
	move X:TCR0,a
	asl #1,a,a
	movep a,X:<<HTX

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
	include 'sin.asm'
	include 'isr.asm'
	end	Start
