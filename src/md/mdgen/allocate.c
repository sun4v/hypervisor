/*
 * Copyright 2004 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#pragma ident	"@(#)allocate.c	1.1	04/07/16 SMI"

#include <string.h>
#include <malloc.h>
#include <unistd.h>
#include <stdlib.h>

#include "fatal.h"
#include "allocate.h"


/*
 * Simple allocation routines
 */

void *
xmalloc(int size, int linen, char *filen)
{
	void *p;

	if (size <= 0) {
		if (size < 0) {
			fatal("xmalloc of negative size (%d) at %d in %s",
			    linen, filen);
		}
		warning("xmalloc of zero size at %d in %s", linen, filen);
		return (NULL);
	}

	p = malloc(size);
	if (p == NULL)
		fatal("malloc of %d at %d in %s", size, linen, filen);

	return (p);
}


void *
xcalloc(int num, int size, int linen, char *filen)
{
	void *p;

	if (size <= 0 || num <= 0) {
		fatal("xcalloc(%d,%d) : one of number or size is <= 0 "
		    "at line %d of %s", num, size, linen, filen);
	}

	p = calloc(num, size);
	if (p == NULL) {
		fatal("calloc of %d of size %d at %d in %s",
		    num, size, linen, filen);
	}

	return (p);
}



void
xfree(void *p, int linen, char *filen)
{
	if (p == NULL) {
		warning("xfree of NULL pointer at %d in %s", linen, filen);
		return;
	}

	free(p);
}


void *
xrealloc(void *oldp, int size, int linen, char *filen)
{
	void *p;

	if (size <= 0) {
		if (size == 0) {
			xfree(oldp, linen, filen);
			warning("xrealloc to zero size at %d in %s",
			    linen, filen);
			return (NULL);
		}

		fatal("xrealloc to negative size %d at %d in %s",
		    size, linen, filen);
	}

	if (oldp == NULL) {
		p = malloc(size);
	} else {
		p = realloc(oldp, size);
	}
	if (p == NULL)
		fatal("xrealloc failed @ %d in %s", linen, filen);

	return (p);
}



char *
xstrdup(char *strp, int linen, char *filen)
{
	char *p;

	p = strdup(strp);
	if (p == NULL)
		fatal("xstrdup @ %d in %s failed", linen, filen);

	return (p);
}
