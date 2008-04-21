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

VARIANT = t1_fpga

RESET = ../fpga_1thread_reset      # use single thread Niagara reset code

include ../Makefile.platform

CP = /bin/cp -f

########################################

OPTIONS = $(PLAT_OPTIONS)

OPTIONS += -DT1_FPGA                 # T1 implementation in FPGA
OPTIONS += -DT1_FPGA_UART_PREINIT    # expecting preinitialized UART device
OPTIONS += -DT1_FPGA_MEMORY_PREINIT  # memory preinitialized
OPTIONS += -DT1_FPGA_STAND_ALONE     # stand-alone program running on top of the hypervisor
                                     # instead of OBP.
#OPTIONS += -DT1_FPGA_FAST_MEMSCRUB  # use block store init instruction to initialize memory


OPTIONS += -DDEBUG
OPTIONS += -DSTRICT_API
OPTIONS += -UNIAGARA_BRINGUP
OPTIONS += -UCONFIG_DISK	# Simulated disk support
OPTIONS += -UCONFIG_FIRE		# Initialize and configure Fire
OPTIONS += -UCONFIG_FIRE_EBUS	# Initialize and configure Fire EBus
OPTIONS += -UCONFIG_IOBYPASS	# Guest I/O bypass access
OPTIONS += -DCONFIG_SVC
OPTIONS += -UCONFIG_VBSC_SVC	# VBSC comm channel
OPTIONS += -UCONFIG_CN_SVC	# Consoles using svc channels
OPTIONS += -UCONFIG_FPGA		# hardware fpga present
OPTIONS += -DCONFIG_STATICTOD	# Time does not move - pending FPGA support
OPTIONS += -UDEBUG_LEGION	# Legion-specific debugging aids
OPTIONS += -UCONFIG_LEGIONBCOPY	# Legion has physical bcopy magic trap
OPTIONS += -UCONFIG_SAS		# Compile without copies for PPG simulation
OPTIONS += -DCONFIG_HVUART
OPTIONS += -UCONFIG_VERSION_TEST

########################################

OPTIONS += $(EXTRA_OPTIONS)
OPTIONS += -UCONFIG_BRINGUP		# Force-enable helpful bringup aids

########################################

PROM_FILE = prom.bin

$(PROTO_PLAT)/q: q
$(PROTO_PLAT)/reset: reset
$(PROTO_PLAT)/$(PROM_FILE): $(PROM_FILE)

all :: reset.bin q.bin $(PROM_FILE)


$(PROM_FILE): reset.bin q.bin guest-pd.bin hv-pd.bin make_prom
	./make_prom $(PROM_FILE)

hv-pd.bin: configs/1up-hv.bin
	$(CP) configs/1up-hv.bin hv-pd.bin

guest-pd.bin: configs/1up-md.bin
	$(CP) configs/1up-md.bin guest-pd.bin

configs/1up-hv.bin:
	@cd configs ; make 1up-hv.bin

configs/1up-md.bin:
	@cd configs ; make 1up-md.bin

clobber::
	$(RM) guest-pd.bin hv-pd.bin $(PROM_FILE) make_prom
	@cd configs && pwd && $(MAKE) clobber

clean::
	@cd configs && pwd && $(MAKE) clean


install :: $(PROTO_PLAT)/q $(PROTO_PLAT)/q.bin $(PROTO_PLAT)/reset $(PROTO_PLAT)/reset.bin $(PROTO_PLAT)/$(PROM_FILE)
