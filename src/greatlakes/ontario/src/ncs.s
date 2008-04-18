/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: ncs.s
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

	.ident	"@(#)ncs.s	1.5	06/04/26 SMI"

	.file	"ncs.s"

/*
 * Niagara API calls
 */

#include <sys/asm_linkage.h>
#include <hypervisor.h>
#include <sparcv9/misc.h>
#include <asi.h>
#include <mmu.h>
#include <sun4v/traps.h>
#include <sun4v/asi.h>
#include <sun4v/mmu.h>
#include <sun4v/queue.h>
#include <devices/pc16550.h>

#include <debug.h>
#include <config.h>
#include <guest.h>
#include <offsets.h>
#include <ncs.h>
#include <util.h>

#ifndef NCS_HVDESC_SHIFT
#error "NCS_HVDESC not a power of 2, this code assumes it is"
#endif

/* Range check and real to phys conversion macro */
#define	REAL_TO_PHYS(raddr, size, paddr, fail_label, gstruct, scr2)	 \
	GUEST_STRUCT(gstruct)						;\
	RANGE_CHECK(gstruct, raddr, size, fail_label, scr2)		;\
	REAL_OFFSET(gstruct, raddr, paddr, scr2)

#define	REAL_TO_PHYS_G(raddr, size, paddr, fail_label, gstruct, scr2)	 \
	RANGE_CHECK(gstruct, raddr, size, fail_label, scr2)		;\
	REAL_OFFSET(gstruct, raddr, paddr, scr2)

/*
 *-----------------------------------------------------------
 * Function: setup_mau()
 *	Called from setup_cores() to initialize per-MA Unit
 *	data structure.
 * Arguments:
 *	Input:
 *		%g1 - Core structure
 *		%g7 - return address
 *	Uses:	%g4, %g5
 *-----------------------------------------------------------
 */
	ENTRY_NP(setup_mau)

	mov	%g0, %g4
	ldub	[%g1 + CORE_CID], %g4		! %g4 = core->cid
	add	%g1, CORE_MAU_QUEUE, %g5	! %g5 = &core->mau_queue
	stx	%g4, [%g5 + MQ_ID]		! core->mau_queue.mq_id = core->cid
	stx	%g0, [%g5 + MQ_BUSY]
	stx	%g0, [%g5 + MQ_BASE]
	stx	%g0, [%g5 + MQ_END]
	stx	%g0, [%g5 + MQ_HEAD]
	stx	%g0, [%g5 + MQ_TAIL]
	stx	%g0, [%g5 + MQ_NENTRIES]

	jmp	%g7 + 4
	nop

	SET_SIZE(setup_mau)

/*
 *-----------------------------------------------------------
 * Function: hcall_ncs_request(int cmd, uint64_t arg, size_t sz)
 * Arguments:
 *	Input:
 *		%o5 - hcall function number
 *		%o0 - NCS sub-function
 *		%o1 - Real address of 'arg' data structure
 *		%o2 - Size of data structure at 'arg'.
 *	Output:
 *		%o0 - EOK (on success),
 *		      EINVAL, ENORADDR, EBADALIGN, EWOULDBLOCK (on failure)
 *-----------------------------------------------------------
 */
	ENTRY_NP(hcall_ncs_request)

	btst	NCS_PTR_ALIGN - 1, %o1
	bnz,pn	%xcc, herr_badalign
	nop
	/*
	 * convert %o1 to physaddr for calls below,
	 */
	REAL_TO_PHYS(%o1, %o2, %o1, herr_noraddr, %g2, %g3)

	cmp	%o0, NCS_QTAIL_UPDATE
	be	ncs_qtail_update

	cmp	%o0, NCS_QCONF
	be	ncs_qconf

	nop

	ba	herr_inval
	nop

	SET_SIZE(hcall_ncs_request)

/*
 *-----------------------------------------------------------
 * Function: ncs_qtail_update(int unused, ncs_qtail_update_arg_t *arg, size_t sz)
 * Arguments:
 *	Input:
 *		%o5 - hcall function number
 *		%o0 - NCS sub-function
 *		%o1 - ncs_qtail_update_arg_t *
 *		%o2 - sizeof (ncs_qtail_update_arg_t)
 *	Output:
 *		%o0 - EOK (on success),
 *		      EINVAL, ENORADDR, EWOULDBLOCK (on failure)
 *-----------------------------------------------------------
 */
	ENTRY_NP(ncs_qtail_update)

	cmp	%o2, NCS_QTAIL_UPDATE_ARG_SIZE
	bne,pn	%xcc, herr_inval
	nop

	ldx	[%o1 + NU_MID], %g2
	cmp	%g2, NMAUS
	bgeu,pn	%xcc, herr_inval
	nop

	CPU_STRUCT(%g7)
	CPU2GUEST_STRUCT(%g7, %g4)
	VCOREID2COREP(%g4, %g2, %o2, herr_inval, %g3)

	add	%o2, CORE_MAU_QUEUE, %g1
	!!
	!! %g1 = core.mau_queue
	!!
	/*
	 * Make sure the tail index the caller
	 * gave us is a valid one for our queue,
	 * i.e. ASSERT(mq_nentries > nu_tail).
	 */
	ldx	[%g1 + MQ_NENTRIES], %g3
	/*
	 * Error if queue not configured,
	 * i.e. MQ_NENTRIES == 0
	 */
	brz,pn	%g3, herr_inval
	nop
	ldx	[%o1 + NU_TAIL], %g2
	!!
	!! %g3 = core.mau_queue.mq_nentries
	!! %g2 = ncs_qtail_update_arg.nu_tail
	!!
	cmp	%g3, %g2
	bleu,pn	%xcc, herr_inval
	nop

	mov	%g4, %o1		! %o1 = guest struct
	/*
	 * Turn tail index passed in by caller into
	 * actual pointer into queue.
	 */
	sllx	%g2, NCS_HVDESC_SHIFT, %g3
	ldx	[%g1 + MQ_BASE], %g4
	add	%g3, %g4, %g3
	!!
	!! %g3 = &mau_queue.mq_base[nu_tail] (new mq_tail)
	!!
	stx	%g3, [%g1 + MQ_TAIL]

.qtail_dowork:
	sub	%g0, 1, %g2
	stx	%g2, [%g1 + MQ_BUSY]

	ldx	[%g1 + MQ_HEAD], %g2
	ldx	[%g1 + MQ_END], %g5
	!!
	!! %g2 = mq_head
	!! %g3 = mq_tail
	!! %g4 = mq_base
	!! %g5 = mq_end
	!!
	/*
	 * Need hw-thread-id for MA_CTL register.
	 * Start at mq_head and keep looking for work
	 * until we run into mq_tail.
	 * XXX - If this was asynchronous (nu_syncflag == NCS_ASYNC)
	 *	 then we would only do one operation then return.
	 */
	ldub	[%g7 + CPU_PID], %g7		! %g7 = physical cpuid
	and	%g7, NCPUS_PER_CORE_MASK, %g7	! phys cpuid -> hw threadid
	!!
	!! %o1 = guest struct
	!! %g7 = hw-thread-id
	!!

.qtail_loop:
	cmp	%g2, %g3			! mq_head == mq_tail?
	be,a,pn	%xcc, .qtail_done
	  stx	%g2, [%g1 + MQ_HEAD]
	/*
	 * Mark current descriptor busy.
	 */
	mov	ND_STATE_BUSY, %o0
	stx	%o0, [%g2 + NHD_STATE]		! nhd_state = BUSY
	add	%g2, NHD_REGS, %g2
	!!
	!! %g2 = ncs_hvdesc.nhd_regs
	!!
	ldx	[%g2 + MR_CTL], %o0
	!!
	!! %o0 = ncs_hvdesc.nhd_regs.nqt_ma_regs.mr_ctl
	!!
	srlx	%o0, MA_CTL_OP_SHIFT, %g6
	and	%g6, MA_CTL_OP_MASK, %g6
	!!
	!! %g6 = ncs_hvdesc.nhd_regs.nqt_ma_regs.mr_ctl.bits.operation
	!!
	/*
	 * Only check/translate address for Load/Store operations
	 */
	cmp	%g6, MA_OP_LOAD
	be	%xcc, .qtail_chk
	cmp	%g6, MA_OP_STORE
	bne,a	%xcc, .qtail_go
	  ldx	[%g2 + MR_MPA], %o0

.qtail_chk:
	and	%o0, MA_CTL_LENGTH_MASK, %o0
	!!
	!! %o0 = ncs_hvdesc.nhd_regs.nqt_ma_regs.mr_ctl.bits.length
	!!
	add	%o0, 1, %o0
	sllx	%o0, MA_WORDS2BYTES_SHIFT, %g6
	ldx	[%g2 + MR_MPA], %o0
	btst	NCS_PTR_ALIGN - 1, %o0
	bnz,a,pn %xcc, .qtail_chk_rv
	  mov	EINVAL, %o0

	REAL_TO_PHYS_G(%o0, %g6, %o0, .qtail_addr_err, %o1, %o2)

	/*
	 * Load MA register with values
	 */
.qtail_go:
	!!
	!! %o0 = PA of MR_MPA if Load/Store
	!!
#if !defined(DEBUG_LEGION)
	mov	ASI_MAU_MPA, %g6
	stxa	%o0, [%g6]ASI_STREAM_MA

	ldx	[%g2 + MR_MA], %o0
	mov	ASI_MAU_ADDR, %g6
	stxa	%o0, [%g6]ASI_STREAM_MA

	ldx	[%g2 + MR_NP], %o0
	mov	ASI_MAU_NP, %g6
	stxa	%o0, [%g6]ASI_STREAM_MA

	ldx	[%g2 + MR_CTL], %o0
	sll	%g7, MA_CTRL_STRAND_SHIFT, %g6
	or	%o0, %g6, %o0
	mov	ASI_MAU_CONTROL, %g6
#ifdef NIAGARA_ERRATUM_41
	membar	#Sync
#endif
	stxa	%o0, [%g6]ASI_STREAM_MA

	mov	EWOULDBLOCK, %o0
	mov	ASI_MAU_SYNC, %g6
	ldxa	[%g6]ASI_STREAM_MA, %o0
	/*
	 * Note that an error/abort in the MAU_SYNC operation
	 * will leave the EWOULDBLOCK in %o0.  A successful
	 * MAU_SYNC operation will load a "0" into %o0.
	 */
#else
	mov	%g0, %o0
#endif	/* !DEBUG_LEGION */

.qtail_chk_rv:
	/*
	 * Determine appropriate state to set
	 * descriptor to.
	 */
	brnz,a,pn  %o0, .qtail_set_state
	  mov	ND_STATE_ERROR, %o2
	mov	ND_STATE_DONE, %o2
.qtail_set_state:
	sub	%g2, NHD_REGS, %g2
	!!
	!! %g2 = &ncs_hvdesc
	!!
	stx	%o2, [%g2 + NHD_STATE]
	brnz,a,pn  %o0, .qtail_err
	  stx	%g2, [%g1 + MQ_HEAD]

	add	%g2, NCS_HVDESC_SIZE, %g2	! mq_head++
	cmp	%g2, %g5			! mq_head == mq_end?
	ba,pt	%xcc, .qtail_loop
	movgeu	%xcc, %g4, %g2			! mq_head = mq_base

.qtail_done:
	ba	hret_ok
	stx	%g0, [%g1 + MQ_BUSY]

.qtail_addr_err:
	ba	.qtail_chk_rv
	mov	ENORADDR, %o0

.qtail_err:
	!!
	!! %o0 = EWOULDBLOCK, EINVAL, ENORADDR
	!!
	stx	%g0, [%g1 + MQ_BUSY]
	done

	SET_SIZE(ncs_qtail_update)

/*
 *-----------------------------------------------------------
 * Function: ncs_qconf(int unused, ncs_qconf_arg_t *arg, size_t sz)
 * Arguments:
 *	Input:
 *		%o5 - hcall function number
 *		%o0 - NCS sub-function
 *		%o1 - ncs_qconf_arg_t *
 *		%o2 - sizeof (ncs_qconf_arg_t)
 *	Output:
 *		%o0 - EOK (on success),
 *		      EINVAL (on failure)
 *-----------------------------------------------------------
 */
	ENTRY_NP(ncs_qconf)

	cmp	%o2, NCS_QCONF_ARG_SIZE
	bne,pn	%xcc, herr_inval
	nop

	ldx	[%o1 + NQ_MID], %g2		! %g2 = mid
	cmp	%g2, NMAUS
	bgeu,pn	%xcc, herr_inval
	nop

	GUEST_STRUCT(%g1)
	/*
	 * XXX - really want herr_nocore.
	 *
	 * Recall that the driver code simply increments
	 * through all the possible vcore-ids when doing
	 * a qconf, regardless of whether they are actually
	 * present or not.  As a result, it is possible for
	 * the following macro to fail if a given vcore-id
	 * is not present.  This is not a critical error
	 * since the driver code will never attempt to use
	 * a non-present vcore, however the driver code
	 * cannot currently handle a "no core" error return
	 * from this HV call and since the driver code is
	 * at present off-limit for repair, we have to fake
	 * success.
	 */
	VCOREID2COREP(%g1, %g2, %g2, hret_ok, %g3)

	add	%g2, CORE_MAU_QUEUE, %g1	! %g1 = &core[mid].mau_queue
	stx	%g0, [%g1 + MQ_BUSY]

	ldx	[%o1 + NQ_BASE], %g2
	brnz,a,pt %g2, .qconf_config
	  ldx	[%o1 + NQ_END], %g3
	/*
	 * Caller wishes to unconfigure the mau_queue entry
	 * for the given MAU.
	 */
	stx	%g0, [%g1 + MQ_BASE]
	stx	%g0, [%g1 + MQ_END]
	stx	%g0, [%g1 + MQ_HEAD]
	stx	%g0, [%g1 + MQ_TAIL]
	stx	%g0, [%g1 + MQ_NENTRIES]
	HCALL_RET(EOK)

.qconf_config:
	/*
	 * %g2 = nq_base
	 * %g3 = nq_end
	 */
	or	%g2, %g3, %g5
	btst	NCS_PTR_ALIGN - 1, %g5
	bnz,pn	%xcc, herr_badalign
	nop

	sub	%g3, %g2, %g5			! %g5 = queue size (end-base)
	/*
	 * %g2 (RA(nq_base) -> PA(nq_base))
	 */
	REAL_TO_PHYS(%g2, %g5, %g2, herr_noraddr, %g4, %g6)
	/*
	 * %g3 (RA(nq_end) -> PA(nq_end))
	 */
	REAL_TO_PHYS(%g3, 8, %g3, herr_noraddr, %g4, %g6)
	/*
	 * Verify that the queue size is what
	 * we would expect, i.e. (nq_nentries << NCS_HVDESC_SHIFT)
	 */
	ldx	[%o1 + NQ_NENTRIES], %g6
	sllx	%g6, NCS_HVDESC_SHIFT, %g7
	cmp	%g5, %g7
	bne,pn	%xcc, herr_inval
	nop

	stx	%g2, [%g1 + MQ_BASE]
	/*
	 * Head and Tail initially point to Base.
	 */
	stx	%g2, [%g1 + MQ_HEAD]
	stx	%g2, [%g1 + MQ_TAIL]

	stx	%g3, [%g1 + MQ_END]
	stx	%g6, [%g1 + MQ_NENTRIES]

	HCALL_RET(EOK)
	SET_SIZE(ncs_qconf)
