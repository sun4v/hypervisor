/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _NIAGARA_CONFIG_H
#define	_NIAGARA_CONFIG_H

#pragma ident	"@(#)config.h	1.24	05/09/13 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include "svc_vbsc.h"		/* dbgerror */


#define	NCORES			8		/* #cores/chip */
#define	NCPUS_PER_CORE		4		/* Must be power of 2 */
#define	NCPUS_PER_CORE_MASK	(NCPUS_PER_CORE - 1)
#define	NGUESTS		2		/* To save space */
#define	NCPUS			(NCORES * NCPUS_PER_CORE)
#define	LOG2_NCPUS		5		/* log2(NCPUS) */
#define	CPUID_2_COREID_SHIFT	2		/* log2(NCPUS_PER_CORE) */
#define	CORE_MASK		0xf

#define	DUMPBUF_MINSIZE	8192	/* smallest dump buffer allowed */


/*
 * cpu_pokedelay - the number of ticks between pokes to a target
 * cpu that has had a mondo outstanding.  The target's cpu queue
 * may have been full and it needs a poke to check it again.
 */
#define	CPU_POKEDELAY		2000	/* clock ticks */


/*
 * memscrub_max default - used as the default if the memscrub_max
 * was not specified in the hypervisor description or if the
 * setting does not correspond to an 8k-aligned byte count.
 */
#define	MEMSCRUB_MAX_DEFAULT	((4 MB) >> L2_LINE_SHIFT)

/*
 * Maximum number of MA (crypto - modular arithmetic) units per
 * Niagara chip, 1 per core.
 */
#define	NMAUS		NCORES

/*
 * Hypervisor console (16550)
 */
#define	HV_UART		0xfff0c2c000
#ifdef CONFIG_FPGA
#define	UART_CLOCK_MULTIPLIER	8 /* For Niagara FPGA */
#endif

#ifndef _ASM

struct nametable {
	uint64_t	hdname_root;
	uint64_t	hdname_cpus;
	uint64_t	hdname_cpu;
	uint64_t	hdname_devices;
	uint64_t	hdname_device;
	uint64_t	hdname_services;
	uint64_t	hdname_service;
	uint64_t	hdname_guests;
	uint64_t	hdname_guest;

	uint64_t	hdname_bootcpu;
	uint64_t	hdname_cpuset;
	uint64_t	hdname_romsize;
	uint64_t	hdname_rombase;
	uint64_t	hdname_memory;
	uint64_t	hdname_nvbase;
	uint64_t	hdname_nvsize;
	uint64_t	hdname_pdpa;
	uint64_t	hdname_size;
	uint64_t	hdname_uartbase;
	uint64_t	hdname_base;
	uint64_t	hdname_link;
	uint64_t	hdname_intrtgt;
	uint64_t	hdname_inobitmap;
	uint64_t	hdname_tod;
	uint64_t	hdname_todfrequency;
	uint64_t	hdname_todoffset;
	uint64_t	hdname_vid;
	uint64_t	hdname_xid;
	uint64_t	hdname_pid;
	uint64_t	hdname_sid;
	uint64_t	hdname_gid;
	uint64_t	hdname_ign;
	uint64_t	hdname_ino;
	uint64_t	hdname_mtu;
	uint64_t	hdname_memoffset;
	uint64_t	hdname_memsize;
	uint64_t	hdname_membase;
	uint64_t	hdname_realbase;
	uint64_t	hdname_hypervisor;
	uint64_t	hdname_perfctraccess;
	uint64_t	hdname_vpcidevice;
	uint64_t	hdname_pciregs;
	uint64_t	hdname_cfghandle;
	uint64_t	hdname_cfgbase;
	uint64_t	hdname_diskpa;
	uint64_t	hdname_diagpriv;
	uint64_t	hdname_iobase;
	uint64_t	hdname_hvuart;
	uint64_t	hdname_flags;
	uint64_t	hdname_stickfrequency;
	uint64_t	hdname_ceblackoutsec;
	uint64_t	hdname_cepollsec;
	uint64_t	hdname_memscrubmax;
	uint64_t	hdname_erpt_pa;
	uint64_t	hdname_erpt_size;
	uint64_t	hdname_vdevs;
	uint64_t	hdname_reset_reason;
};

struct erpt_svc_pkt {
	uint64_t	addr;
	uint64_t	size;
};

/*
 * Global configuration
 */
struct config {
	uint64_t	reloc;	/* hv relocation offset */
	uint64_t	heap;	/* start of heap (after bss) */
	uint64_t	brk;	/* current brk */
	uint64_t	limit;	/* end of hypervisor memory region + 1 */
	uint64_t	hvd;	/* hypervisor description */
	uint64_t	guests;	/* pointer to base of guests array */
	uint64_t	cpus;	/* pointer to base of cpus array */
	uint64_t	cores;	/* pointer to base of cores array */
	uint64_t	cpustartset;
	uint64_t	dummytsb; /* pointer to dummy tsb */

	/*
	 * lock to ensure that only one strand executes
	 */
	uint64_t	single_strand_lock;

	uint64_t	strand_present;	/* strand state information */
	uint64_t	strand_active;
	uint64_t	strand_idle;
	uint64_t	strand_halt;

#ifdef DEBUG
	uint64_t	debug_spinlock; /* debug output serialization */
#endif

	uint64_t	error_svch; /* hypervisor error service handle */

#ifdef CONFIG_VBSC_SVC
	uint64_t	vbsc_svch;
	struct dbgerror vbsc_dbgerror; /* XXX DEBUG? */
#endif

	struct hv_svc_data *svc;
	struct vintr_dev *vintr;

	uint64_t	hvuart_addr;
	uint64_t	tod;
	uint64_t	todfrequency;
	uint64_t	stickfrequency;

	uint64_t	erpt_pa;		/* address of erpt buffer */
	uint64_t	erpt_size;		/* size */
	uint64_t	sram_erpt_buf_inuse;
	/*
	 * Cached hypervisor description nodes
	 */
	uint64_t	root_dtnode;
	uint64_t	devs_dtnode;
	uint64_t	svcs_dtnode;
	uint64_t	guests_dtnode;
	uint64_t	cpus_dtnode;

	/*
	 * error log lock
	 */
	uint64_t	error_lock;

	/*
	 * Name to nameindex translation table for hypervisor description
	 */
	struct nametable hdnametable;

	uint64_t	intrtgt;	/* SSI interrupt targets */

	/*
	 * hcall memory scrub and sync limit
	 *
	 * It's a cacheline count, not byte count, and must correspond to
	 * a byte count multiple of 8k.
	 */
	uint64_t	memscrub_max;

	uint64_t	devinstances;

	/*
	 * cyclic timers
	 */
	uint64_t	cyclic_maxd;		/* max delay in ticks */

	/*
	 * CE Storm Prevention
	 */
	uint64_t	ce_blackout;		/* ticks */
	uint64_t	ce_poll_time;		/* poll time in ticks */

	/*
	 * Error buffers still needed to be sent
	 */
	uint64_t	errs_to_send;
};

#endif /* !_ASM */

/*
 * The intrtgt property is a byte array of physical cpuids for the SSI
 * interrupt targets (INT_MAN devices 1 and 2)
 */
#define	INTRTGT_CPUMASK	0xff	/* Mask for a single array element */
#define	INTRTGT_DEVSHIFT 8	/* #bits for each entry in array */

/*
 * The reset-reason property provided by VBSC
 */
#define	RESET_REASON_POR	0
#define	RESET_REASON_SIR	1


#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA_CONFIG_H */
