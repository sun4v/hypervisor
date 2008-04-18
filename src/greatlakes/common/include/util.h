/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: util.h
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

#ifndef _UTIL_H
#define	_UTIL_H

#pragma ident	"@(#)util.h	1.13	06/05/26 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Size generation constants
 */
#define	KB	* 1024
#define	MB	* 1024LL KB
#define	GB	* 1024LL MB

/*
 * Time constants
 */
#define	MHZ		* 1000000
#define	NS_PER_S	1000000000
#define	MS_PER_NS	1000000



/* BEGIN CSTYLED */

/*
 * CPU2GUEST_STRUCT - get the current guestp from a cpup
 *
 * Delay Slot: safe in a delay slot
 * Register overlap: cpu and root may be the same register
 */
#define	CPU2GUEST_STRUCT(cpu, guest)		\
	ldx	[cpu + CPU_GUEST], guest


/*
 * CPU2ROOT_STRUCT - get the rootp from a cpup
 *
 * Delay Slot: safe in a delay slot if cpup is valid
 * Register overlap: cpu and root may be the same register
 */
#define	CPU2ROOT_STRUCT(cpu, root)		\
	ldx	[cpu + CPU_ROOT], root


/*
 * CPU_STRUCT - get the current cpup from scratch
 *
 * Delay Slot: safe in a delay slot
 */
#define	CPU_STRUCT(cpu)				\
	mov	HSCRATCH0, cpu			;\
	ldxa	[cpu]ASI_HSCRATCHPAD, cpu

/*
 * ROOT_STRUCT - get the current rootp from scratch
 *
 * Delay Slot: safe in a delay slot
 */
#define	ROOT_STRUCT(root)			\
	CPU_STRUCT(root)			;\
	ldx	[root + CPU_ROOT], root


/*
 * LOCK_ADDR - get the lock address from scratch
 *
 * Delay Slot: not safe in a delay slot
 */
#define	LOCK_ADDR(LOCK, addr)			\
	ROOT_STRUCT(addr)			;\
	inc	LOCK, addr


/*
 * CPU_GUEST_STRUCT - get both the current cpup and guestp from scratch
 *
 * Delay Slot: safe in a delay slot
 * Register overlap: if cpu and guest are the same then only the guest
 *     is returned, see GUEST_STRUCT
 */
#define	CPU_GUEST_STRUCT(cpu, guest)		\
	CPU_STRUCT(cpu)				;\
	CPU2GUEST_STRUCT(cpu, guest)


/*
 * GUEST_STRUCT - get the current guestp from scratch
 *
 * Delay Slot: safe in a delay slot
 */
#define	GUEST_STRUCT(guest)			\
	CPU_GUEST_STRUCT(guest, guest)


/*
 * PID2CPUP - convert physical cpu number to a pointer to the physical
 * cpu structure.
 *
 * Register overlap: pid and cpup may be the same register.
 * Delay Slot: safe in a delay slot
 */
#define	PID2CPUP(pid, cpup, scr1)			\
	set	CPU_SIZE, scr1				;\
	mulx	pid, scr1, cpup				;\
	ROOT_STRUCT(scr1)				;\
	ldx	[scr1 + CONFIG_CPUS], scr1		;\
	add	scr1, cpup, cpup

/*
 * VCPUID2CPUP - convert virtual cpu number to a pointer to the current
 * physical cpu struct
 *
 * Register overlap: vcpuid and cpup may be the same register
 * Delay Slot: safe in a delay slot
 */
#define	VCPUID2CPUP(guestp, vcpuid, cpup, fail_label, scr1)	\
	cmp	vcpuid, NCPUS				;\
	bgeu,pn	%xcc, fail_label			;\
	sllx	vcpuid, 3, cpup				;\
	set	GUEST_VCPUS, scr1			;\
	add	cpup, scr1, cpup			;\
	ldx	[guestp + cpup], cpup			;\
	brz,pn	cpup, fail_label			;\
	nop

/* the above macro assumes the array step is 8 */
#if GUEST_VCPUS_INCR != 8
#error "GUEST_VCPUS_INCR is not 8"
#endif

/*
 * VCOREID2COREP - convert virtual core number to a pointer to the
 * current physical core struct
 *
 * Register overlap: vcoreid and corep may be the same register
 * Delay Slot: safe in a delay slot
 */
#define	VCOREID2COREP(guestp, vcoreid, corep, fail_label, scr1)	\
	cmp	vcoreid, NCORES				;\
	bgeu,pn	%xcc, fail_label			;\
	sllx	vcoreid, 3, corep			;\
	set	GUEST_VCORES, scr1			;\
	add	corep, scr1, corep			;\
	ldx	[guestp + corep], corep			;\
	brz,pn	corep, fail_label			;\
	nop

/* the above macro assumes the array step is 8 */
#if GUEST_VCORES_INCR != 8
#error "GUEST_VCORES_INCR is not 8"
#endif


/*
 * PCPUID2COREID - derive core id from physical cpu id
 *
 * Register overlap: pid and coreid may be the same register
 * Delay slot: safe and complete in a delay slot
 */
#define	PCPUID2COREID(pid, coreid) \
	srlx	pid, CPUID_2_COREID_SHIFT, coreid


/*
 * CPU2CORE_STRUCT - obtain core pointer from cpu pointer
 *
 * Register overlap: cpu and core may be the same register
 * Delay Slot: safe in a delay slot
 */
#define	CPU2CORE_STRUCT(cpu, core)		\
	ldx	[cpu + CPU_CORE], core

/*
 * CORE_STRUCT - obtain core pointer
 *
 * Delay Slot: safe in a delay slot
 */
#define	CORE_STRUCT(core)			\
	CPU_STRUCT(core)			;\
	CPU2CORE_STRUCT(core, core)


/*
 * Standard return-from-hcall with status "errno"
 */
#define	HCALL_RET(errno)			\
	mov	errno, %o0			;\
	done

/*
 * HVCALL - make a subroutine call
 * HVRET - return from a subroutine call
 *
 * This hypervisor has a convention of using %g7 as the the
 * return address.
 */
#define	HVCALL(x)				\
	ba,pt	%xcc, x				;\
	rd	%pc, %g7

#define	HVRET					\
	jmp	%g7 + SZ_INSTR			;\
	nop

/*
 * CPU Stack operations
 *
 * CPU_PUSH - push a val into the stack
 * CPU_POP - pop val from the stack
 *
 */
#define CPU_PUSH(val, scr1, scr2, scr3)					\
	CPU_STRUCT(scr1)						;\
	set	TOP, scr2						;\
	ldx	[scr1 + scr2], scr2	/* get top of stack*/		;\
	add	scr2, STACK_VAL_INCR, scr2	/* next element */	;\
	set	CPU_STACK + STACK_VAL, scr3	/* is stack full? */	;\
	add	scr3, scr1, scr3					;\
	add	scr3, ENDOFSTACK, scr3					;\
	cmp	scr2, scr3						;\
	bge,a	%xcc, hvabort						;\
	mov	ABORT_STACK_OVERFLOW, %g1				;\
	set	TOP, scr3						;\
	stx	scr2, [scr1 + scr3]					;\
	stx	val, [scr2]
	

#define	CPU_POP(val, scr1, scr2, scr3)					\
	CPU_STRUCT(scr1)						;\
	set	TOP, scr2						;\
	ldx	[scr1 + scr2], scr2	/* get top of stack */		;\
	ldx	[scr2], val		/* get top element */ 		;\
	sub	scr2, STACK_VAL_INCR, scr2	/* dec stack */		;\
	set	CPU_STACK + STACK_VAL_INCR, scr3			;\
	add	scr1, scr3, scr3		/* begining of stack */	;\
	cmp	scr2, scr3						;\
	blu,a	%xcc, hvabort						;\
	mov	ABORT_STACK_UNDERFLOW, %g1				;\
	set	TOP, scr3		/* set new top */		;\
	stx	scr2, [scr1 + scr3]


/*
 * ATOMIC_OR_64 - atomically logical-or a value in a memory location
 */
#define	ATOMIC_OR_64(addr, value, scr1, scr2)	\
	.pushlocals				;\
	ldx	[addr], scr1			;\
0:	or	scr1, value, scr2		;\
	casx	[addr], scr1, scr2		;\
	cmp	scr1, scr2			;\
	bne,a,pn %xcc, 0b			;\
	mov	 scr2, scr1			;\
	.poplocals

/*
 * ATOMIC_ANDN_64 - atomically logical-andn a value in a memory location
 * Returns oldvalue 
 */
#define	ATOMIC_ANDN_64(addr, value, oldvalue, scr2) \
	.pushlocals				;\
	ldx	[addr], oldvalue		;\
0:	andn	oldvalue, value, scr2		;\
	casx	[addr], oldvalue, scr2		;\
	cmp	oldvalue, scr2			;\
	bne,a,pn %xcc, 0b			;\
	mov	 scr2, oldvalue			;\
	.poplocals

/*
 * ATOMIC_SWAP_64 - swaps the value at addr with newvalue, returns
 * the previous contents of addr as oldvalue
 */
#define	ATOMIC_SWAP_64(addr, newvalue, oldvalue, scr2)	\
	.pushlocals				;\
	ldx	[addr], scr2			;\
0:	mov	newvalue, oldvalue		;\
	casx	[addr], scr2, oldvalue		;\
	cmp	scr2, oldvalue			;\
	bne,a,pn %xcc, 0b			;\
	  mov	 oldvalue, scr2			;\
	.poplocals

/*
 * ATOMIC_ADD_64 - atomically add to a value stored in memory
 */
#define	ATOMIC_ADD_64(addr, value, newvalue, scr2)	\
	.pushlocals				;\
	ldx	[addr], newvalue		;\
0:	add	newvalue, value, scr2		;\
	casx	[addr], newvalue, scr2		;\
	cmp	newvalue, scr2			;\
	bne,a,pn %xcc, 0b			;\
	  mov	 scr2, newvalue			;\
	add	 newvalue, value, newvalue	;\
	.poplocals

/*
 * Locking primitives
 */


#define	MEMBAR_ENTER \
	/* membar #StoreLoad|#StoreStore not necessary on Niagara */
#define	MEMBAR_EXIT \
	/* membar #LoadStore|#StoreStore not necessary on Niagara */

/*
 * SPINLOCK_ENTER - claim lock by setting it to cpu#+1 spinning until it is
 *	free
 */
#define	SPINLOCK_ENTER(lock, scr1, scr2)				\
	.pushlocals							;\
	CPU_STRUCT(scr1)						;\
	ldub	[scr1 + CPU_PID], scr2	/* my ID */			;\
	inc	scr2			/* lockID = cpuid + 1 */ 	;\
1:	mov	scr2, scr1						;\
	casx	[lock], %g0, scr1	/* if zero, write my lockID */	;\
	brnz,pn	scr1, 1b						;\
	nop								;\
	MEMBAR_ENTER							;\
	.poplocals

/*
 * SPINLOCK_EXIT - release lock
 */
#define	SPINLOCK_EXIT(lock)						;\
	MEMBAR_EXIT					       		;\
	stx	%g0, [lock]

#define	IS_CPU_IN_ERROR(cpup, scr1)					\
	ldx	[cpup + CPU_STATUS], scr1				;\
	cmp	scr1, CPU_STATE_ERROR

/*
 * LABEL_ADDRESS(label, reg)
 *
 * Args:
 *      label - assembler label
 *      reg - will hold the address of the label
 *
 * Calculate the (relocated) address of the target label.  Only
 * works if the target label is no more than 4092 bytes away from
 * the current assembly origin.  Also requires that the label be
 * in the same source file, and in the same section as the macro
 * invokation.
 */
#define LABEL_ADDRESS(label, reg)		\
	.pushlocals				;\
0:	rd	%pc, reg			;\
	add	reg, (label) - 0b, reg		;\
	.poplocals


/*
 * RELOC_OFFSET(scr, reg)
 *
 * Args:
 *      scr - scratch register, different from "reg"
 *      reg - will hold the value of the relocation offset
 *
 * Calculates the offset of the current image relative to the
 * address assigned by the linker.  The returned offset value can be
 * subtracted from labels calcuated with "setx" to obtain the actual
 * address after relocation.
 */
#define RELOC_OFFSET(scr, reg)					\
	.pushlocals						;\
	setx	0f, scr, reg		/* reg = linker */	;\
0:	rd	%pc, scr		/* scr = actual */	;\
	sub	reg, scr, reg		/* reg = l - a */	;\
	.poplocals


/*
 * SMALL_COPY_MACRO - byte-wise copy a small region of memory.
 *
 * Args:
 *      src - starting address
 *      len - length of region to copy
 *	dest - destination address
 *	scr - scratch
 *
 * All arguments are clobbered.
 */
#define	SMALL_COPY_MACRO(src, len, dest, scr) \
	.pushlocals		;\
1:	ldub	[src], scr	;\
	inc	src		;\
	deccc	len		;\
	stb	scr, [dest]	;\
	bnz,pt	%xcc, 1b	;\
	  inc	dest		;\
	.poplocals


/* END CSTYLED */


#ifdef __cplusplus
}
#endif

#endif /* _UTIL_H */
