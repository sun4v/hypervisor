/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _SUN4V_VPCI_H
#define	_SUN4V_VPCI_H

#pragma ident	"@(#)vpci.h	1.4	05/06/01 SMI"


#ifdef __cplusplus
extern "C" {
#endif

#define	HVIO_TTE_R		0x001
#define	HVIO_TTE_W		0x002
#define	HVIO_TTE_S		0x004
#define	HVIO_TTE_ATTR_MASK	0x007

#define	HVIO_IO_R		0x001
#define	HVIO_IO_W		0x002
#define	HVIO_IO_ATTR_MASK	0x003

#define	HVIO_MSI_INVALID	0
#define	HVIO_MSI_VALID		1
#define	HVIO_MSI_VALID_MAX_VALUE	HVIO_MSI_VALID

#define	HVIO_PCIE_MSG_INVALID	0
#define	HVIO_PCIE_MSG_VALID	1
#define	HVIO_PCIE_MSG_VALID_MAX_VALUE	HVIO_PCIE_MSG_VALID

#define	HVIO_MSISTATE_DELIVERED	1

#define	HVIO_MSIQSTATE_IDLE	0
#define	HVIO_MSIQSTATE_ERROR	1
#define	HVIO_MSIQSTATE_MAX_VALUE HVIO_MSIQSTATE_ERROR

#define	MSIQTYPE_32		0
#define	MSIQTYPE_64		1
#define	MSIQTYPE_MAX_VALUE	MSIQTYPE_64

#define	INTR_DISABLED		0
#define	INTR_ENABLED		1
#define	INTR_ENABLED_MAX_VALUE	INTR_ENABLED

#define	INTR_IDLE		0
#define	INTR_RECEIVED		1
#define	INTR_DELIVERED		2
#define	INTR_STATE_MAX_VALUE	INTR_DELIVERED

#define	HVIO_DMA_SYNC_DEVICE	1
#define	HVIO_DMA_SYNC_CPU	2

#define	VPCI_MSIEQ_TID_SHIFT	32
#define	VPCI_MSIEQ_MSG_RT_CODE_SHIFT 16
#define	VPCI_MSG_CODE_SHIFT	0


#define	IOMMU_MAP_MAX		64 /* max # of pages mapped  */

#ifdef __cplusplus
}
#endif

#endif /* _SUN4V_VPCI_H */
