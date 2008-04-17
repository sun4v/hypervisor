/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _MMUSTAT_H
#define	_MMUSTAT_H

#pragma ident	"@(#)mmustat.h	1.3	05/08/23 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*

 MMU statistic buffer format

  offset (bytes)        size (bytes)    field
  --------------        ------------    -----
  0x0                   0x8             IMMU TSB hits ctx0, 8kb TTE
  0x8                   0x8             IMMU TSB %tick's ctx0, 8kb TTE
  0x10                  0x8             IMMU TSB hits ctx0, 64kb TTE
  0x18                  0x8             IMMU TSB %tick's ctx0, 64kb TTE
  0x20                  0x10            reserved
  0x30                  0x8             IMMU TSB hits ctx0, 4mb TTE
  0x38                  0x8             IMMU TSB %tick's ctx0, 4mb TTE
  0x40                  0x10            reserved
  0x50                  0x8             IMMU TSB hits ctx0, 256mb TTE
  0x58                  0x8             IMMU TSB %tick's ctx0, 256mb TTE
  0x60                  0x20            reserved
  0x80                  0x8             IMMU TSB hits ctxnon0, 8kb TTE
  0x88                  0x8             IMMU TSB %tick's ctxnon0, 8kb TTE
  0x90                  0x8             IMMU TSB hits ctxnon0, 64kb TTE
  0x98                  0x8             IMMU TSB %tick's ctxnon0, 64kb TTE
  0xA0                  0x10            reserved
  0xB0                  0x8             IMMU TSB hits ctxnon0, 4mb TTE
  0xB8                  0x8             IMMU TSB %tick's ctxnon0, 4mb TTE
  0xC0                  0x10            reserved
  0xD0                  0x8             IMMU TSB hits ctxnon0, 256mb TTE
  0xD8                  0x8             IMMU TSB %tick's ctxnon0, 256mb TTE
  0xE0                  0x20            reserved
  0x100                 0x8             DMMU TSB hit ctx0, 8kb TTE
  0x108                 0x8             DMMU TSB %tick's ctx0, 8kb TTE
  0x110                 0x8             DMMU TSB hit ctx0, 64kb TTE
  0x118                 0x8             DMMU TSB %tick's ctx0, 64kb TTE
  0x120                 0x10            reserved
  0x130                 0x8             DMMU TSB hit ctx0, 4mb TTE
  0x138                 0x8             DMMU TSB %tick's ctx0, 4mb TTE
  0x140                 0x10            reserved
  0x150                 0x8             DMMU TSB hit ctx0, 256mb TTE
  0x158                 0x8             DMMU TSB %tick's ctx0, 256mb TTE
  0x160                 0x20            reserved
  0x180                 0x8             DMMU TSB hit ctxnon0, 8kb TTE
  0x188                 0x8             DMMU TSB %tick's ctxnon0, 8kb TTE
  0x190                 0x8             DMMU TSB hit ctxnon0, 64kb TTE
  0x198                 0x8             DMMU TSB %tick's ctxnon0, 64kb TTE
  0x1A0                 0x10            reserved
  0x1B0                 0x8             DMMU TSB hit ctxnon0, 4mb TTE
  0x1B8                 0x8             DMMU TSB %tick's ctxnon0, 4mb TTE
  0x1C0                 0x10            reserved
  0x1D0                 0x8             DMMU TSB hit ctxnon0, 256mb TTE
  0x1D8                 0x8             DMMU TSB %tick's ctxnon0, 256mb TTE
  0x1E0                 0x20            reserved

 */
#define	MMUSTAT_I			0x0
#define	MMUSTAT_D			0x100

#define	MMUSTAT_CTX0			0x0
#define	MMUSTAT_CTXNON0			0x80

#define	MMUSTAT_HIT			0x0
#define	MMUSTAT_TICK			0x8

#define	MMUSTAT_ENTRY_SZ_SHIFT		4


#define	MMUSTAT_AREA_SIZE		0x200
#define	MMUSTAT_AREA_ALIGN		0x8


#ifdef __cplusplus
}
#endif

#endif /* _MMUSTAT_H */
