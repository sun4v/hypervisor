/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _NIAGARA_MMU_H
#define	_NIAGARA_MMU_H

#pragma ident	"@(#)mmu.h	1.19	05/10/19 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Niagara MMU properties
 */
#define	NCTXS	8192
#define	NVABITS	48

#define	PADDR_IO_BIT	39


/*
 * Only support TSBs for the two hardware TSB page size indexes.
 */
#define	MAX_NTSB	2

/*
 * ASI_[DI]MMU registers
 */
#define	MMU_SFSR	0x18
#define	MMU_SFAR	0x20
#define	MMU_TAG_ACCESS	0x30
#define	MMU_TAG_TARGET	0x00
#define	TAGACC_CTX_LSHIFT	(64-13)
#define	TAGTRG_CTX_RSHIFT	48
#define	TAGTRG_VA_LSHIFT	22

/*
 * ASI_[ID]TSBBASE_CTX*
 */
#define	TSB_SZ0_ENTRIES		512
#define	TSB_SZ0_SHIFT		9	/* LOG2(TSB_SZ0_ENTRIES) */
#define	TSB_MAX_SZCODE		15

/*
 * ASI_[ID]TSB_CONFIG_CTX*
 */
#define	ASI_TSB_CONFIG_PS1_SHIFT	8

/*
 * ASI_[DI]MMU_DEMAP
 */
#define	DEMAP_ALL	0x2

/*
 * ASI_TLB_INVALIDATE
 */
#define	I_INVALIDATE	0x0
#define	D_INVALIDATE	0x8

/*
 * Niagara SFSR
 */
#define	MMU_SFSR_FV	(0x1 << 0)
#define	MMU_SFSR_OW	(0x1 << 1)
#define	MMU_SFSR_W	(0x1 << 2)
#define	MMU_SFSR_CT	(0x3 << 4)
#define	MMU_SFSR_E	(0x1 << 6)
#define	MMU_SFSR_FT_MASK	(0x7f)
#define	MMU_SFSR_FT_SHIFT	(7)
#define	MMU_SFSR_FT	(MMU_SFSR_FT_MASK << MMU_SFSR_FT_SHIFT)
#define	MMU_SFSR_ASI_MASK	(0xff)
#define	MMU_SFSR_ASI_SHIFT	(16)
#define	MMU_SFSR_ASI	(MMU_SFSR_ASI_MASK << MMU_SFSR_ASI_SHIFT)

#define	MMU_SFSR_FT_PRIV	(0x01) /* Privilege violation */
#define	MMU_SFSR_FT_SO		(0x02) /* side-effect load from E-page */
#define	MMU_SFSR_FT_ATOMICIO	(0x04) /* atomic access to IO address */
#define	MMU_SFSR_FT_ASI		(0x08) /* illegal ASI/VA/RW/SZ */
#define	MMU_SFSR_FT_NFO		(0x10) /* non-load from NFO page */
#define	MMU_SFSR_FT_VARANGE	(0x20) /* d-mmu, i-mmu branch, call, seq */
#define	MMU_SFSR_FT_VARANGE2	(0x40) /* i-mmu jmpl or return */

/*
 * Native (sun4u) tte format
 */
#define	TTE4U_V		0x8000000000000000
#define	TTE4U_SZL	0x6000000000000000
#define	TTE4U_NFO	0x1000000000000000
#define	TTE4U_IE	0x0800000000000000
#define	TTE4U_SZH	0x0001000000000000
#define	TTE4U_DIAG	0x0000ff0000000000
#define	TTE4U_PA_SHIFT	13
#define	TTE4U_L		0x0000000000000040
#define	TTE4U_CP	0x0000000000000020
#define	TTE4U_CV	0x0000000000000010
#define	TTE4U_E		0x0000000000000008
#define	TTE4U_P		0x0000000000000004
#define	TTE4U_W		0x0000000000000002

/*
 * Niagara's sun4v format - bit 61 is lock, which is a SW bit
 * in the sun4v spec and must be cleared on TTEs passed from guest.
 */
#define	NI_TTE4V_L_SHIFT	61

/*
 * Convert a real address to a physical address
 * Args:
 *	hstruct - hypervisor partition state struct (preserved)
 *	raddr - real address
 *	paddr - physical address (may be same reg as raddr)
 *	scr - scratch register
 */
/* BEGIN CSTYLED */
#define	REAL_OFFSET(hstruct, raddr, paddr, scr)		\
	ldx	[hstruct + GUEST_MEM_OFFSET], scr	;\
	add	raddr, scr, paddr
/* END CSTYLED */
#define	GUEST_R2P_ADDR	REAL_OFFSET

/*
 * Convert a physical address to a real address
 * Args:
 *	hstruct - hypervisor partition state struct (preserved)
 *	raddr - real address
 *	paddr - physical address (may be same reg as raddr)
 *	scr - scratch register
 */
/* BEGIN CSTYLED */
#define	GUEST_P2R_ADDR(hstruct, paddr, raddr, scr)	\
	ldx	[hstruct + GUEST_MEM_OFFSET], scr	;\
	sub	paddr, scr, raddr
/* END CSTYLED */

#define RADDR_IS_IO_XCCNEG(addr, scr1)			\
	sllx    addr, (63 - PADDR_IO_BIT), scr1		;\
	tst     scr1

/*
 * Check the range of a real address for the partition described
 * by hstruct.  Branches to fail_label on failure.
 * Only scr is modified.  size may be a small constant or register.
 * XXX need to prevent overflow of raddr +size, subtract to normalize base
 */
/* BEGIN CSTYLED */
#define	RANGE_CHECK(hstruct, raddr, size, fail_label, scr) \
	ldx	[hstruct + GUEST_REAL_BASE], scr	;\
	cmp	raddr, scr				;\
	ldx	[hstruct + GUEST_REAL_LIMIT], scr	;\
	blu,pn	%xcc, fail_label			;\
	sub	scr, size, scr				;\
	inc	scr	/* XXX */			;\
	cmp	raddr, scr				;\
	bgu,pn	%xcc, fail_label			;\
	nop
/* END CSTYLED */

/*
 * XXX Fails to take into account mapping size
 */
/* BEGIN CSTYLED */
#define	IN_RANGE(cpustruct, addr, pa, base, offset, size,	\
    fail_label, tmp1, tmp2)				\
	ldx	[cpustruct + CPU_GUEST], tmp1		;\
	ldx	[tmp1 + offset], tmp2			;\
	add	addr, tmp2, tmp2			;\
	ldx	[tmp1 + base], pa			;\
	ldx	[tmp1 + size], tmp1			;\
	cmp	tmp2, pa				;\
	blu,pn	%xcc, fail_label			;\
	add	pa, tmp1, tmp1				;\
	cmp	tmp2, tmp1				;\
	bgeu,pn	%xcc, fail_label			;\
	mov	tmp2, pa
/* END CSTYLED */


#ifdef CONFIG_FIRE
#ifdef CONFIG_IOBYPASS
/*
 * For a guest which is allowed direct access to the I/O bridges (Tomatillo,
 * Fire), this checks for the I/O physical addresses.
 */
/* BEGIN CSTYLED */
#define	RANGE_CHECK_IO(hstruct, raddr, size, pass_label, fail_label, \
    scr1, scr2) \
	/* ldx	[hstruct + GUEST_IOBYPASS], scr1 */	;\
	/* brz,pn	scr1, fail_label */		;\
	/* .empty			*/		;\
	setx	0x800e000000, scr2, scr1		;\
	cmp	raddr, scr1 				;\
	blu,pn	%xcc, fail_label			;\
	.empty						;\
	setx	0x8010000000, scr2, scr1 		;\
	add	raddr, size, scr2			;\
	cmp	scr2, scr1				;\
	blu,pt	%xcc, pass_label			;\
	.empty						;\
	setx	0xc000000000, scr2, scr1		;\
	cmp	raddr, scr1				;\
	blu,pn	%xcc, fail_label			;\
	.empty						;\
	setx	0xff00000000, scr2, scr1		;\
	add	raddr, size, scr2			;\
	cmp	scr2, scr1				;\
	bgu,pn	%xcc, fail_label			;\
	nop
/* END CSTYLED */
#else /* !CONFIG_IOBYPASS */
/* BEGIN CSTYLED */
#define RANGE_CHECK_IO_ONE(raddr, size, lo, hi, pass_label, scr1, scr2)	\
	.pushlocals			;\
	setx	lo, scr2, scr1 		;\
	cmp	raddr, scr1 		;\
	blu,pn	%xcc, 1f		;\
	.empty				;\
	setx	hi, scr2, scr1 		;\
	add	raddr, size, scr2	;\
	cmp	scr2, scr1		;\
	bleu,pt	%xcc, pass_label	;\
	nop				;\
1:;	.poplocals

#define	RANGE_CHECK_IO(hstruct, raddr, size, pass_lbl, fail_lbl, scr1, scr2) \
	RANGE_CHECK_IO_ONE(raddr, size, FIRE_IOBASE(A), FIRE_IOLIMIT(A), \
	   pass_lbl, scr1, scr2)					;\
	RANGE_CHECK_IO_ONE(raddr, size, FIRE_IOBASE(B), FIRE_IOLIMIT(B), \
	   pass_lbl, scr1, scr2)					;\
	RANGE_CHECK_IO_ONE(raddr, size, FIRE_EBUSBASE, FIRE_EBUSLIMIT,	 \
	   pass_lbl, scr1, scr2)					;\
	ba,pt	%xcc, fail_lbl						;\
	nop
/* END CSTYLED */
#endif
#else /* !CONFIG_FIRE */
/* BEGIN CSTYLED */
#define	RANGE_CHECK_IO(hstruct, raddr, size, pass_lbl, fail_lbl,	\
	scr1, scr2)		\
	ba,a	fail_lbl	;\
	.empty
/* END CSTYLED */
#endif

#define	MMU_VALID_FLAGS_MASK	(MAP_ITLB | MAP_DTLB)

/*
 * Check that only valid flags bits are set and that at least
 * one TLB selector is set. If optional flags are added,
 * the simplistic 'brz' will have to be changed.
 */
/* BEGIN CSTYLED */
#define	CHECK_MMU_FLAGS(flags, fail_label)		\
	brz,pn	flags, fail_label			;\
	andncc	flags, MMU_VALID_FLAGS_MASK, %g0	;\
	bnz,pn	%xcc, fail_label			;\
	nop

/*
 * Check the virtual address and context for validity
 * on Niagara
 */
#define	CHECK_CTX(ctx, fail_label, scr)		\
	set	NCTXS, scr				;\
	cmp	ctx, scr				;\
	bgeu,pn	%xcc, fail_label			;\
	nop
#define	CHECK_VA_CTX(va, ctx, fail_label, scr)		\
	sllx	va, (64 - NVABITS), scr			;\
	srax	scr, (64 - NVABITS), scr		;\
	cmp	va, scr					;\
	bne,pn	%xcc, fail_label			;\
	CHECK_CTX(ctx, fail_label, scr)
/* END CSTYLED */

/*
 * Supported page size encodings for Niagara
 */
#define	TTE_VALIDSIZEARRAY		\
	    ((1 << 0) |	/* 8K */	\
	    (1 << 1) |	/* 64k */	\
	    (1 << 3) |	/* 4M */	\
	    (1 << 5))	/* 256M */


#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA_MMU_H */
