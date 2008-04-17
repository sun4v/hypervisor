/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _TRAPTRACE_H
#define	_TRAPTRACE_H

#pragma ident	"@(#)traptrace.h	1.3	05/03/23 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#define	TTRACE_PTR(tmp, ptr, label_notconf, label_frz)	\
	mov	HSCRATCH0, tmp				;\
	ldxa	[tmp]ASI_HSCRATCHPAD, tmp		;\
	ldx	[tmp + CPU_GUEST], ptr			;\
	ldx	[ptr + GUEST_TTRACE_FRZ], ptr		;\
	brnz,pn	ptr, label_frz				;\
	 nop						;\
	ldx	[tmp + CPU_TTRACEBUF_SIZE], ptr		;\
	brz,pn	ptr, label_notconf			;\
	 nop						;\
	ldx	[tmp + CPU_TTRACE_OFFSET], ptr		;\
	ldx     [tmp + CPU_TTRACEBUF_PA], tmp		;\
	add	tmp, ptr, ptr

#define	TTRACE_NEXT(ptr, scr0, scr1, scr2)		 \
	mov	HSCRATCH0, scr0				;\
	ldxa	[scr0]ASI_HSCRATCHPAD, scr0		;\
	ldx	[scr0 + CPU_TTRACEBUF_SIZE], scr2	;\
	ldx	[scr0 + CPU_TTRACEBUF_PA], scr0		;\
	sub	ptr, scr0, scr1				;\
	stx	scr1, [scr0 + TTRACE_HEADER_LAST_OFF]	;\
	add	scr1, TTRACE_RECORD_SIZE, scr1		;\
	cmp	scr1, scr2				;\
	movge	%xcc, TTRACE_RECORD_SIZE, scr1		;\
	stx	scr1, [scr0 + TTRACE_HEADER_OFFSET]	;\
	mov	HSCRATCH0, scr2				;\
	ldxa	[scr2]ASI_HSCRATCHPAD, scr2		;\
	stx	scr1, [scr2 + CPU_TTRACE_OFFSET]

#define	TTRACE_NEXTPTR(ptr, scr0, scr1, scr2)		 \
	TTRACE_NEXT(ptr, scr0, scr1, scr2)		;\
	add	scr0, scr1, ptr

#define	TTRACE_STATE(ptr, typ, scr0, scr1)		 \
	rd	%tick, scr0				;\
	stx	scr0, [ptr + TTRACE_ENTRY_TICK]		;\
	mov	typ, scr0				;\
	stb	scr0, [ptr + TTRACE_ENTRY_TYPE]		;\
	rdpr	%tl, scr0				;\
	stb	scr0, [ptr + TTRACE_ENTRY_TL]		;\
	rdpr	%gl, scr0				;\
	stb	scr0, [ptr + TTRACE_ENTRY_GL]		;\
	rdpr	%tt, scr0				;\
	sth	scr0, [ptr + TTRACE_ENTRY_TT]		;\
	rdpr	%tstate, scr0				;\
	stx	scr0, [ptr + TTRACE_ENTRY_TSTATE]	;\
	rdhpr	%hpstate, scr0				;\
	mov	%g0, scr1				;\
	btst	HPSTATE_TLZ, scr0			;\
	bnz,a	%xcc, .+8				;\
	 or	scr1, TTRACE_HPSTATE_TLZ, scr1		;\
	btst	HPSTATE_ENB, scr0			;\
	bnz,a	%xcc, .+8				;\
	 or	scr1, TTRACE_HPSTATE_ENB, scr1		;\
	stb	scr1, [ptr + TTRACE_ENTRY_HPSTATE]	;\
	rdpr	%tpc, scr0				;\
	stx	scr0, [ptr + TTRACE_ENTRY_TPC]

#define	TTRACE_HPSTATE_TLZ	1
#define	TTRACE_HPSTATE_ENB	2

#define	TTRACE_CHK_BUF(cpu, ttbufsize, label)		\
	ldx	[cpu + CPU_TTRACEBUF_SIZE], ttbufsize	;\
	brz,pn	ttbufsize, label			;\
	nop

#ifdef __cplusplus
}
#endif

#endif /* _TRAPTRACE_H */
