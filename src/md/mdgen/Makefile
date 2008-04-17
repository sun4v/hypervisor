#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)Makefile	1.6	05/08/20 SMI"
#

TOP=../..

CFLAGS = -I$(TOP)/include $(DEBUG)
LEX=env PATH=/pkg/gnu/bin:$$PATH flex
#LIBS = -L../lib -ldtnode
LIBS =
DEBUG=-g

include $(TOP)/Makefile.master
CC=cc

SRCS=			\
	mdmain.c	\
	mdparse.c	\
	mdlex.c		\
	output_bin.c	\
	output_text.c	\
	output_dot.c	\
	allocate.c	\
	warning.c	\
	fatal.c		\
	vfatal.c

OBJS=$(SRCS:.c=.o)

all :: mdgen

install :: $(PROTO_BIN)/mdgen

mdgen: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS) $(LIBS)

mdlex.c: mdlex.l
	$(LEX) $(LFLAGS) -Pmdlex -o$@ $<

mdlex.o := CFLAGS += -erroff=E_STATEMENT_NOT_REACHED

clean ::
	$(RM) mdlex.c $(OBJS)

clobber ::
	$(RM) mdgen
