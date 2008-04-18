/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: md.h
* 
* Copyright (c) 2006 Sun Microsystems, Inc. All Rights Reserved.
* 
*  - Do no alter or remove copyright notices
* 
*  - Redistribution and use of this software in source and binary forms, with 
*    or without modification, are permitted provided that the following 
*    conditions are met: 
* 
*  - Redistribution of source code must retain the above copyright notice, 
*    this list of conditions and the following disclaimer.
* 
*  - Redistribution in binary form must reproduce the above copyright notice,
*    this list of conditions and the following disclaimer in the
*    documentation and/or other materials provided with the distribution. 
* 
*    Neither the name of Sun Microsystems, Inc. or the names of contributors 
* may be used to endorse or promote products derived from this software 
* without specific prior written permission. 
* 
*     This software is provided "AS IS," without a warranty of any kind. 
* ALL EXPRESS OR IMPLIED CONDITIONS, REPRESENTATIONS AND WARRANTIES, 
* INCLUDING ANY IMPLIED WARRANTY OF MERCHANTABILITY, FITNESS FOR A 
* PARTICULAR PURPOSE OR NON-INFRINGEMENT, ARE HEREBY EXCLUDED. SUN 
* MICROSYSTEMS, INC. ("SUN") AND ITS LICENSORS SHALL NOT BE LIABLE FOR 
* ANY DAMAGES SUFFERED BY LICENSEE AS A RESULT OF USING, MODIFYING OR 
* DISTRIBUTING THIS SOFTWARE OR ITS DERIVATIVES. IN NO EVENT WILL SUN 
* OR ITS LICENSORS BE LIABLE FOR ANY LOST REVENUE, PROFIT OR DATA, OR 
* FOR DIRECT, INDIRECT, SPECIAL, CONSEQUENTIAL, INCIDENTAL OR PUNITIVE 
* DAMAGES, HOWEVER CAUSED AND REGARDLESS OF THE THEORY OF LIABILITY, 
* ARISING OUT OF THE USE OF OR INABILITY TO USE THIS SOFTWARE, EVEN IF 
* SUN HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
* 
* You acknowledge that this software is not designed, licensed or
* intended for use in the design, construction, operation or maintenance of
* any nuclear facility. 
* 
* ========== Copyright Header End ============================================
*/
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
