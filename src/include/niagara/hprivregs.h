/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _NIAGARA_HPRIVREGS_H
#define	_NIAGARA_HPRIVREGS_H

#pragma ident	"@(#)hprivregs.h	1.16	05/11/23 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Niagara %ver
 */
#define	VER_MASK_SHIFT		24
#define	VER_MASK_MASK		0xff
#define	VER_MASK_MAJOR_SHIFT	(VER_MASK_SHIFT + 4)
#define	VER_MASK_MAJOR_MASK	0xf

/*
 * Hardware-implemented register windows
 */
#define	NWINDOWS	8

/*
 * Number of unique interrupts per strand
 */
#define	MAXINTR		64

/*
 * Max number of Global levels
 */
#define	MAXGL		3

/*
 * Maximum number of ASI_QUEUE queue entries
 */
#define	MAX_QUEUE_ENTRIES	256

/*
 * Strand Status Register
 */
#define	STR_STATUS_REG	%asr26

#define	STR_STATUS_STRAND_ACTIVE	1
#define	STR_STATUS_STRAND_ID_SHIFT	8
#define	STR_STATUS_STRAND_ID_MASK	0x3
#define	STR_STATUS_CORE_ID_SHIFT	10
#define	STR_STATUS_CORE_ID_MASK		0x7

#define	STR_STATUS_CPU_ID_SHIFT		STR_STATUS_STRAND_ID_SHIFT
#define	STR_STATUS_CPU_ID_MASK		0x1f

/*
 * hpstate:
 *
 * +-----------------------------------------------------+
 * | rsvd | ENB | rsvd | RED | rsvd | HPRIV | rsvd | TLZ |
 * +-----------------------------------------------------+
 *  63..12  11   10..6    5    4..3     2       1     0
 */

#define	HPSTATE_TLZ	0x0001
#define	HPSTATE_HPRIV	0x0004
#define	HPSTATE_RED	0x0020
#define	HPSTATE_ENB	0x0800

#define	HPSTATE_GUEST	(HPSTATE_ENB)

/*
 * htstate:
 *
 * +-----------------------------------------+
 * | rsvd |  RED | rsvd | HPRIV | rsvd | TLZ |
 * +-----------------------------------------+
 *  63..6     5    4..3     2       1     0
 */

#define	HTSTATE_TLZ	0x0001
#define	HTSTATE_HPRIV	0x0004
#define	HTSTATE_RED	0x0010
#define	HTSTATE_ENB	0x0800

/*
 * hstickpending:
 *
 * +------------+
 * | rsvd | HSP |
 * +------------+
 *  63..1    0
 */

#define	HSTICKPEND_HSP	0x1

/*
 * htba:
 *
 * +---------------------------+
 * |    TBA     | TBATL | rsvd |
 * +---------------------------+
 *     63..15      14    13..0
 */
#define	TBATL		0x4000
#define	TBATL_SHIFT	14

/*
 * TLB demap register bit definitions
 * (ASI_DMMU_DEMAP/ASI_IMMU_DEMAP)
 */
#define	TLB_R_BIT		(0x200)
#define	TLB_DEMAP_PAGE_TYPE	0x00
#define	TLB_DEMAP_CTX_TYPE	0x40
#define	TLB_DEMAP_ALL_TYPE	0x80
#define	TLB_DEMAP_PRIMARY	0x00
#define	TLB_DEMAP_SECONDARY	0x10
#define	TLB_DEMAP_NUCLEUS	0x20

/*
 * TLB DATA IN ASI VA bits
 * (ASI_DTLB_DATA_IN/ASI_ITLB_DATA_IN)
 */
#define	TLB_IN_4V_FORMAT	(1 << 10)
#define	TLB_IN_REAL		(1 << 9)

/*
 * LSU Control Register
 */
#define	ASI_LSUCR	0x45
#define	LSUCR_IC	0x000000001	/* I$ enable */
#define	LSUCR_DC	0x000000002	/* D$ enable */
#define	LSUCR_IM	0x000000004	/* IMMU enable */
#define	LSUCR_DM	0x000000008	/* DMMU enable */

/*
 * Misc
 */
#define	L2_CTL_REG	0xa900000000
#define	L2CR_DIS	0x00000001	/* L2$ Disable */
#define	L2CR_DMMODE	0x00000002	/* L2$ Direct-mapped mode */
#define	L2CR_SCRUBEN	0x00000004	/* L2$ Hardware scrub enable */

#define	IOBBASE		0x9800000000
#define	INT_MAN		0x000
#define	INT_CTL		0x400
#define	INT_VEC_DIS	0x800
#define	PROC_SER_NUM	0x820
#define	CORE_AVAIL	0x830
#define	IOB_FUSE	0x840
#define	J_INT_VEC	0xa00

#define	IOBINT		0x9f00000000
#define	J_INT_DATA0	0x600
#define	J_INT_DATA1	0x700
#define	J_INT_BUSY	0x900	/* step 8 count 32 */
#define	J_INT_ABUSY	0xb00	/* aliased to current strand's J_INT_BUSY */

#define	J_INT_BUSY_BUSY	0x0020
#define	J_INT_BUSY_SRC_MASK 0x0001f

#define	SSI_LOG		0xff00000018
#define	SSI_TIMEOUT	0xff00010088

/*
 * INT_VEC_DIS constants
 */
#define	INT_VEC_DIS_TYPE_SHIFT	16
#define	INT_VEC_DIS_VCID_SHIFT	8
#define	INT_VEC_DIS_TYPE_INT	0x0
#define	INT_VEC_DIS_TYPE_RESET	0x1
#define	INT_VEC_DIS_TYPE_IDLE	0x2
#define	INT_VEC_DIS_TYPE_RESUME	0x3


/*
 * Interrupt Vector Dispatch Macros
 */
/*
 * INT_VEC_DSPCH_ONE - interrupt vector dispatch one target
 *
 * Sends interrupt TYPE to any strand including the executing one.
 *
 * Delay Slot: no
 */
#define	INT_VEC_DSPCH_ONE(TYPE, tgt, scr1, scr2) \
	setx	IOBBASE + INT_VEC_DIS, scr1, scr2			;\
	set	(TYPE) << INT_VEC_DIS_TYPE_SHIFT, scr1			;\
	sllx	tgt, INT_VEC_DIS_VCID_SHIFT, tgt			;\
	or	scr1, tgt, scr1						;\
	stx	scr1, [scr2]

/*
 * INT_VEC_DSPCH_ALL - interrupt vector dispatch all
 *
 * Sends interrupt TYPE to all strands whose bit is set in SRC, excluding
 *   the executing one. SRC and DST bitmasks are updated.
 *
 * Delay Slot: no
 */
#define	INT_VEC_DSPCH_ALL(TYPE, SRC, DST, scr1, scr2) \
	.pushlocals							;\
	rd	STR_STATUS_REG, scr2		/* my ID             */	;\
	srlx	scr2, STR_STATUS_CPU_ID_SHIFT, scr2			;\
	and	scr2, STR_STATUS_CPU_ID_MASK, scr2			;\
	mov	1, scr1							;\
	sllx	scr1, scr2, scr1		/* my bit            */	;\
	ldx	[SRC], scr2			/* Source state      */	;\
	stx	scr1, [SRC]			/* new Source        */	;\
	bclr	scr1, scr2			/* clear my bit      */	;\
	ldx	[DST], scr1			/* Destination state */	;\
	bset	scr2, scr1			/* add new bits      */	;\
	stx	scr1, [DST]			/* new To            */	;\
	setx	IOBBASE + INT_VEC_DIS, scr1, DST			;\
	set	(TYPE) << INT_VEC_DIS_TYPE_SHIFT, scr1			;\
1:	btst	1, scr2				/* valid strand?     */	;\
	bnz,a,pn %xcc, 2f			/*   yes: store      */	;\
	  stx	scr1, [DST]			/*   no: annul       */	;\
2:	srlx	scr2, 1, scr2			/* next strand bit   */	;\
	brnz	scr2, 1b			/* more to do        */	;\
	  inc	1 << INT_VEC_DIS_VCID_SHIFT, scr1			;\
	.poplocals

/*
 * IDLE_ALL_STRAND
 *
 * Sends interrupt IDLE to all strands whose bit is set in CONFIG_STACTIVE,
 * excluding the executing one. CONFIG_STACTIVE, CONFIG_STIDLE are
 * updated.
 *
 * Delay Slot: no
 */
#define	IDLE_ALL_STRAND(cpup, scr1, scr2, scr3, scr4) \
	CPU2ROOT_STRUCT(cpup, scr1)		/* ->config*/		;\
	add	scr1, CONFIG_STACTIVE, scr3	/* ->active mask */	;\
	add	scr1, CONFIG_STIDLE, scr4	/* ->idle mask   */	;\
	INT_VEC_DSPCH_ALL(INT_VEC_DIS_TYPE_IDLE, scr3, scr4, scr1, scr2)

/*
 * RESUME_ALL_STRAND
 *
 * Sends interrupt RESUME to all strands whose bit is set in CONFIG_STIDLE,
 * excluding the executing one. CONFIG_STACTIVE, CONFIG_STIDLE are
 * updated.
 *
 * Delay Slot: no
 */
#define	RESUME_ALL_STRAND(cpup,scr1, scr2, scr3, scr4) \
	CPU2ROOT_STRUCT(cpup, scr1)		/* ->config*/		;\
	add	scr1, CONFIG_STIDLE, scr3	/* ->idle mask   */	;\
	add	scr1, CONFIG_STACTIVE, scr4	/* ->active mask */	;\
	INT_VEC_DSPCH_ALL(INT_VEC_DIS_TYPE_RESUME, scr3, scr4, scr1, scr2)

#define	IS_STRAND_(state, cpup, strand, scr1, scr2) \
	mov	1, scr1				/* bit */		;\
	sllx	scr1, strand, scr1		/* 1<<strand */		;\
	CPU2ROOT_STRUCT(cpup, scr2)		/* ->config*/		;\
	ldx	[scr2 + state], scr2		/* state mask */	;\
	btst	scr1, scr2			/* set cc */

#define	IS_STRAND_ACTIVE(cpup, strand, scr1, scr2) \
	IS_STRAND_(CONFIG_STACTIVE, cpup, strand, scr1, scr2)

#define	IS_STRAND_HALT(cpup, strand, scr1, scr2) \
	IS_STRAND_(CONFIG_STHALT, cpup, strand, scr1, scr2)

#define	IS_STRAND_IDLE(cpup, strand, scr1, scr2) \
	IS_STRAND_(CONFIG_STIDLE, cpup, strand, scr1, scr2)

#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA_HPRIVREGS_H */
