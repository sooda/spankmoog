#!/usr/bin/python3
from math import exp

# adsr is a combination of lowpasses
# http://www.synthesizers.com/q109.html
T = 0.1
fs = 48000
y = 0
g = 1 - exp(-1 / (T * fs))
# RC = 1 / (2*pi*fc)
# g = dt / (RC + dt)
x = 1
for i in range(int(2 * T * 48000)):
	y = g * x + (1 - g) * y
	#y += g * (x - y)
	print("%f %f" % (i / 48000, y))
