;*******************************************
;INTERRUPT ROUTINES
;*******************************************

UpdateVolume:
	BRCLR	#HSR_HRDF,X:<<HSR,*	; Make sure that data is available
	MOVEP	X:<<HRX,r7		; Read the data to r7
	MOVE	r7,Y:MasterVolume	; Write the data to memory
	MOVEP	r7,X:<<HTX		; Write the read value back to the MCU
	RTI				; Return from interrupt

UpdateTunable:
	BRCLR	#HSR_HRDF,X:<<HSR,*
	MOVEP	X:<<HRX,r7
	move	Y:(r7+InstruTunables),r7
	BRCLR	#HSR_HRDF,X:<<HSR,*
	MOVEP	X:<<HRX,n7
	move	n7,Y:(r7)
	RTI

KeyEvent:
	BRCLR	#HSR_HRDF,X:<<HSR,*
	MOVEP	X:<<HRX,r7
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
	BRCLR	#HSR_HRDF,X:<<HSR,*
	MOVEP	X:<<HRX,r7
	MOVE	r7,Y:InstrumentThatWentDown
	;BRCLR	#HSR_HRDF,X:<<HSR,*
	;MOVEP	X:<<HRX,r7
	RTI

MidiKeyOff:
	BRCLR	#HSR_HRDF,X:<<HSR,*
	MOVEP	X:<<HRX,r7
	MOVE	r7,Y:NoteThatWentUp
	BRCLR	#HSR_HRDF,X:<<HSR,*
	MOVEP	X:<<HRX,r7
	MOVE	r7,Y:InstrumentThatWentUp
	RTI

Panic:
	bset #0,Y:PanicState
	rti
