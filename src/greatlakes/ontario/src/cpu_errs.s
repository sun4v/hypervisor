/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: cpu_errs.s
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

	.ident	"@(#)cpu_errs.s	1.66	06/05/30 SMI"

	.file	"cpu_errs.s"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <sparcv9/misc.h>
#include <sparcv9/asi.h>
#include <asi.h>
#include <mmu.h>
#include <dram.h>
#include <hprivregs.h>
#include <sun4v/traps.h>
#include <sun4v/asi.h>
#include <sun4v/mmu.h>
#include <sun4v/queue.h>
#include <sun4v/errs_defs.h>
#include <fpga.h>

#include <offsets.h>
#include <cyclic.h>
#include <cpu.h>
#include <guest.h>
#include <config.h>
#include <cpu_errs.h>
#include <errs_common.h>
#include <util.h>
#include <debug.h>
#include <cpu_errs_defs.h>
#include <abort.h>


/*
 * HW issues err. HV attempts to handle the error where appropiate.
 * HV translates it to a sun4v format.  Sends it to the queue.
 */
/*
 * Macro that calls the function to dump the L2$ set diagnostic
 * data into the error report.
 * 	arg1 MUST be specified as %g1, used as arg1 to function
 *	arg2 MUST be specified as %g2, used as arg2 to function
 *	ret7 MUST be specified as %g7, used for return address
 *	scr1 is scratch register
 */
/* BEGIN CSTYLED */
#define	ASMCALL_DUMP_L2_DATA_FOR_CE(arg1, arg2, scr1, ret7)		\
	CPU_STRUCT(scr1)						;\
	add	scr1, CPU_CE_RPT, arg2	/* set %g2 to ce_rpt pointer */	;\
	add	arg2, CPU_EVBSC_L2_AFAR(0), arg1			;\
	ldx	[arg1], arg1		/* %g1 has physical address */	;\
	ba	dump_l2_set_tag_data_ecc				;\
	rd	%pc, ret7
/* END CSTYLED */

/* BEGIN CSTYLED */
#define	SET_CPU_IN_ERROR(scr1, scr2)					\
	CPU_STRUCT(scr1)						;\
	mov	CPU_STATE_ERROR, scr2					;\
	stx	scr2, [scr1 + CPU_STATUS]
/* END CSTYLED */

/*
 * Queue the UE error report as a resumable error to the guest
 */
/* BEGIN CSTYLED */
#define	ASMCALL_RQ_ERPT(E_OFFT, reg1, reg2, reg3, reg4, reg5, reg6, reg7)\
	PRINT("queue RESUMABLE\r\n")					;\
	CPU_STRUCT(reg1)						;\
	add	reg1, E_OFFT, reg2		/* erpt buf ptr */	;\
	ba	queue_resumable_erpt  /* %g1 = cpu, %g2 = erpt */	;\
	rd	%pc, reg7
/* END CSTYLED */

/*
 * The erpt pointer should be passed in %g6 as %g6 is preserved across
 * print routines. The second argument, reg1, should be %g1, which is
 * used as the argument to PRINTX.
 * Arguments:
 *	%g6 - as erpt - pointer to the cpu error buffer
 *	%g1 - as reg1
 * all registers are used.
 */
#ifdef	NIAGARA_BRINGUP
/* BEGIN CSTYLED */
#define	CONSOLE_PRINT_DIAG_ERPT(erpt, reg1)				\
	PRINT("ehdl = ")						;\
	ldx	[erpt + CPU_VBSC_ERPT + EVBSC_EHDL], reg1   /* ehdl */	;\
	PRINTX(reg1)							;\
	PRINT("\r\n")							;\
	PRINT("stick = ")						;\
	ldx	[erpt + CPU_VBSC_ERPT + EVBSC_STICK], reg1  /* stick */	;\
	PRINTX(reg1)							;\
	PRINT("\r\n")							;\
	PRINT("cpuver = ")						;\
	ldx	[erpt + CPU_VBSC_ERPT + EVBSC_CPUVER], reg1 /* cpuver */;\
	PRINTX(reg1)							;\
	PRINT("\r\n")							;\
	PRINT("sparc_afsr = ")						;\
	ldx	[erpt + CPU_VBSC_ERPT + EVBSC_SPARC_AFSR], reg1	/* sparc afsr */;\
	PRINTX(reg1)							;\
	PRINT("\r\n")							;\
	PRINT("sparc_afar = ")						;\
	ldx	[erpt + CPU_VBSC_ERPT + EVBSC_SPARC_AFAR], reg1	/* sparc afar */;\
	PRINTX(reg1)							;\
	PRINT("\r\n")							;\
	PRINT("L2 ESRs\r\n")						;\
	ldx	[erpt + CPU_EVBSC_L2_AFSR(0)], reg1			;\
	PRINTX(reg1)							;\
	PRINT("  ")							;\
	ldx	[erpt + CPU_EVBSC_L2_AFSR(1)], reg1			;\
	PRINTX(reg1)							;\
	PRINT("  ")							;\
	ldx	[erpt + CPU_EVBSC_L2_AFSR(2)], reg1			;\
	PRINTX(reg1)							;\
	PRINT("  ")							;\
	ldx	[erpt + CPU_EVBSC_L2_AFSR(3)], reg1			;\
	PRINTX(reg1)							;\
	PRINT("\r\n")							;\
	PRINT("L2 EARs\r\n")						;\
	ldx	[erpt + CPU_EVBSC_L2_AFAR(0)], reg1			;\
	PRINTX(reg1)							;\
	PRINT("  ")							;\
	ldx	[erpt + CPU_EVBSC_L2_AFAR(1)], reg1			;\
	PRINTX(reg1)							;\
	PRINT("  ")							;\
	ldx	[erpt + CPU_EVBSC_L2_AFAR(2)], reg1			;\
	PRINTX(reg1)							;\
	PRINT("  ")							;\
	ldx	[erpt + CPU_EVBSC_L2_AFAR(3)], reg1			;\
	PRINTX(reg1)							;\
	PRINT("\r\n")							;\
	PRINT("DRAM ESRs\r\n")						;\
	ldx	[erpt + CPU_EVBSC_DRAM_AFSR(0)], reg1			;\
	PRINTX(reg1)							;\
	PRINT("  ")							;\
	ldx	[erpt + CPU_EVBSC_DRAM_AFSR(1)], reg1 			;\
	PRINTX(reg1)							;\
	PRINT("  ")							;\
	ldx	[erpt + CPU_EVBSC_DRAM_AFSR(2)], reg1 			;\
	PRINTX(reg1)							;\
	PRINT("  ")							;\
	ldx	[erpt + CPU_EVBSC_DRAM_AFSR(3)], reg1 			;\
	PRINTX(reg1)							;\
	PRINT("\r\n")							;\
	PRINT("DRAM EARs\r\n")						;\
	ldx	[erpt + CPU_EVBSC_L2_AFAR(0)], reg1			;\
	PRINTX(reg1)							;\
	PRINT("  ")							;\
	ldx	[erpt + CPU_EVBSC_L2_AFAR(1)], reg1			;\
	PRINTX(reg1)							;\
	PRINT("  ")							;\
	ldx	[erpt + CPU_EVBSC_L2_AFAR(2)], reg1 			;\
	PRINTX(reg1)							;\
	PRINT("  ")							;\
	ldx	[erpt + CPU_EVBSC_L2_AFAR(3)], reg1 			;\
	PRINTX(reg1)							;\
	PRINT("\r\n")							;\
	PRINT("DRAM ELRs\r\n")						;\
	ldx	[erpt + CPU_EVBSC_DRAM_LOC(0)], reg1			;\
	PRINTX(reg1)							;\
	PRINT("  ")							;\
	ldx	[erpt + CPU_EVBSC_DRAM_LOC(1)], reg1			;\
	PRINTX(reg1)							;\
	PRINT("  ")							;\
	ldx	[erpt + CPU_EVBSC_DRAM_LOC(2)], reg1			;\
	PRINTX(reg1)							;\
	PRINT("  ")							;\
	ldx	[erpt + CPU_EVBSC_DRAM_LOC(3)], reg1			;\
	PRINTX(reg1)							;\
	PRINT("\r\n")							;\
	PRINT("DRAM ECRs\r\n")						;\
	ldx	[erpt + CPU_EVBSC_DRAM_CNTR(0)], reg1			;\
	PRINTX(reg1)							;\
	PRINT("  ")							;\
	ldx	[erpt + CPU_EVBSC_DRAM_CNTR(1)], reg1			;\
	PRINTX(reg1)							;\
	PRINT("  ")							;\
	ldx	[erpt + CPU_EVBSC_DRAM_CNTR(2)], reg1			;\
	PRINTX(reg1)							;\
	PRINT(" ")							;\
	ldx	[erpt + CPU_EVBSC_DRAM_CNTR(3)], reg1 			;\
	PRINTX(reg1)							;\
	PRINT("\r\n")							;\
	PRINT("tstate = ")						;\
	ldx	[erpt + CPU_VBSC_ERPT + EVBSC_TSTATE], reg1 /* tstate */;\
	PRINTX(reg1)							;\
	PRINT("\r\n")							;\
	PRINT("htstate = ")						;\
	ldx	[erpt + CPU_VBSC_ERPT + EVBSC_HTSTATE], reg1 /* htstate */;\
	PRINTX(reg1)							;\
	PRINT("\r\n")							;\
	PRINT("tpc = ")							;\
	ldx	[erpt + CPU_VBSC_ERPT + EVBSC_TPC], reg1     /* tpc */	;\
	PRINTX(reg1)							;\
	PRINT("\r\n")							;\
	PRINT("cpuid = ")						;\
	lduh	[erpt + CPU_VBSC_ERPT + EVBSC_CPUID], reg1   /* cpuid */;\
	PRINTX(reg1)							;\
	PRINT("\r\n")							;\
	PRINT("TT = ")							;\
	lduh	[erpt + CPU_VBSC_ERPT + EVBSC_TT], reg1		/* tt */;\
	PRINTX(reg1)							;\
	PRINT("\r\n")							;\
	PRINT("TL = ")							;\
	ldub	[erpt + CPU_VBSC_ERPT + EVBSC_TL], reg1		/* tl */;\
	PRINTX(reg1)							;\
	PRINT("\r\n")							;\
	PRINT("------END-------\r\n")
/* END CSTYLED */
#else	 /* NIAGARA_BRINGUP */
#define	CONSOLE_PRINT_DIAG_ERPT(erpt, reg1)
#endif	/* NIAGARA_BRINGUP */

	/*
	 * Correctable error traps can be taken only if PSTATE.IE = 1.
	 * The hypervisor is run with PSTATE.IE = 0, so no CE traps
	 * will be taken when running in hypervisor. Therefore, CE
	 * trap handler is entered only from supervisor which means:
	 *  - no need to check for %htstate.hpriv
	 *  - no need to check for %tstate.gl == MAXGL
	 * Assume the CE trap taken when executing in supervisor mode.
	 *      If TL > MAXPTL
	 *	then
	 *		watchdog_reset
	 *	else
	 *		handle error
	 *
	 * For CEs no error report is sent to the sun4v guest. Hence
	 * the sun4v guest error report members of the erpt struct
	 * are not filled in. Only the diagnostic error report is
	 * constructed and sent.
	 *
	 * At entry,  PSTATE.IE = 0.
	 *
	 * Register usage: where ever possible
	 *  g1-3 = scratch
	 *  g4-6 : preserved across PRINT* macros
	 *  g5 : error report pointer
	 *  g6 : cpu struct pointer
	 */
	ENTRY_NP(ce_poll_entry)	/* entry point for the error daemon */
						! %g6->cpu
	stx	%g7, [%g6 + CPU_ERR_RET]	! save return address

	ENTRY_NP(ce_err)

	/* get cpu, CE buffer in %g6-5, they are safe across calls */
	CPU_ERPT_STRUCT(CPU_CE_RPT, %g6, %g5)	! g6->cpu, g5->cpu.ce_rpt

	! get the lock
	SPINLOCK_ENTER_ERRORLOCK(%g1, %g2, %g3)
	! XXX set the buffer busy flag

	PRINT("CE_ERR\r\n")
	CONSOLE_PRINT_ESRS(%g1, %g2, %g3, %g4)

	/*
	 * Niagara PRM Programming Note: To minimize the possibility of
	 * missing notification of another error, software should clear any
	 * multiple error indication as soon as possible.
	 *
	 * Note: - hardware insures that we will not clear a non-CE error
	 *         See PRM 12.4.2 Table 12-6.
	 */
.ce_0:
	ldxa	[%g0]ASI_SPARC_ERR_STATUS, %g4	! SPARC afsr
.ce_rd_sa:
	ldxa	[%g0]ASI_SPARC_ERR_ADDR, %g3	! SPARC afar
	ldxa	[%g0]ASI_SPARC_ERR_STATUS, %g1	! re-read afsr
	cmp	%g1, %g4			! same?
	bnz,a	%xcc, .ce_rd_sa			!   no: read both again
	  mov	%g1, %g4			!        save last status

	stxa	%g4, [%g0]ASI_SPARC_ERR_STATUS	! clear everything seen

	stx	%g4, [%g5 + CPU_VBSC_ERPT + EVBSC_SPARC_AFSR]	! save afsr
	stx	%g3, [%g5 + CPU_VBSC_ERPT + EVBSC_SPARC_AFAR]	! save afar

	/*
	 * Check to see if there is any error to process
	 */
	CE_CHECK(%g6, %g4, %g1, %g2, %g3)	! cpup, spesr,
	bz,a	%xcc, .ce_unlock_exit		! none: exit
	  nop

	/*
	 * Generate a basic error report
	 *
	 * Sparc status & address are already loaded
	 */
	LOAD_BASIC_ERPT(%g6, %g5, %g1, %g2)

	! now we have a base diagnostic error report captured that
	! can be sent to the SC or diagnosis service provider

	!! %g5 -> ce_rpt
	!! %g6 -> cpu

	! XXX check for TL saturation - why do this for CEs?
	! Too drastic to watchdog reset a guest on a corrected error!
	! rdpr	%tl, %g3		! get trap level
	! cmp	%g3, MAXPTL		! is it at max?
	! bg,pn	%xcc, 1f		! if TL > MAXPTL, watchdog reset
	! nop
#ifdef DEBUG
	.pushlocals
	setx	0xdeadbeefdeadbeef,%g3, %g4
	set	CPU_VBSC_ERPT + EVBSC_DIAG_BUF + DIAG_BUF_SIZE-8, %g3
1:	stx	%g4, [%g5 + %g3]
	cmp	%g3, CPU_VBSC_ERPT + EVBSC_DIAG_BUF
	bgu,pt	%xcc, 1b
	dec	8, %g3
	.poplocals
#endif /* DEBUG */

	/*
	 * At this point we now look for the specific errors:
	 */
	lduw	[%g6 + CPU_ERR_FLAG], %g3
	btst	ERR_FLAG_SPARC, %g3		! blackout?
	ldx	[%g5 + CPU_VBSC_ERPT + EVBSC_SPARC_AFSR], %g3 ! sparc status
	bnz	%xcc, .ce_check_l2		!   yes: check l2 dram

	set	SPARC_CE_BITS, %g4
	btst	%g4, %g3 			! any valid CE bit set?
	bz	%xcc, .ce_check_l2		! no SPARC, check L2DRAM
	nop

	/*
	 * Sparc Errors:
	 */
	mov	%g5, %g2			! g2 = cpu.ce_erpt
	set	SPARC_ESR_IRC, %g4
	btst	%g4, %g3			! is IRC set?
	bnz	%xcc, .ce_irc_err
	nop

	set	SPARC_ESR_FRC, %g4
	btst	%g4, %g3			! is FRC set?
	bnz	%xcc, .ce_frc_err
	nop

	set	SPARC_ESR_DTC, %g4
	btst	%g4, %g3			! is DTC set?
	bnz	%xcc, .ce_dtc_err
	nop

	set	SPARC_ESR_DDC, %g4
	btst	%g4, %g3			! is DDC set?
	bnz	%xcc, .ce_ddc_err
	nop

	set	SPARC_ESR_IDC, %g4
	btst	%g4, %g3			! is IDC set?
	bnz	%xcc, .ce_idc_err
	nop

	set	SPARC_ESR_ITC, %g4
	btst	%g4, %g3			! is ITC set?
	bnz	%xcc, .ce_itc_err
	nop

	! SPARC ESR may have a CE bit and/or MEC bit set
	set	SPARC_ESR_MEC, %g4
	btst	%g4, %g3			! MEC bit set?
	bnz	%xcc, .ce_just_mec
	nop

	! should not get here as all CE conditions have been tested
	PRINT("NOTE: Sparc CE: failed to find error bit set!!")
	ba,a	.ce_no_error


	 ! IRC error handler
.ce_irc_err:
	PRINT("IRC DIAG\r\n")
	! set up %g1 as first arg to irc_check()
	ldx	[%g5 + CPU_VBSC_ERPT + EVBSC_SPARC_AFAR], %g1	! arg1 = EAR
	HVCALL(irc_check)			! %g2 is return value
	cmp	%g2, RF_TRANSIENT
	be	1f				! transient IRC
	nop
	! persistent IRC error,
	!   let storm protection throttle irc and iru reports
	PRINT("persistent IRC error\r\n")
	ba	.ce_sparc_storm			! finish up
	clr	%g1				!   no print or send

1:
	! send the sparc_err_ebl reg to the diag eng
	ldxa	[%g0]ASI_SPARC_ERR_EN, %g1
	stx	%g1, [%g5 + EVBSC_DIAG_BUF + DIAG_BUF_REG_INFO]
	ba,a	.ce_send_sparc_erpt		! send report & finish up


	! Default CE error handler.
	! This just sends the CE diagnostic error report to the
	! vBSC to generate an FMA error report.
/*
 * L1 Instruction Cache:
 */
.ce_itc_err:	/* Tag */
	PRINT("ITC DIAG\r\n")
	DUMP_ICACHE_INFO(CPU_CE_RPT, %g1, %g5, %g3, %g4, %g2, %g6, %g7)
	ba,a	.ce_send_sparc_erpt

.ce_idc_err:
	PRINT("IDC DIAG\r\n")
	DUMP_ICACHE_INFO(CPU_CE_RPT, %g1, %g5, %g3, %g4, %g2, %g6, %g7)
	ba,a	.ce_send_sparc_erpt



/*
 * L1 Data Cache:
 */
.ce_dtc_err:	/* Tag */
	PRINT("DTC DIAG\r\n")
	DUMP_DCACHE_INFO(CPU_CE_RPT, %g6, %g5, %g1, %g2, %g3, %g4, %g7)
	ba,a	.ce_send_sparc_erpt


.ce_ddc_err:	/* Data */
	PRINT("DDC DIAG\r\n")
	DUMP_DCACHE_INFO(CPU_CE_RPT, %g6, %g5, %g1, %g2, %g3, %g4, %g7)
	ba,a	.ce_send_sparc_erpt
/*
 * Float Register Correctable:
 */
.ce_frc_err:
	PRINT("FRC DIAG\r\n")
	! set up %g1 as first arg to frc_check()
	ldx	[%g5 + CPU_VBSC_ERPT + EVBSC_SPARC_AFAR], %g1
	!! %g1 = EAR
	HVCALL(frc_check)
	!! %g2 = return value
	cmp	%g2, RF_TRANSIENT
	be	1f				! transient FRC
	nop
	! persistent FRC error,
	!   let storm protection throttle frc and fru reports
	PRINT("persistent FRC error\r\n")
	ba	.ce_sparc_storm			! finish up
	clr	%g1				!   no print or send
1:
	! send the sparc_err_ebl reg to the diag eng
	ldxa	[%g0]ASI_SPARC_ERR_EN, %g1
	stx	%g1, [%g5 + EVBSC_DIAG_BUF + DIAG_BUF_REG_INFO]
	ba,a	.ce_send_sparc_erpt		! send report & finish up

.ce_just_mec:
	PRINT("JUST MEC\r\n")
	ba,a	.ce_send_sparc_erpt		! send report & finish up

.ce_send_sparc_erpt:
	/*
	 * Note: this path is taken also for "MEC only" and "nothing found".
	 *       It will throttle "false" interrupts.
	 */
	CPU_STRUCT(%g6)				! g6 -> cpu
	add	%g6, CPU_CE_RPT, %g5		! g5 -> cpu.ce_rpt

	set	ERR_SEND_DIAG, %g1
	SET_CPU_RPTFLAGS(%g6, %g1)


	/*
	 * Storm Prevention:
	 *
	 * This code prevents more than one error every time period from
	 *   the group: SPARC Register File & L1$
	 */
.ce_sparc_storm:
	lduw	[%g6 + CPU_ERR_FLAG], %g2
	btst	ERR_FLAG_SPARC, %g2		! handler installed?
	bnz,pn	%xcc, .ce_sparc_storm_done	!   yes

	bset	ERR_FLAG_SPARC, %g2		!   no: set it
	ldx	[%g6 + CPU_ROOT], %g1		! ->config
	ldx	[%g1 + CONFIG_CE_BLACKOUT], %g1
	brz,a,pn %g1, .ce_sparc_storm_done	! zero: blackout disabled
	  nop
	stw	%g2, [%g6 + CPU_ERR_FLAG]	! flag as installed
						! g1 = delta tick
	HVCALL(err_set_sparc_bits)		! g2 = handler address
	set	CEEN, %g3			! g3 = arg 0 : bit(s) to set
	clr	%g4				! g4 = arg 1 : not used
	HVCALL(cyclic_add_rel)	/* ( del_tick, address, arg0, arg1 ) */
.ce_sparc_storm_done:
	ba,a	ce_err_ret


	/*
	 * L2DRAM Error Handling:
	 */
	/* g6->cpu, g5->ce_rpt */
.ce_check_l2:
	/*
	 * L2DRAM errors are global and may not be valid for this cpu.
	 * Process if PID == ERRORSTEER, or this cpu was sent the error.
	 */
	DUMP_L2_DRAM_ERROR_LOGS(%g6, %g5, %g1, %g2, %g3, %g4, %g7)
	/*
	 * Only one error in one bank will be processed
	 * each pass through here.
	 *
	 * Note: storm prevention will block processing of banks
	 * in a blackout
	 */
	! go through each L2 bank and check for valid CE bits
.ce_check_l2_b0:
	CE_CHECK_L2_ESR(0, %g6, %g4, %g1, %g2)
	bz	%xcc, .ce_check_l2_b1		! check next bank
	nop
	SET_CPU_L2BANK(0, %g6, %g7)		! save bank#
	! dump all of the l2 info. must pass the registers as is
	DUMP_L2_SET_TAG_DATA(0, CPU_CE_RPT, %g6, %g5, %g1, %g2)
	! dram data here since all L2 esr need it
	DUMP_DRAM_CONTENTS(0, CPU_CE_RPT, %g6, %g5, %g1, %g2)
	ldx	[%g6 + CPU_CE_RPT + CPU_EVBSC_L2_AFSR(0)], %g4	! l2esr
	/* 6->cpu  4=l2esr */
	CLEAR_L2_ESR(0, %g4, %g1, %g2)
	/* 6->cpu  4=l2esr */
	PROCESS_CE_IN_L2_ESR(0, %g6, %g5, %g4, %g1, %g2, %g3)
	/* 6->cpu  5->erpt  4=flags: action */
	ba,a	.ce_l2_all

.ce_check_l2_b1:
	CE_CHECK_L2_ESR(1, %g6, %g4, %g1, %g2)
	bz	%xcc, .ce_check_l2_b2		! check next bank
	nop
	SET_CPU_L2BANK(1, %g6, %g7)		! save bank#
	! dump all of the l2 info. must pass the registers as is
	DUMP_L2_SET_TAG_DATA(1, CPU_CE_RPT, %g6, %g5, %g1, %g2)
	! dram data here since all L2 esr need it
	DUMP_DRAM_CONTENTS(1, CPU_CE_RPT, %g6, %g5, %g1, %g2)
	ldx	[%g6 + CPU_CE_RPT + CPU_EVBSC_L2_AFSR(1)], %g4
	CLEAR_L2_ESR(1, %g4, %g1, %g2)
	PROCESS_CE_IN_L2_ESR(1, %g6, %g5, %g4, %g1, %g2, %g3)
	ba,a	.ce_l2_all

.ce_check_l2_b2:
	CE_CHECK_L2_ESR(2, %g6, %g4, %g1, %g2)
	bz	%xcc, .ce_check_l2_b3		! check next bank
	nop
	SET_CPU_L2BANK(2, %g6, %g7)		! save bank#
	! dump all of the l2 info. must pass the registers as is
	DUMP_L2_SET_TAG_DATA(2, CPU_CE_RPT, %g6, %g5, %g1, %g2)
	! dram data here since all L2 esr need it
	DUMP_DRAM_CONTENTS(2, CPU_CE_RPT, %g6, %g5, %g1, %g2)
	ldx	[%g6 + CPU_CE_RPT + CPU_EVBSC_L2_AFSR(2)], %g4
	CLEAR_L2_ESR(2, %g4, %g1, %g2)
	PROCESS_CE_IN_L2_ESR(2, %g6, %g5, %g4, %g1, %g2, %g3)
	ba,a	.ce_l2_all

.ce_check_l2_b3:
	CE_CHECK_L2_ESR(3, %g6, %g4, %g1, %g2)
	bz	%xcc, .ce_no_error
	nop
	SET_CPU_L2BANK(3, %g6, %g7)		! save bank#
	! dump all of the l2 info. must pass the registers as is
	DUMP_L2_SET_TAG_DATA(3, CPU_CE_RPT, %g6, %g5, %g1, %g2)
	! dram data here since all L2 esr need it
	DUMP_DRAM_CONTENTS(3, CPU_CE_RPT, %g6, %g5, %g1, %g2)
	ldx	[%g6 + CPU_CE_RPT + CPU_EVBSC_L2_AFSR(3)], %g4
	CLEAR_L2_ESR(3, %g4, %g1, %g2)
	PROCESS_CE_IN_L2_ESR(3, %g6, %g5, %g4, %g1, %g2, %g3)
	ba,a	.ce_l2_all

.ce_l2_all:
	brlz	%g4, .ce_no_error		! no error found - exit now
	nop
	SET_CPU_RPTFLAGS(%g6, %g4)


	/*
	 * Storm Prevention:
	 *
	 * This code prevents more than one error every six seconds from
	 * the groups: L2$, DRAM Banks. Since the enables are system wide
	 * we use the error enable bits to indicate the blackout period.
	 * The callback flag is used to indicate if the handler is enabled
	 * on this cpu.
	 */
	/*
	 * There is a very small window where multiple interrupts can be
	 * delivered to more than one cpu.
	 * Only one will get through this set successfully.
	 */
.ce_l2dram_storm:
	GET_CPU_L2BANK(%g6, %g4)
	BCLR_L2_BANK_EEN(%g4, CEEN, %g1, %g2)	! g4 = bank#
	bz	%xcc, .ce_l2dram_storm_done	! already disabled
	nop
	mov	ERR_FLAG_L2DRAM, %g1		! L2DRAM flag
	sll	%g1, %g4, %g1			! << bank#
	lduw	[%g6 + CPU_ERR_FLAG], %g2	! installed flags
	btst	%g1, %g2			! handler installed?
	bnz,pn	%xcc, .ce_l2dram_storm_done	!   yes

	bset	%g1, %g2			!   no: set it
	ldx	[%g6 + CPU_ROOT], %g1		! ->config
	ldx	[%g1 + CONFIG_CE_BLACKOUT], %g1
	brz,a,pn %g1, .ce_l2dram_storm_done	! zero: blackout disabled
	  nop
	stw	%g2, [%g6 + CPU_ERR_FLAG]	! handler installed
						! g1 = delta tick
	HVCALL(err_set_l2_bits)			! g2 = handler address
	mov	CEEN, %g3			! g3 = arg 0 : bit(s) to set
						! g4 = arg 1 : B5-0: bank #
	HVCALL(cyclic_add_rel)	/* ( del_tick, address, arg0, arg1 ) */
.ce_l2dram_storm_done:
	ba,a	ce_err_ret


	ENTRY_NP(ce_err_ret)

	CPU_STRUCT(%g6)				! g6 -> cpu
	GET_CPU_RPTFLAGS(%g6, %g4)		! g4: flags: action

	btst	ERR_SEND_DIAG, %g4		! send diag report?
	bz	%xcc, .ce_unlock_exit		!   no
	nop
	! send CE diag report
	add	%g6, CPU_CE_RPT + CPU_VBSC_ERPT, %g1	! erpt.vbsc
	add	%g6, CPU_CE_RPT + CPU_UNSENT_PKT, %g2	! erpt.unsent flag
	mov	EVBSC_SIZE, %g3			! size
	HVCALL(send_diag_erpt)			! g4-6 clobbered
	CPU_STRUCT(%g6)				! g6 -> cpu
	SET_CPU_RPTFLAGS(%g6, %g0)		! clear report flags
	ba,a	.ce_unlock_exit		! handler epilogue


	! XXX CEs should never watchdog_reset a guest???
	! XXX It should also not inadvertently let a guest run at TL > MAXPTL
	! send the error report to the diagnostic service provider
	! before watchdog_guest

	! ba,a	watchdog_guest
	/*NOTREACHED*/

	/*
	 * Sparc and L2DRAM checked with no error to report:
	 */
.ce_no_error:
	! Some other thread beat us to it, or we don't own it, or
	! the blackout(s) have left us nothing to report.
	PRINT("NOTE: No Reportable Error\r\n")

	/*
	 * CE epilogue
	 * The CE error handlers return here after handling the error.
	 */
.ce_unlock_exit:
	/* MUST leave Sparc CEEN enabled to get L2DRAM interrupts! */
						/* Reenable CEEN */
	ldxa	[%g0]ASI_SPARC_ERR_EN, %g1	! get current
	bset	CEEN, %g1			! enable CEEN
	stxa	%g1, [%g0] ASI_SPARC_ERR_EN	!    ..

	/*
	 *   With CE storm prevention, the CEEN will be reenabled by the
	 *   hstick_match handler when errors stop.
	 */
	SPINLOCK_EXIT_ERRORLOCK(%g1)		! release lock

	ba,a	.ce_exit			! exit now

.ce_exit:
	ldx	[%g6 + CPU_ERR_RET], %g7	! get return address
	brnz,a	%g7, .ce_return			!   valid: clear it & return
	  stx	%g0, [%g6+ CPU_ERR_RET]		!           ..
	SET_SIZE(ce_poll_entry)
						! NULL: return from interrupt
	retry					! return from CE interrupt

.ce_return:
	HVRET
	SET_SIZE(ce_err_ret)
	SET_SIZE(ce_err)


	/*
	 * Disrupting uncorrectable error handler.
	 * All of these errors are resumable errors to the guest. I.e. they
	 * are not nonresumable errors.
	 *
	 * At entry, PSTATE.IE = 0, so no furthur disrupting error traps.
	 *
	 * The CE error report buffer is used for reporting.
	 */
	ENTRY_NP(dis_ue_err)

	/*
	 * Check for DBU in  DRAM ESR
	 */
	CHECK_DRAM_ERROR(DRAM_ESR_DBU, %g1, %g2, %g3, %g4)
	bnz,pn	%xcc, .fatal_reset_dbu		!  yes: bail now
	nop

	/* get cpu, CE buffer in %g6-5, they are safe across calls */
	CPU_ERPT_STRUCT(CPU_CE_RPT, %g6, %g5)	! g6->cpu, g5->cpu.ce_rpt

	/*
	 * We do not idle all strands if the scrubber got a UE
	 */
	CHECK_L2_ERROR(L2_ESR_LDSU, %g1, %g2, %g3)
	bnz,pn	%xcc, .dis_ue_no_idle
	mov	ERR_FLAG_STRANDS_NOT_IDLED, %g1	
	CHECK_DRAM_ERROR(DRAM_ESR_DSU, %g1, %g2, %g3, %g4)
	bnz,pn	%xcc, .dis_ue_no_idle
	mov	ERR_FLAG_STRANDS_NOT_IDLED, %g1	

	SPINLOCK_IDLE_ALL_STRAND(%g6, %g1, %g2, %g3, %g4)
	! At this point, this is the only strand executing
	mov	%g0, %g1	

.dis_ue_no_idle:

	lduw	[%g6 + CPU_ERR_FLAG], %g2	! installed flags
	bclr	ERR_FLAG_STRANDS_NOT_IDLED, %g2	! reset STRANDS_IDLED
	or	%g2, %g1, %g2
	stw	%g2, [%g6 + CPU_ERR_FLAG]	!	..


	PRINT("DATA ERR\r\n")
	CONSOLE_PRINT_ESRS(%g1, %g2, %g3, %g4)

	/*
	 * Niagara PRM Programming Note: To minimize the possibility of
	 * missing notification of an error, software should any multiple
	 * error indication as soon as possible.
	 */
	ldxa	[%g0]ASI_SPARC_ERR_STATUS, %g4	! SPARC afsr
.dis_ue_rd_sa:
	ldxa	[%g0]ASI_SPARC_ERR_ADDR, %g3	! SPARC afar
	ldxa	[%g0]ASI_SPARC_ERR_STATUS, %g1	! re-read afsr
	cmp	%g1, %g4			! same?
	bnz,a	%xcc, .dis_ue_rd_sa		!   no: read both again
	  mov	%g1, %g4			!        save last status
	stxa	%g4, [%g0]ASI_SPARC_ERR_STATUS	! clear SPARC afsr

	! save ce_rpt.sparc_afsr
	stx	%g4, [%g5 + CPU_VBSC_ERPT + EVBSC_SPARC_AFSR]
	! save ce_rpt.sparc_afar
	stx	%g3, [%g5 + CPU_VBSC_ERPT + EVBSC_SPARC_AFAR]

	/*
	 * Generate a basic error report
	 *
	 * Sparc status & address are already loaded
	 */
	LOAD_BASIC_ERPT(%g6, %g5, %g1, %g2)

	mov	%g6, %g1			! cpu
	mov	%g5, %g2			! cpu.ue_erpt

#ifdef DEBUG
	.pushlocals
	setx	0xdeadbeefdeadbeef,%g3, %g4
	set	CPU_VBSC_ERPT + EVBSC_DIAG_BUF + DIAG_BUF_SIZE-8, %g3
1:	stx	%g4, [%g5 + %g3]
	cmp	%g3, CPU_VBSC_ERPT + EVBSC_DIAG_BUF
	bgu,pt	%xcc, 1b
	dec	8, %g3
	.poplocals
#endif
	! check for MAU error
	/* Dump the L2 and DRAM registers also */
	! %g1 has cpu pointer, %g2 has &ce_rpt - pointer to error report
	DUMP_L2_DRAM_ERROR_LOGS(%g1, %g2, %g3, %g4, %g5, %g6, %g7)

	! go through each L2 bank and check for valid UE bits
.dis_ue_check_l2_b0:
	DIS_UE_CHECK_L2_ESR(0, %g1, %g2, %g3, %g4)	! %g1 = L2ESR
	bz	%xcc, .dis_ue_check_l2_b1		! check next bank
	nop
	/* save the state of the line */
	SAVE_L2_LINE_STATE(0, CPU_CE_RPT, %g1, %g2)
	!! %g1= cpup
	!! %g2 = erpt
	DUMP_L2_SET_TAG_DATA(0, CPU_CE_RPT, %g1, %g2, %g1, %g2)
	!! %g1 = cpu
	!! %g2 = cpu.erpt
	ldx	[%g2 + CPU_EVBSC_L2_AFSR(0)], %g4	! l2esr
	CLEAR_L2_ESR(0, %g4, %g5, %g6)			! clear L2 ESR
	PROCESS_DIS_UE_IN_L2_ESR(0, %g1, %g2, %g3, %g4, %g5, %g6, %g7,	\
		.dis_ue_err_ret, .ue_resume_exit)

.dis_ue_check_l2_b1:
	DIS_UE_CHECK_L2_ESR(1, %g1, %g2, %g3, %g4)	! %g1 = L2ESR
	bz	%xcc, .dis_ue_check_l2_b2		! check next bank
	nop
	/* save the state of the line */
	SAVE_L2_LINE_STATE(1, CPU_CE_RPT, %g1, %g2)
	!! %g1= cpup
	!! %g2 = erpt
	DUMP_L2_SET_TAG_DATA(1, CPU_CE_RPT, %g1, %g2, %g1, %g2)
	ldx	[%g2 + CPU_EVBSC_L2_AFSR(1)], %g4	! l2esr
	CLEAR_L2_ESR(1, %g4, %g5, %g6)			! clear L2 ESR
	PROCESS_DIS_UE_IN_L2_ESR(1, %g1, %g2, %g3, %g4, %g5, %g6, %g7,	\
		.dis_ue_err_ret, .ue_resume_exit)

.dis_ue_check_l2_b2:
	DIS_UE_CHECK_L2_ESR(2, %g1, %g2, %g3, %g4)	! %g1 = L2ESR
	bz	%xcc, .dis_ue_check_l2_b3		! check next bank
	nop
	/* save the state of the line */
	SAVE_L2_LINE_STATE(2, CPU_CE_RPT, %g1, %g2)
	!! %g1= cpup
	!! %g2 = erpt
	DUMP_L2_SET_TAG_DATA(2, CPU_CE_RPT, %g1, %g2, %g1, %g2)
	ldx	[%g2 + CPU_EVBSC_L2_AFSR(2)], %g4	! l2esr
	CLEAR_L2_ESR(2, %g4, %g5, %g6)			! clear L2 ESR
	PROCESS_DIS_UE_IN_L2_ESR(2, %g1, %g2, %g3, %g4, %g5, %g6, %g7,	\
		.dis_ue_err_ret, .ue_resume_exit)

.dis_ue_check_l2_b3:
	DIS_UE_CHECK_L2_ESR(3, %g1, %g2, %g3, %g4)	! %g1 = L2ESR
	bz	%xcc, .dis_ue_no_error			! XXX spurious?
	nop
	/* save the state of the line */
	SAVE_L2_LINE_STATE(3, CPU_CE_RPT, %g1, %g2)
	!! %g1= cpup
	!! %g2 = erpt
	DUMP_L2_SET_TAG_DATA(3, CPU_CE_RPT, %g1, %g2, %g1, %g2)
	ldx	[%g2 + CPU_EVBSC_L2_AFSR(3)], %g4	! l2esr
	CLEAR_L2_ESR(3, %g4, %g5, %g6)			! clear L2 ESR
	PROCESS_DIS_UE_IN_L2_ESR(3, %g1, %g2, %g3, %g4, %g5, %g6, %g7,	\
		.dis_ue_err_ret, .ue_resume_exit)
	!
	! All banks checked, now return
	!
	ba,a	.dis_ue_err_ret				! UE handler epilogue
	/*NOTREACHED*/

.dis_ue_no_error:
	PRINT("NO DIS UE ERROR\r\n")
	! some other thread beat us to it.
	! no bits in L2, simply return (XXX send a service error report?)
	! send CE diag report
	CPU_STRUCT(%g6)
	add	%g6, CPU_CE_RPT + CPU_VBSC_ERPT, %g1	! erpt.vbsc
	add	%g6, CPU_CE_RPT + CPU_UNSENT_PKT, %g2	! erpt.unsent flag
	mov	EVBSC_SIZE, %g3			! size
	HVCALL(send_diag_erpt)

	ba,a	.dis_ue_err_ret			! CE handler epilogue
	/*NOTREACHED*/
	SET_SIZE(dis_ue_err)

	/*
	 * General handling of UEs
	 * if HTSTATE[TL].GL == MAXPGL
	 *    reset chip and partitions
	 * else if HTSTATE.PRIV == 1
	 *    reset chip and partitions
	 * else if TL > MAXPTL then watchdog_reset
	 * else call common handler
	 */

	/*
	 * Uncorrectable error traps can be taken any time NCEEN
	 * in the SPARC error status register is set.
	 * UEs can occur when executing in the hypervisor, supervisor,
	 * or user code.
	 *
	 * XXX UEs when executing in hypervisor resets the system XXX
	 * TL overflow causes guest to be reset
	 */
	ENTRY_NP(ue_poll_entry)	/* entry point for the error daemon */
						! %g6->cpu
	stx	%g7, [%g6 + CPU_ERR_RET]	! save return address

	ba,a	ue_err_notrap
	.empty

	ENTRY_NP(ue_err)

	/*
	 * Check for global register saturation and save the current
	 * global register set if necessary.
	 */
	SAVE_UE_GLOBALS()

ue_err_notrap:
	/*
	 * Check for DBU in  DRAM ESR
	 */
	CHECK_DRAM_ERROR(DRAM_ESR_DBU, %g1, %g2, %g3, %g4)
	bnz,pn	%xcc, .fatal_reset_dbu			!  yes: bail now
	nop

	/* get cpu, UE buffer in %g6-5, they are safe across calls */
	CPU_ERPT_STRUCT(CPU_UE_RPT, %g6, %g5)	! g6->cpu, g5->cpu.ue_rpt

	/*
	 * check to see if UE occurred in hypervisor
	 * We check early in order to avoid a deadlock situation.
	 * in the previous trap, we were handling either a dis UE or a CE
	 */
	rdhpr	%htstate, %g1
	btst	HTSTATE_HPRIV, %g1
	bnz	%xcc, .ue_get_status_addr		! UE in hypervisor
	nop

	SPINLOCK_IDLE_ALL_STRAND(%g6, %g1, %g2, %g3, %g4)
	! At this point, this is the only strand executing

#ifdef DEBUG
	ldxa	[%g0]ASI_SPARC_ERR_STATUS, %g1	! SPARC afsr
	set	SPARC_ESR_NCU, %g4	! Ifetch/Load from IO space bit
	btst	%g4, %g1		! NCU set?
	bnz	%xcc, .skip_print_esrs	! skip printing ESRs
	nop

	PRINT("UE_ERR\r\n")
	CONSOLE_PRINT_ESRS(%g1, %g2, %g3, %g4)
.skip_print_esrs:
#endif /* DEBUG */


.ue_get_status_addr:
	/*
	 * Niagara PRM Programming Note: To minimize the possibility of
	 * missing notification of an error, software should clear the
	 * error indication as soon as possible.
	 */
	ldxa	[%g0]ASI_SPARC_ERR_STATUS, %g4	! SPARC afsr
.ue_rd_sa:
	ldxa	[%g0]ASI_SPARC_ERR_ADDR, %g3	! SPARC afar
	ldxa	[%g0]ASI_SPARC_ERR_STATUS, %g1	! re-read afsr
	cmp	%g1, %g4			! same?
	bnz,a	%xcc, .ue_rd_sa			!   no: read both again
	  mov	%g1, %g4			!        save last status

	stxa	%g4, [%g0]ASI_SPARC_ERR_STATUS	! clear everything seen

	! save ue_rpt.sparc_afsr
	stx	%g4, [%g5 + CPU_VBSC_ERPT + EVBSC_SPARC_AFSR]
	! save ue_rpt.sparc_afar
	stx	%g3, [%g5 + CPU_VBSC_ERPT + EVBSC_SPARC_AFAR]

	/*
	 * Check to see if there is any error to process
	 */
	UE_CHECK(SPARC_UE_MEU_BITS, L2_ESR_UE_BITS, %g4, %g1, %g2, %g3)
	bz,a	%xcc, .ue_resume_exit	! none: exit
	  nop


	/*
	 * Generate a basic error report
	 *
	 * Sparc status & address are already loaded
	 */
	LOAD_BASIC_ERPT(%g6, %g5, %g1, %g2)

	mov	%g6, %g1			! cpu
	mov	%g5, %g2			! cpu.ue_erpt

#ifdef DEBUG
	.pushlocals
	setx	0xdeadbeefdeadbeef,%g3, %g4
	set	CPU_VBSC_ERPT + EVBSC_DIAG_BUF + DIAG_BUF_SIZE-8, %g3
1:	stx	%g4, [%g5 + %g3]
	cmp	%g3, CPU_VBSC_ERPT + EVBSC_DIAG_BUF
	bgu,pt	%xcc, 1b
	dec	8, %g3
	.poplocals
#endif
	! set error descriptor to UE resumable
	set	EDESC_UE_RESUMABLE, %g3
	! edesc in guest erpt
	st	%g3, [%g2 + CPU_SUN4V_ERPT + ESUN4V_EDESC]

	! check SPARC ESR for thread-specific errors
	! %g3 = saved sparc_afsr
	ldx	[%g2 + CPU_VBSC_ERPT + EVBSC_SPARC_AFSR], %g3
	set	SPARC_UE_MEU_BITS, %g4
	btst	%g4, %g3			! any UE or MEU bit set?
	bz	%xcc, .ue_dump_l2		! no UEs, check L2
	nop

	! a UE/MEU bit is set in the SPARC ESR. If it is LDAU, then
	! it is L2$/DRAM related.
	set	SPARC_ESR_LDAU, %g4		! LDAU bit
	btst	%g4, %g3			! LDAU set?
	bnz	%xcc, .ue_ldau_err
	nop

	set	SPARC_ESR_NCU, %g4		! NCU bit
	btst	%g4, %g3			! NCU set?
	bnz	%xcc, .ue_ncu_err
	nop

	set	SPARC_ESR_IRU, %g4		! IRU bit
	btst	%g4, %g3			! IRU set?
	bnz	%xcc, .ue_iru_err
	nop

	set	SPARC_ESR_FRU, %g4		! FRU bit
	btst	%g4, %g3			! FRU set?
	bnz	%xcc, .ue_fru_err
	nop

	/*
	 * check to see if UE occurred in hypervisor
	 * We check early in order to avoid a deadlock situation.
	 * in the previous trap, we were handling either a dis UE or a CE
	 */
	rdhpr	%htstate, %g1
	btst	HTSTATE_HPRIV, %g1
	bnz	%xcc, .hpriv_ue			! UE in hypervisor
	nop

	set	SPARC_ESR_MAU, %g4		! MAU bit
	btst	%g4, %g3			! MAU set?
	bnz	%xcc, .ue_mau_err
	nop

	set	SPARC_ESR_IMDU, %g4		! IMDU bit
	btst	%g4, %g3			! IMDU set?
	bnz	%xcc, .ue_imdu_err
	nop

	set	SPARC_ESR_IMTU, %g4		! IMTU bit
	btst	%g4, %g3			! IMTU set?
	bnz	%xcc, .ue_imtu_err
	nop

	set	SPARC_ESR_DMTU, %g4		! DMTU bit
	btst	%g4, %g3			! DMTU set?
	bnz	%xcc, .ue_dmtu_err
	nop

	set	SPARC_ESR_DMDU, %g4		! DMDU bit
	btst	%g4, %g3			! DMDU set?
	bnz	%xcc, .ue_dmdu_err
	nop

	set	SPARC_ESR_DMSU, %g4		! DMSU bit
	btst	%g4, %g3			! DMSU set?
	bnz	%xcc, .ue_dmsu_err
	nop

	set	SPARC_ESR_MEU, %g4		! MEU bit
	btst	%g4, %g3			! MEU set?
	bnz	%xcc, .ue_just_meu_err
	nop
	/*NOTREACHED*/
	! Should not get here as all UE bits have been tested
	PRINT("NOTREACHED\r\n")
	ba,a	.ue_send_resume_exit

	/*
	 * FRU: Float Register File uncorrectable ECC error
	 */
	! If the error is unrecoverable, mark the cpu in error. Else
	! fill out the ue error report in cpu structure. send service
	! entity diagnosis report, then call precise_ue_err_ret. In
	! precise_ue_err_ret, it will queue the error report to guest.
.ue_fru_err:
	CPU_ERPT_STRUCT(CPU_UE_RPT, %g2, %g2)	! ->cpu.ue_rpt
	ldx	[%g2 + CPU_VBSC_ERPT + EVBSC_SPARC_AFAR], %g1
	!! %g1 = sparc afar
	HVCALL(clear_fregerr)			! %g1 = input, g2 = output
	!! %g2 contains a 0 if we got FRU after FRC for a persistent error
	brnz	%g2, .ue_not_from_frc		! it is a new FRU
	nop
	! Took an FRU trap from the FRC handler reread. Return to FRC handler
	PRINT("FRU FROM FRC DIAG\r\n");

	RESTORE_UE_GLOBALS()

	done					! complete reread of reg

.ue_not_from_frc:
	/*
	 * check to see if UE occurred in hypervisor
	 */
	rdhpr	%htstate, %g3
	btst	HTSTATE_HPRIV, %g3
	bnz	%xcc, .hpriv_ue			! UE in hypervisor
	nop

	HVCALL(fru_check)			! g2 = status
	! %g2 contains whether the error is transient, persistent or a failed RF
	cmp	%g2, RF_TRANSIENT		! transient?
	bne	.ue_fru_cpu			!   no: unrecoverable
	nop

	! FRU is recoverable, send a nonresumable error to the guest
	SET_ERPT_EDESC_EATTR(CPU_UE_RPT, EATTR_FRF,
	    EDESC_PRECISE_NONRESUMABLE, %g1, %g2, %g3)
	CLEAR_SPARC_ESR(CPU_UE_RPT, SPARC_ESR_FRU, %g1, %g2, %g3, %g4)
	PRINT("FRU DIAG\r\n")
	ba,a	.ue_eer_send_ue_rpt

	/* FRU is unrecoverable, mark CPU in error */
.ue_fru_cpu:
	PRINT("CPU in ERROR -FRU\r\n")
	! Set the CPU_ERROR status flag
	SET_CPU_IN_ERROR(%g1, %g2)
	SET_ERPT_EDESC_EATTR(CPU_UE_RPT, EATTR_CPU,
	    EDESC_UE_RESUMABLE, %g1, %g2, %g3)
	ba,a	.ue_send_resume_exit

	/*
	 * IMDU: ITLB Data Parity Error (precise)
	 * Detected on instruction translation as well as with loads
	 * to ASI_ITLB_DATA_ACCESS_REG.
	 */
.ue_imdu_err:
	PRINT("IMDU DIAG\r\n")
	CPU_STRUCT(%g1)
	add	%g1, CPU_UE_RPT, %g2		! %g2 = cpu.ue_rpt
	! dump the ITLB entries into cpu.ue_rpt.diag_buf
	DUMP_ITLB(%g1, %g2, %g3, %g4, %g5, %g6, %g7)
	mov	I_INVALIDATE, %g1
	stxa	%g0, [%g1] ASI_TLB_INVALIDATE
	mov	MAP_ITLB, %g1
	HVCALL(remap_perm_addr)
	! log the TLB entries on the console
	CONSOLE_PRINT_TLB_DATA("ITLB Tag Data\r\n", %g1, %g2, %g3, %g4,	\
		%g5, %g6, %g7)
	! For bringup, dump out the TLB entries after demap page
#ifdef NIAGARA_BRINGUP
	PRINT("IMDU demap\r\n")
	CPU_STRUCT(%g1)
	add	%g1, CPU_UE_RPT, %g2		! %g2 = cpu.ue_rpt
	add	%g2, 0x400, %g2			! use the second 1KB area
	! dump the ITLB entries into cpu diag buffer area
	DUMP_ITLB(%g1, %g2, %g3, %g4, %g5, %g6, %g7)
	! log the TLB entries on the console for bringup
	CONSOLE_PRINT_TLB_DATA_2("ITLB Tag Data\r\n", %g1, %g2, %g3,	\
		%g4, %g5, %g6, %g7)
#endif
	ba,a	.ue_send_resume_exit		! resumable error
	/*NOTREACHED*/

	/*
	 * IMTU: ITLB Tag Parity Error
	 * Parity error when accessed via a load from ASI_ITLB_TAG_READ
	 * Action: Reset the platform.
	 */
.ue_imtu_err:
	PRINT("IMTU DIAG\r\n")
	! Can't dump tlb since there is no safe mechanism
	ba,a	.ue_send_rpt_and_abort		! reset
	/*NOTREACHED*/

	/*
	 * DMTU: DTLB Tag Parity Error
	 * Parity error when accessed via a load from ASI_DTLB_TAG_READ
	 * Action: reset the platform.
	 */
.ue_dmtu_err:
	PRINT("DMTU DIAG\r\n")
	! Can't dump tlb since there is no safe mechanism
	ba,a	.ue_send_rpt_and_abort		! reset
	/*NOTREACHED*/

	/*
	 * DMDU: DTLB Data Parity Error on Load and Atomics
	 * Parity error on atomic or load translation as well
	 * as with loads to ASI_DTLB_DATA_ACCESS_REG.
	 */
.ue_dmdu_err:
	PRINT("DMDU DIAG\r\n")
	CPU_STRUCT(%g1)
	add	%g1, CPU_UE_RPT, %g2		! %g2 = cpu.ue_rpt
	! dump the DTLB entries into the cpu diag buffer
	DUMP_DTLB(%g1, %g2, %g3, %g4, %g5, %g6, %g7)
	! log the TLB data on the console
	CONSOLE_PRINT_TLB_DATA("DTLB Tag Data\r\n", %g1, %g2, %g3, %g4,	\
		%g5, %g6, %g7)
	mov	D_INVALIDATE, %g1
	stxa	%g0, [%g1] ASI_TLB_INVALIDATE
	mov	MAP_DTLB, %g1
	HVCALL(remap_perm_addr)
	! For bringup, dump out the TLB entries after demap page
#ifdef NIAGARA_BRINGUP
	PRINT("after demap\r\n")
	CPU_STRUCT(%g1)
	add	%g1, CPU_UE_RPT, %g2		! %g2 = cpu.ue_rpt
	add	%g2, 1024, %g2		! use next 1KB area
	! dump the dtlb entries into the cpu diag buffer
	DUMP_DTLB(%g1, %g2, %g3, %g4, %g5, %g6, %g7)
	! log the tlb entries on the console for bringup
	CONSOLE_PRINT_TLB_DATA_2("DTLB Tag Data\r\n", %g1, %g2, %g3,	\
		%g4, %g5, %g6, %g7)
#endif
	ba,a	.ue_send_resume_exit		! resumable UE
	/*NOTREACHED*/

	/*
	 * IRU: IRF Uncorrectable ECC Error
	 */
.ue_iru_err:
	CPU_ERPT_STRUCT(CPU_UE_RPT, %g2, %g2)
	ldx	[%g2 + CPU_VBSC_ERPT + EVBSC_SPARC_AFAR], %g1
	!! %g1 = sparc afar
	HVCALL(clear_iregerr)			! %g1 = input, %g2 = output
	!! %g2 = 0 if we got IRU after IRC for a persistent error bit
	brnz	%g2, .ue_not_from_irc		! it is a new IRU
	nop
	! Took an IRU trap from the IRC handler reread. Return to IRC handler
	PRINT("IRU FROM IRC DIAG\r\n")

	RESTORE_UE_GLOBALS()

	done					! complete reread of reg

.ue_not_from_irc:
	/*
	 * check to see if UE occurred in hypervisor
	 */
	rdhpr	%htstate, %g3
	btst	HTSTATE_HPRIV, %g3
	bnz	%xcc, .hpriv_ue			! UE in hypervisor
	nop

	HVCALL(iru_check)			! g2 = status
	cmp	%g2, RF_TRANSIENT		! transient?
	bne	.ue_iru_cpu			!   no: unrecoverable
	nop

	! IRU is recoverable, send a nonresumable error to the guest
	SET_ERPT_EDESC_EATTR(CPU_UE_RPT, EATTR_IRF,
	    EDESC_PRECISE_NONRESUMABLE, %g1, %g2, %g3)
	CLEAR_SPARC_ESR(CPU_UE_RPT, SPARC_ESR_IRU, %g1, %g2, %g3, %g4)
	PRINT("IRU DIAG\r\n")
.ue_eer_send_ue_rpt:
	! send the sparc_err_ebl reg to the diag eng
	CPU_ERPT_STRUCT(CPU_UE_RPT, %g1, %g2)
	ldxa	[%g0]ASI_SPARC_ERR_EN, %g3
	stx	%g3, [%g2 + CPU_VBSC_ERPT + EVBSC_DIAG_BUF + DIAG_BUF_REG_INFO]
	ba,a	.sendnr_ue_resume_exit
	/*NOTREACHED*/

	! IRU is unrecoverable, mark CPU in error
.ue_iru_cpu:
	PRINT("CPU in ERROR - IRU\r\n")
	! Set the CPU_ERROR status flag
	SET_CPU_IN_ERROR(%g1, %g2)
	SET_ERPT_EDESC_EATTR(CPU_UE_RPT, EATTR_CPU,
	    EDESC_UE_RESUMABLE, %g1, %g2, %g3)
	ba,a	.ue_resume_exit

	/*
	 * DMSU: DTLB Data Parity Error on Store
	 * Parity error on store translation.
	 */
.ue_dmsu_err:
	PRINT("DMSU DIAG\r\n")
	mov	D_INVALIDATE, %g1
	stxa	%g0, [%g1] ASI_TLB_INVALIDATE
	CPU_STRUCT(%g1)
	add	%g1, CPU_UE_RPT, %g2		! %g2 = cpu.ue_rpt
	! dump the DTLB entries into the cpu diag buffer
	DUMP_DTLB(%g1, %g2, %g3, %g4, %g5, %g6, %g7)
	! log the TLB data on the console
	CONSOLE_PRINT_TLB_DATA("DTLB Tag Data\r\n", %g1, %g2, %g3, %g4,	\
		%g5, %g6, %g7)
	mov	MAP_DTLB, %g1
	HVCALL(remap_perm_addr)
	! For bringup we dump the TLB after the demap operation
#ifdef NIAGARA_BRINGUP
	PRINT("DMSU demap\r\n")
	CPU_STRUCT(%g1)
	add	%g1, CPU_UE_RPT, %g2		! %g2 = cpu.ue_rpt
	add	%g2, 1024, %g2		! use the next 1KB area
	! dump the dtlb entries
	DUMP_DTLB(%g1, %g2, %g3, %g4, %g5, %g6, %g7)
	! log the dtlb to the console
	CONSOLE_PRINT_TLB_DATA_2("DTLB Tag Data\r\n", %g1, %g2, %g3,	\
		%g4, %g5, %g6, %g7)
#endif
	ba,a	.ue_send_resume_exit		! resumable error
	/*NOTREACHED*/

	/*
	 * MEU: Multiple Uncorrectable Error bit
	 * Sometimes only the MEU bit will be set. It is treated as
	 * a resumable error.
	 */
.ue_just_meu_err:
	PRINT("JUST MEU\r\n")
	ba,a	.ue_send_resume_exit		! resumable UE
	/*NOTREACHED*/

.ue_send_rpt_and_abort:
	! send UE diag report
	CPU_STRUCT(%g6)
	add	%g6, CPU_UE_RPT + CPU_VBSC_ERPT, %g1	! erpt.vbsc
	set	CPU_UE_RPT + CPU_UNSENT_PKT, %g2
	add	%g6, %g2, %g2				! erpt.unsent flag
	mov	EVBSC_SIZE, %g3				! size
	HVCALL(send_diag_erpt)
	SPINLOCK_RESUME_ALL_STRAND(%g6, %g1, %g2, %g3, %g4)
	! abort HV
	ba,pt	%xcc, hvabort
	mov	ABORT_UE_IN_TLB_TAG, %g1
	/*NOTREACHED*/

	/*
	 * NCU: IO Load/Instruction Fetch Error
	 */
.ue_ncu_err:
	! check for io_prot
	CPU_STRUCT(%g1)
	set	CPU_IO_PROT, %g2
	ldx	[%g1 + %g2], %g2	! cpu.io_prot
	brz	%g2, 1f			! if zero, no error protection
	nop
	! under i/o error protection
	! set the i/o error flag in the cpu structure and complete the
	! instruction
	set	CPU_IO_ERROR, %g2
	mov	1, %g3
	stx	%g3, [%g1 + %g2]		! cpu.io_error = 1

	! clear JBI_ERR_LOG, JBI_ERR_OVF
	setx	JBI_ERR_LOG, %g3, %g4
	ldx	[%g4], %g5
	stx	%g5, [%g4]			! clear JBI_ERROR_LOG
	setx	JBI_ERR_OVF, %g3, %g4
	ldx	[%g4], %g5
	stx	%g5, [%g4]			! clear JBI_ERROR_OVF

	SPINLOCK_RESUME_ALL_STRAND(%g1, %g3, %g4, %g5, %g6)

	RESTORE_UE_GLOBALS()

	done					! complete the instruction
	! process error
1:
	PRINT("NCU DIAG\r\n")
	! collect all diagnostic data
	CPU_STRUCT(%g1)
	add	%g1, CPU_UE_RPT, %g2		! %g2 = cpu.ue_rpt
	DUMP_JBI_SSI(%g1, %g2, %g3, %g4, %g5, %g6, %g7)

	! clear JBI_ERR_LOG, JBI_ERR_OVF, SSI_LOG
	setx	JBI_ERR_LOG, %g3, %g4
	ldx	[%g4], %g5
	brz	%g5, .ue_check_ssi
	stx	%g5, [%g4]		! clear JBI_ERROR_LOG
	setx	JBI_ERR_OVF, %g3, %g4
	ldx	[%g4], %g5
	stx	%g5, [%g4]		! clear JBI_ERROR_OVF
	ba,a	.ue_ncu_diag
	! check SSI
.ue_check_ssi:
	setx	SSI_LOG, %g3, %g4
	ldx	[%g4], %g5
	brz	%g5, .ue_no_ncu_info
	stx	%g5, [%g4]
	ba,a	.ue_ncu_diag

.ue_no_ncu_info:
	PRINT("NO ERROR LOGGED IN JBI SSI LOG\r\n")
	ba,a	.ue_ncu_diag

.ue_ncu_diag:
	CONSOLE_PRINT_JBI_SSI("JBI SSI Log\r\n", %g1, %g2, %g3, %g4,	\
		%g5, %g6, %g7)
	! send UE diag report
	CPU_ERPT_STRUCT(CPU_UE_RPT, %g6, %g1)
	inc	CPU_VBSC_ERPT, %g1			! erpt.vbsc
	set	CPU_UE_RPT + CPU_UNSENT_PKT, %g2
	add	%g6, %g2, %g2				! erpt.unsent flag
	mov	EVBSC_SIZE, %g3				! size
	HVCALL(send_diag_erpt)
	SET_ERPT_EDESC_EATTR(CPU_UE_RPT, EATTR_PIO,	\
	   EDESC_PRECISE_NONRESUMABLE, %g4, %g5, %g6)
	CPU_ERPT_STRUCT(CPU_UE_RPT, %g1, %g2)
	ldx	[%g2 + CPU_VBSC_ERPT + EVBSC_SPARC_AFAR], %g3		! VA
	stx	%g3, [%g2 + CPU_SUN4V_ERPT + ESUN4V_RA]
	ba,a	precise_ue_err_ret		! UE error epilogue
	/*NOTREACHED*/

.ue_mau_err:
	PRINT("MAU DIAG\r\n")
	ba,a	.sendnr_ue_resume_exit		! non-resumable UE epilogue

	/*
	 * Precise UEs that are nonresumable errors get here.
	 * Here the diagnostic erpt is sent before executing
	 * the handler epilogue.
	 */
.sendnr_ue_resume_exit:				! non-resumable UE epilogue
	! send UE diag report
	CPU_STRUCT(%g6)
	add	%g6, CPU_UE_RPT + CPU_VBSC_ERPT, %g1	! erpt.vbsc
	set	CPU_UE_RPT + CPU_UNSENT_PKT, %g2
	add	%g6, %g2, %g2				! erpt.unsent flag
	mov	EVBSC_SIZE, %g3				! size
	HVCALL(send_diag_erpt)
	ba,a	precise_ue_err_ret			! UE error epilogue


	! %g1 has the cpu pointer, %g2 has the UE error report buffer
.ue_ldau_err:
.ue_dump_l2:
	DUMP_L2_DRAM_ERROR_LOGS(%g1, %g2, %g3, %g4, %g5, %g6, %g7)

	/*
	 * check to see if UE occurred in hypervisor
	 * We check early in order to avoid a deadlock situation.
	 * in the previous trap, we were handling either a dis UE or a CE
	 */
	rdhpr	%htstate, %g1
	btst	HTSTATE_HPRIV, %g1
	bnz	%xcc, .hpriv_ue			! UE in hypervisor
	nop

	! check for privileged TL overflow
	rdpr	%tl, %g1			! get trap level
	cmp	%g1, MAXPTL			! is it at max?
	bgu,pn	%xcc, .tl_overflow		! TL > MAXPTL
	nop

	! check for SPARC_ESR.LDAU
	! go through each L2 bank and check for valid UE bits
.ue_check_l2_b0:
	UE_CHECK_L2_ESR(0, %g1, %g2, %g3, %g4)		! %g1 = L2ESR
	bz	%xcc, .ue_check_l2_b1			! check next bank
	nop
	SAVE_L2_LINE_STATE(0, CPU_UE_RPT, %g1, %g2)
	DUMP_L2_SET_TAG_DATA(0, CPU_UE_RPT, %g1, %g2, %g1, %g2)
	!! %g1->cpu
	!! %g2->erpt
	ldx	[%g2 + CPU_EVBSC_L2_AFSR(0)], %g4	! l2esr
	CLEAR_L2_ESR(0, %g4, %g5, %g6)			! clear L2 ESR
	PROCESS_UE_IN_L2_ESR(0, %g1, %g2, %g3, %g4, %g5, %g6, %g7,	\
		.sendnr_ue_resume_exit, .ue_senddiag_resume_exit,	\
		.ue_resume_exit)

.ue_check_l2_b1:
	UE_CHECK_L2_ESR(1, %g1, %g2, %g3, %g4)		! %g1 = L2ESR
	bz	%xcc, .ue_check_l2_b2			! check next bank
	nop
	SAVE_L2_LINE_STATE(1, CPU_UE_RPT, %g1, %g2)
	DUMP_L2_SET_TAG_DATA(1, CPU_UE_RPT, %g1, %g2, %g1, %g2)
	ldx	[%g2 + CPU_EVBSC_L2_AFSR(1)], %g4	! l2esr
	CLEAR_L2_ESR(1, %g4, %g5, %g6)			! clear L2 ESR
	PROCESS_UE_IN_L2_ESR(1, %g1, %g2, %g3, %g4, %g5, %g6, %g7,	\
		.sendnr_ue_resume_exit, .ue_senddiag_resume_exit,	\
		.ue_resume_exit)

.ue_check_l2_b2:
	UE_CHECK_L2_ESR(2, %g1, %g2, %g3, %g4)		! %g1 = L2ESR
	bz	%xcc, .ue_check_l2_b3			! check next bank
	nop
	SAVE_L2_LINE_STATE(2, CPU_UE_RPT, %g1, %g2)
	DUMP_L2_SET_TAG_DATA(2, CPU_UE_RPT, %g1, %g2, %g1, %g2)
	ldx	[%g2 + CPU_EVBSC_L2_AFSR(2)], %g4	! l2esr
	CLEAR_L2_ESR(2, %g4, %g5, %g6)			! clear L2 ESR
	PROCESS_UE_IN_L2_ESR(2, %g1, %g2, %g3, %g4, %g5, %g6, %g7,	\
		.sendnr_ue_resume_exit, .ue_senddiag_resume_exit,	\
		.ue_resume_exit)

.ue_check_l2_b3:
	UE_CHECK_L2_ESR(3, %g1, %g2, %g3, %g4)		! %g1 = L2ESR
	bz	%xcc, .ue_no_error			! XXX spurious?
	nop
	SAVE_L2_LINE_STATE(3, CPU_UE_RPT, %g1, %g2)
	DUMP_L2_SET_TAG_DATA(3, CPU_UE_RPT, %g1, %g2, %g1, %g2)
	ldx	[%g2 + CPU_EVBSC_L2_AFSR(3)], %g4	! l2esr
	CLEAR_L2_ESR(3, %g4, %g5, %g6)			! clear L2 ESR
	PROCESS_UE_IN_L2_ESR(3, %g1, %g2, %g3, %g4, %g5, %g6, %g7,	\
		.sendnr_ue_resume_exit, .ue_senddiag_resume_exit,	\
		.ue_resume_exit)
	!
	! All banks checked, now return
	!
	PRINT("NOTREACHED!\r\n")
	ba,a	.ue_resume_exit

.ue_no_error:
	PRINT("NO_UE_ERROR\r\n")
	! some other thread beat us to it.
	! no bits in L2, simply return (XXX send a service error report?)

.ue_send_resume_exit:
	/*
	 * Precise UEs that are resumable errors get here.
	 * Here the diagnostic erpt is sent before executing
	 * the instruction retry.
	 */
	! send UE diag report
	CPU_STRUCT(%g6)
	add	%g6, CPU_UE_RPT + CPU_VBSC_ERPT, %g1 ! erpt.vbsc
	set	CPU_UE_RPT + CPU_UNSENT_PKT, %g2
	add	%g6, %g2, %g2			! erpt.unsent flag
	mov	EVBSC_SIZE, %g3			! size
	HVCALL(send_diag_erpt)

	ba,a	.ue_resume_exit			! resumable UE epilogue


.tl_overflow:
	PRINT("TL OVERFLOW\r\n")
	! send UE diag report
	CPU_STRUCT(%g6)
	add	%g6, CPU_UE_RPT + CPU_VBSC_ERPT, %g1	! erpt.vbsc
	set	CPU_UE_RPT + CPU_UNSENT_PKT, %g2
	add	%g6, %g2, %g2				! erpt.unsent flag
	mov	EVBSC_SIZE, %g3				! size
	HVCALL(send_diag_erpt)

	RESTORE_UE_GLOBALS()

	ba,a	watchdog_guest

.hpriv_ue:
	! send UE diag report
	CPU_STRUCT(%g6)
	add	%g6, CPU_UE_RPT + CPU_VBSC_ERPT, %g1	! erpt.vbsc
	set	CPU_UE_RPT + CPU_UNSENT_PKT, %g2
	add	%g6, %g2, %g2				! erpt.unsent flag
	mov	EVBSC_SIZE, %g3				! size
	HVCALL(send_diag_erpt)
#ifdef DEBUG
	PRINT("UE in hypervisor - reset the system\r\n")
	rdpr	%tl, %g2
	deccc	%g2
	bz	%xcc, 1f
	nop
	wrpr	%g2, %tl
	PRINT("TPC \r\n")
	rdpr	%tpc, %g1
	PRINTX(%g1)
	PRINT("\r\n")
	PRINT("TT \r\n")
	rdpr	%tt, %g1
	PRINTX(%g1)
	PRINT("\r\n")
	PRINT("TSTATE \r\n")
	rdpr	%tstate, %g1
	PRINTX(%g1)
	PRINT("\r\n")
1:
#endif
	CPU_STRUCT(%g6)
	SPINLOCK_RESUME_ALL_STRAND(%g6, %g1, %g2, %g3, %g4)
	LEGION_EXIT(3)
	! abort HV
	ba,pt	%xcc, hvabort
	mov	ABORT_UE_IN_HV, %g1

.err_resume_abort_bad_guest_err_q:
	CPU_STRUCT(%g6)
	SPINLOCK_RESUME_ALL_STRAND(%g6, %g1, %g2, %g2, %g4)
	ba,pt	%xcc, hvabort
	mov	ABORT_BAD_GUEST_ERR_Q, %g1


.fatal_reset_dbu:		/* this is where we take the system down! */
	! don't care how we got here, stop everything now
	PRINT("Reset the System:  sir 0  %o0=1 fatal error\r\n")
	mov	SIR_TYPE_FATAL_DBU, %o0
	sir	0

	/*
	 * Disrupting UE error handler epilogue
	 * The disrupting UE error handlers return here after handling
	 * the error
	 * NCEEN was not disabled, so disrupting UE handler did not
	 * mask any UEs. But we could have hit some CEs or other
	 * disrupting UEs whose trap will be taken when we return.
	 * Here we queue up the resumable error report to the guest.
	 *
	 * Disrupting UEs use the CE error buffer
	 */
.dis_ue_err_ret:
	PRINT("DIS UE_ERR_RET\r\n")

	/* send diag report to vbsc */
	CPU_STRUCT(%g6)
	add	%g6, CPU_CE_RPT + CPU_VBSC_ERPT, %g1
	add	%g6, CPU_CE_RPT + CPU_UNSENT_PKT, %g2	! erpt.unsent flag
	mov	EVBSC_SIZE, %g3
	HVCALL(send_diag_erpt)

	ASMCALL_RQ_ERPT(CPU_CE_RPT, %g1, %g2, %g3, %g4, %g5, %g6, %g7)

	ba,a	.dis_ue_resume_exit


#if 1 /* XXXX DEAD CODE */
	/*
	 * Precise UE but ressumable error handler epilogue
	 * The precise UE error handlers return here after handling the error
	 * A resumable error will be queued to the affected guest.
	 */
	ENTRY_NP(precise_ue_res_ret)
	PRINT("RES UE_ERR_RET\r\n")
	! Call the function to queue the resumable report
	ASMCALL_RQ_ERPT(CPU_UE_RPT, %g1, %g2, %g3, %g4, %g5, %g6, %g7)
	ba,a	.ue_resume_exit
#endif

.ue_senddiag_resume_exit:
	! send UE diag report
	CPU_STRUCT(%g6)
	add	%g6, CPU_UE_RPT + CPU_VBSC_ERPT, %g1	! erpt.vbsc
	set	CPU_UE_RPT + CPU_UNSENT_PKT, %g2
	add	%g6, %g2, %g2				! erpt.unsent flag
	mov	EVBSC_SIZE, %g3				! size
	HVCALL(send_diag_erpt)

.dis_ue_resume_exit:
.ue_resume_exit:
	! See if CPU is in ERROR and handle the case
	CPU_STRUCT(%g1)
	IS_CPU_IN_ERROR(%g1, %g2)
	bne	%xcc, .ue_continue
	nop
	HVCALL(cpu_in_error)

.ue_continue:
	CPU_STRUCT(%g6)					! restore

	/*
	 * Check whether the UE error handler idled the
	 * strands
	 */
	lduw	[%g6 + CPU_ERR_FLAG], %g2
	btst	ERR_FLAG_STRANDS_NOT_IDLED, %g2
	bnz	%xcc, .ue_continue_not_idled	! strands were not idled
	bclr	ERR_FLAG_STRANDS_NOT_IDLED, %g2	! reset STRANDS_IDLED

	SPINLOCK_RESUME_ALL_STRAND(%g6, %g1, %g2, %g3, %g4)
	ba	.ue_continue_idled		! flag is not set,
	nop					! so skip clearing it

.ue_continue_not_idled:

	stw	%g2, [%g6 + CPU_ERR_FLAG]	!	..

.ue_continue_idled:

	ldx	[%g6 + CPU_ERR_RET], %g7	! get return address
	brnz,a	%g7, .ue_return			!   valid: clear it & return
	  stx	%g0, [%g6+ CPU_ERR_RET]		!           ..
						! NULL: return from interrupt
	RESTORE_UE_GLOBALS()
	retry					! return from UE interrupt

.ue_return:
	HVRET
	SET_SIZE(ue_poll_entry)
	SET_SIZE(ue_err)


	/*
	 * Precise UE error handler epilogue
	 * The precise UE error handlers return here after handling the error
	 * A nonresumable error will be queued to the affected guest.
	 */
	ENTRY_NP(precise_ue_err_ret)
	PRINT("precise_ue_err_ret\r\n")

	! queue nonresumable error report
	CPU_ERPT_STRUCT(CPU_UE_RPT, %g1, %g2)

	/*
	 * Translate error address
	 *
	 * When EATTR_PIO, the error PA is in the RA field of the erpt.
	 * For others, check the four L2 AFARs to find a non-zero
	 * address.
	 */
	lduw	[%g2 + CPU_SUN4V_ERPT + ESUN4V_ATTR], %g4
	btst	EATTR_PIO, %g4
	bz,pt	%xcc, .precise_ue_err_ret_mem
	nop

.precise_ue_err_ret_io:
	/* No affected memory region */
	stw	%g0, [%g2 + CPU_SUN4V_ERPT + ESUN4V_SZ]

	ldx	[%g2 + CPU_SUN4V_ERPT + ESUN4V_RA], %g4
	CPU_ERR_IO_PA_TO_RA(%g1, %g4, %g4, %g3, %g5, %g6, .prec_ue_err_ret_io)
	ba,pt	%xcc, 2f
	nop

.precise_ue_err_ret_mem:
	mov	ERPT_MEM_SIZE, %g4
	stw	%g4, [%g2 + CPU_SUN4V_ERPT + ESUN4V_SZ]
	ldx	[%g2 + CPU_EVBSC_L2_AFAR(0)], %g4
	brnz	%g4, 1f
	nop
	ldx	[%g2 + CPU_EVBSC_L2_AFAR(1)], %g4
	brnz	%g4, 1f
	nop
	ldx	[%g2 + CPU_EVBSC_L2_AFAR(2)], %g4
	brnz	%g4, 1f
	nop
	ldx	[%g2 + CPU_EVBSC_L2_AFAR(3)], %g4
	brnz	%g4, 1f
	nop
	ba,pt	%xcc, 2f
	mov	CPU_ERR_INVALID_RA, %g4

1:
	CPU_STRUCT(%g1)
	CPU_ERR_PA_TO_RA(%g1, %g4, %g4, %g5, %g6)

2:
	stx	%g4, [%g2 + CPU_SUN4V_ERPT + ESUN4V_RA]

	!! %g1 = cpup
	!! %g2 = erpt
	HVCALL(queue_nonresumable_erpt)

	SPINLOCK_RESUME_ALL_STRAND(%g1, %g3, %g4, %g5, %g6)

	/*
	 * Jump to the nonresumable_error trap of the privileged code.
	 * Select trap table entry based on TL.
	 */
	wrpr	%g0, NON_RESUMABLE_TT, %tt

	/*
	 * ensure that the guest is not entered in an illegal state
	 */
	rdpr	%gl, %g1
	cmp	%g1, MAXPGL
	bgu,pn	%xcc, watchdog_guest
	rdpr	%tl, %g1
	cmp	%g1, MAXPTL
	bgu,pn	%xcc, watchdog_guest
	nop 

	/*
	 * Note that it is not possible to reach this point
	 * with GL saturated, so we do not need to use
	 * RESTORE_UE_GLOBALS() here
	 */

	rdpr	%pstate, %g1
	or	%g1, PSTATE_PRIV, %g1	! in case we were in user
	wrpr	%g1, %pstate
	rdpr	%tba, %g1
	add	%g1, (NON_RESUMABLE_TT << TT_OFFSET_SHIFT), %g1
	rdpr	%tl, %g2
	cmp	%g2, 1
	be,pt	%xcc, 2f		! if TL - 1 == 0, go to 2
	set	TRAPTABLE_SIZE, %g5	! set TL bit in trap address
	add	%g5, %g1, %g1		! add TL for TL > 1
2:
	mov	HPSTATE_GUEST, %g5
	jmp	%g1			! jump to priv nonresumable_error
	wrhpr	%g5, %hpstate
	/*NOTREACHED*/
	SET_SIZE(precise_ue_err_ret)

#if CPU_SUN4V_ERPT != 0
#error "CPU_SUN4V_ERPT must be 0"
#endif

/*
 * Queue a resumable error report on this CPU
 * %g1 contains pointer to the CPU structure
 * %g2 contains pointer to the error report
 * (CPU_SUN4V_ERPT *must* be 0x0 for this to be called generically)
 *
 * XXX If there is no free entry in the resumable error queue
 * print a message and return. XXX
 */
	ENTRY_NP(queue_resumable_erpt)
	ldx	[%g1 + CPU_ERRQR_BASE_RA], %g3		! get q base RA
	brnz	%g3, 1f			! if base RA is zero, skip
	nop
	mov	%g7, %g6
	PRINT("RQ NOT ALLOC\r\n")
	mov	%g6, %g7
	! The resumable error queue is not allocated/initialized
	! simply return. No guest is there to receive it.
	jmp	%g7 + 4
	nop

	/*
	 * If this is a MEM error report, ensure that it has a valid
	 * RA for this guest
	 */
	ld	[%g2 + CPU_SUN4V_ERPT + ESUN4V_ATTR], %g4	! attr
	btst	EATTR_MEM, %g4
	bz,pt	%xcc, 1f
	nop
	ldx	[%g2 + CPU_SUN4V_ERPT + ESUN4V_RA], %g4	! ra
	cmp	%g4, CPU_ERR_INVALID_RA
	bne,pt %xcc, 1f
	nop

	! not for this guest, return

	jmp	%g7 + 4
	nop
1:
	mov	ERROR_RESUMABLE_QUEUE_TAIL, %g3
	ldxa	[%g3]ASI_QUEUE, %g5		! %g5 = rq_tail
	add	%g5, 0x40, %g6			! %g6 = rq_next = rq_tail++
	ldx	[%g1 + CPU_ERRQR_MASK], %g4
	and	%g6, %g4, %g6			! %g6 = rq_next mod
	mov	ERROR_RESUMABLE_QUEUE_HEAD, %g3
	ldxa	[%g3] ASI_QUEUE, %g4		! %g4 = rq_head
	cmp	%g6, %g4			! head = ++tail?
	be	%xcc, .rq_full
	mov	ERROR_RESUMABLE_QUEUE_TAIL, %g3
	stxa	%g6, [%g3] ASI_QUEUE		! new tail = rq_next
	! write up the queue record
	ldx	[%g1 + CPU_ERRQR_BASE], %g4
	add	%g5, %g4, %g3			! %g3 = base + tail
	ldx	[%g2 + CPU_SUN4V_ERPT + ESUN4V_G_EHDL], %g4	! ehdl
	stx	%g4, [%g3 + 0x0]
	ldx	[%g2 + CPU_SUN4V_ERPT + ESUN4V_G_STICK], %g4	! stick
	stx	%g4, [%g3 + 0x8]
	ld	[%g2 + CPU_SUN4V_ERPT + ESUN4V_EDESC], %g4	! edesc
	st	%g4, [%g3 + 0x10]
	ld	[%g2 + CPU_SUN4V_ERPT + ESUN4V_ATTR], %g4	! attr
	st	%g4, [%g3 + 0x14]
	ldx	[%g2 + CPU_SUN4V_ERPT + ESUN4V_RA], %g4	! ra
	stx	%g4, [%g3 + 0x18]
	ld	[%g2 + CPU_SUN4V_ERPT + ESUN4V_SZ], %g4	! sz
	st	%g4, [%g3 + 0x20]
	lduh	[%g2 + CPU_SUN4V_ERPT + ESUN4V_G_CPUID], %g4	! cpuid
	stuh	%g4, [%g3 + 0x24]
	lduh	[%g2 + CPU_SUN4V_ERPT + ESUN4V_G_SECS], %g4
	stuh	%g4, [%g3 + 0x26]		! pad/secs
	stx	%g0, [%g3 + 0x28]		! word5
	stx	%g0, [%g3 + 0x30]		! word6
	stx	%g0, [%g3 + 0x38]		! word7

	jmp	%g7 + 4
	nop

.rq_full:
	! The resumable error queue is full.
	! simply return
	mov	%g7, %g6
	PRINT("RQ FULL\r\n")
	mov	%g6, %g7

	jmp	%g7 + 4
	nop
	SET_SIZE(queue_resumable_erpt)

/*
 * Queue a nonresumable error report on this CPU
 * %g1 contains pointer to the CPU structure
 * %g2 contains pointer to the error report
 *
 * If there is no free entry in the nonresumable error queue
 * print a message and abort the guest.
 *
 * This routine just moves the erpt to the queue, it does not
 * modify the data.
 */
	ENTRY_NP(queue_nonresumable_erpt)
	ldx	[%g1 + CPU_ERRQNR_BASE_RA], %g3		! get q base RA
	brz,pn	%g3, .queue_nonresumable_bad_queue
	nop
	mov	ERROR_NONRESUMABLE_QUEUE_TAIL, %g3
	ldxa	[%g3]ASI_QUEUE, %g5		! %g5 = rq_tail
	add	%g5, 0x40, %g6			! %g6 = rq_next = rq_tail++
	ldx	[%g1 + CPU_ERRQNR_MASK], %g4
	and	%g6, %g4, %g6			! %g6 = rq_next mod
	mov	ERROR_NONRESUMABLE_QUEUE_HEAD, %g3
	ldxa	[%g3] ASI_QUEUE, %g4		! %g4 = rq_head
	cmp	%g6, %g4			! head = ++tail?
	be,pn	%xcc, .queue_nonresumable_full_queue
	mov	ERROR_NONRESUMABLE_QUEUE_TAIL, %g3
	stxa	%g6, [%g3]ASI_QUEUE		! new tail = rq_next
	! write the queue record
	ldx	[%g1 + CPU_ERRQNR_BASE], %g4
	add	%g5, %g4, %g3			! %g3 = base + tail
	ldx	[%g2 + CPU_SUN4V_ERPT + ESUN4V_G_EHDL], %g4	! ehdl
	stx	%g4, [%g3 + 0x0]
	ldx	[%g2 + CPU_SUN4V_ERPT + ESUN4V_G_STICK], %g4	! stick
	stx	%g4, [%g3 + 0x8]
	ld	[%g2 + CPU_SUN4V_ERPT + ESUN4V_EDESC], %g4	! edesc
	st	%g4, [%g3 + 0x10]
	ld	[%g2 + CPU_SUN4V_ERPT + ESUN4V_ATTR], %g4	! attr
	st	%g4, [%g3 + 0x14]
	ldx	[%g2 + CPU_SUN4V_ERPT + ESUN4V_RA], %g4	! ra
	stx	%g4, [%g3 + 0x18]
	ld	[%g2 + CPU_SUN4V_ERPT + ESUN4V_SZ], %g4	! sz
	st	%g4, [%g3 + 0x20]
	lduh	[%g2 + CPU_SUN4V_ERPT + ESUN4V_G_CPUID], %g4	! cpuid
	stuh	%g4, [%g3 + 0x24]
	stuh	%g0, [%g3 + 0x26]		! pad
	stx	%g0, [%g3 + 0x28]		! word5
	stx	%g0, [%g3 + 0x30]		! word6
	stx	%g0, [%g3 + 0x38]		! word7

	mov	%g7, %g6
	PRINT("queue_nonresumable_erpt: entry enqueued\r\n")
	mov	%g6, %g7

	HVRET

.queue_nonresumable_full_queue:
	/*
	 * The nonresumable error queue is full.
	 * Reset the guest
	 */
#ifdef DEBUG
	mov	%g7, %g6
	PRINT("queue_nonresumable_erpt: nrq full - exiting guest\r\n")
	mov	%g6, %g7
#endif
	ba,a	.queue_nonresumable_abort

.queue_nonresumable_bad_queue:
	/*
	 * The nonresumable error queue is not allocated/initialized
	 * Reset the guest
	 */
#ifdef DEBUG
	mov	%g7, %g6
	PRINT("NRQ NOT ALLOC - exiting guest\r\n")
	mov	%g6, %g7
#endif
	/* fall through */

.queue_nonresumable_abort:
#ifdef NIAGARA_BRINGUP
	rdpr	%tl, %g2
	deccc	%g2
	bz	%xcc, 1f
	nop
	wrpr	%g2, %tl
	PRINT("TPC \r\n")
	rdpr	%tpc, %g1
	PRINTX(%g1)
	PRINT("\r\n")
	PRINT("TT \r\n")
	rdpr	%tt, %g1
	PRINTX(%g1)
	PRINT("\r\n")
	PRINT("TSTATE \r\n")
	rdpr	%tstate, %g1
	PRINTX(%g1)
	PRINT("\r\n")
1:
#endif
	ba,a	.err_resume_abort_bad_guest_err_q
	SET_SIZE(queue_nonresumable_erpt)

/*
 * JBUS error
 */
	ENTRY(ue_jbus_err)

	CPU_ERPT_STRUCT(CPU_UE_RPT, %g6, %g5)	! g6->cpu, g5->cpu.ue_rpt

	SPINLOCK_IDLE_ALL_STRAND(%g6, %g1, %g2, %g3, %g4)
	! At this point, this is the only strand executing

	/*
	 * Generate a basic error report
	 */
	LOAD_BASIC_ERPT(%g6, %g5, %g1, %g2)

	/*
	 * Clear unused diag buf fields
	 */
	stx	%g0, [%g5 + CPU_VBSC_ERPT + EVBSC_SPARC_AFSR]
	stx     %g0, [%g5 + CPU_VBSC_ERPT + CPU_EVBSC_L2_AFSR(0)]
	stx     %g0, [%g5 + CPU_VBSC_ERPT + CPU_EVBSC_L2_AFSR(1)]
	stx     %g0, [%g5 + CPU_VBSC_ERPT + CPU_EVBSC_L2_AFSR(2)]
	stx     %g0, [%g5 + CPU_VBSC_ERPT + CPU_EVBSC_L2_AFSR(3)]
	stx     %g0, [%g5 + CPU_VBSC_ERPT + CPU_EVBSC_DRAM_AFSR(0)]
	stx     %g0, [%g5 + CPU_VBSC_ERPT + CPU_EVBSC_DRAM_AFSR(1)]
	stx     %g0, [%g5 + CPU_VBSC_ERPT + CPU_EVBSC_DRAM_AFSR(2)]
	stx     %g0, [%g5 + CPU_VBSC_ERPT + CPU_EVBSC_DRAM_AFSR(3)]

	 ! Store JBUS error data in error report

	DUMP_JBI_SSI(%g6, %g5, %g3, %g4, %g1, %g2, %g7)

	! send UE diag report

	add	%g6, CPU_UE_RPT + CPU_VBSC_ERPT, %g1	! erpt.vbsc
	set	CPU_UE_RPT + CPU_UNSENT_PKT, %g2
	add	%g6, %g2, %g2				! erpt.unsent flag
	mov	EVBSC_SIZE, %g3				! size
	HVCALL(send_diag_erpt)

	! abort the hypervisor now

	CPU_STRUCT(%g6)
	SPINLOCK_RESUME_ALL_STRAND(%g6, %g1, %g2, %g3, %g4)
	LEGION_EXIT(3)
	! abort HV
	ba,pt	%xcc, hvabort
	mov	ABORT_JBI_ERR, %g1
	SET_SIZE(ue_jbus_err)


	/*
	 * irc_check(uint64_t sparc_ear) [Non-LEAF]
	 *
	 * Checks whether the IRC error is transient or persistent.
	 * Before we re-read the register in error, we set the irc_ear
	 * in the CPU struct to the SPARC EAR value, which has the reg#
	 * and the syndrome. A zero syndrome is not possible for error,
	 * therefore irc_ear == 0 means IRC trap didn't set it.
	 * (Note %g0 like other registers can generate errors.)
	 * If the IRU trap is taken because of a persistent uncorrectable error,
	 * the IRU trap handler will check the irc_ear field with the SPARC_EAR
	 * logged. If they are the same, then IRU trap handler clears the
	 * irc_ear field and returns.
	 *
 	 *	set_ircear(sparc_ear)
 	 *	irf_reread(sparc_ear)
 	 *	if (CPU.irc_ear == 0)
 	 *		return RF_PERSISTENT;
 	 *	else {
 	 *		CPU.irc_ear = 0;
 	 *		return RF_TRANSIENT;
 	 *	}
	 * Arguments:
	 *	%g1 - input - SPARC EAR - clobbered
	 *	%g2 - output (RF_TRANSIENT, RF_PERSISTENT)
	 *	%g3 - scratch
	 *	%g4 - scratch
	 *	%g5 - erpt
	 *	%g6 - cpup
	 *	%g7 - return address
	 */
	ENTRY_NP(irc_check)

	! init CPU.irc_ear
	stx	%g1, [%g6 + CPU_REGERR] ! CPU.irc_ear = sparc EAR (!=0)

	! reread register
	mov	%g7, %g6		! save return address
	HVCALL(irf_reread)		! %g1 has SPARC EAR
	mov	%g6, %g7		! restore return address

	CPU_STRUCT(%g6)			! restore g6->cpu

	! check CPU.irc_ear
	ldx	[%g6 + CPU_REGERR], %g2 ! read CPU.irc_ear
	brz	%g2, .irc_ret		! persistent error
	mov	RF_PERSISTENT, %g2

	! transient error. H/W has fixed it now after the reread
	! get back to interrupted program
	stx	%g0, [%g6 + CPU_REGERR]		! clear irc_ear
	mov	RF_TRANSIENT, %g2		! return transient
.irc_ret:
	HVRET
	SET_SIZE(irc_check)


	/*
	 * int iru_check(uint64_t sparc_ear) [Non-Leaf]
	 *
	 * Check whether the IRU error is transient, persistent
	 *   or if the integer register file is flaky.
	 *
	 *	clear_irf_ue(sparc_ear);
	 *	irf_reread(sparc_ear);
	 *	if (SPARC_ESR.IRU == 0) {
	 *		return RF_TRANSIENT;
	 *	}
	 *	if (SPARC_EAR == sparc_ear)
	 *		return RF_PERSISTENT;
	 *	} else {
	 *		return RF_FAILURE;
	 *	}
	 * Arguments:
	 *	%g1 - input - SPARC EAR - clobbered
	 *	%g2 - output (RF_TRANSIENT, RF_PERSISTENT, RF_FAILURE)
	 *	%g3 - scratch
	 *	%g4 - scratch
	 *	%g5 - erpt pointer
	 *	%g6 - cpu pointer
	 */
	ENTRY_NP(iru_check)
	mov	%g7, %g6			! save return address

	HVCALL(clear_irf_ue)			! %g1 has SPARC EAR

	! reread register
	HVCALL(irf_reread)			! %g1 has SPARC EAR

	mov	%g6, %g7			! restore return address
	CPU_STRUCT(%g6)				! restore cpup

	! check SPARC ESR for IRU error
	ldxa	[%g0]ASI_SPARC_ERR_STATUS, %g4	! get SPARC ESR
	set	SPARC_ESR_IRU, %g3		! IRU bit
	btst	%g3, %g4			! check for IRU
	bz	%xcc, .iru_ret			!   no:
	mov	RF_TRANSIENT, %g2		!      return transient

	! persistent IRU error?
	! check EAR for match
	ldxa	[%g0]ASI_SPARC_ERR_ADDR, %g2	! get SPARC EAR
	ldx	[%g5 + CPU_VBSC_ERPT + EVBSC_SPARC_AFAR], %g1	! saved EAR
	xor	%g2, %g1, %g2			! Are they the same?
	andcc	%g2, SPARC_EAR_IREG_MASK, %g2	! (ignore non-register bits)
	bnz	%xcc, .iru_ret			!   no:
	mov	RF_FAILURE, %g2			!      return reg file failure
	stxa	%g4, [%g0]ASI_SPARC_ERR_STATUS	!   yes: clear SPARC ESR
	mov	RF_PERSISTENT, %g2		!      return persistent error
.iru_ret:
	HVRET					! return to caller
	SET_SIZE(iru_check)


	/*
	 * void irf_reread(uint64_t sparc_ear) [LEAF function]
	 *
	 * Caller: IRC or IRU handler
	 *
	 * Re-read integer register in error
	 * Arguments:
	 *	%g1 - input - SPARC_EAR
	 *	%g2 - %g4 - scratch
	 *	%g5, %g6 - preserved
	 *	%g7 - return address
	 */
	ENTRY_NP(irf_reread)
	and	%g1, SPARC_EAR_IREG_MASK, %g2
	srlx	%g2, SPARC_EAR_IREG_SHIFT, %g2	! %g2 has int reg num

	! %g2 has the int reg# in error.
	! Current window is pointing to the window of the reg in error

	! get the register number within the set
	and	%g2, 0x1f, %g2			! mask off GL/CWP
	cmp	%g2, 8				! is reg# < 8?
	bl	.glob				! yes, then global reg
	nop

	! Now re-read the register in error
	ba	1f				! do reread
	rd	%pc, %g3			! get reread instr base addr
	! an array of instruction blocks indexed by  register number to
	! reread the non-global register reported in error.
	or	%g0, %o0, %o0		! reread %o0
	ba,a	.reread_done
	or	%g0, %o1, %o1		! reread %o1
	ba,a	.reread_done
	or	%g0, %o2, %o2		! reread %o2
	ba,a	.reread_done
	or	%g0, %o3, %o3		! reread %o3
	ba,a	.reread_done
	or	%g0, %o4, %o4		! reread %o4
	ba,a	.reread_done
	or	%g0, %o5, %o5		! reread %o5
	ba,a	.reread_done
	or	%g0, %o6, %o6		! reread %o6
	ba,a	.reread_done
	or	%g0, %o7, %o7		! reread %o7
	ba,a	.reread_done
	or	%g0, %l0, %l0		! reread %l0
	ba,a	.reread_done
	or	%g0, %l1, %l1		! reread %l1
	ba,a	.reread_done
	or	%g0, %l2, %l2		! reread %l2
	ba,a	.reread_done
	or	%g0, %l3, %l3		! reread %l3
	ba,a	.reread_done
	or	%g0, %l4, %l4		! reread %l4
	ba,a	.reread_done
	or	%g0, %l5, %l5		! reread %l5
	ba,a	.reread_done
	or	%g0, %l6, %l6		! reread %l6
	ba,a	.reread_done
	or	%g0, %l7, %l7		! reread %l7
	ba,a	.reread_done
	or	%g0, %i0, %i0		! reread %i0
	ba,a	.reread_done
	or	%g0, %i1, %i1		! reread %i1
	ba,a	.reread_done
	or	%g0, %i2, %i2		! reread %i2
	ba,a	.reread_done
	or	%g0, %i3, %i3		! reread %i3
	ba,a	.reread_done
	or	%g0, %i4, %i4		! reread %i4
	ba,a	.reread_done
	or	%g0, %i5, %i5		! reread %i5
	ba,a	.reread_done
	or	%g0, %i6, %i6		! reread %i6
	ba,a	.reread_done
	or	%g0, %i7, %i7		! reread %i7
	ba,a	.reread_done
1:
	sub	%g2, 8, %g2		! skip globals
	sllx	%g2, 3, %g2		! offset = reg# * 8
	add	%g3, %g2, %g3		! %g3 = instruction block addr

	ldxa	[%g0]ASI_SPARC_ERR_EN, %g2	! save current in %g2
	andn	%g2, CEEN, %g4			! disable CEEN
	stxa	%g4, [%g0] ASI_SPARC_ERR_EN	!    ..

	jmp	%g3 + SZ_INSTR			! jmp to reread register
	nop

	! restore gl from value in %o0, and restore %o0
.gl_reread_done:
	wrpr	%o0, %gl			! restore %gl
	mov	%g4, %o0			! restore %o0

	! Here, we check the iregerr field after the reread. If it
	! is zero, then we know it is a persistent uncorrectable error.
	! If it is nonzero, then we know it is a transient error.
.reread_done:
	stxa	%g2, [%g0] ASI_SPARC_ERR_EN	! restore CEEN
	HVRET					! return to caller

	! %g2 has the register number
.glob:
	! now re-read the global register in error
	ba	1f
	rd	%pc, %g3		! reread instruction base addr
	! an array of instructions blocks indexed by global register number
	! to reread the global register reported in error.
	! %gl points to the error global set
	or	%g0, %g0, %g0		! reread %g0 (yay!)
	ba,a	.gl_reread_done
	or	%g0, %g1, %g1		! reread %g1
	ba,a	.gl_reread_done
	or	%g0, %g2, %g2		! reread %g2
	ba,a	.gl_reread_done
	or	%g0, %g3, %g3		! reread %g3
	ba,a	.gl_reread_done
	or	%g0, %g4, %g4		! reread %g4
	ba,a	.gl_reread_done
	or	%g0, %g5, %g5		! reread %g5
	ba,a	.gl_reread_done
	or	%g0, %g6, %g6		! reread %g6
	ba,a	.gl_reread_done
	or	%g0, %g7, %g7		! reread %g7
	ba,a	.gl_reread_done
1:
	sllx	%g2, 3, %g2			! offset (2 instrs)
	add	%g3, %g2, %g3			! %g3 = instruction entry

	ldxa	[%g0]ASI_SPARC_ERR_EN, %g2	! save current in %g2
	andn	%g2, CEEN, %g4			! disable CEEN
	stxa	%g4, [%g0] ASI_SPARC_ERR_EN	!    ..

	mov	%o0, %g4			! save %o0 in %g4
	rdpr	%gl, %o0			! save %gl in %o0

	! set gl to error global
	and	%g1, SPARC_EAR_GL_MASK, %g1	! get global set from EAR
	srlx	%g1, SPARC_EAR_GL_SHIFT, %g1	! %g1 has %gl value

	jmp	%g3 + SZ_INSTR			! jump to reread global
	wrpr	%g1, %gl			! set gl to error gl
	SET_SIZE(irf_reread)


	/* clear_iregerr(sparc_ear) [LEAF Function]
	 *
	 * Clear CPU.iregerr if the IRU register in error == CPU.iregerr
	 * Return 0 if CPU.iregerr matches, and 1 if no match
	 * Arguments:
	 *	%g1 - SPARC EAR
	 *	%g2 - output - 0 if CPU.iregerr matches, 1 if no match
	 *	%g3, %g4 - scratch
	 *	%g5 - erpt pointer
	 *	%g6 - cpu pointer
	 *	%g7 - return address
	 */
	ENTRY_NP(clear_iregerr)
	ldx	[%g6 + CPU_REGERR], %g3		! %g3 = CPU.iregerr

	! compare the register number from EAR
	xor	%g3, %g1, %g3			! Are they the same?
	andcc	%g3, SPARC_EAR_IREG_MASK, %g3	! (ignore non-register bits)
	bz	%xcc, .ireg_match		! yes, then clear
	nop
	mov	1, %g2				! return 1 for no match
	HVRET

	! %g4 has CPU.iregerr address
	! IRU was taken from IRC trap handler reread attempt
.ireg_match:
	stx	%g0, [%g6 + CPU_REGERR]		! clear CPU.iregerr
	mov	%g0, %g2			! return 0 for ireg match
	HVRET
	SET_SIZE(clear_iregerr)


	/*
	 * void clear_irf_ue(uint64_t sparc_ear)
	 *
	 * Clear the UE in the integer register file
	 * Arguments:
	 *	%g1 - input - SPARC EAR
	 *	%g2-%g4 -scratch
	 *	%g5, %g6 - preserved
	 *	%g7 - return address
	 */
	ENTRY_NP(clear_irf_ue)
	and	%g1, SPARC_EAR_IREG_MASK, %g2
	srlx	%g2, SPARC_EAR_IREG_SHIFT, %g2	! %g2 has int reg num
	! get the register number within the set
	and	%g2, 0x1f, %g2			! mask off GL/CWP
	cmp	%g2, 8				! is reg# < 8?
	bl	.glob_ue			! yes, then global reg
	nop

	! Now clear the register in error
	ba	1f				! clear register
	rd	%pc, %g3			! get clear instr base addr
	! an array of instruction blocks indexed by  register number to
	! clear the non-global register reported in error.
	mov	%g0, %o0		! clear %o0
	ba,a	.clear_done
	mov	%g0, %o1		! clear %o1
	ba,a	.clear_done
	mov	%g0, %o2		! clear %o2
	ba,a	.clear_done
	mov	%g0, %o3		! clear %o3
	ba,a	.clear_done
	mov	%g0, %o4		! clear %o4
	ba,a	.clear_done
	mov	%g0, %o5		! clear %o5
	ba,a	.clear_done
	mov	%g0, %o6		! clear %o6
	ba,a	.clear_done
	mov	%g0, %o7		! clear %o7
	ba,a	.clear_done
	mov	%g0, %l0		! clear %l0
	ba,a	.clear_done
	mov	%g0, %l1		! clear %l1
	ba,a	.clear_done
	mov	%g0, %l2		! clear %l2
	ba,a	.clear_done
	mov	%g0, %l3		! clear %l3
	ba,a	.clear_done
	mov	%g0, %l4		! clear %l4
	ba,a	.clear_done
	mov	%g0, %l5		! clear %l5
	ba,a	.clear_done
	mov	%g0, %l6		! clear %l6
	ba,a	.clear_done
	mov	%g0, %l7		! clear %l7
	ba,a	.clear_done
	mov	%g0, %i0		! clear %i0
	ba,a	.clear_done
	mov	%g0, %i1		! clear %i1
	ba,a	.clear_done
	mov	%g0, %i2		! clear %i2
	ba,a	.clear_done
	mov	%g0, %i3		! clear %i3
	ba,a	.clear_done
	mov	%g0, %i4		! clear %i4
	ba,a	.clear_done
	mov	%g0, %i5		! clear %i5
	ba,a	.clear_done
	mov	%g0, %i6		! clear %i6
	ba,a	.clear_done
	mov	%g0, %i7		! clear %i7
	ba,a	.clear_done
1:
	sub	%g2, 8, %g2		! skip globals
	sllx	%g2, 3, %g2		! offset = reg# * 8
	add	%g3, %g2, %g3		! %g3 = instruction block addr
	jmp	%g3 + SZ_INSTR		! jmp to clear register
	nop

	! restore gl from value in %o0, and restore %o0
.gl_clear_done:
	wrpr	%o0, %gl		! restore %gl
	mov	%g4, %o0		! restore %o0

	! Here, we check the iregerr field after the reread. If it
	! is zero, then we know it is a persistent uncorrectable error.
	! If it is nonzero, then we know it is a transient error.
.clear_done:
	HVRET				! return to caller

	! %g2 has the gl + register number
.glob_ue:
	! now re-read the global register in error
	ba	1f
	rd	%pc, %g3		! get clear instr base addr
	! an array of instructions blocks indexed by global register number
	! to clear the global register reported in error.
	! %gl points to the error global set
	mov	%g0, %g0		! clear %g0 (yay!)
	ba,a	.gl_clear_done
	mov	%g0, %g1		! clear %g1
	ba,a	.gl_clear_done
	mov	%g0, %g2		! clear %g2
	ba,a	.gl_clear_done
	mov	%g0, %g3		! clear %g3
	ba,a	.gl_clear_done
	mov	%g0, %g4		! clear %g4
	ba,a	.gl_clear_done
	mov	%g0, %g5		! clear %g5
	ba,a	.gl_clear_done
	mov	%g0, %g6		! clear %g6
	ba,a	.gl_clear_done
	mov	%g0, %g7		! clear %g7
	ba,a	.gl_clear_done
1:
	sllx	%g2, 3, %g2			! offset (2 instrs)
	add	%g3, %g2, %g3			! %g3 = instruction entry
	mov	%o0, %g4			! save %o0 in %g4
	rdpr	%gl, %o0			! save %gl in %o0

	! set gl to error global
	and	%g1, SPARC_EAR_GL_MASK, %g2	! get global set from EAR
	srlx	%g2, SPARC_EAR_GL_SHIFT, %g2	! %g2 has %gl value

	jmp	%g3 + SZ_INSTR			! jump to clear global
	wrpr	%g2, %gl			! set gl to error gl
	SET_SIZE(clear_irf_ue)


	/*
	 * frc_check(uint64_t sparc_ear) [Non-Leaf]
	 *
	 * Check whether the FRC error is transient or persistent.
	 * Before we re-read the register in error, we set the frc_ear
	 * in the CPU struct to the SPARC EAR value, which has the reg#
	 * and the syndrome. A zero syndrome is not possible for error,
	 * therefore frc_ear == 0 means FRC trap didn't set it.
	 * (Note %g0 like other registers can generate errors.)
	 * If the FRU trap is taken because of a persistent uncorrectable error,
	 * the FRU trap handler will check the frc_ear field with the SPARC_EAR
	 * logged. If they are the same, then FRU trap handler clears the
	 * frc_ear field and returns.
	 *
 	 *	set_frcear(sparc_ear)
 	 *	frf_reread(sparc_ear)
 	 *	if (cpu.frc_ear == 0)
 	 *		return RF_PERSISTENT;
 	 *	else {
 	 *		cpu.frc_ear = 0;
 	 *		return RF_TRANSIENT;
 	 *	}
	 * Arguments:
	 *	%g1 - input - SPARC EAR - clobbered
	 *	%g2 - output (RF_TRANSIENT, RF_PERSISTENT)
	 *	%g3 - scratch
	 *	%g4 - scratch
	 *	%g5 - erpt pointer
	 *	%g6 - cpu pointer
	 */
	ENTRY_NP(frc_check)

	! init cpu.frc_ear
	stx	%g1, [%g6 + CPU_REGERR]		! cpu.frc_ear = sparc EAR (!=0)

	/*
	 * It is possible that FPRS.FEF was disabled when we took the disrupting trap
	 * caused by the FP CE.  We must ensure that FPRS.FEF is enabled before
	 * calling frf_reread().
	 *
	 * Note that the Sparc V9 spec mandates that PSTATE.PEF be enabled when we
	 * take a trap if there is an FPU present. As this error condition can only
	 * occur with an FPU we do not need to verify PSTATE.PEF here.
	 */
	rd	%fprs, %g5
	btst	FPRS_FEF, %g5			! FPRS.FEF set ?
	bz,a,pn	%xcc, 1f			! no: set it
	  wr	%g5, FPRS_FEF, %fprs		! yes: annulled
1:
	! reread register
	mov	%g7, %g6			! save return address
	HVCALL(frf_reread)			! %g1 has SPARC EAR, %g5/%g6 preserved
	wr	%g5, %g0, %fprs			! restore FPRS
	mov	%g6, %g7			! restore return address

	CPU_STRUCT(%g6)				! restore g6->cpu
	! restore %g5
	CPU_ERPT_STRUCT(CPU_CE_RPT, %g6, %g5)	! g6->cpu, g5->cpu.ce_rpt

	! check cpu.frc_ear
	ldx	[%g6 + CPU_REGERR], %g2		! read cpu.frc_ear
	brz	%g2, .frc_ret			! persistent error
	mov	RF_PERSISTENT, %g2

	! transient error. H/W has fixed it now after the reread
	! get back to interrupted program
	stx	%g0, [%g6 + CPU_REGERR]		! clear frc_ear
	mov	RF_TRANSIENT, %g2		! return transient
.frc_ret:
	HVRET
	SET_SIZE(frc_check)


	/*
	 * fru_check(uint64_t sparc_ear) [Non-Leaf]
	 *
	 * Check whether the FRU error is transient or persistent
	 *   or if the floating point register file is failing.
	 *	clear_frf_ue(sparc_ear);
	 *	frf_reread(sparc_ear);
	 *	if (SPARC_ESR.FRU == 0) {
	 *		return RF_TRANSIENT;
	 *	}
	 *	if (SPARC_EAR == sparc_ear)
	 *		return RF_PERSISTENT;
	 *	} else {
	 *		return RF_FAILURE;
	 *	}
	 * Arguments:
	 *	%g1 - input - SPARC EAR - clobbered
	 *	%g2 - output (RF_TRANSIENT, RF_PERSISTENT, RF_FAILURE)
	 *	%g3 - scratch
	 *	%g4 - scratch
	 *	%g5 - erpt pointer
	 *	%g6 - cpu pointer
	 */
	ENTRY_NP(fru_check)
	mov	%g7, %g6			! save return address

	HVCALL(clear_frf_ue)			! %g1 has SPARC EAR

	! reread register
	HVCALL(frf_reread)			! %g1 has SPARC EAR

	mov	%g6, %g7			! restore return address
	CPU_STRUCT(%g6)				! restore cpup

	! check SPARC ESR for FRU error
	ldxa	[%g0]ASI_SPARC_ERR_STATUS, %g4	! get SPARC ESR
	set	SPARC_ESR_FRU, %g3		! FRU bit
	btst	%g3, %g4			! check for FRU
	bz	%xcc, .fru_ret			!   no:
	mov	RF_TRANSIENT, %g2		!      return transient

	! persistent FRU error?
	! check EAR for match
	ldxa	[%g0]ASI_SPARC_ERR_ADDR, %g2	! get SPARC EAR
	ldx	[%g5 + CPU_VBSC_ERPT + EVBSC_SPARC_AFAR], %g1	! saved EAR
	xor	%g2, %g1, %g2			! Are they the same?
	andcc	%g2, SPARC_EAR_FPREG_MASK, %g2	! (ignore non-register bits)
	bnz	%xcc, .fru_ret			!   no:
	mov	RF_FAILURE, %g2			!      return reg file failure
	stxa	%g4, [%g0]ASI_SPARC_ERR_STATUS	!   yes: clear SPARC ESR
	mov	RF_PERSISTENT, %g2		!      return persistent
.fru_ret:
	HVRET					! return to caller
	SET_SIZE(fru_check)


	/*
	 * IRF Uncorrectible ECC Error
	 *
	 *	if (clear_iregerr(sparc_ear) == MATCH from IRC) {
	 *		DONE;
	 *	} else {
	 *		if (iru_check(sparc_ear) == RF_PERSISTENT) {
	 *			CPU.status = mark CPU in ERROR;
	 *			if ((CPUnext = avail(partID)) != NULL) {
	 *				x_call(CPUnext, I_AM_IN_ERROR);
	 *				stop_self();
	 *			} else {
	 *				q_service_error_report(spi);
	 *				stop_self(); - watchdog reset later?
	 *			}
	 *		} else {
	 *			q_sun4v_error_report(nrq);
	 *			q_service_error_report(spi);
	 *			jmp nonresumable_error trap handler
	 *		}
	 *	}
	 */


	/*
	 * frf_reread(uint64_t sparc_ear)	[LEAF function]
	 *
	 * Reread the FRF register in error.
	 * Arguments:
	 *	%g1 - input - SPARC EAR
	 *	%g2 - %g4 - scratch
	 *	%g5, %g6 - preserved
	 *	%g7 - return address
	 */
	ENTRY_NP(frf_reread)
	and	%g1, SPARC_EAR_FPREG_MASK, %g2
	srlx	%g2, SPARC_EAR_FPREG_SHIFT, %g2	! %g2 has 6-bit fpreg number

	! Now reread the register in error
	ba	1f
	rd	%pc, %g3			! %g3 = base address

	! an array of instruction blocks indexed by register number to
	! reread the floating-point register reported in error
	! The first 32 entries use single-precision register
	! The next 32 entries reread the double-precision register
	fmovs	%f0, %f0				! reread %f0
	ba,a	.fp_reread_done
	fmovs	%f1, %f1				! reread %f1
	ba,a	.fp_reread_done
	fmovs	%f2, %f2				! reread %f2
	ba,a	.fp_reread_done
	fmovs	%f3, %f3				! reread %f3
	ba,a	.fp_reread_done
	fmovs	%f4, %f4				! reread %f4
	ba,a	.fp_reread_done
	fmovs	%f5, %f5				! reread %f5
	ba,a	.fp_reread_done
	fmovs	%f6, %f6				! reread %f6
	ba,a	.fp_reread_done
	fmovs	%f7, %f7				! reread %f7
	ba,a	.fp_reread_done
	fmovs	%f8, %f8				! reread %f8
	ba,a	.fp_reread_done
	fmovs	%f9, %f9				! reread %f9
	ba,a	.fp_reread_done
	fmovs	%f10, %f10				! reread %f10
	ba,a	.fp_reread_done
	fmovs	%f11, %f11				! reread %f11
	ba,a	.fp_reread_done
	fmovs	%f12, %f12				! reread %f12
	ba,a	.fp_reread_done
	fmovs	%f13, %f13				! reread %f13
	ba,a	.fp_reread_done
	fmovs	%f14, %f14				! reread %f14
	ba,a	.fp_reread_done
	fmovs	%f15, %f15				! reread %f15
	ba,a	.fp_reread_done
	fmovs	%f16, %f16				! reread %f16
	ba,a	.fp_reread_done
	fmovs	%f17, %f17				! reread %f17
	ba,a	.fp_reread_done
	fmovs	%f18, %f18				! reread %f18
	ba,a	.fp_reread_done
	fmovs	%f19, %f19				! reread %f19
	ba,a	.fp_reread_done
	fmovs	%f20, %f20				! reread %f20
	ba,a	.fp_reread_done
	fmovs	%f21, %f21				! reread %f21
	ba,a	.fp_reread_done
	fmovs	%f22, %f22				! reread %f22
	ba,a	.fp_reread_done
	fmovs	%f23, %f23				! reread %f23
	ba,a	.fp_reread_done
	fmovs	%f24, %f24				! reread %f24
	ba,a	.fp_reread_done
	fmovs	%f25, %f25				! reread %f25
	ba,a	.fp_reread_done
	fmovs	%f26, %f26				! reread %f26
	ba,a	.fp_reread_done
	fmovs	%f27, %f27				! reread %f27
	ba,a	.fp_reread_done
	fmovs	%f28, %f28				! reread %f28
	ba,a	.fp_reread_done
	fmovs	%f29, %f29				! reread %f29
	ba,a	.fp_reread_done
	fmovs	%f30, %f30				! reread %f30
	ba,a	.fp_reread_done
	fmovs	%f30, %f31				! reread %f31
	ba,a	.fp_reread_done
	! double precision register pairs, reread both of them on errors
	fmovd	%f32, %f32				! reread %f32
	ba,a	.fp_reread_done
	fmovd	%f32, %f32				! reread %f32
	ba,a	.fp_reread_done
	fmovd	%f34, %f34				! reread %f34
	ba,a	.fp_reread_done
	fmovd	%f34, %f34				! reread %f34
	ba,a	.fp_reread_done
	fmovd	%f36, %f36				! reread %f36
	ba,a	.fp_reread_done
	fmovd	%f36, %f36				! reread %f36
	ba,a	.fp_reread_done
	fmovd	%f38, %f38				! reread %f38
	ba,a	.fp_reread_done
	fmovd	%f38, %f38				! reread %f38
	ba,a	.fp_reread_done
	fmovd	%f40, %f40				! reread %f40
	ba,a	.fp_reread_done
	fmovd	%f40, %f40				! reread %f40
	ba,a	.fp_reread_done
	fmovd	%f42, %f42				! reread %f42
	ba,a	.fp_reread_done
	fmovd	%f42, %f42				! reread %f42
	ba,a	.fp_reread_done
	fmovd	%f44, %f44				! reread %f44
	ba,a	.fp_reread_done
	fmovd	%f44, %f44				! reread %f44
	ba,a	.fp_reread_done
	fmovd	%f46, %f46				! reread %f46
	ba,a	.fp_reread_done
	fmovd	%f46, %f46				! reread %f46
	ba,a	.fp_reread_done
	fmovd	%f48, %f48				! reread %f48
	ba,a	.fp_reread_done
	fmovd	%f48, %f48				! reread %f48
	ba,a	.fp_reread_done
	fmovd	%f50, %f50				! reread %f50
	ba,a	.fp_reread_done
	fmovd	%f50, %f50				! reread %f50
	ba,a	.fp_reread_done
	fmovd	%f52, %f52				! reread %f52
	ba,a	.fp_reread_done
	fmovd	%f52, %f52				! reread %f52
	ba,a	.fp_reread_done
	fmovd	%f54, %f54				! reread %f54
	ba,a	.fp_reread_done
	fmovd	%f54, %f54				! reread %f54
	ba,a	.fp_reread_done
	fmovd	%f56, %f56				! reread %f56
	ba,a	.fp_reread_done
	fmovd	%f56, %f56				! reread %f56
	ba,a	.fp_reread_done
	fmovd	%f58, %f58				! reread %f58
	ba,a	.fp_reread_done
	fmovd	%f58, %f58				! reread %f58
	ba,a	.fp_reread_done
	fmovd	%f60, %f60				! reread %f60
	ba,a	.fp_reread_done
	fmovd	%f60, %f60				! reread %f60
	ba,a	.fp_reread_done
	fmovd	%f62, %f62				! reread %f62
	ba,a	.fp_reread_done
	fmovd	%f62, %f62				! reread %f62
	ba,a	.fp_reread_done
1:
	! %g2 has freg number, %g3 has base address-4
	sllx	%g2, 3, %g2			! offset = freg# * 8
	add	%g3, %g2, %g3			! %g3 = instruction block addr

	ldxa	[%g0]ASI_SPARC_ERR_EN, %g2	! save current in %g2
	andn	%g2, CEEN, %g4			! disable CEEN
	stxa	%g4, [%g0] ASI_SPARC_ERR_EN	!    ..

	jmp	%g3 + SZ_INSTR  		! jmp to reread register
	nop

.fp_reread_done:
	stxa	%g2, [%g0] ASI_SPARC_ERR_EN	! restore CEEN
	HVRET					! return to caller
	SET_SIZE(frf_reread)


	/*
	 * clear_fregerr(sparc_ear) [LEAF Function]
	 *
	 * Clear cpu.fregerr if the FRU register in error == cpu.fregerr
	 * Return 0 if cpu.fregerr matches, and 1 if no match
	 * Arguments:
	 *	%g1 - SPARC EAR
	 *	%g2 - output - 0 if cpu.fregerr matches, 1 if no match
	 *	%g3, %g4 - scratch
	 *	%g5 - erpt pointer
	 *	%g6 - cpu pointer
	 *	%g7 - return address
	 */
	ENTRY_NP(clear_fregerr)
	ldx	[%g6 + CPU_REGERR], %g3		! %g3 = cpu.fregerr

	! get register number from EAR
	xor	%g3, %g1, %g3			! Are they the same?
	andcc	%g3, SPARC_EAR_FPREG_MASK, %g3	! (ignore non-register bits)
	bz	%xcc, .freg_match		! yes, then clear
	nop
	mov	1, %g2				! return 1 for no match
	HVRET

	! %g4 has cpu.fregerr address
	! FRU was taken from FRC trap handler reread attempt
.freg_match:
	stx	%g0, [%g6 + CPU_REGERR]		! clear cpu.fregerr
	mov	%g0, %g2			! return 0 for freg match
	HVRET
	SET_SIZE(clear_fregerr)


	/*
	 * clear_frf_ue(uint64_t sparc_ear)	[LEAF function]
	 *
	 * Clear the UE in the floating-point register file
	 * Arguments:
	 *	%g1 - SPARC EAR
	 *	%g2 - %g4 - scratch
	 *	%g5, %g6 - preserverd
	 *	%g7 - return address
	 */
	ENTRY_NP(clear_frf_ue)
	and	%g1, SPARC_EAR_FPREG_MASK, %g2
	srlx	%g2, SPARC_EAR_FPREG_SHIFT, %g2	! %g2 has 6-bit fpreg number

	! Now clear the register in error
	ba	1f
	rd	%pc, %g3			! %g3 = base address

	! an array of instruction blocks indexed by register number to
	! clear the floating-point register reported in error
	! The first 32 entries use single-precision register
	! The next 32 entries clear the double-precision register
	fzeros	%f0				! clear %f0
	ba,a	.fp_clear_done
	fzeros	%f1				! clear %f1
	ba,a	.fp_clear_done
	fzeros	%f2				! clear %f2
	ba,a	.fp_clear_done
	fzeros	%f3				! clear %f3
	ba,a	.fp_clear_done
	fzeros	%f4				! clear %f4
	ba,a	.fp_clear_done
	fzeros	%f5				! clear %f5
	ba,a	.fp_clear_done
	fzeros	%f6				! clear %f6
	ba,a	.fp_clear_done
	fzeros	%f7				! clear %f7
	ba,a	.fp_clear_done
	fzeros	%f8				! clear %f8
	ba,a	.fp_clear_done
	fzeros	%f9				! clear %f9
	ba,a	.fp_clear_done
	fzeros	%f10				! clear %f10
	ba,a	.fp_clear_done
	fzeros	%f11				! clear %f11
	ba,a	.fp_clear_done
	fzeros	%f12				! clear %f12
	ba,a	.fp_clear_done
	fzeros	%f13				! clear %f13
	ba,a	.fp_clear_done
	fzeros	%f14				! clear %f14
	ba,a	.fp_clear_done
	fzeros	%f15				! clear %f15
	ba,a	.fp_clear_done
	fzeros	%f16				! clear %f16
	ba,a	.fp_clear_done
	fzeros	%f17				! clear %f17
	ba,a	.fp_clear_done
	fzeros	%f18				! clear %f18
	ba,a	.fp_clear_done
	fzeros	%f19				! clear %f19
	ba,a	.fp_clear_done
	fzeros	%f20				! clear %f20
	ba,a	.fp_clear_done
	fzeros	%f21				! clear %f21
	ba,a	.fp_clear_done
	fzeros	%f22				! clear %f22
	ba,a	.fp_clear_done
	fzeros	%f23				! clear %f23
	ba,a	.fp_clear_done
	fzeros	%f24				! clear %f24
	ba,a	.fp_clear_done
	fzeros	%f25				! clear %f25
	ba,a	.fp_clear_done
	fzeros	%f26				! clear %f26
	ba,a	.fp_clear_done
	fzeros	%f27				! clear %f27
	ba,a	.fp_clear_done
	fzeros	%f28				! clear %f28
	ba,a	.fp_clear_done
	fzeros	%f29				! clear %f29
	ba,a	.fp_clear_done
	fzeros	%f30				! clear %f30
	ba,a	.fp_clear_done
	fzeros	%f31				! clear %f31
	ba,a	.fp_clear_done
	! double precision register pairs, clear both of them on errors
	fzero	%f32				! clear %f32
	ba,a	.fp_clear_done
	fzero	%f32				! clear %f32
	ba,a	.fp_clear_done
	fzero	%f34				! clear %f34
	ba,a	.fp_clear_done
	fzero	%f34				! clear %f34
	ba,a	.fp_clear_done
	fzero	%f36				! clear %f36
	ba,a	.fp_clear_done
	fzero	%f36				! clear %f36
	ba,a	.fp_clear_done
	fzero	%f38				! clear %f38
	ba,a	.fp_clear_done
	fzero	%f38				! clear %f38
	ba,a	.fp_clear_done
	fzero	%f40				! clear %f40
	ba,a	.fp_clear_done
	fzero	%f40				! clear %f40
	ba,a	.fp_clear_done
	fzero	%f42				! clear %f42
	ba,a	.fp_clear_done
	fzero	%f42				! clear %f42
	ba,a	.fp_clear_done
	fzero	%f44				! clear %f44
	ba,a	.fp_clear_done
	fzero	%f44				! clear %f44
	ba,a	.fp_clear_done
	fzero	%f46				! clear %f46
	ba,a	.fp_clear_done
	fzero	%f46				! clear %f46
	ba,a	.fp_clear_done
	fzero	%f48				! clear %f48
	ba,a	.fp_clear_done
	fzero	%f48				! clear %f48
	ba,a	.fp_clear_done
	fzero	%f50				! clear %f50
	ba,a	.fp_clear_done
	fzero	%f50				! clear %f50
	ba,a	.fp_clear_done
	fzero	%f52				! clear %f52
	ba,a	.fp_clear_done
	fzero	%f52				! clear %f52
	ba,a	.fp_clear_done
	fzero	%f54				! clear %f54
	ba,a	.fp_clear_done
	fzero	%f54				! clear %f54
	ba,a	.fp_clear_done
	fzero	%f56				! clear %f56
	ba,a	.fp_clear_done
	fzero	%f56				! clear %f56
	ba,a	.fp_clear_done
	fzero	%f58				! clear %f58
	ba,a	.fp_clear_done
	fzero	%f58				! clear %f58
	ba,a	.fp_clear_done
	fzero	%f60				! clear %f60
	ba,a	.fp_clear_done
	fzero	%f60				! clear %f60
	ba,a	.fp_clear_done
	fzero	%f62				! clear %f62
	ba,a	.fp_clear_done
	fzero	%f62				! clear %f62
	ba,a	.fp_clear_done
1:
	! %g2 has freg number, %g3 has base address-4
	sllx	%g2, 3, %g2			! offset = freg# * 8
	add	%g3, %g2, %g3			! %g3 = instruction block addr
	jmp	%g3 + SZ_INSTR			! jmp to clear register
	nop

.fp_clear_done:
	HVRET					! return to caller
	SET_SIZE(clear_frf_ue)


	/*
	 * FRC Uncorrectible ECC Error
	 *
 	 * FRU Error Handler: Check for persistent error
 	 *	if (fru_check(sparc_ear) == RF_TRANSIENT) {
  	 *		q_sun4v_error_report(nrq);
 	 *		q_service_error_report(spi);
 	 *		jmp nonresumable_error trap handler;
	 *	} else {
 	 *		CPU.status = mark CPU in ERROR;
 	 *		if ((CPUnext = avail(partID)) != NULL) {
 	 *			x_call(CPUnext, I_AM_IN_ERROR);
 	 *			stop_self();
 	 *		} else {
 	 *			q_service_error_report(spi);
 	 *			stop_self(); causes watchdog reset later?
 	 *		}
 	 *	}
	 */


	/*
	 * Handler to set bit(s) in the SPARC Error Enable Register
	 *
	 * Called to get handler callback address (avoid relocation problems)
	 *
	 * Entry Data:
	 *   none
	 *
	 * Return Data:
	 *   %g2: handler address
	 *
	 * Registers modified:
	 *   %g2
	 */
	ENTRY_NP(err_set_sparc_bits)
	RETURN_HANDLER_ADDRESS(%g2)		! in %g2

	/*
	 * Callback from interrupt:
	 *
	 * This will re-enable the Sparc interrupts.
	 * Process in this order:
	 *   - clear any Sparc CE's
	 *   - clear blackout
	 *   - enable Sparc EEN
	 *
	 * Entry Data:
	 *   %g1: bit(s) to set
	 *   %g2: <scratch>
	 *
	 * Return Data:
	 *    none
	 *
	 * Registers modified:
	 *   %g1-6
	 */
.err_set_sparc_bits:		/* This is the actual function entry */
	mov	%g1, %g5			! bits
	!! %g5 = bits to set

	set	SPARC_CE_BITS, %g1
	ldxa	[%g0]ASI_SPARC_ERR_STATUS, %g3	! SPARC afsr
	btst	%g1, %g3			! is a CE pending?
	bz	.err_set_sparc_1		!   no:
	set	SPARC_ESR_PRIV, %g2
	or	%g1, %g2, %g1			!   yes: include PRIV
	and	%g3, %g1, %g3			! just the CE bits
	stxa	%g3, [%g0]ASI_SPARC_ERR_STATUS	! clear SPARC CE afsr bits
.err_set_sparc_1:
	CPU_STRUCT(%g3)
	lduw	[%g3 + CPU_ERR_FLAG], %g1	! installed flags
	bclr	ERR_FLAG_SPARC, %g1		! reset SPARC ESR
	stw	%g1, [%g3 + CPU_ERR_FLAG]	!	..

	ldxa	[%g0]ASI_SPARC_ERR_EN, %g3	! get current
	or	%g3, %g5, %g3			! set bit(s)
	stxa	%g3, [%g0]ASI_SPARC_ERR_EN	! store back


	HVRET
	SET_SIZE(err_set_sparc_bits)


	/*
	 * Handler to set bit(s) in the L2 Error Enable Register
	 *
	 * This will re-enable the L2/DRAM interrupts.
	 * Process in this order:
	 *   - clear any DRAM CE's
	 *   - clear any L2 CE's
	 *   - clear blackout
	 *   - enable L2DRAM EEN
	 *
	 * Called to get handler callback address (avoid relocation problems)
	 *
	 * Entry Data:
	 *   none
	 *
	 * Return Data:
	 *   %g2: handler address
	 *
	 * Registers modified:
	 *   %g2
	 */
	ENTRY_NP(err_set_l2_bits)
	RETURN_HANDLER_ADDRESS(%g2)		! in %g2

	/*
	 * Callback from interrupt:
	 *
	 * Entry Data:
	 *   %g1: bit(s) to set
	 *   %g2: B:5-0 = bank #
	 *
	 * Return Data:
	 *    none
	 *
	 * Registers modified:
	 *   %g1-6
	 */
.err_set_l2_bits:		/* This is the actual function entry */
	mov	%g1, %g5			! bits
	and	%g2, NO_L2_BANKS - 1, %g6	! bank #
	!! %g5 = bits to set
	!! %g6 = bank#
	setx	DRAM_ESR_CE_BITS | DRAM_ESR_MEC, %g1, %g2
	setx	DRAM_ESR_BASE, %g1, %g3		! DRAM base
	sllx	%g6, DRAM_BANK_SHIFT, %g4	!  + bank offset
	ldx	[%g3 + %g4], %g1		! get ESR[bank]
	and	%g1, %g2, %g1			! reset CE bits only
	stx	%g1, [%g3 + %g4]

	setx	L2_ESR_CE_BITS | L2_ESR_VEC, %g1, %g2
	setx	L2_ESR_BASE, %g1, %g3		! L2 base
	sll	%g6, L2_BANK_SHIFT, %g4		!  + bank offset
	ldx	[%g3 + %g4], %g1		! get ESR[bank]
	and	%g1, %g2, %g1			! reset CE bits only
	stx	%g1, [%g3 + %g4]

	CPU_STRUCT(%g3)				! %g3->cpu
	mov	ERR_FLAG_L2DRAM, %g1		! L2DRAM flag
	sll	%g1, %g6, %g1			! << bank#
	lduw	[%g3 + CPU_ERR_FLAG], %g2	! installed flags
	bclr	%g1, %g2			! reset L2DRAM[bank]
	stw	%g2, [%g3 + CPU_ERR_FLAG]	!	..
	!! %g1 = bits
	!! %g6 = bank#
	BSET_L2_BANK_EEN(%g6, %g5, %g2, %g3)	! L2 Bank EEN[%g6] |= %g5

	HVRET
	SET_SIZE(err_set_l2_bits)


	/*
	 * Poll to detect errors that did not cause an interrupt for one
	 * reason or another.
	 * Most common cause: L2/DRAM error from prefetch.
	 *
	 * Called to get handler callback address (avoid relocation problems)
	 *
	 * Entry Data:
	 *   none
	 *
	 * Return Data:
	 *   %g2: handler address
	 *
	 * Registers modified:
	 *   %g2
	 */
	ENTRY_NP(err_poll_daemon)
	RETURN_HANDLER_ADDRESS(%g2)		! in %g2

	/*
	 * Callback from interrupt:
	 *
	 * Entry Data:
	 *   %g1: 0
	 *   %g2: 0
	 *   %g3: Interrupt Tick Time
	 *
	 * Return Data:
	 *    none
	 *
	 * Registers modified:
	 *   %g1-6
	 */
.err_poll_daemon:
	/*
	 * Get cpu, CE buffer in %g6-5, they are safe across calls
	 */

	CPU_STRUCT(%g6)				/* ->cpu */

	stx	%g3, [%g6 + CPU_ERR_POLL_ITT]	! save interrupt tick time
	stx	%g7, [%g6 + CPU_ERR_POLL_RET]	! save return address

	/*
	 * Look for Sparc errors: test only,
	 * the error handler will do the work
	 */
.err_poll_sparc:
	ldxa	[%g0]ASI_SPARC_ERR_STATUS, %g4	! SPARC afsr
	!
	! Check for any UE:
	!
	UE_CHECK(SPARC_UE_MEU_BITS, L2_ESR_UE_BITS, %g4, %g1, %g2, %g3)
	bz	%xcc, .err_poll_no_ue		! no
	nop
	HVCALL(ue_poll_entry)			! yes: go process

	ba,a	.err_poll_sparc			! and re-check Sparc status
.err_poll_no_ue:

	!
	! Check for any CE:
	!
	CE_CHECK(%g6, %g4, %g1, %g2, %g3)	! cpup, spesr,
	bz	%xcc, .err_poll_no_ce		! no
	nop
	HVCALL(ce_poll_entry)			! yes

	ba,a	.err_poll_sparc			! go re-check Sparc status
.err_poll_no_ce:

	/*
	 * reinstall poll handler
	 */
	ldx	[%g6 + CPU_ROOT], %g1		! ->config
	ldx	[%g1 + CONFIG_CE_POLL_TIME], %g1 ! g1 = time interval
	brz	%g1, 9f				! disabled: branch
	nop
	ldx	[%g6 + CPU_ERR_POLL_ITT], %g2	! this interrupt tick time
	add	%g1, %g2, %g1			! abs time for next poll

	HVCALL(err_poll_daemon)			! g2 = handler address
	clr	%g3				! g3 = arg 0 : n/a
	clr	%g4				! g4 = arg 1 : n/a
	HVCALL(cyclic_add_abs)	/* ( abs_tick, address, arg0, arg1 ) */
9:

	ldx	[%g6 + CPU_ERR_POLL_RET], %g7	! restore return address
	HVRET
	SET_SIZE(err_poll_daemon)

	/*
	 * Function to start error polling daemon:
	 *
	 * Entry Data:
	 *   none
	 *
	 * Return Data:
	 *   %g1: status
	 *        0 - success (started)
	 *        1 - failed (already running)
	 *        2 - failed to start
	 *
	 * Registers modified:
	 *   %g1-6
	 */
	ENTRY_NP(err_poll_daemon_start)
	CPU_STRUCT(%g6)				! ->cpu

	stx	%g7, [%g6 + CPU_ERR_POLL_RET]	! save return address

	lduw	[%g6 + CPU_ERR_FLAG], %g2
	btst	ERR_FLAG_POLLD, %g2		! handler flags
	bnz,a	%xcc, 9f			! poll deamon installed?
	  mov	1, %g1				!   yes: return "running"
	bset	ERR_FLAG_POLLD, %g2		! set it
	stw	%g2, [%g6 + CPU_ERR_FLAG]	! store

	/*
	 * Install the callback handler: just start at now + ce_poll_time
	 */
	ldx	[%g6 + CPU_ROOT], %g1		! ->config
	ldx	[%g1 + CONFIG_CE_POLL_TIME], %g1 ! g1 = cycle time in ticks
	HVCALL(err_poll_daemon)			! g2 = handler address
	clr	%g3				! g3 = arg 0 : error bits
	clr	%g4				! g3 = arg 1 :
	HVCALL(cyclic_add_rel)	/* ( del_tick, address, arg0, arg1 ) */

	ldx	[%g6 + CPU_ERR_POLL_RET], %g7	! restore return address
	clr	%g1				! status = success
9:
	HVRET					! %g1 = status
	SET_SIZE(err_poll_daemon_start)


#if EVBSC_L2_AFSR_INCR == 8
#define	EVBSC_L2_AFSR_SHIFT 3
#else
#error	"EVBSC_L2_AFSR_INCR is not 8"
#endif
#if EVBSC_L2_AFAR_INCR == 8
#define	EVBSC_L2_AFAR_SHIFT 3
#else
#error	"EVBSC_L2_AFAR_INCR is not 8"
#endif
	/*
	 * This function determines if an error is transient, sticky or
	 * permanent.  We only check disposition on Memory CE's. Hence,
	 * we only work the L2 error registers.
	 * The algorithm to classify the error is as follows:
	 *      1) Displacement flush the E$ line corresponding to %addr.
	 *         The first ldxa guarantees that the %addr is no longer in
	 *         M, O, or E (goes to I or S (if instruction fetch also
	 *	   happens).
	 *      2) "Write" the data using a ldx %addrm %scr CAS %addr,%scr,%scr.
	 *         The casxa guarantees a transition from I to M or S to M.
	 *	   There are two possibilities that the sequence does not act
	 *	   as intended:
	 *	   - the line is displaced between the ld and the cas:
	 *	     we still have the correct value in %scr and the cas will
	 *	     reload the line - this is OK since the ld was to get the
	 *	     value, no to get the line in the cache.
	 *	   - the line is written between the ld and the cas:
	 *	     the intent to modify the line has effectively succeeded
	 *      3) Displacement flush the E$ line corresponding to %addr.
	 *         The second ldxa pushes the M line out of the ecache,
	 *         into the writeback buffers, on the way to memory.
	 *      4) The "membar #Sync" pushes the cache line out of
	 *         the writeback buffers onto the bus, on the way to
	 *         dram finally.
	 * %g1 - bank number
	 *
	 * XXX - Need to handle race with HW scrubber
	 */
	ENTRY_NP(err_determine_disposition)
	CPU_PUSH(%g7, %g4, %g5, %g6)		! save return address

	! Read and save the current enable
	mov	%g1, %g6			! bank #
	GET_L2_BANK_EEN(%g6, %g5, %g4)
	CPU_PUSH(%g5, %g3, %g4, %g2)		! save for later

	! disable CEEN
	BCLR_L2_BANK_EEN(%g6, CEEN, %g4, %g3)

	! get err address into %g1
	CPU_STRUCT(%g1)
	add	%g1, CPU_CE_RPT + CPU_VBSC_ERPT, %g1
	sllx	%g6, EVBSC_L2_AFAR_SHIFT, %g4
	add	%g4, EVBSC_L2_AFAR, %g2
	ldx	[%g1 + %g2], %g1
	! Mask AFAR to get only valid bits
	and	%g1, ~L2_EAR_DRAM_MASK, %g1

	! l2_flush_line garbles %g6. Save %g6 which
	! contains the BNUM
	CPU_PUSH(%g6, %g3, %g4, %g2)		! save for later

	/*
	 * displace and cause a write back
	 * Niagara works differently than previous generations.
	 * On previous generations, a cas will mark the line dirty,
	 * regardless of the success of the compare.
	 * In Niagara, the line only gets mark dirty if the swap occurs.
	 * Hence, we need to first load the value and store it back via the cas
	 */
	HVCALL(l2_flush_line)
	ldx	[%g1], %g6
	casx	[%g1], %g6, %g6
	HVCALL(l2_flush_line)

	! push cache line out of the write back buffers
	membar	#Sync

	CPU_POP(%g6, %g2, %g3, %g4)

	/*
	 * Read the errs registers again and compare them with our saved
	 * version. If they are the same, then error is persistent
	 */

	! read err regs
	setx	L2_ESR_DRAM_CE_BITS, %g3, %g2
	setx	L2_ESR_BASE, %g3, %g5		! L2 base
	sll	%g6, L2_BANK_SHIFT, %g4		!  + bank offset
	ldx	[%g5 + %g4], %g5		! get ESR[bank]
	and	%g5, %g2, %g5			! compare only CEs

	! get our copy
	CPU_STRUCT(%g3)
	add	%g3, CPU_CE_RPT + CPU_VBSC_ERPT, %g3
	sllx	%g6, EVBSC_L2_AFSR_SHIFT, %g4
	add	%g4, EVBSC_L2_AFSR, %g4
	ldx	[%g3 + %g4], %g4		! orig AFSR
	and	%g4, %g2, %g4			! only CEs

	! clear the disposition to have none
	mov	CE_XDIAG_NONE, %g2
	stx	%g2, [%g3 + EVBSC_DIAG_BUF + DRAM_DISPOSITION]

	! compare with stored
	cmp	%g4, %g5
	bne,pt	%xcc, 2f
	nop

	! now check afar and see if same.
	! %g1 still contains the stored afar

	setx	L2_EAR_BASE, %g4, %g5		! L2 base
	sll	%g6, L2_BANK_SHIFT, %g4		!  + bank offset
	ldx	[%g5 + %g4], %g4
	! mask only valid bits
	and	%g4, ~L2_EAR_DRAM_MASK, %g4

	cmp	%g1, %g4
	bne,pt	%xcc, 2f
	mov	CE_XDIAG_CE1, %g4

	! set ce1 if match
	stx	%g4, [%g3 + EVBSC_DIAG_BUF + DRAM_DISPOSITION]

	! clear the error reg
	sllx	%g6, EVBSC_L2_AFSR_SHIFT, %g4
	add	%g4, EVBSC_L2_AFSR, %g4
	ldx	[%g3 + %g4], %g4		! orig AFSR

	setx	L2_ESR_BASE, %g2, %g5		! L2 base
	sll	%g6, L2_BANK_SHIFT, %g2		!  + bank offset
	stx	%g4, [%g5 + %g2]		! clear ESR[bank]

	/*
	 * Read data again. data should now come from memory. We check
	 * for errors.  If the saved version and new errs registers are the
	 * same then it is a stuck bit
	 * %g1 still contains our stored afar
	 */
2:
	ldx	[%g1], %g2

	! read regs
	setx	L2_ESR_DRAM_CE_BITS, %g5, %g2
	setx	L2_ESR_BASE, %g4, %g5		! L2 base
	sll	%g6, L2_BANK_SHIFT, %g4		!  + bank offset
	ldx	[%g5 + %g4], %g5		! get ESR[bank]
	and	%g5, %g2, %g5			! compare only CEs

	! stored value
	sllx	%g6, EVBSC_L2_AFSR_SHIFT, %g4
	add	%g4, EVBSC_L2_AFSR, %g4
	ldx	[%g3 + %g4], %g4		! orig AFSR
	and	%g4, %g2, %g4			! only CEs

	! compare with stored
	cmp	%g4, %g5
	bne,pt	%xcc, 1f
	nop

	! now check afar and see if same.
	! %g1 still contains the stored afar

	setx	L2_EAR_BASE, %g4, %g5		! L2 base
	sll	%g6, L2_BANK_SHIFT, %g4		!  + bank offset
	ldx	[%g5 + %g4], %g4
	! mask only valid bits
	and	%g4, ~L2_EAR_DRAM_MASK, %g4

	cmp	%g1, %g4
	bne,pt	%xcc, 1f
	mov	CE_XDIAG_CE2, %g5

	! set ce2 if match
	ldx	[%g3 + EVBSC_DIAG_BUF + DRAM_DISPOSITION], %g2
	or	%g5, %g2, %g2
	stx	%g2, [%g3 + EVBSC_DIAG_BUF + DRAM_DISPOSITION]

1:
	! restore orig ce
	CPU_POP(%g5, %g2, %g3, %g4)
	SET_L2_EEN_BASE(%g2)
	sllx	%g6, L2_BANK_SHIFT, %g3		! bank offset
	add	%g2, %g3, %g2			! bank address
	stx	%g5, [%g2]			! restore value

	CPU_POP(%g7, %g1, %g2, %g3)
	HVRET

	SET_SIZE(err_determine_disposition)


/*
 * remap_perm_addr
 * %g1 = I/D remap
 * all registers get garbled
 *
 * The cores should be idled at this point.  We can't grab the
 * spin lock to prevent any deadlocks.
 * We could hit the following scenarios due to not grabing the lock:
 *    - If the TTE was zerod by a perm-unmap then we wouldn't see it and the
 *      strand would demap when it was resumed.
 *    - If we saw bits in the table before they were put into hardware then
 *      we'd end up doing it twice.
 *    - We might not see a new entry due to the TTE being good but the cpuset
 *      not being updated; the strand when resumed would load it into the tlb
 */
	ENTRY_NP(remap_perm_addr)
	CPU_PUSH(%g7, %g3, %g4, %g2)		! save return addr
	GUEST_STRUCT(%g7)
	!! %g7 guestp

	mov	%g1, %g2

	/*
	 * Search for valid perm mappings
	 */
	add	%g7, GUEST_PERM_MAPPINGS, %g1
	mov	((NPERMMAPPINGS - 1) * MAPPING_SIZE), %g3
	add	%g1, %g3, %g4
.remap_perm_loop:
	!! %g1 = base of mapping table
	!! %g3 = current offset into table
	!! %g4 = current entry in table
	!! %g7 = guestp
	ldx	[%g4 + MAPPING_TTE], %g5
	brgez,pn %g5, .remap_perm_continue
	nop

	/* Found a valid mapping */
	/* see if this map belongs to this core */
	cmp	%g2, MAP_DTLB
	move	%xcc, MAPPING_DCPUSET, %g7
	movne	%xcc, MAPPING_ICPUSET, %g7
	lduw	[%g4 + %g7], %g7
	CPU_STRUCT(%g6)
	ldub	[%g6 + CPU_PID], %g6
	PCPUID2COREID(%g6, %g6)
	sllx	%g6, CPUID_2_COREID_SHIFT, %g6	! %g6 * NSTRANDSPERCORE
	srlx	%g7, %g6, %g7
	btst	CORE_MASK, %g7
	bz,pt %xcc, .remap_perm_continue
	nop

#ifdef NIAGARA_ERRATUM_40
	/*
	 * Use entry # in guest's permanent mapping table as position
	 * in tlb, guarantees idx 63 not used (Niagara erratum 40).
	 * We divide the tlb into 8 sets of 8 permanent mappings.
	 * The guest's partid selects the set of 8.
	 *
	 * NB: partid 7 is not supported.
	 */
	GUEST_STRUCT(%g6)
	ldx	[%g6 + GUEST_PARTID], %g1
	inc	GUEST_PERM_MAPPINGS_LOCK, %g6
	sub	%g4, %g6, %g6
	udivx	%g6, MAPPING_SIZE, %g6
	!! %g6 = tlb index #

	sllx	%g1, 3, %g1	! partid * NPERMMAPPINGS
	add	%g6, %g1, %g6	! tlbindex# + (partid * 8)

	sllx	%g6, 3, %g6
	!! %g6 = ASI_TLB_ACCESS va
#endif
	/*
	 * Map in TLB
	 */
	btst	MAP_ITLB, %g2
	bz,pn	%xcc, 1f
	btst	MAP_DTLB, %g2

	/* Set tag */
	ldx	[%g4 + MAPPING_VA], %g5
	mov	MMU_TAG_ACCESS, %g1
	stxa	%g5, [%g1]ASI_IMMU
	membar	#Sync

	ldx	[%g4 + MAPPING_TTE], %g1

	mov	1, %g5
	sllx	%g5, NI_TTE4V_L_SHIFT, %g5
	or	%g1, %g5, %g1	! add lock bit
	set	TLB_IN_4V_FORMAT, %g5

#ifdef NIAGARA_ERRATUM_40
	!! %g6 still contains ASI_TLB_ACCESS va
	stxa	%g1, [%g5 + %g6]ASI_ITLB_DATA_ACC
#else
	stxa	%g1, [%g5]ASI_ITLB_DATA_IN
#endif
	membar	#Sync

	! condition codes still set
1:	bz,pn	%xcc, 2f
	nop

	/* Set Tag */
	ldx	[%g4 + MAPPING_VA], %g5
	mov	MMU_TAG_ACCESS, %g1
	stxa	%g5, [%g1]ASI_DMMU
	membar	#Sync

	ldx	[%g4 + MAPPING_TTE], %g1
	mov	1, %g5
	sllx	%g5, NI_TTE4V_L_SHIFT, %g5
	or	%g1, %g5, %g1	! add lock bit
	set	TLB_IN_4V_FORMAT, %g5
#ifdef NIAGARA_ERRATUM_40
	!! %g6 still contains ASI_TLB_ACCESS va
	stxa	%g1, [%g5 + %g6]ASI_DTLB_DATA_ACC
#else
	stxa	%g1, [%g5]ASI_DTLB_DATA_IN
#endif
	membar	#Sync
2:

.remap_perm_continue:
	GUEST_STRUCT(%g7)
	add	%g7, GUEST_PERM_MAPPINGS, %g1
	deccc	GUEST_PERM_MAPPINGS_INCR, %g3
	bgeu,pt	%xcc, .remap_perm_loop
	add	%g1, %g3, %g4

	CPU_POP(%g7, %g1, %g2, %g5)
	HVRET
	SET_SIZE(remap_perm_addr)

	/*
	 * Handle cpu in error
	 * All other strands are idle
	 * This CPU:
	 *   - search for another "good" cpu
	 *   - flag as halted (bit mask)
	 *   - Remove cyclic (Error Daemon)
	 *   - handoff interrupt steering
	 *   - Migrate all intrs
	 *   - notify good cpu to finish rest of work 
	 *   - put myself into idle
	 * Selected Good CPU:
	 *   - send resumable error to guest
	 * %g6 should not be clobbered
	 */
	ENTRY_NP(cpu_in_error)

	! Remove this cpu from the active bitmask and add it to halted 
	CPU_STRUCT(%g1)
	ldub	[%g1 + CPU_PID], %g5
	mov	1, %g4
	sllx	%g4, %g5, %g4
    
	!! %g1 - cpup
	CPU2ROOT_STRUCT(%g1, %g2)		! config ptr
	! clear this cpu from the active list
	ldx	[%g2 + CONFIG_STACTIVE], %g3
	bclr	%g4, %g3
	stx	%g3, [%g2 + CONFIG_STACTIVE]

	! set this cpu in the halted list
	ldx	[%g2 + CONFIG_STHALT], %g3
	bset	%g4, %g3
	stx	%g3, [%g2 + CONFIG_STHALT]

	! pick another cpu from the idle list
	mov	(NCPUS - 1), %g6
.find_cpu_loop:
	!! %g6 - current tgt cpu id
	!! %g5 - this cpu id
	! skip current cpu (don't want to pick myself)
	cmp	%g6, %g5
	be,pt	%xcc, .find_cpu_continue
	nop

	/*
	 * At this point all "good" strands should be idle
	 * A candidate cpu should meet the following requirements:
	 * - idled
	 * - running guest code
	 * - have error buffers configured
	 * If after checking all cpus non meet this criteria, we abort
	 */ 
	IS_STRAND_IDLE(%g1, %g6, %g4, %g3)
	bz,pt	%xcc, .find_cpu_continue
	nop
	
	! make sure the cpu is in guest code
	PID2CPUP(%g6, %g4, %g3)
	mov	CPU_STATE_RUNNING, %g3
	ldx	[%g4 + CPU_STATUS], %g1
	cmp	%g3, %g1
	bne,pt	%xcc, .find_cpu_continue
	nop

	! check the error queues.. if not set, not a good candidate
	ldx	[%g4 + CPU_ERRQR_BASE], %g3
	brz,pt	%g3, .find_cpu_continue
	nop

	ba,a	.found_a_cpu

.find_cpu_continue:
	deccc	%g6
	bge,pt	 %xcc, .find_cpu_loop 
	nop
	
	! If we got here, we didn't find a good tgt cpu
	brlz,a,pn %g6, hvabort
	  mov	ABORT_NOTGTCPUS, %g1

.found_a_cpu:
	/*
	 * handoff L2 Steering CPU
	 * If we are the steering cpu, migrate it to our chosen one
	 */
	setx	L2_CONTROL_REG, %g3, %g4
	ldx	[%g4], %g2			! current setting
	srlx	%g2, L2_ERRORSTEER_SHIFT, %g3
	and	%g3, (NCPUS -1), %g3
	cmp	%g3, %g5			! is this steering cpu?
	bnz,pt	%xcc, 1f
	nop

	! It is the L2 Steering cpu. Migrate responsibility to tgt cpu
	sllx	%g3, L2_ERRORSTEER_SHIFT, %g3
	andn	%g3, %g2, %g2			! remove this cpu
	sllx	%g6, L2_ERRORSTEER_SHIFT, %g3
	or	%g2, %g3, %g2
	stx	%g2, [%g4]

1:
	/*
	 * Migrate SSI intrs
	 */
	mov	%g5, %g1
	mov	%g6, %g2
	CPU_PUSH(%g1, %g3, %g4, %g5)
	CPU_PUSH(%g2, %g3, %g4, %g5)
	HVCALL(ssi_intr_redistribution)
	CPU_POP(%g2, %g3, %g4, %g5)
	CPU_POP(%g1, %g3, %g4, %g5)

#if 0 /* XXX */
	/*
	 * XXX err_poll_daemon (collapse into heartbeat?)
	 */
#endif

	/*
	 * Disable heartbeat interrupts if they're on this cpu.
	 * cpu_in_error_finish will invoke heartbeat_enable on the
	 * remote cpu if the heartbeat was disabled.
	 */
	CPU_PUSH(%g1, %g3, %g4, %g5)
	CPU_PUSH(%g2, %g3, %g4, %g5)
	HVCALL(heartbeat_disable)
	CPU_POP(%g2, %g3, %g4, %g5)
	CPU_POP(%g1, %g3, %g4, %g5)

#ifdef CONFIG_FIRE
	/*
	 * Migrate fire intrs
	 */
	CPU_PUSH(%g1, %g3, %g4, %g5)
	CPU_PUSH(%g2, %g3, %g4, %g5)
	HVCALL(fire_intr_redistribution)
	CPU_POP(%g2, %g3, %g4, %g5)
	CPU_POP(%g1, %g3, %g4, %g5)

	/*
	 * Migrate fire err intrs
	 */
	CPU_PUSH(%g1, %g3, %g4, %g5)
	CPU_PUSH(%g2, %g3, %g4, %g5)
	HVCALL(fire_err_intr_redistribution)
	CPU_POP(%g2, %g3, %g4, %g5)
	CPU_POP(%g1, %g3, %g4, %g5)
#endif

	/*
	 * Migrate vdev intrs
	 */
	CPU_PUSH(%g1, %g3, %g4, %g5)
	CPU_PUSH(%g2, %g3, %g4, %g5)
	HVCALL(vdev_intr_redistribution)
	CPU_POP(%g2, %g3, %g4, %g5)
	CPU_POP(%g1, %g3, %g4, %g5)

	!! %g1 this cpu id
	!! %g2 tgt cpu id
	mov	%g1, %g5
	mov	%g2, %g6

	/*
	 * This cpu has most of the information to send to the Guest.
	 * We copy from this cpu err rpt to the tgt's err rpt
	 */
	! get this cpu erpt
	CPU_STRUCT(%g1)
	CPU_ERPT_STRUCT(CPU_UE_RPT, %g1, %g1)

	! get tgt cpu erpt
	PID2CPUP(%g6, %g2, %g3)
	CPU2ERPT_STRUCT(CPU_CE_RPT, %g2, %g3)
	
	! copy info to tgt cpu ce err buf
	ldx	[%g1 + CPU_SUN4V_ERPT + ESUN4V_G_EHDL], %g4	! ehdl
	stx	%g4, [%g3 + CPU_SUN4V_ERPT + ESUN4V_G_EHDL]
	ldx	[%g1 + CPU_SUN4V_ERPT + ESUN4V_G_STICK], %g4	! stick
	stx	%g4, [%g3 + CPU_SUN4V_ERPT + ESUN4V_G_STICK]
	ld	[%g1 + CPU_SUN4V_ERPT + ESUN4V_EDESC], %g4	! edesc
	st	%g4, [%g3 + CPU_SUN4V_ERPT + ESUN4V_EDESC]
	ld	[%g1 + CPU_SUN4V_ERPT + ESUN4V_ATTR], %g4	! attr
	st	%g4, [%g3 + CPU_SUN4V_ERPT + ESUN4V_ATTR]
	ldx	[%g1 + CPU_SUN4V_ERPT + ESUN4V_RA], %g4		! ra
	stx	%g4, [%g3 + CPU_SUN4V_ERPT + ESUN4V_RA]
	ld	[%g1 + CPU_SUN4V_ERPT + ESUN4V_SZ], %g4		! sz
	st	%g4, [%g3 + CPU_SUN4V_ERPT + ESUN4V_SZ]
	lduh	[%g1 + CPU_SUN4V_ERPT + ESUN4V_G_CPUID], %g4	! cpuid
	stuh	%g4, [%g3 + CPU_SUN4V_ERPT + ESUN4V_G_CPUID]
	lduh	[%g1 + CPU_SUN4V_ERPT + ESUN4V_G_SECS], %g4
	stuh	%g4, [%g3 + CPU_SUN4V_ERPT + ESUN4V_G_SECS]

	/*
	 * Send a xcall to the target cpu so it can finish the work
	 */
	sllx	%g6, INT_VEC_DIS_VCID_SHIFT, %g5
	or	%g5, VECINTR_CPUINERR, %g5
	stxa	%g5, [%g0]ASI_INTR_UDB_W

	CPU_STRUCT(%g6)
	SPINLOCK_RESUME_ALL_STRAND(%g6, %g1, %g2, %g3, %g4)

	! idle myself
	CPU_STRUCT(%g1)
	ldub	[%g1 + CPU_PID], %g6
	INT_VEC_DSPCH_ONE(INT_VEC_DIS_TYPE_IDLE, %g6, %g3, %g4)

	/*
	 * Paranoia!! If we get here someone else resumed this strand
	 * by mistake
	 * hvabort to catch the mistake
	 */
	ba	hvabort
	mov	ABORT_INTERNAL_CORRUPT, %g1

	SET_SIZE(cpu_in_error)
