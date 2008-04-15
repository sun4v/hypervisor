/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: svc_vbsc.s
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

	.ident	"@(#)svc_vbsc.s	1.15	05/11/04 SMI"

	.file	"svc_vbsc.s"

#if defined(CONFIG_SVC) && defined(CONFIG_VBSC_SVC)

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <sparcv9/misc.h>
#include <niagara/asi.h>
#include <niagara/mmu.h>
#include <niagara/fpga.h>
#include <sun4v/traps.h>
#include <sun4v/asi.h>
#include <sun4v/mmu.h>

#include "config.h"
#include "guest.h"
#include "offsets.h"
#include "svc.h"
#include "svc_vbsc.h"
#include "errs_common.h"
#include "cpu.h"
#include "util.h"
#include "abort.h"
#include "debug.h"

/*
 * vbsc_send_polled - send a command to vbsc using polled I/O
 *
 * If VBSC does not accept the packet then 
 *
 * %g1 - cmd[0]
 * %g2 - cmd[1]
 * %g3 - cmd[2]
 * %g7 - return address
 */
	ENTRY_NP(vbsc_send_polled)
.vbsc_send_polled_resend:
	setx	FPGA_Q3OUT_BASE, %g4, %g5
	setx	FPGA_BASE + FPGA_SRAM_BASE, %g4, %g6

	lduh	[%g5 + FPGA_Q_BASE], %g4
	add	%g4, %g6, %g6
	!! %g6 = sram buffer words

	stx	%g3, [%g6 + (2 * 8)]
	stx	%g2, [%g6 + (1 * 8)]
	stx	%g1, [%g6 + (0 * 8)]
	mov	1, %g4
	sth	%g4, [%g5 + FPGA_Q_SEND]

	/*
	 * Wait for a non-zero status.  If we get an ACK then we're done.
	 * Otherwise re-send the packet.  Failure is not an option, even
	 * to hv_abort we need to send a message to vbsc.  So keep trying.
	 */
.vbsc_send_polled_wait_for_ack:
	lduh	[%g5 + FPGA_Q_STATUS], %g4
	andcc	%g4, (QINTR_ACK | QINTR_NACK | QINTR_BUSY | QINTR_ABORT), %g4
	bz,pn	%xcc, .vbsc_send_polled_wait_for_ack
	nop
	btst	QINTR_ACK, %g4
	bz,pt	%xcc, .vbsc_send_polled_resend
	nop

	sth	%g4, [%g5 + FPGA_Q_STATUS] ! clear status bits
	HVRET
	SET_SIZE(vbsc_send_polled)


/*
 * vbsc_hv_start - notify VBSC that the hypervisor has started
 *
 * %g7 return address
 *
 * Called from setup environment
 */
	ENTRY_NP(vbsc_hv_start)
	mov	%g7, %o3

	setx	VBSC_HV_START, %g2, %g1
	mov	0, %g2
	mov	0, %g3
	HVCALL(vbsc_send_polled)

	mov	%o3, %g7
	HVRET
	SET_SIZE(vbsc_hv_start)


/*
 * vbsc_hv_abort - notify VBSC that hv has aborted
 *
 * %g1 contains reason for the abort
 * %g7 return address
 */
	ENTRY_NP(vbsc_hv_abort)
	mov	%g1, %g2
	setx	VBSC_HV_ABORT, %g3, %g1
	mov	0, %g3
	HVCALL(vbsc_send_polled)

	/* spin until the vbsc powers us down */
	ba	.
	nop
	SET_SIZE(vbsc_hv_abort)


/*
 * vbsc_guest_start - notify VBSC that a guest has started
 *
 * %g7 return address
 */
	ENTRY_NP(vbsc_guest_start)
	mov	%g7, %o3
	
	setx	VBSC_GUEST_ON, %g2, %g1
	GUEST_STRUCT(%o2)
	set	GUEST_XID, %o4
	ldx	[%o2 + %o4], %g2
	mov	0, %g3
	HVCALL(vbsc_send_polled)

	mov	%o3, %g7
	HVRET
	SET_SIZE(vbsc_guest_start)


/*
 * vbsc_guest_exit - notify VBSC that a guest has exited
 *
 * arg0 exit code (%o0)
 * --
 * does not return
 */
	ENTRY_NP(vbsc_guest_exit)
	setx	VBSC_GUEST_OFF, %g2, %g1
	GUEST_STRUCT(%o2)
	set	GUEST_XID, %o4
	ldx	[%o2 + %o4], %g2
	ldx	[%o2 + GUEST_TOD_OFFSET], %g3
	HVCALL(vbsc_send_polled)

	/* spin until the vbsc powers us down */
	ba	.
	nop
	SET_SIZE(vbsc_guest_exit)


/*
 * vbsc_guest_sir - notify vbsc that a guest requested a reset
 *
 * --
 * does not return
 */
	ENTRY_NP(vbsc_guest_sir)
	setx	VBSC_GUEST_RESET, %g2, %g1
	GUEST_STRUCT(%o2)
	set	GUEST_XID, %o4
	ldx	[%o2 + %o4], %g2
	ldx	[%o2 + GUEST_TOD_OFFSET], %g3
	HVCALL(vbsc_send_polled)

	/* spin until the vbsc powers us down */
	ba	.
	nop
	SET_SIZE(vbsc_guest_sir)


/*
 * vbsc_guest_tod_offset - notify VBSC of a guest's TOD offset
 * We don't retry here, failures are ignored.
 *
 * %g1 guestp
 * %g7 return address
 *
 * Clobbers %g1-6
 * Called from guest hcall environment
 */
	ENTRY_NP(vbsc_guest_tod_offset)
	CPU_STRUCT(%g2)
	inc	CPU_SCR0, %g2

	set	GUEST_XID, %g3
	ldx	[%g1 + %g3], %g3
	stx	%g3, [%g2 + 0x8]

	ldx	[%g1 + GUEST_TOD_OFFSET], %g3
	stx	%g3, [%g2 + 0x10]

	setx	VBSC_GUEST_TODOFFSET, %g4, %g3
	stx	%g3, [%g2 + 0x0]

	ROOT_STRUCT(%g1)
	ldx	[%g1 + CONFIG_VBSC_SVCH], %g1

	mov	8 * 3, %g3

	!! %g1 svch
	!! %g2 buf
	!! %g3 length
	ba,pt	%xcc, svc_internal_send	! tail call, returns to caller
	nop
	SET_SIZE(vbsc_guest_tod_offset)



#define	SIM_IRU_DIAG_ERPT(erpt_vbsc, reg1, reg2)			\
	set	ERPT_TYPE_CPU, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_REPORT_TYPE]			;\
	setx	0x10000000000001, reg2, reg1				;\
	stx	reg1, [erpt_vbsc + EVBSC_EHDL]				;\
	setx	0x002a372a4, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_STICK]				;\
	setx	0x3e002310000607, reg2, reg1				;\
	stx	reg1, [erpt_vbsc + EVBSC_CPUVER]			;\
	setx	0x000000000, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_CPUSERIAL]			;\
	setx	0x000010000, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_SPARC_AFSR]			;\
	setx	0x000830550, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_SPARC_AFAR]			;\
	setx	0x400000402, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_TSTATE]			;\
	setx	0x000000800, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_HTSTATE]			;\
	setx	0x000800610, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_TPC]				;\
	set	0x0, reg1						;\
	stuh	reg1, [erpt_vbsc + EVBSC_CPUID]				;\
	set	0x63, reg1						;\
	stuh	reg1, [erpt_vbsc + EVBSC_TT]				;\
	set	0x1, reg1						;\
	stub	reg1, [erpt_vbsc + EVBSC_TL]				;\
	set	0x3, reg1						;\
	stub	reg1, [erpt_vbsc + EVBSC_ERREN]

#define	SIM_IRC_DIAG_ERPT(erpt_vbsc, reg1, reg2)			\
	set	ERPT_TYPE_CPU, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_REPORT_TYPE]			;\
	setx	0x10000000000002, reg2, reg1				;\
	stx	reg1, [erpt_vbsc + EVBSC_EHDL]				;\
	setx	0x002a372a4, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_STICK]				;\
	setx	0x3e002310000607, reg2, reg1				;\
	stx	reg1, [erpt_vbsc + EVBSC_CPUVER]			;\
	setx	0x000000000, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_CPUSERIAL]			;\
	setx	0x000020000, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_SPARC_AFSR]			;\
	setx	0x000830550, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_SPARC_AFAR]			;\
	setx	0x400000402, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_TSTATE]			;\
	setx	0x000000800, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_HTSTATE]			;\
	setx	0x000800610, reg2, reg1					;\
	stx	reg1, [erpt_vbsc + EVBSC_TPC]				;\
	set	0x0, reg1						;\
	stuh	reg1, [erpt_vbsc + EVBSC_CPUID]				;\
	set	0x63, reg1						;\
	stuh	reg1, [erpt_vbsc + EVBSC_TT]				;\
	set	0x1, reg1						;\
	stub	reg1, [erpt_vbsc + EVBSC_TL]				;\
	set	0x3, reg1						;\
	stub	reg1, [erpt_vbsc + EVBSC_ERREN]


/*
 * vbsc_rx
 *
 * %g1 callback cookie (guest struct?XXX)
 * %g2 svc pointer
 * %g7 return address
 */
	ENTRY(vbsc_rx)
	ROOT_STRUCT(%g1)
	ldx	[%g1 + CONFIG_VBSC_SVCH], %g1

	mov	%g7, %g6
	PRINT("vbsc_rx: "); PRINTX(%g1); PRINT("\r\n"); 
	mov	%g6, %g7

	ldx	[%g2 + SVC_CTRL_RECV + SVC_LINK_PA], %g2
	inc	SVC_PKT_SIZE, %g2 ! skip the header

	/*
	 * We don't defer packets so clear the recv pending flag.
	 * This is called on the cpu handling the interrupts so
	 * the contents of the buffer will not get clobbered until
	 * we return.
	 */
	ld	[%g2 + SVC_CTRL_STATE], %g3
	andn	%g3, SVC_FLAGS_RI, %g3
	st	%g3, [%g2 + SVC_CTRL_STATE]	! clear RECV pending

	/*
	 * Dispatch command
	 */
	ldub	[%g2 + 6], %g4
	cmp	%g4, VBSC_CMD_GUEST_STATE
	be,pn	%xcc, gueststatecmd
	cmp	%g4, VBSC_CMD_HV
	be,pn	%xcc, hvcmd
	cmp	%g4, VBSC_CMD_READMEM
	be,pn	%xcc, dbgrd
	cmp	%g4, VBSC_CMD_WRITEMEM
	be,pn	%xcc, dbgwr
	cmp	%g4, VBSC_CMD_SENDERR
	be,pn	%xcc, dbg_send_error
	nop
vbsc_rx_finished:
	HVRET


/*
 * hvcmd - Hypervisor Command
 */
hvcmd:
	ldub	[%g2 + 7], %g4
	cmp     %g4, 'I'
	be,pn	%xcc, hvcmd_ping
	nop
	ba,a	vbsc_rx_finished

	/*
	 * hvcmd_ping - nop, just respond
	 */
hvcmd_ping:
	CPU_STRUCT(%g2)
	inc	CPU_SCR0, %g2
	setx	VBSC_ACK(VBSC_CMD_HV, 'I'), %g4, %g3
	stx	%g3, [%g2 + 0x0]
	rdpr	%tpc, %g3
	st	%g3, [%g2 + 0xc]
	srlx	%g3, 32, %g3
	st	%g3, [%g2 + 0x8]
	ba,pt	%xcc, svc_internal_send	! returns to caller!!!!
	mov	16, %g3		! len


/*
 * gueststatecmd - Request from VBSC to change guest state
 */
gueststatecmd:
	ldub	[%g2 + 7], %g4
	cmp	%g4, GUEST_STATE_CMD_SHUTREQ
	be,pn	%xcc, hvcmd_guest_shutdown_request ! buf[1] = xid
	nop
	ba,a	vbsc_rx_finished

	/*
	 * hvcmd_guest_shutdown_request - notify a guest to shutdown
	 */
hvcmd_guest_shutdown_request:
	ba,pt	%xcc, 1f
	rd	%pc, %g3
	.word	0, 0		!  8 xwords
	.word	0, 0
	.word	0, 0
	.word	0, 0
	.word	0, 0
	.word	0, 0
	.word	0, 0
	.word	0, 0
	.word	0		! extra 4 bytes for alignment
1:	inc	7, %g3
	andn	%g3, 0x7, %g3	! align


	!! %g2 = packet
	!! %g3 = sun4v erpt buffer

#if 0
	/*
	 * Could check the XID against the current guest's XID
	 * but what's the point?  There's only one guest.
	 */
	ldx	[%g2 + 0x8], %g4	! xid
#endif

	/*
	 * Fill in the only additional data in this erpt, the
	 * grace period before shutdown (seconds)
	*/
#define	ESUN4V_G_SECS	ESUN4V_G_PAD
	ldx	[%g2 + 0x10], %g4 ! grace period in seconds
	sth	%g4, [%g3 + ESUN4V_G_SECS]

	/*
	 * Fill in the generic parts of the erpt
	 */
	GEN_SEQ_NUMBER(%g4, %g5)
	stx	%g4, [%g3 + ESUN4V_G_EHDL]

	rd	STICK, %g4
	stx	%g4, [%g3 + ESUN4V_G_STICK]

	set	EDESC_WARN_RESUMABLE, %g4
	stw	%g4, [%g3 + ESUN4V_EDESC]

	set	(ERR_ATTR_MODE(ERR_MODE_UNKNOWN) | EATTR_SECS), %g4
	stw	%g4, [%g3 + ESUN4V_ATTR]

	stx	%g0, [%g3 + ESUN4V_RA]
	stw	%g0, [%g3 + ESUN4V_SZ]
	sth	%g0, [%g3 + ESUN4V_G_CPUID]

	mov	%g3, %g2
	CPU_STRUCT(%g1)
	ba,pt	%xcc, queue_resumable_erpt ! tail call, returns to caller
	nop


	/*
	 * dbgrd - perform read transaction on behalf of vbsc
	 */
dbgrd:
	ldx	[%g2 + 8], %g3		! ADDR
	ldub	[%g2 + 7], %g6		! size
	sub	%g6, '0', %g6
	ldub	[%g2 + 5], %g4		! asi?
	cmp	%g4, 'A'
	bne,pt	%xcc, 1f
	sllx	%g6, 2, %g6			! offset
	add	%g6, 4*4, %g6			! offset of ASIs
	srlx	%g3, 56, %g4
	and	%g4, 0xff, %g4
	wr	%g4, %asi
	sllx	%g3, 8, %g3
	srlx	%g3, 8, %g3			! bits 0-56
1:	ba	1f
	rd	%pc, %g4
	ldub	[%g3], %g6
	lduh	[%g3], %g6
	ld	[%g3], %g6
	ldx	[%g3], %g6
	lduba	[%g3] %asi, %g6
	lduha	[%g3] %asi, %g6
	lda	[%g3] %asi, %g6
	ldxa	[%g3] %asi, %g6
1:      add	%g4, 4, %g4
	jmp	%g4 + %g6			! CTI COUPLE!!
	ba	1f				! CTI COUPLE!!
	nop					! NEVER EXECUTED!! DONT DELETE
1:	ba	1f
	rd	%pc, %g2
.word	0			! data buffer - upper 32 bits
.word	0			! data buffer - lower 32 bits
1:	add	%g2, 4, %g2	! buf
	st	%g6, [%g2 + 4]	! low bits
	srlx	%g6, 32, %g6
	st	%g6, [%g2 + 0]  ! upper bits
	ba	svc_internal_send  ! returns to caller!!!!
	mov	8, %g3		! len

	/*
	 * dbgwr - perform write transaction on behalf of vbsc
	 */
dbgwr:
	ldx	[%g2 + 0x10], %g3 ! ADDR
	ldub	[%g2 + 7], %g6	! size
	sub	%g6, '0', %g6
	ldub	[%g2 + 5], %g1	! asi?
	cmp	%g1, 'A'
	bne,pt	%xcc, 1f
	sllx	%g6, 2, %g6                     ! offset
	add	%g6, 4*4, %g6                   ! offset of ASIs
	srlx	%g3, 56, %g4
	and	%g4, 0xff, %g4
	wr	%g4, %asi
	sllx	%g3, 8, %g3
	srlx    %g3, 8, %g3                     ! bits0-56
1:	ba	1f
	rd	%pc, %g4
	stb	%g1, [%g3]
	sth	%g1, [%g3]
	st	%g1, [%g3]
	stx	%g1, [%g3]
	stba	%g1, [%g3] %asi
	stha	%g1, [%g3] %asi
	sta	%g1, [%g3] %asi
	stxa	%g1, [%g3] %asi
1:	add	%g4, 4, %g4
	ldx	[%g2 + 8], %g1                  ! get data
	jmp	%g4 + %g6                       ! CTI COUPLE!!
	jmp	%g7 + 4                         ! All done.
	nop					! NEVER EXECUTED!!!

	/*
	 * dbg_send_error - send a fake error transaction back to vbsc
	 */
dbg_send_error:
#ifdef DEBUG
	/*
	 * Fill the error reports with valid information to
	 * help test interaction with the FERG on the vbsc
	 */
	mov	%g7, %g6
	CPU_STRUCT(%g3)
	add	%g3, CPU_CE_RPT + CPU_VBSC_ERPT, %g4
	SIM_IRC_DIAG_ERPT(%g4, %g5, %g7)
	add	%g3, CPU_UE_RPT + CPU_VBSC_ERPT, %g4
	SIM_IRU_DIAG_ERPT(%g4, %g5, %g7)
	PRINT("\r\n")
	mov	%g6, %g7
#endif

	CPU_PUSH(%g7, %g1, %g2, %g3)
	CPU_STRUCT(%g1)
	add	%g1, CPU_CE_RPT + CPU_UNSENT_PKT, %g2
	ldx	[%g1 + CPU_ROOT], %g6 	

#ifdef DEBUG
	/*
	 * Send one error and mark another buffer to be
	 * sent
	 */
	mov	1, %g7
	stx	%g7, [%g6 + CONFIG_ERRS_TO_SEND]
	set	CPU_UE_RPT + CPU_UNSENT_PKT, %g3
	add	%g1, %g3, %g3
	stx	%g7, [%g3]
#endif
	add	%g1, CPU_CE_RPT + CPU_VBSC_ERPT, %g1
	mov	EVBSC_SIZE, %g3
	HVCALL(send_diag_erpt)
	CPU_POP(%g7, %g1, %g2, %g3)
	HVRET
	SET_SIZE(vbsc_rx)

 
/*
 * vbsc_tx
 *
 * %g1 callback cookie
 * %g2 packet 
 * %g7 return address
 */
	ENTRY(vbsc_tx)
	mov 	%g7, %g6
	PRINT("vbsc_tx: ")
	PRINTX(%g1)
	PRINT("\r\n")
	mov	%g6, %g7

	HVRET
	SET_SIZE(vbsc_tx)

 
#define	r_tmp1	%l0
#define	r_tmp2	%l1
#define	r_tmp3	%l2
#define	r_tmp4	%l3
#define	r_return %l7
	! We own the entire machine..
	ENTRY(svc_vbsc_init)
	mov	%g7, r_return
	add	%i0, CONFIG_VBSC_DBGERROR, %g1
	SVC_REGISTER(debugt, XPID_HV, SID_VBSC_CTL, vbsc_rx, vbsc_tx)
	brz,a,pn %g1, hvabort
	  mov	ABORT_VBSC_REGISTER, %g1
	stx	%g1, [%i0 + CONFIG_VBSC_SVCH]
	jmp	r_return + 4
	nop
	SET_SIZE(svc_vbsc_init)
#undef	r_tmp1
#undef	r_tmp2
#undef	r_tmp3
#undef	r_tmp4
#undef	r_return

#endif /*  CONFIG_SVC && CONFIG_DEBUGSVC  */
