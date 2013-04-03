#!/usr/bin/python2

def midifreq(p):
	return pow(2, (p - 69) / 12.0) * 440

rate = 48e3
notes = range(128)
freqs = map(midifreq, notes)

coefs = [rate / (4 * freq * (1 - freq / rate))
		for freq in freqs]

ticks = [freq / (rate / 2)
		for freq in freqs]

open("dpw_coefs.asm", "w").write(
	"DpwCoefs: ; rate / (4 * freq * (1 - freq / rate)), midi notes 0..127\n" +
	"\n".join("\tdc\t%f/2048" % c for c in coefs) +
	"\n"
)

open("saw_ticks.asm", "w").write(
	"SawTicks: ; freq / (rate / 2), midi notes 0..127\n" +
	"\n".join("\tdc\t%f" % c for c in ticks) +
	"\n"
)
