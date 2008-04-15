/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: abort.h
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

#ifndef _ABORT_H
#define	_ABORT_H

#pragma ident	"@(#)abort.h	1.7	05/11/25 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Hypervisor abort codes (guru codes)
 *
 * Note: Don't change exiting numbers.  Add new ones. Vbsc uses
 * these numbers to print a message
 *
 */

#define	ABORT_NOHVUART		0x01
#define	ABORT_MISSINGGUESTPROP	0x02
#define	ABORT_MISSINGCPUPID	0x03
#define	ABORT_NOGUESTS		0x04
#define	ABORT_NOCPUS		0x05
#define	ABORT_NOTOD		0x06
#define	ABORT_MISSINGSVCPROP	0x07
#define	ABORT_MISSINGDEVPROP	0x08
#define	ABORT_INVALIDGUESTID	0x09
#define	ABORT_INVALIDCPUPID	0x0a
#define	ABORT_INVALIDCPUVID	0x0b
#define	ABORT_MISSINGCPUGUESTREF 0x0c
#define	ABORT_MISSINGGUESTGID	0x0d
#define	ABORT_MISSINGDEVCFGH	0x0e
#define	ABORT_MISSINGDEVIGN	0x0f
#define	ABORT_MISSINGSVCSID	0x11
#define	ABORT_MISSINGSVCXID	0x12
#define	ABORT_MISSINGSVCFLAGS	0x13
#define	ABORT_MISSINGSVCINO	0x14
#define	ABORT_MISSINGSVCMTU	0x15
#define	ABORT_MISSINGCPUVID	0x16
#define	ABORT_BAD_HDESC_VER	0x17
#define	ABORT_BAD_PDESC_VER	0x18
#define	ABORT_VBSC_REGISTER	0x19
#define	ABORT_UNSUPPORTED_FIRE	0x1a
#define	ABORT_STACK_OVERFLOW	0x1b
#define	ABORT_STACK_UNDERFLOW	0x1c
#define	ABORT_BAD_GUEST_ERR_Q	0x1d
#define	ABORT_UE_IN_HV		0x1e
#define	ABORT_UE_IN_TLB_TAG	0x1f
#define	ABORT_INTERNAL_CORRUPT	0x20
#define	ABORT_NOTGTCPUS		0x21
#define	ABORT_JBI_ERR		0x22

#ifdef __cplusplus
}
#endif

#endif /* _ABORT_H */
