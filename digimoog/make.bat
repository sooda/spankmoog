@REM ***************************************************************************
@REM * C H A M E L E O N    S. D. K.                                           *
@REM ***************************************************************************
@REM *  $Archive:: /Chameleon.sdk/src/examples/hello/make.bat                  $
@REM *     $Date:: 18/02/02 11:53                                              $
@REM * $Revision:: 5                                                           $
@REM * ------------------------------------------------------------------------*
@REM * This file is part of the Chameleon Software Development Kit             *
@REM *                                                                         *
@REM * Copyright (C) 2001-2002 Soundart                                        *
@REM * www.soundart-hot.com                                                    *
@REM * support@soundart-hot.com                                                *
@REM ***************************************************************************

del dsp\dsp_code.h
"c:\Program Files (x86)\Chameleon.sdk\bin\coldfire\make" -r -R -s %1 %2 %3
