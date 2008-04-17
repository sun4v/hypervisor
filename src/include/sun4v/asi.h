/*
 * Copyright 2003 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _SUN4V_ASI_H
#define _SUN4V_ASI_H

#pragma ident	"@(#)asi.h	1.2	03/11/25 SMI"

#ifdef __cplusplus
extern "C" {
#endif


/*
 * sun4v ASI definitions
 */
#define	ASI_REAL	0x14	/* Real-addressed memory */
#define	ASI_REAL_IO	0x15	/* Real-addressed I/O */
#define	ASI_REAL_L	0x1c	/* Real-addressed memory, little-endian */
#define	ASI_REAL_IO_L	0x1d	/* Real-addressed I/O, little-endian */
#define	ASI_SCRATCHPAD	0x20	/* Scratchpad registers */
#define	ASI_MMU		0x21   	/* MMU registers */
#define	ASI_QUEUE	0x25	/* Queue registers */
#define	ASI_REAL_QLDD	0x26	/* Real-addressed quad-ldd */
#define	ASI_REAL_QLDD_L	0x2e	/* Real-addressed quad-ldd, little-endian */

/*
 * sun4v ASI definitions
 */
#define	SOFTINT		%asr22	/* softint register */
#define	TICKCMP		%asr23	/* tick-compare */
#define	STICK		%asr24	/* system tick register */
#define	STICKCMP	%asr25	/* stick-compare */

/*
 * Processor Interrupt Levels
 */
#define	PIL_15		0xf
#define	PIL_14		0xe
#define	PIL_13		0xd
#define	PIL_12		0xc
#define	PIL_11		0xb
#define	PIL_10		0xa
#define	PIL_9		0x9
#define	PIL_8		0x8
#define	PIL_7		0x7
#define	PIL_6		0x6
#define	PIL_5		0x5
#define	PIL_4		0x4
#define	PIL_3		0x3
#define	PIL_2		0x2
#define	PIL_1		0x1
#define	PIL_0		0x0

#ifdef __cplusplus
}
#endif

#endif /* _SUN4V_ASI_H */
