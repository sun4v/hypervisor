/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: cpu.h
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

#ifndef _CPU_H
#define	_CPU_H

#pragma ident	"@(#)cpu.h	1.11	05/10/31 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Size of svc code's per-cpu scratch area in 64-bit words
 */
#define	NSVCSCRATCHREGS	6


/*
 * Stack depth for each cpu
 */
#define	STACKDEPTH	12

#ifndef _ASM

typedef	uint64_t	cpuset_t;

/*
 * Structures for saving watchdog failure state
 */
struct trapstate {
	uint64_t	htstate;
	uint64_t	tstate;
	uint64_t	tt;
	uint64_t	tpc;
	uint64_t	tnpc;
};

struct trapglobals {
	uint64_t	g[8];
};


/*
 * Permanent mapping state
 */
struct mapping {
	uint64_t	va;
	uint64_t	tte;
	uint32_t	icpuset;
	uint32_t	dcpuset;
};


/*
 * Per-core attributes.
 */
struct core {
	int8_t		cid;		/* physical core id */
	int8_t		vid;		/* virtual core id */
	mau_queue_t	mau_queue;	/* queue for MAU */
};


/*
 * Stack support
 *
 * Each CPU has a very simple stack.  Only two operations are supported:
 * Push and Pop. In the event the stack gets full or under poped, hv will
 * abort.
 */
struct stack {
	uint64_t	top;			/* top of the stack */
	uint64_t	val[STACKDEPTH];	/* reg value */
};


/*
 * This is the physical cpu struct.  There's one per physical cpu.
 *
 * This hypervisor supports static assignment of processors to guests.
 * In a hypervisor that supports dynamic assignment of processors to
 * guests and/or sub-cpu scheduling, some of these members would be
 * relocated to vcpu structures contained within each guest structure.
 */
struct cpu {
	struct guest	*guest;	/* pointer to owning guest */
	struct config	*root;
	struct core	*core;
	int8_t		vid;	/* virtual cpu number */
	int8_t		pid;	/* physical cpu number */

	uint64_t	scr0;	/* scratch space */
	uint64_t	scr1;
	uint64_t	scr2;
	uint64_t	scr3;

	/*
	 * Low-level mailbox
	 */
	uint64_t	status;
	uint64_t	lastpoke;
	uint64_t	command;
	uint64_t	arg0;
	uint64_t	arg1;
	uint64_t	arg2;
	uint64_t	arg3;
	uint64_t	arg4;
	uint64_t	arg5;
	uint64_t	arg6;
	uint64_t	arg7;
	uint64_t	vintr;

	/*
	 * State
	 */
	uint64_t	rtba;
	uint64_t	mmu_area;
	uint64_t	mmu_area_ra;
	uint64_t	cpuq_base;
	uint64_t	cpuq_size;
	uint64_t	cpuq_mask;
	uint64_t	cpuq_base_ra;
	uint64_t	devq_base;
	uint64_t	devq_size;
	uint64_t	devq_mask;
	uint64_t	devq_base_ra;
	uint64_t	errqnr_base;
	uint64_t	errqnr_size;
	uint64_t	errqnr_mask;
	uint64_t	errqnr_base_ra;
	uint64_t	errqr_base;
	uint64_t	errqr_size;
	uint64_t	errqr_mask;
	uint64_t	errqr_base_ra;

	/*
	 * Traptrace support
	 */
	uint64_t	ttrace_offset;
	uint64_t	ttrace_buf_size;
	uint64_t	ttrace_buf_ra;
	uint64_t	ttrace_buf_pa;

	/*
	 * TSBs
	 */
	uint64_t	ntsbs_ctx0;
	uint64_t	ntsbs_ctxn;
	uint8_t		tsbds_ctx0[MAX_NTSB * TSBD_BYTES];
	uint8_t		tsbds_ctxn[MAX_NTSB * TSBD_BYTES];

	/*
	 * MMU statistic support
	 */
	uint64_t	mmustat_area;
	uint64_t	mmustat_area_ra;

#ifdef CONFIG_SVC
	uint64_t	svcregs[NSVCSCRATCHREGS];
#endif

	/*
	 * hstick interrupt support
	 */
	struct cyclic_cpu_state	cyclic_cpu_state;

	/*
	 * Error handling support
	 */
	uint64_t	err_seq_no;	/* unique sequence # */
	uint64_t	regerr;			/* SPARC ESR for IRC/FRC */
	int16_t		l2_bank;		/* l2 bank */
	int16_t		rpt_flags;		/* Report flags: action, buf */
	int16_t		wip;			/* flag: Work In Progress */
	uint32_t	err_flag;		/* error handling flags */
	uint64_t	err_poll_tick;		/* poll time in ticks */
	uint64_t	err_ret;		/* saved return address */
	uint64_t	err_poll_itt;		/* saved interrupt tick time */
	uint64_t	err_poll_ret;		/* saved return address */
	uint64_t	err_sparc_afsr;		/* tmp store */
	uint64_t	err_sparc_afar;		/* tmp store */
	uint64_t	l2_line_state;	/* state of line on err */
	struct cpuerpt	ce_rpt;		/* CE error buffer */
	struct cpuerpt	ue_rpt;		/* UE error buffer */
	uint64_t	io_prot;	/* i/o error protection flag */
	uint64_t	io_error;	/* i/o error flag */

	/*
	 * Config
	 */
	uint64_t	dtnode;

	/*
	 * Saved failure state
	 */
	uint64_t	fail_tl;
	uint64_t	fail_gl;
	struct trapstate trapstate[MAXTL];
	struct trapglobals trapglobals[MAXGL];
	struct stack	stack;
};

#endif /* !_ASM */

/*
 * per-cpu low-level mailbox commands, see cpu.command
 */
#define	CPU_CMD_STARTGUEST 0x1
#define	CPU_CMD_BUSY 0x2
#define	CPU_CMD_GUESTMONDO_READY 0x3

/*
 *  struct cpu.wip: Work In Progress
 */
#define	CPU_WIP_CE		(1 << 0)	/* ce processing */
#define	CPU_WIP_UE		(1 << 1)	/* ue processing */
#define	CPU_WIP_CI		(1 << 2)	/* cmpr interrupt processing */
#define	CPU_WIP_ERRPOLL		(1 << 4)	/* polling for errors */

#ifdef __cplusplus
}
#endif

#endif /* _CPU_H */
