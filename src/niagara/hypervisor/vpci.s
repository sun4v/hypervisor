/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

	.ident	"@(#)vpci.s	1.4	05/06/15 SMI"

	.file	"vpci.s"

#include <sys/asm_linkage.h>
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
#include "util.h"

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
