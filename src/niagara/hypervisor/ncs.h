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
