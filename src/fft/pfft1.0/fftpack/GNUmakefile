#
# $Id$
#
#======================================================================
#
# DISCLAIMER
#
# This material was prepared as an account of work sponsored by an
# agency of the United States Government.  Neither the United States
# Government nor the United States Department of Energy, nor Battelle,
# nor any of their employees, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR
# ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY,
# COMPLETENESS, OR USEFULNESS OF ANY INFORMATION, APPARATUS, PRODUCT,
# SOFTWARE, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT
# INFRINGE PRIVATELY OWNED RIGHTS.
#
# ACKNOWLEDGMENT
#
# This software and its documentation were produced with Government
# support under Contract Number DE-AC06-76RLO-1830 awarded by the United
# States Department of Energy.  The Government retains a paid-up
# non-exclusive, irrevocable worldwide license to reproduce, prepare
# derivative works, perform publicly and display publicly by or for the
# Government, including the right to distribute to other Government
# contractors.
#
#======================================================================
#
#  -- PFFT routine (version 1.0) --
#     Pacific Northwest Laboratory
#     April 5, 1995
#
#======================================================================
#
# set FFTLIB = the library to link with for single processor 1-D FFT routines
# set FFTNAM = the name to define in CPP for compiling *.cpp files.
#              Used to generate correct calls to FFTLIB routines.

LIBRARY   = libpfft.a

IO_STYLE = FILE_IO
LIB_DEFINES = -D${IO_STYLE} -DIBM ${GENDEFS}

#CPP		= /usr/lib/cpp -P -C -D${COMM_PKG} -D${IO_STYLE} -DIBM ${GENDEFS}

OBJ_OPTIMIZE=	dcfftb.o scfftb.o  \
		dcfftf.o scfftf.o  \
		dcffti.o scffti.o  \
		dcftb1.o scftb1.o \
		dcftf1.o scftf1.o \
		dcfti1.o scfti1.o \
		dpssb.o  spssb.o  \
		dpssb2.o spssb2.o \
		dpssb3.o spssb3.o \
		dpssb4.o spssb4.o \
		dpssb5.o spssb5.o \
		dpssf.o  spssf.o  \
		dpssf2.o spssf2.o \
		dpssf3.o spssf3.o \
		dpssf4.o spssf4.o \
		dpssf5.o spssf5.o \
		drfftb.o srfftb.o  \
		drfftf.o srfftf.o  \
		drffti.o srffti.o  \
		drftb1.o srftb1.o \
		drftf1.o srftf1.o \
		drfti1.o srfti1.o \
		dradb2.o sradb2.o \
		dradb3.o sradb3.o \
		dradb4.o sradb4.o \
		dradb5.o sradb5.o \
		dradbg.o sradbg.o \
		dradf2.o sradf2.o \
		dradf3.o sradf3.o \
		dradf4.o sradf4.o \
		dradf5.o sradf5.o \
		dradfg.o sradfg.o 

include ../../../config/makefile.h
include $(CNFDIR)/makelib.h

