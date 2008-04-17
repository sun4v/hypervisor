#
# ident	"@(#)mapfile.q	1.6	04/07/16 SMI"
#
# Copyright 2004 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#

note = NOTE;
note : $NOTE ;
note : .comment ;
note : .stab.index ;

rom = LOAD ?RX V0xfff0000000;
rom : .text ;
rom : $PROGBITS ;
rom : $NOBITS ;
rom : .rodata  ;
rom : .data  ;
rom : .data1  ;
rom : .bss  ;

bss =;

