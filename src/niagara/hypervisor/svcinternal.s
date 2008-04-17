/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

	.ident	"@(#)svcinternal.s	1.9	05/08/20 SMI"

	.file	"svcinternal.s"

#ifdef CONFIG_SVC

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <sparcv9/misc.h>
#include <niagara/asi.h>
#include <niagara/mmu.h>
#include <sun4v/traps.h>
#include <sun4v/asi.h>
#include <sun4v/mmu.h>
#include <sun4v/queue.h>
#include <devices/pc16550.h>
#include <niagara/fpga.h>

#include "offsets.h"
#include "config.h"
#include "guest.h"
#include "svc.h"
#include "util.h"
#include "debug.h"


#define COPY_MACRO(src,len,dest,scr)	\
	.pushlocals			;\
1:	ldub	[src], scr		;\
	inc	src			;\
	deccc	len			;\
	stb	scr, [dest]		;\
	bnz,pt	%xcc, 1b		;\
	inc	dest			;\
	.poplocals

#define SEND_SVC_PACKET(r_root, r_svc, sc0, sc1, sc2, sc3)	\
	ldx	[r_root + HV_SVC_DATA_TXBASE], sc0		;\
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_PA], sc1	;\
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE], sc2	;\
	COPY_MACRO(sc1, sc2, sc0, sc3)				;\
	ldx	[r_root + HV_SVC_DATA_TXCHANNEL], sc1		;\
	mov	1, sc0						;\
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE], sc2	;\
	sth	sc2, [sc1 + FPGA_Q_SIZE]			;\
	sth	sc0, [sc1 + FPGA_Q_SEND]

#define LOCK(r_base, offset, r_tmp, r_tmp1)	\
	.pushlocals				;\
	add	r_base, offset, r_tmp		;\
	mov	-1, r_tmp1			;\
1:	casx	[r_tmp], %g0, r_tmp1		;\
	brlz,pn r_tmp1, 1b			;\
	  mov	-1, r_tmp1			;\
	.poplocals

#if 0 /* XXX not used, delay slot? */
#define TRYLOCK(r_base, offset, r_tmp0, r_tmp1, label)	\
	add	r_base, offset, r_tmp0		;\
	mov	-1, r_tmp1			;\
	casx	[r_tmp0], %g0, r_tmp1		;\
	brlz,pn r_tmp1, label
#endif

#define UNLOCK(r_base, offset)			\
	stx	%g0, [r_base + offset]

#define CHECKSUM_PKT(addr, len, retval, sum, tmp0) \
	.pushlocals			;\
	btst	1, len			;\
	be,pt	%xcc, 1f		;\
	mov	%g0, sum		;\
	deccc	len			;\
	ldub	[addr + len], sum	;\
1:	lduh	[addr], tmp0		;\
	add	tmp0, sum, sum		;\
	deccc	2, len			;\
	bgt,pt	%xcc, 1b		;\
	inc	2, addr			;\
2:	srl	sum, 16, tmp0		;\
	sll	sum, 16, sum		;\
	srl	sum, 16, sum		;\
	brnz,pt	tmp0, 2b		;\
	add	tmp0, sum, sum		;\
	mov	-1, len			;\
	srl	len, 16, len		;\
	xor	sum, len, retval	;\
	.poplocals

/*
 * This is the internal access to the svc driver.
 */

#define r_cookie %g1
#define r_table %g2
#define r_svc	%g3
#define r_tmp1	%g4
#define r_nsvcs %g5
#define r_svcarg %g6
#define r_tmp2	%l0
#define r_return %g7

/*
 * svc_register - Called at init time for HV access to services
 *
 * Arguments:
 * %i0 is the config root (CPU_ROOT)
 * %g1 is your cookie
 * %g2 is a pointer to your registration table
 *
 * Return values:
 * %g1 will contain the cookie that you can use to get status
 * of your channel or 0 if the attach failed.
 *
 * Your table is:
 *  <32bits>    XID
 *  <32bits>	SID
 *  <32bits>	offset of your rx callback from %g2
 *  <32bits>	offset of your tx callback from %g2
 *
 * rx callbacks are called with your cookie in %g1, the svc
 * pointer in %g2, the state is RI.  Once the packet is
 * processed the handler must clear the RI flag.
 *
 * tx callbacks are called with your cookie in %g1.
 *
 * The callback routines are called at interrupt time!!
 */
	ENTRY(svc_register)
	!! %i0 configp
	ldx	[%i0 + CONFIG_SVCS], r_svc
	brz,pn	r_svc, 7f			! No services
	nop
	ld	[r_svc + HV_SVC_DATA_NUM_SVCS], r_nsvcs	! numsvcs
	ld	[r_table + SVC_REG_SID], r_svcarg
	add	r_svc, HV_SVC_DATA_SVC, r_svc	! svc base
1:	ld	[r_svc + SVC_CTRL_XID], r_tmp2	! svc partid
	ld	[r_table + SVC_REG_XID], r_tmp1
	cmp	r_tmp2, r_tmp1	! XID match?
	bne,pn	%xcc, 8f
	  ld	[r_svc + SVC_CTRL_SID], r_tmp1	! svcid
	cmp	r_tmp1, r_svcarg
	be,pn	%xcc, 9f
8:	deccc	1, r_nsvcs
	bne,pn	%xcc, 1b
	  add	r_svc, SVC_CTRL_SIZE, r_svc	! next
7:	jmp	r_return + 4
	  mov	0, %g1				! failed!!

9:	/*
	 * Attach the callbacks to this service 
	 *
	 * Ensure intrs are disabled on the channel and set the CALLBACK flag
	 * in both the svc config and state variables 
	 */
	ld	[r_svc + SVC_CTRL_CONFIG], r_tmp1
	or	r_tmp1, SVC_CFG_CALLBACK, r_tmp1
	st	r_tmp1, [r_svc + SVC_CTRL_CONFIG]	! no intrs, no API
	ld	[r_svc + SVC_CTRL_STATE], r_tmp1
	or	r_tmp1, SVC_CFG_CALLBACK, r_tmp1 ! set CALLBACK flag
	st	r_tmp1, [r_svc + SVC_CTRL_STATE]	! no intrs, no API
	ldsw	[r_table + SVC_REG_RECV], r_tmp1
	cmp	r_tmp1, r_table
	be,pn %xcc, 1f
	  mov	0, r_tmp2
	add	r_tmp1, r_table, r_tmp2			! relocate recv
1:	stx	r_tmp2, [r_svc + SVC_CTRL_CALLBACK + SVC_CALLBACK_RX]
	ldsw	[r_table + SVC_REG_SEND], r_tmp1
	cmp	r_tmp1, r_table
	be,pn	%xcc, 1f
	  mov	0, r_tmp2
	add	r_tmp1, r_table, r_tmp2			! relocate send
1:	stx	r_tmp2, [r_svc + SVC_CTRL_CALLBACK + SVC_CALLBACK_TX]
	stx	%g1, [r_svc + SVC_CTRL_CALLBACK + SVC_CALLBACK_COOKIE]
	jmp	r_return + 4
	  mov	r_svc, %g1
	SET_SIZE(svc_register)
#undef r_cookie
#undef r_table
#undef r_svc
#undef r_tmp1
#undef r_nsvcs
#undef r_svcarg
#undef r_tmp2
#undef r_return


#define r_svc	%g1
#define r_buf	%g2
#define r_len	%g3
#define r_tmp0	%g4
#define r_tmp1	%g5
#define r_svcbuf %g6
/*
 * svc_internal_send - Use this to send a packet from inside
 * the hypervisor
 *
 * You had better be sure *you* are not holding the SVC_CTRL_LOCK..
 *
 * Arguments:
 *   %g1 = is the handle given to you by svc_register
 *   %g2 = buf
 *   %g3 = len
 *   %g7 = return address
 * Return value:
 *   %g1 == 0	- ok
 *   %g1 != 0	- failed
 */
	ENTRY(svc_internal_send)
	!! r_svc = %g1
	!! r_tmp0 = %g4
	!! r_tmp1 = %g5
	LOCK(r_svc, SVC_CTRL_LOCK, r_tmp0, r_tmp1)
	ld	[r_svc + SVC_CTRL_CONFIG], r_tmp0	! get status
	btst	SVC_CFG_TX, r_tmp0
	bnz,pt	%xcc, 1f				! cant TX on this SVC
	ld	[r_svc + SVC_CTRL_STATE], r_tmp0

	mov	-1, %g2					! return FAILED.
.svc_internal_send_fail:
2:	UNLOCK(r_svc, SVC_CTRL_LOCK)
	mov	%g2, %g1
	HVRET

1:	btst	SVC_FLAGS_TP, r_tmp0			! TX pending?
	bnz,a,pn %xcc, .svc_internal_send_fail
	  mov	-2, %g2
	ld	[r_svc + SVC_CTRL_MTU], r_tmp0		! size
	dec	SVC_PKT_SIZE, r_tmp0			! mtu -= hdr
	cmp	r_len, r_tmp0
	bgu,a,pn %xcc, .svc_internal_send_fail		! failed - too big!!
	  mov	-3, %g2
	ld	[r_svc + SVC_CTRL_STATE], r_tmp0	! get state flags
	or	r_tmp0, SVC_FLAGS_TP, r_tmp0
	st	r_tmp0, [r_svc SVC_CTRL_STATE]
	UNLOCK(r_svc, SVC_CTRL_LOCK)			! set state
	!! r_svc = %g1
	!! r_tmp0 = %g4
	!! r_tmp1 = %g5
	!! r_svcbuf = %g6
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_PA], r_svcbuf
	ld	[r_svc + SVC_CTRL_XID], r_tmp0
	st	r_tmp0, [r_svcbuf + SVC_PKT_XID]	! xpid
	sth	%g0, [r_svcbuf + SVC_PKT_SUM]		! checksum=0
	ld	[r_svc + SVC_CTRL_SID], r_tmp0
	sth	r_tmp0, [r_svcbuf + SVC_PKT_SID]	! svcid
	add	r_len, SVC_PKT_SIZE, r_tmp0
	stx	r_tmp0, [r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE] ! total size
	add	r_svcbuf, SVC_PKT_SIZE, r_tmp0		! dest
	COPY_MACRO(r_buf, r_len, r_tmp0, r_tmp1)
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE], r_len
	CHECKSUM_PKT(r_svcbuf, r_len, r_buf, r_tmp0, r_tmp1)	!
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_PA], r_svcbuf
	sth	r_buf, [r_svcbuf + SVC_PKT_SUM]		! checksum
#undef r_svcbuf
#undef r_buf
#undef r_len
#define r_root  %g2
#define r_tmp2	%g3
#define r_tmp3	%g6
1:	mov	HSCRATCH0, r_root
	ldxa	[r_root]ASI_HSCRATCHPAD, r_root		! cpu struct
	ldx	[r_root + CPU_ROOT], r_root		! data root
	ldx	[r_root + CONFIG_SVCS], r_root		! svc root
	brz,a,pn r_root, .svc_internal_send_return	! failed!
	  mov	-4, %g1
	LOCK(r_root, HV_SVC_DATA_LOCK, r_tmp0, r_tmp1)
	ldx	[r_root + HV_SVC_DATA_SENDT], r_tmp0	! Tail
	brz,pt r_tmp0, 1f
	  stx	%g0, [r_svc + SVC_CTRL_SEND + SVC_LINK_NEXT] ! svc->next = 0
	/* Tail was non NULL */
	stx	r_svc, [r_tmp0 + SVC_CTRL_SEND + SVC_LINK_NEXT]
1:	ldx	[r_root + HV_SVC_DATA_SENDH], r_tmp0	! Head
	brnz,pt	r_tmp0, 2f
	stx	r_svc, [r_root + HV_SVC_DATA_SENDT]	! set Tail
	stx	r_svc, [r_root + HV_SVC_DATA_SENDH]

	/* If fpga is busy, don't send */
	lduw	[r_root + HV_SVC_DATA_SENDBUSY], r_tmp3
	brnz,pn	r_tmp3, 2f
	nop

	/* Head == NULL.. copy to SRAM, hit TX, enable SSI interrupts.. */
	SEND_SVC_PACKET(r_root, r_svc, r_tmp0, r_tmp1, r_tmp2, r_tmp3)
2:
	UNLOCK(r_root, HV_SVC_DATA_LOCK)
	mov	0, %g1
.svc_internal_send_return:
	HVRET
	SET_SIZE(svc_internal_send)
#undef r_svc
#undef r_buf
#undef r_len
#undef r_tmp1
#undef r_tmp2

#define r_svc	%g1
#define r_buf	%g2
#define r_len	%g3
#define r_tmp0	%g4
#define r_tmp1	%g5
#define r_svcbuf %g6
/*
 * svc_internal_send_nolock - Use this to send a packet from inside
 * the hypervisor. Caller is responsible for managing the sevices locks
 *
 * Arguments:
 *   %g1 = is the handle given to you by svc_register
 *   %g2 = buf
 *   %g3 = len
 *   %g7 = return address
 * Return value:
 *   %g1 == 0	- ok
 *   %g1 != 0	- failed
 */
	ENTRY(svc_internal_send_nolock)
	ld	[r_svc + SVC_CTRL_MTU], r_tmp0		! size
	dec	SVC_PKT_SIZE, r_tmp0			! mtu -= hdr
	cmp	r_len, r_tmp0
	bgu,a,pn %xcc, .svc_internal_send_fail_nolock	! failed - too big!!
	  mov	-3, %g2
	ld	[r_svc + SVC_CTRL_STATE], r_tmp0	! get state flags
	or	r_tmp0, SVC_FLAGS_TP, r_tmp0
	st	r_tmp0, [r_svc SVC_CTRL_STATE]
	!! r_svc = %g1
	!! r_tmp0 = %g4
	!! r_tmp1 = %g5
	!! r_svcbuf = %g6
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_PA], r_svcbuf
	ld	[r_svc + SVC_CTRL_XID], r_tmp0
	st	r_tmp0, [r_svcbuf + SVC_PKT_XID]	! xpid
	sth	%g0, [r_svcbuf + SVC_PKT_SUM]		! checksum=0
	ld	[r_svc + SVC_CTRL_SID], r_tmp0
	sth	r_tmp0, [r_svcbuf + SVC_PKT_SID]	! svcid
	add	r_len, SVC_PKT_SIZE, r_tmp0
	stx	r_tmp0, [r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE] ! total size
	add	r_svcbuf, SVC_PKT_SIZE, r_tmp0		! dest
	COPY_MACRO(r_buf, r_len, r_tmp0, r_tmp1)
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE], r_len
	CHECKSUM_PKT(r_svcbuf, r_len, r_buf, r_tmp0, r_tmp1)	!
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_PA], r_svcbuf
	sth	r_buf, [r_svcbuf + SVC_PKT_SUM]		! checksum
#undef r_svcbuf
#undef r_buf
#undef r_len
#define r_root  %g2
#define r_tmp2	%g3
#define r_tmp3	%g6
1:	mov	HSCRATCH0, r_root
	ldxa	[r_root]ASI_HSCRATCHPAD, r_root		! cpu struct
	ldx	[r_root + CPU_ROOT], r_root		! data root
	ldx	[r_root + CONFIG_SVCS], r_root		! svc root
	brz,a,pn r_root, .svc_internal_send_return	! failed!
	  mov	-4, %g1
	ldx	[r_root + HV_SVC_DATA_SENDT], r_tmp0	! Tail
	brz,pt r_tmp0, 1f
	  stx	%g0, [r_svc + SVC_CTRL_SEND + SVC_LINK_NEXT] ! svc->next = 0
	/* Tail was non NULL */
	stx	r_svc, [r_tmp0 + SVC_CTRL_SEND + SVC_LINK_NEXT]
1:	ldx	[r_root + HV_SVC_DATA_SENDH], r_tmp0	! Head
	brnz,pt	r_tmp0, 2f
	  stx	r_svc, [r_root + HV_SVC_DATA_SENDT]	! set Tail
	/* Head == NULL.. copy to SRAM, hit TX, enable SSI interrupts.. */
	SEND_SVC_PACKET(r_root, r_svc, r_tmp0, r_tmp1, r_tmp2, r_tmp3)
	stx	r_svc, [r_root + HV_SVC_DATA_SENDH]
2:
	mov	0, %g1
.svc_internal_send_return_nolock:
.svc_internal_send_fail_nolock:
	HVRET
	SET_SIZE(svc_internal_send_nolock)
#undef r_svc
#undef r_buf
#undef r_len
#undef r_tmp1
#undef r_tmp2

#if 0 /* XXX unused? need to wire up for virtual interrupts */
/*
 * svc_internal_getstate - check state of a channel
 *
 * Arguments:
 *   %g1 is the handle given to you by svc_register
 * Return value:
 *   %g1 is the service state value (SVC_CTRL_STATE)
 */
	ENTRY(svc_internal_getstate)
	jmp	%g7 + 4
	  ld	[%g1 + SVC_CTRL_STATE], %g1
	SET_SIZE(svc_internal_getstate)
#endif

#endif /* CONFIG_SVC */
