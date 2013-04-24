/**********************************************************************
 * C H A M E L E O N   ColdFire C file                                *
 **********************************************************************
 * Digimoog project for Aalto ELEC S-89.3510 SPÄNK                    *
 * By Konsta and Nuutti Hölttä 2013                                   *
 * Based on:                                                          *
 * Project work template for sample-based audio input and output      *
 * Based on the example dspthru by Soundart                           *
 * Hannu Pulakka, March 2006, February 2007                           *
 * Modified by Antti Pakarinen, February, 2012		 	      * 	
 *	(Panel input and communication routines) 		      *
 **********************************************************************/

/* Usage:
 *
 * Edit key: sequencer event saving on/off
 * Shift key: clear the sequencer and kill all notes immediately
 * Part up/down: select midi channel to edit
 * Group up/down: map selected midi channel to a synth channel
 *
 */

#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <string.h>
#include <rtems.h>
#include <midishare.h>
#include <chameleon.h>

#include "dsp/dsp_code.h"

#include "seq.h"


#define RATE 48000
#define DT (1.0 / RATE)
#define PI 3.14159265
#define FILT_K (DT * 2 * PI)

enum Key {
	KEY_VALUE_DOWN,
	KEY_PARAM_DOWN,
	KEY_VALUE_UP,
	KEY_PARAM_UP,

	KEY_PAGE_DOWN,
	KEY_GROUP_DOWN,
	KEY_PAGE_UP,
	KEY_GROUP_UP,

	KEY_PART_DOWN,
	KEY_SHIFT,
	KEY_PART_UP,
	KEY_EDIT,
};

// number of keys that play a note instead of controlling something
#define NOTE_KEYS 1

// Required definitions for a Chameleon application
/**********************************************************************/
#define WORKSPACE_SIZE	128*1024
rtems_unsigned32 rtems_workspace_size = WORKSPACE_SIZE;
rtems_unsigned32 rtems_workspace_start[WORKSPACE_SIZE];
/**********************************************************************/

// Handles of the panel and the DSP
static int panel, dsp;

static volatile int seqtick, seqevs, seqenabled;
static rtems_unsigned32 encoval;

// midi channel to synth instrument mapping
// if the value is 0, all events to this channel are ignored
// otherwise, synth_idx = midichan_to_synth[midichan] - 1
// note that the program change events are not used for anything
// the keypad buttons work at channel 0
#define SYNTH_INSTRUS 7
#define MIDI_CHAN_MAP_SIZE 8
static int midichan_to_synth[MIDI_CHAN_MAP_SIZE];
static int midichanedit;

// pot to tunable mapping
// these in InstruTunables array in instruparams.asm
#define TUNABLES_SIZE (0xe + 1)
static int pot_to_tunable[3];
static int tunableedit;

// This function is called if an unexpected error occurs
static void Error(char *error) {
	TRACE(error);
	exit(1);
}

// Show a data word on the LCD display
static void show_data(rtems_signed32 data) {
	char str[9];
	sprintf(str, "%06X", data);
	panel_out_lcd_print(panel, 1, 0, str);
}

static char dbgbuf[32];

static void DSP_write_cmd(rtems_unsigned32 vecnum) {
	sprintf(dbgbuf, "DSP_write_cmd %d\n", vecnum); TRACE(dbgbuf);
	if (!dsp_write_command(dsp, vecnum / 2, TRUE))
		Error("ERROR: cannot write command to DSP.\n");
}

static void DSP_write_cmd_data(rtems_unsigned32 vecnum, rtems_unsigned32 data) {
	sprintf(dbgbuf, "DSP_write_cmd %d %d\n", vecnum, data); TRACE(dbgbuf);
	if (!dsp_write_data(dsp, &data, 1))
		Error("ERROR: cannot write data to DSP.\n");
	DSP_write_cmd(vecnum);
}

static void DSP_write_cmd_data2(rtems_unsigned32 vecnum, rtems_unsigned32 data1, rtems_unsigned32 data2) {
	sprintf(dbgbuf, "DSP_write_cmd_data2 %d %d %d\n", vecnum, data1, data2); TRACE(dbgbuf);
	if (!dsp_write_data(dsp, &data1, 1))
		Error("ERROR: cannot write data to DSP.\n");
	DSP_write_cmd_data(vecnum, data2);
}


// FIXME: cannot send three words, would get stuck (?!)
// hangs all threads, even the blinking led stops, wtf
static void DSP_write_cmd_data3(rtems_unsigned32 vecnum, rtems_unsigned32 data1, rtems_unsigned32 data2, rtems_unsigned32 data3) {
	rtems_unsigned32 juttu;
	sprintf(dbgbuf, "DSP_write_cmd_data3 %d %d %d\n", vecnum, data1, data2); TRACE(dbgbuf);
	juttu = float_to_fix_round(data3 / 127.0);
	DSP_write_cmd_data2(vecnum, data1, data2 | (juttu & 0xffff00));
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
	float freq = (float)pot / 0xffffff * 16000.0;
	float c = (FILT_K * freq) / (FILT_K * freq + 1);
	return c * 0x7fffff;
}

static rtems_unsigned32 lowpass_dif(rtems_unsigned32 pot) {
	float freq = (float)pot / 0xffffff * 16000.0;
	float c = FILT_K / ((FILT_K * freq + 1) * (FILT_K * freq + 1));
	c *= 1000; // max amplitude
	return c * 0x7fffff;
}

static rtems_unsigned32 multipole_pot(rtems_unsigned32 pot) {
	float freq = (float)pot / 0xffffff * 8000.0;
	float c = 2 * PI * freq / RATE;
	return c * 0x7fffff;
}

static rtems_unsigned32 hihpass_pot(rtems_unsigned32 pot) {
	float freq = (float)pot / 0xffffff * 16000.0;
	float c = 1.0 / (FILT_K * freq + 1);
	return c * 0x7fffff;
}

static rtems_unsigned32 adsr_time(rtems_unsigned32 pot) {
	float time_secs = (float)pot / 0xffffff * 0.5;
	float c = 1 - exp(-1.0 / (time_secs * RATE));
	return c * 0x7fffff;
}

static void synth_note_off(int notenum, int midichan) {
	if (midichan >= 0 && midichan < MIDI_CHAN_MAP_SIZE) {
		int synthinstru = midichan_to_synth[midichan] - 1;
		if (synthinstru != -1) {
			DSP_write_cmd_data2(DSPP_VecHostCommandMidiKeyOff, notenum, synthinstru);
			if (seqenabled)
				seqevs += seq_add_event(seqtick, synthinstru, SEQ_EVTYPE_KEYOFF, notenum);
		}
	}
}
static void synth_note_on(int notenum, int midichan, int velocity) {
	if (midichan >= 0 && midichan < MIDI_CHAN_MAP_SIZE) {
		int synthinstru = midichan_to_synth[midichan] - 1;
		if (synthinstru != -1) {
			DSP_write_cmd_data3(DSPP_VecHostCommandMidiKeyOn, notenum, synthinstru, velocity);
			if (seqenabled)
				seqevs += seq_add_event2(seqtick, synthinstru, SEQ_EVTYPE_KEYON, notenum, velocity);
		}
	}
}

static void keydown(enum Key key) {
	switch (key) {
	case KEY_SHIFT:
		seq_init();
		seqevs = 0;
		DSP_write_cmd(DSPP_VecHostCommandPanic);
		break;
	case KEY_EDIT:
		seqenabled ^= 1;
		break;
	case KEY_PART_UP:
		midichanedit = midichanedit == MIDI_CHAN_MAP_SIZE-1 ? 0 : midichanedit + 1;
		break;
	case KEY_PART_DOWN:
		midichanedit = midichanedit == 0 ? MIDI_CHAN_MAP_SIZE-1 : midichanedit - 1;
		break;
	case KEY_GROUP_UP:
		midichan_to_synth[midichanedit]++;
		if (midichan_to_synth[midichanedit] == SYNTH_INSTRUS + 1)
			midichan_to_synth[midichanedit] = 0;
		break;
	case KEY_GROUP_DOWN:
		midichan_to_synth[midichanedit]--;
		if (midichan_to_synth[midichanedit] == -1)
			midichan_to_synth[midichanedit] = SYNTH_INSTRUS;
		break;
	case KEY_PAGE_UP:
		tunableedit = tunableedit == 2 ? 0 : tunableedit + 1;
		break;
	case KEY_PAGE_DOWN:
		tunableedit = tunableedit == 0 ? 2 : tunableedit - 1;
		break;
	case KEY_PARAM_UP:
		pot_to_tunable[tunableedit]++;
		if (pot_to_tunable[tunableedit] == TUNABLES_SIZE+1)
			pot_to_tunable[tunableedit] = 0;
		break;
	case KEY_PARAM_DOWN:
		pot_to_tunable[tunableedit]--;
		if (pot_to_tunable[tunableedit] == -1)
			pot_to_tunable[tunableedit] = TUNABLES_SIZE;
		break;
	default:
		if (key < NOTE_KEYS)
			synth_note_on((int)key + NOTE_KEYS * encoval, 0, 50);
	}
}
static void keyup(enum Key key) {
	if (key < NOTE_KEYS)
		synth_note_off((int)key + NOTE_KEYS * encoval, 0);
}

static rtems_signed32	volume_table[128];
static rtems_signed32	linear_table[128];

void update_tunable(int i, int potvalue) {
	int tunable;
	rtems_unsigned32 sendval;

	tunable = pot_to_tunable[i];
	if (tunable != 0) {
		tunable -= 1;
		switch (tunable) {
			case 0x0:
			case 0x1:
			case 0x2: sendval = adsr_time(linear_table[potvalue]); break;
			case 0x3: sendval = lowpass_pot(volume_table[potvalue]); break;
			case 0x4: sendval = lowpass_pot(volume_table[potvalue]); break;
			case 0x5: sendval = linear_table[potvalue]; break;
			case 0x6:
			case 0x7:
			case 0x8: sendval = adsr_time(linear_table[potvalue]); break;
			case 0x9:
			case 0xa: sendval = linear_table[potvalue]; break;
			case 0xb: sendval = hihpass_pot(volume_table[potvalue]); break;
			case 0xc:
			case 0xd:
			case 0xe: sendval = multipole_pot(volume_table[potvalue]); break;
			default: Error("Bad tunable"); break;
		}

		DSP_write_cmd_data2(DSPP_VecHostCommandUpdateTunable, tunable, sendval);
	}
}

// Panel task: interaction with the Chameleon panel
static rtems_task panel_task(rtems_task_argument argument)
{
	rtems_unsigned32	key_bits, key_bits_prev;
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
				break;
			case PANEL01_POT_CTRL1:
				update_tunable(0, value);
				break;
			case PANEL01_POT_CTRL2:
				update_tunable(1, value);
				break;
			case PANEL01_POT_CTRL3:
				update_tunable(2, value);
				break;
			default:
				break;
			}
		} else if (panel_in_keypad(panel, &key_bits)) {
			rtems_unsigned32 key_diff = key_bits ^ key_bits_prev;
			rtems_unsigned32 mask = 0x80000000;
			int key = 0;

			key_bits_prev = key_bits;
			while (key_diff) {
				if (key_diff & mask) {
					// last 4 (8..11) are shifted by 4, move 12 -> 8 etc
					if (key_bits & mask)
						keydown(key < 8 ? key : key - 4);
					else
						keyup(key < 8 ? key : key - 4);
					key_diff ^= mask;
				}
				key++;
				mask >>= 1;
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
	char			debugmsg[32];

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

		while ((ev = MidiGetEv(ref_midi)) != NULL) {
			if (EvType(ev) == typeKeyOff || (EvType(ev) == typeKeyOn && Vel(ev) == 0)) {
				synth_note_off(Pitch(ev), Chan(ev));
			} else if (EvType(ev) == typeKeyOn) {
				synth_note_on(Pitch(ev), Chan(ev), Vel(ev));
			}
			sprintf(debugmsg, "MIDI:type=%d chan=%d key=%d vel=%d\n", EvType(ev), Chan(ev), Pitch(ev), Vel(ev));
			TRACE(debugmsg);
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
				DSP_write_cmd_data3(DSPP_VecHostCommandMidiKeyOn, ev->param1, ev->instrument, ev->param2);
				break;
			case SEQ_EVTYPE_KEYOFF:
				DSP_write_cmd_data2(DSPP_VecHostCommandMidiKeyOff, ev->param1, ev->instrument);
				break;
			}
			ev = ev->next;
			n++;
		}
		sprintf(text, "%xA%xB%xC%x 01234567", seqtick & 15, pot_to_tunable[0], pot_to_tunable[1], pot_to_tunable[2]);
		panel_out_lcd_print(panel, 0, 0, text);
		sprintf(text, "%d%d%d%d%d%d%d%d",
			midichan_to_synth[0],
			midichan_to_synth[1],
			midichan_to_synth[2],
			midichan_to_synth[3],
			midichan_to_synth[4],
			midichan_to_synth[5],
			midichan_to_synth[6],
			midichan_to_synth[7]
			);
		panel_out_lcd_print(panel, 1, 8, text);
		strcat(text,"\n");
		//TRACE(text);

		seqtick++;
		rtems_task_wake_after(period/2);
		panel_out_led(panel, seqenabled ? PANEL01_LED_SHIFT : 0);
		panel_out_lcd_print(panel, 0, 2 + 2 * tunableedit, " ");
		panel_out_lcd_print(panel, 1, 8 + midichanedit, " ");
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
