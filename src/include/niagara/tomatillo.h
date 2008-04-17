/*
 * Copyright 2004 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#pragma ident   "@(#)tomatillo.h 1.1     04/05/27 SMI"

/*
 * Tomatillo Definitions
 */

#define TOMATILLO_BASE  0x800f000000		/* JBUS ID = 1e */

#define TOM_CTL_STAT_REG   ( TOMATILLO_BASE + 0x410000 )
#define TOM_RESET_GEN_REG  ( TOMATILLO_BASE + 0x417010 )
#define TOM_JBUS_DTAG_REGS ( TOMATILLO_BASE + 0x412000 )
#define TOM_JBUS_CTAG_REGS ( TOMATILLO_BASE + 0x413000 )
#define TOM_PCIA_BASE 	   ( TOMATILLO_BASE + 0x600000 )
#define TOM_PCIB_BASE 	   ( TOMATILLO_BASE + 0x700000 )
#define TOM_PCIA_IO_CACHE_TAG ( TOM_PCIA_BASE + 0x2250 )
#define TOM_PCIB_IO_CACHE_TAG ( TOM_PCIB_BASE + 0x2250 )

