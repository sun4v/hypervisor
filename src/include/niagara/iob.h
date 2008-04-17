/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _NIAGARA_IOB_H
#define	_NIAGARA_IOB_H

#pragma ident	"@(#)iob.h	1.3	05/04/26 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Interrupt Management
 */
#define	INT_MAN_BASE		(IOBBASE + INT_MAN)
#define	INT_MAN_STEP		(8)
#define	INT_MAN_DEV_OFF(dev)	((dev) * INT_MAN_STEP)

#define	INT_CTL_BASE		(IOBBASE + INT_CTL)
#define	INT_CTL_STEP		(8)
#define	INT_CTL_DEV_OFF(dev)	((dev) * INT_CTL_STEP)


/*
 * IOB Internal device ids
 */
#define	IOBDEV_SSIERR		1 /* Used for errors */
#define	IOBDEV_SSI		2 /* SSI interrupt from EXT_INT_L pin */


/*
 * INT_MAN Register
 */
#define	INT_MAN_CPU_SHIFT	8
#define	INT_MAN_CPU_MASK	0x1f
#define	INT_MAN_VEC_MASK	0x3f

/*
 * INT_CTL register
 */
#define	INT_CTL_MASK		0x04
#define	INT_CTL_CLEAR		0x02
#define	INT_CTL_PEND		0x01

/*
 * HW DEBUG Reg support
 */

#define	L2_VIS_CONTROL 	(IOBBASE + 0x1800)
#define	L2_VIS_MASK_A 	(IOBBASE + 0x1820)
#define	L2_VIS_MASK_B 	(IOBBASE + 0x1828)
#define	L2_VIS_CMP_A 	(IOBBASE + 0x1830)
#define	L2_VIS_CMP_B 	(IOBBASE + 0x1838)
#define	L2_TRIG_DELAY 	(IOBBASE + 0x1840)
#define	IOB_VIS_SELECT 	(IOBBASE + 0x1000)

#define	DB_ENET_CONTROL (IOBBASE + 0x2000)
#define	DB_ENET_IDLEVAL (IOBBASE + 0x2008)

#define	DB_JBUS_CONTROL (IOBBASE + 0x2100)
#define	DB_JBUS_MASK 	(IOBBASE + 0x2140)
#define	DB_JBUS_COMPARE (IOBBASE + 0x2148)

#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA_IOB_H */
