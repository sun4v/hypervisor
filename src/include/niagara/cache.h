/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#pragma ident	"@(#)cache.h	1.7	05/09/13 SMI"

/*
 * I/D/L2 Cache definitions
 */

/*
 * L2 cache index
 */
#define	L2_BANK_SHIFT		6
#define	L2_BANK_MASK		(0x3)
#define	L2_SET_SHIFT		8
#define	L2_SET_MASK		(0x3FF)
#define	L2_WAY_SHIFT		18
#define	L2_WAY_MASK		(0xF)
#define	NO_L2_BANKS		4

#define	L2_LINE_SHIFT		6
#define	L2_LINE_SIZE		(1 << L2_LINE_SHIFT)	/* 64 */
#define	N_LONG_IN_LINE		(L2_LINE_SIZE / SIZEOF_UI64)
#define	L2_NUM_WAYS		12

#define	L2_CSR_BASE		(0xa0 << 32)

/*
 * L2 Control Register definitions (Count 4 Step 64)
 */
#define	L2_CONTROL_REG		(0xa9 << 32)
#define	L2_DIS_SHIFT		0
#define	L2_DIS			(1 << L2_DIS_SHIFT)
#define	L2_DMMODE_SHIFT		1
#define	L2_DMMODE		(1 << L2_DMMODE_SHIFT)
#define	L2_SCRUBENABLE_SHIFT	2
#define	L2_SCRUBENABLE		(1 << L2_SCRUBENABLE_SHIFT)
#define	L2_SCRUBINTERVAL_SHIFT	3
#define	L2_SCRUBINTERVAL_MASK	(0xfff << L2_SCRUBENABLE_SHIFT)
#define	L2_ERRORSTEER_SHIFT	15
#define	L2_ERRORSTEER_MASK	(0x1f << L2_ERRORSTEER_SHIFT)
#define	L2_DBGEN_SHIFT		20
#define	L2_DBGEN		(1 << L2_DBGEN_SHIFT)
#define	L2_DIRCLEAR_SHIFT	21
#define	L2_DIRCLEAR		(1 << L2_DBGEN_SHIFT)

/*
 * L2 Error Enable Register (Count 4 Step 64)
 */
#define	L2_EEN_BA		0xaa
#define	L2_EEN_BASE		(L2_EEN_BA << 32)
#define	L2_EEN_STEP		0x40
#define	DEBUG_TRIG_EN		(1 << 2)	/* Debug Port Trigger enable */

#define	SET_L2_EEN_BASE(reg) \
	mov	L2_EEN_BA, reg;\
	sllx	reg, 32, reg
#define	GET_L2_BANK_EEN(bank, dst, scr1) \
	SET_L2_EEN_BASE(scr1)			/* Error Enable Register */	;\
	sllx	bank, L2_BANK_SHIFT, dst	/* bank offset */		;\
	ldx	[scr1 + dst], dst		/* get current */
#define	BTST_L2_BANK_EEN(bank, bits, scr1, scr2) \
	GET_L2_BANK_EEN(bank, scr1, scr2)	/* get current */	 	;\
	btst	bits, scr1			/* test bit(s) */
#define	BCLR_L2_BANK_EEN(bank, bits, scr1, scr2) \
	.pushlocals								;\
	SET_L2_EEN_BASE(scr2)			/* Error Enable Register */	;\
	sllx	bank, L2_BANK_SHIFT, scr1	/* bank offset */		;\
	add	scr2, scr1, scr2		/* bank address */		;\
	ldx	[scr2], scr1			/* get current */	 	;\
	btst	bits, scr1			/* reset? */			;\
	bz,pn	%xcc, 9f			/*   yes: return cc=z */	;\
	  bclr	bits, scr1			/* reset bit(s) */		;\
	stx	scr1, [scr2]			/* store back */		;\
9:	.poplocals				/* success: cc=nz */
#define	BSET_L2_BANK_EEN(bank, bits, scr1, scr2) \
	SET_L2_EEN_BASE(scr2)			/* Error Enable Register */	;\
	sllx	bank, L2_BANK_SHIFT, scr1	/* bank offset */		;\
	add	scr2, scr1, scr2		/* bank address */		;\
	ldx	[scr2], scr1			/* get current */	 	;\
	bset	bits, scr1			/* set bit(s) */		;\
	stx	scr1, [scr2]			/* store back */

/*
 * L2 Error Status Register (Count 4 Step 64)
 */
#define	L2_ESR_BA		0xab
#define	L2_ESR_BASE		(L2_ESR_BA << 32)
#define	L2_ESR_STEP		0x40
#define	L2_BANK_STEP		0x40
#define	L2_ESR_MEU		(1 << 63)
#define	L2_ESR_MEC		(1 << 62)
#define	L2_ESR_RW		(1 << 61)
#define	L2_ESR_MODA		(1 << 59)
#define	L2_ESR_VCID_SHIFT	54
#define	L2_ESR_VCID_MASK	0x1f
#define	L2_ESR_VCID		(L2_ESR_VCID_MASK << L2_ESR_VCID_SHIFT)
#define	L2_ESR_LDAC		(1 << 53)
#define	L2_ESR_LDAU		(1 << 52)
#define	L2_ESR_LDWC		(1 << 51)
#define	L2_ESR_LDWU		(1 << 50)
#define	L2_ESR_LDRC		(1 << 49)
#define	L2_ESR_LDRU		(1 << 48)
#define	L2_ESR_LDSC		(1 << 47)
#define	L2_ESR_LDSU		(1 << 46)
#define	L2_ESR_LTC		(1 << 45)
#define	L2_ESR_LRU		(1 << 44)
#define	L2_ESR_LVU		(1 << 43)
#define	L2_ESR_DAC		(1 << 42)
#define	L2_ESR_DAU		(1 << 41)
#define	L2_ESR_DRC		(1 << 40)
#define	L2_ESR_DRU		(1 << 39)
#define	L2_ESR_DSC		(1 << 38)
#define	L2_ESR_DSU		(1 << 37)
#define	L2_ESR_VEC		(1 << 36)
#define	L2_ESR_VEU		(1 << 35)
#define	L2_ESR_SYND_SHIFT	0
#define	L2_ESR_SYND_MASK	0xffffffff
#define	L2_ESR_SYND		(L2_ESR_SYND_MASK << L2_ESR_SYND_SHIFT)

#define	L2_ERROR_STATUS_CLEAR	0xc03ffff800000000

/*
 * L2 Error Address Register (Count 4 Step 64)
 */
#define	L2_EAR_BA		0xac
#define	L2_EAR_BASE		(L2_EAR_BA << 32)

/*
 * L2 diagnostic tag fields
 */
#define	L2_PA_TAG_SHIFT		18
#ifdef _ASM
#define	L2_PA_TAG_MASK		0xfffffc0000
#else
#define	L2_PA_TAG_MASK		(0x3fffffULL << L2_PA_TAG_SHIFT)
#endif
#define	L2_TAG_SHIFT		6
#ifdef _ASM
#define	L2_TAG_MASK		0xfffffc0
#else
#define	L2_TAG_MASK		(0x3fffffULL << L2_TAG_SHIFT)
#endif
#define	L2_TAG(pa)		((pa & L2_PA_TAG_MASK) >> L2_PA_TAG_SHIFT)

#define	L2_TAG_ECC_SHIFT	0
#define	L2_TAG_ECC_MASK		(0x3fULL << L2_TAG_ECC_SHIFT)

#define	L2_TAG_DIAG_SELECT		0xa4
#define	L2_TAG_DIAG_SELECT_SHIFT	32
#define	L2_INDEX_MASK			(L2_SET_MASK << L2_SET_SHIFT) | (L2_BANK_MASK << L2_BANK_SHIFT)

/*
 * L1 icache
 */
#define	ICACHE_MAX_WAYS		4
#define	ICACHE_NUM_OF_WORDS	8

/*
 * L1 Instruction Cache Data Diagnostic Addressing
 */
#define	ICACHE_INSTR_WAY_SHIFT	16
#define	ICACHE_INSTR_WAY_MASK	(0x2 << ICACHE_INSTR_WAY_SHIFT)
#define	ICACHE_INSTR_SET_SHIFT	6
#define	ICACHE_INSTR_SET_MASK	(0x7f << ICACHE_INSTR_SET_SHIFT)
#define	ICACHE_INSTR_WORD_SHIFT	3
#define	ICACHE_INSTR_WORD_MASK	(0x3 << ICACHE_INSTR_WORD_SHIFT)

#define ICACHE_PA_SET_SHIFT	5
#define	ICACHE_PA_SET_MASK	(0x7f << ICACHE_PA_SET_SHIFT)	
#define	ICACHE_PA_WORD_SHIFT	2
#define	ICACHE_PA_WORD_MASK	(0x3 << ICACHE_PA_WORD_SHIFT)

/*
 * L1 Instruction Cache Tag Diagnostic Addressing
 */
#define	ICACHE_TAG_WAY_SHIFT	16
#define	ICACHE_TAG_WAY_MASK	(0x2 << ICACHE_TAG_WAY_SHIFT)
#define	ICACHE_TAG_SET_SHIFT	6
#define	ICACHE_TAG_SET_MASK	(0x7f << ICACHE_TAG_SET_SHIFT)
#define	ICACHE_PA2SET_SHIFT	5
#define	ICACHE_PA2SET_MASK	(0x7f << ICACHE_PA2SET_SHIFT)
#define	ICACHE_SETFROMPA_SHIFT	1
#define	ICACHE_TAG_VALID	34

/*
 * L1 Data Cache Diagnostic Addressing
 */
#define	DCACHE_MAX_WAYS		4
#define	DCACHE_NUM_OF_WORDS	2
#define	DCACHE_WAY_SHIFT	11
#define	DCACHE_SET_MASK		0x7f
#define	DCACHE_SET_SHIFT	4
#define	DCACHE_SET		(DCACHE_SET_MASK << DCACHE_SET_SHIFT)
#define	DCACHE_TAG_MASK		0x3ffffffe
#define	DCACHE_TAG_SHIFT	11
#define	DCACHE_TAG_VALID	1
#define	DCACHE_WORD_MASK	0x1
#define	DCACHE_WORD_SHIFT	3
