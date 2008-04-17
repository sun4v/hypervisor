/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _NIAGARA_CYCLIC_H
#define	_NIAGARA_CYCLIC_H

#pragma ident	"@(#)cyclic.h	1.2	05/08/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif


/*
 * HStick Interrupt:
 */
#define	N_CB		16		/* # callback array elements */

#define	RETURN_HANDLER_ADDRESS(scr1)	/* relocation independent code */  \
	rd	%pc, scr1		/* handler starts after these */  ;\
	jmp	%g7 + SZ_INSTR		/*  three instructions */	  ;\
	  inc	3 * SZ_INSTR, scr1

/*
 * HStick Interrupt execution times.
 *
 * These are used in an attempt to exit hypervisor to guest code
 * and make some progress before the next interrupt. It is a fail-safe that
 * prevents a runaway callback from totally consuming the cpu.
 *
 * Number ticks needed to:	
 */
#define	EXIT_NTICK	0x800	/* exit to guest: measured @ 240 - 3f0 */
#define	HSTICK_RET	0x100	/* set new hstick_cmpr & return */

/*
 * Maximum delay time allowed
 */
#define	CYCLIC_MAX_DAYS		367		/* 1 yr + 1 day */


#ifndef _ASM

/*
 * hstick interrupt support:
 *
 * This struct holds the registered handler & number of ticks required
 * to delay, and two args to be passed to the callback handler.
 *
 * Note: handlers that take a long time are not acounted for (yet?).
 */
struct callback {
	uint64_t		tick;		/* delta tick	   */
	uint64_t		handler;	/* handler address */
	uint64_t		arg0;		/* handler args	   */
	uint64_t		arg1;		/*	..	   */
};

struct cyclic_cpu_state {
	uint64_t		t0;		/* absolute time reference  */
	struct callback		cb[N_CB+1];	/* cyclic callback handlers */
	uint64_t		tick;		/* tmp storage              */
	uint64_t		handler;	/*	..		    */
	uint64_t		arg0;		/*	..		    */
	uint64_t		arg1;		/*	..		    */
};


#endif /* !_ASM */

#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA_CYCLIC_H */
