/*
 Copyright 1990-2006 Alexandre Lemaresquier, Raphael Lemoine
                     Laurent Chemla (Serial support), Daniel Verite (AmigaOS support)

 This file is part of Adebug.

 Adebug is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 Adebug is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Adebug; if not, write to the Free Software
 Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

*/
/*#define WDB */
/*-------------------------------*/
#if defined(ADEBUG)

/* Usual things */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <time.h>

typedef unsigned char uchar;
#ifndef __AMIGA__
typedef unsigned short ushort;
#endif
typedef unsigned long ulong;
typedef int bfint;
typedef unsigned int bfuint;

#if (!defined(__GNUC__) || defined(__atarist))
typedef unsigned short ushort;
#endif

#if defined(__GNUC__)
#define PACKED	__attribute__((packed))
#else
#define PACKED
#endif

#define EVGETMEM(dst,src,size) memcpy(dst,src,size)
#define EVPUTMEM(dst,src,size) memcpy(dst,src,size)
/* Endianness */
#define getil(l)	(l)
#define getiw(w)	(w)
/* ENDIAN_REVERSE non defini */

/* E/S flottantes */
#define DSPRINTF dsprintf
extern int dsprintf(char*,char*,double);
#define STRTOD(a,b) my_strtod(a,b)
extern double my_strtod(char*,char**);
/* Print */
#define WARN(str) nothing(str)
#define PRINTF nothing
#define PERROR nothing
/* Memory */
#define FREE(ptr)

/* For EvalC */
#define TRUE (1==1)
#define FALSE 0
#define MAX(a,b) ((a)<(b)?(b):(a))
#define MIN(a,b) ((a)<(b)?(a):(b))

extern	ulong *HardRegs;	/* d0_buf(a6) */
extern	short FramePtr;
#define SET_REGISTER(n,buf,sz) memcpy(((char*)HardRegs[n])+4-sz,buf,sz)
#endif	ADEBUG
/*-------------------------------*/
#ifdef	WDB
/* Usual things */
#include	"db.h"

#define EVGETMEM(dst,src,size) StubGetMem((short)size,src,dst,0)
#define EVPUTMEM(dst,src,size) StubPutMem((short)size,dst,src,0)

/* Endianness */
#define getil(l) SWAP32(l)
#define getiw(w) SWAP16(w)
#define ENDIAN_REVERSE(buf,size) BsdIndianReverse(buf,size)
/* E/S flottantes */
#define DSPRINTF wsprintf
#define STRTOD(a,b) strtod(a,b)
/* Print */
#define WARN(str) wrprintf("warning: %s",str)
#define PRINTF wprintf
#define PERROR wrprintf
/* Memory */
#define FREE(ptr) free(ptr)
extern	ulong *HardRegs;
extern	short FramePtr;
#define SET_REGISTER(n,buf,sz)	DBSetRegister(n,buf,sz)
#endif	WDB
/*-------------------------------*/

#include "coff.h"
#include "bsd.h"

#define DIR_SEP '/'
#define VOL_SEP ':'
#define MAX_MODS 256
#define MAX_BRACK_LEVEL 256
#define MEMBLK_SIZE 16384
#define PTR_SIZEOF 4 /* void* for target */

extern	char	*PrgName;
