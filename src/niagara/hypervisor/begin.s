/*
 * Copyright 2003 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

	.ident	"@(#)begin.s	1.4	04/07/20 SMI"

	.file	"begin.s"

/*
 * Niagara startup code
 */

#include <sys/asm_linkage.h>

	.section ".text"
	.global begin
	.align 0x2000
	.type begin, #function
begin:

