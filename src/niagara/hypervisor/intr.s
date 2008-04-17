/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

	.ident	"@(#)intr.s	1.25	05/11/25 SMI"

	.file	"intr.s"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <sparcv9/misc.h>
#include <niagara/asi.h>
#include <niagara/mmu.h>
#include <niagara/hprivregs.h>
#include <sun4v/traps.h>
#include <sun4v/asi.h>
#include <sun4v/mmu.h>
#include <sun4v/queue.h>

#include "offsets.h"
#include "guest.h"
#include "cpu.h"
#include "config.h"
#include "vdev_intr.h"
#include "guest.h"
#include "util.h"
#include "abort.h"
#include <niagara/iob.h>


#define DEV_MONDO_QUEUE_ENTRY(cpu, entry, tail, scr, qfull_label,\
		 noq_label)				\
	ldx	[cpu + CPU_DEVQ_BASE], entry		;\
	brz,pn entry, noq_label				;\
	mov	DEV_MONDO_QUEUE_TAIL, scr		;\
	ldxa	[scr]ASI_QUEUE, scr			;\
	add	scr, Q_EL_SIZE, tail			;\
	add	entry, scr, entry			;\
	ldx	[cpu + CPU_DEVQ_MASK], scr		;\
	and	tail, scr, tail				;\
	mov	DEV_MONDO_QUEUE_HEAD, scr		;\
	ldxa	[scr]ASI_QUEUE, scr			;\
	cmp	tail, scr				;\
	be,pn	%xcc, qfull_label			;\
	nop

#ifdef DEBUG
/*
 * Use stxa to ASI_BLK_INIT_P to reduce memory latency.
 */
#define CLRQENTRY(r_cpu, base, offset, scr1)	\
	ldx	[r_cpu + base], scr1		;\
	add	scr1, offset, scr1		;\
	stxa	%g0, [scr1]ASI_BLK_INIT_P	;\
	membar	#Sync				;\
	stx	%g0, [scr1 + 0x08]		;\
	stx	%g0, [scr1 + 0x10]		;\
	stx	%g0, [scr1 + 0x18]		;\
	stx	%g0, [scr1 + 0x20]		;\
	stx	%g0, [scr1 + 0x28]		;\
	stx	%g0, [scr1 + 0x30]		;\
	stx	%g0, [scr1 + 0x38]
#else
#define CLRQENTRY(cpu, base, offset, scr1)
#endif

#define r_cpu   %g1
#define r_qtail %g2
#define r_qins  %g3
#define r_qmask %g4
#define r_qnext %g5
#define r_tmp1  %g6

	! Mondo handler routines
	ENTRY(cpu_mondo)
	/*
	 * Update when we were called last
	 */
	rd	%tick, r_tmp1
	stx	r_tmp1, [r_cpu + CPU_CMD_LASTPOKE]

	/*
	 * Wait for mailbox to not be busy
	 */
1:	ldx	[r_cpu + CPU_COMMAND], r_tmp1
	cmp	r_tmp1, CPU_CMD_BUSY
	be,pn	%xcc, 1b
	cmp	r_tmp1, CPU_CMD_GUESTMONDO_READY
	bne,pn	%xcc, .cpu_mondo_return
	.empty

	mov	CPU_MONDO_QUEUE_TAIL, r_qtail
	ldxa	[r_qtail]ASI_QUEUE, r_qins
	add	r_qins, Q_EL_SIZE, r_qnext
	ldx	[r_cpu + CPU_CPUQ_MASK], r_tmp1
	and	r_qnext, r_tmp1, r_qnext
	mov	CPU_MONDO_QUEUE_HEAD, r_qtail
	ldxa	[r_qtail]ASI_QUEUE, r_qmask
	cmp	r_qnext, r_qmask
	be,pn	%xcc, .cpu_mondo_return	! queue is full
	mov	CPU_MONDO_QUEUE_TAIL, r_qtail
	stxa	r_qnext, [r_qtail]ASI_QUEUE ! new tail pointer
	CLRQENTRY(r_cpu, CPU_CPUQ_BASE, r_qnext, r_tmp1)
	ldx	[r_cpu + CPU_CPUQ_BASE], r_tmp1
	add	r_qins, r_tmp1, r_qnext

	/* Fill in newly-allocated cpu mondo entry */
	ldx	[r_cpu + CPU_CMD_ARG0], r_tmp1
	stx	r_tmp1, [r_qnext + 0x0]
	ldx	[r_cpu + CPU_CMD_ARG1], r_tmp1
	stx	r_tmp1, [r_qnext + 0x8]
	ldx	[r_cpu + CPU_CMD_ARG2], r_tmp1
	stx	r_tmp1, [r_qnext + 0x10]
	ldx	[r_cpu + CPU_CMD_ARG3], r_tmp1
	stx	r_tmp1, [r_qnext + 0x18]
	ldx	[r_cpu + CPU_CMD_ARG4], r_tmp1
	stx	r_tmp1, [r_qnext + 0x20]
	ldx	[r_cpu + CPU_CMD_ARG5], r_tmp1
	stx	r_tmp1, [r_qnext + 0x28]
	ldx	[r_cpu + CPU_CMD_ARG6], r_tmp1
	stx	r_tmp1, [r_qnext + 0x30]
	ldx	[r_cpu + CPU_CMD_ARG7], r_tmp1
	stx	r_tmp1, [r_qnext + 0x38]
	membar	#Sync
	stx	%g0, [r_cpu + CPU_COMMAND] ! clear for next xcall
.cpu_mondo_return:
	jmp	%g7 + 4
	nop
	SET_SIZE(cpu_mondo)


	ENTRY(ssi_mondo)
	
	/*
	 * Abort the HV on JBUS error
	 */
	setx	JBI_ERR_LOG, %g1, %g2
	ldx	[%g2], %g2
	setx	JBI_INTR_ONLY_ERRS, %g1, %g3
	and	%g2, %g3, %g2
	brnz,a,pt %g2, hvabort
	  mov	ABORT_JBI_ERR, %g1

	/*
	 * Clear the INT_CTL.MASK bit for the SSI
	 */
	setx	IOBBASE, %g3, %g2
        stx	%g0, [%g2 + INT_CTL + INT_CTL_DEV_OFF(IOBDEV_SSIERR)]
	HVRET

	SET_SIZE(ssi_mondo)

/*
 * vdev_mondo - deliver a virtual mondo on the current cpu's
 * devmondo queue.
 *
 * %g1 - cpup
 * %g7 - return address
 * --
 */
	ENTRY(vdev_mondo)
	!! %g1 = cpup
	ldx	[%g1 + CPU_DEVQ_BASE], %g6
	!! %g6 - devq base physical address
	brz,pn	%g6, 1f
	mov	DEV_MONDO_QUEUE_TAIL, %g2
	ldxa	[%g2]ASI_QUEUE, %g3
	!! %g3 = current devq entry offset
	add	%g3, Q_EL_SIZE, %g5
	!! %g3 = next devq entry offset
	add	%g6, %g3, %g3
	!! %g3 = current devq entry physical address
	ldx	[%g1 + CPU_DEVQ_MASK], %g6
	and	%g5, %g6, %g5
	!! %g5 = next devq entry offset
	/* check to see if adding this entry overflows the queue */
	mov	DEV_MONDO_QUEUE_HEAD, %g2
	ldxa	[%g2]ASI_QUEUE, %g4
	cmp	%g5, %g4
	be,pn	%xcc, .vecintr_qfull /* XXX */
	mov	DEV_MONDO_QUEUE_TAIL, %g2
	stxa	%g5, [%g2]ASI_QUEUE ! new tail pointer
	CLRQENTRY(%g1, CPU_DEVQ_BASE, %g5, %g6)

	/*
	 * Determine vino to deliver
	 *
	 * XXX Replace with bitset of vinos that we atomically update
	 */
	ldx	[%g1 + CPU_VINTR], %g6
	stx	%g0, [%g1 + CPU_VINTR]

	CPU2GUEST_STRUCT(%g1, %g2) ! current guest
	GUEST2VDEVSTATE(%g2, %g2)
	VINO2MAPREG(%g2, %g6, %g6)
	!! %g3 = current devq entry physical address
	!! %g6 = vmapregp

	/*
	 * Update interrupt state to INTR_DELIVERED
	 */
	mov	INTR_DELIVERED, %g1
	stb	%g1, [%g6 + MAPREG_STATE]

	/*
	 * Fill in the devmondo with the vino
	 */
	ldx	[%g6 + MAPREG_DATA0], %g1
	stx	%g1, [%g3 + 0x00]
	stx	%g0, [%g3 + 0x08]
	stx	%g0, [%g3 + 0x10]
	stx	%g0, [%g3 + 0x18]
	stx	%g0, [%g3 + 0x20]
	stx	%g0, [%g3 + 0x28]
	stx	%g0, [%g3 + 0x30]
1:
	stx	%g0, [%g3 + 0x38]
	HVRET
	SET_SIZE(vdev_mondo)

	/*
	 * cpu_in_error_finish
	 * need to send a resumable pkt to Solaris
	 * The faulty cpu should have set the proper info into our
	 * ce err buf.
	 *
	 */
	ENTRY(cpu_in_error_finish)
	CPU_PUSH(%g7, %g2, %g3, %g4)		! save return address
	CPU_STRUCT(%g1)

	add	%g1, CPU_CE_RPT, %g2
	HVCALL(queue_resumable_erpt)

	CPU_POP(%g7, %g1, %g2, %g5)
	HVRET
	SET_SIZE(cpu_in_error_finish)

	! the mondo starting point.
	! given how short this is now it might make sense to inline the
	! first 3 instructions in the traptable.
	ENTRY_NP(vecintr)
#ifdef NIAGARA_ERRATUM_43
	membar	#Sync
#endif
	ldxa	[%g0]ASI_INTR_UDB_R, %g2
	HVCALL(push_mondo)
	retry

.vecintr_qfull:			! XXX need to do the right thing here
	HVRET
	SET_SIZE(vecintr)


	ENTRY(push_mondo)
	cmp	%g2, VECINTR_XCALL
	beq,pt	%xcc, cpu_mondo
	cmp	%g2, VECINTR_SSIERR
	beq,pt	%xcc, ssi_mondo
	cmp	%g2, VECINTR_DEV
	beq,pt	%xcc, dev_mondo
#ifdef CONFIG_FPGA
	cmp	%g2, VECINTR_FPGA
	beq,pt	%xcc, svc_isr
#endif
	cmp	%g2, VECINTR_VDEV
	beq,pt	%xcc, vdev_mondo
	nop
	cmp	%g2, VECINTR_CPUINERR 
	beq,pt	%xcc, cpu_in_error_finish
	nop

	! XXX unclaimed interrupt
	HVRET
	SET_SIZE(push_mondo)

/*
 * insert_device_mondo_r
 *
 * %g2 = data0
 * %g7 + 4 = return address
 */
	ENTRY_NP(insert_device_mondo_r)
	CPU_STRUCT(%g1)
	!! %g1 = cpup
	!! %g4 = entry
	!! %g5 = tail
	!! %g6 = scratch
	DEV_MONDO_QUEUE_ENTRY(%g1, %g4, %g5, %g6, .vecintr_qfull, \
		.no_devmondo_q)
	!! %g4 = new devmondo queue entry
	!! %g5 = new devmondo queue tail

	! Now store the data in %g2 at %g4

	stx	%g0, [%g4 + 0x38]
	stx	%g0, [%g4 + 0x30]
	stx	%g0, [%g4 + 0x28]
	stx	%g0, [%g4 + 0x20]
	stx	%g0, [%g4 + 0x18]
	stx	%g0, [%g4 + 0x10]
	stx	%g0, [%g4 + 0x08]
	stx	%g2, [%g4 + 0x00]

	!! %g1 = cpup
	!! %g5 = tail
	!! %g6 = scratch
	CLRQENTRY(%g1, CPU_DEVQ_BASE, %g5, %g6)

	mov	DEV_MONDO_QUEUE_TAIL, %g6
	stxa	%g5, [%g6]ASI_QUEUE ! new tail pointer
	HVRET
	SET_SIZE(insert_device_mondo_r)

/*
 * insert_device_mondo_p
 *
 * %g1 = datap
 * %g7 + 4 = return address
 *
 * %g2 - %g6 trashed
 */
	ENTRY_NP(insert_device_mondo_p)
	CPU_STRUCT(%g2)
	!! %g2 = cpup
	!! %g4 = entry
	!! %g5 = tail
	!! %g6 = scratch
	DEV_MONDO_QUEUE_ENTRY(%g2, %g4, %g5, %g6, .vecintr_qfull, \
		.no_devmondo_q)
	!! %g4 = new devmondo queue entry
	!! %g5 = new tail

	! Now store the data starting at %g4

	ldx	[%g1 + 0x38], %g3
	stx	%g3, [%g4 + 0x38]
	ldx	[%g1 + 0x30], %g3
	stx	%g3, [%g4 + 0x30]
	ldx	[%g1 + 0x28], %g3
	stx	%g3, [%g4 + 0x28]
	ldx	[%g1 + 0x20], %g3
	stx	%g3, [%g4 + 0x20]
	ldx	[%g1 + 0x18], %g3
	stx	%g3, [%g4 + 0x18]
	ldx	[%g1 + 0x10], %g3
	stx	%g3, [%g4 + 0x10]
	ldx	[%g1 + 0x08], %g3
	stx	%g3, [%g4 + 0x08]
	ldx	[%g1 + 0x00], %g3
	stx	%g3, [%g4 + 0x00]

	!! %g2 = cpup
	!! %g5 = tail
	!! %g6 = scratch
	CLRQENTRY(%g2, CPU_DEVQ_BASE, %g5, %g6)

	mov	DEV_MONDO_QUEUE_TAIL, %g6
	stxa	%g5, [%g6]ASI_QUEUE ! new tail pointer
	HVRET

.no_devmondo_q:
	/*
	 * XXX Attempting to insert a devmondo w/o a queue.
	 * The spec is not clear on what to do in this case
	 * so for now, assume it is a guest programming error
	 * and drop the mondo.
	 */
	HVRET
	SET_SIZE(insert_device_mondo_p)

/*
 * dev_mondo - handle an incoming JBus mondo
 *
 * %g1 = cpup
 * %g7 + 4 = return address
 */
	ENTRY(dev_mondo)
	!! XXX Check BUSY bit and ignore the dev mondo if it is not set
	setx	IOBINT, %g4, %g6
	ldx	[%g6 + J_INT_ABUSY], %g4
	btst	J_INT_BUSY_BUSY, %g4
	bz,pn	%xcc, 2f			! Not BUSY .. just ignore
	ldx	[%g6 + J_INT_DATA0], %g2	! DATA0
	stx	%g0, [%g6 + J_INT_ABUSY]	! Clear BUSY bit

	! vINOs and what I/O bridge puts into DATA0 are
	! the same therefore we don't need to translate
	! anything here

	srlx	%g2, DEVCFGPA_SHIFT, %g3
	and	%g3, DEVIDMASK, %g3
	and	%g2, NINOSPERDEV -1 , %g4

	!! %g1 = cpup
	!! %g2 = DATA0
	!! %g3 = IGN
	!! %g4 = INO
	JMPL_VINO2DEVOP(%g2, DEVOPSVEC_MONDO_RECEIVE, %g1, %g6, 2f)
2:
	HVRET
	SET_SIZE(dev_mondo)
