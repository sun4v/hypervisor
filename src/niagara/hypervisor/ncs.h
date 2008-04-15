/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: ncs.h
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

#ifndef	_NCS_H
#define	_NCS_H

#pragma ident	"@(#)ncs.h	1.1	05/04/12 SMI"

#ifdef	__cplusplus
extern "C" {
#endif

#include <ncs_api.h>

#ifndef	_ASM
/*
 * Queuing structure used by crypto hypervisor support
 * to represent queue of requests for MA unit.  Kernel
 * side inserts requests into the queue which are
 * subsequently picked up in the context of the
 * hypervisor.
 *
 * Struct is globally kept in a per-MAU array.
 * NCS code indexes into appropriate queue
 * using the Core ID of the Core on which
 * it's running at the time.
 */

typedef struct mau_queue {
	uint64_t	mq_id;
	uint64_t	mq_busy;
	uint64_t	mq_base;
	uint64_t	mq_end;
	uint64_t	mq_head;
	uint64_t	mq_tail;
	uint64_t	mq_nentries;
} mau_queue_t;

#endif	/* _ASM */

#ifdef	__cplusplus
}
#endif

#endif	/* _NCS_H */
