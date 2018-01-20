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
/* bsdeval.h: evaluateur GCC compile avec GCC:
* ne pas definir INT16
* definir ADEBUG si on linke avec adebug
*/

#include "bsdincl.h"
#define NEED_FIXING 0

/* definition de l'entier de la machine cible */
#ifdef INT16
#define INTSIZE 16
#define TARGET_PURE_C
typedef short INT;
typedef unsigned short UINT;
#else
#define INTSIZE 32
#define TARGET_GCC
typedef long INT;
typedef unsigned long UINT;
#endif

/*
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <math.h>
#include <types.h>
*/

enum {
	COMMA_PRI=1,AFFECT_PRI,IFE_PRI,LOR_PRI,LAND_PRI,OR_PRI,XOR_PRI,AND_PRI,
	EQ_PRI,REL_PRI,SFT_PRI,ADD_PRI,MUL_PRI,CAST_PRI,UNARY_PRI,POSTFIX_PRI
};

#define DEF_BSIZE (sizeof(long double))
#define MAX_SCALAR_SIZEOF (sizeof(long double))

typedef int BOOL;
typedef char BYTE;
typedef unsigned char UBYTE;
typedef short HWORD;
typedef unsigned short UHWORD;
/*typedef long WORD;*/
typedef float SINGLE;
typedef double DOUBLE;

#ifdef ADEBUG
#define CUR_NBFILESYMS (LTabs->nb_filesyms)
#define CUR_TABFILESYMS (LTabs->filesyms)
#else
#define CUR_NBFILESYMS CurNbFileSyms
#define CUR_TABFILESYMS CurTabFileSyms
extern long CurNbFileSyms;
extern CSYMP *CurTabFileSyms;
#endif

typedef int (* PTF)();

/* les classes d'operandes */
#define C_LVALUE 1
#define C_CONST  (1<<1)

#define FUNCTYPE_SIZE 1

#ifdef TARGET_PURE_C
/* extrait de pure.h */
/* LineNumber */
enum symKind {
	SK_TYPE,	/* C def */
	SK_TAG,
	SK_AUTO,	/* local */
	SK_PARM,	/* local */
	SK_ISTATIC,
	SK_STATIC,
	SK_GLOBAL,	/* global */
	SK_STATICFUNC,
	SK_GLOBALFUNC /* func */
};

enum symSegment {
	SS_NOSEGMENT, /* C def */
	SS_REGISTER,	/* register */
	SS_A7,		/* stack */
	SS_A6,
	SS_CODE,	/* func */
	SS_DATA,	/* global */
	SS_BSS
};

/* Debug Symbol */
typedef struct {
	char	kind;
	char	__seg;
	char *name; /* 2(a4) */
	struct type_struct *type; /* 6(a4)=l5 offset */
	void *addr; /* 10(a4)=addr/reg number */
} SYM_STRUCT,*SYM_PTR;
#endif /* TARGET_PURE_C */

enum TOPTYPE {
	TT_NOTYPE,	/*	0:	????	*/
	TT_CHAR,	/*	1:	char	*/
	TT_UCHAR, /*	2:	uchar */
#ifndef TARGET_PURE_C
	TT_SHORT,  /* 3: short */
	TT_USHORT, /* 4: ushort */
#endif
	TT_INT, 	/*	5:	int 	*/
	TT_UINT,	/*	6:	uint	*/
	TT_LONG,	/*	7:	long	*/
	TT_ULONG, /*	8:	ulong */
#ifdef TARGET_GCC
	TT_LLONG,
	TT_ULLONG,
#endif
	TT_FLOAT, /*	9:	float */
	TT_DOUBLE,	/*	10:  double  */
	TT_LDOUBLE, /*	11:  long double */
	TT_VOID,	/*	12:  void  */
	TT_POINTER, /*	13:  pointer :0  */
	TT_ARRAY, /*	14:  array :1  */
	TT_ENUM,	/*	15:  enum  :2  */
	TT_STRUCT,	/*	16:  struct  :3  */
	TT_UNION, /*	17:  union :4  */
	TT_FUNC,	/*	18: func	:5	*/
	TT_BIT, 	/*	19: bitfield	:6	*/
};
typedef char	TOPTYPE;

#ifdef TARGET_PURE_C
/* valeurs bidons pour types PureC */
#define TT_SHORT ((TOPTYPE)-1)
#define TT_USHORT ((TOPTYPE)-2)
#define TT_LLONG TT_LONG
#define TT_ULLONG TT_ULONG
#endif

#define IS_INT(t) ((t)>=TT_CHAR && (t)<=TT_ULONG)
#define IS_MEMOBJ(type) ((type)<TT_LDOUBLE || (type)==TT_POINTER || \
	(type)==TT_STRUCT || (type)==TT_UNION)
#define IS_SCALAR(t) (((t)>=TT_CHAR && (t)<=TT_LDOUBLE) || (t)==TT_ENUM \
	|| (t)==TT_BIT)

#ifdef TARGET_PURE_C
/* debug Type */
typedef struct type_struct {
	TOPTYPE top;
	uchar modifier;
	ulong size;
	SYM_PTR sym; /* pour typedef */
	union {
		struct type_struct *basetype;
		struct	{
			long	first; /* member */
			ushort	nb;
		} s;
		struct {
			long	base;
			char	off;		/* bitfield offset */
			char	width;		/* bitfield size */
		} b;
	} t;
} TYPE_STRUCT,*TYPE_PTR,*RTYPE_PTR;

/* debugMember */
typedef struct {
	char *name;
	ulong offset;
	TYPE_PTR type;
} MEMBER_STRUCT,*MEMBER_PTR;

typedef struct operande {
	TYPE_STRUCT type;
	int  class;  /* la classe */
	void *val; /* =&buf si scalaire, sinon vaut addr */
	char buf[sizeof(long double)]; /* buffer valeur scalaire */
	ulong bsize; /* taille du buffer si alloue ; obsolete */
	SYM_PTR sym;
	void *addr; /* adresse de l'objet en memoire p1 */
	struct operande *link;
} OP;

#define IS_REG_OP ((op)->sym->kind==SS_REGISTER)
#define SET_REGISTER(n,buf,sz) memcpy(((char*)LTabs->d0_buf[i])+4-sz,buf,sz)
#endif /* TARGET_PURE_C */

#ifdef TARGET_GCC
typedef CTYPE TYPE_STRUCT;
typedef CTYPEP TYPE_PTR;
typedef CTYPEP RTYPE_PTR;
typedef CSYM SYM_STRUCT;
typedef CSYMP SYM_PTR;

extern CTYPEP *IntrnTypes[];

#define GET_TOPTYPE(op) ((op)->top)
#define SET_TOPTYPE(op,t) ((op)->top=(t))
TOPTYPE BsdGenTopType(TYPE_PTR);
#define EXTRACT_TOPTYPE(t) BsdGenTopType(t)
#define ITYPE_NAME(i) ((*(IntrnTypes[i]))->name)
#define GET_ITYPE_BYNUM(i) (*(IntrnTypes[i]))
#define GET_ITYPE(t) BsdGetIType(t)
#define SET_ITYPE(op,top) ((op)->type=*(GET_ITYPE(top)))
#define ITYPES_NB 14
#define IS_REG_OP(op) ((op)->sym && ((op)->sym->class==CLASS_ARG || \
								 (op)->sym->class==CLASS_REGPARM))
#endif /* TARGET_GCC */

typedef struct operande {
	CTYPE type;
	int  class;  /* la classe */
	void *val; /* =&buf si scalaire, buffer alloue sinon */
	char buf[sizeof(long double)]; /* buffer valeur scalaire */
	ulong bsize; /* taille du buffer si alloue */
	CSYMP sym;
	void *addr; /* adresse de l'objet */
	CTYPE_FIELDP field; /* pour bitfields uniquement */
	struct operande *link;
	uchar modifier;
	TOPTYPE top;
} OP;


#ifdef TARGET_PURE_C
struct SrcDbgPtrs {
	ulong nb_types; /* l5_len */
	char *names;	/* tcnames_ptr */
	char *syms; 	/* l3 */
	char *types;	/* l5 */
	char *structs; /* l6 */
	ulong *d0_buf;
	uchar *text_buf,*data_buf,*bss_buf;
};

extern struct SrcDbgPtrs *LTabs;
extern TYPE_STRUCT htypes[TT_LDOUBLE-TT_CHAR+1];

#define MK_SYMPTR(x) ((SYM_PTR)((ulong)(x)+LTabs->syms))
#define MK_TYPEPTR(x) ((TYPE_PTR)((ulong)(x)+LTabs->types))
#define UNMK_TYPEPTR(x) ((TYPE_PTR)((ulong)(x)-(ulong)LTabs->types))
#define MK_STRUCTPTR(x) ((MEMBER_PTR)((ulong)(x)+LTabs->structs))
#define MK_NAMEPTR(x) (LTabs->names+(ulong)(x))
#define GET_ITYPE(t) htypes[t];
#endif	/* TARGET_PURE_C */

#ifdef TARGET_GCC
struct SrcDbgPtrs {
	ulong nb_filesyms;
	CSYMP *filesyms;
	ulong *d0_buf;
	uchar *text_buf,*data_buf,*bss_buf;
};
extern struct SrcDbgPtrs *LTabs;
TYPE_PTR BsdGetIType(TOPTYPE);
#define MK_SYMPTR(x) (x)
#define MK_TYPEPTR(x) (x)
#define UNMK_TYPEPTR(x) (x)
#define MK_STRUCTPTR(x) (x)
#define MK_NAMEPTR(x) (x)
#endif	/* TARGET_GCC */

/* PROTOS */
int BsdPushOp(OP*);
void BsdPopOp(void);
void BsdPopOpNofree(void);
int BsdPushInt(INT);
TYPE_PTR BsdAllocType(void);

int BsdConvertTypes(OP *a,OP *b);
int BsdEqTypes(RTYPE_PTR,RTYPE_PTR);
TYPE_PTR BsdCheckCast(int*);
int BsdDoStruct(char*,int,int);
int BsdDoPStruct(char*,int,int);
int BsdDoCast(TYPE_PTR);
int BsdDoSftRight(void);
int BsdDoXor(void);
int BsdDoEq(void);
int BsdDoNe(void);
int BsdDoLt(void);
int BsdDoLe(void);
int BsdDoGt(void);
int BsdDoGe(void);
int BsdDoDiv(int);
int BsdDoSftLeft(void);
int BsdDoPlus(void);
int BsdDoUMinus(void);
int BsdDoAnd(void);
int BsdDoCmpAnd(void);
int BsdDoOr(void);
int BsdDoCmpOr(void);
int BsdDoMul(void);
int BsdDoModulo(int);
int BsdDoMinus(void);
int BsdDoBinaryNot(void);
int BsdDoLogicalNot(void);
int BsdGetHexNum(void);
int BsdGetDecNum(void);
int BsdGetOctalNum(void);
int BsdEvalChar(void);
int BsdRefPtr(void);
int BsdDerefPtr(int);
int BsdDoAffect(int);
int BsdDerefArray(int);
int BsdDoIncr(int);
int BsdDoDecr(int);
int BsdDoSizeof(void);

int BsdReadMem(char*,char*,ulong);
void BsdPEvalError(char*,int);
void BsdInternalError(char*);
void BsdValeur(char*);
void BsdInitHTypes(void);
void BsdCreateVars(void);
long BsdObjectSize(TYPE_PTR);

char BsdGetChar(OP*);
uchar BsdGetUChar(OP*);
short BsdGetShort(OP*);
ushort BsdGetUShort(OP*);
INT BsdGetInt(OP*);
UINT BsdGetUInt(OP*);
long BsdGetLong(OP*);
#ifdef TARGET_PUREC
INT GetBitsSVal(INT*,RTYPE_PTR);
UINT GetBitsUVal(UINT*,RTYPE_PTR);
#endif
#ifdef TARGET_GCC
INT BsdGetBitsSVal(INT*,CTYPE_FIELDP);
UINT BsdGetBitsUVal(UINT*,CTYPE_FIELDP);
void BsdPutBitsVal(UINT*,UINT,CTYPE_FIELDP);
#endif
unsigned long BsdGetULong(OP*);
float BsdGetFloat(OP*);
double BsdGetDouble(OP*);
long double BsdGetLDouble(OP*);
int BsdPointerAdd(OP*,OP*);
int BsdPointerSub(OP*,OP*);

extern SYM_PTR BsdFindVar(char *p);
void *BsdGetObjAddr(SYM_PTR,ulong);
int BsdReallocBuf(OP*,ulong);
int BsdEval(int,int);

#if defined(ADEBUG)
void	*MyMalloc(ulong);
void	MyMfree(void*,ulong);
#endif	ADEBUG

#if defined(WDB)
#define MyMalloc(x) malloc(x)
#define MyMfree(x,y)	free(x)
#endif	WDB

/*	codes d'erreurs de l'evaluateur */
enum {
	NO_ERROR,
	EVERR_UNEXP_CLOSEPAR,
	EVERR_UNMATCHED_PARENT,
	EVERR_BOP_EXPECTED,
	EVERR_NUMVAL_EXPECTED,
	EVERR_UNDFND_SYMBOL,
	EVERR_ZERO_DIVIDE,
	EVERR_CANT_AFFECT,
	EVERR_BAD_HEXA,
	EVERR_UNEXP_EOE,
	EVERR_MISSING_SINGLE_QUOTE,
	EVERR_UNEXP_BOP,
	EVERR_UNEXP_UOP,
	EVERR_ERR_CHAR,
	EVERR_SPURIOUS_DBLEP,
	EVERR_IFE_NOMATCH,
	EVERR_BAD_FLOAT,
	EVERR_BOOL_EXPECTED,
	EVERR_TYPE_MISMATCH,
	EVERR_BAD_PTR_TYPE,
	EVERR_UNKNOWN_TYPE,
	EVERR_LOOSE_PREC,
	EVERR_NO_MEM,
	EVERR_VOID_USED,
	EVERR_LVALUE_REQ,
	EVERR_NO_ADDR,
	EVERR_UNEXP_CLOSEBRACK,
	EVERR_UNMATCHED_BRACK,
	EVERR_IDX_NEG,
	EVERR_OUTOF_ARRAY,
	EVERR_INVAL_CAST,
	EVERR_STRUCT_REQ,
	EVERR_PSTRUCT_REQ,
	EVERR_MEMB_NF,
	EVERR_INTT_REQ,
	EVERR_CANT_CMP,
	EVERR_NULL_DEREF,
	EVERR_PTR_READ,
	EVERR_PTR_WRITE,
	NB_ERRORS
};

