/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: main.s
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

	.ident	"@(#)main.s	1.63	06/04/26 SMI"

	.file	"main.s"

/*
 * Niagara startup code
 */

#include <sys/asm_linkage.h>
#include <sparcv9/misc.h>
#include <hprivregs.h>
#include <asi.h>
#include <traps.h>
#include <sun4v/traps.h>
#include <dram.h>
#include <sun4v/mmu.h>
#include <sun4v/asi.h>
#include <sun4v/queue.h>
#include <devices/pc16550.h>
#include <hypervisor.h>

#include <guest.h>
#include <offsets.h>
#include <md.h>
#include <cpu.h>
#include <cpu_errs.h>
#include <config.h>
#include <cyclic.h>
#include <util.h>
#include <abort.h>

#include <debug.h>
#undef PRINT /* Don't use trapping version in this code */
#undef PRINTW /* Don't use trapping version in this code */
#undef PRINTX /* Don't use trapping version in this code */


	ENTRY_NP(start_master)
	!! save incoming arguments
	mov	%g1, %i0	! membase
	mov	%g2, %i1	! memsize
	mov	%g3, %i2	! hypervisor description

#ifdef CONFIG_HVUART /* clobbers %g1,%g2,%g3,%g7 */
	! init hv console UART XXX we don't know the address yet!
	setx	HV_UART, %g2, %g1
	HVCALL(uart_init)
#endif

	PRINT_NOTRAP("Entering hypervisor\r\n")

	/*
	 * Determine if we're running in RAM or ROM
	 */
	rd	%pc, %g4
	srlx	%g4, 32, %g4	! in rom?
	cmp	%g4, 0x80	! bits <39,32>
	blu,pt	%xcc, .master_nocopy ! no, in ram already
	nop

	/*
	 * Running from ROM
	 *
	 * Scrub the memory that we're going to copy ourselves
	 * into.
	 */
	PRINT_NOTRAP("Scrubbing initial RAM\r\n")
	mov	%i0, %g1
	setx	htraptable, %g7, %g2
	setx	_edata, %g7, %g3
	brnz	%g3, 0f
	nop
	setx	_etext, %g7, %g3
0:	
	! align to next 64-byte boundary
	inc	(64 - 1), %g3
	andn	%g3, (64 - 1), %g3
	sub	%g3, %g2, %g2
	HVCALL(memscrub)

	/*
	 * Currently executing in ROM, copy to RAM
	 */
	PRINT_NOTRAP("Copying from ROM to RAM\r\n")

	RELOC_OFFSET(%g1, %g5)	! %g5 = offset

	mov	%i0, %g2	! membase
	setx	htraptable, %g7, %g1
	sub	%g1, %g5, %g1
	setx	_edata, %g7, %g3
	brnz	%g3, 0f
	nop
	setx	_etext, %g7, %g3
0:
	sub	%g3, %g5, %g3

	sub	%g3, %g1, %g3
	inc	7, %g3
	andn	%g3, 7, %g3
	HVCALL(xcopy)

	mov	%i0, %g1	! membase
	mov	%i1, %g2	! memsize
	mov	%i2, %g3	! hypervisor description
	add	%i0, (TT_POR * TRAPTABLE_ENTRY_SIZE), %g4	! master offset
	jmp	%g4
	nop

.master_nocopy:
	wrpr	%g0, 1, %tl
	wrpr	%g0, NWINDOWS - 2, %cansave
	wrpr	%g0, NWINDOWS - 2, %cleanwin	! XXX?
	wrpr	%g0, 0, %canrestore
	wrpr	%g0, 0, %otherwin
	wrpr	%g0, 0, %cwp
	wrpr	%g0, 0, %wstate


	RELOC_OFFSET(%g1, %g5)	! %g5 = offset
	setx	htraptable, %g3, %g1
	sub	%g1, %g5, %g1
	wrhpr	%g1, %htba
/* XXX get out of red mode?  and lower %gl earlier */

	!! %g5 offset

#ifdef DEBUG
	PRINT_NOTRAP("Running from RAM\r\n")
	PRINT_NOTRAP("Hypervisor version: ")
	HVCALL(printversion)
#endif

	PRINT_NOTRAP("Scrubbing remaining hypervisor RAM\r\n")
	setx	_edata, %g7, %g1
	brnz	%g1, 0f
	nop
	setx	_etext, %g7, %g1
0:
	! align to next 64-byte boundary
	add	%g1, (64 - 1), %g1
	andn	%g1, (64 - 1), %g1
	sub	%g1, %g5, %g1	! Start address
	add	%i0, %i1, %g2	! end address + 1
	sub	%g2, %g1, %g2	! length = end+1 - start
	HVCALL(memscrub)

	!! %g5 offset
	setx	config, %g6, %g1
	sub	%g1, %g5, %g6	! %g6 - global config

	setx	_end, %g7, %g1
	! align to next 64-byte boundary
	add	%g1, (64 - 1), %g1
	andn	%g1, (64 - 1), %g1
	sub	%g1, %g5, %g1
	stx	%g1, [%g6 + CONFIG_HEAP]
	stx	%g1, [%g6 + CONFIG_BRK]
	add	%i0, %i1, %g1
	stx	%g1, [%g6 + CONFIG_LIMIT]

	mov	%g6, %i0	! %i0 - global config

	stx	%g5, [%i0 + CONFIG_RELOC]
	stx	%i2, [%i0 + CONFIG_HVD]
	mov	%i2, %i4
	!! %i4 - hypervisor description

	setx	guests, %g6, %g1
	sub	%g1, %g5, %i1
	!! %i1 - guests base
	stx	%i1, [%i0 + CONFIG_GUESTS]

	setx	cpus, %g6, %g1
	sub	%g1, %g5, %i2
	!! %i2 - cpu base
	stx	%i2, [%i0 + CONFIG_CPUS]

	setx	cores, %g6, %g1
	sub	%g1, %g5, %i3
	!! %i3 - cores base
	stx	%i3, [%i0 + CONFIG_CORES]

	HVCALL(setup_hdesc)

#ifdef CONFIG_HVUART
	LOOKUP_TAG_NODE(%i0, HDNAME_ROOT, %o0, %o2)
	LOOKUP_TAG_PROP_VAL(%i0, HDNAME_HVUART, %o1, %o2)
	GETNODEPROP_BY_TAG(%i4, %o0, %o1)
	bne,a,pn %xcc, hvabort
	  mov	ABORT_NOHVUART, %g1
	stx	%g1, [%i0 + CONFIG_HVUART_ADDR]
#endif

	LOOKUP_TAG_NODE(%i0, HDNAME_ROOT, %o0, %o2)
	LOOKUP_TAG_PROP_VAL(%i0, HDNAME_TOD, %o1, %o2)
	GETNODEPROP_BY_TAG(%i4, %o0, %o1)
	movne	%xcc, 0, %g1	! if tod doesn't exist simply don't use it
0:	stx	%g1, [%i0 + CONFIG_TOD]

	LOOKUP_TAG_NODE(%i0, HDNAME_ROOT, %o0, %o2)
	LOOKUP_TAG_PROP_VAL(%i0, HDNAME_TODFREQUENCY, %o1, %o2)
	GETNODEPROP_BY_TAG(%i4, %o0, %o1)
	movne	%xcc, 1, %g1	! default of divide by 1
0:	stx	%g1, [%i0 + CONFIG_TODFREQUENCY]

	LOOKUP_TAG_NODE(%i0, HDNAME_ROOT, %o0, %o2)
	LOOKUP_TAG_PROP_VAL(%i0, HDNAME_STICKFREQUENCY, %o1, %o2)
	GETNODEPROP_BY_TAG(%i4, %o0, %o1)
	movne	%xcc, 0, %g1
0:	stx	%g1, [%i0 + CONFIG_STICKFREQUENCY]

	LOOKUP_TAG_NODE(%i0, HDNAME_ROOT, %o0, %o2)
	LOOKUP_TAG_PROP_ARC(%i0, HDNAME_GUESTS, %o1, %o2)
	GETNODEPROP_BY_TAG(%i4, %o0, %o1)
	bne,a,pn %xcc, hvabort
	  mov	ABORT_NOGUESTS, %g1
	stx	%g1, [%i0 + CONFIG_GUESTS_DTNODE]

	LOOKUP_TAG_NODE(%i0, HDNAME_ROOT, %o0, %o2)
	LOOKUP_TAG_PROP_ARC(%i0, HDNAME_CPUS, %o1, %o2)
	GETNODEPROP_BY_TAG(%i4, %o0, %o1)
	bne,a,pn %xcc, hvabort
	  mov	ABORT_NOCPUS, %g1
	stx	%g1, [%i0 + CONFIG_CPUS_DTNODE]

	/* root devices node, 0 if it doesn't exist */
	LOOKUP_TAG_NODE(%i0, HDNAME_ROOT, %o0, %o2)
	LOOKUP_TAG_PROP_ARC(%i0, HDNAME_DEVICES, %o1, %o2)
	GETNODEPROP_BY_TAG(%i4, %o0, %o1)
	bne,a,pn %xcc, 0f
	  mov	0, %g1
0:	stx	%g1, [%i0 + CONFIG_DEVS_DTNODE]

	/* erpt-pkt buffer address, 0 if it doesn't exist */
	LOOKUP_TAG_NODE(%i0, HDNAME_ROOT, %o0, %o2)
	LOOKUP_TAG_PROP_VAL(%i0, HDNAME_ERPT_PA, %o1, %o2)
	GETNODEPROP_BY_TAG(%i4, %o0, %o1)
	movne	%xcc, 0, %g1
0:      stx	%g1, [%i0 + CONFIG_ERPT_PA]

	/* erpt-pkt buffer size, 0 if it doesn't exist */
	LOOKUP_TAG_NODE(%i0, HDNAME_ROOT, %o0, %o2)
	LOOKUP_TAG_PROP_VAL(%i0, HDNAME_ERPT_SIZE, %o1, %o2)
	GETNODEPROP_BY_TAG(%i4, %o0, %o1)
	movne	%xcc, 0, %g1
0:	stx	%g1, [%i0 + CONFIG_ERPT_SIZE]
 
         
#ifdef CONFIG_SVC
	/* root services node, 0 if it doesn't exist */
	LOOKUP_TAG_NODE(%i0, HDNAME_ROOT, %o0, %o2)
	LOOKUP_TAG_PROP_ARC(%i0, HDNAME_SERVICES, %o1, %o2)
	GETNODEPROP_BY_TAG(%i4, %o0, %o1)
	bne,a,pn %xcc, 0f
	  mov	0, %g1
0:	stx	%g1, [%i0 + CONFIG_SVCS_DTNODE]
#endif

	/* intrtgt cpuid property, default intrtg=0 if it doesn't exist */
	LOOKUP_TAG_NODE(%i0, HDNAME_ROOT, %o0, %o2)
	LOOKUP_TAG_PROP_VAL(%i0, HDNAME_INTRTGT, %o1, %o2)
	GETNODEPROP_BY_TAG(%i4, %o0, %o1)
	bne,a,pn %xcc, 0f
	  mov	0, %g1		! XXX current cpu if not set
0:	stx	%g1, [%i0 + CONFIG_INTRTGT]

	/*
	 * Initialize error_lock
	 */
	stx	%g0, [%i0 + CONFIG_ERRORLOCK]

	/*
	 * Initialize the error buffer in use flag
	 */
	stx	%g0, [%i0 + CONFIG_SRAM_ERPT_BUF_INUSE]

	/*
	 * Initialize the max length we impose on any memory APIs to the guest
	 *
	 * Try to grab if from the PD first, if not there, we set our own value
	 */
	LOOKUP_TAG_NODE(%i0, HDNAME_ROOT, %o0, %o2)
	LOOKUP_TAG_PROP_VAL(%i0, HDNAME_MEMSCRUBMAX, %o1, %o2)
	GETNODEPROP_BY_TAG(%i4, %o0, %o1)
	setx	MEMSCRUB_MAX_DEFAULT, %g3, %g2
	movne	%xcc, %g2, %g1	! default value if getprop failed
	set	MEMSYNC_ALIGNMENT - 1, %g3
	btst	%g3, %g1
	movnz	%xcc, %g2, %g1
	stx	%g1, [%i0 + CONFIG_MEMSCRUB_MAX]

	/*
	 * Initialize the blackout time for correctable errors.
	 *
	 * Try to grab if from the PD first, if not there, we set our own value
	 */
	LOOKUP_TAG_NODE(%i0, HDNAME_ROOT, %o0, %o2)
	LOOKUP_TAG_PROP_VAL(%i0, HDNAME_CEBLACKOUTSEC, %o1, %o2)
	GETNODEPROP_BY_TAG(%i4, %o0, %o1)
	movne	%xcc, 6, %g1				! default = 6 sec
	set	1 * 60 * 60, %g2			! max is 1 hour!!
	cmp	%g1, %g2				! min(%g1, %g2)
	movg	%xcc, %g2, %g1
	ldx	[%i0 + CONFIG_STICKFREQUENCY], %g2	! 1 sec ticks
	mulx	%g1, %g2, %g1				! time in stick/
	stx	%g1, [%i0 + CONFIG_CE_BLACKOUT]		! ticks

	setx	devinstances, %g2, %g1
	ldx	[%i0 + CONFIG_RELOC], %g3
	sub	%g1, %g3, %g2
	stx	%g2, [%i0 + CONFIG_DEVINSTANCES]

	set	256, %g1
	mulx	%g1, DEVINST_SIZE, %g1
2:	sub	%g1, 8, %g1
	ldx	[%g2 + %g1], %g4
	brnz,a	%g4, 1f
	  sub	%g4, %g3, %g4
1:	brgz	%g1, 2b
	  stx	%g4, [%g2 + %g1]

	/*
	 * Setup this strand's HSCRATCH0 to solve dependencies
	 * on it in the setup routines
	 */
	rd	STR_STATUS_REG, %g3
	srlx	%g3, STR_STATUS_CPU_ID_SHIFT, %g3
	and	%g3, STR_STATUS_CPU_ID_MASK, %g3
	set	CPU_SIZE, %g2
	mulx	%g3, %g2, %g3
	ldx	[%i0 + CONFIG_CPUS], %g1
	add	%g1, %g3, %g1
	mov	HSCRATCH0, %g2
	stxa	%g1, [%g2]ASI_HSCRATCHPAD
	stx	%i0, [%g1 + CPU_ROOT]

	/*
	 * Setup everything else
	 */
	HVCALL(setup_cores)
	HVCALL(setup_cpus)
	HVCALL(setup_guests)
	HVCALL(setup_dummytsb)
	HVCALL(setup_iob)
	HVCALL(setup_jbi)
	/*
	 * Enable JBI error interrupts and clear SSIERROR
	 * mask (%g1 = 1)
	 */
	setx	JBI_INTR_ONLY_ERRS, %g2, %g1
	mov	1, %g2
	HVCALL(setup_jbi_err_interrupts)
	HVCALL(setup_devops)

#ifdef CONFIG_SVC /* { */
	HVCALL(setup_services)

	/* Must be before setup_vbsc_svc */
	HVCALL(setup_err_svc)
#ifdef CONFIG_VBSC_SVC
	HVCALL(setup_vbsc_svc)
#endif
#ifdef CONFIG_CN_SVC
	HVCALL(setup_cn_svc)
#endif
#endif /* } CONFIG_SVC */

#ifdef CONFIG_FIRE
	HVCALL(setup_fire)
#endif

#ifdef DEBUG
	ldx	[%i0 + CONFIG_BRK], %g1
	ldx	[%i0 + CONFIG_LIMIT], %g2
	cmp	%g1, %g2
	blu,pt	%xcc, 1f
	nop
	PRINT_NOTRAP("XXX Dynamic allocations overflowed hypervisor memory region\r\n")
1:
#endif

#ifdef CONFIG_VBSC_SVC
	PRINT_NOTRAP("Sending HV start message to vbsc\r\n")
	HVCALL(vbsc_hv_start)
#endif
	/*
	 * Setup the cyclic max delay time:
	 */
	set	CYCLIC_MAX_DAYS, %g1			! default
	setx	(24 * 60 * 60), %g3, %g2		! seconds per day
	mulx	%g1, %g2, %g1				! => seconds
	ldx	[%i0 + CONFIG_STICKFREQUENCY], %g2	! ticks per second
	mulx	%g1, %g2, %g1				! => ticks
	stx	%g1, [%i0 + CONFIG_CYCLIC_MAXD]		! ticks

	/*
	 * Setup the Error Steer & Start the Polling Daemon:
	 */
	setx	L2_CONTROL_REG, %g1, %g4
	ldx	[%g4], %g3	
	setx	(NCPUS -1) << L2_ERRORSTEER_SHIFT, %g1, %g2
	andn	%g3, %g2, %g3				! remove current
	rd	STR_STATUS_REG, %g1			! this cpu
	srlx	%g1, STR_STATUS_CPU_ID_SHIFT, %g1	! right justify
	sllx	%g1, L2_ERRORSTEER_SHIFT, %g1		! position for CReg
	and	%g1, %g2, %g1				! mask
	or	%g3, %g1, %g3				! insert
	stx	%g3, [%g4]				! set to this cpu
	/*
	 * Initialize the poll daemon cyclic time.
	 *
	 * Try to grab if from the PD first, if not there, we set our own value
	 */
	LOOKUP_TAG_NODE(%i0, HDNAME_ROOT, %o0, %o2)
	LOOKUP_TAG_PROP_VAL(%i0, HDNAME_CEPOLLSEC, %o1, %o2)
	GETNODEPROP_BY_TAG(%i4, %o0, %o1)
	movne	%xcc, 30, %g1				! default = 30 sec!!
	set	12 * 60 * 60, %g2			! max is 12 hours!!
	cmp	%g1, %g2				! min(%g1, %g2)
	movg	%xcc, %g2, %g1
	ldx	[%i0 + CONFIG_STICKFREQUENCY], %g2	! ticks per sec
	mulx	%g1, %g2, %g2				! time in ticks
	stx	%g2, [%i0 + CONFIG_CE_POLL_TIME]	! ticks

	!! %g1-7 modified
	HVCALL(err_poll_daemon_start)			! start the daemon

	/*
	 * Start heartbeat
	 */
	HVCALL(heartbeat_enable)


	/*
	 * Start other processors
	 *
	 * XXX - TODO:	 start only the boot cpus, RESUME the others
	 * from the hcall that starts a cpu
	 */
	ldx	[%i0 + CONFIG_CPUSTARTSET], %g2
	rd	STR_STATUS_REG, %g3
	srlx	%g3, STR_STATUS_CPU_ID_SHIFT, %g3
	and	%g3, STR_STATUS_CPU_ID_MASK, %g3
	!! %g3 = current cpu
	mov	1, %g4
	sllx	%g4, %g3, %g3
	andn	%g2, %g3, %g2	! remove curcpu from set
	mov	NCPUS - 1, %g1

	setx	IOBBASE + INT_VEC_DIS, %g4, %g5
1:	mov	1, %g3
	sllx	%g3, %g1, %g3
	btst	%g2, %g3
	bz,pn	%xcc, 2f
	mov	INT_VEC_DIS_TYPE_RESUME, %g4
	sllx	%g4, INT_VEC_DIS_TYPE_SHIFT, %g4
	sllx	%g1, INT_VEC_DIS_VCID_SHIFT, %g3 ! target strand
	or	%g4, %g3, %g3	! int_vec_dis value
	stx	%g3, [%g5]

2:	deccc	%g1
	bgeu,pt	%xcc, 1b
	nop

	!! %i0 config
	!! %i2 base of cpus

	ba,a	find_work	! Expects %i2 = base of cpus
	SET_SIZE(start_master)

	ENTRY_NP(start_slave)
	!! save incoming arguments
	mov	%g1, %i0	! membase
	mov	%g2, %i1	! memsize
	mov	%g3, %i2	! hypervisor description

	rd	%pc, %g4
	srlx	%g4, 32, %g4	! in rom?
	cmp	%g4, 0x80	! bits <39,32>
	blu,pt	%xcc, 1f	! no, in ram already
	nop
	add	%i0, (TT_POR * TRAPTABLE_ENTRY_SIZE) + 0x10, %g4 ! slave offset
	jmp	%g4		! goto ram traptable
	nop
1:
	RELOC_OFFSET(%g1, %g5)	! %g5 = offset
	setx	htraptable, %g3, %g1
	sub	%g1, %g5, %g1
	wrhpr	%g1, %htba

	setx	config, %g4, %g2
	sub	%g2, %g5, %g2
	ldx	[%g2 + CONFIG_CPUS], %i2


	!! %i2 - base of cpus
find_work:
	rd	STR_STATUS_REG, %g1
	srlx	%g1, STR_STATUS_CPU_ID_SHIFT, %g1
	and	%g1, STR_STATUS_CPU_ID_MASK, %g4
	!! %g4 = current cpu id

	set	CPU_SIZE, %g6
	mulx	%g6, %g4, %g6
	add	%i2, %g6, %i3	! %i3 - cur cpu

	mov	1, %g6
	sllx	%g6, %g4, %g6	! %g6 cpuset of curcpu

	ldx	[%i3 + CPU_GUEST], %g1
	ldx	[%g1 + GUEST_CPUSET], %g7

	btst	%g6, %g7
	bnz,a,pt %xcc, start_cpu ! expects %g1 = guest, %g2 = cpu
	  mov	%i3, %g2

	PRINT_NOTRAP("WARNING: No guest for CPU ");
	PRINTW_NOTRAP(%g4)
	PRINT_NOTRAP(", spinning\r\n");
	/* XXX put to sleep, hvabort, etc */
2:	ba,a	2b
	SET_SIZE(start_slave)

	/*
	 * %g1 - guest struct
	 * %g2 - cpu
	 */
	ENTRY_NP(start_cpu)
	! save guest pointer in cpu struct
	mov	CPU_STATE_STOPPED, %g5
	stx	%g5, [%g2 + CPU_STATUS]

	! clear NPT
	rdpr	%tick, %g3
	cmp	%g3, 0
	bge	%xcc, 1f
	nop
	sllx	%g3, 1, %g3
	srlx	%g3, 1, %g3
	wrpr	%g3, %tick
1:

	! Set up first hypervisor scratchpad register to point
	! to cpu struct
	mov	HSCRATCH0, %g3
	stxa	%g2, [%g3]ASI_HSCRATCHPAD

	ldx	[%g1 + GUEST_BOOTCPU], %g3
	ldub	[%g2 + CPU_VID], %g4
	cmp	%g3, %g4
	be,pt	%xcc, .master_start
	nop

.slave_start:
	mov	1, %g3
	sllx	%g3, %g4, %g4	! cpuset of our virtual cpu id
	! cas into guest->cpu_active

1:
	nop; nop; nop; nop; nop; nop; nop; nop;
	ldx	[%g2 + CPU_COMMAND], %g3
	cmp	%g3, CPU_CMD_STARTGUEST
	bne,pn	%xcc, 1b
	nop

#ifdef RESETCONFIG_BROKENTICK

#define	TICK_DIFF	200

	ldx	[%g2 + CPU_CMD_ARG3], %g4
	rdpr	%tick, %g3
	sub	%g3, %g4, %g3
	cmp	%g3, -TICK_DIFF
	ble	%xcc, 2f
	cmp	%g3, TICK_DIFF
	blt	%xcc, 3f
2:	add	%g4, TICK_DIFF, %g4
	wrpr	%g4, %tick
3:
#endif

	wrpr	%g0, 1, %tl
	ldx	[%g2 + CPU_CMD_ARG0], %g3 ! pc
	ldx	[%g2 + CPU_CMD_ARG1], %g4 ! tba
	stx	%g4, [%g2 + CPU_RTBA]
	wrpr	%g3, %tnpc

	mov	%g2, %g6	! so it doesn't get clobbered by PRINT
	ba	.guest_start
	  mov	%g1, %g5

.master_start:
	!! %g1 - guest struct
	!! %g2 - cpu

	mov	%g2, %g6	! so it doesn't get clobbered by PRINT
	mov	%g1, %g5

	!! %g6 = cpu struct
	!! %g5 = guest struct

	/*
	 * Only scrub guest memory if reaset reason is POR
	 */
	set	GUEST_RESET_REASON, %g1
	ldx	[%g5 + %g1], %g1
	cmp	%g1, RESET_REASON_POR
	bne,pt	%xcc, .master_guest_scrub_done
	nop
	PRINT_NOTRAP("Scrubbing guest memory\r\n");
	ldx	[%g5 + GUEST_MEM_BASE], %g1
	ldx	[%g5 + GUEST_MEM_SIZE], %g2
	HVCALL(memscrub)
.master_guest_scrub_done:

#ifdef RESETCONFIG_ENABLEHWSCRUBBERS
/*
 * Configuration
 */
#define	DEFAULT_L2_SCRUBINTERVAL	0x100
#define	DEFAULT_DRAM_SCRUBFREQ		0xfff

/*
 * Helper macros which check if the scrubbers should be enabled, if so
 * they get enabled with the default scrub rates.
 */
#define	DRAM_SCRUB_ENABLE(dram_base, bank, reg1, reg2)			\
	.pushlocals							;\
	set	DRAM_CHANNEL_DISABLE_REG + ((bank) * DRAM_BANK_STEP), reg1 ;\
	ldx	[dram_base + reg1], reg1				;\
	brnz,pn	reg1, 1f						;\
	nop								;\
	set	DRAM_SCRUB_ENABLE_REG + ((bank) * DRAM_BANK_STEP), reg1	;\
	mov	DEFAULT_DRAM_SCRUBFREQ, reg2				;\
	stx	reg2, [dram_base + reg1]				;\
	set	DRAM_SCRUB_ENABLE_REG + ((bank) * DRAM_BANK_STEP), reg1	;\
	mov	DRAM_SCRUB_ENABLE_REG_ENAB, reg2			;\
	stx	reg2, [dram_base + reg1]				;\
    1: 	.poplocals

#define	L2_SCRUB_ENABLE(l2cr_base, bank, reg1, reg2)			\
	.pushlocals							;\
	set	bank << L2_BANK_SHIFT, reg1				;\
	ldx	[l2cr_base + reg1], reg2				;\
	btst	L2_SCRUBENABLE, reg2					;\
	bnz,pt	%xcc, 1f						;\
	nop								;\
	set	L2_SCRUBINTERVAL_MASK, reg1				;\
	andn	reg2, reg1, reg2					;\
	set	DEFAULT_L2_SCRUBINTERVAL, reg1				;\
	sllx	reg1, L2_SCRUBINTERVAL_SHIFT, reg1			;\
	or	reg1, L2_SCRUBENABLE, reg1				;\
	or	reg2, reg1, reg2					;\
	set	bank << L2_BANK_SHIFT, reg1				;\
	stx	reg2, [l2cr_base + reg1]				;\
    1: 	.poplocals

	/*
	 * Ensure all zero'd memory is flushed from the l2$
	 */
	mov	%g5, %o0
	mov	%g6, %o1
	HVCALL(l2_flush_cache)
	mov	%o1, %g6
	mov	%o0, %g5

	/*
	 * Enable the l2$ scrubber for each of the four l2$ banks
	 */
	setx	L2_CONTROL_REG, %g2, %g1
	L2_SCRUB_ENABLE(%g1, /* bank */ 0, %g2, %g3)
	L2_SCRUB_ENABLE(%g1, /* bank */ 1, %g2, %g3)
	L2_SCRUB_ENABLE(%g1, /* bank */ 2, %g2, %g3)
	L2_SCRUB_ENABLE(%g1, /* bank */ 3, %g2, %g3)

	/*
	 * Enable the Niagara memory scrubber for each enabled DRAM
	 * bank
	 */
	setx	DRAM_BASE, %g2, %g1
	DRAM_SCRUB_ENABLE(%g1, /* bank */ 0, %g2, %g3)
	DRAM_SCRUB_ENABLE(%g1, /* bank */ 1, %g2, %g3)
	DRAM_SCRUB_ENABLE(%g1, /* bank */ 2, %g2, %g3)
	DRAM_SCRUB_ENABLE(%g1, /* bank */ 3, %g2, %g3)
#endif

	/*
	 * Calculate size of guest's partition description based
	 * on the header information.
	 */
	set	GUEST_PD_PA, %g1
	ldx	[%g5 + %g1], %g1
	lduh	[%g1 + DTHDR_VER], %g2	! only check major number
	cmp	%g2, (MD_TRANSPORT_VERSION >> 16)
	bne,a,pn %xcc, hvabort
	  mov	ABORT_BAD_PDESC_VER, %g1
	lduw	[%g1 + DTHDR_NODESZ], %g2
	add	%g2, DTHDR_SIZE, %g2
	lduw	[%g1 + DTHDR_NAMES], %g3
	add	%g2, %g3, %g2
	lduw	[%g1 + DTHDR_DATA], %g3
	add	%g2, %g3, %g2
	set	GUEST_PD_SIZE, %g3
	stx	%g2, [%g5 + %g3]

	/*
	 * Copy guest's firmware image into the partition
	 */
	PRINT_NOTRAP("Guest firmware copy\r\n")
	set	GUEST_ROM_BASE, %g7
	ldx	[%g5 + %g7], %g1
	ldx	[%g5 + GUEST_MEM_BASE], %g2
	set	GUEST_ROM_SIZE, %g7
	ldx	[%g5 + %g7], %g3
	HVCALL(xcopy)

	!! %g5 - guest
	!! %g6 - cpu

#if defined(CONFIG_HVUART) && !defined(CONFIG_CN_SVC)
	/* clobbers %g1,%g2,%g3,%g7 */
	/* Setup uart */
	ldx	[%g5 + GUEST_CONSOLE + CONS_BASE], %g1	! get UART base
	HVCALL(uart_init)
#endif

#ifdef CONFIG_VBSC_SVC
	mov	%g5, %l0
	mov	%g6, %l1
	HVCALL(vbsc_guest_start)
	mov	%l1, %g6
	mov	%l0, %g5
#endif
	!! %g5 - guest
	!! %g6 - cpu

	/*
	 * Configure environment and initialize registers
	 */
	wrpr	%g0, MAXPTL + 1, %tl

	set	GUEST_ENTRY, %g1
	ldx	[%g5 + %g1], %g1
	stx	%g1, [%g6 + CPU_RTBA]
	inc	(TT_POR * TRAPTABLE_ENTRY_SIZE), %g1 ! Power-on-reset vector
	wrpr	%g1, %tnpc

	/*
	 * Enable JBI Interrupt timeout errors before entering the guest
	 * Don't clear the SSIERR mask bit (%g2 = 0) as we might already
	 * have a pending JBI error interrupt and we don't want to lose
	 * it.
	 */
	set	JBI_INTR_TO, %g1
	clr	%g2
	HVCALL(setup_jbi_err_interrupts)

	!! %g5 - guest
	!! %g6 - cpu
.guest_start:
#if 0 /* def DEBUG XXX obp times out the cpus with this output */
	DEBUG_SPINLOCK_ENTER(%g1, %g2, %g3)
	PRINT_NOTRAP("Guest starting on physical cpu: ")
	ldub	[%g6 + CPU_PID], %g1
	PRINTW_NOTRAP(%g1)
	PRINT_NOTRAP(", virtual cpu: ")
	ldub	[%g6 + CPU_VID], %g1
	PRINTW_NOTRAP(%g1)
	PRINT_NOTRAP("\r\n")
	DEBUG_SPINLOCK_EXIT(%g5)
	ldx	[%g6 + CPU_GUEST], %g5 ! restore clobbered %g5
#endif

#define	INITIAL_PSTATE	(PSTATE_PRIV | PSTATE_MM_TSO)
#define	INITIAL_TSTATE	((INITIAL_PSTATE << TSTATE_PSTATE_SHIFT) | \
	(MAXPGL << TSTATE_GL_SHIFT))

	setx	INITIAL_TSTATE, %g2, %g1
	wrpr	%g1, %tstate
	wrhpr	%g0, %htstate

	ldx	[%g5 + GUEST_PARTID], %g2
	set	IDMMU_PARTITION_ID, %g1
	stxa	%g2, [%g1]ASI_DMMU
	mov	MMU_PCONTEXT, %g1
	stxa	%g0, [%g1]ASI_MMU
	mov	MMU_SCONTEXT, %g1
	stxa	%g0, [%g1]ASI_MMU

	HVCALL(set_dummytsb_ctx0)
	HVCALL(set_dummytsb_ctxN)

	wr	%g0, 0, SOFTINT
	wrpr	%g0, PIL_15, %pil
	mov	CPU_MONDO_QUEUE_HEAD, %g1
	stxa	%g0, [%g1]ASI_QUEUE
	mov	CPU_MONDO_QUEUE_TAIL, %g1
	stxa	%g0, [%g1]ASI_QUEUE
	mov	DEV_MONDO_QUEUE_HEAD, %g1
	stxa	%g0, [%g1]ASI_QUEUE
	mov	DEV_MONDO_QUEUE_TAIL, %g1
	stxa	%g0, [%g1]ASI_QUEUE

	mov	ERROR_RESUMABLE_QUEUE_HEAD, %g1
	stxa	%g0, [%g1]ASI_QUEUE
	mov	ERROR_RESUMABLE_QUEUE_TAIL, %g1
	stxa	%g0, [%g1]ASI_QUEUE
	mov	ERROR_NONRESUMABLE_QUEUE_HEAD, %g1
	stxa	%g0, [%g1]ASI_QUEUE
	mov	ERROR_NONRESUMABLE_QUEUE_TAIL, %g1
	stxa	%g0, [%g1]ASI_QUEUE

	! clear the l2 esr regs
	! XXX need to log the nonzero error status
	set	(NO_L2_BANKS - 1), %g5		! bank select
2:
	setx	L2_ESR_BASE, %g2, %g4		! access the L2 csr
	sllx	%g5, L2_BANK_SHIFT, %g2
	or	%g4, %g2, %g4
	ldx	[%g4], %g3			! read status
	stx	%g3, [%g4]			! clear status (RW1C)
	subcc	%g5, 1, %g5
	bge	%xcc, 2b
	nop

	! clear the DRAM esr regs
	! XXX need to log the nonzero error status
	set	(NO_DRAM_BANKS - 1), %g5	! bank select
2:
	setx	DRAM_ESR_BASE, %g2, %g4		! access the dram csr
	sllx	%g5, DRAM_BANK_SHIFT, %g2
	or	%g4, %g2, %g4
	ldx	[%g4], %g3			! read status
	stx	%g3, [%g4]			! clear status (RW1C)
	subcc	%g5, 1, %g5
	bge	%xcc, 2b
	nop

	! clear CEs logged in SPARC ESR also
	setx	SPARC_CE_BITS, %g1, %g2
	stxa	%g2, [%g0]ASI_SPARC_ERR_STATUS

	! enable all errors, UEs should already be enabled
	mov	(CEEN | NCEEN), %g1
	stxa	%g1, [%g0]ASI_SPARC_ERR_EN

	! initialize the stack
	set	CPU_STACK + STACK_VAL, %g2
	add	%g6, %g2, %g1
	set	TOP, %g2
	stx	%g1, [%g6 + %g2]

	!! Non-privileged initial state
	! Clean register windows
	mov	NWINDOWS - 1, %g1
1:	wrpr	%g1, %cwp
	clr	%i0
	clr	%i1
	clr	%i2
	clr	%i3
	clr	%i4
	clr	%i5
	clr	%i6
	clr	%i7
	clr	%l0
	clr	%l1
	clr	%l2
	clr	%l3
	clr	%l4
	clr	%l5
	clr	%l6
	deccc	%g1
	bge,pn	%xcc, 1b
	clr	%l7
	! exit with %cwp == 0
	wrpr	%g0, NWINDOWS - 2, %cansave
	wrpr	%g0, NWINDOWS - 2, %cleanwin	! XXX?
	wrpr	%g0, 0, %canrestore
	wrpr	%g0, 0, %otherwin
	wrpr	%g0, 0, %wstate
	wr	%g0, %y

	! initialize fp regs
	rdpr	%pstate, %g1
	or	%g1, PSTATE_PEF, %g1
	wrpr	%g1, %g0, %pstate
	wr	%g0, FPRS_FEF, %fprs
	stx	%g0, [%g6 + CPU_SCR0]
	ldd	[%g6 + CPU_SCR0], %f0
	ldd	[%g6 + CPU_SCR0], %f2
	ldd	[%g6 + CPU_SCR0], %f4
	ldd	[%g6 + CPU_SCR0], %f6
	ldd	[%g6 + CPU_SCR0], %f8
	ldd	[%g6 + CPU_SCR0], %f10
	ldd	[%g6 + CPU_SCR0], %f12
	ldd	[%g6 + CPU_SCR0], %f14
	ldd	[%g6 + CPU_SCR0], %f16
	ldd	[%g6 + CPU_SCR0], %f18
	ldd	[%g6 + CPU_SCR0], %f20
	ldd	[%g6 + CPU_SCR0], %f22
	ldd	[%g6 + CPU_SCR0], %f24
	ldd	[%g6 + CPU_SCR0], %f26
	ldd	[%g6 + CPU_SCR0], %f28
	ldd	[%g6 + CPU_SCR0], %f30

	ldd	[%g6 + CPU_SCR0], %f32
	ldd	[%g6 + CPU_SCR0], %f34
	ldd	[%g6 + CPU_SCR0], %f36
	ldd	[%g6 + CPU_SCR0], %f38
	ldd	[%g6 + CPU_SCR0], %f40
	ldd	[%g6 + CPU_SCR0], %f42
	ldd	[%g6 + CPU_SCR0], %f44
	ldd	[%g6 + CPU_SCR0], %f46
	ldd	[%g6 + CPU_SCR0], %f48
	ldd	[%g6 + CPU_SCR0], %f50
	ldd	[%g6 + CPU_SCR0], %f52
	ldd	[%g6 + CPU_SCR0], %f54
	ldd	[%g6 + CPU_SCR0], %f56
	ldd	[%g6 + CPU_SCR0], %f58
	ldd	[%g6 + CPU_SCR0], %f60
	ldd	[%g6 + CPU_SCR0], %f62

	ldx	[%g6 + CPU_SCR0], %fsr
	wr	%g0, 0, %gsr
	wr	%g0, 0, %fprs

	!! %g6 cpu

	/*
	 * Initial arguments for the guest
	 */
	mov	CPU_STATE_RUNNING, %o0
	stx	%o0, [%g6 + CPU_STATUS]
	ldx	[%g6 + CPU_CMD_ARG2], %o0	! argument
	stx	%g0, [%g6 + CPU_COMMAND]	! clear mbox command
	membar	#Sync

        ldx     [%g6 + CPU_GUEST], %g6
	!! %g6 guest
        ldx     [%g6 + GUEST_REAL_BASE], %i0	! memory base
        ldx     [%g6 + GUEST_MEM_SIZE], %i1	! memory size
	membar	#Sync

#if 0
	/* XXX clear vecintr */
	/* XXX clear pending asynch sources (tick compare, cpu perf ctrs) */
#endif
#if 0
	/* XXX scrub all global levels */
	wrpr	%g0, 2 /* MAXPTL */, %gl
	mov	0, %g1;	mov	0, %g2;	mov	0, %g3;	mov	0, %g4
	mov	0, %g5;	mov	0, %g6;	mov	0, %g7
	wrpr	%g0, 1 /* MAXPTL - 1*/, %gl
	mov	0, %g1;	mov	0, %g2;	mov	0, %g3;	mov	0, %g4
	mov	0, %g5;	mov	0, %g6;	mov	0, %g7
	wrpr	%g0, 0 /* MAXPTL - 2 */, %gl
	mov	0, %g1;	mov	0, %g2;	mov	0, %g3;	mov	0, %g4
	mov	0, %g5;	mov	0, %g6;	mov	0, %g7
#endif
	done
	SET_SIZE(start_cpu)
