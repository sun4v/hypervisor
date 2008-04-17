/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef	_ALLOCATE_H_
#define	_ALLOCATE_H_

#pragma ident	"@(#)allocate.h	1.1	05/03/31 SMI"

#ifdef __cplusplus
extern "C" {
#endif

extern void *xmalloc(int size, int line, char *filep);
#define	Xmalloc(_size)	xmalloc(_size, __LINE__, __FILE__)

extern void *xcalloc(int num, int size, int linen, char *filep);
#define	Xcalloc(_num, _type) xcalloc(_num, sizeof (_type), __LINE__, __FILE__)

extern void xfree(void *p, int, char *);
#define	Xfree(_p)	xfree(_p, __LINE__, __FILE__)

extern void *xrealloc(void *, int, int, char *);
#define	Xrealloc(_oldp, _size)	xrealloc(_oldp, _size, __LINE__, __FILE__)

extern char *xstrdup(char *ptr, int linen, char *filen);
#define	Xstrdup(_s)	xstrdup(_s, __LINE__, __FILE__)

#ifdef __cplusplus
}
#endif

#endif /* _ALLOCATE_H_ */
