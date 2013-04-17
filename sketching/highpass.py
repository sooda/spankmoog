#!/usr/bin/python3

fs = 48000
dt = 1 / fs
fc = 1000
y = 0
g = 1 / (1 + dt * fc)
# RC = 1 / (2*pi*fc)
# g = RC / (RC + dt)
x = 1
x0 = 0
for i in range(int(fs*0.01)):
	#y = g * y + g * (x - x0)
	y = g * (y + x - x0)
	x0 = x
	print("%f %f" % (i / fs, y))
