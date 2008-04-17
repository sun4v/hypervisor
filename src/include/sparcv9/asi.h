/*
 * Copyright 2002 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _SPARCV9_ASI_H
#define _SPARCV9_ASI_H

#pragma ident	"@(#)asi.h	1.1	02/12/21 SMI"

/*
 * SPARC v9 ASI definitions
 */

#ifdef __cplusplus
extern "C" {
#endif

#define	ASI_N		0x04	/* Nucleus */
#define	ASI_N_LE	0x0c	/* Nucleus, little endian */
#define	ASI_AIUP	0x10	/* As if user, primary */
#define	ASI_AIUS	0x11	/* As if user, secondary */
#define	ASI_AIUP_LE	0x18	/* As if user, primary, little endian */
#define	ASI_AIUS_LE	0x19	/* As is user, secondary, little endian */
#define	ASI_P		0x80	/* Primary MMU context*/
#define	ASI_S		0x81	/* Secondary MMU context */
#define	ASI_P_NF	0x82	/* Primary MMU context, no fault */
#define	ASI_S_NF	0x83	/* Secondary MMU context, no fault */
#define	ASI_P_LE	0x88	/* Primary MMU context, little endian */
#define	ASI_S_LE	0x89	/* Secondary MMU context, little endian */
#define	ASI_P_NF_LE	0x8a	/* Primary MMU context, LE, no fault */
#define	ASI_S_NF_LE	0x8b	/* Secondary MMU context, LE, no fault */

#endif /* _SPARCV9_ASI_H */
