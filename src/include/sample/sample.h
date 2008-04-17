/*
 * Copyright 2003 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _SAMPLE_H
#define _SAMPLE_H

#pragma ident	"@(#)sample.h	1.4	03/11/10 SMI"

#ifdef __cplusplus
extern "C" {
#endif

extern void *getsp(void);
extern void *getfp(void);
extern int getcwp(void);
extern int getcansave(void);
extern int gettl(void);
extern void flushw(void);
extern int disasm(uint64_t *);

#define K(n)	((n)*1024)
#define M(n)	(K(n)*1024)

#ifdef __cplusplus
}
#endif

#endif /* _SAMPLE_H */
