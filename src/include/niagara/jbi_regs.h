/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _NIAGARA_JBI_REGS_H
#define	_NIAGARA_JBI_REGS_H

#pragma ident	"@(#)jbi_regs.h	1.4	05/12/09 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#define	JBI_BASE		0x8000000000

#define	JBI_CONFIG1		JBI_BASE
#define	JBI_CONFIG2		(JBI_BASE + 0x00008)

#define	JBI_DEBUG		(JBI_BASE + 0x04000)
#define	JBI_DEBUG_ARB		(JBI_BASE + 0x04100)
#define	JBI_ERR_INJECT		(JBI_BASE + 0x04800)

#define	JBI_ERR_CONFIG		(JBI_BASE + 0x10000)
#define	JBI_ERR_LOG		(JBI_BASE + 0x10020)
#define	JBI_ERR_OVF		(JBI_BASE + 0x10028)
#define	JBI_LOG_ENB		(JBI_BASE + 0x10030)
#define	JBI_SIG_ENB		(JBI_BASE + 0x10038)
#define	JBI_LOG_ADDR		(JBI_BASE + 0x10040)
#define	JBI_LOG_DATA0		(JBI_BASE + 0x10050)
#define	JBI_LOG_DATA1		(JBI_BASE + 0x10058)
#define	JBI_LOG_CTRL		(JBI_BASE + 0x10048)
#define	JBI_LOG_PAR		(JBI_BASE + 0x10060)
#define	JBI_LOG_NACK		(JBI_BASE + 0x10070)
#define	JBI_LOG_ARB		(JBI_BASE + 0x10078)
#define	JBI_L2_TIMEOUT		(JBI_BASE + 0x10080)
#define	JBI_ARB_TIMEOUT		(JBI_BASE + 0x10088)
#define	JBI_TRANS_TIMEOUT	(JBI_BASE + 0x10090)
#define	JBI_INTR_TIMEOUT	(JBI_BASE + 0x10098)
#define	JBI_MEMSIZE		(JBI_BASE + 0x100a0)

#define	JBI_PERF_CTL		(JBI_BASE + 0x20000)
#define	JBI_PERF_COUNT		(JBI_BASE + 0x20008)

/* JBI_ERR_LOG bits */
#define	JBI_APAR		(1 << 28)
#define	JBI_CPAR		(1 << 27)
#define	JBI_ADTYPE		(1 << 26)
#define	JBI_L2_TO		(1 << 25)
#define	JBI_ARB_TO		(1 << 24)
#define	JBI_FATAL_MASK		0x2
#define	JBI_FATAL		(1 << 16)
#define	JBI_DPAR_WR		(1 << 15)
#define	JBI_DPAR_RD		(1 << 14)
#define	JBI_DPAR_O		(1 << 13)
#define	JBI_REP_UE		(1 << 12)
#define	JBI_ILLEGAL		(1 << 11)
#define	JBI_UNSUPP		(1 << 10)
#define	JBI_NONEX_WR		(1 << 9)
#define	JBI_NONEX_RD		(1 << 8)
#define	JBI_READ_TO		(1 << 5)
#define	JBI_UNMAP_WR		(1 << 4)
#define	JBI_RSVD4		(1 << 3)
#define	JBI_ERR_CYCLE		(1 << 2)
#define	JBI_UNEXP_DR		(1 << 1)
#define	JBI_INTR_TO		(1 << 0)

/* BEGIN CSTYLED */

#ifdef NIAGARA_JBI_INTR_TO_WORKAROUND
#define	JBI_INTR_ONLY_ERRS	(JBI_DPAR_WR | JBI_REP_UE | JBI_DPAR_O |  \
				JBI_ILLEGAL | JBI_UNSUPP | JBI_NONEX_WR | \
				JBI_UNMAP_WR | JBI_UNEXP_DR)
#else
#define	JBI_INTR_ONLY_ERRS	(JBI_DPAR_WR | JBI_REP_UE | JBI_DPAR_O |  \
				JBI_ILLEGAL | JBI_UNSUPP | JBI_NONEX_WR | \
				JBI_UNMAP_WR | JBI_UNEXP_DR | JBI_INTR_TO)
#endif

#define	ENABLE_JBI_INTR_ERRS(reg1, reg2, reg3)				\
	setx	JBI_INTR_ONLY_ERRS, reg1, reg3				;\
	setx	JBI_LOG_ENB, reg2, reg1					;\
	ldx	[reg1], reg2						;\
	or	reg3, reg2, reg2					;\
	stx	reg2, [reg1]						;\
	setx	JBI_SIG_ENB, reg2, reg1					;\
	ldx	[reg1], reg2						;\
	or	reg3, reg2, reg2					;\
	stx	reg2, [reg1]

#define	DISABLE_JBI_INTR_ERRS(reg1, reg2, reg3)				\
	setx	JBI_INTR_ONLY_ERRS, reg1, reg3				;\
	setx	JBI_LOG_ENB, reg2, reg1					;\
	ldx	[reg1], reg2						;\
	andn	reg3, reg2, reg2					;\
	stx	reg2, [reg1]						;\
	setx	JBI_SIG_ENB, reg2, reg1					;\
	ldx	[reg1], reg2						;\
	andn	reg3, reg2, reg2					;\
	stx	reg2, [reg1]

/* END CSTYLED */

#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA_JBI_REGS_H */
