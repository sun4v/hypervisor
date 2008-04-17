/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _SVC_H_
#define	_SVC_H_

#pragma ident	"@(#)svc.h	1.6	05/08/14 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#ifdef CONFIG_SVC

#define	XPID_RESET	0
#define	XPID_POST	1
#define	XPID_HV		2
#define	XPID_GUESTBASE	16
#define	XPID_GUEST(n)	(XPID_GUESTBASE + (n))

#define	SID_CONSOLE	0
#define	SID_NVRAM	1
#define	SID_ERROR	2
#define	SID_VBSC_CTL	3
#define	SID_ECHO	4
#define	SID_LOOP1	5
#define	SID_LOOP2	6
#define	SID_FMA		7

/* the service config bits */
#define	SVC_CFG_RX	0x00000001 /* support RECV */
#define	SVC_CFG_RE	0x00000002 /* support RECV intr */
#define	SVC_CFG_TX	0x00000004 /* support SEND */
#define	SVC_CFG_TE	0x00000008 /* support SEND intr */
#define	SVC_CFG_GET	0x00000010 /* support GETSTATUS */
#define	SVC_CFG_SET	0x00000020 /* support SETSTATUS */
#define	SVC_CFG_LINK	0x00000100 /* cross linked svc */
#define	SVC_CFG_MAGIC	0x00000200 /* legion magic trap */
#define	SVC_CFG_CALLBACK 0x0000800 /* hypervisor callback */
#define	SVC_CFG_PRIV	0x80000000

#define	ABORT_SHIFT	11

#define	SVC_DUPLEX	(	   \
	    SVC_CFG_RX | SVC_CFG_RI | \
	    SVC_CFG_TX | SVC_CFG_TI | \
	    SVC_CFG_GET | SVC_CFG_SET)

/* the service status/flag bits */
#define	SVC_FLAGS_RI	0x00000001 /* RECV pending */
#define	SVC_FLAGS_RE	0x00000002 /* RECV intr enabled */
#define	SVC_FLAGS_TI	0x00000004 /* SEND complete */
#define	SVC_FLAGS_TE	0x00000008 /* SEND intr enabled */
#define	SVC_FLAGS_TP	0x00000010 /* TX pending (queued) */
#define	SVC_FLAG_ABORT	(1 << ABORT_SHIFT) /* ABORT XXX interrupt ? */

/* the offsets in the svc register tables */
#define	SVC_REG_XID	0x0
#define	SVC_REG_SID	0x4
#define	SVC_REG_RECV	0x8
#define	SVC_REG_SEND	0xC

#ifdef _ASM

/*
 * tname - the tables name; (symbol will be created)
 * sid	- the service id
 * recv - your recv callback function (0 is none)
 * send - your send callback function (0 is none)
 */
/* BEGIN CSTYLED */
#define	SVC_REGISTER(tname, xid, sid, recv, send)	\
	ba	svc/**/tname/**/end	;\
	  rd	%pc, %g2		;\
svc/**/tname:				;\
	.word	xid			;\
	.word	sid			;\
	.word	recv - svc/**/tname	;\
	.word	send - svc/**/tname	;\
svc/**/tname/**/end:			;\
	add	%g2, 4, %g2		;\
	ba	svc_register		;\
	rd	%pc, %g7		;\
/* END CSTYLED */

#define UNLOCK(r_base, offset)		\
	stx	%g0, [r_base + offset]

#endif /* _ASM */

#define	SVCCN_TYPE_BREAK	0x80
#define	SVCCN_TYPE_HUP		0x81
#define	SVCCN_TYPE_CHARS	0x00

#endif /* CONFIG_SVC */

#ifndef _ASM

/*
 * The svc_data blocks are back-to-back in memory (a linear array)
 * if we get to the end then this is a bad service request.
 */
struct svc_link {
	uint64_t	size;
	uint64_t	pa;
	struct svc_ctrl *next;
};

struct svc_callback {
	uint64_t	rx; 		/* called on rx intr */
	uint64_t	tx;
	uint64_t	cookie; 	/* your callback cookie */
};

struct svc_ctrl {
	uint32_t	xid;
	uint32_t	sid;
	uint32_t	ino;			/* virtual INO  */
	uint32_t	mtu;
	uint32_t	config;			/* API control bits */
	uint32_t	state;			/* device state */
	uint32_t	dcount;			/* defer count */
	uint32_t	dstate;			/* defer state 0=NACK, 1=BUSY */
	uint64_t	lock;			/* simple mutex */
	uint64_t	intr_cookie;		/* intr gen cookie */
	struct svc_callback callback; 		/* HV call backhandle */
	struct svc_ctrl *link;			/* cross link */
	struct svc_link	recv;
	struct svc_link send;
};

struct svc_pkt {
	uint32_t	xid;			/* service guest ID */
	uint16_t	sum;			/* packet checksum */
	uint16_t	sid;			/* svcid */
};

struct hv_svc_data {
	uint64_t	rxbase;			/* PA of RX buffer (SRAM) */
	uint64_t	txbase;			/* PA of TX buffer (SRAM) */
	uint64_t	rxchannel;		/* RX channel regs PA */
	uint64_t	txchannel;		/* TX channel regs PA */
	uint64_t	scr[2];			/* reg scratch */
	uint32_t	num_svcs;
	uint32_t	sendbusy;
	struct svc_ctrl *sendh;			/* intrs send from here */
	struct svc_ctrl *sendt;			/* sender adds here */
	struct svc_ctrl *senddh;		/* holding.. (nack/busy) */
	struct svc_ctrl *senddt;
	uint64_t	lock;			/* need mutex?? */
	struct svc_ctrl svcs[1];		/* the svc buffers follow */
};


/*
 * Console protocol packet definition
 */
struct svccn_packet {
	uint8_t		type;
	uint8_t		len;
	uint8_t		data[1];
};

#endif /* _ASM */

#ifdef __cplusplus
}
#endif

#endif /* _SVC_H_ */
