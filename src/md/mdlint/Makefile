#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)Makefile	1.2	05/08/20 SMI"
#

TOP=../..

CFLAGS = -I$(TOP)/include
#LEX=env PATH=/pkg/gnu/bin:$$PATH flex
LIBS =

include $(TOP)/Makefile.master

SRCS=			\
	mdlint.c	\
	allocate.c	\
	warning.c	\
	fatal.c		\
	vfatal.c

OBJS=$(SRCS:.c=.o)

all :: mdlint

install :: $(PROTO_BIN)/mdlint

mdlint: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS) $(LIBS)

clean ::
	$(RM) $(OBJS)

clobber ::
	$(RM) mdlint
