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
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _NIAGARA_GUEST_H
#define	_NIAGARA_GUEST_H

#pragma ident	"@(#)guest.h	1.44	05/09/08 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <hypervisor.h>
#include <sun4v/traps.h>
#include <niagara/hprivregs.h>
#include "config.h"
#include "fire.h"
#include "ncs.h"

#include "cpu_errs.h"
#include "vdev_intr.h"
#include "vdev_console.h"
#include "vdev_simdisk.h"

#ifndef _ASM

/*
 * This file contains definitions of the state structures for guests
 * and physical processors.
 */


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
	uint64_t	pd_size;
	uint64_t	pd_pa;

	/*
	 * NVRAM
	 */
	uint64_t	nvram_pa;
	uint64_t	nvram_size;

	/*
	 * Debug
	 */
	uint64_t	dumpbuf_ra;
	uint64_t	dumpbuf_pa;
	uint64_t	dumpbuf_size;

	/*
	 * Config
	 */
	uint64_t	dtnode;
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
