/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

	.ident	"@(#)version.s	1.4	05/03/01 SMI"

	.file	"version.s"

/*
 * Niagara startup code
 */

#include <sys/asm_linkage.h>

	.section ".text"
	.global	qversion, eqversion
	.align	64
qversion:
	.ascii	"@(#)"
	.ascii	 VERSION
	.asciz	"\r\n"
	.align	8
eqversion:
#ifdef DEBUG
	ENTRY_NP(printversion)
	mov	%g7, %g2
	set	.-qversion, %g1
	rd	%pc, %g7
	sub	%g7, %g1, %g1
	ba	puts
	mov	%g2, %g7
	jmp	%g7 + 4
	nop
	SET_SIZE(printversion)
#endif
