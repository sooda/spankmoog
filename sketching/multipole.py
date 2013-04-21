from math import exp, pi, sin

class filt(object):
	def __init__(self, fc):
		self.x0 = 0
		self.y0 = 0
		w = 2 * pi * fc / fs
		self.g = 0.9892 * w - 0.4342 * w**2 + 0.1381 * w**3 - 0.0202 * w**4

	def __call__(self, x1):
		a = (x1 + 0.3 * self.x0) / 1.3
		self.x0 = x1
		self.y0 += self.g * (a - self.y0) # y = g * a + (1 - g) * y
		return self.y0

class filt4(object):
	def __init__(self, a, b, c, d, e, fc, c_res):
		w = 2 * pi * fc / fs # TODO: w argument, not fc
		self.filts = [filt(fc), filt(fc), filt(fc), filt(fc)]
		self.coefs = [a, b, c, d, e]
		self.mem = 0
		self.g_comp = 0.5
		self.g_res = c_res * (1.0029 + 0.0526 * w - 0.0926 * w**2 + 0.0218 * w**3)
		
	def __call__(self, x1):
		x = x1 - 4 * self.g_res * (self.mem - self.g_comp * x1)
		taps = []
		taps.append(self.coefs[0] * x)
		x = self.filts[0](x)
		taps.append(self.coefs[1] * x)
		x = self.filts[1](x)
		taps.append(self.coefs[2] * x)
		x = self.filts[2](x)
		taps.append(self.coefs[3] * x)
		x = self.filts[3](x)
		taps.append(self.coefs[4] * x)
		self.mem = x
		return sum(taps)

class lp4(filt4):
	def __init__(self, fc):
		filt4.__init__(self, 0, 0, 0, 0, 1, fc, 0.5)

class lp2(filt4):
	def __init__(self, fc):
		filt4.__init__(self, 0, 0, 1, 0, 0, fc, 0.5)

class hp4(filt4):
	def __init__(self, fc):
		filt4.__init__(self, 1, -4, 6, -4, 1, fc, 0.5)

class hp2(filt4):
	def __init__(self, fc):
		filt4.__init__(self, 1, -2, 1, -0, 0, fc, 0.5)

def inp(t):
	return sin(2 * pi * 500 * t)

T = 0.1
fs = 48000
fc = 100

filts = [lp4(fc), lp2(fc), hp4(fc), hp2(fc)]
for i in range(48000):
	t = i / 48000.0
	print " ".join(map(str, [t] + [f(inp(t)) for f in filts]))
