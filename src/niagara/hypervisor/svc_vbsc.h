/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: svc_vbsc.h
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

#ifndef _SVC_VBSC_H
#define	_SVC_VBSC_H

#pragma ident	"@(#)svc_vbsc.h	1.5	05/09/09 SMI"

#ifdef CONFIG_VBSC_SVC

#define	VBSC_CMD_READMEM	'R'
#define	VBSC_CMD_WRITEMEM	'W'
#define	VBSC_CMD_SENDERR	'E'
#define	VBSC_CMD_GUEST_STATE	'P'
#define	VBSC_CMD_GUEST_XIR	'X'
#define	VBSC_CMD_GUEST_TODOFFSET 'O'
#define	VBSC_CMD_HV		'H'

#define	GUEST_STATE_CMD_OFF	0
#define	GUEST_STATE_CMD_ON	1
#define	GUEST_STATE_CMD_RESET	2
#define	GUEST_STATE_CMD_SHUTREQ	3


#define	VBSC_CMD(x, y)	((0x80 << 56) | (((x) << 8) | (y)))
#define	VBSC_ACK(x, y)	((((x) << 8) | (y)))

#define	VBSC_GUEST_OFF	VBSC_CMD(VBSC_CMD_GUEST_STATE, GUEST_STATE_CMD_OFF)
#define	VBSC_GUEST_ON	VBSC_CMD(VBSC_CMD_GUEST_STATE, GUEST_STATE_CMD_ON)
#define	VBSC_GUEST_RESET VBSC_CMD(VBSC_CMD_GUEST_STATE, GUEST_STATE_CMD_RESET)
#define	VBSC_GUEST_XIR	VBSC_CMD(VBSC_CMD_GUEST_XIR, 0)
#define	VBSC_GUEST_TODOFFSET	VBSC_CMD(VBSC_CMD_GUEST_TODOFFSET, 0)
#define	VBSC_HV_START	VBSC_CMD(VBSC_CMD_HV, 'V')
#define	VBSC_HV_PING	VBSC_CMD(VBSC_CMD_HV, 'I')
#define	VBSC_HV_ABORT	VBSC_CMD(VBSC_CMD_HV, 'A')

/*
 * HV_GUEST_SHUTDOWN_REQ - send the guest a graceful shutdown resumable
 * error report
 *
 * word0: VBSC_HV_GUEST_SHUTDOWN_REQ
 * word1: xid
 * word1: grace period in seconds
 */
#define	VBSC_HV_GUEST_SHUTDOWN_REQ	\
	VBSC_CMD(VBSC_CMD_GUEST_STATE, GUEST_STATE_CMD_SHUTREQ)

/*
 * Debugging aids, emitted on hte vbsc HV "console" (TCP port 2001)
 *
 * putchars - writes up to 8 characters, leading NUL characters are ignored
 *
 * puthex - writes a 64-bit hex number
 */
#define	VBSC_HV_PUTCHARS VBSC_CMD(VBSC_CMD_HV, 'C')
#define	VBSC_HV_PUTHEX	VBSC_CMD(VBSC_CMD_HV, 'N')


/*
 * VBSC_SEND_CMD - send a command packet to the VBSC
 *
 * Clobbers: %g1, %g2, %g3, %g7
 */
#define VBSC_SEND_CMD(rootp, cmd, arg0, arg1)		\
	.pushlocals					;\
	ldx	[rootp + CONFIG_VBSC_SVCH], %g1		;\
	brz,pn	%g1, 2f					;\
	nop						;\
	ba	1f					;\
	rd	%pc, %g2				;\
	.word	0, 0					;\
	.word	0, 0					;\
	.word	0, 0					;\
1:	inc	INSTRUCTION_SIZE, %g2			;\
	st	cmd, [%g2 + VBSC_PKT_CMD + 4]		;\
	srlx	cmd, 32, cmd				;\
	st	cmd, [%g2 + VBSC_PKT_CMD]		;\
	st	arg0, [%g2 + VBSC_PKT_ARG0 + 4]		;\
	srlx	arg0, 32, arg0				;\
	st	arg0, [%g2 + VBSC_PKT_ARG0]		;\
	st	arg1, [%g2 + VBSC_PKT_ARG1 + 4]		;\
	srlx	arg1, 32, arg1				;\
	st	arg1, [%g2 + VBSC_PKT_ARG1]		;\
	mov	VBSC_CTRL_PKT_SIZE, %g3			;\
	ba	svc_internal_send			;\
	rd	%pc, %g7				;\
2:	.poplocals


#endif /* CONFIG_VBSC_SVC */

#ifndef _ASM

struct vbsc_ctrl_pkt {
	uint64_t cmd;
	uint64_t arg0;
	uint64_t arg1;
	uint64_t arg2;
};


/*
 * For debugging mailbox channels
 */
struct dbgerror_payload {
	uint64_t data[63];
};

struct dbgerror {
	uint64_t error_svch;
	struct dbgerror_payload payload;
};

#endif /* !_ASM */

#endif /* _SVC_VBSC_H */
