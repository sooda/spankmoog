#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <stdio.h>
#include <limits.h>
#include <math.h>

// samplerate 48khz
// ~21 microseconds between samples
// cpu 100MHz = 0.01 microseconds per instruction
// ~2083 instructions/sample

// TODO: time units
// TODO: status flags into bitfields
// TODO: fixedpoint
// TODO: instruments in memory X, states in memory Y to parallelize fetching
//
#define FIX(x) (int)((x) * INT_MAX)
#define SAMPLERATE 48000
#define DT (1.0f / SAMPLERATE)
#define M_PI 3.14159265358979323846


typedef int sample;

typedef struct AdsrParams {
	int attack, decay, sustain, release; // time units or coefficients what
} AdsrParams;

// TODO: instrument or channel here?
typedef struct Instrument {
	// TODO: separate functions needed or not? just one render()?
	sample (*oscfunc)(const struct Instrument*, void* state, int note);
	sample (*filtfunc)(const struct Instrument*, void* state, sample s);
	AdsrParams adsr;
	int volume;
	int midinum;
} Instrument;

typedef enum AdsrSection {
	ADSR_ATTACK,
	ADSR_DECAY,
	ADSR_SUSTAIN,
	ADSR_RELEASE,
	ADSR_OFF
} Adsrsection;

typedef struct AdsrState {
	int value;
	int time; // TODO: time_t?
	int currentcoef;
	enum AdsrSection section;
	int nexttime;
	int nextvalue;
} AdsrState;

typedef struct Channel {
	const Instrument* instr;
	int alive;
	AdsrState adsr;
	int volume;
	void* instrstate;
	int note;
} Channel;

int time; // TODO register
int  lowpass_juttu(int current, int next);


// shouldn't need to check alive bit - never called for dead voices (no zombie channels possible)
// FIXME: bloat
int adsr(const AdsrParams* params, AdsrState* state) {
	int out = state->value;
	// TODO: use time constant to precalc coefs, skip to next if value == zing
	// TODO: precalculate coefficients g = 1 - exp(1/(T*fs))
	// TODO: use linear ramp at attack stage?
	state->value = lowpass_juttu(state->currentcoef, state->nextvalue);
	if (++state->time >= state->nexttime) {
		switch (state->section) {
			case ADSR_ATTACK:
				state->currentcoef = params->decay;
				state->nextvalue = params->sustain;
				break;
			case ADSR_DECAY:
				state->currentcoef = FIX(1);
				state->value = params->sustain; // TODO: do i need this when it has went there already
				break;
			case ADSR_SUSTAIN:
				state->currentcoef = params->release;
				break;
			case ADSR_RELEASE:
				break;
			default:
				assert(0); // no zombie channels
		}
		state->nexttime = params->nexttime[state->section];
		state->section++;
	}
	return out;
}
int adsr_init(const AdsrParams* params, AdsrState* state) {
	memset(state, 0, sizeof(*state));
	state->currentcoef = params->attack;
}

float midifreq(int note) {
	return (1 << ((note - 69) / 12)) * 440.0;
}

// oscillators are always running and never change the frequency
// TODO: code this in a dsp way
typedef struct SinState {
} SinState;
sample osc_sin(SinState* state, int note) {
}

// sample osc_tri(int time, int note);
// sample osc_saw(int time, int note);
// sample osc_pulse(int time, int note);
// sample osc_rnd(RandomState* state);


// lowpass filter coefficients may change over time due to lfo's

typedef struct LowpassParams {
	int freq;
	int coef; // here for initialization
} LowpassParams;

typedef struct LowpassState {
	int coef; // this here for lfos and stuff, init'd at the beginning of the note
	sample prev;
} LowpassState;

typedef struct BassState {
	LowpassState lp;
	SinState osc;
	int lfotime; // since note start
} BassState;

typedef struct Bass {
	Instrument base;
	LowpassParams lp;
	int lfofreq; // should be pretty constant
} Bass;

// TODO: inline these if needed
sample lowpass(LowpassState* state, sample x) {
	return state->prev + state->coef * (x - state->prev);
}
#define LOWPASS_COEF(freq) (DT / (freq / (2 * M_PI) + DT))
// TODO: function or not? get rid of division
#define lowpass_coef(freq) LOWPASS_COEF(freq)

sample lfo_iexp(int time, int freq) {
	return exp(-time * freq);
}

sample bassosc(const Bass* instru, BassState* state, int note) {
	return osc_sin(&state->osc, note);
}

sample bassfilt(const Bass* instru, BassState* state, sample s) {
	const int lowfreq = 100; // TODO: this also to the instrument? lp low freq?
	int lfo = lfo_iexp(state->lfotime, instru->lfofreq);
	state->lfotime++; // TODO: decide units
	state->lp.coef = lowpass_coef(lowfreq + lfo * (instru->lp.freq - lowfreq));
	return lowpass(&state->lp, s);
}

#define NUM_CHANNELS 8
static Channel channels[NUM_CHANNELS];
// TODO: INSTRUMENT(x, y) --> { (funccast)x,  etc}
// blah, should be constants
Bass bass = {{bassosc, bassfilt, {FIX(0.05), FIX(0.5), FIX(0.8), FIX(0.1)}}, 440, LOWPASS_COEF(440)}, 1};
Instrument* instruments = {
	(Instrument*)&bass
};
int mastervol;

sample eval_channel(Channel* ch) {
	const Instrument* instr = ch->instr;
	sample a = instr->oscfunc(instr, ch->instrstate, ch->note);
	sample b = instr->filtfunc(instr, ch->instrstate, a);
	sample c = adsr(&instr->adsr, &ch->adsr) * b;
	if (ch->adsr.section == ADSR_OFF)
		ch->alive = 0;
	return ch->volume * c;
}

sample render() {
	sample out = 0;
	for (int i = 0; i < NUM_CHANNELS; i++) {
		if (channels[i].alive)
			out += eval_channel(&channels[i]);
	}
	return out * mastervol;
}
Instrument* instruobj_by_num(int instrument);

int note_on(int midinote, int instrument) {
	for (int i = 0; i < NUM_CHANNELS; i++) {
		Channel* ch = &channels[i];
		if (!ch->alive) {
			ch->instr = instruobj_by_num(instrument);
			memset(ch->instrstate, 0, sizeof(ch->instrstate));
			adsr_init(&ch->instr->adsr, &ch->adsr);
			ch->note = midinote;
			ch->alive = 1;
			ch->volume = ch->instr->volume;
			return 0;
		}
	}
	return -1;
}
int note_off(int midinote, int instrument) {
	for (int i = 0; i < NUM_CHANNELS; i++) {
		Channel* ch = &channels[i];
		if (ch->alive
				&& ch->instr->midinum == instrument
				&& ch->note == midinote) {
			ch->adsr.section = ADSR_OFF;
			return 0;
		}
	}
	return -1;
}

// samples to play
#define MUSICDURATION 48000

int main() {
	note_on(100, 0);
	for (int i = 0; i < MUSICDURATION; i++) {
		sample s = render();
		printf("%d %d %d\n", i, s, s / 0x7fffffff);
	}
}
