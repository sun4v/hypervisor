/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: vdev_console.s
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

	.ident	"@(#)vdev_console.s	1.9	06/05/26 SMI"

	.file	"vdev_console.s"

/*
 * Virtual console device implementation
 */

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hprivregs.h>
#include <asi.h>
#include <fpga.h>
#include <mmu.h>
#include <sun4v/traps.h>
#include <sun4v/mmu.h>
#include <sun4v/asi.h>
#include <sun4v/queue.h>
#include <devices/pc16550.h>

#include <guest.h>
#include <cpu.h>
#include <offsets.h>
#include <util.h>
#include <svc.h>
#include <vdev_intr.h>
#include <vdev_console.h>
#include <debug.h>


/*
 * Virtual console guest interfaces (hcalls)
 */

#ifdef CONFIG_CN_SVC /* { */

/*
 * Service Channel implemenation
 */


/*
 * cons_read - read characters from the console
 *
 * Read arg1 characters from the console and place into buffer at arg0.
 * If arg1 is zero the call immediately returns success, no data
 * is consumed.
 * On success ret1 contains either a magic character (CONS_BREAK, CONS_HUP)
 * or the number of characters placed into the buffer.
 *
 * arg0 buffer RA (%o0)
 * arg1 length (%o1)
 * --
 * ret0 status (%o0)
 * ret1 length completed (%o1)
 */
	ENTRY_NP(hcall_cons_read)
	GUEST_STRUCT(%g1)
	!! %g1 = guestp

	/*
	 * Check for pending svc packet
	 */
	ldx	[%g1 + GUEST_CONSOLE + CONS_PENDING], %g2
	!! %g2 = svcp
	brz,pt	%g2, herr_wouldblock  /* XXX EOK if bufsize is 0? */
	nop

.consread_pkt_avail:
	ldx	[%g2 + SVC_CTRL_RECV + SVC_LINK_PA], %g3
	add	%g3, SVC_PKT_SIZE, %g3 ! skip the header
	!! %g3 = packet pointer

	ldub	[%g3 + SVCCN_PKT_TYPE], %g4
	cmp	%g4, SVCCN_TYPE_CHARS
	be,pt	%xcc, .consread_pkt_chars
	nop

	/*
	 * Meta characters
	 *
	 * Return special characters even if the read buffer size is zero.
	 */
.consread_pkt_metachars:
	mov	0, %o1
	cmp	%g4, SVCCN_TYPE_HUP
	move	%xcc, CONS_HUP, %o1
	cmp	%g4, SVCCN_TYPE_BREAK
	move	%xcc, CONS_BREAK, %o1
	ba,pt	%xcc, .consread_pkt_complete
	nop

.consread_pkt_chars:
	/*
	 * read buffer size is 0, return success
	 */
	brz,pn	%o1, hret_ok
	nop

	/*
	 * Character data
	 *
	 * The original length of the data is still in the packet.
	 * The remaining amount is in CHARS_AVAIL.
	 */
	!! %g1 = guestp
	!! %g2 = svcp
	!! %g3 = packet pointer
	RANGE_CHECK(%g1, %o0, %o1, herr_noraddr, %g5)
	REAL_OFFSET(%g1, %o0, %o0, %g6)
	!! %o0 buf RA

	/* transaction size = MIN(avail, bufsize) */
	ldub	[%g1 + GUEST_CONSOLE + CONS_CHARS_AVAIL], %g4
	cmp	%o1, %g4
	movgu	%xcc, %g4, %o1

	ldub	[%g3 + SVCCN_PKT_LEN], %g5
	sub	%g5, %g4, %g5	! offset into packet
	add	%g3, %g5, %g5
	inc	SVCCN_PKT_DATA, %g5 ! skip header
	/* src=%g5, dst=%o0, len=%o1 */
	mov	%o1, %g6	! SMALL COPY MACRO would clobber %o1
	SMALL_COPY_MACRO(%g5, %g6, %o0, %g7)

	subcc	%g4, %o1, %g4
	bnz,a,pt %xcc, .consread_pkt_pending
	  stb	%g4, [%g1 + GUEST_CONSOLE + CONS_CHARS_AVAIL]

.consread_pkt_complete:
	/*
	 * Done with this packet
	 */
	stx	%g0, [%g1 + GUEST_CONSOLE + CONS_PENDING]
	stb	%g0, [%g1 + GUEST_CONSOLE + CONS_CHARS_AVAIL]
	ld	[%g2 + SVC_CTRL_STATE], %g5
	andn	%g5, SVC_FLAGS_RI, %g5
	st	%g5, [%g2 + SVC_CTRL_STATE]	! clear RECV pending

.consread_pkt_pending:
	HCALL_RET(EOK)
	SET_SIZE(hcall_cons_read)


/*
 * cons_write - write characters to the console
 *
 * Writes arg1 characters from the buffer at arg0 to the console.
 * If arg1 is zero the call immediately returns success, no data
 * is consumed.
 * On success ret1 contains the actual number of characters consumed
 * from the buffer.
 *
 * arg0 buffer RA (%o0)
 * arg1 length (%o1)
 * --
 * ret0 status (%o0)
 * ret1 length completed (%o1)
 */
	ENTRY_NP(hcall_cons_write)
	brz,pn	%o1, hret_ok
	nop
	CPU_GUEST_STRUCT(%g4, %g3)
	!! %g3 = guestp
	!! %g4 = cpup

	RANGE_CHECK(%g3, %o0, %o1, herr_noraddr, %g5)
	REAL_OFFSET(%g3, %o0, %o0, %g6)
	!! %o0 buf RA

	ldx	[%g3 + GUEST_CONSOLE + CONS_SVCP], %g5
	brz,pn	%g5, herr_ioerror
	nop
	!! %g5 = cnsvc handle

	/* Adjust length for the size of the header fields */
	lduw	[%g5 + SVC_CTRL_MTU], %g1
	mov	(NCPUSCRATCH * CPU_SCR_INCR), %g2
	cmp	%g1, %g2
	movgu	%xcc, %g2, %g1
	!! %g1 = MIN(scratchsize, MTU)
	dec	(SVC_PKT_SIZE + SVCCN_PKT_SIZE - 1), %g1
	cmp	%o1, %g1
	movgu	%xcc, %g1, %o1
	!! %o1 = MIN(%o1, MTU-hdrsize)

	mov	%g5, %g1
	add	%g4, CPU_SCR, %g2
	stb	%g0, [%g2 + SVCCN_PKT_TYPE]
	stb	%o1, [%g2 + SVCCN_PKT_LEN]

	/* The packet size constant already contains one character */
	mov	SVCCN_PKT_SIZE - 1, %g3
	add	%g3, %o1, %g3

	mov	%o1, %g4	! need to preserve %o1
	add	%g2, SVCCN_PKT_DATA, %g5
	SMALL_COPY_MACRO(%o0, %g4, %g5, %g6)

	!! %g1 handle
	!! %g2 buf
	!! %g3 len
	HVCALL(svc_internal_send)
	brnz	%g1, herr_wouldblock
	nop
	HCALL_RET(EOK)
	SET_SIZE(hcall_cons_write)


/*
 * cons_putchar
 *
 * arg0 char (%o0)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_cons_putchar)
#if 0 /* XXX check for invalid char -or- magic values (BREAK) */
	cmp	%o0, MAX_CHAR
	bgu,pn	%xcc, herr_inval
#endif
	CPU_GUEST_STRUCT(%g4, %g3)
	!! %g3 = guestp
	!! %g4 = cpup

	ldx	[%g3 + GUEST_CONSOLE + CONS_SVCP], %g5
	brz,pn	%g5, herr_inval
	nop
	!! %g5 = cnsvc handle

	mov	%g5, %g1
	add	%g4, CPU_SCR3, %g2
	stb	%g0, [%g2 + SVCCN_PKT_TYPE]
	mov	1, %g3		! one character per putchar
	stb	%g3, [%g2 + SVCCN_PKT_LEN]
	stb	%o0, [%g2 + SVCCN_PKT_DATA + 0]
	/* The packet size already contains one character */
	mov	SVCCN_PKT_SIZE, %g3
	!! %g1 handle
	!! %g2 buf
	!! %g3 len
	HVCALL(svc_internal_send)
	brnz	%g1, .putchar_wouldblock
	nop

	HCALL_RET(EOK)

.putchar_wouldblock:
	ba,pt	%xcc, herr_wouldblock
	nop
	SET_SIZE(hcall_cons_putchar)


/*
 * cons_getchar
 *
 * no arguments
 * --
 * ret0 status (%o0)
 * ret1 char (%o1)
 */
	ENTRY_NP(hcall_cons_getchar)
	GUEST_STRUCT(%g1)
	!! %g1 = guestp

	/*
	 * Check for pending svc packet
	 */
	ldx	[%g1 + GUEST_CONSOLE + CONS_PENDING], %g2
	!! %g2 = svcp
	brz,pt	%g2, herr_wouldblock
	nop

.getchar_pkt_avail:
	ldx	[%g2 + SVC_CTRL_RECV + SVC_LINK_PA], %g3
	add	%g3, SVC_PKT_SIZE, %g3 ! skip the header
	!! %g3 = packet pointer

	ldub	[%g3 + SVCCN_PKT_TYPE], %g4
	cmp	%g4, SVCCN_TYPE_CHARS
	be,pt	%xcc, .getchar_pkt_chars
	nop

	/*
	 * Meta characters
	 */
.getchar_pkt_metachars:
	cmp	%g4, SVCCN_TYPE_HUP
	move	%xcc, CONS_HUP, %o1
	cmp	%g4, SVCCN_TYPE_BREAK
	move	%xcc, CONS_BREAK, %o1
	ba,pt	%xcc, .getchar_pkt_complete
	nop

.getchar_pkt_chars:
	/*
	 * Character data
	 *
	 * The original length of the data is still in the packet.
	 * The remaining amount is in CHARS_AVAIL.
	 */
	!! %g1 = guestp
	!! %g2 = svcp
	!! %g3 = packet pointer
	ldub	[%g1 + GUEST_CONSOLE + CONS_CHARS_AVAIL], %g4
	ldub	[%g3 + SVCCN_PKT_LEN], %g5
	sub	%g5, %g4, %g5	! offset into packet
	add	%g3, %g5, %g5
	ldub	[%g5 + SVCCN_PKT_DATA], %o1
	deccc	%g4
	bnz,a,pt %xcc, .getchar_pkt_pending
	  stb	%g4, [%g1 + GUEST_CONSOLE + CONS_CHARS_AVAIL]

.getchar_pkt_complete:
	/*
	 * Done with this packet
	 */
	stx	%g0, [%g1 + GUEST_CONSOLE + CONS_PENDING]
	stb	%g0, [%g1 + GUEST_CONSOLE + CONS_CHARS_AVAIL]
	ld	[%g2 + SVC_CTRL_STATE], %g5
	andn	%g5, SVC_FLAGS_RI, %g5
	st	%g5, [%g2 + SVC_CTRL_STATE]	! clear RECV pending

.getchar_pkt_pending:
	HCALL_RET(EOK)
	SET_SIZE(hcall_cons_getchar)


/*
 * setup_cn_svc
 *
 * in:
 *	%i0 - global config pointer
 *	%i1 - base of guests
 *	%i2 - base of cpus
 *	%g7 - return address
 *
 * volatile:
 *	%locals
 */
	ENTRY_NP(setup_cn_svc)	/* XXX per-guest */
	mov	%g7, %l7
	add	%i1, GUEST_CONSOLE, %g1 ! XXX guest0 hard-coded
	SVC_REGISTER(cnt, XPID_GUEST(0), SID_CONSOLE, cn_svc_rx, cn_svc_tx)
	brnz,pn	%g1, 1f
	nop
	PRINT("WARNING: setup_cn_svc register failed\r\n");
	mov	0, %g1
1:	! save the service handle (cookie), 0 if register failed
	brz,pn  %g1, 2f
	nop

	/* XXX guest0 hard-coded */
	stx	%g1, [%i1 + GUEST_CONSOLE + CONS_SVCP]
	ldx	[%g1 + SVC_CTRL_INTR_COOKIE], %g2
	stx	%g2, [%i1 + GUEST_CONSOLE + CONS_VINTR_ARG]

	setx	cn_svc_getstate, %g3, %g4
	ldx	[%i0 + CONFIG_RELOC], %g3
	sub	%g4, %g3, %g4
	stx	%g4, [%g2 + MAPREG_GETSTATE]

#ifdef DEBUG_CONSOLE
	mov	%g2, %l6
	PRINT_NOTRAP("setup_cn_svc: ino= ")
	ldx	[%l6 + MAPREG_DATA0], %g1
	PRINTX_NOTRAP(%g1)
	PRINT_NOTRAP("\r\n")
#endif
2:
	jmp	%l7 + 4
	nop
	SET_SIZE(setup_cn_svc)


/*
 * cn_svc_rx
 *
 * %g1 callback cookie (XXX guest's console struct?)
 * %g2 svc pointer
 * %g7 return address
 */
	ENTRY(cn_svc_rx)
#ifdef DEBUG_CONSOLE
	mov	%g7, %g6
	PRINT("cn_svc_rx\r\n")
	mov	%g6, %g7
#endif
#if 1 /* XXX */
	/* XXX When the cookie is the guestp then remove this hack */
	GUEST_STRUCT(%g1)
#endif
	!! %g1 = guestp
	!! %g2 = svcp

	/* check for an already pending packet */
	ldx	[%g1 + GUEST_CONSOLE + CONS_PENDING], %g3
	brz,pt	%g3, 1f
	nop

	/* We already have a packet pending? */
#ifdef DEBUG_CONSOLE
	mov	%g7, %g6
	PRINT("cn_svc_rx: packet received when another pending?\r\n")
	mov	%g6, %g7
#endif
	ba,pt	%xcc, 2f
	nop

	/*
	 * Process packet
	 */
1:
	!! %g1 = target guestp
	!! %g2 = svcp
	ldx	[%g2 + SVC_CTRL_RECV + SVC_LINK_PA], %g3
	add	%g3, SVC_PKT_SIZE, %g3 ! skip the header
        !! %g3 = packet pointer
	ldub    [%g3 + SVCCN_PKT_LEN], %g5
	stb	%g5, [%g1 + GUEST_CONSOLE + CONS_CHARS_AVAIL]
	stx	%g2, [%g1 + GUEST_CONSOLE + CONS_PENDING]

#ifdef CONSOLE_DEBUG
	mov	%g7, %g6
	PRINT("rx: ")
	GUEST_STRUCT(%g1)
	ldx	[%g1 + GUEST_CONSOLE + CONS_PENDING], %g1
	ldx	[%g1 + SVC_CTRL_RECV + SVC_LINK_PA], %g1
	add	%g1, SVC_PKT_SIZE, %g1 ! skip the header
	lduw	[%g1], %g1
	PRINTX(%g1)
	PRINT("\r\n")
	mov	%g6, %g7
	GUEST_STRUCT(%g1)
#endif

2:
	/*
	 * Generate virtual console interrupt
	 */
	ldx	[%g1 + GUEST_CONSOLE + CONS_VINTR_ARG], %g1
	/* tail call, returns to caller */
	brnz,pt	%g1, vdev_intr_generate
	nop

	HVRET	
        SET_SIZE(cn_svc_rx)


/*
 * cn_svc_tx
 *
 * %g1 callback cookie
 * %g2 packet 
 * %g7 return address
 */
	ENTRY(cn_svc_tx)
#ifdef DEBUG_CONSOLE
	mov	%g7, %g6
	PRINT("cn_svc_tx\r\n")
	mov	%g6, %g7
#endif

#if 1 /* XXX %g1 should already be the guest? cookie=guest? */
	GUEST_STRUCT(%g1)
#endif

	/*
	 * Generate virtual console interrupt
	 */
	ldx	[%g1 + GUEST_CONSOLE + CONS_VINTR_ARG], %g1
	/* tail call, returns to caller */
	brnz,pt	%g1, vdev_intr_generate
	nop

	HVRET
        SET_SIZE(cn_svc_tx)

/*
 * cn_svc_getstate - get interrupt "level"
 *
 * %g1 - cookie
 * %g7 - return address
 * --
 * %g1 - current interrupt "level"
 */
	ENTRY_NP(cn_svc_getstate)
	mov	0, %g1
	HVRET
	SET_SIZE(cn_svc_getstate)


#else /* } !CONFIG_CN_SVC { */


/*
 * cons_read - read characters from the console
 *
 * Read arg1 characters from the console and place into buffer at arg0.
 * If arg1 is zero the call immediately returns success, no data
 * is consumed.
 * On success ret1 contains either a magic character (CONS_BREAK, CONS_HUP)
 * or the number of characters placed into the buffer.
 *
 * arg0 buffer RA (%o0)
 * arg1 length (%o1)
 * --
 * ret0 status (%o0)
 * ret1 length completed (%o1)
 */
	ENTRY_NP(hcall_cons_read)
	/*
	 * read buffer size is 0, return success
	 */
	brz,pn	%o1, hret_ok
	nop

	GUEST_STRUCT(%g1)

	RANGE_CHECK(%g1, %o0, %o1, herr_noraddr, %g5)
	REAL_OFFSET(%g1, %o0, %o0, %g6)
	!! %o0 buf RA

	ldx	[%g1 + GUEST_CONSOLE + CONS_BASE], %g2
	!! %g2 = uartp

	ldub	[%g2 + LSR_ADDR], %g3 ! line status register
	btst	LSR_BINT, %g3	! BREAK?
	bz,pt	%xcc, 1f
	nop

	! BREAK
	andn	%g3, LSR_BINT, %g3
	stb	%g3, [%g2 + LSR_ADDR] 	! XXX clear BREAK? need w1c
	mov	CONS_BREAK, %o1
	HCALL_RET(EOK)

1:	btst	LSR_DRDY, %g3	! character ready?
	bz,pt	%xcc, herr_wouldblock
	nop

	ldub	[%g2], %g3	! input data register
	stb	%g3, [%o0]
	mov	1, %o1		! Always one character
	HCALL_RET(EOK)
	SET_SIZE(hcall_cons_read)


/*
 * cons_write - write characters to the console
 *
 * Writes arg1 characters from the buffer at arg0 to the console.
 * If arg1 is zero the call immediately returns success, no data
 * is consumed.
 * On success ret1 contains the actual number of characters consumed
 * from the buffer.
 *
 * arg0 buffer RA (%o0)
 * arg1 length (%o1)
 * --
 * ret0 status (%o0)
 * ret1 length completed (%o1)
 */
	ENTRY_NP(hcall_cons_write)
	brz,pn	%o1, hret_ok
	nop
	CPU_GUEST_STRUCT(%g4, %g3)
	!! %g3 = guestp
	!! %g4 = cpup

	RANGE_CHECK(%g3, %o0, %o1, herr_noraddr, %g5)
	REAL_OFFSET(%g3, %o0, %o0, %g6)
	!! %o0 buf RA

	ldx	[%g3 + GUEST_CONSOLE + CONS_BASE], %g1
	!! %g1 = uartp

	ldub	[%g1 + LSR_ADDR], %g4
	btst	LSR_THRE, %g4
	bz,pn	%xcc, herr_wouldblock
	nop

	mov	0, %g2
	!! %g2 count of characters written
1:
	ldub	[%o0 + %g2], %g3
	stb	%g3, [%g1]
	inc	%g2
	cmp	%g2, %o1
	bgeu,pn	%xcc, 2f
	nop
	ldub	[%g1 + LSR_ADDR], %g4
	btst	LSR_THRE, %g4
	bnz,pt	%xcc, 1b
	nop

2:
	mov	%g2, %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_cons_write)


/*
 * cons_putchar
 *
 * arg0 char (%o0)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_cons_putchar)
#if 0 /* XXX valid char -or- BREAK */
	cmp	%o0, MAX_CHAR
	bgu,pn	%xcc, herr_inval
#endif
	GUEST_STRUCT(%g3)
	!! %g3 = guestp
	ldx	[%g3 + GUEST_CONSOLE + CONS_BASE], %g1
	!! %g1 = uartp
0:
	ldub	[%g1 + LSR_ADDR], %g4
	btst	LSR_THRE, %g4
	bz,pn	%xcc, herr_wouldblock
	nop
	stb	%o0, [%g1]
	HCALL_RET(EOK)
	SET_SIZE(hcall_cons_putchar)


/*
 * cons_getchar
 *
 * no arguments
 * --
 * ret0 status (%o0)
 * ret1 char (%o1)
 */
	ENTRY_NP(hcall_cons_getchar)
	GUEST_STRUCT(%g1)
	!! %g1 = guestp

	ldx	[%g1 + GUEST_CONSOLE + CONS_BASE], %g2
	!! %g2 = uartp

	ldub	[%g2 + LSR_ADDR], %g3 ! line status register
	btst	LSR_BINT, %g3	! BREAK?
	bz,pt	%xcc, 1f
	nop

	! BREAK
	andn	%g3, LSR_BINT, %g3
	stb	%g3, [%g2 + LSR_ADDR] 	! XXX clear BREAK? need w1c
	mov	CONS_BREAK, %o1
	HCALL_RET(EOK)

1:	btst	LSR_DRDY, %g3	! character ready?
	bz,pt	%xcc, herr_wouldblock
	nop

	ldub	[%g2], %o1	! input data register
	HCALL_RET(EOK)
	SET_SIZE(hcall_cons_getchar)

#endif /* } CONFIG_CNSVC */
