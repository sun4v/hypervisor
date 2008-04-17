/*
 * Copyright 2004 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#pragma ident	"@(#)vfatal.c	1.1	04/07/16 SMI"

#include <stdarg.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>

#include "basics.h"

extern void vfatal(bool_t really_quit, char *fmt, va_list args);


void
vfatal(bool_t really_quit, char *fmt, va_list args)
{
	char *quit = really_quit ? "fatal" : "warning";

	if (errno != 0) {
		fprintf(stderr, "%s error: %s : ", quit, strerror(errno));
	} else {
		fprintf(stderr, "%s: ", quit);
	}
	vfprintf(stderr, fmt, args);
	fprintf(stderr, "\n");

	if (really_quit) exit(1);
}
