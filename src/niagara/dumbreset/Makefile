#
# Copyright 2004 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)Makefile	1.4	05/11/04 SMI"
#

TOP=../..
include $(TOP)/Makefile.master

OPTIONS =
OPTIONS += -DDEBUG
OPTIONS += -DDEBUG_LEGION	# Legion-specific debugging aids
OPTIONS += -UCONFIG_SAS		# Compile without copies for PPG simulation
OPTIONS += $(EXTRA_OPTIONS)

CPPFLAGS = -I$(TOP)/include -I../hypervisor $(OPTIONS)
CFLAGS = -xarch=v9a
ASFLAGS = -xarch=v9v -D_ASM -P -xregsym=no $(CPPFLAGS)

S_SRCS = reset.s
RESET_OBJS = reset.o

all :: reset.bin

reset.bin: reset
	$(OBJCOPY) -O binary reset reset.bin

$(OBJS): offsets.h

reset: $(RESET_OBJS) mapfile
	$(LD) -o $@ -e start_reset -dn -z defs -M mapfile $(RESET_OBJS)

# This would work but only dumps the .text, nothing else
#	elfdump -N .text -w q.bin q

offsets.h: offsets.in
	@grep "^#" offsets.in > offsets.c
	$(CC) -xdebugformat=stabs $(CFLAGS) $(CPPFLAGS) -g -S -o offsets.s offsets.c
	@grep -v "^#" offsets.in > offsets.tmp
	$(STABS) -t genassym -m lp64 offsets.tmp < offsets.s > offsets.h
	@$(RM) offsets.c offsets.s offsets.tmp

# Source browsing
CSDIR	= .
CSDIRS	= . ../include
CSPATHS	= $(CSDIRS:%=$(CSDIR)/%)
CSINCS	= $(CSPATHS:%=-I%)
CSCOPE	= cscope
CTAGS	= ctags
CSFLAGS	= -b
CTFLAGS	= -wt

.PRECIOUS:	cscope.out

cscope.out: cscope.files FRC
	${CSCOPE} ${CSFLAGS}

cscope.files: FRC
	@-$(RM) cscope.files cscope.files.raw
	echo "$(CSINCS)" > cscope.files
	-find $(CSPATHS) -name SCCS -prune -o \
	    -type d -name '.del-*' -prune -o -type f \
	    \( -name '*.[csh]' -o -name 'Makefile*' -o -name '*.il*' \) \
	    -print > cscope.files.raw
	-grep -v Makefile cscope.files.raw >> cscope.files
	-grep Makefile cscope.files.raw >> cscope.files
	-$(RM) cscope.files.raw
	@wc -l cscope.files

tags: tags.list FRC
	${CTAGS} ${CTFLAGS} `cat tags.list`

tags.list: cscope.files
	@$(RM) tags.list
	grep '\.[chs]$$' cscope.files > tags.list

clean ::
	$(RM) $(OBJS) $(RESET_OBJS)  offsets.h

clobber ::
	$(RM) reset reset.bin

.KEEP_STATE:

FRC:
