#include <stdio.h>

#define BITMASK 0xffffffff
#define BITONE  0x7fffffff

int main() {
	int rate = 48000;
	int counter = -BITONE;
	int tick = 440.0 / (rate/2.0) * BITONE; // freq = tick * rate/2, tick = freq / (rate/2)
	int comp = 0;
	int out = -1;

	FILE* fhs = fopen("saw.out", "wb");
	FILE* fhp = fopen("pls.out", "wb");
	for (int x = 0; x < rate; x++) { // a second
		short cnts = 0x7fff * ((float)counter / BITONE);
		short outs = 0x7fff * out;
		printf("%f\n", (float)counter / BITONE);
		fwrite(&cnts, 1, sizeof(cnts), fhs);
		fwrite(&outs, 1, sizeof(outs), fhp);

		int prev = comp - counter;
		counter += tick;
		int curr = comp - counter;
		if ((curr ^ prev) & 0x80000000)
			out = -out;
	}

}
