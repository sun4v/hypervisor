/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: fpga.h
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
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _NIAGARA_FPGA_H_
#define	_NIAGARA_FPGA_H_

#pragma ident	"@(#)fpga.h	1.3	05/08/09 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#define	MByte(x)			(1024 * 1024 * (x))

#define	FPGA_BASE		0xfff0000000

#define	HOST_REGS_BASE(x)	(FPGA_BASE + (MByte(12) + (x)))
#define	FPGA_QIN_BASE		HOST_REGS_BASE(0x02000)
#define	FPGA_QOUT_BASE		HOST_REGS_BASE(0x02100)
#define	FPGA_Q3IN_BASE		HOST_REGS_BASE(0x02600)
#define	FPGA_Q3OUT_BASE		HOST_REGS_BASE(0x02700)
#define	FPGA_INTR_BASE		HOST_REGS_BASE(0x0a000)
#define	FPGA_SRAM_BASE		MByte(8)

/* mbox/queue offsets */
#define	FPGA_Q_MTU		(0 * 8)
#define	FPGA_Q_SIZE		(1 * 8)
#define	FPGA_Q_BASE		(2 * 8)
#define	FPGA_Q_SEND		(3 * 8)
#define	FPGA_Q_STATUS		(4 * 8)

/* Interrupt control */
#define	FPGA_INTR_STATUS	(0 * 8)
#define	FPGA_INTR_ENABLE	(1 * 8)
#define	FPGA_INTR_DISABLE	(2 * 8)
#define	FPGA_INTR_GENERATE	(3 * 8)

#define	IRQ_QUEUE_IN	0x0001
#define	IRQ_QUEUE_OUT	0x0002
#define	IRQ_SQUEUE_IN	0x0004
#define	IRQ_SQUEUE_OUT	0x0008
#define	IRQ_SC_ILLACC   0x0010
#define	IRQ_SHUTDN_REQ  0x0020
#define	IRQ_WATCHDOG    0x0040
#define	IRQ_USER_DEF    0x0080
#define	IRQ_MBOX_IN	0x0100
#define	IRQ_MBOX_OUT    0x0200
#define	IRQ_MASK	0x13ff
#define	IRQ_RESET_HACK	0x1000

#define	QINTR_ACK	1	/* payload undamaged, accepted */
#define	QINTR_NACK	2	/* payload damaged, rejected */
#define	QINTR_BUSY	4	/* payload undamaged, rejected try later */
#define	QINTR_ABORT	8	/* sync lost, abort */


#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA_FPGA_H_ */
