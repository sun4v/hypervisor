/*
 * Copyright 2003 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _SPARCV9_MISC_H
#define _SPARCV9_MISC_H

#pragma ident	"@(#)misc.h	1.2	04/08/11 SMI"

#ifdef __cplusplus
extern "C" {
#endif


#define	CCR_xc	0x10
#define	CCR_ic	0x01

/*
 * Floating Point Registers State (FPRS)
 *      (For V9 only)
 *
 *   |---------------|
 *   | FEF | DU | DL |
 *   |-----|----|----|
 *      2    1     0
 */
#define	FPRS_DL		0x1	/* dirty lower */
#define	FPRS_DU		0x2	/* dirty upper */
#define	FPRS_FEF	0x4	/* enable fp */


#ifdef __cplusplus
}
#endif

#endif /* _SPARCV9_MISC_H */
