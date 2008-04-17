/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _NIAGARA_VPCI_ERRS_DEFS_H
#define _NIAGARA_VPCI_ERRS_DEFS_H

#pragma ident	"@(#)vpci_errs_defs.h	1.3	05/07/21 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _ASM
/*
 * Diagnostic error report structure.
 * Area containing both the sun4v error report and the diagnostic
 * error report.
 * Total size < 4096 (0x1000). So offsets into this struct can be used
 * as immediate values in assembler for reads and writes.
 * First 64 bytes is the sun4v error report sent to the affected guest.
 * The diagnostic error report starts at offset 0x40.
 */
struct pci_erpt {
	struct epkt {
		/* sun4v guest error report starts at offset 0x0 */
		uint64_t	sysino;		/* I/O error interrupt number */
		uint64_t	sun4v_ehdl;	/* guest error handle */
		uint64_t	sun4v_stick;	/* %stick to guest */
		uint32_t	sun4v_desc;	/* error decriptor */
		uint32_t	sun4v_specfic;	/* error specific */
		uint64_t	word4;
		uint64_t	HDR1;		/* pci header 1 */
		uint64_t	HDR2;		/* pci header 2 */
		uint64_t	word7;		/* filler */
	} pciepkt;
	union {
		struct	jbc_err {
			uint64_t	report_type;	/* cpu/io identifier */
			uint64_t	pciehdl; 	/* EHDL */
			uint64_t	pcistick; 	/* STICK */
			uint64_t	cpuver;		/* Proc version reg */
			uint32_t	agentid;
			uint32_t	mondo_num;
        			/* mondo 63 regs */
			uint64_t	jbc_err_log_enable;	/* 0x471000, jbc_ele */
			uint64_t	jbc_intr_enable;	/* 0x471008, jbc_ie */
			uint64_t	jbc_intr_status;	/* 0x471010, jbc_is */
			uint64_t	jbc_error_status_set_reg;	/* 0x471020, jbc_ess */
			uint64_t	jbc_core_and_block_err_status;	/* PCIERPT_JBC_CORE_AND_BLOCK_ERR_STATUS, 0x471808 */
			uint64_t	merge_trans_err_log;	/* 0x471060, jbc_mtel */
			uint64_t	jbcint_in_trans_err_log;	/* 0x471030, jbc_jitel1 */
			uint64_t	jbcint_in_trans_err_log_reg_2;	/* 0x471038, jbc_jitel2 */
			uint64_t	jbcint_out_trans_err_log;	/* 0x471040, jbc_jotel1 */
			uint64_t	jbcint_out_trans_err_log_reg_2;	/* 0x471048, jbc_jotel2 */
			uint64_t	dmcint_odcd_err_log;
			uint64_t	dmcint_idc_err_log;
			uint64_t	csr_err_log;
			uint64_t	fatal_err_log_reg_1;	/* 0x471050, jbc_fel1 */
			uint64_t	fatal_err_log_reg_2;	/* 0x471058, jbc_fel2 */
		} jbc_err;
		struct	pcie_err {
			uint64_t	report_type;	/* cpu or io identifier */
			uint64_t	pciehdl; 	/* error handle */
			uint64_t	pcistick; 	/* value of %stick */
			uint64_t	cpuver;		/* Processor version reg */
			uint32_t	agentid;
			uint32_t	mondo_num;
       	 		/* mondo 62 regs */
			uint64_t	multi_core_err_status;
			uint64_t	dmc_core_and_block_err_status;
			uint64_t	imu_err_log_enable;	/* 0x31000, imu_ele */
			uint64_t	imu_interrupt_enable;	/* 0x31008, imu_ie */
			uint64_t	imu_enabled_err_status;
			uint64_t	imu_err_status_set;	/* 0x31020, imu_ess */
			uint64_t	imu_scs_err_log;
			uint64_t	imu_eqs_err_log;
			uint64_t	imu_rds_err_log;
			uint64_t	mmu_err_log_enable;
			uint64_t	mmu_intr_enable;
			uint64_t	mmu_intr_status;
			uint64_t	mmu_err_status_set;
			uint64_t	mmu_translation_fault_address;
			uint64_t	mmu_translation_fault_status;
			uint64_t	pec_core_and_block_intr_status;
			uint64_t	ilu_err_log_enable;	/* 0x51000, ilu_ele */
			uint64_t	ilu_intr_enable;	/* 0x51008, ilu_ie */
			uint64_t	ilu_intr_status;
			uint64_t	ilu_err_status_set;	/* 0x51020, ilu_ess */
			uint64_t	tlu_ue_log_enable;
			uint64_t	tlu_ue_intr_enable;
			uint64_t	tlu_ue_status;
			uint64_t	tlu_ue_status_set;	/* 0x691020, tlu_uess */
			uint64_t	tlu_ce_log_enable;	/* 0x6a1000, tlu_cele */
			uint64_t	tlu_ce_interrupt_enable;	/* 0x6a1008, tlu_cie */
			uint64_t	tlu_ce_interrupt_status;	/* 0x6a1010, tlu_cis */
			uint64_t	tlu_ce_status;		/* 0x6a1020, tlu_cess */
			uint64_t	tlu_receive_ue_header1_log;
			uint64_t	tlu_receive_ue_header2_log;
			uint64_t	tlu_transmit_ue_header1_log;
			uint64_t	tlu_transmit_ue_header2_log;
			uint64_t	lpu_phy_layer_intr_and_status;
			uint64_t	tlu_other_event_log_enable;	/* 0x81000, tlu_oeele */
			uint64_t	tlu_other_event_intr_enable;	/* 0x81008, tlu_oeie */
			uint64_t	tlu_other_event_intr_status;	/* 0x81010, tlu_oeis */
			uint64_t	tlu_other_event_status_set;	/* 0x81020, tlu_oess */
			uint64_t	tlu_receive_other_event_header1_log;
			uint64_t	tlu_receive_other_event_header2_log;
			uint64_t	tlu_transmit_other_event_header1_log;
			uint64_t	tlu_transmit_other_event_header2_log;
			uint64_t	lpu_intr_status;	/* 0xe2040 */
			uint64_t	lpu_link_perf_counter2;	/* 0xe2130 */ 
			uint64_t	lpu_link_perf_counter1;			/* 0xe2120 */
			uint64_t	lpu_link_layer_interrupt_and_status;	/* 0xe2210 */
			uint64_t	lpu_phy_layer_interrupt_and_status;	/* 0xe2610 */
			uint64_t	lpu_ltssm_interrupt_and_status;	/* 0xe27c0 */
			uint64_t	lpu_transmit_phy_interrupt_and_status;	/* 0xe2710 */
			uint64_t	lpu_receive_phy_interrupt_ans_status;/* 0xe26a0 */
			uint64_t	lpu_gigablaze_glue_interupt_and_status;/* 0xe2828 */
		} pcie_err;
	} _u;
	int		unsent_pkt;	/* mark pkt to be sent */
};
#endif /* ASM */

#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA_VPCI_ERRS_DEFS_H */
