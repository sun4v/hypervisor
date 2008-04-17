/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _NIAGARA_MAU_H
#define	_NIAGARA_MAU_H

#pragma ident	"@(#)mau.h	1.1	05/04/12 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Niagara Crypto Provider hardware specific defines.
 */

#ifndef _ASM
/* Forward typedefs */
typedef union ma_ctl		ma_ctl_t;
typedef union ma_mpa		ma_mpa_t;
typedef union ma_ma		ma_ma_t;
typedef uint64_t		ma_np_t;

/*
 * Modulare Arithmetic Unit (MA) control register definition.
 */
union ma_ctl {
	uint64_t	value;
	struct {
		uint64_t	reserved1:50;
		uint64_t	invert_parity:1;
		uint64_t	thread:2;
		uint64_t	busy:1;
		uint64_t	interrupt:1;
		uint64_t	operation:3;
		uint64_t	length:6;
	} bits;
};
#endif	/* _ASM */

/* Values for ma_ctl operation field */
#define	MA_OP_LOAD		0x0
#define	MA_OP_STORE		0x1
#define	MA_OP_MULTIPLY		0x2
#define	MA_OP_REDUCE		0x3
#define	MA_OP_EXPONENTIATE	0x4

/* mask to check busy bit in ctl register */
#define	MA_CTL_BUSY_BIT_MASK	0x0000000000000400
/* defines to check operation field */
#define	MA_CTL_OP_SHIFT		6
#define	MA_CTL_OP_MASK		0x7

#define	MA_CTL_LENGTH_MASK	0x3f

#define	MA_WORDS2BYTES_SHIFT	3	/* log2(sizeof(uint64_t)) */

/* The MA memory is 1280 bytes (160 8 byte words) */
#define	MA_SIZE		1280

/* We can only load 64 8 byte words at a time */
#define	MA_LOAD_MAX	64

#ifndef _ASM
union ma_mpa {
	uint64_t	value;
	struct {
		uint64_t	reserved0:24;
		uint64_t	address:37;
		uint64_t	reserved1:3;
	} bits;
};

union ma_ma {
	uint64_t	value;
	struct {
		uint64_t	reserved0:16;
		uint64_t	address5:8;
		uint64_t	address4:8;
		uint64_t	address3:8;
		uint64_t	address2:8;
		uint64_t	address1:8;
		uint64_t	address0:8;
	} bits;
};

#endif	/* _ASM */

/*
 * MA Control Register
 *	Field	Bits	R/W
 *	-----	----	---
 *	STRAND	12:11	R/W
 *	BUSY	10	RO
 *	INTR	9	R/W
 *	OP	8:6	R/W
 */
#define	MA_CTRL_STRAND_SHIFT	11
#define	MA_CTRL_BUSY_SHIFT	10
#define	MA_CTRL_INTR_SHIFT	9
#define	MA_CTRL_OP_SHIFT	6

#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA_MAU_H */
