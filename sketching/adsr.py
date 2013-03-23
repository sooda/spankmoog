#!/usr/bin/python3
from math import exp

T = 0.1
fs = 48000
y = 0
g = 1 - exp(-1 / (T * fs))
x = 1
for i in range(int(2 * T * 48000)):
	y = g * x + (1 - g) * y
	print("%f %f" % (i / 48000, y))
