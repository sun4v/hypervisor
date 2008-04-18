/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: mmu.s
* 
* Copyright (c) 2006 Sun Microsystems, Inc. All Rights Reserved.
* 
*  - Do no alter or remove copyright notices
* 
*  - Redistribution and use of this software in source and binary forms, with 
*    or without modification, are permitted provided that the following 
*    conditions are met: 
* 
*  - Redistribution of source code must retain the above copyright notice, 
*    this list of conditions and the following disclaimer.
* 
*  - Redistribution in binary form must reproduce the above copyright notice,
*    this list of conditions and the following disclaimer in the
*    documentation and/or other materials provided with the distribution. 
* 
*    Neither the name of Sun Microsystems, Inc. or the names of contributors 
* may be used to endorse or promote products derived from this software 
* without specific prior written permission. 
* 
*     This software is provided "AS IS," without a warranty of any kind. 
* ALL EXPRESS OR IMPLIED CONDITIONS, REPRESENTATIONS AND WARRANTIES, 
* INCLUDING ANY IMPLIED WARRANTY OF MERCHANTABILITY, FITNESS FOR A 
* PARTICULAR PURPOSE OR NON-INFRINGEMENT, ARE HEREBY EXCLUDED. SUN 
* MICROSYSTEMS, INC. ("SUN") AND ITS LICENSORS SHALL NOT BE LIABLE FOR 
* ANY DAMAGES SUFFERED BY LICENSEE AS A RESULT OF USING, MODIFYING OR 
* DISTRIBUTING THIS SOFTWARE OR ITS DERIVATIVES. IN NO EVENT WILL SUN 
* OR ITS LICENSORS BE LIABLE FOR ANY LOST REVENUE, PROFIT OR DATA, OR 
* FOR DIRECT, INDIRECT, SPECIAL, CONSEQUENTIAL, INCIDENTAL OR PUNITIVE 
* DAMAGES, HOWEVER CAUSED AND REGARDLESS OF THE THEORY OF LIABILITY, 
* ARISING OUT OF THE USE OF OR INABILITY TO USE THIS SOFTWARE, EVEN IF 
* SUN HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
* 
* You acknowledge that this software is not designed, licensed or
* intended for use in the design, construction, operation or maintenance of
* any nuclear facility. 
* 
* ========== Copyright Header End ============================================
*/
/*
 * Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

	.ident	"@(#)mmu.s	1.38	06/05/23 SMI"

	.file	"mmu.s"

/*
 * Niagara startup code
 */

#include <sys/asm_linkage.h>
#include <hprivregs.h>
#include <asi.h>
#include <traps.h>
#include <mmu.h>
#include <sun4v/traps.h>
#include <sun4v/mmu.h>
#include <mmustat.h>

#include <guest.h>
#include <offsets.h>
#include <debug.h>
#include <util.h>


	! %g1	cpup
	! %g2	8k-aligned real addr from tag access
	ENTRY_NP(rdmmu_miss)
	! offset handling
	! XXX if hypervisor access then panic instead of watchdog_guest
	IN_RANGE(%g1, %g2, %g3,
		GUEST_MEM_BASE, GUEST_MEM_OFFSET, GUEST_MEM_SIZE,
		1f, %g4, %g6)

	! tte valid, cp, writable, priv
	mov	1, %g2
	sllx	%g2, 63, %g2
	or	%g2, TTE4U_CP | TTE4U_P | TTE4U_W, %g2
	or	%g3, %g2, %g3
	mov	TLB_IN_REAL, %g2	! Real bit
	stxa	%g3, [%g2]ASI_DTLB_DATA_IN
	retry

1:
	GUEST_STRUCT(%g1)
	set	8192, %g6
	RANGE_CHECK_IO(%g1, %g2, %g6, .rdmmu_miss_found, .rdmmu_miss_not_found,
	    %g3, %g4)
.rdmmu_miss_found:
	mov	%g2, %g3

	! tte valid, e, writable, priv
	mov	1, %g2
	sllx	%g2, 63, %g2
	or	%g2, TTE4U_E | TTE4U_P | TTE4U_W, %g2
	or	%g3, %g2, %g3
	mov	TLB_IN_REAL, %g2	! Real bit
	stxa	%g3, [%g2]ASI_DTLB_DATA_IN
	retry

.rdmmu_miss_not_found:
1:
	!! %g2 real address
	LEGION_GOT_HERE
	mov	MMU_FT_INVALIDRA, %g1
	ba,pt	%xcc, revec_dax	! (%g1=ft, %g2=addr, %g3=ctx)
	mov	0, %g3
	SET_SIZE(rdmmu_miss)

	! %g1	cpup
	! %g2	8k-aligned real addr from tag access
	ENTRY_NP(rimmu_miss)

#if 1
	! offset handling
	! XXX if hypervisor access then panic instead of watchdog_guest
	ldx	[%g1 + CPU_GUEST], %g1
	ldx	[%g1 + GUEST_MEM_OFFSET], %g3
	add	%g2, %g3, %g2
	ldx	[%g1 + GUEST_MEM_BASE], %g3
	ldx	[%g1 + GUEST_MEM_SIZE], %g4
	cmp	%g2, %g3
	blu,pn	%xcc, 1f
	add	%g3, %g4, %g3
	cmp	%g2, %g3
	bgeu,pn	%xcc, 1f
	mov	%g2, %g1
#else
	! offset handling
	ldx	[%g1 + CPU_GUEST], %g1
	ldx	[%g1 + GUEST_MEM_OFFSET], %g1
	add	%g2, %g1, %g1
#endif

	! tte valid, cp, writable, priv
	mov	1, %g2
	sllx	%g2, 63, %g2
	or	%g2, TTE4U_CP | TTE4U_P | TTE4U_W, %g2
	or	%g1, %g2, %g1
	mov	TLB_IN_REAL, %g2	! Real bit
	stxa	%g1, [%g2]ASI_ITLB_DATA_IN
	retry

1:
	!! %g2 real address
	LEGION_GOT_HERE
	mov	MMU_FT_INVALIDRA, %g1
	ba,pt	%xcc, revec_iax	! (%g1=ft, %g2=addr, %g3=ctx)
	mov	0, %g3
	SET_SIZE(rimmu_miss)

	/*
	 * Normal tlb miss handlers
	 *
	 * Guest miss area:
	 *
	 * NB:	 If it's possible to context switch a guest then
	 * the tag access register (tag target too?) needs to
	 * be saved/restored.
	 */

	/* %g1 contains per CPU area */
	ENTRY_NP(immu_miss)
	rd	%tick, %g2
	stx	%g2, [%g1 + CPU_SCR0]
	ldxa	[%g0]ASI_IMMU, %g3	/* tag target */
	srlx	%g3, TAGTRG_CTX_RSHIFT, %g4	/* ctx from tag target */

	!! %g1 = CPU pointer
	!! %g3 = tag target
	!! %g4 = ctx

.checkitsb0:
	! for context != 0 and unshared TSB, that ctx == TSB ctx
	brz,pn	%g4, 1f
	mov	%g3, %g2
	ld	[%g1 + CPU_TSBDS_CTXN + TSBD_CTX_INDEX], %g5
	cmp	%g5, -1
	be,pn	%icc, 1f
	nop
	! if TSB not shared, zero out context for match
	sllx	%g3, TAGTRG_VA_LSHIFT, %g2
	srlx	%g2, TAGTRG_VA_LSHIFT, %g2	! clear context
1:
	ldxa	[%g0]ASI_IMMU_TSB_PS0, %g5
	! if TSB desc. specifies xor of TSB index, do it here
	! e.g. for shared TSBs in S9 xor value is ctx << 4
	ldda	[%g5]ASI_QUAD_LDD, %g6	/* g6 = tag, g7 = data */
	cmp	%g6, %g2
	bne,pn	%xcc, .checkitsb1	! tag mismatch
	nop
	brlz,pt %g7, .itsbhit		! TTE valid
	nop

.checkitsb1:
	! repeat check for second TSB
	brz,pn	%g4, 1f
	mov	%g3, %g2
	ld	[%g1 + CPU_TSBDS_CTXN + TSBD_BYTES + TSBD_CTX_INDEX], %g5
	cmp	%g5, -1
	be,pn	%icc, 1f
	nop
	! if TSB not shared, zero out context for match
	sllx	%g3, TAGTRG_VA_LSHIFT, %g2
	srlx	%g2, TAGTRG_VA_LSHIFT, %g2	! clear context
1:
	ldxa	[%g0]ASI_IMMU_TSB_PS1, %g5
	! if TSB desc. specifies xor of TSB index, do it here
	ldda	[%g5]ASI_QUAD_LDD, %g6	/* g6 = tag, g7 = data */
	cmp	%g6, %g2
	bne,pn	%xcc, .itsbmiss		! tag mismatch
	nop
	brgez,pn %g7, .itsbmiss		! TTE valid?
	nop

.itsbhit:
	! extract sz from tte
	TTE_SIZE(%g7, %g4, %g3, .itsbmiss) ! XXX fault not just a miss
	btst	TTE_X, %g7	! must check X bit for IMMU
	bz,pn	%icc, .itsbmiss
	sub	%g4, 1, %g5	! %g5 page mask

	! extract ra from tte
	sllx	%g7, 64 - 40, %g3
	srlx	%g3, 64 - 40 + 13, %g3
	sllx	%g3, 13, %g3	! %g3 real address
	xor	%g7, %g3, %g7	! %g7 orig tte with ra field zeroed
	andn	%g3, %g5, %g3
	ldx	[%g1 + CPU_GUEST], %g6
	RANGE_CHECK(%g6, %g3, %g4, .itsbmiss, %g5) ! XXX fault not just a miss
	REAL_OFFSET(%g6, %g3, %g3, %g4)
	or	%g7, %g3, %g7	! %g7 new tte with pa

	mov	1, %g5
	sllx	%g5, NI_TTE4V_L_SHIFT, %g5
	andn	%g7, %g5, %g7	! %g7 tte (force clear lock bit)

	set	TLB_IN_4V_FORMAT, %g5	! %g5 sun4v-style tte selection
	stxa	%g7, [%g5]ASI_ITLB_DATA_IN
	!!
	!! %g1 = CPU pointer
	!! %g7 = TTE
	!!
	ldx	[%g1 + CPU_MMUSTAT_AREA], %g6
	brnz,pn	%g6, 1f
	nop

	retry

1:
	rd	%tick, %g2
	ldx	[%g1 + CPU_SCR0], %g1
	sub	%g2, %g1, %g5
	!!
	!! %g5 = %tick delta
	!! %g6 = MMU statistics area
	!! %g7 = TTE
	!!
	inc	MMUSTAT_I, %g6			/* stats + i */
	ldxa	[%g0]ASI_IMMU, %g3		/* tag target */
	srlx	%g3, TAGTRG_CTX_RSHIFT, %g4	/* ctx from tag target */
	mov	MMUSTAT_CTX0, %g1
	movrnz	%g4, MMUSTAT_CTXNON0, %g1
	add	%g6, %g1, %g6			/* stats + i + ctx */
	and	%g7, TTE_SZ_MASK, %g7
	sllx	%g7, MMUSTAT_ENTRY_SZ_SHIFT, %g7
	add	%g6, %g7, %g6			/* stats + i + ctx + pgsz */
	ldx	[%g6 + MMUSTAT_TICK], %g3
	add	%g3, %g5, %g3
	stx	%g3, [%g6 + MMUSTAT_TICK]
	ldx	[%g6 + MMUSTAT_HIT], %g3
	inc	%g3
	stx	%g3, [%g6 + MMUSTAT_HIT]
	retry

.itsbmiss:
	ldx	[%g1 + CPU_MMU_AREA], %g2
	brz,pn	%g2, watchdog_guest
	.empty

	!! %g1 is CPU pointer
	!! %g2 is MMU Fault Status Area
	!! %g4 is context (possibly shifted - still OK for zero test)
	/* if ctx == 0 and ctx0 set TSBs used, take slow trap */
	/* if ctx != 0 and ctxnon0 set TSBs used, take slow trap */
	mov	CPU_NTSBS_CTXN, %g7
	movrz	%g4, CPU_NTSBS_CTX0, %g7
	ldx	[%g1 + %g7], %g7
	brnz,pn	%g7, .islowmiss
	nop

.ifastmiss:
	/*
	 * Update MMU_FAULT_AREA_INSTR
	 */
	mov	MMU_TAG_ACCESS, %g3
	ldxa	[%g3]ASI_IMMU, %g3	/* tag access */
	set	(NCTXS - 1), %g5
	andn	%g3, %g5, %g4
	and	%g3, %g5, %g5
	stx	%g4, [%g2 + MMU_FAULT_AREA_IADDR]
	stx	%g5, [%g2 + MMU_FAULT_AREA_ICTX]
	/* fast misses do not update MMU_FAULT_AREA_IFT with MMU_FT_FASTMISS */
	! wrpr	%g0, FAST_IMMU_MISS_TT, %tt	/* already set */
	rdpr	%pstate, %g3
	or	%g3, PSTATE_PRIV, %g3
	wrpr	%g3, %pstate
	rdpr	%tba, %g3
	add	%g3, (FAST_IMMU_MISS_TT << TT_OFFSET_SHIFT), %g3
7:
	rdpr	%tl, %g2
	cmp	%g2, 1	/* trap happened at tl=0 */
	be,pt	%xcc, 1f
	.empty
	set	TRAPTABLE_SIZE, %g5

	cmp	%g2, MAXPTL
	bgu,pn	%xcc, watchdog_guest
	add	%g5, %g3, %g3

1:
	mov	HPSTATE_GUEST, %g5		! set ENB bit
	jmp	%g3
	wrhpr	%g5, %hpstate

.islowmiss:
	/*
	 * Update MMU_FAULT_AREA_INSTR
	 */
	mov	MMU_TAG_TARGET, %g3
	ldxa	[%g3]ASI_IMMU, %g3	/* tag target */
	srlx	%g3, 48, %g3
	stx	%g3, [%g2 + MMU_FAULT_AREA_ICTX]
	rdpr	%tpc, %g4
	stx	%g4, [%g2 + MMU_FAULT_AREA_IADDR]
	mov	MMU_FT_MISS, %g4
	stx	%g4, [%g2 + MMU_FAULT_AREA_IFT]
	wrpr	%g0, IMMU_MISS_TT, %tt
	rdpr	%pstate, %g3
	or	%g3, PSTATE_PRIV, %g3
	wrpr	%g3, %pstate
	rdpr	%tba, %g3
	add	%g3, (IMMU_MISS_TT << TT_OFFSET_SHIFT), %g3
	ba,a	7b
	.empty
	SET_SIZE(immu_miss)

	/* %g1 contains per CPU area */
	ENTRY_NP(dmmu_miss)
	rd	%tick, %g2
	stx	%g2, [%g1 + CPU_SCR0]
	ldxa	[%g0]ASI_DMMU, %g3	/* tag target */
	srlx	%g3, TAGTRG_CTX_RSHIFT, %g4	/* ctx from tag target */

	!! %g1 = CPU pointer
	!! %g3 = tag target
	!! %g4 = ctx

.checkdtsb0:
	! for context != 0 and unshared TSB, that ctx == TSB ctx
	brz,pn	%g4, 1f
	mov	%g3, %g2
	ld	[%g1 + CPU_TSBDS_CTXN + TSBD_CTX_INDEX], %g5
	cmp	%g5, -1
	be,pn	%icc, 1f
	nop
	! if TSB not shared, zero out context for match
	sllx	%g3, TAGTRG_VA_LSHIFT, %g2
	srlx	%g2, TAGTRG_VA_LSHIFT, %g2	! clear context
1:
	ldxa	[%g0]ASI_DMMU_TSB_PS0, %g5
	! if TSB desc. specifies xor of TSB index, do it here
	! e.g. for shared TSBs in S9 xor value is ctx << 4
	ldda	[%g5]ASI_QUAD_LDD, %g6	/* g6 = tag, g7 = data */
	cmp	%g6, %g2
	bne,pn	%xcc, .checkdtsb1	! tag mismatch
	nop
	brlz,pt %g7, .dtsbhit		! TTE valid
	nop

.checkdtsb1:
	! repeat check for second TSB
	brz,pn	%g4, 1f
	mov	%g3, %g2
	ld	[%g1 + CPU_TSBDS_CTXN + TSBD_BYTES + TSBD_CTX_INDEX], %g5
	cmp	%g5, -1
	be,pn	%icc, 1f
	nop
	! if TSB not shared, zero out context for match
	sllx	%g3, TAGTRG_VA_LSHIFT, %g2
	srlx	%g2, TAGTRG_VA_LSHIFT, %g2	! clear context
1:
	ldxa	[%g0]ASI_DMMU_TSB_PS1, %g5
	! if TSB desc. specifies xor of TSB index, do it here
	ldda	[%g5]ASI_QUAD_LDD, %g6	/* g6 = tag, g7 = data */
	cmp	%g6, %g2
	bne,pn	%xcc, .dtsbmiss		! tag mismatch
	nop
	brgez,pn %g7, .dtsbmiss		! TTE valid
	nop

.dtsbhit:
	! extract sz from tte
	TTE_SIZE(%g7, %g4, %g3, .dtsbmiss) ! XXX fault not just a miss
	sub	%g4, 1, %g5	! %g5 page mask

	! extract ra from tte
	sllx	%g7, 64 - 40, %g3
	srlx	%g3, 64 - 40 + 13, %g3
	sllx	%g3, 13, %g3	! %g3 real address
	xor	%g7, %g3, %g7	! %g7 orig tte with ra field zeroed
	andn	%g3, %g5, %g3
	ldx	[%g1 + CPU_GUEST], %g6
	!! %g1 cpu struct
	!! %g2 --
	!! %g3 raddr
	!! %g4 page size
	!! %g5 --
	!! %g6 guest struct
	!! %g7 TTE ready for pa
	RANGE_CHECK(%g6, %g3, %g4, 3f, %g5)
	REAL_OFFSET(%g6, %g3, %g3, %g4)
4:
	!! %g1 cpu struct
	!! %g3 raddr
	!! %g7 TTE ready for pa
	or	%g7, %g3, %g7	! %g7 new tte with pa

	mov	1, %g5
	sllx	%g5, NI_TTE4V_L_SHIFT, %g5
	andn	%g7, %g5, %g7	! %g7 tte (force clear lock bit)

	set	TLB_IN_4V_FORMAT, %g5	! %g5 sun4v-style tte selection
	stxa	%g7, [%g5]ASI_DTLB_DATA_IN
	!!
	!! %g1 = CPU pointer
	!! %g7 = TTE
	!!
	ldx	[%g1 + CPU_MMUSTAT_AREA], %g6
	brnz,pn	%g6, 1f
	nop

	retry

1:
	rd	%tick, %g2
	ldx	[%g1 + CPU_SCR0], %g1
	sub	%g2, %g1, %g5
	!!
	!! %g5 = %tick delta
	!! %g6 = MMU statistics area
	!! %g7 = TTE
	!!
	inc	MMUSTAT_D, %g6			/* stats + d */
	ldxa	[%g0]ASI_DMMU, %g3		/* tag target */
	srlx	%g3, TAGTRG_CTX_RSHIFT, %g4	/* ctx from tag target */
	mov	MMUSTAT_CTX0, %g1
	movrnz	%g4, MMUSTAT_CTXNON0, %g1
	add	%g6, %g1, %g6			/* stats + d + ctx */
	and	%g7, TTE_SZ_MASK, %g7
	sllx	%g7, MMUSTAT_ENTRY_SZ_SHIFT, %g7
	add	%g6, %g7, %g6			/* stats + d + ctx + pgsz */
	ldx	[%g6 + MMUSTAT_TICK], %g3
	add	%g3, %g5, %g3
	stx	%g3, [%g6 + MMUSTAT_TICK]
	ldx	[%g6 + MMUSTAT_HIT], %g3
	inc	%g3
	stx	%g3, [%g6 + MMUSTAT_HIT]
	retry
3:
	!! %g1 cpu struct
	!! %g2 --
	!! %g3 raddr
	!! %g4 page size
	!! %g5 --
	!! %g6 guest struct
	!! %g7 TTE ready for pa
	! check for IO address
	! branch back to 4b with pa in %g3
	! must preserve %g1 and %g7
	RANGE_CHECK_IO(%g6, %g3, %g4, .dmmu_miss_io_found,
	    .dmmu_miss_io_not_found, %g2, %g5)
.dmmu_miss_io_found:
	ba,a	4b
.dmmu_miss_io_not_found:

.dtsbmiss:
	ldx	[%g1 + CPU_MMU_AREA], %g2
	brz,pn	%g2, watchdog_guest
	.empty

	!! %g1 is CPU pointer
	!! %g2 is MMU Fault Status Area
	!! %g4 is context (possibly shifted - still OK for zero test)
	/* if ctx == 0 and ctx0 set TSBs used, take slow trap */
	/* if ctx != 0 and ctxnon0 set TSBs used, take slow trap */
	mov	CPU_NTSBS_CTXN, %g7
	movrz	%g4, CPU_NTSBS_CTX0, %g7
	ldx	[%g1 + %g7], %g7
	brnz,pn	%g7, .dslowmiss
	nop

.dfastmiss:
	/*
	 * Update MMU_FAULT_AREA_DATA
	 */
	mov	MMU_TAG_ACCESS, %g3
	ldxa	[%g3]ASI_DMMU, %g3	/* tag access */
	set	(NCTXS - 1), %g5
	andn	%g3, %g5, %g4
	and	%g3, %g5, %g5
	stx	%g4, [%g2 + MMU_FAULT_AREA_DADDR]
	stx	%g5, [%g2 + MMU_FAULT_AREA_DCTX]
	/* fast misses do not update MMU_FAULT_AREA_DFT with MMU_FT_FASTMISS */
	! wrpr	%g0, FAST_DMMU_MISS_TT, %tt	/* already set */
	rdpr	%pstate, %g3
	or	%g3, PSTATE_PRIV, %g3
	wrpr	%g3, %pstate
	rdpr	%tba, %g3
	add	%g3, (FAST_DMMU_MISS_TT << TT_OFFSET_SHIFT), %g3
7:
	rdpr	%tl, %g2
	cmp	%g2, 1 /* trap happened at tl=0 */
	be,pt	%xcc, 1f
	.empty
	set	TRAPTABLE_SIZE, %g5

	cmp	%g2, MAXPTL
	bgu,pn	%xcc, watchdog_guest
	add	%g5, %g3, %g3

1:
	mov	HPSTATE_GUEST, %g5	! set ENB bit
	jmp	%g3
	wrhpr	%g5, %hpstate

.dslowmiss:
	/*
	 * Update MMU_FAULT_AREA_DATA
	 */
	mov	MMU_TAG_ACCESS, %g3
	ldxa	[%g3]ASI_DMMU, %g3	/* tag access */
	set	(NCTXS - 1), %g5
	andn	%g3, %g5, %g4
	and	%g3, %g5, %g5
	stx	%g4, [%g2 + MMU_FAULT_AREA_DADDR]
	stx	%g5, [%g2 + MMU_FAULT_AREA_DCTX]
	mov	MMU_FT_MISS, %g4
	stx	%g4, [%g2 + MMU_FAULT_AREA_DFT]
	wrpr	%g0, DMMU_MISS_TT, %tt
	rdpr	%pstate, %g3
	or	%g3, PSTATE_PRIV, %g3
	wrpr	%g3, %pstate
	rdpr	%tba, %g3
	add	%g3, (DMMU_MISS_TT << TT_OFFSET_SHIFT), %g3
	ba,a	7b
	.empty
	SET_SIZE(dmmu_miss)

	/* %g2 contains guest's miss info pointer (hv phys addr) */
	ENTRY_NP(dmmu_prot)
	/*
	 * TLB parity errors can cause normal MMU traps (N1 PRM
	 * section 12.3.3 and 12.3.4).  Check here for an outstanding
	 * parity error and have ue_err handle it instead.
	 */
	ldxa	[%g0]ASI_SPARC_ERR_STATUS, %g1	! SPARC err reg
	set	(SPARC_ESR_DMDU | SPARC_ESR_DMSU), %g3	! is it a dmdu/dmsu err
	btst	%g3, %g1
	bnz	%xcc, ue_err			! err handler takes care of it
	/*
	 * Update MMU_FAULT_AREA_DATA
	 */
	mov	MMU_TAG_ACCESS, %g3
	ldxa	[%g3]ASI_DMMU, %g3	/* tag access */
	set	(NCTXS - 1), %g5
	andn	%g3, %g5, %g4
	and	%g3, %g5, %g5
	stx	%g4, [%g2 + MMU_FAULT_AREA_DADDR]
	stx	%g5, [%g2 + MMU_FAULT_AREA_DCTX]
	/* fast misses do not update MMU_FAULT_AREA_DFT with MMU_FT_FASTPROT */
	wrpr	%g0, FAST_PROT_TT, %tt	/* already set? XXXQ */
	rdpr	%pstate, %g3
	or	%g3, PSTATE_PRIV, %g3
	wrpr	%g3, %pstate
	rdpr	%tba, %g3
	add	%g3, (FAST_PROT_TT << TT_OFFSET_SHIFT), %g3

	rdpr	%tl, %g2
	cmp	%g2, 1 /* trap happened at tl=0 */
	be,pt	%xcc, 1f
	.empty
	set	TRAPTABLE_SIZE, %g5

	cmp	%g2, MAXPTL
	bgu,pn	%xcc, watchdog_guest
	add	%g5, %g3, %g3

1:
	mov	HPSTATE_GUEST, %g5	! set ENB bit
	jmp	%g3
	wrhpr	%g5, %hpstate
	SET_SIZE(dmmu_prot)


/*
 * set all TSB base registers to dummy
 * call sequence:
 * in:
 *	%g7 return address
 *
 * volatile:
 *	%g1
 */
	ENTRY_NP(set_dummytsb_ctx0)
	ROOT_STRUCT(%g1)
	ldx	[%g1 + CONFIG_DUMMYTSB], %g1

	stxa	%g1, [%g0]ASI_DTSBBASE_CTX0_PS0
	stxa	%g1, [%g0]ASI_ITSBBASE_CTX0_PS0
	stxa	%g1, [%g0]ASI_DTSBBASE_CTX0_PS1
	stxa	%g1, [%g0]ASI_ITSBBASE_CTX0_PS1

	stxa	%g0, [%g0]ASI_DTSB_CONFIG_CTX0
	jmp	%g7 + 4
	stxa	%g0, [%g0]ASI_ITSB_CONFIG_CTX0
	SET_SIZE(set_dummytsb_ctx0)

	ENTRY_NP(set_dummytsb_ctxN)
	ROOT_STRUCT(%g1)
	ldx	[%g1 + CONFIG_DUMMYTSB], %g1

	stxa	%g1, [%g0]ASI_DTSBBASE_CTXN_PS0
	stxa	%g1, [%g0]ASI_ITSBBASE_CTXN_PS0
	stxa	%g1, [%g0]ASI_DTSBBASE_CTXN_PS1
	stxa	%g1, [%g0]ASI_ITSBBASE_CTXN_PS1

	stxa	%g0, [%g0]ASI_DTSB_CONFIG_CTXN
	jmp	%g7 + 4
	stxa	%g0, [%g0]ASI_ITSB_CONFIG_CTXN
	SET_SIZE(set_dummytsb_ctxN)

	ENTRY_NP(dmmu_err)
	/*
	 * TLB parity errors can cause normal MMU traps (N1 PRM
	 * section 12.3.3 and 12.3.4).  Check here for an outstanding
	 * parity error and have ue_err handle it instead.
	 */
	ldxa	[%g0]ASI_SPARC_ERR_STATUS, %g1	! SPARC err reg
	set	(SPARC_ESR_DMDU | SPARC_ESR_DMSU), %g2	! is it a dmdu/dmsu err
	btst	%g2, %g1
	bnz	%xcc, ue_err			! err handler takes care of it
	rdhpr	%htstate, %g1
	btst	HTSTATE_HPRIV, %g1
	bnz,pn	%xcc, badtrap
	rdpr	%pstate, %g1
	or	%g1, PSTATE_PRIV, %g1
	wrpr	%g1, %pstate
	rdpr	%tba, %g1
	rdpr	%tt, %g2
	sllx	%g2, 5, %g2
	add	%g1, %g2, %g1
	rdpr	%tl, %g3
	cmp	%g3, MAXPTL
	bgu,pn	%xcc, watchdog_guest
	clr	%g2
	cmp	%g3, 1
	movne	%xcc, 1, %g2
	sllx	%g2, 14, %g2

	CPU_STRUCT(%g3)
	ldx	[%g3 + CPU_MMU_AREA], %g3
	brz,pn	%g3, watchdog_guest		! Nothing we can do about this
	.empty
	!! %g3 - MMU_FAULT_AREA

	/*
	 * Update MMU_FAULT_AREA_DATA
	 */
	mov	MMU_SFAR, %g4
	ldxa	[%g4]ASI_DMMU, %g4
	stx	%g4, [%g3 + MMU_FAULT_AREA_DADDR]
	mov	MMU_SFSR, %g5
	ldxa	[%g5]ASI_DMMU, %g4 ! Capture SFSR
	stxa	%g0, [%g5]ASI_DMMU ! Clear SFSR

	mov	MMU_TAG_ACCESS, %g5
	ldxa	[%g5]ASI_DMMU, %g5
	set	(NCTXS - 1), %g6
	and	%g5, %g6, %g5
	stx	%g5, [%g3 + MMU_FAULT_AREA_DCTX]

	rdpr	%tt, %g5
	cmp	%g5, TT_DAX
	bne,pn	%xcc, 2f
	mov	MMU_FT_MULTIERR, %g6 ! unknown FT or multiple bits

	!! %g4 - sfsr
	srlx	%g4, MMU_SFSR_FT_SHIFT, %g5
	andcc	%g5, MMU_SFSR_FT_MASK, %g5
	bz,pn	%xcc, 1f
	nop
	!! %g5 - fault type
	!! %g6 - sun4v ft
	andncc	%g5, MMU_SFSR_FT_PRIV, %g0
	movz	%xcc, MMU_FT_PRIV, %g6 ! priv is only bit set
	andncc	%g5, MMU_SFSR_FT_SO, %g0
	movz	%xcc, MMU_FT_SO, %g6	! so is only bit set
	andncc	%g5, MMU_SFSR_FT_ATOMICIO, %g0
	movz	%xcc, MMU_FT_NCATOMIC, %g6 ! atomicio is only bit set
	andncc	%g5, MMU_SFSR_FT_ASI, %g0
	movz	%xcc, MMU_FT_BADASI, %g6 ! badasi is only bit set
	andncc	%g5, MMU_SFSR_FT_NFO, %g0
	movz	%xcc, MMU_FT_NFO, %g6	! nfo is only bit set
	andncc	%g5, (MMU_SFSR_FT_VARANGE | MMU_SFSR_FT_VARANGE2), %g0
	movz	%xcc, MMU_FT_VARANGE, %g6 ! varange are only bits set
1:	stx	%g6, [%g3 + MMU_FAULT_AREA_DFT]
2:	mov	HPSTATE_GUEST, %g3
	jmp	%g1 + %g2
	wrhpr	%g3, %hpstate	! keep ENB bit
	SET_SIZE(dmmu_err)

	ENTRY_NP(immu_err)
	/*
	 * TLB parity errors can cause normal MMU traps (N1 PRM
	 * section 12.3.1.  Check here for an outstanding
	 * parity error and have ue_err handle it instead.
	 */
	ldxa	[%g0]ASI_SPARC_ERR_STATUS, %g1	! SPARC err reg
	set	SPARC_ESR_IMDU, %g2		! is it a imdu err
	btst	%g2, %g1
	bnz	%xcc, ue_err			! err handler takes care of it
	rdhpr	%htstate, %g1
	btst	HTSTATE_HPRIV, %g1
	bnz,pn	%xcc, badtrap
	rdpr	%pstate, %g1
	or	%g1, PSTATE_PRIV, %g1
	wrpr	%g1, %pstate
	rdpr	%tba, %g1
	rdpr	%tt, %g2
	sllx	%g2, 5, %g2
	add	%g1, %g2, %g1
	rdpr	%tl, %g3
	cmp	%g3, MAXPTL
	bgu,pn	%xcc, watchdog_guest
	clr	%g2
	cmp	%g3, 1
	movne	%xcc, 1, %g2
	sllx	%g2, 14, %g2
	CPU_STRUCT(%g3)
	ldx	[%g3 + CPU_MMU_AREA], %g3
	brz,pn	%g3, watchdog_guest	! Nothing we can do about this
	nop
	!! %g3 - MMU_FAULT_AREA
	/* decode sfsr, update MMU_FAULT_AREA_INSTR */
	rdpr	%tpc, %g4
	stx	%g4, [%g3 + MMU_FAULT_AREA_IADDR]

	mov	MMU_PCONTEXT, %g5
	ldxa	[%g5]ASI_MMU, %g5
	movrnz	%g2, 0, %g5 ! primary ctx for TL=0, nucleus ctx for TL>0
	stx	%g5, [%g3 + MMU_FAULT_AREA_ICTX]

	!! %g6 - sun4v ft
	mov	MMU_FT_MULTIERR, %g6 ! unknown FT or multiple bits

	mov	MMU_SFSR, %g5
	ldxa	[%g5]ASI_IMMU, %g4 ! Capture SFSR
	stxa	%g0, [%g5]ASI_IMMU ! Clear SFSR
	!! %g4 - sfsr
	srlx	%g4, MMU_SFSR_FT_SHIFT, %g5
	andcc	%g5, MMU_SFSR_FT_MASK, %g5
	bz,pn	%xcc, 1f
	nop
	!! %g5 - fault type
	andncc	%g5, MMU_SFSR_FT_PRIV, %g0
	movz	%xcc, MMU_FT_PRIV, %g6 ! priv is only bit set
	andncc	%g5, (MMU_SFSR_FT_VARANGE | MMU_SFSR_FT_VARANGE2), %g0
	movz	%xcc, MMU_FT_VARANGE, %g6 ! varange are only bits set
1:	stx	%g6, [%g3 + MMU_FAULT_AREA_IFT]
	mov	HPSTATE_GUEST, %g3
	jmp	%g1 + %g2
	wrhpr	%g3, %hpstate	! keep ENB bit
	SET_SIZE(immu_err)


/*
 * revec_dax - revector the current trap to the guest's DAX handler
 *
 * %g1 - fault type
 * %g2 - fault addr
 * %g3 - fault ctx
 */
	ENTRY_NP(revec_dax)
	CPU_STRUCT(%g4)
	ldx	[%g4 + CPU_MMU_AREA], %g4
	brz,pn	%g4, watchdog_guest
	nop
	stx	%g1, [%g4 + MMU_FAULT_AREA_DFT]
	stx	%g2, [%g4 + MMU_FAULT_AREA_DADDR]
	stx	%g3, [%g4 + MMU_FAULT_AREA_DCTX]

	rdhpr	%htstate, %g1
	btst	HTSTATE_HPRIV, %g1
	bnz,pn	%xcc, badtrap
	rdpr	%pstate, %g1
	or	%g1, PSTATE_PRIV, %g1
	wrpr	%g1, %pstate
	rdpr	%tba, %g1
	mov	TT_DAX, %g2
	wrpr	%g2, 0, %tt
	sllx	%g2, 5, %g2
	add	%g1, %g2, %g1
	rdpr	%tl, %g3
	cmp	%g3, MAXPTL
	bgu,pn	%xcc, watchdog_guest
	clr	%g2
	cmp	%g3, 1
	movne	%xcc, 1, %g2
	sllx	%g2, 14, %g2
	mov	HPSTATE_GUEST, %g3
	jmp	%g1 + %g2
	wrhpr	%g3, %hpstate	! keep ENB bit
	SET_SIZE(revec_dax)

/*
 * revec_iax - revector the current trap to the guest's IAX handler
 *
 * %g1 - fault type
 * %g2 - fault addr
 * %g3 - fault ctx
 */
	ENTRY_NP(revec_iax)
	CPU_STRUCT(%g4)
	ldx	[%g4 + CPU_MMU_AREA], %g4
	brz,pn	%g4, watchdog_guest
	nop
	stx	%g1, [%g4 + MMU_FAULT_AREA_IFT]
	stx	%g2, [%g4 + MMU_FAULT_AREA_IADDR]
	stx	%g3, [%g4 + MMU_FAULT_AREA_ICTX]

	rdhpr	%htstate, %g1
	btst	HTSTATE_HPRIV, %g1
	bnz,pn	%xcc, badtrap
	rdpr	%pstate, %g1
	or	%g1, PSTATE_PRIV, %g1
	wrpr	%g1, %pstate
	rdpr	%tba, %g1
	mov	TT_IAX, %g2
	wrpr	%g2, 0, %tt
	sllx	%g2, 5, %g2
	add	%g1, %g2, %g1
	rdpr	%tl, %g3
	cmp	%g3, MAXPTL
	bgu,pn	%xcc, watchdog_guest
	clr	%g2
	cmp	%g3, 1
	movne	%xcc, 1, %g2
	sllx	%g2, 14, %g2
	mov	HPSTATE_GUEST, %g3
	jmp	%g1 + %g2
	wrhpr	%g3, %hpstate	! keep ENB bit
	SET_SIZE(revec_iax)
