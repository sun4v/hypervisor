/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hcall.s
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

	.ident	"@(#)hcall.s	1.78	05/11/23 SMI"

	.file	"hcall.s"

/*
 * Niagara API calls
 */

#include <sys/asm_linkage.h>
#include <hypervisor.h>
#include <sparcv9/misc.h>
#include <niagara/asi.h>
#include <niagara/mmu.h>
#include <niagara/jbi_regs.h>
#include <niagara/dram.h>
#include <sun4v/traps.h>
#include <sun4v/asi.h>
#include <sun4v/mmu.h>
#include <sun4v/queue.h>
#include <devices/pc16550.h>
#include <sparcv9/asi.h>
#include <mmustat.h>

#include "config.h"
#include "cpu.h"
#include "guest.h"
#include "offsets.h"
#include "traptrace.h"
#include "svc.h"
#include "util.h"
#include "vdev_ops.h"
#include "vdev_intr.h"
#include "debug.h"

#ifdef CONFIG_BRINGUP
#define	VDEV_GENINTR	0x280	/* for testing */
#endif /* CONFIG_BRINGUP */


/*
 * hcall_core - entry point for the core hcalls: versioning plus
 * aliases for standard APIs that need to be called when there
 * exists a version mismatch.
 */
	ENTRY_NP(hcall_core)
	HCALL_RET(EBADTRAP)
	SET_SIZE(hcall_core)


/*
 * hcall - entry point for FAST_TRAP hcalls
 */
	ENTRY_NP(hcall)
	cmp	%o5, MMU_DEMAP_PAGE
	be,pn	%xcc, hcall_mmu_demap_page
	cmp	%o5, MMU_DEMAP_CTX
	be,pn	%xcc, hcall_mmu_demap_ctx
	cmp	%o5, MMU_DEMAP_ALL
	be,pn	%xcc, hcall_mmu_demap_all
	cmp	%o5, CPU_MONDO_SEND
	be,pn	%xcc, hcall_cpu_mondo_send
	cmp	%o5, CONS_PUTCHAR
	be,pn	%xcc, hcall_cons_putchar
	cmp	%o5, CONS_GETCHAR
	be,pn	%xcc, hcall_cons_getchar
	cmp	%o5, TOD_GET
	be,pn	%xcc, hcall_tod_get
	cmp	%o5, TOD_SET
	be,pn	%xcc, hcall_tod_set
	cmp	%o5, MMU_TSB_CTX0
	be,pn	%xcc, hcall_mmu_tsb_ctx0
	cmp	%o5, MMU_TSB_CTXNON0
	be,pn	%xcc, hcall_mmu_tsb_ctxnon0
	cmp	%o5, MMU_MAP_PERM_ADDR
	be,pn	%xcc, hcall_mmu_map_perm_addr
	cmp	%o5, MMU_UNMAP_PERM_ADDR
	be,pn	%xcc, hcall_mmu_unmap_perm_addr
	cmp	%o5, MMU_FAULT_AREA_CONF
	be,pn	%xcc, hcall_mmu_fault_area_conf
	cmp	%o5, MEM_SCRUB
	be,pn	%xcc, hcall_mem_scrub
	cmp	%o5, MEM_SYNC
	be,pn	%xcc, hcall_mem_sync
#if defined(NVRAM_READ) && defined(NVRAM_WRITE)
	cmp	%o5, NVRAM_READ
	be,pn	%xcc, hcall_nvram_read
	cmp	%o5, NVRAM_WRITE
	be,pn	%xcc, hcall_nvram_write
#endif
#ifdef CONFIG_SVC
	cmp	%o5, SVC_SEND
	be,pn	%xcc, hcall_svc_send
	cmp	%o5, SVC_RECV
	be,pn	%xcc, hcall_svc_recv
	cmp	%o5, SVC_GETSTATUS
	be,pn	%xcc, hcall_svc_getstatus
	cmp	%o5, SVC_SETSTATUS
	be,pn	%xcc, hcall_svc_setstatus
	cmp	%o5, SVC_CLRSTATUS
	be,pn	%xcc, hcall_svc_clrstatus
#endif
	cmp	%o5, CPU_QINFO
	be,pn	%xcc, hcall_qinfo
	cmp	%o5, CPU_QCONF
	be,pn	%xcc, hcall_qconf
	cmp	%o5, CPU_START
	be,pn	%xcc, hcall_cpu_start
	cmp	%o5, CPU_STOP
	be,pn	%xcc, hcall_cpu_stop
	cmp	%o5, CPU_STATE
	be,pn	%xcc, hcall_cpu_state
	cmp	%o5, CPU_YIELD
	be,pn	%xcc, hcall_cpu_yield
	cmp	%o5, MACH_SIR
	be,pn	%xcc, hcall_mach_sir
	cmp	%o5, MACH_EXIT
	be,pn	%xcc, hcall_mach_exit
	cmp	%o5, CPU_MYID
	be,pn	%xcc, hcall_cpu_myid
	cmp	%o5, MMU_ENABLE
	be,pn	%xcc, hcall_mmu_enable
	cmp	%o5, MMU_TSB_CTX0_INFO
	be,pn	%xcc, hcall_mmu_tsb_ctx0_info
	cmp	%o5, MMU_TSB_CTXNON0_INFO
	be,pn	%xcc, hcall_mmu_tsb_ctxnon0_info
	cmp	%o5, NIAGARA_GET_PERFREG
	be,pn	%xcc, hcall_niagara_getperf
	cmp	%o5, NIAGARA_SET_PERFREG
	be,pn	%xcc, hcall_niagara_setperf
	cmp	%o5, DIAG_RA2PA
	be,pn	%xcc, hcall_ra2pa
	cmp	%o5, DIAG_HEXEC
	be,pn	%xcc, hcall_hexec
	cmp	%o5, MACH_DESC
	be,pn	%xcc, hcall_mach_desc
	cmp	%o5, DUMP_BUF_INFO
	be,pn	%xcc, hcall_dump_buf_info
	cmp	%o5, DUMP_BUF_UPDATE
	be,pn	%xcc, hcall_dump_buf_update
	cmp	%o5, INTR_DEVINO2SYSINO
	be,pn	%xcc, hcall_intr_devino2sysino
	cmp	%o5, INTR_GETENABLED
	be,pn	%xcc, hcall_intr_getenabled
	cmp	%o5, INTR_SETENABLED
	be,pn	%xcc, hcall_intr_setenabled
	cmp	%o5, INTR_GETSTATE
	be,pn	%xcc, hcall_intr_getstate
	cmp	%o5, INTR_SETSTATE
	be,pn	%xcc, hcall_intr_setstate
	cmp	%o5, INTR_GETTARGET
	be,pn	%xcc, hcall_intr_gettarget
	cmp	%o5, INTR_SETTARGET
	be,pn	%xcc, hcall_intr_settarget
	cmp	%o5, VPCI_IOMMU_MAP
	be,pn	%xcc, hcall_vpci_iommu_map
	cmp	%o5, VPCI_IOMMU_UNMAP
	be,pn	%xcc, hcall_vpci_iommu_unmap
	cmp	%o5, VPCI_IOMMU_GETMAP
	be,pn	%xcc, hcall_vpci_iommu_getmap
	cmp	%o5, VPCI_IOMMU_GETBYPASS
	be,pn	%xcc, hcall_vpci_iommu_getbypass
	cmp	%o5, VPCI_CONFIG_GET
	be,pn	%xcc, hcall_vpci_config_get
	cmp	%o5, VPCI_CONFIG_PUT
	be,pn	%xcc, hcall_vpci_config_put
	cmp	%o5, VPCI_IO_PEEK
	be,pn	%xcc, hcall_vpci_io_peek
	cmp	%o5, VPCI_IO_POKE
	be,pn	%xcc, hcall_vpci_io_poke
	cmp	%o5, VPCI_DMA_SYNC
	be,pn	%xcc, hcall_vpci_dma_sync
	cmp	%o5, MSIQ_CONF
	be,pn	%xcc, hcall_msiq_conf
	cmp	%o5, MSIQ_INFO
	be,pn	%xcc, hcall_msiq_info
	cmp	%o5, MSIQ_GETVALID
	be,pn	%xcc, hcall_msiq_getvalid
	cmp	%o5, MSIQ_SETVALID
	be,pn	%xcc, hcall_msiq_setvalid
	cmp	%o5, MSIQ_GETSTATE
	be,pn	%xcc, hcall_msiq_getstate
	cmp	%o5, MSIQ_SETSTATE
	be,pn	%xcc, hcall_msiq_setstate
	cmp	%o5, MSIQ_GETHEAD
	be,pn	%xcc, hcall_msiq_gethead
	cmp	%o5, MSIQ_SETHEAD
	be,pn	%xcc, hcall_msiq_sethead
	cmp	%o5, MSIQ_GETTAIL
	be,pn	%xcc, hcall_msiq_gettail
	cmp	%o5, MSI_GETVALID
	be,pn	%xcc, hcall_msi_getvalid
	cmp	%o5, MSI_SETVALID
	be,pn	%xcc, hcall_msi_setvalid
	cmp	%o5, MSI_GETSTATE
	be,pn	%xcc, hcall_msi_getstate
	cmp	%o5, MSI_SETSTATE
	be,pn	%xcc, hcall_msi_setstate
	cmp	%o5, MSI_GETMSIQ
	be,pn	%xcc, hcall_msi_getmsiq
	cmp	%o5, MSI_SETMSIQ
	be,pn	%xcc, hcall_msi_setmsiq
	cmp	%o5, MSI_MSG_GETVALID
	be,pn	%xcc, hcall_msi_msg_getvalid
	cmp	%o5, MSI_MSG_SETVALID
	be,pn	%xcc, hcall_msi_msg_setvalid
	cmp	%o5, MSI_MSG_GETMSIQ
	be,pn	%xcc, hcall_msi_msg_getmsiq
	cmp	%o5, MSI_MSG_SETMSIQ
	be,pn	%xcc, hcall_msi_msg_setmsiq
#ifdef CONFIG_DISK
	cmp	%o5, DISK_READ
	be,pn	%xcc, hcall_disk_read
	cmp	%o5, DISK_WRITE
	be,pn	%xcc, hcall_disk_write
#endif
	cmp	%o5, NCS_REQUEST
	be,pn	%xcc, hcall_ncs_request
	cmp	%o5, NIAGARA_MMUSTAT_CONF
	be,pn	%xcc, hcall_niagara_mmustat_conf
	cmp	%o5, NIAGARA_MMUSTAT_INFO
	be,pn	%xcc, hcall_niagara_mmustat_info
	cmp	%o5, TTRACE_BUF_CONF
	be,pn   %xcc, hcall_ttrace_buf_conf
	cmp	%o5, TTRACE_BUF_INFO
	be,pn   %xcc, hcall_ttrace_buf_info
	cmp	%o5, TTRACE_ENABLE
	be,pn   %xcc, hcall_ttrace_enable
	cmp	%o5, TTRACE_FREEZE
	be,pn   %xcc, hcall_ttrace_freeze
	cmp	%o5, MMU_FAULT_AREA_INFO
	be,pn	%xcc, hcall_mmu_fault_area_info
	cmp	%o5, CPU_GET_RTBA
	be,pn	%xcc, hcall_get_rtba
	cmp	%o5, CPU_SET_RTBA
	be,pn	%xcc, hcall_set_rtba
#ifdef CONFIG_FIRE
	cmp	%o5, FIRE_GET_PERFREG
	be,pn	%xcc, hcall_vpci_get_perfreg
	cmp	%o5, FIRE_SET_PERFREG
	be,pn	%xcc, hcall_vpci_set_perfreg
#endif
#ifdef CONFIG_BRINGUP
	cmp	%o5, VDEV_GENINTR
	be,pn	%xcc, hcall_vdev_genintr
#endif
#ifdef DEBUG
	cmp	%o5, MMU_PERM_ADDR_INFO
	be,pn	%xcc, hcall_mmu_perm_addr_info
#endif
	nop
	HCALL_RET(EBADTRAP)
	SET_SIZE(hcall)

/*
 * Common error escapes so errors can be implemented by
 * cmp, branch.
 */
	ENTRY(hret_ok)
	HCALL_RET(EOK)
	SET_SIZE(hret_ok)

	ENTRY(herr_nocpu)
	HCALL_RET(ENOCPU)
	SET_SIZE(herr_nocpu)

	ENTRY(herr_noraddr)
	HCALL_RET(ENORADDR)
	SET_SIZE(herr_noraddr)

	ENTRY(herr_nointr)
	HCALL_RET(ENOINTR)
	SET_SIZE(herr_nointr)

	ENTRY(herr_badpgsz)
	HCALL_RET(EBADPGSZ)
	SET_SIZE(herr_badpgsz)

	ENTRY(herr_badtsb)
	HCALL_RET(EBADTSB)
	SET_SIZE(herr_badtsb)

	ENTRY(herr_inval)
	HCALL_RET(EINVAL)
	SET_SIZE(herr_inval)

	ENTRY(herr_badtrap)
	HCALL_RET(EBADTRAP)
	SET_SIZE(herr_badtrap)

	ENTRY(herr_badalign)
	HCALL_RET(EBADALIGN)
	SET_SIZE(herr_badalign)

	ENTRY(herr_wouldblock)
	HCALL_RET(EWOULDBLOCK)
	SET_SIZE(herr_wouldblock)

	ENTRY(herr_noaccess)
	HCALL_RET(ENOACCESS)
	SET_SIZE(herr_noaccess)

	ENTRY(herr_ioerror)
	HCALL_RET(EIO)
	SET_SIZE(herr_ioerror)

	ENTRY(herr_cpuerror)
	HCALL_RET(ECPUERROR)
	SET_SIZE(herr_cpuerror)

	ENTRY(herr_toomany)
	HCALL_RET(ETOOMANY)
	SET_SIZE(herr_toomany)

	ENTRY(herr_nomap)
	HCALL_RET(ENOMAP)
	SET_SIZE(herr_nomap)

	ENTRY(herr_notsupported)
	HCALL_RET(ENOTSUPPORTED)
	SET_SIZE(herr_notsupported)


/*
 * mach_exit
 *
 * arg0 exit code (%o0)
 * --
 * does not return
 */
	ENTRY_NP(hcall_mach_exit)
	/*
	 * - quiesce all other cpus in guest
	 * - re-initialize guest
	 * - go back to start so boot cpu (maybe not this cpu)
	 *   can reboot the guest or wait for further instructions
	 *   from the Higher One
	 */
#ifdef CONFIG_VBSC_SVC
	ba,pt	%xcc, vbsc_guest_exit
	nop
#else
	LEGION_EXIT(%o0)
#endif
	HCALL_RET(EBADTRAP)
	SET_SIZE(hcall_mach_exit)


/*
 * mach_sir
 *
 * --
 * does not return
 */
	ENTRY_NP(hcall_mach_sir)
	/*
	 * - quiesce all other cpus in guest
	 * - re-initialize guest
	 * - go back to start so boot cpu (maybe not this cpu)
	 *   can reboot the guest or wait for further instructions
	 *   from the Higher One
	 */
#ifdef CONFIG_VBSC_SVC
	ba,pt	%xcc, vbsc_guest_sir
	nop
#else
	LEGION_EXIT(0)
#endif
	HCALL_RET(EBADTRAP)
	SET_SIZE(hcall_mach_sir)


/*
 * mach_desc
 *
 * arg0 buffer (%o0)
 * arg1 len (%o1)
 * --
 * ret0 status (%o0)
 * ret1 actual len (%o1) (for EOK or EINVAL)
 *
 * guest uses this sequence to get the machine description:
 *	mach_desc(0, 0)
 *	if %o0 != EINVAL, failed
 *	len = %o1
 *	buf = allocate(len)
 *	mach_desc(buf, len)
 *	if %o0 != EOK, failed
 * so the EINVAL case is the first error check
 */
	ENTRY_NP(hcall_mach_desc)
	CPU_GUEST_STRUCT(%g1, %g6)
	set	GUEST_PD_SIZE, %g7
	ldx	[%g6 + %g7], %g3
	! paranoia for xcopy - should already be 16byte multiple
	add	%g3, MACH_DESC_ALIGNMENT - 1, %g3
	andn	%g3, MACH_DESC_ALIGNMENT - 1, %g3
	cmp	%g3, %o1
	bgu,pn	%xcc, herr_inval
	mov	%g3, %o1	! return PD size for success or EINVAL

	btst	MACH_DESC_ALIGNMENT - 1, %o0
	bnz,pn	%xcc, herr_badalign
	.empty	/* RANGE_CHECK may start in a delay slot */

	RANGE_CHECK(%g6, %o0, %g3, herr_noraddr, %g4)
	REAL_OFFSET(%g6, %o0, %g4, %g5)
	! %g3 = size of pd
	! %g4 = pa of guest buffer
	/* xcopy(pd, buf[%o0], size[%g3]) */
	set	GUEST_PD_PA, %g7
	ldx	[%g6 + %g7], %g1
	mov	%g4, %g2
	ba	xcopy
	rd	%pc, %g7

	! %o1 was set above to the guest's PD size
	HCALL_RET(EOK)
	SET_SIZE(hcall_mach_desc)


/*
 * tod_get - Time-of-day get
 *
 * no arguments
 * --
 * ret0 status (%o0)
 * ret1 tod (%o1)
 */
	ENTRY_NP(hcall_tod_get)
	CPU_STRUCT(%g1)
	CPU2ROOT_STRUCT(%g1, %g2)
	CPU2GUEST_STRUCT(%g1, %g1)
	!! %g1 guestp
	!! %g2 configp
	ldx	[%g1 + GUEST_TOD_OFFSET], %g3
	ldx	[%g2 + CONFIG_TOD], %g4
	ldx	[%g2 + CONFIG_TODFREQUENCY], %g5
	!! %g3 guest's tod offset
	!! %g4 tod
	!! %g5 tod frequency
#ifdef CONFIG_STATICTOD
	! If the PD says no TOD then start with 0
	brz,pn	%g4, hret_ok
	  clr	%o1
#else
	brz,pn	%g4, herr_notsupported
	  clr	%o1		! In case error status not checked
#endif

	ldx	[%g4], %o1
	udivx	%o1, %g5, %o1	! Convert to seconds
	add	%o1, %g3, %o1	! Add partition's tod offset
	HCALL_RET(EOK)
	SET_SIZE(hcall_tod_get)

/*
 * tod_set - Time-of-day set
 *
 * arg0 tod (%o0)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_tod_set)
	CPU_STRUCT(%g1)
	CPU2ROOT_STRUCT(%g1, %g2)
	CPU2GUEST_STRUCT(%g1, %g1)
	!! %g1 guestp
	!! %g2 configp
	ldx	[%g1 + GUEST_TOD_OFFSET], %g3
	ldx	[%g2 + CONFIG_TOD], %g4
	ldx	[%g2 + CONFIG_TODFREQUENCY], %g5
	!! %g3 guest's tod offset
	!! %g4 tod
	!! %g5 tod frequency

#ifdef CONFIG_STATICTOD
	/*
	 * If no hardware TOD then tod-get returned 0 the first time
	 * and will continue to do so.
	 */
	brz,pn	%g4, hret_ok
	  nop
#else
	brz,pn	%g4, herr_notsupported
	  nop
#endif

	ldx	[%g4], %g6	! %g6 = system tod
	udivx	%g6, %g5, %g6	! Convert to seconds
	sub	%o0, %g6, %g6	! %g4 = new delta
	stx	%g6, [%g1 + GUEST_TOD_OFFSET]
#ifdef CONFIG_VBSC_SVC
	/*
	 * Try to send the new offset to vbsc.  It may fail,
	 * we send the offset on a guest exit/reset as well.
	 */
	!! %g1 = guestp
	HVCALL(vbsc_guest_tod_offset)
#endif
	HCALL_RET(EOK)
	SET_SIZE(hcall_tod_set)


/*
 * mmu_enable
 *
 * arg0 enable (%o0)
 * arg1 return address (%o1)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_mmu_enable)
	/*
	 * Check requested return address for instruction
	 * alignment
	 */
	btst	(INSTRUCTION_ALIGNMENT - 1), %o1
	bnz,pn	%xcc, herr_badalign
	nop

	ldxa	[%g0]ASI_LSUCR, %g1
	set	(LSUCR_DM | LSUCR_IM), %g2
	!! %g1 = current lsucr value
	!! %g2 = mmu enable mask

	brz,pn	%o0, 1f		! enable or disable?
	btst	%g1, %g2	! ccr indicates current status

	/*
	 * Trying to enable
	 *
	 * The return address will be virtual and we cannot
	 * check its range, the alignment has already been
	 * checked.
	 */
	bnz,pn	%xcc, herr_inval ! it's already enabled
	or	%g1, %g2, %g1	! enable MMU

	ba,pt	%xcc, 2f
	nop

1:
	/*
	 * Trying to disable
	 *
	 * The return address is a real address so we check
	 * its range, the alignment has already been checked.
	 */
	bz,pn	%xcc, herr_inval ! it's already disabled
	andn	%g1, %g2, %g1	! disable MMU

	/* Check RA range */
	GUEST_STRUCT(%g3)
	RANGE_CHECK(%g3, %o1, INSTRUCTION_SIZE, herr_noraddr, %g4)

2:
	wrpr	%o1, %tnpc
	stxa	%g1, [%g0]ASI_LSUCR
	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_enable)


/*
 * mmu_fault_area_conf
 *
 * arg0 raddr (%o0)
 * --
 * ret0 status (%o0)
 * ret1 oldraddr (%o1)
 */
	ENTRY_NP(hcall_mmu_fault_area_conf)
	btst	(MMU_FAULT_AREA_ALIGNMENT - 1), %o0	! check alignment
	bnz,pn	%xcc, herr_badalign
	CPU_GUEST_STRUCT(%g1, %g4)
	brz,a,pn %o0, 1f
	  mov	0, %g2
	RANGE_CHECK(%g4, %o0, MMU_FAULT_AREA_SIZE, herr_noraddr, %g3)
	REAL_OFFSET(%g4, %o0, %g2, %g3)
1:
	ldx	[%g1 + CPU_MMU_AREA_RA], %o1
	stx	%o0, [%g1 + CPU_MMU_AREA_RA]
	stx	%g2, [%g1 + CPU_MMU_AREA]

	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_fault_area_conf)

/*
 * mmu_fault_area_info
 *
 * --
 * ret0 status (%o0)
 * ret1 fault area raddr (%o1)
 */
	ENTRY_NP(hcall_mmu_fault_area_info)
	CPU_STRUCT(%g1)
	ldx	[%g1 + CPU_MMU_AREA_RA], %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_fault_area_info)

/*
 * mmu_tsb_ctx0
 *
 * arg0 ntsb (%o0)
 * arg1 tsbs (%o1)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_mmu_tsb_ctx0)
	CPU_GUEST_STRUCT(%g5, %g6)
	/* set cpu->ntsbs to zero now in case we error exit */
	stx	%g0, [%g5 + CPU_NTSBS_CTX0]
	/* Also zero out H/W bases */
	ba	set_dummytsb_ctx0
	rd	%pc, %g7
	brz,pn	%o0, setntsbs0
	cmp	%o0, MAX_NTSB
	bgu,pn	%xcc, herr_inval
	btst	TSBD_ALIGNMENT - 1, %o1
	bnz,pn	%xcc, herr_badalign
	sllx	%o0, TSBD_SHIFT, %g3
	RANGE_CHECK(%g6, %o1, %g3, herr_noraddr, %g2)
	/* xcopy(tsbs, cpu->tsbds, ntsbs*TSBD_BYTES) */
	REAL_OFFSET(%g6, %o1, %g1, %g2)
	add	%g5, CPU_TSBDS_CTX0, %g2
	! xcopy trashes g1-4
	ba	xcopy
	rd	%pc, %g7
	/* loop over each TSBD and validate */
	mov	%o0, %g1
	add	%g5, CPU_TSBDS_CTX0, %g2
1:
	/* check pagesize - accept any size encoding? XXX */
	/* XXX pageszidx is lowest-order bit of pageszmask */
	lduh	[%g2 + TSBD_IDXPGSZ_OFF], %g3
	cmp	%g3, NPGSZ
	bgeu,pn	%xcc, herr_badpgsz
	nop
	/* check associativity - only support 1-way */
	lduh	[%g2 + TSBD_ASSOC_OFF], %g3
	cmp	%g3, 1
	bne,pn	%icc, herr_badtsb
	nop
	/* check TSB size */
	ld	[%g2 + TSBD_SIZE_OFF], %g3
	sub	%g3, 1, %g4
	btst	%g3, %g4
	bnz,pn	%icc, herr_badtsb
	mov	TSB_SZ0_ENTRIES, %g4
	cmp	%g3, %g4
	blt,pn	%icc, herr_badtsb
	sll	%g4, TSB_MAX_SZCODE, %g4
	cmp	%g3, %g4
	bgt,pn	%icc, herr_badtsb
	nop
	/* check context index field - must be -1 (shared) or zero */
	ld	[%g2 + TSBD_CTX_INDEX], %g3
	cmp	%g3, TSBD_CTX_IDX_SHARE
	be	%icc, 2f	! -1 is OK
	nop
	brnz,pn	%g3, herr_inval	! only one set of context regs
	nop
2:
	/* check reserved field - must be zero for now */
	ldx	[%g2 + TSBD_RSVD_OFF], %g3
	brnz,pn	%g3, herr_inval
	nop
	/* check TSB base real address */
	ldx	[%g2 + TSBD_BASE_OFF], %g3
	ld	[%g2 + TSBD_SIZE_OFF], %g4
	sllx	%g4, TSBE_SHIFT, %g4
	RANGE_CHECK(%g6, %g3, %g4, herr_noraddr, %g7)
	/* range OK, check alignment */
	sub	%g4, 1, %g4
	btst	%g3, %g4
	bnz,pn	%xcc, herr_badalign
	sub	%g1, 1, %g1
	brnz,pt	%g1, 1b
	add	%g2, TSBD_BYTES, %g2

	/* now setup H/W TSB regs */
	/* only look at first two TSBDs for now */
	add	%g5, CPU_TSBDS_CTX0, %g2
	ldx	[%g2 + TSBD_BASE_OFF], %g1
	REAL_OFFSET(%g6, %g1, %g1, %g4)
	ld	[%g2 + TSBD_SIZE_OFF], %g4
	srl	%g4, TSB_SZ0_SHIFT, %g4
1:
	btst	1, %g4
	srl	%g4, 1, %g4
	bz,a,pt	%icc, 1b
	  add	%g1, 1, %g1	! increment TSB size field

	stxa	%g1, [%g0]ASI_DTSBBASE_CTX0_PS0
	stxa	%g1, [%g0]ASI_ITSBBASE_CTX0_PS0

	lduh	[%g2 + TSBD_IDXPGSZ_OFF], %g3
	stxa	%g3, [%g0]ASI_DTSB_CONFIG_CTX0 ! (PS0 only)
	stxa	%g3, [%g0]ASI_ITSB_CONFIG_CTX0 ! (PS0 only)

	/* process second TSBD, if available */
	cmp	%o0, 1
	be,pt	%xcc, 2f
	add	%g2, TSBD_BYTES, %g2	! move to next TSBD
	ldx	[%g2 + TSBD_BASE_OFF], %g1
	REAL_OFFSET(%g6, %g1, %g1, %g4)
	ld	[%g2 + TSBD_SIZE_OFF], %g4
	srl	%g4, TSB_SZ0_SHIFT, %g4
1:
	btst	1, %g4
	srl	%g4, 1, %g4
	bz,a,pt	%icc, 1b
	  add	%g1, 1, %g1	! increment TSB size field

	stxa	%g1, [%g0]ASI_DTSBBASE_CTX0_PS1
	stxa	%g1, [%g0]ASI_ITSBBASE_CTX0_PS1

	/* %g3 still has old CONFIG value. */
	lduh	[%g2 + TSBD_IDXPGSZ_OFF], %g7
	sllx	%g7, ASI_TSB_CONFIG_PS1_SHIFT, %g7
	or	%g3, %g7, %g3
	stxa	%g3, [%g0]ASI_DTSB_CONFIG_CTX0 ! (PS0 + PS1)
	stxa	%g3, [%g0]ASI_ITSB_CONFIG_CTX0 ! (PS0 + PS1)

2:
	stx	%o0, [%g5 + CPU_NTSBS_CTX0]
setntsbs0:
	clr	%o1	! no return value
	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_tsb_ctx0)


/*
 * mmu_tsb_ctxnon0
 *
 * arg0 ntsb (%o0)
 * arg1 tsbs (%o1)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_mmu_tsb_ctxnon0)
	CPU_GUEST_STRUCT(%g5, %g6)
	/* set cpu->ntsbs to zero now in case we error exit */
	stx	%g0, [%g5 + CPU_NTSBS_CTXN]
	/* Also zero out H/W bases */
	ba	set_dummytsb_ctxN
	rd	%pc, %g7
	brz,pn	%o0, setntsbsN
	cmp	%o0, MAX_NTSB
	bgu,pn	%xcc, herr_inval
	btst	TSBD_ALIGNMENT - 1, %o1
	bnz,pn	%xcc, herr_badalign
	sllx	%o0, TSBD_SHIFT, %g3
	RANGE_CHECK(%g6, %o1, %g3, herr_noraddr, %g2)
	/* xcopy(tsbs, cpu->tsbds, ntsbs*TSBD_BYTES) */
	REAL_OFFSET(%g6, %o1, %g1, %g2)
	add	%g5, CPU_TSBDS_CTXN, %g2
	! xcopy trashes g1-4
	ba	xcopy
	rd	%pc, %g7
	/* loop over each TSBD and validate */
	mov	%o0, %g1
	add	%g5, CPU_TSBDS_CTXN, %g2
1:
	/* check pagesize - accept any size encoding? XXX */
	/* XXX pageszidx is lowest-order bit of pageszmask */
	lduh	[%g2 + TSBD_IDXPGSZ_OFF], %g3
	cmp	%g3, NPGSZ
	bgeu,pn	%xcc, herr_badpgsz
	nop
	/* check associativity - only support 1-way */
	lduh	[%g2 + TSBD_ASSOC_OFF], %g3
	cmp	%g3, 1
	bne,pn	%icc, herr_badtsb
	nop
	/* check TSB size */
	ld	[%g2 + TSBD_SIZE_OFF], %g3
	sub	%g3, 1, %g4
	btst	%g3, %g4
	bnz,pn	%icc, herr_badtsb
	mov	TSB_SZ0_ENTRIES, %g4
	cmp	%g3, %g4
	blt,pn	%icc, herr_badtsb
	sll	%g4, TSB_MAX_SZCODE, %g4
	cmp	%g3, %g4
	bgt,pn	%icc, herr_badtsb
	nop
	/* check context index field - must be -1 (shared) or zero */
	ld	[%g2 + TSBD_CTX_INDEX], %g3
	cmp	%g3, TSBD_CTX_IDX_SHARE
	be	%icc, 2f	! -1 is OK
	nop
	brnz,pn	%g3, herr_inval	! only one set of context regs
	nop
2:
	/* check reserved field - must be zero for now */
	ldx	[%g2 + TSBD_RSVD_OFF], %g3
	brnz,pn	%g3, herr_inval
	nop
	/* check TSB base real address */
	ldx	[%g2 + TSBD_BASE_OFF], %g3
	ld	[%g2 + TSBD_SIZE_OFF], %g4
	sllx	%g4, TSBE_SHIFT, %g4
	RANGE_CHECK(%g6, %g3, %g4, herr_noraddr, %g7)
	/* range OK, check alignment */
	sub	%g4, 1, %g4
	btst	%g3, %g4
	bnz,pn	%xcc, herr_badalign
	sub	%g1, 1, %g1
	brnz,pt	%g1, 1b
	add	%g2, TSBD_BYTES, %g2

	/* now setup H/W TSB regs */
	/* only look at first two TSBDs for now */
	add	%g5, CPU_TSBDS_CTXN, %g2
	ldx	[%g2 + TSBD_BASE_OFF], %g1
	REAL_OFFSET(%g6, %g1, %g1, %g4)
	ld	[%g2 + TSBD_SIZE_OFF], %g4
	srl	%g4, TSB_SZ0_SHIFT, %g4
1:
	btst	1, %g4
	srl	%g4, 1, %g4
	bz,a,pt	%icc, 1b
	  add	%g1, 1, %g1	! increment TSB size field

	stxa	%g1, [%g0]ASI_DTSBBASE_CTXN_PS0
	stxa	%g1, [%g0]ASI_ITSBBASE_CTXN_PS0

	lduh	[%g2 + TSBD_IDXPGSZ_OFF], %g3
	stxa	%g3, [%g0]ASI_DTSB_CONFIG_CTXN ! (PS0 only)
	stxa	%g3, [%g0]ASI_ITSB_CONFIG_CTXN ! (PS0 only)

	/* process second TSBD, if available */
	cmp	%o0, 1
	be,pt	%xcc, 2f
	add	%g2, TSBD_BYTES, %g2	! move to next TSBD
	ldx	[%g2 + TSBD_BASE_OFF], %g1
	REAL_OFFSET(%g6, %g1, %g1, %g4)
	ld	[%g2 + TSBD_SIZE_OFF], %g4
	srl	%g4, TSB_SZ0_SHIFT, %g4
1:
	btst	1, %g4
	srl	%g4, 1, %g4
	bz,a,pt	%icc, 1b
	  add	%g1, 1, %g1	! increment TSB size field

	stxa	%g1, [%g0]ASI_DTSBBASE_CTXN_PS1
	stxa	%g1, [%g0]ASI_ITSBBASE_CTXN_PS1

	/* %g3 still has old CONFIG value. */
	lduh	[%g2 + TSBD_IDXPGSZ_OFF], %g7
	sllx	%g7, ASI_TSB_CONFIG_PS1_SHIFT, %g7
	or	%g3, %g7, %g3
	stxa	%g3, [%g0]ASI_DTSB_CONFIG_CTXN ! (PS0 + PS1)
	stxa	%g3, [%g0]ASI_ITSB_CONFIG_CTXN ! (PS0 + PS1)

2:
	stx	%o0, [%g5 + CPU_NTSBS_CTXN]
setntsbsN:
	clr	%o1	! no return value
	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_tsb_ctxnon0)


/*
 * mmu_tsb_ctx0_info
 *
 * arg0 maxtsbs (%o0)
 * arg1 tsbs (%o1)
 * --
 * ret0 status (%o0)
 * ret1 ntsbs (%o1)
 */
	ENTRY_NP(hcall_mmu_tsb_ctx0_info)
	CPU_GUEST_STRUCT(%g5, %g6)
	!! %g5 cpup
	!! %g6 guestp

	! actual ntsbs always returned in %o1, so save tsbs now
	mov	%o1, %g4
	! Check to see if ntsbs fits into the supplied buffer
	ldx	[%g5 + CPU_NTSBS_CTX0], %o1
	brz,pn	%o1, hret_ok
	cmp	%o1, %o0
	bgu,pn	%xcc, herr_inval
	nop

	btst	TSBD_ALIGNMENT - 1, %g4
	bnz,pn	%xcc, herr_badalign
	sllx	%o1, TSBD_SHIFT, %g3
	!! %g3 size of tsbd in bytes
	RANGE_CHECK(%g6, %g4, %g3, herr_noraddr, %g2)
	REAL_OFFSET(%g6, %g4, %g2, %g1)
	!! %g2 pa of buffer
	!! xcopy(cpu->tsbds, buffer, ntsbs*TSBD_BYTES)
	add	%g5, CPU_TSBDS_CTX0, %g1
	!! clobbers %g1-%g4
	ba	xcopy
	rd	%pc, %g7

	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_tsb_ctx0_info)


/*
 * mmu_tsb_ctxnon0_info
 *
 * arg0 maxtsbs (%o0)
 * arg1 tsbs (%o1)
 * --
 * ret0 status (%o0)
 * ret1 ntsbs (%o1)
 */
	ENTRY_NP(hcall_mmu_tsb_ctxnon0_info)
	CPU_GUEST_STRUCT(%g5, %g6)
	!! %g5 cpup
	!! %g6 guestp

	! actual ntsbs always returned in %o1, so save tsbs now
	mov	%o1, %g4
	! Check to see if ntsbs fits into the supplied buffer
	ldx	[%g5 + CPU_NTSBS_CTXN], %o1
	brz,pn	%o1, hret_ok
	cmp	%o1, %o0
	bgu,pn	%xcc, herr_inval
	nop

	btst	TSBD_ALIGNMENT - 1, %g4
	bnz,pn	%xcc, herr_badalign
	sllx	%o1, TSBD_SHIFT, %g3
	!! %g3 size of tsbd in bytes
	RANGE_CHECK(%g6, %g4, %g3, herr_noraddr, %g2)
	REAL_OFFSET(%g6, %g4, %g2, %g1)
	!! %g2 pa of buffer
	!! xcopy(cpu->tsbds, buffer, ntsbs*TSBD_BYTES)
	add	%g5, CPU_TSBDS_CTXN, %g1
	!! clobbers %g1-%g4
	ba	xcopy
	rd	%pc, %g7

	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_tsb_ctxnon0_info)


/*
 * mmu_map_addr - stuff ttes directly into the tlbs
 *
 * arg0 vaddr (%o0)
 * arg1 ctx (%o1)
 * arg2 tte (%o2)
 * arg3 flags (%o3)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_mmu_map_addr)
	CPU_GUEST_STRUCT(%g1, %g6)

#ifdef STRICT_API
	CHECK_VA_CTX(%o0, %o1, herr_inval, %g2)
	CHECK_MMU_FLAGS(%o3, herr_inval)
#endif /* STRICT_API */

	! extract sz from tte
	TTE_SIZE(%o2, %g4, %g2, herr_badpgsz)
	sub	%g4, 1, %g5	! %g5 page mask

	! extract ra from tte
	sllx	%o2, 64 - 40, %g2
	srlx	%g2, 64 - 40 + 13, %g2
	sllx	%g2, 13, %g2	! %g2 real address
	xor	%o2, %g2, %g3	! %g3 orig tte with ra field zeroed
	andn	%g2, %g5, %g2
	RANGE_CHECK(%g6, %g2, %g4, 3f, %g5)
	REAL_OFFSET(%g6, %g2, %g2, %g4)
4:	or	%g3, %g2, %g1	! %g1 new tte with pa

#ifndef STRICT_API
	set	(NCTXS - 1), %g3
	and	%o1, %g3, %o1
	andn	%o0, %g3, %o0
#endif /* STRICT_API */
	or	%o0, %o1, %g2	! %g2 tag
	mov	MMU_TAG_ACCESS, %g3 ! %g3 tag_access
	mov	1, %g4
	sllx	%g4, NI_TTE4V_L_SHIFT, %g4
	andn	%g1, %g4, %g1	! %g1 tte (force clear lock bit)
	set	TLB_IN_4V_FORMAT, %g5	! %g5 sun4v-style tte selection

	btst	MAP_DTLB, %o3
	bz	2f
	btst	MAP_ITLB, %o3

	stxa	%g2, [%g3]ASI_DMMU
	membar	#Sync
	stxa	%g1, [%g5]ASI_DTLB_DATA_IN
	! condition codes still set
2:	bz	1f
	nop

	stxa	%g2, [%g3]ASI_IMMU
	membar	#Sync
	stxa	%g1, [%g5]ASI_ITLB_DATA_IN

1:	HCALL_RET(EOK)

	! Check for I/O
3:
	RANGE_CHECK_IO(%g6, %g2, %g4, .hcall_mmu_map_addr_io_found,
	    .hcall_mmu_map_addr_io_not_found, %g1, %g5)
.hcall_mmu_map_addr_io_found:
	ba,a	4b
.hcall_mmu_map_addr_io_not_found:
	ba,a	herr_noraddr
	SET_SIZE(hcall_mmu_map_addr)


/*
 * mmu_unmap_addr
 *
 * arg0 vaddr (%o0)
 * arg1 ctx (%o1)
 * arg2 flags (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_mmu_unmap_addr)
#ifdef STRICT_API
	CHECK_VA_CTX(%o0, %o1, herr_inval, %g2)
	CHECK_MMU_FLAGS(%o2, herr_inval)
#endif /* STRICT_API */
	mov	MMU_PCONTEXT, %g1
	set	(NCTXS - 1), %g2	! 8K page mask
	andn	%o0, %g2, %g2
	ldxa	[%g1]ASI_MMU, %g3 ! save current primary ctx
	stxa	%o1, [%g1]ASI_MMU ! switch to new ctx
	btst	MAP_ITLB, %o2
	bz,pn	%xcc, 1f
	  btst	MAP_DTLB, %o2
	stxa	%g0, [%g2]ASI_IMMU_DEMAP
1:	bz,pn	%xcc, 2f
	  nop
	stxa	%g0, [%g2]ASI_DMMU_DEMAP
2:	stxa	%g3, [%g1]ASI_MMU !  restore original primary ctx
	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_unmap_addr)


/*
 * mmu_demap_page
 *
 * arg0/1 cpulist (%o0/%o1)
 * arg2 vaddr (%o2)
 * arg3 ctx (%o3)
 * arg4 flags (%o4)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_mmu_demap_page)
	orcc	%o0, %o1, %g0
	bnz,pn	%xcc, herr_notsupported ! cpulist not yet supported
#ifdef STRICT_API
	nop
	CHECK_VA_CTX(%o2, %o3, herr_inval, %g2)
	CHECK_MMU_FLAGS(%o4, herr_inval)
#endif /* STRICT_API */
	mov	MMU_PCONTEXT, %g1
	set	(NCTXS - 1), %g2
	andn	%o2, %g2, %g2
	ldxa	[%g1]ASI_MMU, %g3
	stxa	%o3, [%g1]ASI_MMU
	btst	MAP_ITLB, %o4
	bz,pn	%xcc, 1f
	  btst	MAP_DTLB, %o4
	stxa	%g0, [%g2]ASI_IMMU_DEMAP
1:	bz,pn	%xcc, 2f
	  nop
	stxa	%g0, [%g2]ASI_DMMU_DEMAP
2:	stxa	%g3, [%g1]ASI_MMU ! restore primary ctx
	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_demap_page)


/*
 * hcall_mmu_demap_ctx
 *
 * arg0/1 cpulist (%o0/%o1)
 * arg2 ctx (%o2)
 * arg3 flags (%o3)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_mmu_demap_ctx)
	orcc	%o0, %o1, %g0
	bnz,pn	%xcc, herr_notsupported ! cpulist not yet supported
#ifdef STRICT_API
	nop
	CHECK_CTX(%o2, herr_inval, %g2)
	CHECK_MMU_FLAGS(%o3, herr_inval)
#endif /* STRICT_API */
	set	TLB_DEMAP_CTX_TYPE, %g3
	mov	MMU_PCONTEXT, %g2
	ldxa	[%g2]ASI_MMU, %g7
	stxa	%o2, [%g2]ASI_MMU
	btst	MAP_ITLB, %o3
	bz,pn	%xcc, 1f
	  btst	MAP_DTLB, %o3
	stxa	%g0, [%g3]ASI_IMMU_DEMAP
1:	bz,pn	%xcc, 2f
	  nop
	stxa	%g0, [%g3]ASI_DMMU_DEMAP
2:	stxa	%g7, [%g2]ASI_MMU ! restore primary ctx
	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_demap_ctx)


/*
 * hcall_mmu_demap_all
 *
 * arg0/1 cpulist (%o0/%o1)
 * arg2 flags (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_mmu_demap_all)
	orcc	%o0, %o1, %g0
	bnz,pn	%xcc, herr_notsupported ! cpulist not yet supported
#ifdef STRICT_API
	nop
	CHECK_MMU_FLAGS(%o2, herr_inval)
#endif /* STRICT_API */
	set	TLB_DEMAP_ALL_TYPE, %g3
	btst	MAP_ITLB, %o2
	bz,pn	%xcc, 1f
	  btst	MAP_DTLB, %o2
	stxa	%g0, [%g3]ASI_IMMU_DEMAP
1:	bz,pn	%xcc, 2f
	  nop
	stxa	%g0, [%g3]ASI_DMMU_DEMAP
2:	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_demap_all)


/*
 * mmu_map_perm_addr
 *
 * arg0 vaddr (%o0)
 * arg1 context (%o1)  must be zero
 * arg2 tte (%o2)
 * arg3 flags (%o3)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_mmu_map_perm_addr)
	brnz,pn	%o1, herr_inval
	CPU_GUEST_STRUCT(%g1, %g6)

	CHECK_VA_CTX(%o0, %o1, herr_inval, %g2)
	CHECK_MMU_FLAGS(%o3, herr_inval)

	! Fail if tte isn't valid
	brgez,pn %o2, herr_inval
	nop

	! extract sz from tte
	TTE_SIZE(%o2, %g4, %g2, herr_badpgsz)
	sub	%g4, 1, %g5	! %g5 page mask

	! Fail if page-offset bits aren't zero
	btst	%g5, %o0
	bnz,pn	%xcc, herr_inval
	.empty

	! extract ra from tte
	sllx	%o2, 64 - 40, %g2
	srlx	%g2, 64 - 40 + 13, %g2
	sllx	%g2, 13, %g2	! %g2 real address
	xor	%o2, %g2, %g3	! %g3 orig tte with ra field zeroed
	andn	%g2, %g5, %g2
	RANGE_CHECK(%g6, %g2, %g4, herr_noraddr, %g5)
	REAL_OFFSET(%g6, %g2, %g2, %g4)
	or	%g3, %g2, %g2	! %g2 new tte with pa
	!! %g2 = swizzled tte

	add	%g6, GUEST_PERM_MAPPINGS_LOCK, %g1
	SPINLOCK_ENTER(%g1, %g3, %g4)

	/* Search for existing perm mapping */
	add	%g6, GUEST_PERM_MAPPINGS, %g1
	mov	((NPERMMAPPINGS - 1) * MAPPING_SIZE), %g3
	mov	0, %g4

	/*
	 * for (i = NPERMMAPPINGS - 1; i >= 0; i--) {
	 *	if (!table[i]->tte.v) {
	 *		saved_entry = &table[i];  // free entry
	 *		continue;
	 *	}
	 *	if (table[i]->va == va) {
	 *		saved_entry = &table[i];  // matching entry
	 *		break;
	 *	}
	 * }
	 */
.pmap_loop:
	!! %g1 = permanent mapping table base address
	!! %g3 = current offset into table
	!! %g4 = last free entry / saved_entry
	add	%g1, %g3, %g5
	ldx	[%g5 + MAPPING_TTE], %g6

	/*
	 * if (!tte.v) {
	 *	saved_entry = current_entry;
	 *	continue;
	 * }
	 */
	brgez,a,pt %g6, .pmap_continue
	  mov	%g5, %g4

	/*
	 * if (m->va == va) {
	 *	saved_entry = current_entry;
	 *	break;
	 * }
	 *
	 * NB: overlapping mappings not detected, behavior
	 * is undefined right now.   The hardware will demap
	 * when we insert and a TLB error later could reinstall
	 * both in some order where the end result is different
	 * than the post-map-perm result.
	 */
	ldx	[%g5 + MAPPING_VA], %g6
	cmp	%g6, %o0
	be,a,pt	%xcc, .pmap_break
	  mov	%g5, %g4

.pmap_continue:
	deccc	GUEST_PERM_MAPPINGS_INCR, %g3
	bgeu,pt	%xcc, .pmap_loop
	nop

.pmap_break:
	!! %g4 = saved_entry

	/*
	 * if (saved_entry == NULL)
	 *	return (ETOOMANY);
	 */
	brz,a,pn %g4, .pmap_return
	  mov	ETOOMANY, %o0

	/*
	 * if (saved_entry->tte.v)
	 *	existing entry to modify
	 * else
	 *	free entry to fill in
	 */
	ldx	[%g4 + MAPPING_TTE], %g5
	brgez,pn %g5, .pmap_free_entry
	nop

	/*
	 * Compare new tte with existing tte
	 */
	cmp	%o2, %g5
	bne,a,pn %xcc, .pmap_return
	   mov	EINVAL, %o0

.pmap_existing_entry:
	CPU_STRUCT(%g1)
	ldub	[%g1 + CPU_PID], %g1
	mov	1, %g3
	sllx	%g3, %g1, %g1
	!! %g1 = (1 << CPU->pid)

	/*
	 * if (flags & I) {
	 *	if (saved_entry->icpuset & (1 << curcpu))
	 *		return (EINVAL);
	 * }
	 */
	btst	MAP_ITLB, %o3
	bz,pn	%xcc, 1f
	nop
	lduw	[%g4 + MAPPING_ICPUSET], %g5
	btst	%g1, %g5
	bnz,a,pn %xcc, .pmap_return
	  mov	EINVAL, %o0
1:
	/*
	 * if (flags & D) {
	 *	if (saved_entry->dcpuset & (1 << curcpu))
	 *		return (EINVAL);
	 * }
	 */
	btst	MAP_DTLB, %o3
	bz,pn	%xcc, 2f
	nop
	lduw	[%g4 + MAPPING_DCPUSET], %g5
	btst	%g1, %g5
	bnz,a,pn %xcc, .pmap_return
	  mov	EINVAL, %o0
2:
	ba,pt	%xcc, .pmap_finish
	nop

.pmap_free_entry:
	/*
	 * m->va = va;
	 * m->tte = tte;
	 */
	stx	%o0, [%g4 + MAPPING_VA]
	stx	%o2, [%g4 + MAPPING_TTE]

.pmap_finish:
	CPU_STRUCT(%g1)
	ldub	[%g1 + CPU_PID], %g3
	mov	1, %g1
	sllx	%g1, %g3, %g1
	!! %g1 = (1 << CPU->pid)
	!! %g3 = pid

	/*
	 * if (flags & I)
	 *	if ((m->icpuset >> (CPU2COREID(curcpu) * 4)) & 0xf)
	 *		flags &= ~I;
	 *	m->icpuset |= (1 << CPU->pid);
	 * }
	 */
	btst	MAP_ITLB, %o3
	bz,pn	%xcc, 3f
	nop

	/*
	 * If other strands on this core already have this mapping
	 * in the iTLB then do not map it again.
	 */
	lduw	[%g4 + MAPPING_ICPUSET], %g5
	PCPUID2COREID(%g3, %g6)
	sllx	%g6, CPUID_2_COREID_SHIFT, %g6	! %g6 * NSTRANDSPERCORE
	srlx	%g5, %g6, %g7
	btst	CORE_MASK, %g7
	bnz,a,pt %xcc, 0f
	  andn	%o3, MAP_ITLB, %o3
0:
	or	%g5, %g1, %g5
	stw	%g5, [%g4 + MAPPING_ICPUSET]
3:

	/*
	 * if (flags & D) {
	 *	if ((m->dcpuset >> (CPU2COREID(curcpu) * 4)) & 0xf)
	 *		flags &= ~D;
	 *	m->dcpuset |= (1 << CPU->pid);
	 * }
	 */
	btst	MAP_DTLB, %o3
	bz,pn	%xcc, 4f
	nop

	/*
	 * If other strands on this core already have this mapping
	 * in the dTLB then do not map it again.
	 */
	lduw	[%g4 + MAPPING_DCPUSET], %g5
	PCPUID2COREID(%g3, %g6)
	sllx	%g6, CPUID_2_COREID_SHIFT, %g6	! %g6 * NSTRANDSPERCORE
	srlx	%g5, %g6, %g7
	btst	CORE_MASK, %g7
	bnz,a,pt %xcc, 0f
	  andn	%o3, MAP_DTLB, %o3
0:
	or	%g5, %g1, %g5
	stw	%g5, [%g4 + MAPPING_DCPUSET]
4:
#ifdef NIAGARA_ERRATUM_40
	/*
	 * Use entry # in guest's permanent mapping table as position
	 * in tlb, guarantees idx 63 not used (Niagara erratum 40).
	 * We divide the tlb into 8 sets of 8 permanent mappings.
	 * The guest's partid selects the set of 8.
	 *
	 * NB: partid 7 is not supported.
	 */
	GUEST_STRUCT(%g6)
	ldx	[%g6 + GUEST_PARTID], %g1
	inc	GUEST_PERM_MAPPINGS_LOCK, %g6
	sub	%g4, %g6, %g6
	udivx	%g6, MAPPING_SIZE, %g6
	!! %g6 = tlb index #

	sllx	%g1, 3, %g1	! partid * NPERMMAPPINGS
	add	%g6, %g1, %g6	! tlbindex# + (partid * 8)

	sllx	%g6, 3, %g6
	!! %g6 = ASI_TLB_ACCESS va
#endif
	mov	%g2, %g1	! put tte back in %g1

	mov	MMU_TAG_ACCESS, %g3
	mov	1, %g4
	sllx	%g4, NI_TTE4V_L_SHIFT, %g4
	or	%g1, %g4, %g1	! add lock bit

	/*
	 * Map in TLB
	 */
	set	TLB_IN_4V_FORMAT, %g5	! sun4v-style tte selection
	btst	MAP_ITLB, %o3
	bz,pn	%xcc, 1f
	  btst	MAP_DTLB, %o3
	stxa	%o0, [%g3]ASI_IMMU
	membar	#Sync
#ifdef NIAGARA_ERRATUM_40
	!! %g6 still contains ASI_TLB_ACCESS va
	stxa	%g1, [%g5 + %g6]ASI_ITLB_DATA_ACC
#else
	stxa	%g1, [%g5]ASI_ITLB_DATA_IN
#endif
	membar	#Sync
	! condition codes still set
1:	bz,pn	%xcc, 2f
	  nop
	stxa	%o0, [%g3]ASI_DMMU
	membar	#Sync
#ifdef NIAGARA_ERRATUM_40
	!! %g6 still contains ASI_TLB_ACCESS va
	stxa	%g1, [%g5 + %g6]ASI_DTLB_DATA_ACC
#else
	stxa	%g1, [%g5]ASI_DTLB_DATA_IN
#endif
	membar	#Sync
2:
	mov	EOK, %o0

.pmap_return:
	GUEST_STRUCT(%g1)
	inc	GUEST_PERM_MAPPINGS_LOCK, %g1
	SPINLOCK_EXIT(%g1)
	done
	SET_SIZE(hcall_mmu_map_perm_addr)


/*
 * mmu_unmap_perm_addr
 *
 * arg0 vaddr (%o0)
 * arg1 ctx (%o1)
 * arg2 flags (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_mmu_unmap_perm_addr)
	brnz,pn	%o1, herr_inval
	nop
	CHECK_VA_CTX(%o0, %o1, herr_inval, %g2)
	CHECK_MMU_FLAGS(%o2, herr_inval)

	/*
	 * Search for existing perm mapping
	 */
	GUEST_STRUCT(%g6)
	add	%g6, GUEST_PERM_MAPPINGS, %g1
	mov	((NPERMMAPPINGS - 1) * MAPPING_SIZE), %g3
	mov	0, %g4

	add	%g6, GUEST_PERM_MAPPINGS_LOCK, %g2
	SPINLOCK_ENTER(%g2, %g5, %g6)

	/*
	 * for (i = NPERMMAPPINGS - 1; i >= 0; i--) {
	 *	if (!table[i]->tte.v)
	 *		continue;
	 *	if (table[i]->va == va)
	 *		break;
	 * }
	 */
.punmap_loop:
	!! %g1 = permanent mapping table base address
	!! %g3 = current offset into table
	!! %g4 = last free entry / saved_entry
	add	%g1, %g3, %g5
	ldx	[%g5 + MAPPING_TTE], %g6

	/*
	 * if (!m->tte.v)
	 *	continue;
	 */
	brgez,pt %g6, .punmap_continue
	nop

	/*
	 * if (m->va == va)
	 *	break;
	 */
	ldx	[%g5 + MAPPING_VA], %g6
	cmp	%g6, %o0
	be,pt	%xcc, .punmap_break
	nop

.punmap_continue:
	deccc	GUEST_PERM_MAPPINGS_INCR, %g3
	bgeu,pt	%xcc, .punmap_loop
	nop

.punmap_break:
	!! %g5 = entry in mapping table

	/*
	 * if (i < 0)
	 *	return (EINVAL);
	 */
	brlz,a,pn %g3, .punmap_return
	  mov	ENOMAP, %o0

	CPU_STRUCT(%g1)
	ldub	[%g1 + CPU_PID], %g3
	mov	1, %g1
	sllx	%g1, %g3, %g1
	!! %g1 = (1 << CPU->pid)
	!! %g3 = pid
	!! %g5 = entry in mapping table

	/*
	 * if (flags & MAP_I) {
	 *	m->cpuset_i &= ~(1 << curcpu);
	 *	if ((m->cpuset_i >> (CPU2COREID(curcpu) * 4)) & 0xf)
	 *		flags &= ~MAP_I;
	 * }
	 */
	btst	MAP_ITLB, %o2
	bz,pn	%xcc, 1f
	nop

	lduw	[%g5 + MAPPING_ICPUSET], %g2
	andn	%g2, %g1, %g2
	stw	%g2, [%g5 + MAPPING_ICPUSET]

	/*
	 * If other strands on this core are still using this entry
	 * in the iTLB then do not unmap it.
	 */
	PCPUID2COREID(%g3, %g4)
	sllx	%g4, 2, %g4
	srlx	%g2, %g4, %g2
	btst	CORE_MASK, %g2
	bnz,a,pt %xcc, 1f
	  andn	%o2, MAP_ITLB, %o2
1:
	/*
	 * if (flags & MAP_D) {
	 *	m->cpuset_d &= ~(1 << curcpu);
	 *	if ((m->cpuset_d >> (CPU2COREID(curcpu) * 4)) & 0xf)
	 *		flags &= ~MAP_D;
	 * }
	 */
	btst	MAP_DTLB, %o2
	bz,pn	%xcc, 2f
	nop

	lduw	[%g5 + MAPPING_DCPUSET], %g2
	andn	%g2, %g1, %g2
	stw	%g2, [%g5 + MAPPING_DCPUSET]

	/*
	 * If other strands on this core are still using this entry
	 * in the dTLB then do not unmap it.
	 */
	PCPUID2COREID(%g3, %g4)
	sllx	%g4, 2, %g4
	srlx	%g2, %g4, %g2
	btst	CORE_MASK, %g2
	bnz,a,pt %xcc, 2f
	  andn	%o2, MAP_DTLB, %o2
2:
	/*
	 * if (m->cpuset_d == 0 && m->cpuset_i == 0) {
	 *	m->va = 0;
	 *	m->tte = 0;
	 * }
	 */
	lduw	[%g5 + MAPPING_DCPUSET], %g1
	lduw	[%g5 + MAPPING_ICPUSET], %g2
	orcc	%g1, %g2, %g0
	bnz,pt	%xcc, 3f
	nop

	stx	%g0, [%g5 + MAPPING_VA]
	stx	%g0, [%g5 + MAPPING_TTE]
3:
	/*
	 * Unmap hardware TLB entries
	 */
	mov	MMU_PCONTEXT, %g1
	ldxa	[%g1]ASI_MMU, %g3 ! save current primary ctx
	stxa	%o1, [%g1]ASI_MMU ! switch to new ctx
	btst	MAP_ITLB, %o2
	bz,pn	%xcc, 1f
	  btst	MAP_DTLB, %o2
	stxa	%g0, [%o0]ASI_IMMU_DEMAP
1:	bz,pn	%xcc, 2f
	  nop
	stxa	%g0, [%o0]ASI_DMMU_DEMAP
2:	stxa	%g3, [%g1]ASI_MMU !  restore original primary ctx

	mov	EOK, %o0

.punmap_return:
	GUEST_STRUCT(%g1)
	inc	GUEST_PERM_MAPPINGS_LOCK, %g1
	SPINLOCK_EXIT(%g1)
	done
	SET_SIZE(hcall_mmu_unmap_perm_addr)


#ifdef DEBUG /* { */

/*
 * mmu_perm_addr_info
 *
 * arg0 buffer (%o0)
 * arg1 nentries (%o1)
 * --
 * ret0 status (%o0)
 * ret1 nentries (%o1)
 */
	ENTRY_NP(hcall_mmu_perm_addr_info)
	GUEST_STRUCT(%g7)
	!! %g7 guestp

	! Check to see if table fits into the supplied buffer
	cmp	%o1, NPERMMAPPINGS
	blu,pn	%xcc, herr_inval
	mov	NPERMMAPPINGS, %o1

	btst	3, %o0
	bnz,pn	%xcc, herr_badalign
	mulx	%o1, PERMMAPINFO_BYTES, %g3
	!! %g3 size of permmap table in bytes
	RANGE_CHECK(%g7, %o0, %g3, herr_noraddr, %g2)
	REAL_OFFSET(%g7, %o0, %g2, %g1)
	!! %g2 pa of buffer

	add	%g7, GUEST_PERM_MAPPINGS_LOCK, %g1
	SPINLOCK_ENTER(%g1, %g3, %g4)

	/*
	 * Search for valid perm mappings
	 */
	add	%g7, GUEST_PERM_MAPPINGS, %g1
	mov	((NPERMMAPPINGS - 1) * MAPPING_SIZE), %g3
	mov	0, %o1
	add	%g1, %g3, %g4
.perm_info_loop:
	!! %o1 = count of valid entries
	!! %g1 = base of mapping table
	!! %g2 = pa of guest's buffer
	!! %g3 = current offset into table
	!! %g4 = current entry in table
	!! %g7 = guestp
	ldx	[%g4 + MAPPING_TTE], %g5
	brgez,pn %g5, .perm_info_continue
	nop

	/* Found a valid mapping */
	ldx	[%g4 + MAPPING_VA], %g5
	stx	%g5, [%g2 + PERMMAPINFO_VA]
	stx	%g0, [%g2 + PERMMAPINFO_CTX]
	ldx	[%g4 + MAPPING_TTE], %g5
	stx	%g5, [%g2 + PERMMAPINFO_TTE]

#if 0 /* XXX debug, just return the raw sets */
	lduw	[%g4 + MAPPING_ICPUSET], %g5
	lduw	[%g4 + MAPPING_DCPUSET], %o0
	sllx	%g5, 32, %g5
	or	%g5, %o0, %g5
	stx	%g5, [%g2 + PERMMAPINFO_FLAGS]
#else
	CPU_STRUCT(%g5)
	ldub	[%g5 + CPU_PID], %g5
	mov	1, %o0
	sllx	%o0, %g5, %o0
	!! %o0 = curcpu bit mask
	mov	0, %g6
	!! %g6 = flags
	lduw	[%g4 + MAPPING_ICPUSET], %g5
	btst	%g5, %o0
	bnz,a,pt %xcc, 0f
	  or	%g6, MAP_ITLB, %g6
0:	lduw	[%g4 + MAPPING_DCPUSET], %g5
	btst	%g5, %o0
	bnz,a,pt %xcc, 0f
	  or	%g6, MAP_DTLB, %g6
0:	stx	%g6, [%g4 + PERMMAPINFO_FLAGS]
#endif

	inc	%o1
	inc	PERMMAPINFO_BYTES, %g2

.perm_info_continue:
	deccc	GUEST_PERM_MAPPINGS_INCR, %g3
	bgeu,pt	%xcc, .perm_info_loop
	add	%g1, %g3, %g4

	GUEST_STRUCT(%g1)
	inc	GUEST_PERM_MAPPINGS_LOCK, %g1
	SPINLOCK_EXIT(%g1)

	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_perm_addr_info)

#endif /* } DEBUG */


/*
 * qconf
 *
 * arg0 queue (%o0)
 * arg1 base raddr (%o1)
 * arg2 size (#entries, not #bytes) (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_qconf)
	sllx	%o2, Q_EL_SIZE_SHIFT, %g4	! convert #entries to bytes
	CPU_STRUCT(%g1)

	! size of 0 unconfigures queue
	brnz,pt	%o2, 1f
	nop

	/*
	 * Set the stored configuration to relatively safe values
	 * when un-initializing the queue
	 */
	mov	-1, %g2
	mov	-1, %o1
	ba,pt	%xcc, 2f
	mov	0, %g4

1:
	cmp	%o2, MIN_QUEUE_ENTRIES
	blu,pn	%xcc, herr_inval
	.empty

	cmp	%o2, MAX_QUEUE_ENTRIES
	bgu,pn	%xcc, herr_inval
	.empty

	! check that size is a power of two
	sub	%o2, 1, %g2
	andcc	%o2, %g2, %g0
	bnz,pn	%xcc, herr_inval
	.empty

	! Check base raddr alignment
	sub	%g4, 1, %g2	! size in bytes to mask
	btst	%o1, %g2
	bnz,pn	%xcc, herr_badalign
	.empty

	ldx	[%g1 + CPU_GUEST], %g6
	RANGE_CHECK(%g6, %o1, %g4, herr_noraddr, %g2)
	REAL_OFFSET(%g6, %o1, %g2, %g3)

	! %g2 - queue paddr
	! %g4 - queue size (#bytes)
	dec	%g4
	! %g4 - queue mask

2:
	cmp	%o0, CPU_MONDO_QUEUE
	be,pn	%xcc, qconf_cpuq
	cmp	%o0, DEV_MONDO_QUEUE
	be,pn	%xcc, qconf_devq
	cmp	%o0, ERROR_RESUMABLE_QUEUE
	be,pn	%xcc, qconf_errrq
	cmp	%o0, ERROR_NONRESUMABLE_QUEUE
	bne,pn	%xcc, herr_inval
	nop

qconf_errnrq:
	stx	%g2, [%g1 + CPU_ERRQNR_BASE]
	stx	%o1, [%g1 + CPU_ERRQNR_BASE_RA]
	stx	%o2, [%g1 + CPU_ERRQNR_SIZE]
	stx	%g4, [%g1 + CPU_ERRQNR_MASK]
	mov	ERROR_NONRESUMABLE_QUEUE_HEAD, %g3
	stxa	%g0, [%g3]ASI_QUEUE
	mov	ERROR_NONRESUMABLE_QUEUE_TAIL, %g3
	ba,pt	%xcc, 4f
	stxa	%g0, [%g3]ASI_QUEUE

qconf_errrq:
	stx	%g2, [%g1 + CPU_ERRQR_BASE]
	stx	%o1, [%g1 + CPU_ERRQR_BASE_RA]
	stx	%o2, [%g1 + CPU_ERRQR_SIZE]
	stx	%g4, [%g1 + CPU_ERRQR_MASK]
	mov	ERROR_RESUMABLE_QUEUE_HEAD, %g3
	stxa	%g0, [%g3]ASI_QUEUE
	mov	ERROR_RESUMABLE_QUEUE_TAIL, %g3
	ba,pt	%xcc, 4f
	stxa	%g0, [%g3]ASI_QUEUE

qconf_devq:
	stx	%g2, [%g1 + CPU_DEVQ_BASE]
	stx	%o1, [%g1 + CPU_DEVQ_BASE_RA]
	stx	%o2, [%g1 + CPU_DEVQ_SIZE]
	stx	%g4, [%g1 + CPU_DEVQ_MASK]
	mov	DEV_MONDO_QUEUE_HEAD, %g3
	stxa	%g0, [%g3]ASI_QUEUE
	mov	DEV_MONDO_QUEUE_TAIL, %g3
	ba,pt	%xcc, 4f
	stxa	%g0, [%g3]ASI_QUEUE

qconf_cpuq:
	stx	%g2, [%g1 + CPU_CPUQ_BASE]
	stx	%o1, [%g1 + CPU_CPUQ_BASE_RA]
	stx	%o2, [%g1 + CPU_CPUQ_SIZE]
	stx	%g4, [%g1 + CPU_CPUQ_MASK]
	mov	CPU_MONDO_QUEUE_HEAD, %g3
	stxa	%g0, [%g3]ASI_QUEUE
	mov	CPU_MONDO_QUEUE_TAIL, %g3
	stxa	%g0, [%g3]ASI_QUEUE

4:
	HCALL_RET(EOK)
	SET_SIZE(hcall_qconf)


/*
 * qinfo
 *
 * arg0 queue (%o0)
 * --
 * ret0 status (%o0)
 * ret1 base raddr (%o1)
 * ret2 size (#entries) (%o2)
 */
	ENTRY_NP(hcall_qinfo)
	CPU_STRUCT(%g1)

	cmp	%o0, CPU_MONDO_QUEUE
	be,pn	%xcc, qinfo_cpuq
	cmp	%o0, DEV_MONDO_QUEUE
	be,pn	%xcc, qinfo_devq
	cmp	%o0, ERROR_RESUMABLE_QUEUE
	be,pn	%xcc, qinfo_errrq
	cmp	%o0, ERROR_NONRESUMABLE_QUEUE
	bne,pn	%xcc, herr_inval
	nop
qinfo_errnrq:
	ldx	[%g1 + CPU_ERRQNR_BASE_RA], %o1
	ba,pt	%xcc, 1f
	ldx	[%g1 + CPU_ERRQNR_SIZE], %o2

qinfo_errrq:
	ldx	[%g1 + CPU_ERRQR_BASE_RA], %o1
	ba,pt	%xcc, 1f
	ldx	[%g1 + CPU_ERRQR_SIZE], %o2

qinfo_devq:
	ldx	[%g1 + CPU_DEVQ_BASE_RA], %o1
	ba,pt	%xcc, 1f
	ldx	[%g1 + CPU_DEVQ_SIZE], %o2

qinfo_cpuq:
	ldx	[%g1 + CPU_CPUQ_BASE_RA], %o1
	ldx	[%g1 + CPU_CPUQ_SIZE], %o2

1:
	HCALL_RET(EOK)
	SET_SIZE(hcall_qinfo)


/*
 * cpu_start
 *
 * arg0 cpu (%o0)
 * arg1 pc (%o1)
 * arg2 rtba (%o2)
 * arg3 arg (%o3)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_cpu_start)
	CPU_GUEST_STRUCT(%g6, %g7)
	!! %g6 = CPU
	!! %g7 = guest

	cmp	%o0, NCPUS
	bgeu,pn	%xcc, herr_nocpu
	nop

	! Check pc (real) and tba (real) for validity
	RANGE_CHECK(%g7, %o1, INSTRUCTION_SIZE, herr_noraddr, %g1)
	RANGE_CHECK(%g7, %o2, REAL_TRAPTABLE_SIZE, herr_noraddr, %g1)
	btst	(INSTRUCTION_ALIGNMENT - 1), %o1	! Check pc alignment
	bnz,pn	%xcc, herr_badalign
	set	REAL_TRAPTABLE_SIZE - 1, %g1
	btst	%o2, %g1
	bnz,pn	%xcc, herr_badalign
	nop

	! Check current state of requested cpu
	sllx	%o0, 3, %g1
	mov	GUEST_VCPUS, %g2
	add	%g1, %g2, %g1	! %g1 = vcpus[n] offset
	ldx	[%g7 + %g1], %g1 ! %g1 = guest.vcpus[n]
	brz,pn	%g1, herr_nocpu
	nop
	!! %g1 requested CPU cpu struct

	ldx	[%g1 + CPU_STATUS], %g2
	cmp	%g2, CPU_STATE_STOPPED
	bne,pn	%xcc, herr_inval
	nop

	/* Check to see if the mailbox is available */
	add	%g1, CPU_COMMAND, %g2
	mov	CPU_CMD_BUSY, %g4
	casxa	[%g2]ASI_P, %g0, %g4
	brnz,pn	%g4, herr_wouldblock
	nop

	stx	%o1, [%g1 + CPU_CMD_ARG0]
	stx	%o2, [%g1 + CPU_CMD_ARG1]
	stx	%o3, [%g1 + CPU_CMD_ARG2]
#ifdef RESETCONFIG_BROKENTICK
	rdpr	%tick, %g2
	stx	%g2, [%g1 + CPU_CMD_ARG3]
#endif

	membar	#StoreStore
	mov	CPU_CMD_STARTGUEST, %g2
	stx	%g2, [%g1 + CPU_COMMAND]

	HCALL_RET(EOK)
	SET_SIZE(hcall_cpu_start)


/*
 * cpu_stop
 *
 * arg0 cpu (%o0)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_cpu_stop)
	HCALL_RET(EBADTRAP)	/* XXX */
	SET_SIZE(hcall_cpu_stop)

/*
 * cpu_state
 *
 * arg0 cpu (%o0)
 * --
 * ret0 status (%o0)
 * ret1 state (%o1)
 */
	ENTRY_NP(hcall_cpu_state)
	GUEST_STRUCT(%g1)
	VCPUID2CPUP(%g1, %o0, %g2, herr_nocpu, %g3)
	!! %g2 = target cpup

	ldx	[%g2 + CPU_STATUS], %o1
	! ASSERT(%o1 != CPU_STATE_INVALID)
	cmp	%o1, CPU_STATE_LAST_PUBLIC
	movgu	%xcc, CPU_STATE_ERROR, %o1	! Any non-API state is ERROR
	HCALL_RET(EOK)
	SET_SIZE(hcall_cpu_state)


/*
 * hcall_mem_scrub
 *
 * arg0 real address (%o0)
 * arg1 length       (%o1)
 * --
 * ret0 status (%o0)
 *   EOK       : success or partial success
 *   ENORADDR  : invalid (bad) address
 *   EBADALIGN : bad alignment
 * ret1 length scrubbed (%o1)
 */
	ENTRY_NP(hcall_mem_scrub)
	brz,pn	%o1, herr_inval			! length 0 invalid
	or	%o0, %o1, %g1			! address and length
	btst	L2_LINE_SIZE - 1, %g1		!    aligned?
	bnz,pn	%xcc, herr_badalign		! no: error
	  nop

        CPU_GUEST_STRUCT(%g6, %g5)

	/* Check input arguments with guest map: error ret: r0=ENORADDR */
	RANGE_CHECK(%g5, %o0, %o1, herr_noraddr, %g1)
	REAL_OFFSET(%g5, %o0, %o0, %g1)	/* real => physical address */

	/* Get Max length: */
	ldx	[%g6 + CPU_ROOT], %g2		! root (config) struct
	ldx	[%g2 + CONFIG_MEMSCRUB_MAX], %g5 ! limit (# cache lines)

	/* Compute max # lines: */
	srlx	%o1, L2_LINE_SHIFT, %g2		! # input cache lines
	cmp	%g5, %g2			! g2 = min(inp, max)
	movlu	%xcc, %g5, %g2			!	..
	sllx	%g2, L2_LINE_SHIFT, %o1		! ret1 = count scrubbed

	/*
	 * This is the core of this function.
	 * All of the code before and after has been optimized to make this
	 *   and the most common path the fastest.
	 */
	wr	%g0, ASI_BLK_INIT_P, %asi
.ms_clear_mem:
	stxa	%g0, [%o0 + (0 * 8)]%asi
	stxa	%g0, [%o0 + (1 * 8)]%asi
	stxa	%g0, [%o0 + (2 * 8)]%asi
	stxa	%g0, [%o0 + (3 * 8)]%asi
	stxa	%g0, [%o0 + (4 * 8)]%asi
	stxa	%g0, [%o0 + (5 * 8)]%asi
	stxa	%g0, [%o0 + (6 * 8)]%asi
	stxa	%g0, [%o0 + (7 * 8)]%asi
	deccc	1, %g2
	bnz,pt	%xcc, .ms_clear_mem
	  inc	64, %o0
	HCALL_RET(EOK)				! ret0=status, ret1=count
	SET_SIZE(hcall_mem_scrub)


/*
 * hcall_mem_sync
 *
 * arg0 real address (%o0)
 * arg1 length       (%o1)
 * --
 * ret0 (%o0):
 *   EOK       : success, partial success
 *   ENORADDR  : bad address
 *   EBADALIGN : bad alignment
 * ret1 (%o1):
 *   length synced
 */
	ENTRY_NP(hcall_mem_sync)
	brz,pn	%o1, herr_inval		! len 0 not valid
	or	%o0, %o1, %g2
	set	MEMSYNC_ALIGNMENT - 1, %g3
	btst	%g3, %g2	! check for alignment of addr/len
	bnz,pn	%xcc, herr_badalign
	.empty

	CPU_STRUCT(%g5)
	RANGE_CHECK(%g5, %o0, %o1, herr_noraddr, %g1)
	REAL_OFFSET(%g5, %o0, %o0, %g1)	/* real => physical address ? */
	!! %o0 pa
	!! %o1 length

	/*
	 * Clamp requested length at MEMSCRUB_MAX
	 */
	ldx	[%g5 + CPU_ROOT], %g2
	ldx	[%g2 + CONFIG_MEMSCRUB_MAX], %g3
	sllx	%g3, L2_LINE_SHIFT, %g3
	cmp	%o1, %g3
	movgu	%xcc, %g3, %o1
	!! %o1 MIN(requested length, max length)

	/*
	 * Push cache lines to memory
	 */
	sub	%o1, L2_LINE_SIZE, %o5
	!! %o5 loop counter
	add	%o0, %o5, %g1	! hoisted delay slot (see below)
1:
	ba	l2_flush_line
	  rd	%pc, %g7
	deccc	L2_LINE_SIZE, %o5 ! get to next line
	bgeu,pt	%xcc, 1b
	  add	%o0, %o5, %g1	! %g1 is pa to flush

	HCALL_RET(EOK)
	SET_SIZE(hcall_mem_sync)


/*
 * intr_devino2sysino
 *
 * arg0 dev handle [dev config pa] (%o0)
 * arg1 devino (%o1)
 * --
 * ret0 status (%o0)
 * ret1 sysino (%o1)
 *
 */
	ENTRY_NP(hcall_intr_devino2sysino)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_DEVINO2VINO, %g1, %g2, %g3, \
	    herr_inval)
	SET_SIZE(hcall_intr_devino2sysino)

/*
 * intr_getenabled
 *
 * arg0 sysino (%o0)
 * --
 * ret0 status (%o0)
 * ret1 intr valid state (%o1)
 */
	ENTRY_NP(hcall_intr_getenabled)
	JMPL_VINO2DEVOP(%o0, DEVOPSVEC_GETVALID, %g1, %g2, herr_inval)
	SET_SIZE(hcall_intr_getenabled)

/*
 * intr_setenabled
 *
 * arg0 sysino (%o0)
 * arg1 intr valid state (%o1) 1: Valid 0: Invalid
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_intr_setenabled)
	cmp	%o1, INTR_ENABLED_MAX_VALUE
	bgu,pn	%xcc, herr_inval
	nop
	JMPL_VINO2DEVOP(%o0, DEVOPSVEC_SETVALID, %g1, %g2, herr_inval)
	SET_SIZE(hcall_intr_setenabled)

/*
 * intr_getstate
 *
 * arg0 sysino (%o0)
 * --
 * ret0 status (%o0)
 * ret1 (%o1) 0: idle 1: received 2: delivered
 */
	ENTRY_NP(hcall_intr_getstate)
	JMPL_VINO2DEVOP(%o0, DEVOPSVEC_GETSTATE, %g1, %g2, herr_inval)
	SET_SIZE(hcall_intr_getstate)

/*
 * intr_setstate
 *
 * arg0 sysino (%o0)
 * arg1 (%o1) 0: idle 1: received 2: delivered
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_intr_setstate)
	JMPL_VINO2DEVOP(%o0, DEVOPSVEC_SETSTATE, %g1, %g2, herr_inval)
	SET_SIZE(hcall_intr_setstate)

/*
 * intr_gettarget
 *
 * arg0 sysino (%o0)
 * --
 * ret0 status (%o0)
 * ret1 cpuid (%o1)
 */
	ENTRY_NP(hcall_intr_gettarget)
	JMPL_VINO2DEVOP(%o0, DEVOPSVEC_GETTARGET, %g1, %g2, herr_inval)
	SET_SIZE(hcall_intr_gettarget)

/*
 * intr_settarget
 *
 * arg0 sysino (%o0)
 * arg1 cpuid (%o1)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_intr_settarget)
	JMPL_VINO2DEVOP(%o0, DEVOPSVEC_SETTARGET, %g1, %g2, herr_inval)
	SET_SIZE(hcall_intr_settarget)


/*
 * cpu_yield
 *
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_cpu_yield)
#ifdef NIAGARA_ERRATUM_39
	rdhpr	%hver, %g1
	srlx	%g1, VER_MASK_MAJOR_SHIFT, %g1
	and	%g1, VER_MASK_MAJOR_MASK, %g1
	cmp	%g1, 1		! Check for Niagara 1.x
	bleu,pt	%xcc, hret_ok
	nop
#endif
	rd      STR_STATUS_REG, %g1
	! xor ACTIVE to clear it on current strand
	wr      %g1, STR_STATUS_STRAND_ACTIVE, STR_STATUS_REG
	! skid
	nop
	nop
	nop
	nop
	HCALL_RET(EOK)
	SET_SIZE(hcall_cpu_yield)


/*
 * cpu_myid
 *
 * --
 * ret0 status (%o0)
 * ret1 mycpuid (%o1)
 */
	ENTRY_NP(hcall_cpu_myid)
	CPU_STRUCT(%g1)
	ldub	[%g1 + CPU_VID], %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_cpu_myid)


/*
 * hcall_niagara_getperf
 *
 * arg0 JBUS/DRAM performance register ID (%o0)
 * --
 * ret0 status (%o0)
 * ret1 Perf register value (%o1)
 */
	ENTRY_NP(hcall_niagara_getperf)
	! check if JBUS/DRAM perf registers are accessible
	GUEST_STRUCT(%g1)
	set	GUEST_PERFREG_ACCESSIBLE, %g2
	ldx	[%g1 + %g2], %g2
	brz,pn	%g2, herr_noaccess
	.empty

	! check if perfreg within range
	cmp	%o0, NIAGARA_PERFREG_MAX
	bgeu,pn %xcc, herr_inval
	.empty

	set	niagara_perf_paddr_table - niagara_getperf_1, %g2
niagara_getperf_1:
	rd	%pc, %g3
	add	%g2, %g3, %g2
	sllx	%o0, 4, %o0			! table entry offset
	add	%o0, %g2, %g2
	ldx	[%g2], %g3			! get perf reg paddr
	ldx	[%g3], %o1			! read perf reg
	HCALL_RET(EOK)
	SET_SIZE(hcall_niagara_getperf)

/*
 * hcall_niagara_setperf
 *
 * arg0 JBUS/DRAM performance register ID (%o0)
 * arg1 perf register value (%o1)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_niagara_setperf)
	! check if JBUS/DRAM perf registers are accessible
	GUEST_STRUCT(%g1)
	set	GUEST_PERFREG_ACCESSIBLE, %g2
	ldx	[%g1 + %g2], %g2
	brz,pn	%g2, herr_noaccess
	.empty

	! check if perfreg within range
	cmp	%o0, NIAGARA_PERFREG_MAX
	bgeu,pn	%xcc, herr_inval
	.empty

	set	niagara_perf_paddr_table - niagara_setperf_1, %g2
niagara_setperf_1:
	rd	%pc, %g3
	add	%g2, %g3, %g2
	sllx	%o0, 4, %o0			! table entry offset
	add	%o0, %g2, %g2
	ldx	[%g2], %g3			! get perf reg paddr
	ldx	[%g2+8], %g1			! get perf reg write mask
	and	%g1, %o1, %g1
	stx	%g1, [%g3]			! write perf reg
	HCALL_RET(EOK)
	SET_SIZE(hcall_niagara_setperf)

/*
 * Niagara JBUS/DRAM performance register physical address/mask table
 * (order must match performance register ID assignment)
 */
	.section ".text"
	.align	8
niagara_perf_paddr_table:
	.xword	JBI_PERF_CTL, 0xff
	.xword	JBI_PERF_COUNT, 0xffffffffffffffff
	.xword	DRAM_PERF_CTL0, 0xff
	.xword	DRAM_PERF_COUNT0, 0xffffffffffffffff
	.xword	DRAM_PERF_CTL1, 0xff
	.xword	DRAM_PERF_COUNT1, 0xffffffffffffffff
	.xword	DRAM_PERF_CTL2, 0xff
	.xword	DRAM_PERF_COUNT2, 0xffffffffffffffff
	.xword	DRAM_PERF_CTL3, 0xff
	.xword	DRAM_PERF_COUNT3, 0xffffffffffffffff


/*
 * hcall_niagara_mmustat_conf
 *
 * arg0 mmustat buffer ra (%o0)
 * --
 * ret0 status (%o0)
 * ret1 old mmustat buffer ra (%o1)
 */
	ENTRY_NP(hcall_niagara_mmustat_conf)
	btst	MMUSTAT_AREA_ALIGN - 1, %o0	! check alignment
	bnz,pn	%xcc, herr_badalign
	CPU_GUEST_STRUCT(%g1, %g4)
	brz,a,pn %o0, 1f
	  mov	0, %g2
	RANGE_CHECK(%g4, %o0, MMUSTAT_AREA_SIZE, herr_noraddr, %g3)
	REAL_OFFSET(%g4, %o0, %g2, %g3)
1:
	ldx	[%g1 + CPU_MMUSTAT_AREA_RA], %o1
	stx	%o0, [%g1 + CPU_MMUSTAT_AREA_RA]
	stx	%g2, [%g1 + CPU_MMUSTAT_AREA]
	HCALL_RET(EOK)
	SET_SIZE(hcall_niagara_mmustat_conf)

/*
 * hcall_niagara_mmustat_info
 *
 * --
 * ret0 status (%o0)
 * ret1 mmustat buffer ra (%o1)
 */
	ENTRY_NP(hcall_niagara_mmustat_info)
	CPU_STRUCT(%g1)
	ldx	[%g1 + CPU_MMUSTAT_AREA_RA], %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_niagara_mmustat_info)


/*
 * hcall_ra2pa
 *
 * arg0 ra (%o0)
 * --
 * ret0 status (%o0)
 * ret1 pa (%o1)
 */
	ENTRY_NP(hcall_ra2pa)
	GUEST_STRUCT(%g1)
	set	GUEST_DIAGPRIV, %g2
	ldx	[%g1 + %g2], %g2
	brz,pn	%g2, herr_noaccess
	nop

	RANGE_CHECK(%g1, %o0, 1, herr_noraddr, %g2)
	REAL_OFFSET(%g1, %o0, %o1, %g2)

	HCALL_RET(EOK)
	SET_SIZE(hcall_ra2pa)


/*
 * hcall_hexec
 *
 * arg0 physical address of routine to execute (%o0)
 * --
 * ret0 status if noaccess, other SEP (somebody else's problem) (%o0)
 */
	ENTRY_NP(hcall_hexec)
	GUEST_STRUCT(%g1)
	set	GUEST_DIAGPRIV, %g2
	ldx	[%g1 + %g2], %g2
	brz,pn	%g2, herr_noaccess
	nop

	jmp	%o0
	nop
	/* caller executes "done" */
	SET_SIZE(hcall_hexec)


/*
 * dump_buf_update
 *
 * arg0 ra of dump buffer (%o0)
 * arg1 size of dump buffer (%o1)
 * --
 * ret0 status (%o0)
 * ret1 size on success (%o1), min size on EINVAL
 */
	ENTRY_NP(hcall_dump_buf_update)
	GUEST_STRUCT(%g1)

	/*
	 * XXX What locking is required between multiple strands
	 * XXX making simultaneous conf calls?
	 */

	/*
	 * Any error unconfigures any currently configured dump buf
	 * so set to unconfigured now to avoid special error exit code.
	 */
	set	GUEST_DUMPBUF_SIZE, %g4
	stx	%g0, [%g1 + %g4]
	set	GUEST_DUMPBUF_RA, %g4
	stx	%g0, [%g1 + %g4]
	set	GUEST_DUMPBUF_PA, %g4
	stx	%g0, [%g1 + %g4]

	! Size of 0 unconfigures the dump
	brz,pn	%o1, hret_ok
	nop

	set	DUMPBUF_MINSIZE, %g2
	cmp	%o1, %g2
	blu,a,pn %xcc, herr_inval
	  mov	%g2, %o1	! return min size on EINVAL

	! Check alignment
	btst	(DUMPBUF_ALIGNMENT - 1), %o0
	bnz,pn	%xcc, herr_badalign
	  nop

	RANGE_CHECK(%g1, %o0, %o1, herr_noraddr, %g2)
	REAL_OFFSET(%g1, %o0, %g2, %g3)
	!! %g2 pa of dump buffer
	set	GUEST_DUMPBUF_SIZE, %g4
	stx	%o1, [%g1 + %g4]
	set	GUEST_DUMPBUF_RA, %g4
	stx	%o0, [%g1 + %g4]
	set	GUEST_DUMPBUF_PA, %g4
	stx	%g2, [%g1 + %g4]

	! XXX Need to put something in the buffer
#if 0
	CPU_STRUCT(%g5)
	ldx	[%g5 + CPU_ROOT], %g5
	ldx	[%g5 + CONFIG_VERSION], %g1
	! mov	%g2, %g2
	ldx	[%g5 + CONFIG_VERSIONLEN], %g3
	! ASSERT(%g3 <= [GUEST_DUMPBUF_SIZE])
	ba	xcopy
	rd	%pc, %g7
#endif

	HCALL_RET(EOK)
	SET_SIZE(hcall_dump_buf_update)


/*
 * dump_buf_info
 *
 * --
 * ret0 status (%o0)
 * ret1 current dumpbuf ra (%o1)
 * ret2 current dumpbuf size (%o2)
 */
	ENTRY_NP(hcall_dump_buf_info)
	GUEST_STRUCT(%g1)
	set	GUEST_DUMPBUF_SIZE, %g4
	ldx	[%g1 + %g4], %o2
	set	GUEST_DUMPBUF_RA, %g4
	ldx	[%g1 + %g4], %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_dump_buf_info)


/*
 * cpu_mondo_send
 *
 * arg0/1 cpulist (%o0/%o1)
 * arg2 ptr to 64-byte-aligned data to send (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY(hcall_cpu_mondo_send)
	btst	CPULIST_ALIGNMENT - 1, %o1
	bnz,pn	%xcc, herr_badalign
	btst	MONDO_DATA_ALIGNMENT - 1, %o2
	bnz,pn	%xcc, herr_badalign
	nop

	CPU_GUEST_STRUCT(%g3, %g6)
	!! %g3 cpup
	!! %g6 guestp

	sllx	%o0, CPULIST_ENTRYSIZE_SHIFT, %g5

	RANGE_CHECK(%g6, %o1, %g5, herr_noraddr, %g7)
	REAL_OFFSET(%g6, %o1, %g1, %g7)
	!! %g1 cpulistpa
	RANGE_CHECK(%g6, %o2, MONDO_DATA_SIZE, herr_noraddr, %g7)
	REAL_OFFSET(%g6, %o2, %g2, %g5)
	!! %g2 mondopa

	clr	%g4
	!! %g4 true for EWOULDBLOCK
.cpu_mondo_continue:
	!! %g1 pa of current entry in cpulist
	!! %g3 cpup
	!! %g4 ewouldblock flag
	!! %o0 number of entries remaining in the list
	deccc	%o0
	blu,pn	%xcc, .cpu_mondo_break
	nop

	ldsh	[%g1], %g6
	!! %g6 tcpuid
	cmp	%g6, CPULIST_ENTRYDONE
	be,a,pn	%xcc, .cpu_mondo_continue
	  inc	CPULIST_ENTRYSIZE, %g1

	ldx	[%g3 + CPU_GUEST], %g5
	VCPUID2CPUP(%g5, %g6, %g6, herr_nocpu, %g7)
	!! %g6 tcpup

	/* Sending to one's self is not allowed */
	cmp	%g3, %g6	! cpup <?> tcpup
	be,pn	%xcc, herr_inval
	nop

	IS_CPU_IN_ERROR(%g6, %g5)
	be,pn	%xcc, herr_cpuerror
	nop

	/*
	 * Check to see if the recipient's mailbox is available
	 */
	add	%g6, CPU_COMMAND, %g5
	mov	CPU_CMD_BUSY, %g7
	casxa	[%g5]ASI_P, %g0, %g7
	brz,pt	%g7, .cpu_mondo_send_one
	nop

	!! %g1 pa of current entry in cpulist
	!! %g3 cpup
	!! %g4 ewouldblock flag
	!! %g6 tcpup
	!! %o0 number of entries remaining in the list

	/*
	 * If the mailbox isn't available then the queue could
	 * be full.  Poke the target cpu to check if the queue
	 * is still full since we cannot read its head/tail
	 * registers.
	 */
	inc	%g4		! ewouldblock flag

	cmp	%g7, CPU_CMD_GUESTMONDO_READY
	bne,a,pt %xcc, .cpu_mondo_continue
	  inc	CPULIST_ENTRYSIZE, %g1 ! next entry in list

	/*
	 * Only send another if CPU_POKEDELAY ticks have elapsed since the
	 * last poke.
	 */
	ldx	[%g6 + CPU_CMD_LASTPOKE], %g7
	inc	CPU_POKEDELAY, %g7
	rd	%tick, %g5
	cmp	%g5, %g7
	blu,a,pt %xcc, .cpu_mondo_continue
	  inc	CPULIST_ENTRYSIZE, %g1
	stx	%g5, [%g6 + CPU_CMD_LASTPOKE]

	/*
	 * Send the target cpu a dummy vecintr so it checks
	 * to see if the guest removed entries from the queue
	 */
	ldub	[%g6 + CPU_PID], %g7
	sllx	%g7, INT_VEC_DIS_VCID_SHIFT, %g5
	or	%g5, VECINTR_XCALL, %g5
	stxa	%g5, [%g0]ASI_INTR_UDB_W

	ba,pt	%xcc, .cpu_mondo_continue
	  inc	CPULIST_ENTRYSIZE, %g1 ! next entry in list

	/*
	 * Copy the mondo data into the target cpu's incoming buffer
	 */
.cpu_mondo_send_one:
	ldx	[%g2 + 0x00], %g7
	stx	%g7, [%g6 + CPU_CMD_ARG0]
	ldx	[%g2 + 0x08], %g7
	stx	%g7, [%g6 + CPU_CMD_ARG1]
	ldx	[%g2 + 0x10], %g7
	stx	%g7, [%g6 + CPU_CMD_ARG2]
	ldx	[%g2 + 0x18], %g7
	stx	%g7, [%g6 + CPU_CMD_ARG3]
	ldx	[%g2 + 0x20], %g7
	stx	%g7, [%g6 + CPU_CMD_ARG4]
	ldx	[%g2 + 0x28], %g7
	stx	%g7, [%g6 + CPU_CMD_ARG5]
	ldx	[%g2 + 0x30], %g7
	stx	%g7, [%g6 + CPU_CMD_ARG6]
	ldx	[%g2 + 0x38], %g7
	stx	%g7, [%g6 + CPU_CMD_ARG7]
	membar	#Sync
	mov	CPU_CMD_GUESTMONDO_READY, %g7
	stx	%g7, [%g6 + CPU_COMMAND]

	/*
	 * Send a xcall vector interrupt to the target cpu
	 */
	ldub	[%g6 + CPU_PID], %g7
	sllx	%g7, INT_VEC_DIS_VCID_SHIFT, %g5
	or	%g5, VECINTR_XCALL, %g5
	stxa	%g5, [%g0]ASI_INTR_UDB_W

	mov	CPULIST_ENTRYDONE, %g7
	sth	%g7, [%g1]

	ba	.cpu_mondo_continue
	inc	CPULIST_ENTRYSIZE, %g1 ! next entry in list

.cpu_mondo_break:
	brnz,pn	%g4, herr_wouldblock	! If remaining then EAGAIN
	nop
	HCALL_RET(EOK)
	SET_SIZE(hcall_cpu_mondo_send)


#define	TTRACE_RELOC_ADDR(addr, scr0, scr1)	 \
	setx	.+8, scr0, scr1			;\
	rd	%pc, scr0			;\
	sub	scr1, scr0, scr0		;\
	sub	addr, scr0, addr

/*
 * hcal_ttrace_buf_conf
 *
 * arg0 ra of traptrace buffer (%o0)
 * arg1 size of traptrace buffer in entries (%o1)
 * --
 * ret0 status (%o0)
 * ret1 minimum #entries on EINVAL, #entries on success (%o1)
 */
	ENTRY_NP(hcall_ttrace_buf_conf)
	CPU_GUEST_STRUCT(%g1, %g2)

	/*
	 * Disable traptrace by restoring %htba to original traptable
	 * always do this first to make error returns easier.
	 */
	setx	htraptable, %g3, %g4
	TTRACE_RELOC_ADDR(%g4, %g3, %g5)
	wrhpr	%g4, %htba

	! Clear buffer description
	stx	%g0, [%g1 + CPU_TTRACEBUF_SIZE]	! size must be first
	stx	%g0, [%g1 + CPU_TTRACEBUF_PA]
	stx	%g0, [%g1 + CPU_TTRACEBUF_RA]

	/*
	 * nentries (arg1) > 0 configures the buffer
	 * nentries ==  0 disables traptrace and cleans up buffer config
	 */
	brz,pn	%o1, hret_ok
	nop

	! Check alignment
	btst	TTRACE_ALIGNMENT - 1, %o0
	bnz,pn	%xcc, herr_badalign
	nop

	! Check that #entries is >= TTRACE_MINIMUM_ENTRIES
	cmp	%o1, TTRACE_MINIMUM_ENTRIES
	blu,a,pn %xcc, herr_inval
	  mov	TTRACE_MINIMUM_ENTRIES, %o1

	sllx	%o1, TTRACE_RECORD_SZ_SHIFT, %g6 ! convert #entries to bytes

	RANGE_CHECK(%g2, %o0, %g6, herr_noraddr, %g4)
	REAL_OFFSET(%g2, %o0, %g3, %g4)
	!! %g3 pa of traptrace buffer
	stx	%o0, [%g1 + CPU_TTRACEBUF_RA]
	stx	%g3, [%g1 + CPU_TTRACEBUF_PA]
	stx	%g6, [%g1 + CPU_TTRACEBUF_SIZE]	! size must be last

	!! Initialize traptrace buffer header
	mov	TTRACE_RECORD_SIZE, %g2
	stx	%g2, [%g1 + CPU_TTRACE_OFFSET]
	stx	%g2, [%g3 + TTRACE_HEADER_OFFSET]
	stx	%g2, [%g3 + TTRACE_HEADER_LAST_OFF]
	! %o1 return is the same as that passed in
	HCALL_RET(EOK)
	SET_SIZE(hcall_ttrace_buf_conf)


/*
 * hcall_ttrace_buf_info
 *
 * --
 * ret0 status (%o0)
 * ret1 current traptrace buf ra (%o1)
 * ret2 current traptrace buf size (%o2)
 */
	ENTRY_NP(hcall_ttrace_buf_info)
	CPU_STRUCT(%g1)

	ldx	[%g1 + CPU_TTRACEBUF_RA], %o1
	ldx	[%g1 + CPU_TTRACEBUF_SIZE], %o2
	srlx	%o2, TTRACE_RECORD_SZ_SHIFT, %o2 ! convert bytes to #entries
	movrz	%o2, %g0, %o1	! ensure RA zero if size is zero

	HCALL_RET(EOK)
	SET_SIZE(hcall_ttrace_buf_info)


/*
 * hcall_ttrace_enable
 *
 * arg0 boolean: 0 = disable, non-zero = enable (%o0)
 * --
 * ret0 status (%o0)
 * ret1 previous enable state (0=disabled, 1=enabled) (%o1)
 */
	ENTRY_NP(hcall_ttrace_enable)
	setx	htraptracetable, %g1, %g2	! %g2 = reloc'd &htraptracetable
	TTRACE_RELOC_ADDR(%g2, %g1, %g3)

	setx	htraptable, %g1, %g3		! %g3 = reloc'd &htraptable
	TTRACE_RELOC_ADDR(%g3, %g1, %g4)

	mov	%g3, %g1			! %g1 = (%o0 ? %g3 : %g2)
	movrnz	%o0, %g2, %g1

	rdhpr	%htba, %g4			! %o1 = (%htba == %g2)
	mov	%g0, %o1
	cmp	%g4, %g2
	move	%xcc, 1, %o1

	/*
	 * Check that the guest has previously provided a buf for this cpu
	 * Check here since by now %o1 will be properly set
	 */
	CPU_STRUCT(%g2)
	TTRACE_CHK_BUF(%g2, %g3, herr_inval)

	wrhpr	%g1, %htba

	HCALL_RET(EOK)
	SET_SIZE(hcall_ttrace_enable)


/*
 * hcall_ttrace_freeze
 *
 * arg0 boolean: 0 = disable, non-zero = enable (%o0)
 * --
 * ret0 status (%o0)
 * ret1 previous freeze state (0=disabled, 1=enabled) (%o1)
 */
	ENTRY_NP(hcall_ttrace_freeze)
	GUEST_STRUCT(%g1)

	movrnz	%o0, 1, %o0			! normalize to formal bool

	! race conditions for two CPUs updating this not harmful
	ldx	[%g1 + GUEST_TTRACE_FRZ], %o1	! current val for ret1
	stx	%o0, [%g1 + GUEST_TTRACE_FRZ]

	HCALL_RET(EOK)
	SET_SIZE(hcall_ttrace_freeze)


/*
 * hcall_ttrace_addentry
 *
 * arg0 lower 16 bits stored in TTRACE_ENTRY_TAG (%o0)
 * arg1 stored in TTRACE_ENTRY_F1 (%o1)
 * arg2 stored in TTRACE_ENTRY_F2 (%o2)
 * arg3 stored in TTRACE_ENTRY_F3 (%o3)
 * arg4 stored in TTRACE_ENTRY_F4 (%o4)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_ttrace_addentry)
	/*
	 * Check that the guest has perviously provided a buf for this cpu
	 * return EINVAL if not configured, ignore (EOK) if frozen
	 */
	TTRACE_PTR(%g3, %g2, herr_inval, hret_ok)

	rdpr	%tl, %g4			! %g4 holds current tl
	sub	%g4, 1, %g3			! %g3 holds tl of caller
	mov	%g3, %g1			! save for TL field fixup
	movrz	%g3, 1, %g3			! minimum is TL=1
	wrpr	%g3, %tl

	TTRACE_STATE(%g2, TTRACE_TYPE_GUEST, %g3, %g5)
	stb	%g1, [%g2 + TTRACE_ENTRY_TL]	! overwrite with calc'd TL

	wrpr	%g4, %tl			! restore trap level

	sth	%o0, [%g2 + TTRACE_ENTRY_TAG]
	stx	%o1, [%g2 + TTRACE_ENTRY_F1]
	stx	%o2, [%g2 + TTRACE_ENTRY_F2]
	stx	%o3, [%g2 + TTRACE_ENTRY_F3]
	stx	%o4, [%g2 + TTRACE_ENTRY_F4]

	TTRACE_NEXT(%g2, %g3, %g4, %g5)

	HCALL_RET(EOK)
	SET_SIZE(hcall_ttrace_addentry)


/*
 * hcall_set_rtba - set the current cpu's rtba
 *
 * arg0 rtba (%o0)
 * --
 * ret0 status (%o0)
 * ret1 previous rtba (%o1)
 */
	ENTRY_NP(hcall_set_rtba)
	CPU_GUEST_STRUCT(%g1, %g2)
	!! %g1 = cpup
	!! %g2 = guestp

	! Return prior rtba value
	ldx	[%g1 + CPU_RTBA], %o1

	! Check rtba for validity
	RANGE_CHECK(%g2, %o0, REAL_TRAPTABLE_SIZE, herr_noraddr, %g7)
	set	REAL_TRAPTABLE_SIZE - 1, %g3
	btst	%o0, %g3
	bnz,pn	%xcc, herr_badalign
	nop
	stx	%o0, [%g1 + CPU_RTBA]
	HCALL_RET(EOK)
	SET_SIZE(hcall_set_rtba)


/*
 * hcall_get_rtba - return the current cpu's rtba
 *
 * --
 * ret0 status (%o0)
 * ret1 rtba (%o1)
 */
	ENTRY_NP(hcall_get_rtba)
	CPU_STRUCT(%g1)
	ldx	[%g1 + CPU_RTBA], %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_get_rtba)


#ifdef CONFIG_BRINGUP

/*
 * vdev_genintr - generate a virtual interrupt
 *
 * arg0 sysino (%o0)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_vdev_genintr)
	GUEST_STRUCT(%g1)
	!! %g1 = guestp
	VINO2DEVINST(%g1, %o0, %g2, herr_inval)
	cmp	%g2, DEVOPS_VDEV
	bne,pn	%xcc, herr_inval
	nop
	add	%g1, GUEST_VDEV_STATE, %g2
	add	%g2, VDEV_STATE_MAPREG, %g2
	!! %g2 = mapreg array
	and	%o0, VINTR_INO_MASK, %o0	! get INO bits
	mulx	%o0, MAPREG_SIZE, %g1
	add	%g2, %g1, %g1
	!! %g1 = mapreg
	HVCALL(vdev_intr_generate)
	HCALL_RET(EOK)
	SET_SIZE(hcall_vdev_genintr)

#endif /* CONFIG_BRINGUP */
