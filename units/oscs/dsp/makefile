################################################################################
# C H A M E L E O N   DSP makefile                                             #
################################################################################
# Copyright (C) 2001-2003 Soundart                                             #
# www.soundart-hot.com                                                         #
# support@soundart-hot.com                                                     #
################################################################################

DSPAPP     := main.cld
OUTDIR     := myprojects/oscs/dsp
EXTRAGOALS := dsp_code.h

DSPDEPENDS := \
	dpw_coefs.asm \
	saw_ticks.asm \
	osc.asm oscinc.asm


include /Chameleon.sdk/make/maindsp.mak

dsp_code.h : $(DSPAPP)
	$(call cld2header, dspCode)
