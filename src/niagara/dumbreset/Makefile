# ========== Copyright Header Begin ==========================================
# 
# Hypervisor Software File: Makefile
# 
# Copyright (c) 2006 Sun Microsystems, Inc. All Rights Reserved.
# 
#  - Do no alter or remove copyright notices
# 
#  - Redistribution and use of this software in source and binary forms, with 
#    or without modification, are permitted provided that the following 
#    conditions are met: 
# 
#  - Redistribution of source code must retain the above copyright notice, 
#    this list of conditions and the following disclaimer.
# 
#  - Redistribution in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution. 
# 
#    Neither the name of Sun Microsystems, Inc. or the names of contributors 
# may be used to endorse or promote products derived from this software 
# without specific prior written permission. 
# 
#     This software is provided "AS IS," without a warranty of any kind. 
# ALL EXPRESS OR IMPLIED CONDITIONS, REPRESENTATIONS AND WARRANTIES, 
# INCLUDING ANY IMPLIED WARRANTY OF MERCHANTABILITY, FITNESS FOR A 
# PARTICULAR PURPOSE OR NON-INFRINGEMENT, ARE HEREBY EXCLUDED. SUN 
# MICROSYSTEMS, INC. ("SUN") AND ITS LICENSORS SHALL NOT BE LIABLE FOR 
# ANY DAMAGES SUFFERED BY LICENSEE AS A RESULT OF USING, MODIFYING OR 
# DISTRIBUTING THIS SOFTWARE OR ITS DERIVATIVES. IN NO EVENT WILL SUN 
# OR ITS LICENSORS BE LIABLE FOR ANY LOST REVENUE, PROFIT OR DATA, OR 
# FOR DIRECT, INDIRECT, SPECIAL, CONSEQUENTIAL, INCIDENTAL OR PUNITIVE 
# DAMAGES, HOWEVER CAUSED AND REGARDLESS OF THE THEORY OF LIABILITY, 
# ARISING OUT OF THE USE OF OR INABILITY TO USE THIS SOFTWARE, EVEN IF 
# SUN HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
# 
# You acknowledge that this software is not designed, licensed or
# intended for use in the design, construction, operation or maintenance of
# any nuclear facility. 
# 
# ========== Copyright Header End ============================================
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
