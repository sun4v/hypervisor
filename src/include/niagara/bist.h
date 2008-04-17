/*
 * Copyright 2004 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#pragma ident   "@(#)bist.h 1.1     04/08/02 SMI"

/*
 * BIST controls
 */

#define BIST_CTL_BISI_MODE  	(1 << 6)  
#define BIST_DONE	    	(1 << 10)
#define BIST_START 	   	1

#define BISI_START		(BIST_CTL_BISI_MODE + BIST_START)

#define L2_BIST_CTL		(0xa8 << 32)	
