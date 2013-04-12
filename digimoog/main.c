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
#include <string.h>
#include <rtems.h>
#include <midishare.h>
#include <chameleon.h>

#include "dsp/dsp_code.h"

#include "seq.h"


// Required definitions for a Chameleon application
/**********************************************************************/
#define WORKSPACE_SIZE	128*1024
rtems_unsigned32 rtems_workspace_size = WORKSPACE_SIZE;
rtems_unsigned32 rtems_workspace_start[WORKSPACE_SIZE];
/**********************************************************************/

// Handles of the panel and the DSP
int panel, dsp;

volatile int seqtick, seqevs, seqenabled;

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

static void DSP_write_cmd(rtems_unsigned32 vecnum)
{
	if (!dsp_write_command(dsp, vecnum / 2, TRUE))
		Error("ERROR: cannot write command to DSP.\n");
}

static void DSP_write_cmd_data(rtems_unsigned32 vecnum, rtems_unsigned32 data)
{
	if (!dsp_write_data(dsp, &data, 1))
		Error("ERROR: cannot write data to DSP.\n");
	DSP_write_cmd(vecnum);
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

static rtems_unsigned32 lowpass_pot(rtems_unsigned32 pot) {
	static const float dt = 1.0 / 48000;
	static const float pi = 3.14159;

	float freq = (float)pot / 0xffffff * 16000.0;
	float c = (dt * 2 * pi * freq) / (dt * 2 * pi * freq + 1);
	return c * 0x7fffff;
}

static void synth_note_off(int notenum) {
	DSP_write_cmd_data(DSPP_VecHostCommandMidiKeyOff, notenum);
	if (seqenabled)
		seqevs += seq_add_event(seqtick, 0, SEQ_EVTYPE_KEYOFF, notenum);
}
static void synth_note_on(int notenum) {
	DSP_write_cmd_data(DSPP_VecHostCommandMidiKeyOn, notenum);
	if (seqenabled)
		seqevs += seq_add_event(seqtick, 0, SEQ_EVTYPE_KEYON, notenum);
}

// Panel task: interaction with the Chameleon panel
static rtems_task panel_task(rtems_task_argument argument)
{
	static rtems_signed32	volume_table[128];
	static rtems_signed32	linear_table[128];
	rtems_unsigned32	key_bits, key_bits_prev, encoval;
	rtems_unsigned8 	potentiometer;
	rtems_unsigned8 	encoder;
	rtems_signed8		increment;
	char			text[17];

	rtems_unsigned8 value;
	int i;
	float dB;

	TRACE("digimoog");

	// Precalculate gain values for different volume settings
	for (i = 0; i < 128; i++) {
		if (i < 27)
			dB = -90.0 + (float)40.0 * i/27.0;
		else
			dB = -50.0 + (float)50.0 * (i-27)/100.0;
		volume_table[i] = float_to_fix_round(pow(10.0, dB/20.0));
	}
	volume_table[0] = 0;

	// Precalculate a linear table to scale the potentiometer values linearily between 0..~1
	for (i = 1; i < 128; i++) {
		linear_table[i]=float_to_fix_round((float)i/127.0);
	}

	key_bits_prev = 0;
	encoval = 0;

	// Main loop
	while (TRUE) {
		//Poll for panel events
		if (!panel_in_new_event(panel, TRUE))
			Error("ERROR: unexpected exit waiting new panel event.\n");

		if (panel_in_potentiometer(panel, &potentiometer, &value)) {
			switch (potentiometer)
			{
			case PANEL01_POT_VOLUME:
				DSP_write_cmd_data(DSPP_VecHostCommandUpdateVolume, volume_table[value]);
				panel_out_lcd_print(panel, 0, 0, "Volume:         ");
				break;
			case PANEL01_POT_CTRL1:
				DSP_write_cmd_data(DSPP_VecHostCommandUpdateCTRL1, lowpass_pot(volume_table[value]));
				panel_out_lcd_print(panel, 0, 0, "Ctrl1:          ");
				break;
			case PANEL01_POT_CTRL2:
				DSP_write_cmd_data(DSPP_VecHostCommandUpdateCTRL2, linear_table[value]);
				panel_out_lcd_print(panel, 0, 0, "Ctrl2:          ");
				break;
			case PANEL01_POT_CTRL3:
				DSP_write_cmd_data(DSPP_VecHostCommandUpdateCTRL3, linear_table[value]);
				panel_out_lcd_print(panel, 0, 0, "Ctrl3:          ");
				break;
			default:
				break;
			}
		} else if (panel_in_keypad(panel, &key_bits)) {
			// key_diff should only contain one bit here
			rtems_unsigned32 key_diff = key_bits ^ key_bits_prev, key = 0;
			key_bits_prev = key_bits;
			switch (key_diff) {
				case 0x80000000: key = 0; break; // value down
				case 0x40000000: key = 1; break; // param down
				case 0x20000000: key = 2; break; // value up
				case 0x10000000: key = 3; break; // param up
				case 0x08000000: key = 4; break; // page down
				case 0x04000000: key = 5; break; // group down
				case 0x02000000: key = 6; break; // page up
				case 0x01000000: key = 7; break; // group up
				case 0x00080000: key = 8; break; // part down
				case 0x00040000: key = 9; break; // shift
				case 0x00020000: key = 10; break; // part up
				case 0x00010000: key = 11; break; // edit
			}
			if (key == 11) {
				seq_init();
				seqevs = 0;
				DSP_write_cmd(DSPP_VecHostCommandPanic);
			} else if (key == 9) {
				if (key_bits)
					seqenabled ^= 1;
			} else {
				key += 12 * encoval;
				if (key_bits)
					synth_note_on(key);
				else
					synth_note_off(key);
			}
		} else if (panel_in_encoder(panel, &encoder, &increment)) {
			encoval += increment;
#if 0
			sprintf(text, "Encoder: %+3d ", increment);
			if(increment > 0)
				DSP_write_cmd(DSPP_VecHostCommandEncoderUp);
			else
				DSP_write_cmd(DSPP_VecHostCommandEncoderDown);
			panel_out_lcd_print(panel, 0, 0, text);
			panel_out_lcd_print(panel, 1, 0, "                ");
#endif
		}
	}

	panel_exit(panel);
	rtems_task_delete(RTEMS_SELF);
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
			if (EvType(ev) == typeKeyOff || (EvType(ev) == typeKeyOn && Vel(ev) == 0)) {
				synth_note_off(Pitch(ev));
			} else if (EvType(ev) == typeKeyOn) {
				synth_note_on(Pitch(ev));
			}
		}
	}

	MidiConnect(0, ref_midi, FALSE);

	MidiClose(ref_midi);

	rtems_task_delete(RTEMS_SELF);
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

static rtems_task seq_task(rtems_task_argument ignored) {
	int bpm = 4;
	rtems_interval secticks, period;
	struct seqevent* ev;
	char text[20];
	int n;

	rtems_clock_get(RTEMS_CLOCK_GET_TICKS_PER_SECOND, &secticks);
	period = secticks / bpm;

	seq_init();

	while (TRUE) {
		panel_out_led(panel, PANEL01_LED_EDIT | (seqenabled ? PANEL01_LED_SHIFT : 0));
		ev = seq_events_at(seqtick);
		n = 0;
		while (ev) {
			switch (ev->type) {
			case SEQ_EVTYPE_KEYON:
				DSP_write_cmd_data(DSPP_VecHostCommandMidiKeyOn, ev->param);
				break;
			case SEQ_EVTYPE_KEYOFF:
				DSP_write_cmd_data(DSPP_VecHostCommandMidiKeyOff, ev->param);
				break;
			}
			ev = ev->next;
			n++;
		}
		sprintf(text, "%x %x %x_", seqtick & 15, n, seqevs);
		panel_out_lcd_print(panel, 0, 0, text);
		strcat(text,"\n");
		TRACE(text);

		seqtick++;
		rtems_task_wake_after(period/2);
		panel_out_led(panel, seqenabled ? PANEL01_LED_SHIFT : 0);
		rtems_task_wake_after(period/2);
	}

	rtems_task_delete(RTEMS_SELF);
}
rtems_boolean create_task(rtems_task (*task)(rtems_task_argument), const char *name) {
	rtems_id task_id;
	rtems_status_code status;

	status = rtems_task_create(
			rtems_build_name(name[0], name[1], name[2], name[3]),
			50,
			RTEMS_MINIMUM_STACK_SIZE,
			RTEMS_DEFAULT_MODES,
			RTEMS_DEFAULT_ATTRIBUTES,
			&task_id
			);
	if (status != RTEMS_SUCCESSFUL) {
		TRACE("ERROR: cannot create "); TRACE(name); TRACE("seq_task.\n");
		return FALSE;
	}
	status = rtems_task_start(task_id, task, 0);
	if (status != RTEMS_SUCCESSFUL) {
		TRACE("ERROR: cannot start "); TRACE(name); TRACE("seq_task.\n");
		return FALSE;
	}
	return TRUE;
}

// The main function that is called when the application is started
rtems_task rtems_main(rtems_task_argument ignored)
{
    initialize();
	create_task(panel_task, "PANE");
	create_task(midi_task, "MIDI");
	create_task(read_task, "READ");
	create_task(seq_task, "SEQR");
    rtems_task_delete(RTEMS_SELF);
}
