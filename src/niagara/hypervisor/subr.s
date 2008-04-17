/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

	.ident	"@(#)subr.s	1.20	05/11/04 SMI"

	.file	"subr.s"

/*
 * Niagara startup code
 */

#include <sys/asm_linkage.h>
#include <devices/pc16550.h>
#include <niagara/asi.h>

#include "config.h"
#include "debug.h"


/*
 * memscrub - zero memory using Niagara blk-init stores
 * Assumes cache-line alignment and counts
 *
 * %g1 address
 * %g2 length
 *
 * Note that the block initializing store only zeros the
 * whole cacheline if the address is at the start of the
 * cacheline and the line is not in the L2 cache. Otherwise
 * the existing cacheline contents are retained other
 * than the specifically stored value.
 */
	ENTRY_NP(memscrub)
#ifdef CONFIG_FPGA /* running on real hardware */
	brz	%g2, 2f
	add	%g1, %g2, %g2
	mov	ASI_BLK_INIT_P, %asi
1:
	stxa	%g0, [%g1 + 0x00]%asi
	stxa	%g0, [%g1 + 0x08]%asi
	stxa	%g0, [%g1 + 0x10]%asi
	stxa	%g0, [%g1 + 0x18]%asi
	stxa	%g0, [%g1 + 0x20]%asi
	stxa	%g0, [%g1 + 0x28]%asi
	stxa	%g0, [%g1 + 0x30]%asi
	stxa	%g0, [%g1 + 0x38]%asi
	inc	0x40, %g1

	cmp	%g1, %g2
	blu,pt	%xcc, 1b
	nop
2:	
	membar	#Sync
#endif
	jmp	%g7 + 4
	nop
	SET_SIZE(memscrub)

/*
 * xcopy - copy xwords
 * Assumes 8-byte alignment and counts
 *
 * %g1 source (clobbered)
 * %g2 dest (clobbered)
 * %g3 size (clobbered)
 * %g4 temp (clobbered)
 * %g7 return address
 */
	ENTRY_NP(xcopy)
#ifdef CONFIG_LEGIONBCOPY
	/*
	 * Use a legion magic-trap to do the copy
	 * do alignment test to catch programming errors
	 */
	or	%g1, %g2, %g4
	or	%g4, %g3, %g4
	btst	7, %g4
	bnz,pt	%xcc, 1f
	nop
	ta	LEGION_MAGICTRAP_PABCOPY
	brz	%g4, 2f		! %g4 == 0 successful
	nop
1:
#endif
	sub	%g1, %g2, %g1
1:
	ldx	[%g1 + %g2], %g4
	deccc	8, %g3
	stx	%g4, [%g2]
	bgu,pt	%xcc, 1b
	inc	8, %g2
#ifdef CONFIG_LEGIONBCOPY
2:
#endif
	jmp	%g7 + 4
	nop
	SET_SIZE(xcopy)

/*
 * bcopy - short byte-aligned copies
 *
 * %g1 source (clobbered)
 * %g2 dest (clobbered)
 * %g3 size (clobbered)
 * %g4 temp (clobbered)
 * %g7 return address
 */
	ENTRY_NP(bcopy)
	! alignment test
	or	%g1, %g2, %g4
	or	%g4, %g3, %g4
	btst	7, %g4
	bz,pt	%xcc, xcopy
	nop

#ifdef CONFIG_LEGIONBCOPY
	/*
	 * Use a legion magic-trap to do the copy
	 */
	ta	LEGION_MAGICTRAP_PABCOPY
	brz	%g4, 2f		! %g4 == 0 successful
	nop
#endif
	sub	%g1, %g2, %g1
1:
	ldub	[%g1 + %g2], %g4
	deccc	%g3
	stb	%g4, [%g2]
	bgu,pt	%xcc, 1b
	inc	%g2
#ifdef CONFIG_LEGIONBCOPY
2:
#endif
	jmp	%g7 + 4
	nop
	SET_SIZE(bcopy)

/*
 * puts - print a string on the debug uart
 *
 * %g1 string (clobbered)
 * %g7 return address
 *
 * %g2-%g3 clobbered
 */
	ENTRY_NP(puts)
#ifdef CONFIG_HVUART
	setx	HV_UART, %g3, %g2
1:
	ldub	[%g2 + LSR_ADDR], %g3
	btst	LSR_THRE, %g3
	bz	1b
	nop

1:
	ldub	[%g1], %g3
	cmp	%g3, 0
	inc	%g1
	bne,a,pt %icc, 2f
	stb	%g3, [%g2]
	jmp	%g7 + 4
	nop

2:
	ldub	[%g2 + LSR_ADDR], %g3
	btst	LSR_TEMT, %g3
	bz	2b
	nop
	ba,a	1b
#else
	jmp	%g7 + 4
	nop
#endif
	SET_SIZE(puts)


/*
 * putx - print a 64-bit xword on the debug uart
 * %g1 value (clobbered)
 * %g7 return address
 *
 * %g2-%g5 clobbered
 */
	ENTRY_NP(putx)
#ifdef CONFIG_HVUART
	setx	HV_UART, %g3, %g2
1:	
	ldub	[%g2 + LSR_ADDR], %g4
	btst	LSR_THRE, %g4
	bz	1b
	nop
	
	mov	60, %g3
	ba	2f
	rd	%pc, %g4
	.ascii	"0123456789abcdef"
	.align	4
2:
	add	%g4, 4, %g4
1:
	srlx	%g1, %g3, %g5
	and	%g5, 0xf, %g5
	ldub	[%g4 + %g5], %g5
	stb	%g5, [%g2]
	subcc	%g3, 4, %g3
	bnz	2f
	nop
	
	and	%g1, 0xf, %g5
	ldub	[%g4 + %g5], %g5
	stb	%g5, [%g2]
	jmp	%g7 + 4
	nop

2:
	ldub	[%g2 + LSR_ADDR], %g5
	btst	LSR_TEMT, %g5
	bz	2b
	nop
	ba,a	1b
#else
	jmp	%g7 + 4
	nop
#endif
	SET_SIZE(putx)

/*
 * putw - print a 32-bit word on the debug uart
 *
 * %g1 value (clobbered)
 * %g7 return address
 *
 * %g2-%g5 clobbered
 */
	ENTRY_NP(putw)
#ifdef CONFIG_HVUART
	setx	HV_UART, %g3, %g2
#if !defined(CONFIG_SAS_IO)
1:	
	ldub	[%g2 + LSR_ADDR], %g4
	btst	LSR_THRE, %g4
	bz	1b
	nop
#endif
	
	mov	28, %g3
	ba	2f
	rd	%pc, %g4
	.ascii	"0123456789abcdef"
	.align	4
2:
	add	%g4, 4, %g4
1:
	srlx	%g1, %g3, %g5
	and	%g5, 0xf, %g5
	ldub	[%g4 + %g5], %g5
	stb	%g5, [%g2]
	subcc	%g3, 4, %g3
	bnz	2f
	nop
	
	and	%g1, 0xf, %g5
	ldub	[%g4 + %g5], %g5
	stb	%g5, [%g2]
	jmp	%g7 + 4
	nop

2:
#if !defined(CONFIG_SAS_IO)
	ldub	[%g2 + LSR_ADDR], %g5
	btst	LSR_TEMT, %g5
	bz	2b
	nop
#endif
	ba,a	1b
#else
	jmp	%g7 + 4
	nop
#endif /* CONFIG_HVUART */
	SET_SIZE(putw)

#ifdef CONFIG_HVUART
/*
 * uart_init - initialize the debug uart
 * Supports only 16550 UART
 *
 * %g1 is UART base address
 * %g2,%g3 clobbered
 * %g7 return address
 */
	ENTRY_NP(uart_init)
	ldub	[%g1 + LSR_ADDR], %g2	! read LSR
	stb	%g0, [%g1 + IER_ADDR] 	! clear IER
	stb	%g0, [%g1 + FCR_ADDR] 	! clear FCR, disable FIFO
	mov	(FCR_XMIT_RESET | FCR_RCVR_RESET),  %g3
	stb	%g3, [%g1 + FCR_ADDR] 	! reset FIFOs in FCR
	mov	FCR_FIFO_ENABLE,  %g3
	stb	%g3, [%g1 + FCR_ADDR] 	! FCR enable FIFO
	mov	(LCR_DLAB | LCR_8N1), %g3
	stb	%g3, [%g1 + LCR_ADDR] 	! set LCR for 8-n-1, set DLAB
	! DLAB = 1
	mov	DLL_9600, %g3
#ifdef UART_CLOCK_MULTIPLIER
	mulx	%g3, UART_CLOCK_MULTIPLIER, %g3
#endif
	stb	%g3, [%g1 + DLL_ADDR] 	! set baud rate = 9600
	stb	%g0, [%g1 + DLM_ADDR] 	! set MS = 0
	! disable DLAB
	mov	LCR_8N1, %g3		! set LCR for 8-n-1, unset DLAB
	jmp	%g7 + 4
	stb	%g3, [%g1 + LCR_ADDR] 	! set LCR for 8-n-1, unset DLAB
	SET_SIZE(uart_init)
#endif /* CONFIG_HVUART */

	ENTRY_NP(hvabort)
	mov	%g1, %g6
	PRINT_NOTRAP("ABORT: Failure 0x");
	PRINTX_NOTRAP(%g6)
#ifdef CONFIG_VBSC_SVC
	PRINT_NOTRAP(", contacting vbsc\r\n");
	ba,pt   %xcc, vbsc_hv_abort
	mov	%g6, %g1

#else
	PRINT_NOTRAP(", spinning\r\n");
	LEGION_EXIT(1)
2:	ba,a	2b
#endif
	SET_SIZE(hvabort)


#ifdef DEBUG
/*
 * These routines are called from softtrap handlers.
 *
 * We do this so that debug printing does not trample all over
 * the registers you are using.
 */
	ENTRY_NP(hprint)
	mov	%o0, %g1
	ba	puts
	rd	%pc, %g7
	done
	SET_SIZE(hprint)

	ENTRY_NP(hprintx)
	mov	%o0, %g1
	ba	putx
	rd	%pc, %g7
	done
	SET_SIZE(hprintx)

	ENTRY_NP(hprintw)
	mov	%o0, %g1
	ba	putw
	rd	%pc, %g7
	done
	SET_SIZE(hprintw)

#endif /* DEBUG */
