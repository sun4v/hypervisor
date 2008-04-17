/*
 * Copyright 2003 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _PC16550_H
#define _PC16550_H

#pragma ident	"@(#)pc16550.h	1.3	04/07/21 SMI"

/*
 * Hypervisor UART console definitions
 */

#ifdef __cplusplus
extern "C" {
#endif

#define	RBR_ADDR	0x0
#define	THR_ADDR	0x0
#define	IER_ADDR	0x1
#define	IIR_ADDR	0x2
#define	FCR_ADDR	0x2
#define	LCR_ADDR	0x3
#define	MCR_ADDR	0x4
#define	LSR_ADDR	0x5
#define	MSR_ADDR	0x6
#define	SCR_ADDR	0x7
#define	DLL_ADDR	0x0
#define	DLM_ADDR	0x1

/*
 * Some Line Status Register (FCR) bits
 */
#define	LSR_DRDY	0x1
#define	LSR_BINT	0x10
#define	LSR_THRE	0x20
#define	LSR_TEMT	0x40

/*
 * Some FIFO Control Register (FCR) bits
 */
#define	FCR_FIFO_ENABLE	0x1
#define	FCR_RCVR_RESET	0x2
#define	FCR_XMIT_RESET	0x4

/*
 * Line Control Register settings
 */
#define	LCR_DLAB	0x80
#define	LCR_8N1		0x3

/*
 * Baud rate settings for Divisor Latch Low (DLL) and Most (DLM)
 */
#define	DLL_9600	0xc
#define	DLM_9600	0x0
#endif /* _PC16550_H */
