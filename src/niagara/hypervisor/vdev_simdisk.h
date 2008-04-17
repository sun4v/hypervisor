/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _VDEV_SIMDISK_H
#define	_VDEV_SIMDISK_H

#pragma ident	"@(#)vdev_simdisk.h	1.1	05/04/26 SMI"

#ifndef _ASM

struct hvdisk {
	uint64_t	pa;	/* base pa of simulated disk */
	uint64_t	size;	/* size of simulated disk */
};

#endif /* !_ASM */

/*
 * On the very first access to the disk read/write
 * we get the size of the disk by reading the nblks
 * value for slice 2 from the label. We save the size
 * so that the subsequent accesses should only incurr
 * a branch overhead.
 */
#define	DISK_S2NBLK_OFFSET	0x1d0
#define	DISK_BLKSIZE		512
#define	DISK_BLKSIZE_SHIFT	9 	/* 2^9 = 512 */

#endif /* _VDEV_SIMDISK_H */
