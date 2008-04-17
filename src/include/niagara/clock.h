/*
 * Copyright 2004 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#pragma ident   "@(#)clock.h 1.1     04/08/02 SMI"

/*
 * Clock Unit Definitions
 */

#define CLK_BASE  ( 0x96 << 32 )

#define CLK_DIV_REG			0x00
#define CLK_CTL_REG			0x08
#define CLK_DLL_CNTL_REG		0x18
#define CLK_DLL_BYP_REG			0x38
#define CLK_JSYNC_REG			0x28
#define CLK_DSYNC_REG			0x30
#define CLK_VERSION_REG			0x40

#define CLK_CTL_MASK			0xffff000000000000
#define CLK_DEBUG_INIT_REG		0x10		/* DEBUG ONLY, not for normal use */


