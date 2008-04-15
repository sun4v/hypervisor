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
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)Makefile	1.70	05/12/09 SMI"
#

TOP=../..

PLATFORM = ontario # ontario or legion

include $(TOP)/Makefile.master

HOST :sh = uname -n
USER :sh = /usr/bin/who am i | awk -e '{ print $1; }'
DATE :sh = date +\%Y"/"\%m"/"\%d
TIME :sh = date +\%H":"\%M
SHORTDOMAIN :sh = /bin/expr "`domainname`" : '.*\.\(.*\)\.sun\.com' \| unknown
RELEASE_VERSION$(RELEASE_VERSION) = 0.1
#QVERSION = HV:$(RELEASE_VERSION):$(PLATFORM):$(HOST).$(SHORTDOMAIN):$(CODEMGR_WS):$(DATE):$(USER)
QVERSION = "Hypervisor "$(RELEASE_VERSION)" "$(DATE)" "$(TIME)

########################################

ontario_OPTIONS =
ontario_OPTIONS += -UDEBUG
ontario_OPTIONS += -USTRICT_API
ontario_OPTIONS += -UNIAGARA_BRINGUP
ontario_OPTIONS += -UCONFIG_DISK	# Simulated disk support
ontario_OPTIONS += -DCONFIG_FIRE	# Initialize and configure Fire
ontario_OPTIONS += -DCONFIG_FIRE_EBUS	# Initialize and configure Fire EBus
ontario_OPTIONS += -UCONFIG_IOBYPASS	# Guest I/O bypass access
ontario_OPTIONS += -DCONFIG_SVC
ontario_OPTIONS += -DCONFIG_VBSC_SVC	# VBSC comm channel
ontario_OPTIONS += -DCONFIG_CN_SVC	# Consoles using svc channels
ontario_OPTIONS += -DCONFIG_FPGA	# hardware fpga present
ontario_OPTIONS += -UCONFIG_STATICTOD	# Time does not move - pending FPGA support
ontario_OPTIONS += -UDEBUG_LEGION	# Legion-specific debugging aids
ontario_OPTIONS += -UCONFIG_LEGIONBCOPY # Legion has physical bcopy magic trap
ontario_OPTIONS += -UCONFIG_SAS	# Compile without copies for PPG simulation
ontario_OPTIONS += -DCONFIG_HVUART

########################################

legion_OPTIONS =
legion_OPTIONS += -DDEBUG
legion_OPTIONS += -DSTRICT_API
legion_OPTIONS += -UNIAGARA_BRINGUP
legion_OPTIONS += -DCONFIG_DISK	# Simulated disk support
legion_OPTIONS += -UCONFIG_FIRE		# Initialize and configure Fire
legion_OPTIONS += -UCONFIG_FIRE_EBUS	# Initialize and configure Fire EBus
legion_OPTIONS += -DCONFIG_IOBYPASS	# Guest I/O bypass access
legion_OPTIONS += -DCONFIG_SVC
legion_OPTIONS += -UCONFIG_VBSC_SVC	# VBSC comm channel
legion_OPTIONS += -UCONFIG_CN_SVC	# Consoles using svc channels
legion_OPTIONS += -UCONFIG_FPGA		# hardware fpga present
legion_OPTIONS += -DCONFIG_STATICTOD	# Time does not move - pending FPGA support
legion_OPTIONS += -DDEBUG_LEGION	# Legion-specific debugging aids
legion_OPTIONS += -DCONFIG_LEGIONBCOPY	# Legion has physical bcopy magic trap
legion_OPTIONS += -UCONFIG_SAS		# Compile without copies for PPG simulation
legion_OPTIONS += -DCONFIG_HVUART

########################################

OPTIONS = $($(PLATFORM)_OPTIONS) $(EXTRA_OPTIONS)
OPTIONS += -UCONFIG_BRINGUP		# Force-enable helpful bringup aids

########################################

# #####################################
# Workarounds
# #####################################

# Items prefixed with DESUPPORT_NIAGARA_1x should be disabled by setting
# the make variable DESUPPORT_NIAGARA_1x once Niagara 1.x parts are flushed.
#
# DESUPPORT_NIAGARA_1x=YES	# Leave unset until 1.x parts obsolete


# Reset/Config doesn't properly initialize tick/stick
OPTIONS += -DRESETCONFIG_BROKENTICK

# Enable DRAM and L2$ scrubbers in hypervisor
OPTIONS += -DRESETCONFIG_ENABLEHWSCRUBBERS

# Niagara erratum #39: Halted strand not re-awakened by interrupt
$(DESUPPORT_NIAGARA_1x)OPTIONS += -DNIAGARA_ERRATUM_39

# Niagara erratum #40: Locked TLB entry #63 gets replaced (now a "feature")
OPTIONS += -DNIAGARA_ERRATUM_40

# Niagara erratum #41: Reserved Supervisor or User SPU stxa can silently abort SPU op
OPTIONS += -DNIAGARA_ERRATUM_41

#
# Niagara: JBI INTACK Timeout occurring at boot. Need to mask the
# error interrupt until root cause discovered.
#
OPTIONS += -DNIAGARA_JBI_INTR_TO_WORKAROUND

# Niagara erratum #43: Partial_raw Load after Block_Init_Store Hangs Thread
$(DESUPPORT_NIAGARA_1x)OPTIONS += -DNIAGARA_ERRATUM_43

########################################

CPPFLAGS = -I$(TOP)/include $(OPTIONS)
CFLAGS = -xarch=v9a
ASFLAGS = -xarch=v9v -D_ASM -P -xregsym=no $(CPPFLAGS)

S_SRCS = traptable.s mmu.s intr.s subr.s hcall.s \
	vdev_intr.s \
	vdev_console.s \
	vdev_simdisk.s \
	vdev_nvram.s \
	vpci.s vpci_msi.s vpci_fire.s vpci_errs.s \
	cyclic.s cpu_errs.s l2subr.s errs_common.s \
	svc.s svcinternal.s \
	svc_vbsc.s \
	main.s \
	setup.s md.s \
	version.s \
	ncs.s

C_SRCS = config.c
Q_OBJS = $(S_SRCS:%.s=%.o) $(C_SRCS:%.c=%.o)
OBJS = begin.o $(Q_OBJS) end.o

all :: q.bin

$(OBJS): offsets.h

version.o: version.s
	@echo "Version: $(QVERSION)"
	$(AS) $(ASFLAGS) -DVERSION=\"$(QVERSION)\" $< -o $@

versioninfo:
	@echo "Version: $(QVERSION)"

q.bin: q
	$(OBJCOPY) -O binary q q.bin
	@what q.bin
	@ls -l q.bin

q: $(OBJS) mapfile.q
	$(LD) -o $@ -e start_master -dn -z defs -M mapfile.q $(OBJS)
	@size q

q.dis: q0
	dis q0 > $@

q0: $(Q_OBJS) mapfile.q0
	$(LD) -o $@ -e start_master -dn -z defs -M mapfile.q0 $(Q_OBJS)

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
CSDIRS	= . $(TOP)/include
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
	$(RM) *.o *~ offsets.h

clobber ::
	$(RM) q q0 q.bin q.dis .make.state ,* *~ cscope.files cscope.out tags.list tags

install :: $(PROTO_PLAT)/q0 $(PROTO_PLAT)/q.bin

.KEEP_STATE:

FRC:
