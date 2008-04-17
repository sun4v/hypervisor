/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _MD_MD_IMPL_H
#define	_MD_MD_IMPL_H

#pragma ident	"@(#)md_impl.h	1.4	05/03/31 SMI"

#ifdef __cplusplus
extern "C" {
#endif

	/*
	 * Each logical domain is detailed via a (Virtual) Machine Description
	 * available to each guest Operating System courtesy of a
	 * Hypervisor service.
	 *
	 * A complete Machine Description (MD) is built from a very
	 * simple list of descriptor table (DT) elements.
	 *
	 */


#define	MD_TRANSPORT_VERSION	0x10000 /* the version this library generates */

#define	DT_ILLEGAL_IDX	((uint64_t)-1)

#define	DT_LIST_END	0x0
#define	DT_NULL		' '
#define	DT_NODE		'N'
#define	DT_NODE_END	'E'
#define	DT_PROP_ARC	'a'
#define	DT_PROP_VAL	'v'
#define	DT_PROP_STR	's'
#define	DT_PROP_DAT	'd'
#define	MDET_NULL	DT_NULL
#define	MDET_NODE	DT_NODE
#define	MDET_NODE_END	DT_NODE_END
#define	MDET_PROP_ARC	DT_PROP_ARC
#define	MDET_PROP_VAL	DT_PROP_VAL
#define	MDET_PROP_STR	DT_PROP_STR
#define	MDET_PROP_DAT	DT_PROP_DAT

#ifndef _ASM
/*
 * Each MD has the following header to
 * provide information about each section of the MD.
 *
 * The header fields are actually written in network
 * byte order.
 */

struct md_header {
	uint32_t	transport_version;
	uint32_t	node_blk_sz;	/* size in bytes of the node block */
	uint32_t	name_blk_sz;	/* size in bytes of the name block */
	uint32_t	data_blk_sz;	/* size in bytes of the data block */
};

typedef struct md_header md_hdr_t;
typedef struct md_header md_header_t;

/*
 * This is the handle that represents the description
 *
 * While we are building the nodes the data and name tags in the nodes
 * are in fact indexes into the table arrays.
 *
 * When we 'end nodes' the dtheader is added, and the data rewritten
 * into the binary form.
 *
 */
struct dthandle {
	char		**nametable;
	uint8_t		**datatable;
	int		namesize;
	int		datasize;
	int		nodesize;
	int		nameidx;
	int		dataidx;
	int		namebytes;
	int		databytes;
	int		nodeentries;
	int		preload;
	struct dtnode 	*root;
	int 		lastnode;
};
typedef struct dthandle dthandle_t;

/*
 * With this model there are 3 sections
 * the description, the name table and the data blocks.
 * the name and data entries are offsets from the
 * base of their blocks, this makes it possible to extend the segments.
 *
 * For 'node' tags, the data is the index to the next node, not a data
 * offset.
 *
 * All values are stored in network byte order.
 * The namelen field holds the storage length of a ASCIIZ name, NOT the strlen.
 */

struct md_element {
	uint8_t 	tag;
	uint8_t		namelen;
	uint32_t	name;
	union {
		struct	{
			uint32_t	len;
			uint32_t	offset;
		} prop_data;		/* for PROP_DATA and PROP_STR */
		uint64_t prop_val;	/* for PROP_VAL */
		uint64_t prop_idx;	/* for PROP_ARC and NODE */
	} d;
};

	/* FIXME: dtnode_t to be renamed as md_element_t */
typedef struct md_element dtnode_t;
typedef struct md_element md_element_t;
#define	MD_ELEMENT_SIZE	16

#endif /* !_ASM */

#ifdef __cplusplus
}
#endif

#endif /* _MD_MD_IMPL_H */
