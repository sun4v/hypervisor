/*
 * Copyright 2002 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _NIAGARA_TRAPS_H
#define _NIAGARA_TRAPS_H

#pragma ident	"@(#)traps.h	1.3	04/07/22 SMI"

/*
 * Niagara trap types
 */

#ifdef __cplusplus
extern "C" {
#endif

#define	MAXTL		6
#define	MAXGL		3

#define	TT_POR		0x1	/* power-on reset */
#define	TT_WDR		0x2	/* watchdog reset */
#define	TT_XIR		0x3	/* eXternally-initiated reset */
#define	TT_SIR		0x4	/* software-initiated reset */
#define	TT_RED		0x5	/* RED state exception */
#define	TT_IAX		0x8	/* instruction access exception */
#define	TT_IMMUMISS	0x9	/* instruction access mmu miss */
#define	TT_IAE		0xa	/* instruction access error */
#define	TT_ILLINST	0x10	/* illegal instruction */
#define	TT_PRIVOP	0x11	/* privileged opcode */
#define	TT_UNIMP_LDD	0x12	/* unimplemented LDD */
#define	TT_UNIMP_STD	0x13	/* unimplemented STD */
#define	TT_FP_DISABLED	0x20	/* fp disabled */
#define	TT_FP_IEEE754	0x21	/* IEEE 754 exception */
#define	TT_FP_OTHER	0x22	/* fp other */
#define	TT_TAGOVERFLOW	0x23	/* tag overflow */
#define	TT_CLEANWIN	0x24	/* cleanwin (BIG) */
#define	TT_DIV0		0x28	/* division by zero */
#define	TT_PROCERR	0x29	/* internal processor error */
#define	TT_DAX		0x30	/* data access exception */
#define	TT_DMMUMISS	0x31	/* data access mmu miss */
#define	TT_DAE		0x32	/* data access error */
#define	TT_DAP		0x33	/* data access protection */
#define	TT_ALIGN	0x34	/* mem address not aligned */
#define	TT_LDDF_ALIGN	0x35	/* LDDF mem address not aligned */
#define	TT_STDF_ALIGN	0x36	/* STDF mem address not aligned */
#define	TT_PRIVACT	0x37	/* privileged action */
#define	TT_LDQF_ALIGN	0x38	/* LDQF mem address not aligned */
#define	TT_STQF_ALIGN	0x39	/* STQF mem address not aligned */
#define	TT_REALMISS	0x3f	/* read translation miss trap */
#define	TT_ASYNCERR	0x40	/* async data error */
#define	TT_INTR_LEV1	0x41	/* interrupt level 1 */
#define	TT_INTR_LEV2	0x42	/* interrupt level 2 */
#define	TT_INTR_LEV3	0x43	/* interrupt level 3 */
#define	TT_INTR_LEV4	0x44	/* interrupt level 4 */
#define	TT_INTR_LEV5	0x45	/* interrupt level 5 */
#define	TT_INTR_LEV6	0x46	/* interrupt level 6 */
#define	TT_INTR_LEV7	0x47	/* interrupt level 7 */
#define	TT_INTR_LEV8	0x48	/* interrupt level 8 */
#define	TT_INTR_LEV9	0x49	/* interrupt level 9 */
#define	TT_INTR_LEVa	0x4a	/* interrupt level a */
#define	TT_INTR_LEVb	0x4b	/* interrupt level b */
#define	TT_INTR_LEVc	0x4c	/* interrupt level c */
#define	TT_INTR_LEVd	0x4d	/* interrupt level d */
#define	TT_INTR_LEVe	0x4e	/* interrupt level e */
#define	TT_INTR_LEVf	0x4f	/* interrupt level f */
#define	TT_HSTICK	0x5e	/* hstick match interrupt */
#define	TT_LEVEL0	0x5f	/* trap level 0 */
#define	TT_VECINTR	0x60	/* interrupt vector trap */
#define	TT_RA_WATCH	0x61	/* real address watchpoint */
#define	TT_VA_WATCH	0x62	/* virtual address watchpoint */
#define	TT_ECC_ERROR	0x63	/* ECC error */
#define	TT_FAST_IMMU_MISS 0x64	/* fast immu miss (BIG) */
#define	TT_FAST_DMMU_MISS 0x68	/* fast dmmu miss (BIG) */
#define	TT_FAST_DMMU_PROT 0x6c	/* fast dmmu protection (BIG) */
#define	TT_CPU_MONDO	0x7c	/* cpu mondo trap */
#define	TT_DEV_MONDO	0x7d	/* dev mondo trap */
#define	TT_RESUMABLE_ERR 0x7e	/* resumable error */
#define	TT_NONRESUMABLE_ERR 0x7f /* non-resumable error */
#define	TT_SPILL_0_NORMAL 0x80	/* spill 0 normal (BIG) */
#define	TT_SPILL_1_NORMAL 0x84	/* spill 1 normal (BIG) */
#define	TT_SPILL_2_NORMAL 0x88	/* spill 2 normal (BIG) */
#define	TT_SPILL_3_NORMAL 0x8c	/* spill 3 normal (BIG) */
#define	TT_SPILL_4_NORMAL 0x90	/* spill 4 normal (BIG) */
#define	TT_SPILL_5_NORMAL 0x94	/* spill 5 normal (BIG) */
#define	TT_SPILL_6_NORMAL 0x98	/* spill 6 normal (BIG) */
#define	TT_SPILL_7_NORMAL 0x9c	/* spill 7 normal (BIG) */
#define	TT_SPILL_0_OTHER  0xa0	/* spill 0 other (BIG) */
#define	TT_SPILL_1_OTHER  0xa4	/* spill 1 other (BIG) */
#define	TT_SPILL_2_OTHER  0xa8	/* spill 2 other (BIG) */
#define	TT_SPILL_3_OTHER  0xac	/* spill 3 other (BIG) */
#define	TT_SPILL_4_OTHER  0xb0	/* spill 4 other (BIG) */
#define	TT_SPILL_5_OTHER  0xb4	/* spill 5 other (BIG) */
#define	TT_SPILL_6_OTHER  0xb8	/* spill 6 other (BIG) */
#define	TT_SPILL_7_OTHER  0xbc	/* spill 7 other (BIG) */
#define	TT_FILL_0_NORMAL  0xc0	/* fill 0 normal (BIG) */
#define	TT_FILL_1_NORMAL  0xc4	/* fill 1 normal (BIG) */
#define	TT_FILL_2_NORMAL  0xc8	/* fill 2 normal (BIG) */
#define	TT_FILL_3_NORMAL  0xcc	/* fill 3 normal (BIG) */
#define	TT_FILL_4_NORMAL  0xd0	/* fill 4 normal (BIG) */
#define	TT_FILL_5_NORMAL  0xd4	/* fill 5 normal (BIG) */
#define	TT_FILL_6_NORMAL  0xd8	/* fill 6 normal (BIG) */
#define	TT_FILL_7_NORMAL  0xdc	/* fill 7 normal (BIG) */
#define	TT_FILL_0_OTHER   0xe0	/* fill 0 other (BIG) */
#define	TT_FILL_1_OTHER   0xe4	/* fill 1 other (BIG) */
#define	TT_FILL_2_OTHER   0xe8	/* fill 2 other (BIG) */
#define	TT_FILL_3_OTHER   0xec	/* fill 3 other (BIG) */
#define	TT_FILL_4_OTHER   0xf0	/* fill 4 other (BIG) */
#define	TT_FILL_5_OTHER   0xf4	/* fill 5 other (BIG) */
#define	TT_FILL_6_OTHER   0xf8	/* fill 6 other (BIG) */
#define	TT_FILL_7_OTHER   0xfc	/* fill 7 other (BIG) */
#define	TT_SWTRAP_BASE	0x100	/* trap instruction */
#define	TT_HTRAP_BASE	0x180	/* hypertrap instruction */

#endif /* _NIAGARA_TRAPS_H */
