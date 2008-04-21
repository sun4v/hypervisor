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
  
TOP = ../../../..

include $(TOP)/Makefile.master

CONFIGS = 1up
DBIN_CFGS = $(CONFIGS:%=%-md.bin)
DTXT_CFGS = $(CONFIGS:%=%-md.txt)
HBIN_CFGS = $(CONFIGS:%=%-hv.bin)
HTXT_CFGS = $(CONFIGS:%=%-hv.txt)

MDGEN=$(TOP)/md/mdgen/mdgen

all :: $(DBIN_CFGS) $(DTXT_CFGS) $(HBIN_CFGS) $(HTXT_CFGS)

%-md.pp: %.pdesc
	$(CPP) $< $@

%-hv.pp: %.hdesc
	$(CPP) $< $@

%-md.bin: %-md.pp
	$(MDGEN) --binary $(VERBOSE) --outfile $@ $<

%-md.txt: %-md.pp
	$(MDGEN) --text --outfile $@ $<

%-hv.bin: %-hv.pp
	$(MDGEN) --binary $(VERBOSE) --outfile $@ $<

%-hv.txt: %-hv.pp
	$(MDGEN) --text --outfile $@ $<

clean ::
	$(RM) *.pp $(HTXT_CFGS) $(DTXT_CFGS)

clobber ::
	$(RM) $(HBIN_CFGS) $(DBIN_CFGS)

.KEEP_STATE:
