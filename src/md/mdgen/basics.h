/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef	_BASICS_H_
#define	_BASICS_H_

#pragma ident	"@(#)basics.h	1.2	05/03/31 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#if defined(__linux__)
#include <linux/types.h>
typedef __uint8_t uint8_t;
typedef __uint16_t uint16_t;
typedef __uint32_t uint32_t;
typedef __uint64_t uint64_t;
#endif

typedef enum {
	false = 0, true = !false
} bool_t;

#define	SANITY(_s)	do { _s } while (0)
#define	DBG(_s)		do { _s } while (0)
#include <assert.h>
#define	ASSERT(_s)	assert(_s)

#ifdef __cplusplus
}
#endif

#endif /* _BASICS_H_ */
