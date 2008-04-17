/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _DEBUG_H
#define	_DEBUG_H

#pragma ident	"@(#)debug.h	1.3	05/04/26 SMI"

#include "legion.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifdef DEBUG

/*
 * Debugging aids
 */

/* BEGIN CSTYLED */
#define	DEBUG_SPINLOCK_ENTER(scr1, scr2, scr3)				\
	mov	HSCRATCH0, scr1						;\
	ldxa	[scr1]ASI_HSCRATCHPAD, scr1				;\
	ldub	[scr1 + CPU_PID], scr2		/* my ID */		;\
	inc	scr2			/* lockID = cpuid + 1 */ 	;\
	ldx	[scr1 + CPU_ROOT], scr1					;\
	add	scr1, CONFIG_DEBUG_SPINLOCK, scr1 /* scr1 = lockaddr */ ;\
1: 	nop; nop; nop; nop;			/* delay */		;\
	mov	scr2, scr3						;\
	casxa	[scr1]0x4, %g0, scr3	/* if zero, write my lockID */	;\
	cmp	scr3, scr2						;\
	bne,pt	%xcc, 1b						;\
	nop

#define	DEBUG_SPINLOCK_EXIT(scr1)					\
	mov	HSCRATCH0, scr1						;\
	ldxa	[scr1]ASI_HSCRATCHPAD, scr1				;\
	ldx	[scr1 + CPU_ROOT], scr1					;\
	add	scr1, CONFIG_DEBUG_SPINLOCK, scr1/* scr1 = lockaddr */	;\
	stx	%g0, [scr1]
/* END CSTYLED */


/*
 * These PRINT macros clobber %g7
 *
 * XXX - when gl is too high ta 0x95 which will print "lost message" error
 */

#define	MAX_PRINTTRAP_GL 2

/* BEGIN CSTYLED */
#define PRINTX(x)		\
	.pushlocals		;\
	rdpr	%gl, %g7	;\
	cmp	%g7, MAX_PRINTTRAP_GL ;\
	bgu,pt	%xcc, 2f	;\
	nop			;\
	mov	%o0, %g7	;\
	mov	x, %o0		;\
	ta	0x94		;\
	mov	%g7, %o0	;\
2:				;\
	.poplocals

#define PRINTW(x)		\
	.pushlocals		;\
	rdpr	%gl, %g7	;\
	cmp	%g7, MAX_PRINTTRAP_GL ;\
	bgu,pt	%xcc, 2f	;\
	nop			;\
	mov	%o0, %g7	;\
	mov	x, %o0		;\
	ta	0x95		;\
	mov	%g7, %o0	;\
2:				;\
	.poplocals

#define	PRINT(s)		\
	.pushlocals		;\
	rdpr	%gl, %g7	;\
	cmp	%g7, MAX_PRINTTRAP_GL ;\
	bgu,pt	%xcc, 2f	;\
	nop			;\
	mov	%o0, %g7	;\
	ba	1f		;\
	  rd	%pc, %o0	;\
	.asciz	s		;\
	.align	4		;\
1:	add	%o0, 4, %o0	;\
	ta	0x93		;\
	mov	%g7, %o0	;\
2:				;\
	.poplocals

/*
 * clobbers %g1-%g3,%g7
 */
#define	PRINT_NOTRAP(s)		\
	.pushlocals		;\
	ba	1f		;\
	rd	%pc, %g1	;\
2:	.asciz	s		;\
	.align	4		;\
1:	add	%g1, 4, %g1	;\
	ba	puts		;\
	rd	%pc, %g7	;\
	.poplocals

/*
 * clobbers %g1-%g5,%g7
 */
#define	PRINTX_NOTRAP(x)	\
	mov	x, %g1		;\
	ba	putx		;\
	rd	%pc, %g7

/*
 * clobbers %g1-%g5,%g7
 */
#define	PRINTW_NOTRAP(w)	\
	mov	w, %g1		;\
	ba	putw		;\
	rd	%pc, %g7

/* END CSTYLED */

#else /* !DEBUG */

#define	PRINTX(x)
#define	PRINTW(x)
#define	PRINT(x)
#define	PRINTX_NOTRAP(x)
#define	PRINTW_NOTRAP(x)
#define	PRINT_NOTRAP(x)

#endif /* !DEBUG */

#ifdef __cplusplus
}
#endif

#endif /* _DEBUG_H */
