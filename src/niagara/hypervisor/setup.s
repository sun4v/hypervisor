/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

	.ident	"@(#)setup.s	1.38	05/11/25 SMI"

	.file	"setup.s"

/*
 * Routines that configure the hypervisor
 */

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <niagara/hprivregs.h>
#include <niagara/asi.h>
#include <niagara/fpga.h>
#include <niagara/iob.h>
#include <sun4v/traps.h>
#include <sun4v/mmu.h>
#include <sun4v/asi.h>
#include <sun4v/queue.h>
#include <devices/pc16550.h>

#include "guest.h"
#include "offsets.h"
#include "md.h"
#include "cpu_errs.h"
#include "svc.h"
#include "vdev_intr.h"
#include "abort.h"
#include "cpu.h"
#include "util.h"
#include "debug.h"


#define	HVALLOC(root, size, ptr, tmp)		\
	ldx	[root + CONFIG_BRK], ptr	;\
	add	ptr, size, tmp			;\
	stx	tmp, [root + CONFIG_BRK]


#define	CONFIG	%i0
#define	GUESTS	%i1
#define	CPUS	%i2
#define	CORES	%i3


/*
 * setup_hdesc:	figure out the tags for the nodes/props we're
 * interested in using
 *
 * in:
 *	%i0 - global config pointer
 *	%i1 - base of guests
 *	%i2 - base of cpus
 *	%g7 - return address
 *
 * volatile:
 *	%globals, %locals, %outs
 */
	ENTRY_NP(setup_hdesc)
	mov	%g7, %l7

	ldx	[%i0 + CONFIG_HVD], %l3
	!! %l3 hvd

	lduh	[%l3 + DTHDR_VER], %l1	! only check major version
	cmp	%l1, (MD_TRANSPORT_VERSION >> 16)
	bne,a,pt %xcc, hvabort
	  mov	ABORT_BAD_HDESC_VER, %g1

	add	%i0, CONFIG_HDNAMETABLE, %l1
	!! %l1 hdnametable array

	/* pd_findname clobbers %g1-%g7, %o0-%o2 */
#define	GET_NAMEOFFSET(name, htag, hdnametable, scr1)		\
	.pushlocals						;\
	ba	1f						;\
	rd	%pc, scr1					;\
2:	.asciz	name						;\
	.align	4						;\
1:	add	scr1, 4, %g2					;\
	mov	%l3, %g1					;\
	ba	pd_findname					;\
	rd	%pc, %g7					;\
	stx	%g1, [hdnametable + htag]			;\
	.poplocals

	GET_NAMEOFFSET("root", HDNAME_ROOT, %l1, %l2)
	GET_NAMEOFFSET("hvuart", HDNAME_HVUART, %l1, %l2)
	GET_NAMEOFFSET("guest", HDNAME_GUEST, %l1, %l2)
	GET_NAMEOFFSET("guests", HDNAME_GUESTS, %l1, %l2)
	GET_NAMEOFFSET("cpu", HDNAME_CPU, %l1, %l2)
	GET_NAMEOFFSET("cpus", HDNAME_CPUS, %l1, %l2)
	GET_NAMEOFFSET("pid", HDNAME_PID, %l1, %l2)
	GET_NAMEOFFSET("vid", HDNAME_VID, %l1, %l2)
	GET_NAMEOFFSET("gid", HDNAME_GID, %l1, %l2)
	GET_NAMEOFFSET("uartbase", HDNAME_UARTBASE, %l1, %l2)
	GET_NAMEOFFSET("nvbase", HDNAME_NVBASE, %l1, %l2)
	GET_NAMEOFFSET("nvsize", HDNAME_NVSIZE, %l1, %l2)
	GET_NAMEOFFSET("rombase", HDNAME_ROMBASE, %l1, %l2)
	GET_NAMEOFFSET("romsize", HDNAME_ROMSIZE, %l1, %l2)
	GET_NAMEOFFSET("diskpa", HDNAME_DISKPA, %l1, %l2)
	GET_NAMEOFFSET("membase", HDNAME_MEMBASE, %l1, %l2)
	GET_NAMEOFFSET("memsize", HDNAME_MEMSIZE, %l1, %l2)
	GET_NAMEOFFSET("memoffset", HDNAME_MEMOFFSET, %l1, %l2)
	GET_NAMEOFFSET("realbase", HDNAME_REALBASE, %l1, %l2)
	GET_NAMEOFFSET("bootcpu", HDNAME_BOOTCPU, %l1, %l2)
	GET_NAMEOFFSET("cpuset", HDNAME_CPUSET, %l1, %l2)
	GET_NAMEOFFSET("pdpa", HDNAME_PDPA, %l1, %l2)
	GET_NAMEOFFSET("guests", HDNAME_GUESTS, %l1, %l2)
	GET_NAMEOFFSET("base", HDNAME_BASE, %l1, %l2)
	GET_NAMEOFFSET("size", HDNAME_SIZE, %l1, %l2)
	GET_NAMEOFFSET("ino", HDNAME_INO, %l1, %l2)
	GET_NAMEOFFSET("xid", HDNAME_XID, %l1, %l2)
	GET_NAMEOFFSET("sid", HDNAME_SID, %l1, %l2)
	GET_NAMEOFFSET("memory", HDNAME_MEMORY, %l1, %l2)
	GET_NAMEOFFSET("hypervisor", HDNAME_HYPERVISOR, %l1, %l2)
	GET_NAMEOFFSET("vpcidevice", HDNAME_VPCIDEVICE, %l1, %l2)
	GET_NAMEOFFSET("cfghandle", HDNAME_CFGHANDLE, %l1, %l2)
	GET_NAMEOFFSET("ign", HDNAME_IGN, %l1, %l2)
	GET_NAMEOFFSET("intrtgt", HDNAME_INTRTGT, %l1, %l2)
	GET_NAMEOFFSET("cfgbase", HDNAME_CFGBASE, %l1, %l2)
	GET_NAMEOFFSET("membase", HDNAME_MEMBASE, %l1, %l2)
	GET_NAMEOFFSET("iobase", HDNAME_IOBASE, %l1, %l2)
	GET_NAMEOFFSET("pciregs", HDNAME_PCIREGS, %l1, %l2)
	GET_NAMEOFFSET("tod", HDNAME_TOD, %l1, %l2)
	GET_NAMEOFFSET("devices", HDNAME_DEVICES, %l1, %l2)
	GET_NAMEOFFSET("device", HDNAME_DEVICE, %l1, %l2)
	GET_NAMEOFFSET("services", HDNAME_SERVICES, %l1, %l2)
	GET_NAMEOFFSET("service", HDNAME_SERVICE, %l1, %l2)
	GET_NAMEOFFSET("flags", HDNAME_FLAGS, %l1, %l2)
	GET_NAMEOFFSET("mtu", HDNAME_MTU, %l1, %l2)
	GET_NAMEOFFSET("link", HDNAME_LINK, %l1, %l2)
	GET_NAMEOFFSET("perfctraccess", HDNAME_PERFCTRACCESS, %l1, %l2)
	GET_NAMEOFFSET("diagpriv", HDNAME_DIAGPRIV, %l1, %l2)
	GET_NAMEOFFSET("tod-frequency", HDNAME_TODFREQUENCY, %l1, %l2)
	GET_NAMEOFFSET("tod-offset", HDNAME_TODOFFSET, %l1, %l2)
	GET_NAMEOFFSET("stick-frequency", HDNAME_STICKFREQUENCY, %l1, %l2)
	GET_NAMEOFFSET("ce-blackout-sec", HDNAME_CEBLACKOUTSEC, %l1, %l2)
	GET_NAMEOFFSET("ce-poll-sec", HDNAME_CEPOLLSEC, %l1, %l2)
	GET_NAMEOFFSET("memscrubmax", HDNAME_MEMSCRUBMAX, %l1, %l2)
	GET_NAMEOFFSET("erpt-pa", HDNAME_ERPT_PA, %l1, %l2)
	GET_NAMEOFFSET("erpt-size", HDNAME_ERPT_SIZE, %l1, %l2)
	GET_NAMEOFFSET("virtualdevices", HDNAME_VDEVS, %l1, %l2)
	GET_NAMEOFFSET("reset-reason", HDNAME_RESET_REASON, %l1, %l2)

	jmp	%l7 + 4
	nop
	SET_SIZE(setup_hdesc)


/*
 * setup_cores: Setup core structs - all we do right now
 *		is initialize the core id field (cid) and
 *		the MA queue structure.
 *
 * in:
 *	%i0 - global config pointer
 *	%i1 - base of guests
 *	%i2 - base of cpus
 *	%i3 - base of cores
 *	%g7 - return address
 *
 * volatile:
 *	%globals, %locals
 */
	ENTRY_NP(setup_cores)
	mov	%g7, %l7	! save return address
	mov	NCORES, %g2		! g2 = index into core[]
	mov	NCORES, %l0
	set	CORE_SIZE, %g3

.another_core:
	brz,pn	%g2, .end_cores
	dec	%g2
	mulx	%g2, %g3, %g1
	add	CORES, %g1, %g1		! g1 = &core[g2]
	stb	%g2, [%g1 + CORE_CID]	! core[g2].cid = g2
	/*
	 * Set VID to value indicating uninitialized.
	 * The VID will be set up at setup_cpus time
	 * which is called after setup_cores.
	 */
	stb	%l0, [%g1 + CORE_VID]	! core[g2].vid = MAX
	/*
	 * %g1 = Core structure
	 *
	 * Now set up per-core MA Unit structure.
	 */
	ba	setup_mau
	rd	%pc, %g7

	ba,pt	%xcc, .another_core
	nop

.end_cores:
	jmp	%l7 + 4
	nop
	SET_SIZE(setup_cores)

/*
 * setup_cpus: Find cpus in the hdesc and configure them
 *
 * in:
 *	%i0 - global config pointer
 *	%i1 - base of guests
 *	%i2 - base of cpus
 *	%g7 - return address
 *
 * volatile:
 *	%globals, %locals
 */
	ENTRY_NP(setup_cpus)
	mov	%g7, %l7	! save return address
	ldx	[CONFIG + CONFIG_HVD], %l4
	ldx	[CONFIG + CONFIG_CPUS_DTNODE], %l5
	mov	0, %l1
	!! %l4 hvd
	!! %l5 cpus dtnode
.another_cpu:
	TGETARCMULT(CONFIG, %l4, %l1, %l5, HDNAME_CPU, %g4, %g2)
	bne,pn	%xcc, .end_cpus
	mov	%g1, %l0	! current cpu node handle
	mov	%g2, %l1	! save offset
	!! %l0 current cpu node
	!! %l1 saved getprop offset

	/* get processor id */
	TGETVAL(CONFIG, %l4, %l0, HDNAME_PID, %g4, %g2)
	bne,a,pn %xcc, hvabort
	  mov	ABORT_MISSINGCPUPID, %g1
	cmp	%g1, NCPUS
	bgeu,a,pn %xcc, hvabort
	  mov	ABORT_INVALIDCPUPID, %g1
	set	CPU_SIZE, %g4
	mulx	%g1, %g4, %g2
	add	CPUS, %g2, %l2

	!! %l2 current cpu
	set	CPU_DTNODE, %g4
	stx	%l0, [%l2 + %g4]
	stb	%g1, [%l2 + CPU_PID]

	/*
	 * Mark this cpu active
	 */
	mov	1, %g3
	ldx	[%i0 + CONFIG_STACTIVE], %g4
	sllx	%g3, %g1, %g3
	bset	%g4, %g3
	stx	%g3, [%i0 + CONFIG_STACTIVE]

	/* get core pointer */
	srlx	%g1, CPUID_2_COREID_SHIFT, %g1		! g1 = Core ID
	set	CORE_SIZE, %g4
	mulx	%g1, %g4, %g1
	add	CORES, %g1, %g1				! g1 = &core[Core ID]
	stx	%g1, [%l2 + CPU_CORE]

	/* Get guest/vid for current cpu */
	TGETVAL(CONFIG, %l4, %l0, HDNAME_VID, %g4, %g2)
	bne,a,pn %xcc, hvabort
	  mov	ABORT_MISSINGCPUVID, %g1
	stb	%g1, [%l2 + CPU_VID]

	/* Configure the core's virtual core-id */
	ldx	[%l2 + CPU_CORE], %g4
	ldub	[%g4 + CORE_VID], %g2
	srlx	%g1, CPUID_2_COREID_SHIFT, %g1
	/*
	 * Check if CORE_VID has been already set,
	 * and if so then ensure it's the same as
	 * what we computed for this CPU_VID.
	 */
	cmp	%g2, NCORES				! initialized?
	be,a,pn	%xcc, 1f
	  stb	%g1, [%g4 + CORE_VID]
	cmp	%g2, %g1
	bne,a,pn %xcc, hvabort
	  mov	ABORT_INVALIDCPUVID, %g1
1:
	TGETARC(CONFIG, %l4, %l0, HDNAME_GUEST, %g4, %g2)
	bne,a,pn %xcc, hvabort
	  mov	ABORT_MISSINGCPUGUESTREF, %g1
	TGETVAL(CONFIG, %l4, %g1, HDNAME_GID, %g4, %g2)
	bne,a,pn %xcc, hvabort
	  mov	ABORT_MISSINGGUESTGID, %g1
	cmp	%g1, NGUESTS
	bgeu,a,pn %xcc, hvabort
	  mov	ABORT_INVALIDGUESTID, %g1

	set	GUEST_SIZE, %g4
	mulx	%g1, %g4, %g1
	add	GUESTS, %g1, %g1
	stx	%g1, [%l2 + CPU_GUEST]
	ldub	[%l2 + CPU_VID], %g2

	/* Add this cpu's core to the guest's vcores array */
	srlx	%g2, CPUID_2_COREID_SHIFT, %g4
	mulx	%g4, GUEST_VCORES_INCR, %g4
	add	%g4, GUEST_VCORES, %g4
	ldx	[%l2 + CPU_CORE], %g3
	stx	%g3, [%g1 + %g4]

	/* Add this cpu to the guest's vcpus array */
	mulx	%g2, GUEST_VCPUS_INCR, %g2
	add	%g2, GUEST_VCPUS, %g2
	stx	%l2, [%g1 + %g2]

	/*
	 * Finish initializing cpu struct
	 */
	stx	%g0, [%l2 + CPU_MMU_AREA]
	stx	%g0, [%l2 + CPU_MMU_AREA_RA]
	stx	CONFIG, [%l2 + CPU_ROOT]

	/* Initialize the error seq no for this cpu */
	set	ERR_SEQ_NO, %g2
	stx	%g0, [%l2 + %g2]

	/* Initialize the io_prot, io_error flag */
	set	CPU_IO_PROT, %g2
	stx	%g0, [%l2 + %g2]
	set	CPU_IO_ERROR, %g2
	stx	%g0, [%l2 + %g2]

	ba,pt	%xcc, .another_cpu
	nop
.end_cpus:
	jmp	%l7 + 4
	nop
	SET_SIZE(setup_cpus)


/*
 * setup_guests: Find guests in the hdesc and configure them
 *
 * in:
 *	%i0 - global config pointer
 *	%i1 - base of guests
 *	%i2 - base of cpus
 *	%g7 - return address
 *
 * volatile:
 *	%locals
 *	%outs
 *	%globals
 */
	ENTRY_NP(setup_guests)
	mov	%g7, %l7	! save return address
	!! %l7 saved return address
	ldx	[CONFIG + CONFIG_HVD], %l4
	ldx	[CONFIG + CONFIG_GUESTS_DTNODE], %l5
	!! %l5 guests dtnode
	mov	0, %l3
.another_guest:
	TGETARCMULT(CONFIG, %l4, %l3, %l5, HDNAME_GUEST, %g4, %g2)
	bne,pn	%xcc, .end_guests
	mov	%g1, %l2	! current guest node handle
	mov	%g2, %l3	! save offset
	!! %l2 guest dtnode
	!! %l4 current guest node handle
	!! %l3 saved offset

	/* get guest id */
	TGETVAL(CONFIG, %l4, %l2, HDNAME_GID, %g4, %g2)
	bne,a,pn %xcc, hvabort
	  mov	ABORT_MISSINGGUESTGID, %g1
	cmp	%g1, NGUESTS
	bgeu,a,pn %xcc, hvabort
	  mov	ABORT_INVALIDGUESTID, %g1
	set	GUEST_SIZE, %g2
	mulx	%g2, %g1, %g2
	add	GUESTS, %g2, %l6
	!! %l6 current guest structure
	/*
	 * Fill in a guest structure by looking up properties in the
	 * respective guest node.
	 */
	ba	1f
	nop
	.align 8
1:
	ba	1f
	rd	%pc, %o0
	.xword	HDNAME_CPUSET, GUEST_CPUSET
	.xword	HDNAME_BOOTCPU, GUEST_BOOTCPU
	.xword	HDNAME_PID, GUEST_PARTID
	.xword	HDNAME_XID, GUEST_XID
	.xword	HDNAME_MEMBASE, GUEST_MEM_BASE
	.xword	HDNAME_MEMSIZE, GUEST_MEM_SIZE
	.xword	HDNAME_REALBASE, GUEST_REAL_BASE
	.xword	HDNAME_ROMBASE, GUEST_ROM_BASE
	.xword	HDNAME_ROMSIZE, GUEST_ROM_SIZE
#ifndef CONFIG_CN_SVC
	.xword	HDNAME_UARTBASE, GUEST_CONSOLE + CONS_BASE
#endif
	.xword	HDNAME_NVBASE, GUEST_NVRAM_PA
	.xword	HDNAME_NVSIZE, GUEST_NVRAM_SIZE
	.xword	HDNAME_PDPA, GUEST_PD_PA
#ifdef CONFIG_DISK
	.xword	HDNAME_DISKPA, GUEST_DISK + DISK_PA
#endif
	.xword	HDNAME_REALBASE, GUEST_ENTRY
	.xword	-1, -1		! End of table
1:	inc	4, %o0
2:	ldx	[%o0 + 0], %o1
	ldx	[%o0 + 8], %o2
	cmp	%o1, -1
	be,pn	%xcc, 3f
	nop
	TGETVAL(CONFIG, %l4, %l2, %o1, %g4, %g2)
	bne,a,pn %xcc, hvabort
	  mov	ABORT_MISSINGGUESTPROP, %g1
	stx	%g1, [%l6 + %o2]
	ba	2b
	inc	16, %o0
3:
	!! %l6 current guest structure

	/* Finish initializing guest struct */
	ldx	[%l6 + GUEST_REAL_BASE], %g1
	ldx	[%l6 + GUEST_MEM_SIZE], %g2
	dec	%g2
	add	%g1, %g2, %g2
	stx	%g2, [%l6 + GUEST_REAL_LIMIT]
	ldx	[%l6 + GUEST_MEM_BASE], %g2
	sub	%g2, %g1, %g2
	stx	%g2, [%l6 + GUEST_MEM_OFFSET]
#ifdef CONFIG_DISK
	set	GUEST_DISK + DISK_SIZE, %g1
	stx	%g0, [%l6 + %g1]
#endif
	stx	CONFIG, [%l6 + GUEST_ROOT]

	/* Update global set of cpus to start */
	ldx	[%l6 + GUEST_CPUSET], %g1
	ldx	[CONFIG + CONFIG_CPUSTARTSET], %g2
	or	%g2, %g1, %g2
	stx	%g2, [CONFIG + CONFIG_CPUSTARTSET]

#ifdef CONFIG_DISK
	/*
	 * If disk property does not exist or is -1 then
	 * the virtual disk is not configured
	 */
	TGETVAL(CONFIG, %l4, %l2, HDNAME_DISKPA, %g4, %g2)
	movne	%xcc, -1, %g1
	set	GUEST_DISK + DISK_PA, %g2
	stx	%g1, [%l6 + %g2]
#endif

	/*
	 * Check for a reset-reason property
	 */
	TGETVAL(CONFIG, %l4, %l2, HDNAME_RESET_REASON, %g4, %g2)
	movne	%xcc, RESET_REASON_POR, %g1
	set	GUEST_RESET_REASON, %g2
	stx	%g1, [%l6 + %g2]

	/*
	 * Look for the "perfctraccess" property. This property
	 * must be present and set to a non-zero value for the
	 * guest to have access to the JBUS/DRAM perf counters
	 */
	TGETVAL(CONFIG, %l4, %l2, HDNAME_PERFCTRACCESS, %g4, %g2)
	movne	%xcc, %g0, %g1
	set	GUEST_PERFREG_ACCESSIBLE, %g2
	stx	%g1, [%l6 + %g2]

	/*
	 * Look for "diagpriv" property.  This property enables
	 * the guest to execute arbitrary hyperprivileged code.
	 */
	TGETVAL(CONFIG, %l4, %l2, HDNAME_DIAGPRIV, %g4, %g2)
#ifdef CONFIG_BRINGUP
	movne	%xcc, -1, %g1
#else
	movne	%xcc, %g0, %g1
#endif
	set	GUEST_DIAGPRIV, %g2
	stx	%g1, [%l6 + %g2]

	/*
	 * Per-guest TOD offset
	 */
	TGETVAL(CONFIG, %l4, %l2, HDNAME_TODOFFSET, %g4, %g2)
	movne	%xcc, %g0, %g1
	stx	%g1, [%l6 + GUEST_TOD_OFFSET]

	/*
	 * Count "device" refs in the guest "devices" node
	 */
	TGETARC(CONFIG, %l4, %l2, HDNAME_DEVICES, %g4, %g2)
	bne,pn	%xcc, .guest_devs_end
	mov	%g1, %o0
	set	GUEST_DEVS_DTNODE, %g2
	stx	%g1, [%l6 + %g2]
	!! %o0 devs node handle
	mov	0, %o2		! %o2 = count
	mov	0, %o1		! %o1 = offset
0:
	TGETARCMULT(CONFIG, %l4, %o1, %o0, HDNAME_DEVICE, %g4, %g2)
	bne,pn	%xcc, 1f
	mov	%g2, %o1	! save offset
	ba	0b
	inc	%o2		! bump devices count
1:
	brz,pn	%o2, .guest_devs_end
	nop
	!! %o2 device count for this guest

#if 1 /* XXX not done yet */
	set	GUEST_DEVS_DTNODE, %o0
	ldx	[%l6 + %o0], %o0
	!! %o0 devs node handle
	mov	0, %o1		! %o1 = offset
0:
	TGETARCMULT(CONFIG, %l4, %o1, %o0, HDNAME_DEVICE, %g4, %g2)
	bne,pn	%xcc, 1f
	mov	%g1, %o2	! save current dev node
	mov	%g2, %o1	! save offset

#if 1 /* XXX test */
	/*
	 * XXX is this virtualdevices?  If so we need to use
	 * the cfghandle/ign instead of hardwiring them.
	 * Same goes for vpci...
	 */
	.pushlocals
	!! %l4 current node
	LOOKUP_TAG_NODE(%i0, HDNAME_VDEVS, %g1, %g2)
	ldx	[%o2], %g2
	cmp	%g1, %g2
	bne	0f
	nop

	PRINT("XXX found virtualdevices\r\n")

0:
	.poplocals
#endif

	/* get cfghandle */
	TGETVAL(CONFIG, %l4, %o2, HDNAME_CFGHANDLE, %g4, %g2)
	bne,a,pn %xcc, hvabort
	  mov	ABORT_MISSINGDEVCFGH, %g1
#ifdef DEBUG
	mov	%g1, %l1
	PRINT("guest device:\r\n    cfg handle 0x")
	PRINTX(%l1)
	PRINT("\r\n")
#endif

	/* get ign */
	TGETVAL(CONFIG, %l4, %o2, HDNAME_IGN, %g4, %g2)
	bne,a,pn %xcc, hvabort
	  mov	ABORT_MISSINGDEVIGN, %g1
#ifdef DEBUG
	mov	%g1, %l1
	PRINT("    ign 0x")
	PRINTX(%l1)
	PRINT("\r\n")
#endif

	ba	0b
	nop
1:
#endif /* XXXOLD */

.guest_devs_end:

	/*
	 * %i0 - global config pointer
	 * %i1 - base of guests
	 * %i2 - base of cpus
	 * %g7 - return address
	 * %l6 - current guest structure
	 */
	setx	vino2inst, %o2, %o1
	ldx	[%i0 + CONFIG_RELOC], %o0
	sub	%o1, %o0, %o1
	set	GUEST_VINO2INST, %o2
	add	%l6, %o2, %o2
	set	VINO2INST_SIZE, %o4
2:	sub	%o4, 1, %o4
	ldub	[%o1+%o4], %o5
	brgez,a	%o4, 2b
	  stb	%o5, [%o2+%o4]

	setx	dev2inst, %o2, %o1
	ldx	[%i0 + CONFIG_RELOC], %o0
	sub	%o1, %o0, %o1
	add	%l6, GUEST_DEV2INST, %o2
	set	NDEVIDS, %o4
2:	dec	%o4
	ldub	[%o1 + %o4], %o5
	brgez,a	%o4, 2b
	  stb	%o5, [%o2 + %o4]

	ba,pt	%xcc, .another_guest;
	nop
.end_guests:
	jmp	%l7 + 4
	nop
	SET_SIZE(setup_guests)

#if defined(CONFIG_FIRE)
/*
 * setup_fire: Initialize Fire
 *
 * in:
 *	%i0 - global config pointer
 *	%i1 - base of guests
 *	%i2 - base of cpus
 *	%g7 - return address
 *
 * volatile:
 *	%locals
 *	%outs
 *	%globals
 */
	ENTRY_NP(setup_fire)

	mov	%g7, %l7	/* save return address */
	PRINT("HV:setup_fire\r\n")
	/*
	 * Relocate Fire TSB base pointers
	 */
	ldx	[%i0 + CONFIG_RELOC], %o0
	setx	fire_dev, %o2, %o1
	sub	%o1, %o0, %o1
	ldx	[%o1 + FIRE_COOKIE_IOTSB], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_IOTSB]
	add	%o1, FIRE_COOKIE_SIZE, %o1
	ldx	[%o1 + FIRE_COOKIE_IOTSB], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_IOTSB]

	sub	%o1, FIRE_COOKIE_SIZE, %o1

	/*
	 * Relocate Fire MSI EQ base pointers
	 */
	ldx	[%o1 + FIRE_COOKIE_MSIEQBASE], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_MSIEQBASE]
	add	%o1, FIRE_COOKIE_SIZE, %o1
	ldx	[%o1 + FIRE_COOKIE_MSIEQBASE], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_MSIEQBASE]

	sub	%o1, FIRE_COOKIE_SIZE, %o1

	/*
	 * Relocate Fire Virtual Interrupt pointer
	 */
	ldx	[%o1 + FIRE_COOKIE_VIRTUAL_INTMAP], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_VIRTUAL_INTMAP]
	add	%o1, FIRE_COOKIE_SIZE, %o1
	ldx	[%o1 + FIRE_COOKIE_VIRTUAL_INTMAP], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_VIRTUAL_INTMAP]

	sub	%o1, FIRE_COOKIE_SIZE, %o1

	/*
	 * Relocate Fire MSI and ERR Cookies
	 */

	ldx	[%o1 + FIRE_COOKIE_ERRCOOKIE], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_ERRCOOKIE]
	ldx	[%o2 + FIRE_ERR_COOKIE_FIRE], %o4
	sub	%o4, %o0, %o4
	stx	%o4, [%o2 + FIRE_ERR_COOKIE_FIRE]
	add	%o1, FIRE_COOKIE_SIZE, %o1
	ldx	[%o1 + FIRE_COOKIE_ERRCOOKIE], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_ERRCOOKIE]
	ldx	[%o2 + FIRE_ERR_COOKIE_FIRE], %o4
	sub	%o4, %o0, %o4
	stx	%o4, [%o2 + FIRE_ERR_COOKIE_FIRE]

	sub	%o1, FIRE_COOKIE_SIZE, %o1

	ldx	[%o1 + FIRE_COOKIE_MSICOOKIE], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_MSICOOKIE]
	ldx	[%o2 + FIRE_MSI_COOKIE_FIRE], %o4
	sub	%o4, %o0, %o4
	stx	%o4, [%o2 + FIRE_MSI_COOKIE_FIRE]
	add	%o1, FIRE_COOKIE_SIZE, %o1
	ldx	[%o1 + FIRE_COOKIE_MSICOOKIE], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_MSICOOKIE]
	ldx	[%o2 + FIRE_MSI_COOKIE_FIRE], %o4
	sub	%o4, %o0, %o4
	stx	%o4, [%o2 + FIRE_MSI_COOKIE_FIRE]

	setx	fire_msi, %o2, %o1
	sub	%o1, %o0, %o1

	mov	FIRE_NEQS, %o3
	add	%o1, FIRE_MSI_COOKIE_EQ, %o2
0:
	ldx	[%o2 + FIRE_MSIEQ_BASE], %o4
	sub	%o4, %o0, %o4
	stx	%o4, [%o2 + FIRE_MSIEQ_BASE]
	add	%o2, FIRE_MSIEQ_SIZE, %o2
	subcc	%o3, 1, %o3
	bnz	0b
	nop

	add	%o1, FIRE_MSI_COOKIE_SIZE, %o1

	mov	FIRE_NEQS, %o3
	add	%o1, FIRE_MSI_COOKIE_EQ, %o2
0:
	ldx	[%o2 + FIRE_MSIEQ_BASE], %o4
	sub	%o4, %o0, %o4
	stx	%o4, [%o2 + FIRE_MSIEQ_BASE]
	add	%o2, FIRE_MSIEQ_SIZE, %o2
	subcc	%o3, 1, %o3
	bnz	0b
	nop

	ba	fire_init
	mov	%l7, %g7
	SET_SIZE(setup_fire)
#endif


#define RELOC_DEVOPS(n, reloc, scr1, scr2, scr3) \
	.pushlocals			;\
	setx	n/**/_ops, scr1, scr2	;\
	set	DEVOPSVEC_SIZE, scr1	;\
	sub	scr2, reloc, scr2	;\
2:	sub	scr1, 8, scr1		;\
	ldx	[scr2 + scr1], scr3	;\
	brnz,a	scr3, 1f		;\
	  sub	scr3, reloc, scr3	;\
1:	brgz	scr1, 2b		;\
	  stx	scr3, [scr2 + scr1]	;\
	.poplocals

/*
 * setup_devops - relocate devops arrays
 *
 * in:
 *	%i0 - global config pointer
 *	%g7 - return address
 *
 * volatile:
 *	%outs
 *	%globals
 */
	ENTRY_NP(setup_devops)
	ldx	[%i0 + CONFIG_RELOC], %o0
	RELOC_DEVOPS(vdev, %o0, %g1, %g2, %g3)
#ifdef CONFIG_FIRE
	RELOC_DEVOPS(fire_dev, %o0, %g1, %g2, %g3)
	RELOC_DEVOPS(fire_int, %o0, %g1, %g2, %g3)
	RELOC_DEVOPS(fire_msi, %o0, %g1, %g2, %g3)
	RELOC_DEVOPS(fire_err_int, %o0, %g1, %g2, %g3)
#endif
	jmp	%g7 + 4
	nop
	SET_SIZE(setup_devops)



/*
 * setup_svcs: initialize services
 *
 * in:
 *	%i0 - global config pointer
 *	%i1 - base of guests
 *	%i2 - base of cpus
 *	%g7 - return address
 *
 * volatile:
 *	%globals, %locals
 */
	ENTRY_NP(setup_services)
	mov	%g7, %l7	! save return address

#ifdef CONFIG_SVC

	/*
	 * Count root services
	 */
	ldx	[CONFIG + CONFIG_HVD], %l4
	mov	0, %l3		! %l3 = current offset within node
	mov	0, %l0		! %l0 = count
	ldx	[CONFIG + CONFIG_SVCS_DTNODE], %l5
	brz,pn	%l5, .end_svcs
	nop
	!! %l5 root services node
0:
	TGETARCMULT(CONFIG, %l4, %l3, %l5, HDNAME_SERVICE, %g4, %g2)
	bne,pn	%xcc, 1f
	mov	%g2, %l3	! save offset
	ba	0b
	inc	%l0
1:
	brz,pn	%l0, .end_svcs
	nop

	/*
	 * Allocate:
	 * (sizeof (hv_svc_data) + ((n-1) * sizeof (svc_ctrl)))
	 */
	set	HV_SVC_DATA_SIZE, %l1
	sub	%l0, 1, %l2
	set	SVC_CTRL_SIZE, %l3
	mulx	%l2, %l3, %l2
	add	%l2, %l1, %l1
	!! %l0 - num_svcs
	!! %l1 - allocation size
	HVALLOC(CONFIG, %l1, %l2, %g1) ! root,sz,ptr,tmp
	mov	%l2, %l1
	!! %l1 - config->svc
	stx	%l1, [CONFIG + CONFIG_SVCS]
	stw	%l0, [%l1 + HV_SVC_DATA_NUM_SVCS]

#ifdef DEBUG
	PRINT("services: 0x")
	PRINTX(%l1)
	PRINT(" #services: 0x")
	PRINTX(%l0)
	PRINT("\r\n")
#endif

#ifdef CONFIG_FPGA /* Don't touch fpga hardware if it isn't there, testing */
	setx	FPGA_QIN_BASE, %g1, %l2
	lduh	[%l2 + FPGA_Q_BASE], %l3
	setx	(FPGA_BASE + FPGA_SRAM_BASE), %g1, %l2
	add	%l3, %l2, %g1
	stx	%g1, [%l1 + HV_SVC_DATA_RXBASE]

	setx	FPGA_QOUT_BASE, %g1, %l2
	lduh	[%l2 + FPGA_Q_BASE], %l3
	setx	(FPGA_BASE + FPGA_SRAM_BASE), %g1, %l2
	add	%l3, %l2, %g1
	stx	%g1, [%l1 + HV_SVC_DATA_TXBASE]

	/*
	 * The FPGA interrupt output is an active-low level interrupt.
	 * The Niagara SSI interrupt input is falling-edge-triggered.
	 * We can lose an interrupt across a warm reset so workaround
	 * that by injecting a fake SSI interrupt at start-up time.
	 */
	setx	IOBBASE, %g1, %g2
	ldx	[%g2 + INT_MAN + INT_MAN_DEV_OFF(IOBDEV_SSI)], %g1
	stx	%g1, [%g2 + INT_VEC_DIS]
#else
	mov	-1, %g1
	stx	%g1, [%l1 + HV_SVC_DATA_RXBASE]
	stx	%g1, [%l1 + HV_SVC_DATA_TXBASE]
#endif /* CONFIG_FPGA */

	setx	FPGA_QIN_BASE, %g1, %l2
	stx	%l2, [%l1 + HV_SVC_DATA_RXCHANNEL]

	setx	FPGA_QOUT_BASE, %g1, %l2
	stx	%l2, [%l1 + HV_SVC_DATA_TXCHANNEL]

	/*
	 * foreach service:
	 *   populate-svc
	 * svcs[nsvcs].recv.next = NULL
	 */
	add	%l1, HV_SVC_DATA_SVC, %l2 ! %l2 - current svc_ctrl
	ldx	[CONFIG + CONFIG_SVCS_DTNODE], %o0
	!! %l2 current svc_ctrl
	!! %o0 services node
	mov	0, %o1		! %o1 = current offset within node
0:
	TGETARCMULT(CONFIG, %l4, %o1, %o0, HDNAME_SERVICE, %g4, %g2)
	bne,pn	%xcc, .last_svc
	mov	%g1, %o2	! current guest node handle
	mov	%g2, %o1	! save offset
	!! %o1 current offset within services node
	!! %o2 current service node
	!! %l2 = current svc_ctrl

	/* get sid */
	TGETVAL(CONFIG, %l4, %o2, HDNAME_SID, %g4, %g2)
	bne,a,pn %xcc, hvabort
	  mov	ABORT_MISSINGSVCSID, %g1
	stw	%g1, [%l2 + SVC_CTRL_SID]

	/* get xid */
	TGETVAL(CONFIG, %l4, %o2, HDNAME_XID, %g4, %g2)
	bne,a,pn %xcc, hvabort
	  mov	ABORT_MISSINGSVCXID, %g1
	stw	%g1, [%l2 + SVC_CTRL_XID]

	/* get flags */
	TGETVAL(CONFIG, %l4, %o2, HDNAME_FLAGS, %g4, %g2)
	bne,a,pn %xcc, hvabort
	  mov	ABORT_MISSINGSVCFLAGS, %g1
	stw	%g1, [%l2 + SVC_CTRL_CONFIG]

	/* get ino */
	lduw	[%l2 + SVC_CTRL_CONFIG], %g1
	btst	(SVC_CFG_RE | SVC_CFG_TE), %g1
	bz,pn	%xcc, 1f
	nop
	TGETVAL(CONFIG, %l4, %o2, HDNAME_INO, %g4, %g2)
	bne,a,pn %xcc, hvabort
	  mov	ABORT_MISSINGSVCINO, %g1
	stw	%g1, [%l2 + SVC_CTRL_INO]
1:

	/* get mtu */
	TGETVAL(CONFIG, %l4, %o2, HDNAME_MTU, %g4, %g2)
	bne,a,pn %xcc, hvabort
	  mov	ABORT_MISSINGSVCMTU, %g1
	stw	%g1, [%l2 + SVC_CTRL_MTU]

#ifdef DEBUG
	PRINT("SVC: 0x")
	PRINTX(%l2)
	PRINT(" XID: 0x")
	lduw	[%l2 + SVC_CTRL_XID], %g1
	PRINTX(%g1)
	PRINT(" SID: 0x")
	lduw	[%l2 + SVC_CTRL_SID], %g1
	PRINTX(%g1)
	PRINT(" Flags: 0x")
	lduw	[%l2 + SVC_CTRL_CONFIG], %g1
	PRINTX(%g1)
	PRINT(" Ino: 0x")
	lduw	[%l2 + SVC_CTRL_INO], %g1
	PRINTX(%g1)
	PRINT(" MTU: 0x")
	lduw	[%l2 + SVC_CTRL_MTU], %g1
	PRINTX(%g1)
	PRINT("\r\n")
#endif

	/* get link */
	TGETARC(CONFIG, %l4, %o2, HDNAME_LINK, %g4, %g2)
	bne,pn	%xcc, 1f
	mov	%g1, %o3
	!! %o3 linked service node
	TGETVAL(CONFIG, %l4, %o3, HDNAME_XID, %g4, %g2)
	bne,pn	%xcc, 1f
	mov	%g1, %o4
	!! %o4 = linked xid
	TGETVAL(CONFIG, %l4, %o3, HDNAME_SID, %g4, %g2)
	bne,pn	%xcc, 1f
	mov	%g1, %o5
	!! %o5 = linked sid

	! XXX don't set SVC_CFG_LINK until both halves linked? for robustness
	lduw	[%l2 + SVC_CTRL_CONFIG], %g1
	or	%g1, SVC_CFG_LINK, %g1
	stw	%g1, [%l2 + SVC_CTRL_CONFIG]

#ifdef DEBUG
	PRINT("Link: 0x")
	PRINTX(%l2)
	PRINT("\r\n")
#endif

	/*
	 * Walk all of the services looking for the other end of the link
	 */
	lduw	[%l1 + HV_SVC_DATA_NUM_SVCS], %g4
	!! %g4 number of services, loop counter
	add	%l1, HV_SVC_DATA_SVC, %g2
	!! %g2 base of array
.next_svc_link:
	!! %g2 current target svc
	cmp	%g2, %l2	! skip over ourself
	be,pn	%xcc, .next_svc_link_cont ! no match, continue
	lduw	[%g2 + SVC_CTRL_XID], %g1
	cmp	%g1, %o4
	bne,pt	%xcc, .next_svc_link_cont ! no match, continue
	lduw	[%g2 + SVC_CTRL_SID], %g1
	cmp	%g1, %o5
	bne,pt	%xcc, .next_svc_link_cont ! no match, continue
	nop

	/* found a match, set it up */
	stx	%l2, [%g2 + SVC_CTRL_LINK]
	stx	%g2, [%l2 + SVC_CTRL_LINK]
	lduw	[%g2 + SVC_CTRL_CONFIG], %g1
	btst	SVC_CFG_LINK, %g1
	bz,pn	%xcc, 1f	! break out of loop
	nop
	! svc->send.pa = linked->recv.pa
	ldx	[%g2 + SVC_CTRL_RECV + SVC_LINK_PA], %g1
	stx	%g1, [%l2 + SVC_CTRL_SEND + SVC_LINK_PA]
	! svc->recv.pa = linked->send.pa
	ldx	[%g2 + SVC_CTRL_SEND + SVC_LINK_PA], %g1
	stx	%g1, [%l2 + SVC_CTRL_RECV + SVC_LINK_PA]

#ifdef DEBUG
	PRINT("Other end: 0x")
	ldx	[%l2 + SVC_CTRL_LINK], %g1
	PRINTX(%g1)
	PRINT("  sendpa 0x")
	ldx	[%l2 + SVC_CTRL_RECV + SVC_LINK_PA], %g1
	PRINTX(%g1)
	PRINT("  recvpa 0x")
	ldx	[%l2 + SVC_CTRL_SEND + SVC_LINK_PA], %g1
	PRINTX(%g1)
	PRINT("\r\n")
#endif
	ba,a	1f		! break out of loop

.next_svc_link_cont:
	deccc	%g4
	bz,pn	%xcc, 1f
	add	%g2, SVC_CTRL_SIZE, %g2 ! next service
	ba	.next_svc_link
	nop
1:

	/* allocate rx buffer */
	lduw	[%l2 + SVC_CTRL_CONFIG], %g1
	btst	SVC_CFG_RX, %g1
	bz,pn	%xcc, 1f
	nop
	! svc->recv.size = 0
	stx	%g0, [%l2 + SVC_CTRL_RECV + SVC_LINK_SIZE]
	! svc->recv.next = svcs[n + 1]
	add	%l2, SVC_CTRL_SIZE, %g1
	stx	%g1, [%l2 + SVC_CTRL_RECV + SVC_LINK_NEXT]
	! if no buffer, svc->recv.pa = hvalloc(mtu)
	ldx	[%l2 + SVC_CTRL_RECV + SVC_LINK_PA], %g1
	brnz,pn	%g1, 1f
	nop
	lduw	[%l2 + SVC_CTRL_MTU], %g2
	HVALLOC(CONFIG, %g2, %g1, %g3) ! root,sz,ptr,tmp
	stx	%g1, [%l2 + SVC_CTRL_RECV + SVC_LINK_PA]
#ifdef DEBUG
	PRINT("recvpa: 0x")
	ldx	[%l2 + SVC_CTRL_RECV + SVC_LINK_PA], %g1
	PRINTX(%g1)
	PRINT("\r\n")
#endif
1:

	/* allocate tx buffer */
	lduw	[%l2 + SVC_CTRL_CONFIG], %g1
	btst	SVC_CFG_TX, %g1
	bz,pn	%xcc, 1f
	nop
	! svc->send.size = 0
	stx	%g0, [%l2 + SVC_CTRL_SEND + SVC_LINK_SIZE]
	! svc->send.next = 0
	stx	%g0, [%l2 + SVC_CTRL_SEND + SVC_LINK_NEXT]
	! if no buffer, svc->send.pa = hvalloc(mtu)
	ldx	[%l2 + SVC_CTRL_SEND + SVC_LINK_PA], %g1
	brnz,pn	%g1, 1f
	nop
	lduw	[%l2 + SVC_CTRL_MTU], %g2
	HVALLOC(CONFIG, %g2, %g1, %g3) ! root,sz,ptr,tmp
	stx	%g1, [%l2 + SVC_CTRL_SEND + SVC_LINK_PA]
#ifdef DEBUG
	PRINT("sendpa: 0x")
	ldx	[%l2 + SVC_CTRL_SEND + SVC_LINK_PA], %g1
	PRINTX(%g1)
	PRINT("\r\n")
#endif
1:

	/* Point to next svc_ctrl and find the next service */
	add	%l2, SVC_CTRL_SIZE, %l2
	ba	0b
	nop

.last_svc:
	!! %l2 points to svcs[n+1]
	add	%l2, SVC_CTRL_SIZE, %l2
	stx	%g0, [%l2 + SVC_CTRL_RECV + SVC_LINK_NEXT]

	ba	svc_init
	mov	%l7, %g7	! NOTE:	 Tail call!
	/*NOTREACHED*/

.end_svcs:
#endif /* CONFIG_SVC */

	jmp	%l7 + 4
	nop
	SET_SIZE(setup_services)



/*
 * setup_dummytsb
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
#define	DUMMYTSB_SIZE	0x2000
#define	DUMMYTSB_ALIGN	0x2000

	ENTRY_NP(setup_dummytsb)
	ldx	[%i0 + CONFIG_RELOC], %l3
	setx	dummytsb, %l2, %l1
	sub	%l1, %l3, %l1
	stx	%l1, [%i0 + CONFIG_DUMMYTSB]

	set	DUMMYTSB_SIZE, %l2
	mov	-1, %l3
	ba,a	2f
	.empty
1:
	stx	%l3, [%l1 + %l2]	! store invalid tag
2:
	brnz,pt	%l2, 1b
	dec	16, %l2

	jmp	%g7 + 4
	nop
	SET_SIZE(setup_dummytsb)

/*
 * dummy tsb for the hypervisor to use
 */
BSS_GLOBAL(dummytsb, DUMMYTSB_SIZE, DUMMYTSB_ALIGN)


/*
 * setup_iob
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
	ENTRY_NP(setup_iob)
#ifdef CONFIG_FPGA
	ldx	[CONFIG + CONFIG_INTRTGT], %g1
	setx	IOBBASE, %g3, %g2
	!! %g1 = intrtgt CPUID array (8-bits per INT_MAN target)
	!! %g2 = IOB Base address

	/*
	 * Clear interrupts for both SSIERR and SSI
	 *
	 * PRM: "After setting the MASK bit, software needs to issue a
	 * read on the INT_CTL register to guarantee the masking write
	 * is completed."
	 */
	mov	INT_CTL_MASK, %g4
	stx	%g4, [%g2 + INT_CTL + INT_CTL_DEV_OFF(IOBDEV_SSIERR)]
	ldx	[%g2 + INT_CTL + INT_CTL_DEV_OFF(IOBDEV_SSIERR)], %g0
	stx	%g4, [%g2 + INT_CTL + INT_CTL_DEV_OFF(IOBDEV_SSI)]
	ldx	[%g2 + INT_CTL + INT_CTL_DEV_OFF(IOBDEV_SSI)], %g0

	/*
	 * setup the map registers for the SSI
	 */

	/* SSI Error interrupt */
	srl	%g1, INTRTGT_DEVSHIFT, %g1 ! get dev1 bits in bottom
	and	%g1, INTRTGT_CPUMASK, %g3
	sllx	%g3, INT_MAN_CPU_SHIFT, %g3 ! int_man.cpu
	or	%g3, VECINTR_SSIERR, %g3 ! int_man.vecnum
	stx	%g3, [%g2 + INT_MAN + INT_MAN_DEV_OFF(IOBDEV_SSIERR)]

	/* SSI Interrupt */
	srl	%g1, INTRTGT_DEVSHIFT, %g1 ! get dev2 bits in bottom
	and	%g1, INTRTGT_CPUMASK, %g3
	sllx	%g3, INT_MAN_CPU_SHIFT, %g3 ! int_man.cpu
	or	%g3, VECINTR_FPGA, %g3 ! int_man.vecnum
	stx	%g3, [%g2 + INT_MAN + INT_MAN_DEV_OFF(IOBDEV_SSI)]

	/*
	 * Enable All JBUS errors which generate an SSI interrupt
	 */
	ENABLE_JBI_INTR_ERRS(%g1, %g3, %g4)

	/*
	 * Enable interrupts for both SSIERR and SSI by clearing
	 * the MASK bit
	 */

	stx	%g0, [%g2 + INT_CTL + INT_CTL_DEV_OFF(IOBDEV_SSIERR)]
	stx	%g0, [%g2 + INT_CTL + INT_CTL_DEV_OFF(IOBDEV_SSI)]
#endif /* CONFIG_FPGA */

	/*
	 * Set J_INT_VEC to target all JBus interrupts to vec# VECINTR_DEV
	 */
	setx	IOBBASE + J_INT_VEC, %l2, %l1
	mov	VECINTR_DEV, %l2
	stx	%l2, [%l1]

	jmp	%g7 + 4
	nop
	SET_SIZE(setup_iob)

#ifdef CONFIG_SVC /* { */

#ifdef CONFIG_VBSC_SVC
/*
 * setup_svc_debug
 */
	ENTRY_NP(setup_vbsc_svc)
	/* Put errorsvc handle into the debug structure */
	ldx	[%i0 + CONFIG_ERROR_SVCH], %g1 ! get the error service handle
	stx	%g1, [%i0 + CONFIG_VBSC_DBGERROR + DBGERROR_ERROR_SVCH]

	ba,pt	%xcc, svc_vbsc_init	! returns to caller via %g7
	nop
	SET_SIZE(setup_vbsc_svc)
#endif /* CONFIG_VBSC_SVC */


/*
 * setup_err_svc
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
	ENTRY_NP(setup_err_svc)
	mov	%g7, %l7
	mov	0, %g1		! No cookie
	SVC_REGISTER(errort, XPID_HV, SID_ERROR, error_svc_rx, error_svc_tx)
	brnz,pn	%g1, 1f
	nop
	PRINT_NOTRAP("WARNING: setup_err_svc register failed\r\n")
	mov	%g0, %g1 ! write %g1 = zero for error service cookie
1:	! save the error service handle (cookie), 0 if register failed
	stx	%g1, [%i0 + CONFIG_ERROR_SVCH] ! save error service handle
2:	jmp	%l7 + 4
	nop
	SET_SIZE(setup_err_svc)

/*
 * SVC_REGISTER requires that we have these 2 null functions
 * declared here.
 */
/*
 * error_svc_rx
 *
 * %g1 callback cookie
 * %g2 svc pointer
 * %g7 return address
 */
        ENTRY(error_svc_rx)
	/*
	 * Done with this packet
	 */
	ld	[%g2 + SVC_CTRL_STATE], %g5
	andn	%g5, SVC_FLAGS_RI, %g5
	st	%g5, [%g2 + SVC_CTRL_STATE]	! clear RECV pending

        mov     %g7, %g6
	PRINT("error_svc_rx\r\n")
        mov	%g6, %g7

        jmp     %g7 + 4
        nop
        SET_SIZE(error_svc_rx)

/*
 * cn_svc_tx - error report transmission completion interrupt
 *
 * While sram was busy an other error may have occurred. In such case, we
 * increase the send pkt counter and mark such packet for delivery.
 * In this function, we check to see if there are any packets to be transmitted.
 *
 * We search in the following way:
 * Look at fire A jbi err buffer
 * Look at fire A pcie err buffer
 * Look at fire B jbi err buffer
 * Look at fire B pcie err buffer
 * For each cpu in NCPUS
 *   Look at CE err buffer
 *   Look at UE err buffer
 *
 * We only send a packet at a time, and in the previously described order.
 * Since we are running in the intr completion routing, the svc_internal_send
 * has already adquire the locks. For such reason, this routing needs to use
 * send_diag_buf_noblock.
 *
 * %g1 callback cookie
 * %g2 packet
 * %g7 return address
 */
        ENTRY(error_svc_tx)
	CPU_PUSH(%g7, %g1, %g2, %g3)
	PRINT("error_svc_tx\r\n")

	CPU_STRUCT(%g1)
	ldx	[%g1 + CPU_ROOT], %g1
	stx	%g0, [%g1 + CONFIG_SRAM_ERPT_BUF_INUSE] ! clear the inuse flag

	/*
	 * See if we need to send more packets
	 */
	ldx	[%g1 + CONFIG_ERRS_TO_SEND], %g2
	brz	%g2, 4f
	nop

	PRINT("NEED TO SEND ANOTHER PACKET\r\n")
#ifdef CONFIG_FIRE
	/*
	 * search vpci to see if we need to send errors
	 */

	/* Look at fire_a jbi */
	GUEST_STRUCT(%g1)
	mov	FIRE_A_AID, %g2
	DEVINST2INDEX(%g1, %g2, %g2, %g3, 4f)
	DEVINST2COOKIE(%g1, %g2, %g2, %g3, 4f)
	mov	%g2, %g1
	add	%g1, FIRE_COOKIE_JBC_ERPT, %g5
	add	%g5, PCI_UNSENT_PKT, %g2
	ldx	[%g2], %g4
	mov	PCIERPT_SIZE - EPKTSIZE, %g3
	brnz	%g4, 2f
	nop

	/* Look at fire_a pcie */
	add	%g1, FIRE_COOKIE_PCIE_ERPT, %g1
	add	%g1, PCI_UNSENT_PKT, %g2
	ldx	[%g2], %g4
	mov	PCIERPT_SIZE - EPKTSIZE, %g3
	brnz	%g4, 2f
	add	%g1, PCI_ERPT_U, %g1

	/* Look at fire_b jbc */
	GUEST_STRUCT(%g1)
	mov	FIRE_B_AID, %g2
	DEVINST2INDEX(%g1, %g2, %g2, %g3, 4f)
	DEVINST2COOKIE(%g1, %g2, %g2, %g3, 4f)
	mov	%g2, %g1
	add	%g1, FIRE_COOKIE_JBC_ERPT, %g5
	ldx	[%g5 + PCI_UNSENT_PKT], %g4
	mov	PCIERPT_SIZE - EPKTSIZE, %g3
	cmp	%g4, %g0
	bnz	%xcc, 2f
	nop

	/* Look at fire_b pcie */
	add	%g1, FIRE_COOKIE_PCIE_ERPT, %g1
	ldx	[%g1 + PCI_UNSENT_PKT], %g4
	mov	PCIERPT_SIZE - EPKTSIZE, %g3
	cmp	%g4, %g0
	bnz	%xcc, 2f
	add	%g1, PCI_ERPT_U, %g1
#endif /* CONFIG_FIRE */

	/* Now look at the cpu erpts */

	CPU_STRUCT(%g6)
	ldx	[%g6 + CPU_ROOT], %g6
	ldx	[%g6 + CONFIG_CPUS], %g6
	set	CPU_SIZE * NCPUS, %g5
	add	%g6, %g5, %g5	! last cpu ptr

1:
	! %g6 cur cpu ptr
	! If CPU is invalid, skip it
	ldx	[%g6 + CPU_STATUS], %g2
	cmp	CPU_STATE_INVALID, %g2
	be	%xcc, 3f
	nop

	! Check in the CE err buf for marked pkt
	add	%g6, CPU_CE_RPT + CPU_UNSENT_PKT, %g2
	mov	EVBSC_SIZE, %g3
	ldx	[%g2], %g4
	cmp	%g0, %g4
	bnz	%xcc, 2f
	add	%g6, CPU_CE_RPT + CPU_VBSC_ERPT, %g1

	! Check in the UE err buf for marked pkt
	set	CPU_UE_RPT + CPU_UNSENT_PKT, %g2
	add	%g6, %g2, %g2
	ldx	[%g2], %g4
	set	CPU_UE_RPT + CPU_VBSC_ERPT, %g3
	add	%g6, %g3, %g1
	cmp	%g0, %g4
	bnz	%xcc, 2f
	mov	EVBSC_SIZE, %g3

3:
	set	CPU_SIZE, %g4
	add	%g4, %g6, %g6
	cmp	%g6, %g5		! new ptr == last ptr?
	bl	%xcc, 1b
	nop

	ba	4f
	nop

2:
	PRINT("FOUND THE PACKAGE TO SEND\r\n")
	! We found it.  We have all the args in place, so just sent the pkt
	HVCALL(send_diag_erpt_nolock)

	! Mark as one less pkt to send
	CPU_STRUCT(%g6)
	ldx	[%g6 + CPU_ROOT], %g6		/* config data */
	add	%g6, CONFIG_ERRS_TO_SEND, %g6
	ldx	[%g6], %g1
0:	sub	%g1, 1, %g3
	casx	[%g6], %g1, %g3
	cmp	%g1, %g3
	bne,a,pn %xcc, 0b
	mov	%g3, %g1

4:
	! Pop return pc. Done
	CPU_POP(%g7, %g1, %g2, %g3)
	HVRET
        SET_SIZE(error_svc_tx)

#endif /* } CONFIG_SVC */
