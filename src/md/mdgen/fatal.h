/*
 * Copyright 2004 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef	_FATAL_H_
#define	_FATAL_H_

#pragma ident	"@(#)fatal.h	1.1	04/07/16 SMI"

#ifdef __cplusplus
extern "C" {
#endif

extern void fatal(char *fmt, ...);
extern void warning(char *fmt, ...);

#ifdef __cplusplus
}
#endif

#endif /* _FATAL_H_ */
