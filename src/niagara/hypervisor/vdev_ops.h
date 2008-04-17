/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _VDEV_OPS_H
#define	_VDEV_OPS_H

#pragma ident	"@(#)vdev_ops.h	1.3	05/08/26 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Devops assignments to various nexii
 */

#define	DEVOPS_RESERVED		0

#ifdef CONFIG_FIRE
#define	DEVOPS_FIRE_A		1
#define	DEVOPS_FIRE_B		2
#define	DEVOPS_INT_FIRE_A	3
#define	DEVOPS_INT_FIRE_B	4
#define	DEVOPS_MSI_FIRE_A	5
#define	DEVOPS_MSI_FIRE_B	6
#define	DEVOPS_ERR_FIRE_A	7
#define	DEVOPS_ERR_FIRE_B	8
#else /* CONFIG_FIRE */
#define	DEVOPS_FIRE_A		DEVOPS_RESERVED
#define	DEVOPS_FIRE_B		DEVOPS_RESERVED
#define	DEVOPS_INT_FIRE_A	DEVOPS_RESERVED
#define	DEVOPS_INT_FIRE_B	DEVOPS_RESERVED
#define	DEVOPS_MSI_FIRE_A	DEVOPS_RESERVED
#define	DEVOPS_MSI_FIRE_B	DEVOPS_RESERVED
#define	DEVOPS_ERR_FIRE_A	DEVOPS_RESERVED
#define	DEVOPS_ERR_FIRE_B	DEVOPS_RESERVED
#endif /* CONFIG_FIRE */

#define	DEVOPS_VDEV		9

#define	NDEVOPSVECS		10

/*
 */


#define	NULL_iommu_map		0
#define	NULL_iommu_getmap	0
#define	NULL_iommu_unmap	0
#define	NULL_iommu_getbypass	0
#define	NULL_config_get		0
#define	NULL_config_put		0
#define	NULL_io_peek		0
#define	NULL_io_poke		0
#define	NULL_dma_sync		0
#define	NULL_devino2vino	0
#define	NULL_mondo_receive	0
#define	NULL_intr_getvalid	0
#define	NULL_intr_setvalid	0
#define	NULL_intr_settarget	0
#define	NULL_intr_gettarget	0
#define	NULL_intr_getstate	0
#define	NULL_intr_setstate	0
#define	NULL_msiq_conf		0
#define	NULL_msiq_info		0
#define	NULL_msiq_getvalid	0
#define	NULL_msiq_setvalid	0
#define	NULL_msiq_getstate	0
#define	NULL_msiq_setstate	0
#define	NULL_msiq_gethead	0
#define	NULL_msiq_sethead	0
#define	NULL_msiq_gettail	0
#define	NULL_msi_getvalid	0
#define	NULL_msi_setvalid	0
#define	NULL_msi_getstate	0
#define	NULL_msi_setstate	0
#define	NULL_msi_getmsiq	0
#define	NULL_msi_setmsiq	0
#define	NULL_msi_msg_getmsiq	0
#define	NULL_msi_msg_setmsiq	0
#define	NULL_msi_msg_getvalid	0
#define	NULL_msi_msg_setvalid	0
#define	NULL_get_perf_reg	0
#define	NULL_set_perf_reg	0

#define	INTR_OPS(device) \
	.devino2vino = device##_devino2vino

#define	MONDO_OPS(device) \
	.mondo_receive = device##_mondo_receive

#define	PERF_OPS(device) \
	.getperfreg = device##_get_perf_reg, \
	.setperfreg = device##_set_perf_reg

#define	VINO_OPS(device) \
	.getvalid = device##_intr_getvalid, \
	.setvalid = device##_intr_setvalid, \
	.getstate = device##_intr_getstate, \
	.setstate = device##_intr_setstate, \
	.gettarget = device##_intr_gettarget, \
	.settarget = device##_intr_settarget

#define	VPCI_OPS(bridge) \
	.map	= bridge##_iommu_map,	\
	.getmap = bridge##_iommu_getmap,\
	.unmap	= bridge##_iommu_unmap,	\
	.getbypass = bridge##_iommu_getbypass, \
	.configget = bridge##_config_get, \
	.configput = bridge##_config_put, \
	.peek	= bridge##_io_peek, \
	.poke	= bridge##_io_poke, \
	.dmasync = bridge##_dma_sync

#define	MSI_OPS(bridge) \
	.msiq_conf	= bridge##_msiq_conf, \
	.msiq_info	= bridge##_msiq_info, \
	.msiq_getvalid	= bridge##_msiq_getvalid, \
	.msiq_setvalid	= bridge##_msiq_setvalid, \
	.msiq_getstate	= bridge##_msiq_getstate, \
	.msiq_setstate	= bridge##_msiq_setstate, \
	.msiq_gethead	= bridge##_msiq_gethead, \
	.msiq_sethead	= bridge##_msiq_sethead, \
	.msiq_gettail	= bridge##_msiq_gettail, \
	.msi_getvalid	= bridge##_msi_getvalid, \
	.msi_setvalid	= bridge##_msi_setvalid, \
	.msi_getstate	= bridge##_msi_getstate, \
	.msi_setstate	= bridge##_msi_setstate, \
	.msi_getmsiq	= bridge##_msi_getmsiq, \
	.msi_setmsiq	= bridge##_msi_setmsiq, \
	.msi_msg_getmsiq = bridge##_msi_msg_getmsiq, \
	.msi_msg_setmsiq = bridge##_msi_msg_setmsiq, \
	.msi_msg_getvalid = bridge##_msi_msg_getvalid, \
	.msi_msg_setvalid = bridge##_msi_msg_setvalid

/*
 * "null" nexus
 */
#define	NULL_DEV_OPS \
	INTR_OPS(NULL), VINO_OPS(NULL), VPCI_OPS(NULL),	\
		MSI_OPS(NULL), PERF_OPS(NULL)


/*
 * Virtual device (vdev) nexus
 */
#define	VINO_HANDLER_VDEV \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 00 - 01 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 02 - 03 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 04 - 05 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 06 - 07 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 08 - 09 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 10 - 11 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 12 - 13 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 14 - 15 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 16 - 17 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 18 - 19 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 20 - 21 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 22 - 23 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 24 - 25 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 26 - 27 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 28 - 29 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 30 - 31 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 32 - 33 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 34 - 35 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 36 - 37 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 38 - 39 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 40 - 41 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 42 - 33 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 44 - 45 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 46 - 47 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 48 - 49 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 50 - 51 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 52 - 53 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 54 - 55 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 56 - 57 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 58 - 59 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 60 - 61 */ \
	DEVOPS_VDEV, DEVOPS_VDEV	/* 62 - 63 */

#define	VDEV_OPS \
	INTR_OPS(vdev), MONDO_OPS(NULL), VINO_OPS(vdev),	\
		VPCI_OPS(NULL), MSI_OPS(NULL), PERF_OPS(NULL)


/*
 * Fire nexus
 */
#ifdef CONFIG_FIRE

#define	FIRE_LEAF(n)	(FIRE_##n##_AID) & (NFIRELEAVES-1)
#define	FIRE_DEV_COOKIE(n) (struct fire_cookie *)&fire_dev[FIRE_LEAF(n)]
#define	FIRE_MSI_COOKIE(n) (struct fire_msi_cookie *)&fire_msi[FIRE_LEAF(n)]
#define	FIRE_ERR_COOKIE(n) (struct fire_err_cookie *)&fire_err[FIRE_LEAF(n)]

/*
 * Functions with first arg as devhandle
 */
#define	FIRE_DEV_OPS \
	INTR_OPS(fire), MONDO_OPS(NULL), VINO_OPS(NULL), \
		VPCI_OPS(fire), MSI_OPS(fire), PERF_OPS(fire)

/*
 * Functions with first arg as vINO
 */
#define	FIRE_INT_OPS \
	INTR_OPS(NULL), MONDO_OPS(fire), VINO_OPS(fire), \
		VPCI_OPS(NULL), MSI_OPS(NULL), PERF_OPS(NULL)

/*
 * MSI functions
 */
#define	FIRE_MSI_OPS \
		INTR_OPS(NULL), MONDO_OPS(fire_msi), VINO_OPS(fire), \
		VPCI_OPS(NULL), MSI_OPS(NULL), PERF_OPS(NULL)

/*
 * Fire Error INOs
 */
#define	FIRE_ERR_OPS \
	INTR_OPS(NULL), MONDO_OPS(fire_err), VINO_OPS(fire_err), \
		VPCI_OPS(NULL), MSI_OPS(NULL), PERF_OPS(NULL)

#define	DEVOPS_INT_FIRE(n)	(DEVOPS_INT_FIRE_##n)
#define	DEVOPS_MSI_FIRE(n)	(DEVOPS_MSI_FIRE_##n)
#define	DEVOPS_ERR_FIRE(n)	(DEVOPS_ERR_FIRE_##n)

#define	VINO_HANDLER_FIRE(n) \
	/* Standard INOs from devices */		      \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 00 - 01 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 02 - 03 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 04 - 05 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 06 - 07 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 08 - 09 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 10 - 11 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 12 - 13 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 14 - 15 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 16 - 17 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 18 - 19 */ \
	/* INTx emulation */				      \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 20 - 21 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 22 - 23 */ \
	/* MSI QUEUEs */				      \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 24 - 25 */	\
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 26 - 27 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 28 - 29 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 30 - 31 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 32 - 33 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 34 - 35 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 36 - 37 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 38 - 39 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 40 - 41 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 42 - 43 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 44 - 45 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 46 - 47 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 48 - 49 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 50 - 51 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 52 - 53 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 54 - 55 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 56 - 57 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 58 - 59 */ \
	/* I2C Interrupts */				      \
	DEVOPS_RESERVED, DEVOPS_RESERVED,	/* 60 - 61 */ \
	/* Error Interrupts */				      \
	DEVOPS_ERR_FIRE(n), DEVOPS_ERR_FIRE(n)	/* 62 - 63 */


#else /* !CONFIG_FIRE */

#define	FIRE_DEV_COOKIE(n) 0
#define	FIRE_MSI_COOKIE(n) 0
#define	FIRE_ERR_COOKIE(n) 0
#define	FIRE_DEV_OPS	NULL_DEV_OPS
#define	FIRE_INT_OPS	NULL_DEV_OPS
#define	FIRE_MSI_OPS	NULL_DEV_OPS
#define	FIRE_ERR_OPS	NULL_DEV_OPS

#endif /* !CONFIG_FIRE */

#ifndef _ASM

struct devopsvec {
	void	(*devino2vino)();

	void	(*mondo_receive)();
	void	(*getvalid)();
	void	(*setvalid)();
	void	(*getstate)();
	void	(*setstate)();
	void	(*gettarget)();
	void	(*settarget)();

	void	(*map)();
	void	(*getmap)();
	void	(*unmap)();
	void	(*getbypass)();
	void	(*configget)();
	void	(*configput)();
	void	(*peek)();
	void	(*poke)();
	void	(*dmasync)();
	void	(*msiq_conf)();
	void	(*msiq_info)();
	void	(*msiq_getvalid)();
	void	(*msiq_setvalid)();
	void	(*msiq_getstate)();
	void	(*msiq_setstate)();
	void	(*msiq_gethead)();
	void	(*msiq_sethead)();
	void	(*msiq_gettail)();
	void	(*msi_getvalid)();
	void	(*msi_setvalid)();
	void	(*msi_getstate)();
	void	(*msi_setstate)();
	void	(*msi_getmsiq)();
	void	(*msi_setmsiq)();
	void	(*msi_msg_getmsiq)();
	void	(*msi_msg_setmsiq)();
	void	(*msi_msg_getvalid)();
	void	(*msi_msg_setvalid)();

	void	(*getperfreg)();
	void	(*setperfreg)();
};

#endif /* !_ASM */

#ifdef __cplusplus
}
#endif

#endif /* _VDEV_OPS_H */
