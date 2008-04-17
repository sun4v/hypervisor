/*
 * Copyright 2005 Sun Microsystems, Inc.	 All rights reserved.
 * Use is subject to license terms.
 */

#pragma ident	"@(#)output_text.c	1.1	05/03/31 SMI"


#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <ctype.h>
#include <strings.h>
#include <inttypes.h>
#include <netinet/in.h>
#include <errno.h>

#include <assert.h>

#include <md/md_impl.h>

#include "basics.h"
#include "allocate.h"
#include "fatal.h"
#include "lexer.h"

#include "dagtypes.h"
#include "outputtypes.h"


#define	ASSERT(_s)	assert(_s)

#define	DBGN(_s) do { } while (0)

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





	/*
	 *------------------------------------
	 * Output in text format for human use
	 *------------------------------------
	 */


#define	BASE_TAG_COUNT	2
#define	LAST_OFFSET	1



void
output_text(FILE *fp)
{
	dag_node_t *dnp;
	int fh;
	int offset;
	int list_end_offset;

	fflush(fp);

		/*
		 * Step1: compute the offsets for the start of each node.
		 */

	offset = 0;
	for (dnp = dag_listp; NULL != dnp; dnp = dnp->nextp) {
		dnp->offset = offset;

DBGN(	fprintf(stderr, "Node %d @ %d : %s %s\tprop=%d\n",
		dnp->idx, offset, dnp->typep, dnp->namep,
		dnp->properties.num); );

		offset += BASE_TAG_COUNT;
		offset += dnp->properties.num;
	}
	list_end_offset = offset;

	dump_dag_nodes(fp);
}
