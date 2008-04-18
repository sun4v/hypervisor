/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: vpci.s
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

	.ident	"@(#)vpci.s	1.5	06/04/26 SMI"

	.file	"vpci.s"

#include <sys/asm_linkage.h>
#include <hypervisor.h>
#include <sparcv9/misc.h>
#include <asi.h>
#include <mmu.h>
#include <hprivregs.h>
#include <sun4v/traps.h>
#include <sun4v/asi.h>
#include <sun4v/mmu.h>
#include <sun4v/queue.h>

#include <offsets.h>
#include <guest.h>
#include <util.h>

/*
 * Return code template
 */
	ENTRY_NP(hcall_vpci_iommu_map)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MAP, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_iommu_map)

	ENTRY_NP(hcall_vpci_iommu_getmap)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_GETMAP, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_iommu_getmap)

	ENTRY_NP(hcall_vpci_iommu_unmap)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_UNMAP, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_iommu_unmap)

	ENTRY_NP(hcall_vpci_iommu_getbypass)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_GETBYPASS, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_iommu_getbypass)

	ENTRY_NP(hcall_vpci_config_get)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_CONFIGGET, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_config_get)

	ENTRY_NP(hcall_vpci_config_put)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_CONFIGPUT, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_config_put)

	ENTRY_NP(hcall_vpci_io_peek)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_IOPEEK, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_io_peek)

	ENTRY_NP(hcall_vpci_io_poke)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_IOPOKE, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_io_poke)

	ENTRY_NP(hcall_vpci_dma_sync)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_DMASYNC, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_dma_sync)

	ENTRY_NP(hcall_vpci_get_perfreg)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_GETPERFREG, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_get_perfreg)

	ENTRY_NP(hcall_vpci_set_perfreg)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_SETPERFREG, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_set_perfreg)
