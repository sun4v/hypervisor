/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

	.ident	"@(#)vdev_simdisk.s	1.1	05/04/26 SMI"

	.file	"vdev_simdisk.s"

#ifdef CONFIG_DISK /* { */

#include <sys/asm_linkage.h>
#include <hypervisor.h>
#include <niagara/asi.h>
#include <niagara/mmu.h>

#include "guest.h"
#include "offsets.h"
#include "util.h"
#include "vdev_simdisk.h"


/*
 * fake-disk read
 *
 * arg0 disk offset (%o0)
 * arg1 target real address (%o1)
 * arg2 size (%o2)
 * --
 * ret0 status (%o0)
 * ret1 size (%o1)
 */
	ENTRY_NP(hcall_disk_read)
	GUEST_STRUCT(%g1)
	RANGE_CHECK(%g1, %o1, %o2, herr_noraddr, %g2)
	REAL_OFFSET(%g1, %o1, %g2, %g3)

	set	GUEST_DISK, %g3
	add	%g1, %g3, %g1
	!! %g1 = diskp

	ldx	[%g1 + DISK_SIZE], %g3
	brnz,pt	%g3, 1f
	  cmp	%o0, %g3	! XXX this doesn't matter, just %o0+%o2

	ldx	[%g1 + DISK_PA], %g4 ! base of disk
	cmp	%g4, -1
	be,pn	%xcc, herr_inval
	nop

	ld	[%g4 + DISK_S2NBLK_OFFSET], %g5	! read nblks from s2
	sllx	%g5, DISK_BLKSIZE_SHIFT, %g5		! multiply by blocksize
	stx 	%g5, [%g1 + DISK_SIZE]	! store disk size
	mov	%g5, %g3

	cmp	%o0, %g3
1:	bgeu,pn	%xcc, herr_inval
	add	%o0, %o2, %g4
	cmp	%g4, %g3
	bgu,pn	%xcc, herr_inval
	ldx	[%g1 + DISK_PA], %g3 ! base of disk

	/* bcopy(%g3 + %o0, %g2, %o2) */
	add	%g3, %o0, %g1
	! %g2 already set up
	mov	%o2, %g3
	ba	bcopy
	rd	%pc, %g7

	mov	%o2, %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_disk_read)

/*
 * fake-disk write
 *
 * arg0 disk offset (%o0)
 * arg1 source real address (%o1)
 * arg2 size (%o2)
 * --
 * ret0 status (%o0)
 * ret1 size (%o1)
 */
	ENTRY_NP(hcall_disk_write)
	GUEST_STRUCT(%g1)
	RANGE_CHECK(%g1, %o1, %o2, herr_noraddr, %g2)
	REAL_OFFSET(%g1, %o1, %g3, %g2)

	set	GUEST_DISK, %g2
	add	%g1, %g2, %g1
	!! %g1 = diskp

	ldx	[%g1 + DISK_SIZE], %g2
	brnz,pt	%g2, 1f
	  cmp	%o0, %g2

	ldx	[%g1 + DISK_PA], %g4	 ! base of disk
	cmp	%g4, -1
	be,pn	%xcc, herr_inval
	nop

	ld	[%g4 + DISK_S2NBLK_OFFSET], %g5	! read nblks from s2
	sllx	%g5, DISK_BLKSIZE_SHIFT, %g5	! multiply by blocksize
	stx 	%g5, [%g1 + DISK_SIZE]	! store disk size
	mov	%g5, %g2

	cmp	%o0, %g2
1:	bgeu,pn	%xcc, herr_inval
	add	%o0, %o2, %g4
	cmp	%g4, %g2
	bgu,pn	%xcc, herr_inval
	ldx	[%g1 + DISK_PA], %g2	! base of disk

	/* bcopy(%g3, %g2 + %o0, %o2) */
	mov	%g3, %g1
	add	%g2, %o0, %g2
	mov	%o2, %g3
	ba	bcopy
	rd	%pc, %g7

	mov	%o2, %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_disk_write)

#endif /* CONFIG_DISK } */

