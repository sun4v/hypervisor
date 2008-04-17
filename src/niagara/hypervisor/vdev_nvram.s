/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

	.ident	"@(#)vdev_nvram.s	1.1	05/04/26 SMI"

	.file	"vdev_nvram.s"

#include <hypervisor.h>

#if defined(NVRAM_READ) && defined(NVRAM_WRITE) /* Not in API spec */

#include <sys/asm_linkage.h>
#include <niagara/asi.h>
#include <niagara/mmu.h>

#include "guest.h"
#include "offsets.h"
#include "util.h"

/*
 * nvram read
 *
 * arg0 nvram offset (%o0)
 * arg1 target real address (%o1)
 * arg2 size (%o2)
 * --
 * ret0 status (%o0)
 * ret1 size (%o1)
 */
	ENTRY_NP(hcall_nvram_read)
	GUEST_STRUCT(%g1)
	RANGE_CHECK(%g1, %o1, %o2, herr_noraddr, %g2)
	REAL_OFFSET(%g1, %o1, %g2, %g3)

	set	GUEST_NVRAM_SIZE, %g3
	ldx	[%g1 + %g3], %g3 ! size of NVRAM
	add	%o0, %o2, %g4
	cmp	%g4, %g3
	bgu,pn	%xcc, herr_inval
	.empty
	set	GUEST_NVRAM_PA, %g3
	ldx	[%g1 + %g3], %g3 ! base of NVRAM

	/* bcopy(%g3 + %o0, %g2, %o2) */
	add	%g3, %o0, %g1
	mov	%o2, %g3
	sub	%g1, %g2, %g1
1:
	ldub	[%g1 + %g2], %g4
	deccc	%g3
	stb	%g4, [%g2]
	bgu,pt	%xcc, 1b
	inc	%g2

	mov	%o2, %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_nvram_read)


/*
 * nvram write
 *
 * arg0 nvram offset (%o0)
 * arg1 source real address (%o1)
 * arg2 size (%o2)
 * --
 * ret0 status (%o0)
 * ret1 size (%o1)
 */
	ENTRY_NP(hcall_nvram_write)
	GUEST_STRUCT(%g1)
	RANGE_CHECK(%g1, %o1, %o2, herr_noraddr, %g2)
	REAL_OFFSET(%g1, %o1, %g3, %g2)

	set	GUEST_NVRAM_SIZE, %g2
	ldx	[%g1 + %g2], %g2
	cmp	%o0, %g2
	bgu,pn	%xcc, herr_inval
	add	%o0, %o2, %g4
	cmp	%g4, %g2
	bgu,pn	%xcc, herr_inval
	.empty
	set	GUEST_NVRAM_PA, %g2
	ldx	[%g1 + %g2], %g2 ! base of NVRAM

	!! %g3 pa of the src
	!! %o2 is the size
	!! %g2 nvram base
	add	%g2, %o0, %g2
	!! %g2 is the dst
	sub	%g3, %g2, %g1
	mov	%o2, %g3
	!! %g3 is the size
1:
	ldub	[%g1 + %g2], %g4
	deccc	%g3
	stb	%g4, [%g2]
	bgu,pt	%xcc, 1b
	inc	%g2

	mov	%o2, %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_nvram_write)

#endif /* not in API spec */

