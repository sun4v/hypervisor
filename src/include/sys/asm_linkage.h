/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _SYS_ASM_LINKAGE_H
#define	_SYS_ASM_LINKAGE_H

#pragma ident	"@(#)asm_linkage.h	1.1	05/04/26 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _ASM

/*
 * Assembler short-cuts
 */

#define	ENTRY(x)					\
	/* BEGIN CSTYLED */				\
	.section	".text"				;\
	.align		4				;\
	.global		x				;\
	.type		x, #function			;\
x:							;\

#define	ENTRY_NP(x)	ENTRY(x)

#define	ALTENTRY(x)					\
	/* BEGIN CSTYLED */				\
	.global		x				;\
	.type		x, #function			;\
	x:						;\
	/* END CSTYLED */


#define DATA_GLOBAL(name)				\
	/* BEGIN CSTYLED */				\
	.align		8				;\
	.section	".data"				;\
	.global		name				;\
	name:						;\
	.type		name, #object			;\
	/* END CSTYLED */

#define BSS_GLOBAL(name, sz, algn)			\
	/* BEGIN CSTYLED */				\
	.section	".bss"				;\
	.align		algn				;\
	.global		name				;\
	name:						;\
	.type		name, #object			;\
	.skip		sz				;\
	.size		name, . - name			;\
	/* END CSTYLED */

#define	SET_SIZE(x)					\
	.size		x, (. - x)

/* END CSTYLED */

#endif /* _ASM */

#ifdef __cplusplus
}
#endif

#endif /* _SYS_ASM_LINKAGE_H */
