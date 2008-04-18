/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: svc.s
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

	.ident	"@(#)svc.s	1.15	06/05/26 SMI"

	.file	"svc.s"

#ifdef CONFIG_SVC /* { */

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <sparcv9/misc.h>
#include <asi.h>
#include <mmu.h>
#include <hprivregs.h>
#include <fpga.h>
#include <iob.h>
#include <sun4v/traps.h>
#include <sun4v/asi.h>
#include <sun4v/mmu.h>
#include <sun4v/queue.h>

#include <offsets.h>
#include <config.h>
#include <guest.h>
#include <debug.h>
#include <svc.h>
#include <abort.h>
#include <cpu.h>
#include <util.h>

#define	HCALL_RET(errno)			\
	mov	errno, %o0			;\
	done

/* May not modify condition codes */
#define LOCK(r_base, offset, r_tmp, r_tmp1)	\
	.pushlocals				;\
	add	r_base, offset, r_tmp		;\
	sub	%g0, 1, r_tmp1			;\
1:	casx	[r_tmp], %g0, r_tmp1		;\
	brlz,pn r_tmp1, 1b			;\
	  sub	%g0, 1, r_tmp1			;\
	.poplocals

/* May not modify condition codes */
/* watchout!! the branch will use the delay slot.. */
#define TRYLOCK(r_base, offset, r_tmp0, r_tmp1)	\
	add	r_base, offset, r_tmp0		;\
	sub	%g0, 1, r_tmp1			;\
	casx	[r_tmp0], %g0, r_tmp1		;\
	brlz,pn r_tmp1, herr_wouldblock		;

#ifdef SVCDEBUG
#define TRACE(x)	PRINT(x); PRINT("\r\n")
#define TRACE1(x)	PRINT(x); PRINT(": "); PRINTX(%o0); PRINT("\r\n")

#define TRACE2(x)	\
	PRINT(x); PRINT(": ");\
	PRINTX(%o0)	;\
	PRINT(", ")	;\
	PRINTX(%o1)	;\
	PRINT("\r\n")	; 

#define TRACE3(x)	\
	PRINT(x); PRINT(": ");\
	PRINTX(%o0)	;\
	PRINT(", ")	;\
	PRINTX(%o1)	;\
	PRINT(", ")	;\
	PRINTX(%o2)	;\
	PRINT("\r\n")	; 
#else
#define TRACE(s)
#define TRACE1(s)
#define TRACE2(s)
#define TRACE3(s)
#endif

/*
 * Perform service related functions
 *
 * enumerate_len(void)
 *		ret0 status
 *		ret1 len
 *
 * enumerate(buffer,len)
 *		ret0 status
 *		ret1 len
 *
 * send(svc, buffer, len)
 *		ret0 status
 *		ret1 len
 *
 * recv(svc, buffer, len)
 *		ret0 status
 *		ret1 len
 *
 * getstatus(svc)
 *		ret0 status
 *		ret1 vreg
 *
 * setstatus(svc, reg)			this is considered a SET SVC
 *		ret0 status
 *  
 * clrstatus(svc, reg)			this is considered a SET SVC
 *		ret0 status
 */
#define SVC_GET_SVC(r_g, r_s, fail_label)	\
	mov	HSCRATCH0, r_s			;\
	ldxa	[r_s]ASI_HSCRATCHPAD, r_g	;\
	ldx	[r_g + CPU_ROOT], r_s		;\
	ldx	[r_g + CPU_GUEST], r_g	 	;\
	ldx	[r_s + CONFIG_SVCS], r_s	;\
	brz,pn	r_s, fail_label			;\
	nop

	! IN
	!   %o0 = svcid
	!   %o1 = size
	!   %g1 = guest data
	!   %g2 = svc data start
	!   %g7 = return address
	!
	! OUT
	!   %g1 - trashed
	!   %g2 - ??
	!   %g3 - ??
	!   %g4 -
	!   %g5 - scratch
	!   %g6 - service pointer
	!
#define r_svcarg %o0
#define r_xpid %g1
#define	r_nsvcs %g2
#define r_tmp0 %g3
#define r_tmp1 %g4
#define r_guest %g5
#define r_svc %g6
	ENTRY_NP(findsvc)
	SVC_GET_SVC(r_guest, r_svc, 2f)
	ld	[r_svc + HV_SVC_DATA_NUM_SVCS], r_nsvcs	! numsvcs
	add	r_svc, HV_SVC_DATA_SVC, r_svc		! svc base
	set	GUEST_XID, r_xpid
	ldx	[r_guest + r_xpid], r_xpid
1:	ld	[r_svc + SVC_CTRL_XID], r_tmp0	! svc partid
	cmp	r_xpid, r_tmp0
	bne,pn	%xcc, 8f
	  ld	[r_svc + SVC_CTRL_SID], r_tmp1	! svcid
	cmp	r_tmp1, r_svcarg
	beq,pn	%xcc, 9f
8:	deccc	r_nsvcs
	bne,pn	%xcc, 1b
	  add	r_svc, SVC_CTRL_SIZE, r_svc		! next
2:	HCALL_RET(EINVAL)	! XXX was ENXIO
9:	HVRET
	SET_SIZE(findsvc)
#undef r_svcarg
#undef r_nsvcs
#undef r_xpid

#define r_svcarg %o0
#define r_xpid %g1
#define	r_nsvcs %g2
#define r_tmp0 %g3
#define r_tmp1 %g4
	
	ENTRY_NP(hcall_svc_getstatus)
	TRACE1("hcall_svc_getstatus")
	HVCALL(findsvc)
	ld	[r_svc + SVC_CTRL_CONFIG], r_tmp0
	btst	SVC_CFG_GET, r_tmp0
	bnz,pt	%xcc, 1f
	  ld	[r_svc + SVC_CTRL_STATE], r_tmp1
	HCALL_RET(EINVAL)
1:	and	r_tmp1, 0xfff, %o1		! XXX FLAGS MASK
	HCALL_RET(EOK)
	SET_SIZE(hcall_svc_getstatus)

	! In
	!   %o0 = svc
	!   %o1 = bits to set
	ENTRY_NP(hcall_svc_setstatus)
	TRACE2("hcall_svc_setstatus")
	HVCALL(findsvc)
	ld	[r_svc + SVC_CTRL_CONFIG], r_tmp0
	btst	SVC_CFG_SET, r_tmp0			! can set?
	LOCK(r_svc, SVC_CTRL_LOCK, r_tmp1, %g7)
	bnz,pt	%xcc, 1f
	  ld	[r_svc + SVC_CTRL_STATE], r_tmp1	! get state
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	HCALL_RET(EINVAL)
1:	and	r_tmp1, SVC_FLAGS_RE + SVC_FLAGS_TE, %g1
	mov	%g0, %g2				! mask
	btst	SVC_CFG_RE, r_tmp0			! svc has RE?
	bz,pt %xcc, 1f
	  btst	SVC_CFG_TE, r_tmp0			! svc has TE?
	or	%g2, SVC_FLAGS_RE, %g2			! RE bits ok
1:	bz,pt %xcc, 1f
	  btst	(1 << ABORT_SHIFT), %o1
	or	%g2, SVC_FLAGS_TE, %g2			! clr TE bits
1:	bz,pt	%xcc, 1f
	  btst	SVC_FLAGS_TP, r_tmp1		! queued?
	bz,pn	%xcc, 1f
	  nop
	! XXX need mutex.
	! need to check HEAD.. if pkt==head its too late..
	! else need to rip from the queue..
	PRINT("In Queue, Process Abort\r\n")
1:	and	%o1, %g2, %g2				! bits changed?
	xorcc	%g2, %g1, %g0
	beq,pn	%xcc, 1f
	  or	%g2, %g1, %g1
	or	r_tmp1, %g2, %g1
	st	%g1, [r_svc + SVC_CTRL_STATE]		! update state
1:
	/*
	 * Check if changing the flags requires an interrupt
	 * to be generated
	 */
	mov	r_svc, %g1
	HVCALL(svc_intr_getstate)
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	brz,pt	%g1, 1f
	nop

	/* Generate the interrupt */
	ldx	[r_svc	+ SVC_CTRL_INTR_COOKIE], %g1
	HVCALL(vdev_intr_generate)

1:	HCALL_RET(EOK)
	SET_SIZE(hcall_svc_setstatus)

	
	! In
	!  %g1 = buffer
	!  %g2 = len
	! Out
	!  %g1 = checksum
	!  %g3 = scratched
	!  %g4 = scratched
#define addr	%g1
#define len	%g2
#define tmp0	%g3
#define sum	%g4
#define retval	%g1
	ENTRY_NP(checksum_pkt)
	btst	1, len			! len&1 ?
	bz,pt	%xcc, 1f
	  mov	%g0, sum		! sum=0
	subcc	len, 1, len		! decr
	ldub	[addr + len], sum	! preload sum with last byte
	bne,pt	%xcc, 1f		! zero?
	  sub	%g0, 1, tmp0		! this will probably NEVER happen!!
	xor	sum, tmp0, retval	! return sum.
	HVRET				! as this pkt would be too short
1:	lduh	[addr], tmp0
	add	tmp0, sum, sum
	subcc	len, 2, len
	bgt,pt	%xcc, 1b
	  add	addr, 2, addr
2:	srl	sum, 16, tmp0		! get upper 16 bits
	sll	sum, 16, sum
	srl	sum, 16, sum		! chuck upper 16 bits
	brnz,pt	tmp0, 2b
	  add	tmp0, sum, sum
	sub	%g0, 1, len
	srl	len, 16, len		! 0xffff
	xor	sum, len, retval
	HVRET
#undef addr
#undef len
#undef tmp0
#undef sum
#undef retval
	SET_SIZE(checksum_pkt)


#ifdef INTR_DEBUG
#define	SEND_SVC_TRACE						\
	PRINT("svc root: "); PRINTX(r_root);			\
	PRINT(", "); PRINTX(r_svc); PRINT("\r\n");
#else
#define SEND_SVC_TRACE
#endif
	
#define SEND_SVC_PACKET(r_root, r_svc, sc0, sc1, sc2, sc3)	\
	SEND_SVC_TRACE					;	\
	ldx	[r_root + HV_SVC_DATA_TXBASE], sc0 ;		\
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_PA], sc1;	\
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE], sc2;	\
	SMALL_COPY_MACRO(sc1, sc2, sc0, sc3)	;		\
	ldx	[r_root + HV_SVC_DATA_TXCHANNEL], sc1 ;		\
	mov	1, sc0; 					\
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE], sc2;	\
	sth	sc2, [sc1 + FPGA_Q_SIZE] ;			\
	sth	sc0, [sc1 + FPGA_Q_SEND] ;

/*
 * svc send
 *
 * arg0 sid (%o0)
 * arg1 buffer (%o1)
 * arg2 size (%o2)
 * --
 * ret0 status (%o0)
 * ret1 size (%o1)
 * XXX clobbers %o4
 */
#define r_tmp2 %g1
#define r_svcbuf %o4
	ENTRY_NP(hcall_svc_send)
	TRACE3("hcall_svc_send")
	HVCALL(findsvc)
	RANGE_CHECK(r_guest, %o1, %o2, herr_noraddr, r_tmp0)
	REAL_OFFSET(r_guest, %o1, %o1, r_tmp1)	! get the buffer addr
	ld	[r_svc + SVC_CTRL_MTU], r_tmp1
	sub	r_tmp1, SVC_PKT_SIZE, r_tmp1		! mtu -= hdr
	cmp	%o2, r_tmp1
	bleu,pt	%xcc, 1f
	  ld	[r_svc + SVC_CTRL_CONFIG], r_tmp0
2:	mov	%g0, %o1				! NO HINTS
	mov	%g0, r_svcbuf				! NO HINTS
	HCALL_RET(EINVAL)				! size < 0
1:
	btst	SVC_CFG_TX, r_tmp0
	bz,pn	%xcc, 2b				! cant TX on this SVC
	LOCK(r_svc, SVC_CTRL_LOCK, r_tmp1, r_tmp2)
	ld	[r_svc + SVC_CTRL_STATE], r_tmp1	! get state flags
	btst	SVC_FLAGS_TP, r_tmp1			! tx pending already?
	bz,pt	%xcc, 1f
	  or	r_tmp1, SVC_FLAGS_TP, r_tmp1
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	mov	%g0, %o1
	mov	%g0, r_svcbuf
	HCALL_RET(EWOULDBLOCK)				! bail
1:	st	r_tmp1, [r_svc + SVC_CTRL_STATE]	! set TX pending
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_PA], r_svcbuf
	ld	[r_svc + SVC_CTRL_XID], r_tmp1
	st	r_tmp1, [r_svcbuf + SVC_PKT_XID]	! xpid
	sth	%g0, [r_svcbuf + SVC_PKT_SUM]		! checksum=0
	sth	%o0, [r_svcbuf + SVC_PKT_SID]		! svcid
	add	r_svcbuf, SVC_PKT_SIZE, %o3		! dest
	add	%o2, SVC_PKT_SIZE, %g1
	stx	%g1, [r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE] ! total pkt size
	SMALL_COPY_MACRO(%o1, %o2, %o3, %g1)
	mov	r_svcbuf, %g1
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE], %g2
	HVCALL(checksum_pkt)
	sth	%g1, [r_svcbuf + SVC_PKT_SUM]		! checksum

	! Now the fun starts, the packet is ready to go
	! but not on the tx queue yet.
	! check if it is 'linked'. A linked packet is
	! a fast path between two services, the RX, TX buffers
	! for linked services are swapped.
	ld	[r_svc + SVC_CTRL_CONFIG], r_tmp1	! get state flags
	btst	SVC_CFG_LINK, r_tmp1			! xlinked?
	bz,pt	%xcc, 1f
#ifdef CONFIG_MAGIC
	  nop
#endif
	  ldx	[r_svc + SVC_CTRL_LINK], r_tmp1		! get the linked svc
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE], r_tmp2 ! get size
	stx	r_tmp2, [r_tmp1 + SVC_CTRL_RECV + SVC_LINK_SIZE]
	LOCK(r_tmp1, SVC_CTRL_LOCK, r_tmp2, %g2)
	ld	[r_tmp1 + SVC_CTRL_STATE], r_tmp2
	or	r_tmp2, SVC_FLAGS_RI, r_tmp2
	st	r_tmp2, [r_tmp1 + SVC_CTRL_STATE]	! RECV pending
	UNLOCK(r_tmp1, SVC_CTRL_LOCK)
	btst	SVC_FLAGS_RE, r_tmp2			! RECV intr enabled?
	bz,pn	%xcc, 2f
	  ldx	[r_tmp1	+ SVC_CTRL_INTR_COOKIE], %g1	! Cookie
	PRINT("XXX - SENDING RX PENDING INTR - XXX\r\n")
	ba	vdev_intr_generate			! deliver??
	  rd	%pc, %g7
2:	HCALL_RET(EOK)
#undef r_tmp2
1:	! Normal packet, need to queue it.
	!
#define r_root r_guest
#ifdef CONFIG_MAGIC
	btst	SVC_CFG_MAGIC, r_tmp1			! magic trap?
	bz,pt	%xcc, 1f
	  nop
#ifdef DEBUG_LEGION
	ta	%xcc, 0x7f	! not a standard legion magic trap
#endif
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE], %o1
	sub	%o1, SVC_PKT_SIZE, %o1			! return bytes
	HCALL_RET(EOK)
#endif
1:	mov	HSCRATCH0, r_root
	ldxa	[r_root]ASI_HSCRATCHPAD, r_root		! cpu struct
	ldx	[r_root + CPU_ROOT], r_root		! data root
	ldx	[r_root + CONFIG_SVCS], r_root		! svc root
	LOCK(r_root, HV_SVC_DATA_LOCK, r_tmp0, r_tmp1)
	ldx	[r_root + HV_SVC_DATA_SENDT], r_tmp0	! Tail
	brz,pt r_tmp0, 1f
	  stx	%g0, [r_svc + SVC_CTRL_SEND + SVC_LINK_NEXT] ! svc->next = 0
	! Tail was non NULL.
	stx	r_svc, [r_tmp0 + SVC_CTRL_SEND + SVC_LINK_NEXT]
#ifdef INTR_DEBUG
	PRINT("Queuing packet\r\n")
#endif
1:	ldx	[r_root + HV_SVC_DATA_SENDH], r_tmp0	! Head
	brnz,pt	r_tmp0, 2f
	  stx	r_svc, [r_root + HV_SVC_DATA_SENDT]	! set Tail
	! Head == NULL.. copy to SRAM, hit TX, enable SSI interrupts..
	!
#ifdef INTR_DEBUG
	PRINT("Copy packet to sram, kick it\r\n");
#endif
	SEND_SVC_PACKET(r_root, r_svc, %o1, %o2, r_tmp0, r_tmp1)
	stx	r_svc, [r_root + HV_SVC_DATA_SENDH]
2:	UNLOCK(r_root, HV_SVC_DATA_LOCK)
	mov	%g0, %o1				! NO HINTS
	mov	%g1, %o2				! NO HINTS
	HCALL_RET(EOK)
	SET_SIZE(hcall_svc_send)
#undef r_root

/*
 * svc recv
 *
 * arg0 sid (%o0)
 * arg1 buffer (%o1)
 * arg2 size (%o2)
 * --
 * ret0 status (%o0)
 * ret1 size (%o1)
 */
	ENTRY_NP(hcall_svc_recv)
	TRACE3("hcall_svc_recv")
	HVCALL(findsvc)
	RANGE_CHECK(r_guest, %o1, %o2, herr_noraddr, r_tmp0)
	REAL_OFFSET(r_guest, %o1, %o1, r_tmp1)	! get the buffer addr
	ld	[r_svc + SVC_CTRL_CONFIG], r_tmp1	! get cfg flags
	btst	SVC_CFG_RX, r_tmp1			! can RX?
	bnz,pt	%xcc, 1f
	  ld	[r_svc + SVC_CTRL_STATE], r_tmp1	! get state flags
	! XXX was ENXIO
	mov	0, %o1					! NO HINTS
	HCALL_RET(EINVAL)				! No SVC
1:	btst	SVC_FLAGS_RI, r_tmp1			! got a pkt?
	bnz,pt	%xcc, 1f
	  ldx	[r_svc + SVC_CTRL_RECV + SVC_LINK_PA], r_svcbuf
	mov	%g0, r_svcbuf
	mov	0, %o1					! NO HINTS
	HCALL_RET(EWOULDBLOCK)				! no pkt.
1:	ldx	[r_svc + SVC_CTRL_RECV + SVC_LINK_SIZE], r_tmp1	! # bytes
	sub	r_tmp1, SVC_PKT_SIZE, r_tmp1		! remove header
	cmp	%o2, r_tmp1
	bleu,pt	%xcc, 1f				! min xfer
	  mov	%o1, %g2
	mov	r_tmp1, %o2				! return size..
1:	mov	%o2, %g3				! set size
	mov	%o2, %o1				! return size..
	add	r_svcbuf, SVC_PKT_SIZE, %g1		! src
	SMALL_COPY_MACRO(%g1,%g3,%g2,%g4)
	HCALL_RET(EOK)					! all done
	SET_SIZE(hcall_svc_recv)
#undef r_tmp2
#undef r_svcbuf


#define r_lsvc	%g5
#define r_tmp2	%g1
#define r_tmp3	%o4
#define r_tmp4	%g2
#define r_clr	%o1
	! %o0 = svc
	! %o1 = state bits
	ENTRY_NP(hcall_svc_clrstatus)
	TRACE2("hcall_svc_clrstatus")
	HVCALL(findsvc)
	ld	[r_svc + SVC_CTRL_CONFIG], r_tmp0
	btst	SVC_CFG_SET, r_tmp0			! can set?
	LOCK(r_svc, SVC_CTRL_LOCK, r_tmp1, r_tmp3)
	bnz,pt	%xcc, 1f
	  ld	[r_svc + SVC_CTRL_STATE], r_tmp1	! get state
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	HCALL_RET(EINVAL)
1:	and	r_clr, (1 << ABORT_SHIFT), r_tmp3	! permit clr of abort
	and	r_clr, r_tmp0, r_clr			! toss bad bits
	or	r_clr, r_tmp3, r_clr
	and	r_clr, r_tmp1, r_clr
	mov	r_tmp1, r_tmp3				! save current state
	mov	%g0, r_tmp4
	btst	SVC_FLAGS_RI, r_clr			! test RI
	bz,pn	%xcc, clrre				! got RI?
	  btst	SVC_CFG_RE, r_clr			! test RE
	andn	r_tmp1, SVC_FLAGS_RI, r_tmp1		! clr RI status
	btst	SVC_CFG_LINK, r_tmp0			! linked?
	bz,pt	%xcc, clrre
	  btst	SVC_CFG_RE, r_clr			! re-test RE
	! Linked service:  a clear RX done completes XFER
	ldx	[r_svc + SVC_CTRL_LINK], r_lsvc
	LOCK(r_lsvc, SVC_CTRL_LOCK, r_tmp4, %g7)
	ld	[r_lsvc + SVC_CTRL_STATE], r_tmp4	! get linked state
	andn	r_tmp4, SVC_FLAGS_TP, r_tmp4		! TP clear
	or	r_tmp4, SVC_FLAGS_TI, r_tmp4		! set TX intr
	btst	SVC_FLAGS_TE, r_tmp4			! TX INTR enabled?
	st	r_tmp4, [r_lsvc + SVC_CTRL_STATE]	! done.
	UNLOCK(r_lsvc, SVC_CTRL_LOCK)
	mov	%g0, r_tmp4				! no-linked intr
	bz,pn	%xcc, clrre
	  btst	SVC_CFG_RE, r_clr
	mov	r_lsvc, r_tmp4				! yes, linked intr
clrre:	bz,pn	%xcc, 1f				! got RE?
	  btst	SVC_CFG_TX, r_clr			! test TI
	andn	r_tmp1, SVC_FLAGS_RE, r_tmp1		! clr RE
1:	bz,pn	%xcc, 1f				! got TI?
	  btst	SVC_CFG_TE, r_clr			! test TE
	andn	r_tmp1, SVC_FLAGS_TI, r_tmp1		! clr TI
1:	bz,pn	%xcc, 1f				! got TE?
	  btst	(1 << ABORT_SHIFT), r_clr
	andn	r_tmp1, SVC_FLAGS_TE, r_tmp1		! clr TE
1:	bz,pn	%xcc, 1f				! clr Abort?
	  cmp	r_clr, %g0				! <nothing>
	andn	r_tmp1, (1 << ABORT_SHIFT), r_tmp1
1:	bz,pn	%xcc, 1f
	  xorcc	r_tmp3, r_tmp1, %g0			! bits changed?
	bz,pn	%xcc, 1f
	  mov	%g0, r_tmp3
	st	r_tmp1, [r_svc + SVC_CTRL_STATE]	! update state
1:	UNLOCK(r_svc, SVC_CTRL_LOCK)
	brz,pt	r_tmp4, 1f
	  nop
	PRINT("XXX - SENDING TX COMPLETE INTR - XXX\r\n")
	ldx	[r_lsvc	+ SVC_CTRL_INTR_COOKIE], %g1	! Cookie
	ba	vdev_intr_generate			! deliver??
	  rd	%pc, %g7
1:	HCALL_RET(EOK)
	SET_SIZE(hcall_svc_clrstatus)
#undef r_lsvc
#undef r_tmp2
#undef r_tmp3
#undef r_tmp4
#undef r_clr
#undef r_svcarg
#undef r_xpid
#undef r_nsvcs
#undef r_tmp0
#undef r_tmp1
#undef r_guest
#undef r_svc


/*
 * svc_intr_getstate - return a service's current interrupt state
 *
 * Get the state, mask with the enable bits, or TX and RX with
 * the abort bit, return the result. non-zero means intr pending.
 *
 * %g1 - svc pointer
 * --
 * %g1 - current state
 */
	ENTRY_NP(svc_intr_getstate)
	ld	[%g1 + SVC_CTRL_STATE], %g1
	and	%g1, (SVC_FLAGS_RE | SVC_FLAGS_TE), %g2	! XXX FLAGS MASK
	and	%g1, (SVC_FLAGS_RI | SVC_FLAGS_TI), %g3
	srl	%g2, 1, %g2
	and	%g2, %g3, %g2
	srl	%g2, 2, %g3
	or	%g2, %g3, %g2
	and	%g2, 1, %g2
	srl	%g1, ABORT_SHIFT, %g1		! abort..
	or	%g2, %g1, %g1
	HVRET
	SET_SIZE(svc_intr_getstate)


/*
 * svc_init - initialize the service channels
 *
 * This is called from the global setup environment
 *
 * %i0 - global config pointer
 * %g7 - return address
 */
#define r_guest	%l0
#define r_svc	%l1
#define r_nsvcs	%l2
#define r_tmp0	%l3
#define r_tmp1	%l4
#define r_return %l7
	ENTRY_NP(svc_init)
	mov	%g7, r_return	! save return address

	/*
	 * Walk through each service and setup interrupts
	 */
	ldx	[%i0 + CONFIG_SVCS], r_svc
	ld	[r_svc + HV_SVC_DATA_NUM_SVCS], r_nsvcs	! numsvcs
	add	r_svc, HV_SVC_DATA_SVC, r_svc		! svc base
9:
	ld	[r_svc + SVC_CTRL_INO], %g2		! svc ino in %g2
	ld	[r_svc + SVC_CTRL_CONFIG], r_tmp1
	btst	(SVC_CFG_RE | SVC_CFG_TE), r_tmp1
	bz,pn	%xcc, 2f
	mov	r_svc, %g4
	!! %g4 = svc cookie

	/* Determine the guest for this service */
	lduw	[r_svc + SVC_CTRL_XID], %g1
	cmp	%g1, XPID_GUESTBASE
	blu,pn	%xcc, 2f
	sub	%g1, XPID_GUESTBASE, %g1
	/* XXX GID2GUEST */
	set	GUEST_SIZE, %g3
	mulx	%g1, %g3, %g1
	ldx	[%i0 + CONFIG_GUESTS], %g3
	add	%g1, %g3, %g1
	!! %g1 = guestp

	setx	svc_intr_getstate, r_tmp1, %g3
	ldx	[%i0 + CONFIG_RELOC], r_tmp1
	sub	%g3, r_tmp1, %g3
	!! %g3 = svc_intr_getstate

	!! %g1 = guestp for service
	!! %g2 = ino
	!! %g3 = svc_intr_getstate
	!! %g4 = service cookie
	HVCALL(vdev_intr_register)
	stx	%g1, [r_svc + SVC_CTRL_INTR_COOKIE]	! save cookie
2:	deccc	r_nsvcs
	bne,pn	%xcc, 9b
	  add	r_svc, SVC_CTRL_SIZE, r_svc		! next

	/*
	 * Mailbox hardware initialization
	 */
#ifdef CONFIG_FPGA
	/* Clear previously-pending state */
	setx	FPGA_QOUT_BASE, r_tmp0, r_tmp1
	lduh	[r_tmp1 + FPGA_Q_STATUS], r_tmp0
	sth	r_tmp0, [r_tmp1 + FPGA_Q_STATUS]

	/* Enable interrupts */
	setx	FPGA_INTR_BASE, r_tmp0, r_tmp1
	mov	IRQ_QUEUE_IN | IRQ_QUEUE_OUT, r_tmp0
	sth	r_tmp0, [r_tmp1 + FPGA_INTR_ENABLE]
#endif
3:	jmp	r_return + 4
	  nop
	SET_SIZE(svc_init)
#undef r_guest
#undef r_svc
#undef r_nsvcs
#undef r_tmp0
#undef r_tmp1
#undef r_return
	

#define FPGA_INT_DISABLE(x)				\
	setx	FPGA_INTR_BASE, r_tmp2, r_tmp3		;\
	mov	x, r_tmp2				;\
	sth	r_tmp2, [r_tmp3 + FPGA_INTR_DISABLE]

#define FPGA_INT_ENABLE(x)				\
	setx	FPGA_INTR_BASE, r_tmp2, r_tmp3		;\
	mov	x, r_tmp2				;\
	sth	r_tmp2, [r_tmp3 + FPGA_INTR_ENABLE]

#define r_tmp1	%g1
#define r_tmp2	%g2
#define r_tmp3	%g3
#define r_svc	%g4
#define r_chan	%g5
#define r_root	%g6
#define r_tmp4	%g7

/*
 * svc_isr - The mailbox interrupt service routine..
 * we will retry here, as we do not expect to be 'called'
 *
 * r_cpu (%g1) comes from the mondo vector handler.
 *
 * svc_process:
 *	if (intr_status & IRQ_QUEUE_IN) {
 *		goto svc_rx_intr;
 *      }
 *	if (intr_status & IRQ_QUEUE_OUT)
 *		goto svc_tx_intr;
 *	retry;
 *
 * isr_common:
 *	UNLOCK(lock);
 *	goto svc_process;
 *
 * svc_rx_intr:
 *	...
 *	goto isr_common;
 *
 * svc_tx_intr:
 *	LOCK(lock);
 *	...
 *	goto isr_common;
 */
	ENTRY_NP(svc_isr)
	! XXX disable FPGA interrupts.
	FPGA_INT_DISABLE(IRQ_QUEUE_IN|IRQ_QUEUE_OUT)

	/*
	 * Clear the int_ctl.pend bit by writing it to zero, do not
	 * set int_ctl.clear; int_ctl.pend is read-only and cleared by
	 * hardware.
	 */
	setx	IOBBASE + INT_CTL, r_tmp3, r_tmp2
	stx	%g0, [r_tmp2 + INT_CTL_DEV_OFF(IOBDEV_SSI)]

	ldx	[%g1 + CPU_ROOT], r_root		! root data
svc_process:
	setx	FPGA_INTR_BASE, r_tmp3, r_tmp2
	lduh	[r_tmp2 + FPGA_INTR_STATUS], %g4
#ifdef INTR_DEBUG
	PRINT("Intr status: "); PRINTX(%g4); PRINT("\r\n")
#endif
	btst	IRQ_QUEUE_IN, %g4
	bnz,pt	%xcc, svc_rx_intr
	  btst	IRQ_QUEUE_OUT, %g4
	bnz,pt	%xcc, svc_tx_intr
	  nop						! more intr srcs here!
	! XXX enable FPGA interrupts.
	FPGA_INT_ENABLE(IRQ_QUEUE_IN|IRQ_QUEUE_OUT)
	retry
isr_common:
	/* reload registers */
	CPU_STRUCT(%g1)
	ldx	[%g1 + CPU_ROOT], r_root
	ldx	[r_root + CONFIG_SVCS], r_svc
	ba,a	svc_process			! r_root is ptr to root data
	SET_SIZE(svc_isr)


#define INT_ENABLE(x)			\
	ba	isr_common		;\
	  mov	x, %g1

#define	TX_INTR_DONE(x)				\
	CPU_STRUCT(%g1)				;\
	ldx	[%g1 + CPU_ROOT], r_root	;\
	ldx	[r_root + CONFIG_SVCS], r_svc	;\
	UNLOCK(r_svc, HV_SVC_DATA_LOCK)		;\
	INT_ENABLE(x)

#define RX_INTR_DONE(status,r_chan)		\
	mov	status, %g1			;\
	sth	%g1, [r_chan + FPGA_Q_STATUS]   ;\
	INT_ENABLE(IRQ_QUEUE_IN)
	
	ENTRY_NP(svc_rx_intr)
#ifdef INTR_DEBUG
	PRINT("Got an SSI FPGA RX Interrupt\r\n")
#endif
	ldx	[r_root + CONFIG_SVCS], r_svc
	ldx	[r_svc + HV_SVC_DATA_RXCHANNEL], r_chan	! regs
	lduh	[r_chan + FPGA_Q_SIZE], %g2		! len
	brz,pn	%g2, rxbadpkt
	  ldx	[r_svc + HV_SVC_DATA_RXBASE], %g1	! buffer
	HVCALL(checksum_pkt)
	brnz,pn	%g1, rxbadpkt
	  ldx	[r_root + CONFIG_SVCS], r_svc
	ld	[r_svc + HV_SVC_DATA_NUM_SVCS], r_tmp3	! numsvcs
	ldx	[r_svc + HV_SVC_DATA_RXBASE], r_tmp1	! buffer addr
	add	r_svc, HV_SVC_DATA_SVC, r_svc		! svc base
9:	ld	[r_tmp1 + SVC_PKT_XID], r_tmp2
	ld	[r_svc + SVC_CTRL_XID], r_tmp4	! svc partid
	cmp	r_tmp2, r_tmp4
	bne,pn	%xcc, 1f
	  lduh	[r_tmp1 + SVC_PKT_SID], r_tmp2
	ld	[r_svc + SVC_CTRL_SID], r_tmp4
	cmp	r_tmp2, r_tmp4
	beq,pn	%xcc, rxintr_gotone
1:	  subcc	r_tmp3, 1, r_tmp3			! nsvcs--
	bne,pn	%xcc, 9b
	  add	r_svc, SVC_CTRL_SIZE, r_svc		! next
rxsvc_abort:
	PRINT("Aborted Transport to bad XPID/SVC\r\n")
	RX_INTR_DONE(QINTR_ABORT, r_chan)
rxintr_gotone:
#ifdef INTRDEBUG
	PRINT("Found: "); PRINTX(r_svc); PRINT("\r\n")
#endif
	ld	[r_svc + SVC_CTRL_CONFIG], r_tmp4	! check config bits
	btst	SVC_CFG_RX, r_tmp4			! can RX ?
	bz,pn	%xcc, rxsvc_abort
	  ld	[r_svc + SVC_CTRL_STATE], r_tmp4
	btst	SVC_FLAGS_RI, r_tmp4			! buffer available?
	bnz,pn	%xcc, rx_busy
	  nop
	! XXX need mutex!!
	lduh	[r_chan + FPGA_Q_SIZE], r_tmp1		! len
	stx	r_tmp1, [r_svc + SVC_CTRL_RECV + SVC_LINK_SIZE] ! len
	ldx	[r_svc + SVC_CTRL_RECV + SVC_LINK_PA], r_tmp3	! dest
	ldx	[r_root + CONFIG_SVCS], r_tmp2
	ldx	[r_tmp2 + HV_SVC_DATA_RXBASE], r_tmp2		! src
	SMALL_COPY_MACRO(r_tmp2, r_tmp1, r_tmp3, r_tmp4)
	LOCK(r_svc, SVC_CTRL_LOCK, r_tmp3, r_tmp4)
	ld	[r_svc + SVC_CTRL_STATE], r_tmp4
	btst	SVC_CFG_CALLBACK, r_tmp4
#define r_hvrxcallback r_tmp4
	or	r_tmp4, SVC_FLAGS_RI, r_tmp4
	bnz,pn	%xcc, do_hvrxcallback			! HV callback
	st	r_tmp4, [r_svc + SVC_CTRL_STATE]	! RX pending
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	btst	SVC_FLAGS_RE, r_tmp4			! RECV intr enabled?
	bz,pn	%xcc, 2f
	  ldx	[r_svc + SVC_CTRL_INTR_COOKIE], %g1	! Cookie
	PRINT("XXX - SVC INTR SENDING RX PENDING INTR - XXX\r\n")
	ba	vdev_intr_generate			! deliver??
	  rd	%pc, %g7
2:
	mov	HSCRATCH0, r_root
	ldxa	[r_root]ASI_HSCRATCHPAD, r_root		! cpu struct
	ldx	[r_root + CPU_ROOT], r_root		! root data
	ldx	[r_root + CONFIG_SVCS], r_svc
	ldx	[r_svc + HV_SVC_DATA_RXCHANNEL], r_chan	! regs
	RX_INTR_DONE(QINTR_ACK, r_chan)
rx_busy:
	PRINT("SVC Buffer Busy\r\n")
	RX_INTR_DONE(QINTR_BUSY, r_chan)
rxbadpkt:
	PRINT("SVC RX Bad packet: "); PRINTX(%g1); PRINT("\r\n")
	RX_INTR_DONE(QINTR_NACK, r_chan)
	SET_SIZE(svc_rx_intr)


	ENTRY_NP(svc_tx_intr)
#ifdef INTR_DEBUG
	PRINT("Got an SSI FPGA TX Interrupt: ")
	ldx	[%g1 + CPU_ROOT], r_root			! data root
	ldx	[r_root + HV_SVC_DATA_TXCHANNEL], r_chan	! regs
	lduh	[r_chan + FPGA_Q_STATUS], r_tmp3		! status
	PRINTX(r_tmp3)
	PRINT("\r\n")
#endif
	! XXX need mutex!!
	ldx	[%g1 + CPU_ROOT], r_root			! data root
	ldx	[r_root + CONFIG_SVCS], r_root			! svc root

	LOCK(r_root, HV_SVC_DATA_LOCK, r_svc, r_chan)

	ldx	[r_root + HV_SVC_DATA_SENDH], r_svc		! head of tx q
	brz,pn	r_svc, tx_nointr
	  ldx	[r_root + HV_SVC_DATA_TXCHANNEL], r_chan	! regs
	lduh	[r_chan + FPGA_Q_STATUS], r_tmp3		! status
	sth	%g0, [r_chan + FPGA_Q_SIZE]			! len=0
	btst	QINTR_ACK, r_tmp3
	bnz,pt	%xcc, txpacket_ack
	btst	QINTR_NACK, r_tmp3
	bnz,pt	%xcc, txpacket_nack
	btst	QINTR_BUSY, r_tmp3
	bnz,pt	%xcc, txpacket_busy
	btst	QINTR_ABORT, r_tmp3
	bnz,pt	%xcc, txpacket_abort
	nop
#ifdef INTR_DEBUG
	PRINT("XXX unserviced bits in tx status register: ")
	PRINTX(r_tmp3)
	PRINT("\r\n")
#endif
	TX_INTR_DONE(IRQ_QUEUE_OUT)

txpacket_nack:
#ifdef INTR_DEBUG
	PRINT("txSVC NACK!!\r\n")
#endif
	ba	defer_pkt
	  mov	1, %g7					! Nack..

txpacket_abort:
#ifdef INTR_DEBUG
	PRINT("txSVC Abort!!\r\n")
#endif
	LOCK(r_svc, SVC_CTRL_LOCK, r_tmp2, r_tmp1)
	ld	[r_svc + SVC_CTRL_STATE], r_tmp2
	andn	r_tmp2, SVC_FLAGS_TP, r_tmp2
	or	r_tmp2, SVC_FLAG_ABORT, r_tmp2
	st	r_tmp2, [r_svc + SVC_CTRL_STATE]
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	ba	txintr_done
	  sth	r_tmp3, [r_chan + FPGA_Q_STATUS]		! clr status

txpacket_busy:
#ifdef INTR_DEBUG
	PRINT("txSVC Busy!!\r\n")
#endif
	mov	0, %g7		! ??? Ack?
	/*FALLTHROUGH*/

defer_pkt:
	!! %g7 = 1=NACK, 0=BUSY  ??? something.
	sth	r_tmp3, [r_chan + FPGA_Q_STATUS]		! clr status
#ifdef INTR_DEBUG
	PRINT("Deferring..\r\n")
#endif
	mov	HSCRATCH0, r_root
	ldxa	[r_root]ASI_HSCRATCHPAD, r_root
	ldx	[r_root + CPU_ROOT], r_root			! data root
	ldx	[r_root + CONFIG_SVCS], r_root			! svc root
#if 1 /* XXX */
	/*
	 * XXX we should delay and resend later or at least put this
	 * packet on the end of the queue so other packets have a chance.
	 */
	ldx	[r_root + HV_SVC_DATA_SENDH], r_svc		! head of tx q
	SEND_SVC_PACKET(r_root, r_svc, r_tmp1, r_tmp2, r_tmp3, r_tmp4)
	ba	txintr_done
	nop
#else
	/*
	 * Move the current head to the end of the queue:
	 *	if (head->next != NULL) {
	 *		tmp1 = head
	 *		head = tmp1->next
	 *		tmp1->next = NULL
	 *		tail->next = tmp1
	 *		tail = tmp1
	 *	}
	 */
	ldx	[r_root + HV_SVC_DATA_SENDH], r_tmp1
	ldx	[r_tmp1 + SVC_CTRL_SEND + SVC_LINK_NEXT], r_tmp2
	brz,pt	r_tmp2, hv_txintr	! only item on list
	nop
	stx	r_tmp2, [r_root + HV_SVC_DATA_SENDH]
	stx	%g0, [r_tmp1 + SVC_CTRL_SEND + SVC_LINK_NEXT]
	ldx	[r_root + HV_SVC_DATA_SENDT], r_tmp2
	stx	r_tmp1, [r_tmp2 + SVC_CTRL_SEND + SVC_LINK_NEXT]
	stx	r_tmp1, [r_root + HV_SVC_DATA_SENDT]
#ifdef INTR_DEBUG
	PRINT("round-robin\r\n")
#endif
	ba,pt	%xcc, hv_txintr
	nop
#endif

txpacket_ack:
	sth	r_tmp3, [r_chan + FPGA_Q_STATUS]		! clr status
	LOCK(r_svc, SVC_CTRL_LOCK, r_tmp2, r_tmp1)

	/* Mark busy, prevents svc_internal_send from touching fpga */
	mov	-1, r_tmp2
	stw	r_tmp2, [r_root + HV_SVC_DATA_SENDBUSY]

	/* Remove head from list prior to calling the tx callback */
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_NEXT], r_tmp2
	stx	r_tmp2, [r_root + HV_SVC_DATA_SENDH]
	brz,a,pt r_tmp2, 1f
	stx	%g0, [r_root + HV_SVC_DATA_SENDT]
1:	stx	%g0, [r_svc + SVC_CTRL_SEND + SVC_LINK_NEXT]

	ld	[r_svc + SVC_CTRL_STATE], r_tmp2
	andn	r_tmp2, SVC_FLAGS_TP, r_tmp2
	or	r_tmp2, SVC_FLAGS_TI, r_tmp2
	st	r_tmp2, [r_svc + SVC_CTRL_STATE]
	btst	SVC_CFG_CALLBACK, r_tmp2
#define r_hvtxcallback r_tmp2
	bnz,pn	%xcc, do_hvtxcallback				! HV callback
	nop
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	btst	SVC_FLAGS_TE, r_tmp2
	bz,pn	%xcc, hv_txintr
	ldx	[r_svc + SVC_CTRL_INTR_COOKIE], %g1		! Cookie
	ba	vdev_intr_generate				! deliver??
	  rd	%pc, %g7
hv_txintr:
	! rebuild the regs we care about
	mov	HSCRATCH0, %g1
	ldxa	[%g1]ASI_HSCRATCHPAD, %g1
	ldx	[%g1 + CPU_ROOT], r_root			! data root
	ldx	[r_root + CONFIG_SVCS], r_root			! svc root

	/* clear busy */
	stw	%g0, [r_root + HV_SVC_DATA_SENDBUSY]

	ldx	[r_root + HV_SVC_DATA_SENDH], r_svc		! head of tx q
#ifdef INTR_DEBUG
	PRINT("Next Packet: "); PRINTX(r_svc); PRINT("\r\n")
#endif
	brz,pn	r_svc, txintr_done
	nop
	SEND_SVC_PACKET(r_root, r_svc, r_tmp1, r_tmp2, r_tmp3, r_tmp4)
txintr_done:
	TX_INTR_DONE(IRQ_QUEUE_OUT)

tx_nointr:
	lduh	[r_chan + FPGA_Q_STATUS], r_tmp3		! get status
	sth	r_tmp3, [r_chan + FPGA_Q_STATUS]		! clr status
	TX_INTR_DONE(IRQ_QUEUE_OUT)
	SET_SIZE(svc_tx_intr)
#undef r_tmp1
#if 0
#undef r_tmp3
#undef r_tmp2
#undef r_svc
#undef r_chan
#endif

/*
 * SAVE/RESTORE_SVCREGS - save/restore all registers except %g7 which
 * gets clobbered
 */
#define SAVE_SVCREGS				\
	mov	HSCRATCH0, %g7			;\
	ldxa	[%g7]ASI_HSCRATCHPAD, %g7	;\
	add	%g7, CPU_SVCREGS, %g7		;\
	stx	%g1, [%g7 + 0x00]		;\
	stx	%g2, [%g7 + 0x08]		;\
	stx	%g3, [%g7 + 0x10]		;\
	stx	%g4, [%g7 + 0x18]		;\
	stx	%g5, [%g7 + 0x20]		;\
	stx	%g6, [%g7 + 0x28]		;

#define RESTORE_SVCREGS				\
	mov	HSCRATCH0, %g7			;\
	ldxa	[%g7]ASI_HSCRATCHPAD, %g7	;\
	add	%g7, CPU_SVCREGS, %g7		;\
	ldx	[%g7 + 0x00], %g1		;\
	ldx	[%g7 + 0x08], %g2		;\
	ldx	[%g7 + 0x10], %g3		;\
	ldx	[%g7 + 0x18], %g4		;\
	ldx	[%g7 + 0x20], %g5		;\
	ldx	[%g7 + 0x28], %g6

/*
 * Perform a hypervisor callback for a receive channel
 *
 * The callback cookie is passed in %g1.
 * The svc pointer %g2, state is RI.  If the
 * packet has been successfully processed then the callback
 * routine needs to clear the RI flag.
 */
	ENTRY_NP(do_hvrxcallback)
#ifdef INTRDEBUG
	PRINT("do_hvrxcallback\r\n")
#endif
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	ldx	[r_svc + SVC_CTRL_CALLBACK + SVC_CALLBACK_RX], %g7
	brz,pn	%g7, 9f
	  nop
	SAVE_SVCREGS
#ifdef INTRDEBUG
	PRINT("HV RX Callback: "); PRINTX(r_svc); PRINT("\r\n")
#endif
	ldx	[r_svc + SVC_CTRL_CALLBACK + SVC_CALLBACK_RX], %g7
	ldx	[r_svc + SVC_CTRL_CALLBACK + SVC_CALLBACK_COOKIE], %g1
	mov	r_svc, %g2
	jmp	%g7
	  rd	%pc, %g7
	RESTORE_SVCREGS
9:	RX_INTR_DONE(QINTR_ACK, r_chan)
	SET_SIZE(do_hvrxcallback)

	ENTRY_NP(do_hvtxcallback)
#ifdef INTRDEBUG
	PRINT("do_hvtxcallback\r\n")
#endif
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	ldx	[r_svc + SVC_CTRL_CALLBACK + SVC_CALLBACK_TX], %g1
	brz,pn	%g1, hv_txintr
	  nop
	SAVE_SVCREGS
#ifdef INTRDEBUG
	PRINT("HV TX Callback: "); PRINTX(r_svc); PRINT("\r\n")
#endif
	ldx	[r_svc + SVC_CTRL_CALLBACK + SVC_CALLBACK_TX], %g6
	ldx	[r_svc + SVC_CTRL_CALLBACK + SVC_CALLBACK_COOKIE], %g1
	!! XXX is this useful
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_PA], %g2
	add	%g2, SVC_PKT_SIZE, %g2		! skip header
	jmp	%g6
	  rd	%pc, %g7
	RESTORE_SVCREGS
9:	ba	hv_txintr
	  nop
	SET_SIZE(do_hvtxcallback)
#undef r_tmp3
#undef r_tmp2
#undef r_tmp4
#undef r_svc
#undef r_chan
	
	/*
	 * ssi_intr_redistribution
	 * 
	 * If this cpu is handling ssi intrs, move them to the tgt cpu.
	 * Once the registers are reprogrammed, we send an FPGA intr
	 * to the tgt cpu. We do this to prevent any intrs from being
	 * lost
	 *
	 * %g1 - this cpu id
	 * %g2 - tgt cpu id
	 */
	ENTRY_NP(ssi_intr_redistribution)
#ifdef CONFIG_FPGA
	CPU_PUSH(%g7, %g3, %g4, %g5)
	setx	IOBBASE, %g3, %g4
	! %g4 = IOB Base address

	/* SSI Error interrupt */
.ssi_err_change_cpu:
	ldx	[%g4 + INT_MAN + INT_MAN_DEV_OFF(IOBDEV_SSIERR)], %g3
	srlx	%g3, INT_MAN_CPU_SHIFT, %g5 ! int_man.cpu
	and	%g5, INT_MAN_CPU_MASK, %g5
	cmp	%g5, %g1
	bne,pt	%xcc, .ssi_intr_change_cpu
	nop

	! clear the current cpu value
	mov	INT_MAN_CPU_MASK, %g5
	sllx	%g5, INT_MAN_CPU_SHIFT, %g5
	andn	%g3, %g5, %g3
	sllx	%g2, INT_MAN_CPU_SHIFT, %g6
	or	%g6, %g3, %g3

	stx	%g3, [%g4 + INT_MAN + INT_MAN_DEV_OFF(IOBDEV_SSIERR)]

	/* SSI Interrupt */
.ssi_intr_change_cpu:
	ldx	[%g4 + INT_MAN + INT_MAN_DEV_OFF(IOBDEV_SSI)], %g3
	srlx	%g3, INT_MAN_CPU_SHIFT, %g5 ! int_man.cpu
	and	%g5, INT_MAN_CPU_MASK, %g5
	cmp	%g5, %g1
	bne,pt	%xcc, .mondo_errs_intr_change_cpu
	nop

	! clear the current cpu value
	mov	INT_MAN_CPU_MASK, %g5
	sllx	%g5, INT_MAN_CPU_SHIFT, %g5
	andn	%g3, %g5, %g3
	sllx	%g2, INT_MAN_CPU_SHIFT, %g6
	or	%g6, %g3, %g3

	stx	%g3, [%g4 + INT_MAN + INT_MAN_DEV_OFF(IOBDEV_SSI)]

	! send a ssi intr to other cpu so we don't miss any intrs
	sllx	%g2, INT_VEC_DIS_VCID_SHIFT, %g5
	or	%g5, VECINTR_FPGA, %g5
	stxa	%g5, [%g0]ASI_INTR_UDB_W
.mondo_errs_intr_change_cpu:

	CPU_POP(%g7, %g3, %g4, %g5)
#endif /* CONFIG_FPGA */
	HVRET
	SET_SIZE(ssi_intr_redistribution)
#endif /* CONFIG_SVC } */
