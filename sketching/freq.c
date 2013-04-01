#include <stdio.h>

#define BITMASK 0xffffffff
#define BITONE  0x7fffffff

int main() {
	int rate = 48000;
	int counter = -BITONE;
	float freq = 440;
	int tick = freq / (rate/2.0) * BITONE; // freq = tick * rate/2, tick = freq / (rate/2)
	int pulsshift = 1.0*BITONE;
	int out = BITONE;
	int laststate = counter;

	FILE* fhs = fopen("saw.out", "wb");
	FILE* fhp = fopen("pls.out", "wb");
	FILE* fhd = fopen("dpw.out", "wb");
	for (int x = 0; x < rate; x++) { // a second
		short cnts = 0x7fff * ((float)counter / BITONE);
		short outs = 0x7fff * out;
		int sq = (int)(((long)counter * (long)counter) >> 32UL);
		int filtd = sq - laststate;
		laststate = sq;
		float c = 2*rate / (4 * freq * (1 - freq / rate)); // FIXME: why 2*?
		printf("%d %f %f %f\n", x, (float)counter / BITONE, (float)out / BITONE, (float)filtd / BITONE * c);
		fwrite(&cnts, 1, sizeof(cnts), fhs);
		fwrite(&outs, 1, sizeof(outs), fhp);
		short dpw = 0x7fff * (float)filtd / BITONE * c;
		fwrite(&dpw, 1, sizeof(dpw), fhd);

		counter += tick;
		int next = counter + pulsshift;
		int asd = (counter >> 1) + 0.5*BITONE; // scale to 0..1
		int bsd = (next >> 1) + 0.5*BITONE;
		out = bsd-asd ;//- counter;
		out += BITONE-pulsshift/2;
	}

}
