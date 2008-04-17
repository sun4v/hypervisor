#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)Makefile	1.1	05/08/20 SMI"
#

TOP = ..

include $(TOP)/Makefile.master

# Headers we install into the proto area
HDRS =	hypervisor.h \
	ncs_api.h \
	sun4v/asi.h sun4v/mmu.h sun4v/queue.h sun4v/traps.h sun4v/vpci.h \
	md/md_impl.h

$(PROTO_INC)/sun4v $(PROTO_INC)/md:
	$(INS.dir)

$(PROTO_INC)/sun4v/%: % $(PROTO_INC)/sun4v
	$(INS.file)

$(PROTO_INC)/md/%: % $(PROTO_INC)/md
	$(INS.file)

install :: $(PROTO_INC)/sun4v $(PROTO_INC)/md $(HDRS:%=$(PROTO_INC)/%)
