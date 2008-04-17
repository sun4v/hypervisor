/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 *
 */

#ifndef	_DAGTYPES_H
#define	_DAGTYPES_H

#pragma ident	"@(#)dagtypes.h	1.1	05/03/31 SMI"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct DAG_NODE dag_node_t;
#define	MAX_DATALEN 	128

typedef struct {
	char	*namep;
	enum { PE_none, PE_string, PE_int, PE_arc, PE_noderef, PE_data } utype;

	void	*name_tmp;	/* used for output */

	union {
		char	*strp;	/* string & noderef */
		uint64_t val;
		dag_node_t *dnp;
		struct {
			int len;
			uint8_t buffer[MAX_DATALEN];
		} data;
	} u;

	void	*data_tmp;	/* used for output */
} pair_entry_t;


typedef struct {
	int	num;
	int	space;
	pair_entry_t *listp;
} pair_list_t;


struct DAG_NODE {
	char	*typep;
	char	*namep;
	int	idx;
	int	offset;	/* used when computing node links for output */
	int	proto;

	void	*name_tmp;	/* used for output */

	pair_list_t properties;

	dag_node_t *prevp;
	dag_node_t *nextp;
};


	/*
	 * DAG globals
	 */

extern dag_node_t *dag_listp;
extern dag_node_t *dag_list_endp;

	/*
	 * Support functions
	 */

extern void validate_dag(void);
extern dag_node_t *new_dag_node(void);
extern pair_entry_t *add_pair_entry(pair_list_t *plp);
extern pair_entry_t *find_pair_by_name(pair_list_t *plp, char *namep);
extern dag_node_t *find_dag_node_by_type(char *namep);
extern dag_node_t *find_dag_node_by_name(char *namep);
extern dag_node_t *grab_node(char *message);
extern pair_entry_t *grab_prop(char *message, dag_node_t *node);
extern void dump_dag_nodes(FILE *fp);


#ifdef __cplusplus
}
#endif

#endif	/* _DAGTYPES_H */
