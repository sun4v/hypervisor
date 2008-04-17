/*
 * Copyright 2003 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _SUN4V_TRAPS_H
#define	_SUN4V_TRAPS_H

#pragma ident	"@(#)traps.h	1.7	04/12/05 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#define	MAXPTL		2	/* Maximum privileged trap level */
#define	MAXPGL		2	/* Maximum privileged globals level */
#define	TRAPTABLE_ENTRY_SIZE	(8 * 4) /* Eight Instructions */
#define	REAL_TRAPTABLE_SIZE	(8 * TRAPTABLE_ENTRY_SIZE)
#define	TRAPTABLE_SIZE	(1 << 14)

/*
 * sun4v definition of pstate
 */
#define	PSTATE_IE	0x00000002 /* interrupt enable */
#define	PSTATE_PRIV	0x00000004 /* privilege */
#define	PSTATE_AM	0x00000008 /* address mask */
#define	PSTATE_PEF	0x00000010 /* fpu enable */
#define	PSTATE_MM_MASK	0x000000c0 /* memory model */
#define	PSTATE_MM_SHIFT	0x00000006
#define	PSTATE_TLE	0x00000100 /* trap little-endian */
#define	PSTATE_CLE	0x00000200 /* current little-endian */
#define	PSTATE_TCT	0x00001000 /* trap on control transfer */

#define	PSTATE_MM_TSO	0x00
#define	PSTATE_MM_PSO	0x40
#define	PSTATE_MM_RMO	0x80

#define	TSTATE_PSTATE_SHIFT	8
#define	TSTATE_GL_SHIFT		40
#define	TSTATE_CCR_SHIFT	32
#define	TSTATE_ASI_SHIFT	24

#define	WATCHDOG_TT		0x02
#define	XIR_TT			0x03
#define	IMMU_MISS_TT		0x09
#define	DMMU_MISS_TT		0x31
#define	FAST_IMMU_MISS_TT	0x64
#define	FAST_DMMU_MISS_TT	0x68
#define	FAST_PROT_TT		0x6c
#define	NON_RESUMABLE_TT	0x7f
#define	TT_OFFSET_SHIFT		5 /* convert tt to tba offset */

#ifdef __cplusplus
}
#endif

#endif /* _SUN4V_TRAPS_H */
