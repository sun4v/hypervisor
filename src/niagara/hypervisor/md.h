/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _PD_H
#define	_PD_H

#pragma ident	"@(#)md.h	1.3	05/03/31 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <md/md_impl.h>


#define	LOOKUP_TAG_NODE(config,tag,value,scr) 		\
	mov	MDET_NODE, scr				;\
	sllx	scr, 56, scr				;\
	add	config, tag, value			;\
	ldx	[value + CONFIG_HDNAMETABLE], value	;\
	or	value, scr, value

#define	LOOKUP_TAG_PROP_VAL(config,tag,value,scr) 	\
	mov	MDET_PROP_VAL, scr				;\
	sllx	scr, 56, scr				;\
	add	config, tag, value			;\
	ldx	[value + CONFIG_HDNAMETABLE], value	;\
	or	value, scr, value

#define	LOOKUP_TAG_PROP_ARC(config,tag,value,scr) 	\
	mov	MDET_PROP_ARC, scr				;\
	sllx	scr, 56, scr				;\
	add	config, tag, value			;\
	ldx	[value + CONFIG_HDNAMETABLE], value	;\
	or	value, scr, value

/* regusage: %g1-%g7 */
#define	GETPROP_BY_TAG(hd,node_reg,prop)	\
	mov	node_reg, %g1		;\
	mov	prop, %g2		;\
	mov	hd, %g3			;\
	ba	pd_getprop		;\
	rd	%pc, %g7

/* regusage: %g1-%g7 */
#define	GETNODEMULTPROPR_BY_TAG(hd,offset,node,prop) \
	mov	node, %g1		;\
	mov	offset, %g2		;\
	mov	prop, %g3		;\
	mov	hd, %g4			;\
	ba	pd_getnodemultprop	;\
	rd	%pc, %g7

#define	GETNODEPROP_BY_TAG(hd,node,prop) \
	mov	node, %g1		;\
	mov	prop, %g2		;\
	mov	hd, %g3			;\
	ba	pd_getnodeprop		;\
	rd	%pc, %g7

/* regusage: %g1-%g7 */
#define	TGETVAL(config, hvd, node, hdname, scr1, scr2) \
	LOOKUP_TAG_PROP_VAL(config, hdname, scr1, scr2);\
	GETPROP_BY_TAG(hvd, node, scr1)
#define	TGETARC(config, hvd, node, hdname, scr1, scr2) \
	LOOKUP_TAG_PROP_ARC(config, hdname, scr1, scr2);\
	GETPROP_BY_TAG(hvd, node, scr1)
#define	TGETARCMULT(config, hvd, offset, node, hdname, scr1, scr2) \
	LOOKUP_TAG_PROP_ARC(config, hdname, scr1, scr2);\
	GETNODEMULTPROPR_BY_TAG(hvd, offset, node, scr1)


#ifdef __cplusplus
}
#endif

#endif /* _PD_H */
