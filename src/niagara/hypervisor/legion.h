/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _LEGION_H
#define	_LEGION_H

#pragma ident	"@(#)legion.h	1.1	05/04/26 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#ifdef DEBUG_LEGION

#define	LEGION_MAGICTRAP_DEBUG	0x70
#define	LEGION_MAGICTRAP_EXIT	0x71
#define	LEGION_MAGICTRAP_GOT_HERE 0x72
#define	LEGION_MAGICTRAP_LOGROTATE 0x74
#define	LEGION_MAGICTRAP_PABCOPY 0x75
#define	LEGION_MAGICTRAP_INSTCOUNT 0x76

#define	LEGION_GOT_HERE					\
	ta	LEGION_MAGICTRAP_GOT_HERE

#define	LEGION_EXIT(n)					\
	mov	n, %o0					;\
	ta	LEGION_MAGICTRAP_EXIT

#define	LEGION_TRACEON(gscratch)			;\
	mov	%o0, gscratch				;\
	mov	-1, %o0					;\
	ta	LEGION_MAGICTRAP_DEBUG			;\
	mov	gscratch, %o0

#define	LEGION_TRACEOFF(gscratch)			;\
	mov	%o0, gscratch				;\
	mov	0, %o0					;\
	ta	LEGION_MAGICTRAP_DEBUG			;\
	mov	gscratch, %o0

#else /* !DEBUG_LEGION */

#define	LEGION_GOT_HERE
#define	LEGION_EXIT(n)
#define	LEGION_TRACEON(gscratch)
#define	LEGION_TRACEOFF(gscratch)

#endif /* !DEBUG_LEGION */

#ifdef __cplusplus
}
#endif

#endif /* _LEGION_H */
