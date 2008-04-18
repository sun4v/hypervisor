/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: guest.h
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

#ifndef _NIAGARA_GUEST_H
#define	_NIAGARA_GUEST_H

#pragma ident	"@(#)guest.h	1.48	06/05/11 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <hypervisor.h>
#include <sun4v/traps.h>
#include <hprivregs.h>
#include <config.h>
#include <fire.h>
#include <ncs.h>

#include <cpu_errs.h>
#include <vdev_intr.h>
#include <vdev_console.h>
#include <vdev_simdisk.h>
#include <svc_vbsc.h>


/*
 * This file contains definitions of the state structures for guests
 * and physical processors.
 */


/*
 * Various constants associated with the guest's API version
 * configuration.
 *
 * The guest's hcall table is an array of branch instructions.
 * Most of the API calls in the table are indexed by the FAST_TRAP
 * function number associated with the call.  The last five
 * calls are indexed by unique indexes.  Here's the overall
 * layout:
 *      +-----------------------+ --
 *      | FAST_TRAP function #0 |   \
 *      +-----------------------+    \
 *      | FAST_TRAP function #1 |     \
 *      +-----------------------+     |
 *      |          ...          |     |
 *      +-----------------------+     |
 *      |  MAX_FAST_TRAP_VALUE  |     |
 *      +-----------------------+      \
 *      |    DIAG_RA2PA_IDX     |       - NUM_API_CALLS
 *      +-----------------------+      /
 *      |    DIAG_HEXEC_IDX     |     |
 *      +-----------------------+     |
 *      |   MMU_MAP_ADDR_IDX    |     |
 *      +-----------------------+     |
 *      |  MMU_UNMAP_ADDR_IDX   |     /
 *      +-----------------------+    /
 *      |  TTRACE_ADDENTRY_IDX  |   /
 *      +-----------------------+ --
 *
 * Other important constants:
 *
 * NUM_API_GROUPS - The size of the "api_versions" table in the
 *     guest structure.  One more than the number of entries in the
 *     table in hcall.s, to account for API_GROUP_SUN4V.
 *
 * API_ENTRY_SIZE_SHIFT -
 * API_ENTRY_SIZE - Size of one entry in the API table.  Entries are
 *     unconditional branch instructions, so they occupy 4 bytes.
 *
 * HCALL_TABLE_SIZE - Total size in bytes of the hcall table for one
 *     guest.  The size is rounded up to align to the L2$ line size.
 */
#define	NUM_API_GROUPS		10	/* one more than table */

#define	MAX_FAST_TRAP_VALUE	0x121
#define	DIAG_RA2PA_IDX		(MAX_FAST_TRAP_VALUE+1)
#define	DIAG_HEXEC_IDX		(MAX_FAST_TRAP_VALUE+2)
#define	MMU_MAP_ADDR_IDX	(MAX_FAST_TRAP_VALUE+3)
#define	MMU_UNMAP_ADDR_IDX	(MAX_FAST_TRAP_VALUE+4)
#define	TTRACE_ADDENTRY_IDX	(MAX_FAST_TRAP_VALUE+5)
#define	NUM_API_CALLS		(MAX_FAST_TRAP_VALUE+6)

#define	API_ENTRY_SIZE_SHIFT	2
#define	API_ENTRY_SIZE		(1 << API_ENTRY_SIZE_SHIFT)

#define	HCALL_TABLE_SIZE	\
	    ((NUM_API_CALLS * API_ENTRY_SIZE + L2_LINE_SIZE-1) & \
		~(L2_LINE_SIZE-1))


/*
 * Constants relating to the internal representation of version
 * numbers.
 */
#define	MAJOR_OFF		0
#define	MINOR_OFF		4
#define	MAJOR_SHIFT		32
#define	MAKE_VERSION(maj, min)	(((maj)<<MAJOR_SHIFT)+(min))


#ifndef _ASM
/*
 * API group version information
 */
struct version {
	uint64_t	version_num;
	uint64_t	verptr;
};


struct guest_watchdog {
	uint64_t	ticks;	/* ticks of our heartbeat timer, not ms */
};


/*
 * Layout of the guest data structure in the niagara hypervisor
 */
struct guest {
	uint64_t	partid;

	/*
	 * Virtualized address space config
	 */
	uint64_t	mem_base;
	uint64_t	mem_size;
	uint64_t	mem_offset;
	uint64_t	real_base;
	uint64_t	real_limit;

	/*
	 * Per-guest virtualized console state
	 */
	struct console	console;

	/*
	 * Misc. Guest state
	 */
	uint64_t	tod_offset;
	uint64_t	ttrace_freeze;

	/*
	 * Static configuration data
	 */
	uint64_t	root; /* global hv configuration */
	struct cpu	*vcpus[NCPUS]; /* virtual cpu# index */
	struct core	*vcores[NCORES]; /* virtual core# index */

	/*
	 * Configuration information
	 */
	uint64_t	cpuset;	/* physical cpu ids */
	uint64_t	bootcpu; /* virtual cpu id */

	/*
	 * Permanent mappings
	 */
	uint64_t	perm_mappings_lock;
	struct mapping perm_mappings[NPERMMAPPINGS];

	/*
	 * API version management information
	 */
	struct version	api_groups[NUM_API_GROUPS];
	uint64_t	hcall_table;

	/*
	 * Virtual devices
	 */
	uint8_t		dev2inst[NDEVIDS];
	struct vino2inst vino2inst;
	struct vdev_state vdev_state;

	/*
	 * Service channels
	 */
	uint64_t	xid;	/* service id (XXXcan be calculated, remove) */

	/*
	 * Partition description
	 */
	uint64_t	pd_pa;
	uint64_t	pd_size;

	/*
	 * NVRAM
	 */
	uint64_t	nvram_pa;
	uint64_t	nvram_size;

	/*
	 * Debug
	 */
	uint64_t	dumpbuf_pa;
	uint64_t	dumpbuf_ra;
	uint64_t	dumpbuf_size;

	/*
	 * Config
	 */
	uint64_t	devs_dtnode;

	/*
	 * Startup configuration
	 */
	uint64_t	entry;
	uint64_t	rom_base;
	uint64_t	rom_size;

	/*
	 * Policy settings from Zeus
	 */
	uint64_t	perfreg_accessible;
	uint64_t	diagpriv;
	uint64_t	reset_reason;

	/*
	 * Watchdog configuration
	 */
	struct guest_watchdog watchdog;

#ifdef CONFIG_DISK
	/*
	 * Simulated disk
	 */
	struct hvdisk	disk;
#endif
};

#endif /* !_ASM */


#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA_GUEST_H */
