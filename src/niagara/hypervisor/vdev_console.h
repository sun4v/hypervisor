/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _VDEV_CONSOLE_H
#define	_VDEV_CONSOLE_H

#pragma ident	"@(#)vdev_console.h	1.3	05/06/30 SMI"

#ifndef _ASM

struct console {
#ifdef CONFIG_CN_SVC
	uint64_t	vintr_arg; /* vintr cookie */
	uint64_t	svcp;   /* pointer to svc */
	uint64_t	pending;   /* pointer to svc when pkt outstanding */
	int8_t		chars_avail; /* chars still in pkt */
	uint8_t		tbsy;	/* transmitter busy optimization */
#else
	uint64_t	base; /* console base address */
#endif
};

#endif /* !_ASM */

#endif /* _VDEV_CONSOLE_H */
