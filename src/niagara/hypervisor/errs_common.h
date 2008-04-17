/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef	_NIAGARA_ERRS_COMMON_H
#define	_NIAGARA_ERRS_COMMON_H

#pragma ident	"@(#)errs_common.h	1.3	05/09/09 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Guest error report: Error Handle (ehdl) encoding
 * The error handle is 64 bits long. It will be used to generate a
 * unique error handle.  Each strand has an incremental value. 
 *
 * 63           56 55  52 51                                              0
 *  ----------------------------------------------------------------------
 * | PHYS CPU ID  | TL    |                incrmt num                     |
 *  ----------------------------------------------------------------------
 */
#define	EHDL_TL_BITS		4
#define	EHDL_SEQ_MASK		0x000FFFFFFFFFFFFF
#define	EHDL_SEQ_MASK_SHIFT	12	/* use this strip off upper bits */
#define	EHDL_CPUTL_SHIFT	52

#define	ERPT_TYPE_CPU		0x1
#define	ERPT_TYPE_FIRE		0x2

/*
 * in:
 *
 * out:
 * scr1 -> unique error sequence
 *
 */
#define	GEN_SEQ_NUMBER(scr1, scr2)					\
	CPU_STRUCT(scr2);						;\
	ldx	[scr2 + ERR_SEQ_NO], scr1	/* get current seq# */	;\
	add	scr1, 1, scr1			/* new seq#	    */	;\
	stx	scr1, [scr2 + ERR_SEQ_NO]	/* update seq#      */	;\
	sllx	scr1, EHDL_SEQ_MASK_SHIFT, scr1				;\
	srlx	scr1, EHDL_SEQ_MASK_SHIFT, scr1	/* scr1 = normalized seq# */;\
	ldub	[scr2 + CPU_PID], scr2		/* scr2 has CPUID    */	;\
	sllx	scr2, EHDL_TL_BITS, scr2	/* scr2 << EHDL_TL_BITS */;\
	sllx	scr2, EHDL_CPUTL_SHIFT, scr2	/* scr2 now has cpuid in 63:56 */  ;\
	or	scr2, scr1, scr1		/* scr1 now has ehdl without tl */ ;\
	rdpr	%tl, scr2			/* scr2 = %tl        */	;\
	sllx	scr2, EHDL_CPUTL_SHIFT, scr2	/* scr2 tl in position  */;\
	or	scr2, scr1, scr1		/* scr1 -> ehdl   */

/*
 * A error channel packet gets sent to the vbsc with the PA and size
 * pointing the location of the bulk data.
 * HV obtains the PA and the Size avail from the PDs. They correspond
 * to a location in sram.
 *
 * There is only 1 sram error buffer per system, so it needs to be shared
 * across cpus, fire leaves, and guests.
 * The err_buf_inuse flag on the config struct is used for this purpose.
 * The following flag defines the sram error buffer as busy.
 *
 */
#define	ERR_BUF_BUSY	1

/*
 * Software Initiated Reset type codes
 */
#define	SIR_TYPE_FATAL_DBU		1


#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA_ERRS_COMMON_H */
