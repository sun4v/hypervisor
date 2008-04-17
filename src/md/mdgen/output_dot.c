/*
 * Copyright 2005 Sun Microsystems, Inc.	 All rights reserved.
 * Use is subject to license terms.
 */

#pragma ident	"@(#)output_dot.c	1.1	05/03/31 SMI"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <strings.h>
#include <ctype.h>

#include <assert.h>

#include "basics.h"
#include "allocate.h"
#include "fatal.h"
#include "lexer.h"

#include "dagtypes.h"
#include "outputtypes.h"

#define	ASSERT(_s)	assert(_s)



	/*
	 *------------------------------------------------------------
	 * Output for DOT utility
	 */






static char *
sanity_name(char *p)
{
	static char buf[2048];
	int i, ch;

	for (i = 0; (ch = p[i]) != '\0'; i++) {
		if (isalnum(ch) || ch == '_') {
			buf[i] = ch;
		} else {
			buf[i] = '_';
		}
	}
	buf[i] = '\0';

	return (buf);
}



extern char *output_dot_dagp;
extern bool_t output_dot_flag_none;




void
output_dot(FILE *fp)
{
	dag_node_t *dnp;

	fprintf(fp, "digraph machine_description {\n");
	fprintf(fp, "rankdir = LR ;\n");
	fprintf(fp, "ordering=in ;\n");
	fprintf(fp, "size=\"8.5,10\" ;\n");
	fprintf(fp, "nslimit=\"100.0\" ;\n");
	fprintf(fp, "mclimit=\"100.0\" ;\n");
#if 0 /* { */
	fprintf(fp, "node [ fontfamily=Helvetica , fontsize=6 ] ;\n");
#endif /* } */
	fprintf(fp, "node [ fontfamily=Helvetica ] ;\n");

		/* Now output the nodes ... and their connections */
	for (dnp = dag_listp; NULL != dnp; dnp = dnp->nextp) {
		int i;
		pair_entry_t *pep;

		fprintf(fp, "%s [ label=\"%s\\n", sanity_name(dnp->namep),
		    dnp->typep);

		if (!output_dot_flag_none) {
			pep = dnp->properties.listp;
			for (i = 0; i < dnp->properties.num; i++) {
				switch (pep->utype) {
				case PE_none:
					break;
				case PE_string:
					fprintf(fp, "%s =",
					    sanity_name(pep->namep));
					fprintf(fp, " %s\\n",
					    sanity_name(pep->u.strp));
					break;
				case PE_int:
					fprintf(fp, "%s = 0x%llx\\n",
					    pep->namep, pep->u.val);
					break;
				case PE_arc:
					break;
				case PE_noderef:
					fatal("Internal error noderefs should \
all be resolved");
					break;
				}
				pep ++;
			}
		}
		fprintf(fp, "\" ] ;\n");

			/* Now connect the arcs */
		pep = dnp->properties.listp;
		for (i = 0; i < dnp->properties.num; i++) {
			switch (pep->utype) {
			case PE_none:
				break;
			case PE_string:
				break;
			case PE_int:
				break;
			case PE_arc:
				if (strcmp(output_dot_dagp, pep->namep) == 0) {
					fprintf(fp, "%s ->\n",
					    sanity_name(dnp->namep));
					fprintf(fp, "%s\n",
					    sanity_name(pep->u.dnp->namep));
				}
				break;
			case PE_noderef:
				fatal("Internal error noderefs should all \
be resolved");
				break;
			}
			pep ++;
		}
	}

	fprintf(fp, "}\n");
	fflush(fp);
}
