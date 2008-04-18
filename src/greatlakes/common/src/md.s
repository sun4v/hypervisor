/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: md.s
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
 * Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

	.ident	"@(#)md.s	1.5	06/04/26 SMI"

	.file	"md.s"

/*
 * Partition Description scanner routines
 */

#include <sys/asm_linkage.h>
#include <hypervisor.h>
#include <sparcv9/misc.h>
#include <asi.h>
#include <mmu.h>
#include <sun4v/traps.h>
#include <sun4v/asi.h>

#include <config.h>
#include <guest.h>
#include <offsets.h>
#include <md.h>


/*
 * Find the offset of a string in the name table
 *
 * In
 * %g1 is the hypervisor description
 * %g2 is a pointer to the name
 * %g7 return address
 *
 * Out
 * %g1 is the name offset or -1
 *
 * Volatile:	%globals, %outs
 */
#define	NEXT_STRING(base, offset, scr)	\
	.pushlocals			;\
	inc	offset			;\
1:	ldub	[base + offset], scr	;\
	brnz,pt	scr, 1b			;\
	inc	offset			;\
	.poplocals

#define	STRCMP(str1, str2, scr1, scr2, scr3) \
	.pushlocals			;\
	mov	0, scr1			;\
1:	ldub	[str1 + scr1], scr2	;\
	ldub	[str2 + scr1], scr3	;\
	cmp	scr2, scr3		;\
	bne,pn	%xcc, 2f		;\
	nop				;\
	brnz,pt	scr2, 1b		;\
	inc	scr1			;\
2:					;\
	.poplocals

#define	STRLEN(str, len, scr1)		\
	.pushlocals			;\
	mov	0, len			;\
1:	ldub	[str + len], scr1	;\
	brnz,pt	scr1, 1b		;\
	inc	len			;\
2:	dec	len			;\
	.poplocals

	ENTRY_NP(pd_findname)
	!! %g1 hd
	lduw	[%g1 + DTHDR_NODESZ], %g3
	add	%g1, %g3, %g3
	add	%g3, DTHDR_SIZE, %g3		! skip the hdr
	!! %g3 start of nametable
	mov	0, %g4
	!! %g4 current offset into nametable

1:	add	%g3, %g4, %g5
	STRCMP(%g2, %g5, %o0, %o1, %o2)
	beq	2f
	nop
	/* adjust %g4 to point to next NUL+1 */
	NEXT_STRING(%g3, %g4, %g5)
	lduw	[%g1 + DTHDR_NAMES], %g5
	cmp	%g4, %g5
	blu,pn	%xcc, 1b
	nop
	/* not found, return -1 */
	jmp	%g7 + 4	
	mov	-1, %g1

2:	/* found it */

	/* Make nameoffset/namelen component of tag */
	STRLEN(%g5, %g1, %o0)
	sllx	%g1, 48, %g1
	jmp	%g7 + 4	
	or	%g1, %g4, %g1
	SET_SIZE(pd_findname)


/*
 * This code assumes the only data type that HV cares about will be 'ints'.
 * It also assumes that you are using the fixed name encoding - if your
 * tagname is not in preload.names then you should add it otherwise it might
 * change its offset.
 */

#define r_tmp1	%g4
#define r_tmp2	%g5
#define r_pd	%g6

	! In
	!   %g1 is the 'name' of the node you want.
	!   %g2 is the hypervisor description
	! Out
	!   %g1 is the node.
	!   condition code 'equal 0' means success.
	ENTRY_NP(pd_findnode)
	add	%g2, DTHDR_SIZE, r_pd		! skip the hdr
1:	ldx	[r_pd + DTNODE_TAG], r_tmp1	! get name+len+offset
	cmp	r_tmp1, %g1			! match?
	beq,pn	%xcc, 9f
	  ldx	[r_pd + DTNODE_DATA], r_tmp2	! get data
	srl	r_tmp2, 0, r_tmp2		! reduce to 32bit offset
	mulx	r_tmp2, DTNODE_SIZE, r_tmp2
	brnz,pt	r_tmp1, 1b
	  add	%g2, r_tmp2, r_pd		! next node
	mov	%g0, %g1
	jmp	%g7 + 4
	  cmp	%g0, 1				! Not Found (CC!=0)
9:	mov	r_pd, %g1
	jmp	%g7 + 4
	  cmp	%g0, 0				! Found.
	SET_SIZE(pd_findnode)

	! In
	!   %g1 is the node pointer
	!   %g2 is the tag you want
	!   %g3 hypervisor description
	! Out
	!   %g1 = value
	!   condition code 'equal 0' means success.
	ENTRY_NP(pd_getprop)
	add	%g1, DTNODE_SIZE, %g1		! skip the 'node', first prop.
1:	ldx	[%g1 + DTNODE_TAG], r_tmp1
	cmp	r_tmp1, %g2			! match?
	beq,pn	%xcc, 9f
	  ldx	[%g1 + DTNODE_DATA], r_tmp2	! get data
	srlx	r_tmp1, 56, r_tmp1		! get the Tag type
	cmp	r_tmp1, MDET_NODE_END
	bne,pt	%xcc, 1b			! list end
	  add	%g1, DTNODE_SIZE, %g1		! next prop
	mov	%g0, %g1
	jmp	%g7 + 4
	  cmp	%g0, 1				! Not Found (CC!=0)
9:	srlx	%g2, 56, %g2			! get the tag
	cmp	%g2, MDET_PROP_VAL
	beq,pt	%xcc, 1f			! XXX Assume a REF...
	  mov	r_tmp2, %g1			! data in %g1
	add	%g3, DTHDR_SIZE, r_tmp2		! skip the hdr
	srl	%g1, 0, %g1			! node id
	mulx	%g1, DTNODE_SIZE, %g1
	add	%g1, r_tmp2, %g1		! data is nodeptr
1:	jmp	%g7 + 4
	  cmp	%g0, 0				! Found.
	SET_SIZE(pd_getprop)

	! Save some effort in callers..
	! combine the findnode and getprop routines
	!
	! In
	!   %g1 is the 'name' of the node you want.
	!   %g2 is the 'prop' in the node
	!   %g3 is the hypervisor description
	! Out
	!   %g1 is the data.
	!   condition code 'equal 0' means success.
	ENTRY_NP(pd_getnodeprop)
	add	%g3, DTHDR_SIZE, r_pd		! skip the hdr
1:	ldx	[r_pd + DTNODE_TAG], r_tmp1	! get name+len+offset
	cmp	r_tmp1, %g1			! match?
	beq,pn	%xcc, 9f
	  ldx	[r_pd + DTNODE_DATA], r_tmp2	! get data
	sll	r_tmp2, 0, r_tmp2		! reduce to 32bit offset
	mulx	r_tmp2, DTNODE_SIZE, r_tmp2
	brnz,pt	r_tmp1, 1b
	  add	%g3, r_tmp2, r_pd		! next node
	mov	%g0, %g1
	jmp	%g7 + 4
	  cmp	%g0, 1				! Not Found (CC!=0)
9:	mov	r_pd, %g1
	add	%g1, DTNODE_SIZE, %g1		! skip the 'node', first prop.
1:	ldx	[%g1 + DTNODE_TAG], r_tmp1
	cmp	r_tmp1, %g2			! match?
	beq,pn	%xcc, 9f
	  ldx	[%g1 + DTNODE_DATA], r_tmp2	! get data
	srlx	r_tmp1, 56, r_tmp1		! get the Tag type
	cmp	r_tmp1, MDET_NODE_END
	bne,pt	%xcc, 1b			! list end
	  add	%g1, DTNODE_SIZE, %g1		! next prop
	mov	%g0, %g1
	jmp	%g7 + 4
	  cmp	%g0, 1				! Not Found (CC!=0)
9:	srlx	%g2, 56, %g2			! get the tag
	cmp	%g2, MDET_PROP_VAL
	beq,pt	%xcc, 1f
	  mov	r_tmp2, %g1			! data in %g1
	add	%g3, DTHDR_SIZE, r_tmp2		! skip the hdr
	srl	%g1, 0, %g1			! node id
	mulx	%g1, DTNODE_SIZE, %g1
	add	%g1, r_tmp2, %g1		! data is nodeptr
1:	jmp	%g7 + 4
	  cmp	%g0, 0				! Found.
	SET_SIZE(pd_getnodeprop)

	! In
	!   %g1 is the node pointer
	!   %g2 is the current offset (0 initially)
	!   %g3 is the tag you want
	!   %g4 hypervisor description
	! Out
	!   %g1 = value
	!   %g2 = new offset if success
	!   condition code 'equal 0' means success.
	ENTRY_NP(pd_getnodemultprop)
	mov	%g4, r_pd
	brnz	%g2, 1f
	nop
	add	%g1, DTNODE_SIZE, %g2		! skip the 'node', first prop.
1:	ldx	[%g2 + DTNODE_TAG], r_tmp1
	cmp	r_tmp1, %g3			! match?
	beq,pn	%xcc, 9f
	  ldx	[%g2 + DTNODE_DATA], %g1	! get data
	srlx	r_tmp1, 56, r_tmp1		! get the Tag type
	cmp	r_tmp1, MDET_NODE_END
	bne,pt	%xcc, 1b			! list end
	  add	%g2, DTNODE_SIZE, %g2		! next prop
	mov	%g0, %g1
	jmp	%g7 + 4
	  cmp	%g0, 1				! Not Found (CC!=0)
9:	srlx	%g3, 56, %g3			! get the tag
	cmp	%g3, MDET_PROP_VAL
	beq,pt	%xcc, 1f			! XXX Assume a REF...
	  nop
	add	r_pd, DTHDR_SIZE, r_tmp2	! skip the hdr
	srl	%g1, 0, %g1			! node id
	mulx	%g1, DTNODE_SIZE, %g1
	add	%g1, r_tmp2, %g1		! data is nodeptr
1:
	add	%g2, DTNODE_SIZE, %g2		! next offset
	jmp	%g7 + 4
	  cmp	%g0, 0				! Found.
	SET_SIZE(pd_getnodemultprop)
