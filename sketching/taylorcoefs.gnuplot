# period or something, dt looks too much like a differential
p = 1 / 48000.0
# shorthand coefficient
k = 2 * pi * p
# lowpass filter coefficient for function f
c(f) = k*f / (k*f + 1)
# 1st derivative
dc(f) = k / (k*f + 1)**2
# 2nd derivative
ddc(f) = -2*k**2 / (k*f + 1)**3
# taylor approximations for c(f) around point a
tayl(f, a)  = c(a) + dc(a) * (f-a)
tayl2(f, a) = c(a) + dc(a) * (f-a) + ddc(a)/2 * (f-a)**2
# inverse of c(f) for computing the error of filtered frequency based on c
ffromc(c) = 1/k * c/(1-c)

fc=900

max(x,y) = x > y ? x : y
set xrange [max(100, fc-2000):fc+2000]

plot \
c(x) title 'coef', \
tayl(x, fc) title 'taylor1st', \
(ffromc(tayl(x, fc)) - x) / x title '1st relative error in f', \
tayl2(x, fc) title 'taylor2st', \
(ffromc(tayl2(x, fc)) - x) / x title '2nd relative error in f'
