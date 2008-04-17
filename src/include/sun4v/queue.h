/*
 * Copyright 2003 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _SUN4V_QUEUE_H
#define _SUN4V_QUEUE_H

#pragma ident	"@(#)queue.h	1.3	04/08/19 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * sun4v Queue registers
 */

#define	CPU_MONDO_QUEUE		0x3c
#define	DEV_MONDO_QUEUE		0x3d
#define	ERROR_RESUMABLE_QUEUE	0x3e
#define	ERROR_NONRESUMABLE_QUEUE 0x3f

#define	CPU_MONDO_QUEUE_HEAD	0x3c0 /* rw */
#define	CPU_MONDO_QUEUE_TAIL	0x3c8 /* ro */
#define	DEV_MONDO_QUEUE_HEAD	0x3d0 /* rw */
#define	DEV_MONDO_QUEUE_TAIL	0x3d8 /* ro */

#define	ERROR_RESUMABLE_QUEUE_HEAD	0x3e0 /* rw */
#define	ERROR_RESUMABLE_QUEUE_TAIL	0x3e8 /* ro */
#define	ERROR_NONRESUMABLE_QUEUE_HEAD	0x3f0 /* rw */
#define	ERROR_NONRESUMABLE_QUEUE_TAIL	0x3f8 /* ro */

#define	Q_EL_SIZE		0x40
#define	Q_EL_SIZE_SHIFT		6	/* LOG2(Q_EL_SIZE) */

#ifdef __cplusplus
}
#endif

#endif /* _SUN4V_QUEUE_H */
