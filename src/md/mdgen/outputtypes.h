/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 *
 */

#ifndef	_OUTPUTTYPES_H
#define	_OUTPUTTYPES_H

#pragma ident	"@(#)outputtypes.h	1.1	05/03/31 SMI"

#ifdef __cplusplus
extern "C" {
#endif

extern bool_t flag_verbose;

extern void output_bin(FILE *fp);
extern void output_text(FILE *fp);
extern void output_dot(FILE *fp);

#ifdef __cplusplus
}
#endif

#endif	/* _OUTPUTTYPES_H */
