/*
 * Small tool for prototyping ADSR figures
 * Outputs gnuplottable curves
 * Note that we use values larger than 1 so that the target value is reached in the time constant
 * Change CONSTSUSTAIN to experiment with constant sustain level or always-decaying release
 */

#include <stdio.h>
#include <math.h>

#define RATE 48000
#define CONSTSUSTAIN 1

int main() {
	const float t = 5000.0 / RATE;
	const float coeff = 1.0f - exp(-1.0f / (t * RATE)); // using same for a,d,r for simplicity
	const float targetf = 1.0f - exp(-1.0f); // ~0.63
	const float temppuf = 1.0f / targetf;
	const float topf = 1.0f * temppuf;
	const float sustainf = 0.2345f;
	// the thing goes 63% of start to target in the time constant T
	// thus, the target has to be adjusted a bit
	// tgt = start + (want - start) / 0.63
#if CONSTSUSTAIN
	float sust_target = 1.0f + (sustainf - 1.0f) * temppuf;
#endif
	float rel_target = sustainf + (0 - sustainf) * temppuf;

#define STATE_ATTACK 0
#define STATE_DECAY 1
#define STATE_SUSTAIN 2
#define STATE_RELEASE 3
#define STATE_KILLED 4
	int state = 0;
	float value = 0;
	int gatetime = 25000;
	for (int i = 0; i < RATE; i++) { // render one second
		int gate = i < gatetime;
		if (gate) { // key on (pressed)
			switch (state) {
			case STATE_ATTACK:
				value += coeff * (topf - value);
				if (value >= 1.0f) {
					value = 1.0f; // TODO: interpolation? maybe not so exact needed
					state = STATE_DECAY;
				}
				break;
			case STATE_DECAY:
#if CONSTSUSTAIN
				value += coeff * (sust_target - value); // stop at sustain stage exactly
				if (value <= sustainf) {
					value = sustainf;
					state = STATE_SUSTAIN;
				}
#else
				value += coeff * (sustainf - value); // never actually reach sustain but fade gradually
#endif
				break;
				// no change when in sustain state!
			default:
				break;
			}
		} else { // key off (released)
			switch (state) {
			case STATE_DECAY:
#if !CONSTSUSTAIN
				// release from current level, we're never at the sustain level
				rel_target = value + (0.0f - value) * temppuf;
#endif
				// fall through
			case STATE_SUSTAIN:
				state = STATE_RELEASE;
				// fall through
			case STATE_RELEASE:
				value += coeff * (rel_target - value);
				if (value < 0) {
					value = 0;
					state = STATE_KILLED;
				}
				break;
			// nothing happens when killed
			default:
				break;
			}
		}
		printf("%d %f\n", i, value);
	}
}
