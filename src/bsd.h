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
#define	OMAGIC	0x107	/* Code indicating object file or impure executable */
#define	NMAGIC	0x108	/* Code indicating pure executable */
#define	ZMAGIC	0x10b	/* Code indicating demand-paged executable */
#define	QMAGIC	0xcc	/* Code indicating demand-paged executable C header */
#define	LIMAGIC	0x64	/* Code indicating Linux/i386 */
#define	LMMAGIC	0x02	/* Code indicating Linux/m68k */
#define	LIPAGE	1024L	/* Linux/i386 implicit page size */
#define	LMPAGE	1024L	/* Linux/m68k implicit page size */

typedef struct {
	ulong	magic;	/* should be 0x107L */
	ulong	tsize;	/* text size in bytes */
	ulong	dsize;	/* data size in bytes */
	ulong	bsize;	/* bss size in bytes */
	ulong	ssize;	/* symbols size in bytes */
	ulong	entry;	/* first entry (should be 0L) */
	ulong	trsize;	/* text relocation size in bytes */
	ulong	drsize;	/* data relocation size in bytes */
} BSD_HDR;

typedef struct {
	bfuint	snum:24;	/* symbol number or section reloc */
	bfuint	pc:1;		/* 1 means pc-relative */
	bfuint	size:2;		/* 1<<size in bytes */
	bfuint	ext:1;		/* 1 means snum contains symbol number */
	bfuint	pad:3;		/* padding bits, always 0 */
	bfuint	swap:1;		/* 1 means GPU style swap (MOVEI) */
} BSD_RFIELD;

typedef union {
	long	l;
#if !defined(__PUREC__)
	BSD_RFIELD	t;		/* 32-bitfield */
#endif
} BSD_RTYPE;

typedef struct {
	long	addr;
	BSD_RTYPE	t;
} BSD_REL;

#define	N_EXT	1			/* External */

#define	N_UNDF	0			/* Undefined */
#define	N_ABS	2			/* Absolute */
#define	N_TEXT	4			/* TEXT rel */
#define	N_DATA	6			/* DATA rel */
#define	N_BSS	8			/* BSS rel */

#define	N_FN	0xf
#define	N_COMM	0x12		/* Common ref */
#define	N_TYPE	0x1e
#define	N_STAB	0xe0		/* Stab mask */
#define	N_INDR	0xa			/* Indirect symbol */
#define	N_SETA	0x14		/* Absolute set element symbol */
#define	N_SETT	0x16		/* Text set element symbol */
#define	N_SETD	0x18		/* Data set element symbol */
#define	N_SETB	0x1A		/* Bss set element symbol */
#define	N_SETV	0x1C		/* Pointer to set vector in data area.  */

/* stabs */
#define	N_GSYM	0x20		/* Global variable */
#define	N_FNAME	0x22		/* Fortran function name */
#define	N_FUN	0x24		/* C func name or TEXT var */
#define	N_STSYM	0x26		/* Static DATA */
#define	N_LCSYM	0x28		/* Static BSS */
#define	N_MAIN	0x2a		/* Main name */
#define	N_PC	0x30		/* Pascal global symbol */
#define	N_NSYMS	0x32		/* Ultrix 4.0 nb of syms */
#define	N_NOMAP	0x34		/* Ultrix 4.0 no DST map */
#define	N_OBJ	0x38		/* Solaris ?? */
#define	N_OPT	0x3c		/* Solaris ?? */
#define	N_RSYM	0x40		/* Register variable */
#define	N_M2C	0x42		/* M2 compilation unit */
#define	N_SLINE	0x44		/* TEXT line number (Value: @, Desc: l#) */
#define	N_DSLINE	0x46	/* DATA line number (Value: @, Desc: l#) */
#define	N_BSLINE	0x48	/* BSS line number (Value: @, Desc: l#) */
#define	N_BROWS	0x48		/* Sun's source-code browser stabs */
#define	N_DEFD	0x4a		/* M2 definition module dependency */
#define N_ASLINE	0x4c	/* ABS line number (Value: @, Desc: l#) (add from ALB) */
#define	N_EHDECL	0x50	/* C++ exception variable */
#define	N_MOD2	0x50		/* M2 info "for imc" */
#define	N_CATCH	0x54		/* C++ `catch' clause */
#define	N_SSYM	0x60		/* Structure/union (Value=offset) */
#define	N_SO	0x64		/* Main source (Value=TEXT @) */
#define	N_LSYM	0x80		/* Stack auto var (Value=offset) */
#define	N_BINCL	0x82		/* SUN beginning of include */
#define	N_SOL	0x84		/* Sub source (Value=TEXT @) */
#define	N_PSYM	0xa0		/* Par var (Value=offset) */
#define	N_EINCL	0xa2		/* SUN end of include */
#define	N_ENTRY	0xa4		/* Alt entry point */
#define	N_LBRAC	0xc0		/* Beg of lexical block */
#define	N_EXCL	0xc2		/* SUN deleted include file */
#define	N_SCOPE	0xc4		/* M2 scope */
#define	N_RBRAC	0xe0		/* End of lexical block */
#define	N_BCOMM	0xe2		/* Beg of common block */
#define	N_ECOMM	0xe4		/* End of common block */
#define	N_ECOML	0xe8		/* Beg of local common block */
#define	N_NBTEXT	0xf0	/* Gould */
#define	N_NBDATA	0xf2	/* Gould */
#define	N_NBBSS	0xf4	/* Gould */
#define	N_NBSTS	0xf6	/* Gould */
#define	N_NBLCS	0xf8	/* Gould */
#define	N_LENG	0xfe	/* Value=prev entry length */

/* The above information, in matrix format.
	_________________________________________________
	| 00 - 1F are not dbx stab symbols				|
	| In most cases, the low bit is the EXTernal bit|

	| 00 UNDEF  | 02 ABS	| 04 TEXT   | 06 DATA	|
	| 01  |EXT  | 03  |EXT	| 05  |EXT  | 07  |EXT	|

	| 08 BSS    | 0A INDR	| 0C FN_SEQ | 0E		|
	| 09  |EXT  | 0B		| 0D		| 0F		|

	| 10 	    | 12 COMM	| 14 SETA   | 16 SETT	|
	| 11	    | 13		| 15		| 17		|

	| 18 SETD   | 1A SETB	| 1C SETV   | 1E WARNING|
	| 19	    | 1B		| 1D 		| 1F FN		|

	|_______________________________________________|
	| Debug entries with bit 01 set are unused.		|
	| 20 GSYM   | 22 FNAME	| 24 FUN    | 26 STSYM	|
	| 28 LCSYM  | 2A MAIN	| 2C	    | 2E		|
	| 30 PC	    | 32 NSYMS	| 34 NOMAP  | 36		|
	| 38 OBJ    | 3A		| 3C OPT    | 3E		|
	| 40 RSYM   | 42 M2C	| 44 SLINE  | 46 DSLINE	|
	| 48 BSLINE*| 4A DEFD	| 4C        | 4E		|
	| 50 EHDECL*| 52		| 54 CATCH  | 56		|
	| 58        | 5A        | 5C        | 5E		|
	| 60 SSYM   | 62		| 64 SO	    | 66		|
	| 68 	    | 6A		| 6C	    | 6E		|
	| 70	    | 72		| 74	    | 76		|
	| 78	    | 7A		| 7C	    | 7E		|
	| 80 LSYM   | 82 BINCL	| 84 SOL    | 86		|
	| 88	    | 8A		| 8C	    | 8E		|
	| 90	    | 92		| 94	    | 96		|
	| 98	    | 9A		| 9C	    | 9E		|
	| A0 PSYM   | A2 EINCL	| A4 ENTRY  | A6		|
	| A8	    | AA		| AC	    | AE		|
	| B0	    | B2		| B4	    | B6		|
	| B8	    | BA		| BC	    | BE		|
	| C0 LBRAC  | C2 EXCL	| C4 SCOPE  | C6		|
	| C8	    | CA		| CC	    | CE		|
	| D0	    | D2		| D4	    | D6		|
	| D8	    | DA		| DC	    | DE		|
	| E0 RBRAC  | E2 BCOMM	| E4 ECOMM  | E6		|
	| E8 ECOML  | EA		| EC	    | EE		|
	| F0	    | F2		| F4	    | F6		|
	| F8	    | FA		| FC	    | FE LENG	|
	+-----------------------------------------------+
 * 50 EHDECL is also MOD2.
 * 48 BSLINE is also BROWS.
 */

typedef struct {
	ulong	strx;	/* symbol name offset in string table */
	uchar	type;	/* symbol type is one of the above */
	uchar	other;	/* used in C debugging stuff */
	ushort	desc;	/* used in C debugging stuff and source-level */
	ulong	value;	/* symbol value */
} BSD_SYM;

typedef	enum {
	CTYPEC_UNDEF,		/* Not used; catches errors (unset type) */
	CTYPEC_PTR,			/* Pointer type */
	CTYPEC_ARRAY,		/* Array type, lower bound zero */
	CTYPEC_STRUCT,		/* C struct or Pascal record */
	CTYPEC_UNION,		/* C union or Pascal variant part */
	CTYPEC_ENUM,		/* Enumeration type */
	CTYPEC_FUNC,		/* Function type */
	CTYPEC_INT,			/* Integer type */
	CTYPEC_FLT,			/* Floating type */
	CTYPEC_VOID,		/* Void type (values zero length) */
	CTYPEC_SET,			/* Pascal sets */
	CTYPEC_RANGE,		/* Range (integers within spec'd bounds) */
	CTYPEC_PASCAL_ARRAY,/* Array with explicit type of index */
	CTYPEC_ERROR,		/* Unknown type */

	/* C++ */
	CTYPEC_MEMBER,		/* Member type */
	CTYPEC_METHOD,		/* Method type */
	CTYPEC_REF,			/* C++ Reference types */
	CTYPEC_CHAR,		/* real char */
	CTYPEC_BOOL			/* real boolean */
} CTYPE_CODE;

#define	CTYPEF_UNSIGNED	1
#define	CTYPEF_PERM		4	/* pointer to a function returning a built in scalar type */
#define CTYPEF_STUB		8
#define CTYPEF_TARGET_STUB		16

typedef enum
{
	CLASS_UNDEF,	/* Not used; catches errors */
	CLASS_CONST,	/* Value is constant int */
	CLASS_STATIC,	/* Value is at fixed address */
	CLASS_REG,		/* Value is in register */
	CLASS_ARG,		/* Value is at spec'd position in arglist */
	CLASS_REF_ARG,	/* Value address is at spec'd position in */
					/* arglist.  */
	CLASS_REGPARM,	/* Value is at spec'd position in  register window */
	CLASS_LOCAL,	/* Value is at spec'd pos in stack frame */
	CLASS_TYPEDEF,	/* Value not used; definition in SYMBOL_TYPE
					Symbols in the namespace STRUCT_NAMESPACE
					all have this class.  */
	CLASS_LABEL,	/* Value is address in the code */
	CLASS_BLOCK,	/* Value is address of a `struct block'.
					Function names have this class.  */
	CLASS_EXTERNAL,	/* Value is at address not in this compilation.
					This is used for .comm symbols
					and for extern symbols within functions.
					Inside DB, this is changed to CLASS_STATIC once the
					real address is obtained from a loader symbol.  */
	CLASS_CONST_BYTES	/* Value is a constant byte-sequence.   */
} CSYM_CLASS;

typedef struct {
	char	*name;
	struct	_CTYPE	*type;
	long	bitpos,bitsize;
} CTYPE_FIELD,*CTYPE_FIELDP;

typedef struct _CTYPE {
	CTYPE_CODE	code;
	char	*name;
	char	*tag;
	ulong	size;
	struct	_CTYPE	*target;
	struct	_CTYPE	*ptr;
	struct	_CTYPE	*fct;
/*	struct	_CTYPE	*ref;*/		/* C++ */
	short	flags,fieldsnb;
	CTYPE_FIELDP	fields;
	/* C++ */
/*	struct	_CTYPE	*vptr;*/	/* C++ */
} CTYPE,*CTYPEP;

typedef struct scope {
	ulong start;
	ulong end;
	short level;
} SCOPE;

typedef	struct {
	char	*name;
	union {
		ulong	i;
		char	*p;
	} value;
	CTYPEP	type;
	short	class;
	SCOPE	*scope;
} CSYM,*CSYMP;

#define	N_FLAGS_COFF_ENCAPSULATE	0x20	/* coff header precedes bsd header */

typedef struct {
	COF_HDR	cof_hdr PACKED;
	COF_RUN	run_hdr PACKED;
	COF_SEC	scns[3] PACKED;
} COF_ENC_HDR;

typedef enum {
	X_UNDEF,
	X_PTR,
	X_ARRAY,
	X_STRUCT,
	X_UNION,
	X_ENUM,
	X_FUNC,
	X_INT,
	X_FLT,
	X_VOID,
	X_SET,
	X_RANGE,
	X_PARRAY,
	X_MEMBER,
	X_METHOD,
	X_REF
} BSD_XCODE;

#define	X_UNSIGNED	1
#define	X_PERM	4
#define	X_STUB	8
#define	X_CONS	256
#define	X_DEST	512
#define	X_PUBL	1024
#define	X_VIRT	2048

#define	ARLMAG	'Gnu '
#define	ARMAG	"Gnu is Not eUnuchs.\n"
#define	SARMAG	20
#define	ARFMAG	"\r\n"
#define	ARSYM	"__.SYMDEF"

typedef struct {
	char	name[16];
	char	size[12],date[12],mode[8],uid[4],gid[4],fmag[2];
} BSD_ARCHDR;

typedef struct {
	union {
		ulong	strx;
		char	*name;
	} name;
	ulong	loff;
} BSD_SYMDEF;

enum {
	BT_CHAR,BT_SHORT,BT_INT,BT_LONG,BT_LLONG,BT_FLOAT,BT_DOUBLE,
	BT_LDOUBLE,BT_VOID
};
