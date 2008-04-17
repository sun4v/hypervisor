/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _SYS_HTYPES_H
#define	_SYS_HTYPES_H

#pragma ident	"@(#)htypes.h	1.3	05/09/13 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _ASM
/*
 * Basic / Extended integer types
 *
 * The following defines the basic fixed-size integer types.
 */
typedef char			int8_t;
typedef short			int16_t;
typedef int			int32_t;
typedef	long 			int64_t;

typedef unsigned char		uint8_t;
typedef unsigned short		uint16_t;
typedef unsigned int		uint32_t;

#if !defined(__sparcv9)
#error "__sparcv9 compilation environment required"
#endif

typedef unsigned long           uint64_t;


#endif /* _ASM */

/*
 * Sizeof definitions
 */
#define	SHIFT_BYTE	0			/* log2(SZ_BYTE)    	     */
#define	SZ_BYTE		(1 << SHIFT_BYTE)	/* # bytes in a byte	     */

#define SHIFT_HWORD	1			/* log2(SZ_HWORD)    	     */
#define SZ_HWORD	(1 << SHIFT_HWORD)	/* # bytes in a half word    */

#define	SHIFT_WORD	2			/* log2(SZ_WORD)    	     */
#define	SZ_WORD		(1 << SHIFT_WORD)	/* # bytes in a word	     */

#define	SHIFT_LONG	3			/* log2(SZ_LONG)    	     */
#define	SZ_LONG		(1 << SHIFT_LONG)	/* # bytes in a long	     */

#define	SHIFT_INST	2			/* log2(SZ_INST)    	     */
#define	SZ_INSTR	(1 << SHIFT_INST)	/* # bytes in an instruction */


#define	SIZEOF_UI64	SZ_LONG		/* # bytes in a unsigned int 64 bit */


#ifdef __cplusplus
}
#endif

#endif /* _SYS_HTYPES_H */
