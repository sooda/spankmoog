/**********************************************************************
 * C H A M E L E O N   ColdFire C file                                *
 **********************************************************************
 * Project work template for sample-based audio input and output      *
 * Based on the example dspthru by Soundart                           *
 * Hannu Pulakka, March 2006, February 2007                           *
 * Modified by Antti Pakarinen, February, 2012		 	      * 	
 *	(Panel input and communication routines) 		      *
 **********************************************************************/

#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <rtems.h>
#include <midishare.h>
#include <chameleon.h>

#include "dsp/dsp_code.h"

#define	KEYPAD_EVENT	4
#define ENCODER_UP	5
#define ENCODER_DOWN	6

#define MIDI_KEY_ON	7
#define MIDI_KEY_OFF	8

// Required definitions for a Chameleon application
/**********************************************************************/
#define WORKSPACE_SIZE	128*1024
rtems_unsigned32 rtems_workspace_size = WORKSPACE_SIZE;
rtems_unsigned32 rtems_workspace_start[WORKSPACE_SIZE];
/**********************************************************************/

// Handles of the panel and the DSP
int panel, dsp;


// This function is called if an unexpected error occurs
void Error(char *error)
{
    TRACE(error);
    exit(1);
}

// Show a data word on the LCD display
void show_data(rtems_signed32 data)
{
  char str[16];
  sprintf(str, "0x%06X", data);
  panel_out_lcd_print(panel, 1, 0, str);
}

//** DSP_write ********************************************************************
// 
// Description:	Function for writing commands and data to the DSP
//
// Parameters:  rtems_unsigned32 event 		
//			-type of the event that is to be forwarded to the DSP 
// 		rtems_signed32 data	
//			-data value to be sent, for example potentiometer position
//
// Returns: 	TRUE if successful
//
//*********************************************************************************

char DSP_write(rtems_unsigned32 event, rtems_unsigned32 data)
{
	
	switch(event)
	{
	case PANEL01_POT_VOLUME:
	        //First, the data is written to the HI08 port
	        if (!dsp_write_data(dsp, &data, 1))
	                Error("ERROR: cannot write data to DSP.\n");
	        //then, a command is sent to interrupt the DSP and execute the appropriate interrupt routine
	        if (!dsp_write_command(dsp, DSPP_VecHostCommandUpdateVolume/2, TRUE))
			Error("ERROR: cannot write command to DSP.\n");
		return 1;
	case PANEL01_POT_CTRL1:
	        if (!dsp_write_data(dsp, &data, 1))
	                Error("ERROR: cannot write data to DSP.\n");
	        if (!dsp_write_command(dsp, DSPP_VecHostCommandUpdateCTRL1/2, TRUE))
			Error("ERROR: cannot write command to DSP.\n");
		return 1;
	case PANEL01_POT_CTRL2:
	        if (!dsp_write_data(dsp, &data, 1))
	                Error("ERROR: cannot write data to DSP.\n");
	        if (!dsp_write_command(dsp, DSPP_VecHostCommandUpdateCTRL2/2, TRUE))
			Error("ERROR: cannot write command to DSP.\n");
		return 1;
	case PANEL01_POT_CTRL3:
	        if (!dsp_write_data(dsp, &data, 1))
	                Error("ERROR: cannot write data to DSP.\n");
	        if (!dsp_write_command(dsp, DSPP_VecHostCommandUpdateCTRL3/2, TRUE))
			Error("ERROR: cannot write command to DSP.\n");
	  	return 1;
	case KEYPAD_EVENT:
		if (!dsp_write_data(dsp, &data, 1))
	                Error("ERROR: cannot write data to DSP.\n");
	        if (!dsp_write_command(dsp, DSPP_VecHostCommandKeyEvent/2, TRUE))
			Error("ERROR: cannot write command to DSP.\n");
		return 1;
	case ENCODER_UP:
	        //No data written, just the command
	        if (!dsp_write_command(dsp, DSPP_VecHostCommandEncoderUp/2, TRUE))
			Error("ERROR: cannot write command to DSP.\n");
	  	return 1;
	case ENCODER_DOWN:
		//No data written, just the command
	        if (!dsp_write_command(dsp, DSPP_VecHostCommandEncoderDown/2, TRUE))
			Error("ERROR: cannot write command to DSP.\n");
	  	return 1;
	case MIDI_KEY_ON:
			if (!dsp_write_data(dsp, &data, 1))
				Error("ERROR: cannot write data to DSP.\n");
			if (!dsp_write_command(dsp, DSPP_VecHostCommandMidiKeyOn/2, TRUE))
				Error("ERROR: cannot write command to DSP.\n");
		return 1;
	case MIDI_KEY_OFF:
			if (!dsp_write_data(dsp, &data, 1))
				Error("ERROR: cannot write data to DSP.\n");
			if (!dsp_write_command(dsp, DSPP_VecHostCommandMidiKeyOff/2, TRUE))
				Error("ERROR: cannot write command to DSP.\n");
		return 1;

	default:
	
		TRACE("\nWrong dsp write source type!\n");
		return 0;
	}
}


// Initialization of the panel and the DSP
void initialize()
{
    // Initialize panel and DSP
    panel = panel_init();
    if (!panel)
        Error("ERROR: cannot access the panel.\n");

    dsp = dsp_init(1, dspCode);
    if (!dsp)
        Error("ERROR: cannot access the DSP.\n");

    panel_out_lcd_print(panel, 0, 0, "digimoog");
}

// Panel task: interaction with the Chameleon panel
static rtems_task panel_task(rtems_task_argument argument)
{
    static rtems_signed32 volume_table[128];
    static rtems_signed32 linear_table[128];
    rtems_unsigned32  	key_bits;
    rtems_unsigned32	dummy=0xFFFFFFFF;
    rtems_unsigned8 	potentiometer;
    rtems_unsigned8 	encoder;
    rtems_signed8	increment;
    char		text[17];
    
    rtems_unsigned8 value;
    int i;
    float dB;


    TRACE("Project work template for sample-based audio input and output\n");

    // Precalculate gain values for different volume settings
    for (i=0; i<128 ;i++) {
    	if (i < 27)
            dB = -90.0 + (float) 40.0*i/27.0;
        else
            dB = -50.0 + (float) 50.0*(i-27)/100.0;
        volume_table[i] = float_to_fix_round(pow(10.0, dB/20.0));
    }
    volume_table[0] = 0;
    
    // Precalculate a linear table to scale the potentiometer values linearily between 0..~1
    for (i=1; i<128 ;i++) 
    {
    	linear_table[i]=float_to_fix_round((float)i/127.0);	
    }
	
    // Main loop
    while (TRUE) 
    {

        // *** Write your panel interaction code here ***
	//Poll for panel events
        if (!panel_in_new_event(panel, TRUE))
        	Error("ERROR: unexpected exit waiting new panel event.\n");
        if (panel_in_potentiometer(panel, &potentiometer, &value)) 
        {
		switch (potentiometer)
		{
	             	case PANEL01_POT_VOLUME:	
	                	DSP_write(PANEL01_POT_VOLUME,volume_table[value]);
			       	panel_out_lcd_print(panel, 0, 0, "Volume:         ");
			       	break;
	                case PANEL01_POT_CTRL1:		
	                    	DSP_write(PANEL01_POT_CTRL1,linear_table[value]);
			    	panel_out_lcd_print(panel, 0, 0, "Ctrl1:          ");
			       	break;
	                case PANEL01_POT_CTRL2:		
                	    	DSP_write(PANEL01_POT_CTRL2,linear_table[value]);
                	    	panel_out_lcd_print(panel, 0, 0, "Ctrl2:          ");
			       	break;
		      	case PANEL01_POT_CTRL3:		
	                    	DSP_write(PANEL01_POT_CTRL3,linear_table[value]);
	                	panel_out_lcd_print(panel, 0, 0, "Ctrl3:          ");
			       	break;
			
	                default:
	                	break;
        	}
                       
        }
        else if (panel_in_keypad(panel, &key_bits))
	{
	
		key_bits>>=8;	//NOTE! shift 8 bits to fit in 24bits in the dsp
		DSP_write(KEYPAD_EVENT,key_bits);
		panel_out_lcd_print(panel, 0, 0, "Keypad:         ");
			
	}
	else if (panel_in_encoder(panel, &encoder, &increment))
	{
		sprintf(text, "Encoder: %+3d ", increment);
		if(increment>0)
			DSP_write(ENCODER_UP,dummy);
		else
			DSP_write(ENCODER_DOWN,dummy);	
		panel_out_lcd_print(panel, 0, 0, text);
		panel_out_lcd_print(panel, 1, 0, "                ");
		
	}

	
    }

    panel_exit(panel);
    rtems_task_delete(RTEMS_SELF);
}

// Create and start the panel task that runs the function panel_task
rtems_boolean create_panel_task(void)
{
    rtems_id task_id;
    rtems_status_code status;

    status = rtems_task_create(rtems_build_name('T', 'H', 'R', 'U'),
                               50,
                               RTEMS_MINIMUM_STACK_SIZE,
                               RTEMS_DEFAULT_MODES,
                               RTEMS_DEFAULT_ATTRIBUTES,
                               &task_id);
    if (status != RTEMS_SUCCESSFUL) {
        TRACE("ERROR: cannot create panel_task.\n");
        return FALSE;
    }

    status = rtems_task_start(task_id, panel_task, 0);
    if (status != RTEMS_SUCCESSFUL) {
        TRACE("ERROR: cannot start panel_task.\n");
        return FALSE;
    }

    return TRUE;
}

#define EVENT_MIDI RTEMS_EVENT_1

static void receive_alarm(short ref)
{
	rtems_event_send((rtems_id) MidiGetInfo(ref), EVENT_MIDI);
}

// Midi task: receive midi events from MidiShare and send to dsp
static rtems_task midi_task(rtems_task_argument ignored)
{
	MidiEvPtr		ev;
	rtems_event_set		pending;
	rtems_status_code	status;
	rtems_id		task_id;
	short			ref_midi;

	ref_midi = MidiOpen("Synth");
	if (ref_midi < 0)
	{
		TRACE("ERROR: cannot open MidiShare.\n");
		rtems_task_delete(RTEMS_SELF);
	}

	rtems_task_ident(RTEMS_SELF, 0, &task_id);

	MidiSetInfo(ref_midi, (void *) task_id);
	MidiSetRcvAlarm(ref_midi, receive_alarm);

	MidiConnect(0, ref_midi, TRUE);

	while (TRUE)
	{
		status = rtems_event_receive(
			EVENT_MIDI,
			RTEMS_WAIT | RTEMS_EVENT_ANY,
			RTEMS_NO_TIMEOUT,
			&pending
		);
		if (status != RTEMS_SUCCESSFUL)
			break;

		ev = NULL;
		while (MidiCountEvs(ref_midi))
		{
			if (ev)
				MidiFreeEv(ev);

			ev = MidiGetEv(ref_midi);
		}

		if (ev)
		{
			if (EvType(ev) == typeKeyOn)
				DSP_write(MIDI_KEY_ON, MidiGetField(ev, 0));
			else if (EvType(ev) == typeKeyOff)
				DSP_write(MIDI_KEY_OFF, MidiGetField(ev, 0));
		}
	}

	MidiConnect(0, ref_midi, FALSE);

	MidiClose(ref_midi);

	rtems_task_delete(RTEMS_SELF);
}

// Create and start the midi task that runs the function midi_task
rtems_boolean create_midi_task(void)
{
  rtems_id task_id;
  rtems_status_code status;

  status = rtems_task_create(
    rtems_build_name('T', 'M', 'I', 'D'),
    50,
    RTEMS_MINIMUM_STACK_SIZE,
    RTEMS_DEFAULT_MODES,
    RTEMS_DEFAULT_ATTRIBUTES,
    &task_id
  );
  if (status != RTEMS_SUCCESSFUL) {
    TRACE("ERROR: cannot create midi_task.\n");
    return FALSE;
  }
  status = rtems_task_start(task_id, midi_task, 0);
  if (status != RTEMS_SUCCESSFUL) {
    TRACE("ERROR: cannot start midi_task.\n");
    return FALSE;
  }
  return TRUE;
}

// Read task: read data from the DSP
static rtems_task read_task(rtems_task_argument ignored)
{
  rtems_signed32 data;
  rtems_boolean res;
  
  while (TRUE) {
    res = dsp_read_data(dsp, &data, 1);
    if (res) {
      data &= 0x00FFFFFF;	//clear the sign extension
      show_data(data);

      // *** You can implement your own data handling here ***

    }
  }

  rtems_task_delete(RTEMS_SELF);
}

// Create and start the read task that runs the function read_task
rtems_boolean create_read_task(void)
{
  rtems_id task_id;
  rtems_status_code status;

  status = rtems_task_create(
    rtems_build_name('T', 'R', 'E', 'A'),
    50,
    RTEMS_MINIMUM_STACK_SIZE,
    RTEMS_DEFAULT_MODES,
    RTEMS_DEFAULT_ATTRIBUTES,
    &task_id
  );
  if (status != RTEMS_SUCCESSFUL) {
    TRACE("ERROR: cannot create read_task.\n");
    return FALSE;
  }
  status = rtems_task_start(task_id, read_task, 0);
  if (status != RTEMS_SUCCESSFUL) {
    TRACE("ERROR: cannot start read_task.\n");
    return FALSE;
  }
  return TRUE;
}

// The main function that is called when the application is started
rtems_task rtems_main(rtems_task_argument ignored)
{
    initialize();
    create_panel_task();
    create_midi_task();
    create_read_task();
    rtems_task_delete(RTEMS_SELF);
}
