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
#define	M68KMAGIC	0x150L
#define	M56KMAGIC	0x2c5L
#define	M96KMAGIC	-1L
#define	M16KMAGIC	-1L
#define	I386MAGIC	0x14cL
#define	A29KMAGIC	0x17aL

#define	F_RELFLG	0x1L
#define	F_EXEC		0x2L
#define	F_LNNO		0x4
#define	F_LSYMS		0x8L
#define	F_CC		0x10000L

/*#define	MOTOCOFF*/

#if	defined(MOTOCOFF)
typedef	ulong	CCHAR;			/* Motorola's COFF ~ ELF */
typedef	ulong	CWORD;			/* Motorola's COFF ~ ELF */
typedef	ulong	CLONG;
#else	MOTOCOFF
typedef	uchar	CCHAR;			/* UNIX's (standard) COFF */
typedef	ushort	CWORD;			/* UNIX's (standard) COFF */
typedef	ulong	CLONG;
#endif	MOTOCOFF

typedef struct {
	CWORD	magic	PACKED;
	CWORD	secnb	PACKED;
	CLONG	date	PACKED;
	CLONG	symoff	PACKED;
	CLONG	symnb	PACKED;
	CWORD	optsz	PACKED;
	CWORD	flags	PACKED;
} COF_HDR;

typedef	ulong	CMAP;

typedef struct {
	CLONG	addr;
#if	defined(MOTOCOFF)
	CMAP	map;				/* used in Motorola DSP 56K/96K at least */
#endif	MOTOCOFF
} CADDR;

#define	WORD_SZ	1				/* size of a word / byte */
#define	SYM_VAL_SZ	1			/* size of a symbol value */
#define	CORE_ADDR_ADDR(x)	(x).addr
#define	CORE_ADDR_MAP(x)	(x).map
#define	BTYPE(x)	(x)&0xf
#define	ISFCN(x)	(x)&0x20

typedef struct {
	CWORD	magic	PACKED;
	CWORD	vstamp	PACKED;
	CLONG	tsz		PACKED;
	CLONG	dsz		PACKED;
	CLONG	bsz		PACKED;
	CADDR	entry	PACKED;
	CADDR	tstrt	PACKED;
	CADDR	dstrt	PACKED;
#if	defined(MOTOCOFF)
	CADDR	tend	PACKED;
	CADDR	dend	PACKED;		/* again in Motorola */
#endif
} COF_RUN;

enum SECFLAGS {
	STYP_REG=	0,
	STYP_DSECT=	1,
	STYP_NOLOAD=2,
	STYP_GROUP=	4,
	STYP_PAD=	8,
	STYP_COPY=	0x10,
	STYP_TEXT=	0x20,
	STYP_DATA=	0x40,
	STYP_BSS=	0x80,
	STYP_BLOCK=	0x400
/* STYP_INFO STYP_LIB */
};

typedef CLONG SECFLAGS;

typedef union {
	char	name[8];
	struct {
		CLONG	zer;
		CLONG	off;
	} str;
} CNAME;

typedef struct {
	CNAME	name	PACKED;	/* should be only char[8]; */
	CADDR	paddr	PACKED;
	CADDR	vaddr	PACKED;
	CLONG	size	PACKED;
	CLONG	scnptr	PACKED;
	CLONG	relptr	PACKED;
	CLONG	lnnoptr	PACKED;
	CWORD	nreloc	PACKED;
	CWORD	nlnno	PACKED;
	SECFLAGS	flags	PACKED;
} COF_SEC;

typedef struct {
	CLONG	vaddr;
	CLONG	symndx;
	CWORD	type;
} COF_REL;

typedef struct {
	union {
		CLONG	symndx;	/* lnno==0 */
		CLONG	paddr;	/* otherwise */
	} l;
	CWORD	lnno;
} COF_LINE;

typedef enum {
	T_NULL=0,
	T_VOID,
	T_CHAR,
	T_SHORT,
	T_INT,
	T_LONG,
	T_FLOAT,
	T_DOUBLE,
	T_STRUCT,
	T_UNION,
	T_ENUM,
	T_MOE,
	T_UCHAR,
	T_USHORT,
	T_UINT,
	T_ULONG,
	T_LNGDBL
} C_TYPE;

typedef enum {
	DT_NON=0,
	DT_PTR,
	DT_FCN,
	DT_ARY
} C_DTYPE;

enum CCLASS {
	C_EFCN=0xff,/* End of function */
	C_NULL=0,		/* None */
	C_AUTO,		/* Stacked auto var */
	C_EXT,		/* External symbol */
	C_STAT,		/* Static ?? */
	C_REG,		/* Register var */
	C_EXTDEF,	/* External defintion ?? */
	C_LABEL,	/* Goto label */
	C_ULABEL,	/* Undefined label ?? */
	C_MOS,		/* Member of structure */
	C_ARG,		/* Stacked fct arg */
	C_STRTAG,	/* Structure tagname entry */
	C_MOU,		/* Member of union */
	C_UNTAG,	/* Union tagname entry */
	C_TPDEF,	/* Typedef entry */
	C_USTATIC,	/* Undefined static ?? */
	C_ENTAG,	/* Enum tag ?? */
	C_MOE,		/* Member of enum */
	C_REGPARM,	/* Register parameter */
	C_FIELD,	/* Member of bitfield */
	C_BLOCK=100,/* Beginning/end of block */
	C_FCN,		/* Beginning/end of function */
	C_EOS,		/* End of structure */
	C_FILE,		/* Symbol table index */
	C_LINE,		/* Line # ?? */
	C_ALIAS,	/* Duplicate tag */
	C_HIDDEN	/* Ext symbol in dmert public lib ?? */
};

/* typedef	CCHAR	CCLASS; */
typedef	short	CCLASS;

typedef enum {
	C_PTV=	0xfffc,
	C_NTV=	0xfffd,
	C_DEBUG=0xfffe,
	C_ABS=	0xffff,
	C_UNDEF=0
} C_SEC;

typedef struct {
	CNAME	name;
	union {
		CLONG	value[SYM_VAL_SZ];
		CADDR	addr;
	} value;
	CWORD	secnum;
	CWORD	type;
	CCHAR	class;
	CCHAR	auxnb;
} COF_SYM;

typedef struct {
	char	name[14];
	CLONG	off;
	char	dum[14];
} AUX_FILE;

typedef struct {
	CLONG	scnlen;
	CLONG	nreloc;
	CLONG	nlinno;
	char	dum[20];
} AUX_SEC;

typedef struct {
	CLONG	secno;
	CLONG	rsecno;
	CLONG	mem;
	CLONG	flags;
	CLONG	bufcnt;
	CLONG	buftyp;
	CLONG	buflim;
	CLONG	ovlcnt;
	CLONG	ovlmem;
	CLONG	ovlstr;
	CLONG	dum;
} AUX_RSEC;

typedef struct {
	CLONG	dum1[2];
	CLONG	size;
	CLONG	dum2;
	CLONG	endndx;
	CLONG	dum3;
} AUX_TAG;

typedef struct {
	CLONG	tagndx;
	CLONG	dum1;
	CLONG	size;
	CLONG	dum2[5];
} AUX_EOS;

typedef struct {
	CLONG	tagndx;
	CLONG	fsize;
	CLONG	lnnoptr;
	CLONG	endndx;
	CLONG	dum[4];
} AUX_SYM;

typedef struct {
	CLONG	tagndx;
	CLONG	lnno;
	CLONG	size;
	CLONG	dimen[4];
	CLONG	dum;
} AUX_ARY;

typedef struct {
	CLONG	dum1;
	CLONG	lnno;
	CLONG	dum2;
} AUX_EOB;

typedef struct {
	CLONG	dum1;
	CLONG	lnno;
	CLONG	dum2;
	CLONG	endndx;
	CLONG	dum3[3];
} AUX_SOB;

typedef struct {
	CLONG	tagndx;
	CLONG	dum1;
	CLONG	sz;
	CLONG	dum2;
} AUX_ENUM;

