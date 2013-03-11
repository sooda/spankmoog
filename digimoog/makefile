################################################################################
# C H A M E L E O N  Main makefile                                             #
################################################################################
# Copyright (C) 2001-2003 Soundart                                             #
# www.soundart-hot.com                                                         #
# support@soundart-hot.com                                                     #
################################################################################

APP    := digimoog.elf
OUTDIR := myprojects/digimoog

include /Chameleon.sdk/make/main.mak

dsp/dsp_code.h::
	$(call make, ./dsp)
