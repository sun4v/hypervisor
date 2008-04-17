/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef	_BASICS_H
#define	_BASICS_H

#pragma ident	"@(#)basics.h	1.1	05/03/31 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#if defined(__linux__)
#include <linux/types.h>
typedef __uint8_t uint8_t;	/* UG! */
typedef __uint16_t uint16_t;	/* UG! */
typedef __uint32_t uint32_t;	/* UG! */
typedef __uint64_t uint64_t;	/* UG! */
#endif

typedef enum {
	false = 0, true = !false
} bool_t;

#define	SANITY(_s)	do { _s } while (0)
#define	DBG(_s)		do { _s } while (0)

#if defined(_BIG_ENDIAN)
#define	hton16(_s)	((uint16_t)(_s))
#define	hton32(_s)	((uint32_t)(_s))
#define	hton64(_s)	((uint64_t)(_s))
#define	ntoh16(_s)	((uint16_t)(_s))
#define	ntoh32(_s)	((uint32_t)(_s))
#define	ntoh64(_s)	((uint64_t)(_s))
#else
#error	FIXME: Define byte reversal functions for network byte ordering
#endif

#ifdef __cplusplus
}
#endif

#endif /* _BASICS_H */
