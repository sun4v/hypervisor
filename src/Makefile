#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"@(#)Makefile	1.9	05/08/20 SMI"
#

TOP = .

HVIMPLS:sh = echo */hypervisor/Makefile | sed -e 's%/hypervisor/Makefile%%g'

SUBDIRS = include md $(HVIMPLS)

include $(TOP)/Makefile.master
