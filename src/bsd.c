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
#include	"bsdincl.h"

#ifdef BDEBUG
char *BreakSym = "next";
#define BRKSYMLEN 4 /* strlen(BreakSym) */
#endif

#define MALLOC(size) BsdMalloc(size)

#define ADD_MODULE(dir) { \
			if (++nbmods >= MAX_MODS) \
				return 0; \
			curmod=nbmods-1; \
			mods[curmod].name=strtbl+getil(syms->strx); \
			mods[curmod].nbl=0; \
			mods[curmod].dirname=dir; }
#define END_SYMS(cnt,max) { \
		if (cnt>max) \
			max=cnt; \
		cnt=0; }

#define GETFILESCOPE(scope) GetScope(scope,0)
#define GETFUNCSCOPE(scope) GetScope(scope,1)
#define IN_SCOPE(inner,outer) (inner==outer || \
	((inner)->start>=(outer)->start && (inner)->end<=(outer)->end))

struct LineEntry {
	ushort line;
	ulong pc;
} *LineTab;

struct Module {
	char *dirname;
	char *name;	/* le nom full ou relatif dans les strings */
	ushort nbl; /* le nbre d'entrees ligne */
	struct LineEntry *lines,*curline;
	ulong binoffs;
	SCOPE *scope;
	CTYPEP *ttab;	/* tableau des types */
	ulong tnb;		/* le nbre des types */
} *ModTab;

struct smallblk {
	struct Module *mod;
	ulong blkstrt;
	ulong blksz;
};

struct MemBlk {
	struct MemBlk *next;
	char *buf;
	ulong cursz,allocsz;
} *CurMemBlk;

typedef struct {
	BSD_SYM	*syms,*csym;
	char	*strs;
	ulong	strsz,snb;
	struct scope *scope;
} DBXINF, *DBXINFP;

struct SymMemCtxt {
	CSYMP *tab;
	ulong cursz;
} CSymGlblMem,CSymFileMem,CSymLoclMem;

extern int CBsdPrintType(char *buf,CTYPEP type);
int AllocModNames(void);

CTYPEP	AllocCType(long *typenums);
CTYPEP	BReadCType(char **ptr,DBXINFP);
long	BReadCNb(char **ptr,char c,short *bits);
short	BReadCTypeNb(char **ptr,long *typenums);

ulong NbMods,NbScopes,TotNbl;
ulong PTypeCurSz;
SCOPE *ScopeTab,*CurScope;
ulong	CTypeNb=0L;
CTYPEP	*CTypeTab=NULL;	/* types *array (fixed order) */

CSYMP	*CSymTab,*CSymGlblTab;	/* symbols *array (on-disk order) */
ulong	CSymGlblNb,CSymFileNb,CSymLoclNb;
ulong	MaxLocSyms,MaxStaticSyms;
CSYMP *LocsTab,*StaticsTab /*,*GlosTab*/ ;

/*
#define	CSymFileTab	CSymTab
#define	CSymLoclTab	CSymTab
*/

static ulong locals_nb,statics_nb;

CTYPEP	ctype_char,ctype_short,ctype_int,ctype_long,ctype_longlong;
CTYPEP	ctype_uchar,ctype_ushort,ctype_uint,ctype_ulong,ctype_ulonglong;
CTYPEP	ctype_float,ctype_double,ctype_void;
CTYPEP	ctype_longdouble;

char	*CTypeUnsigned[(sizeof(unsigned long)+1)*sizeof(void *)];
char	*CTypeSigned[(sizeof(long)+1)*sizeof(void *)];
char	*CTypeFloat[(sizeof(double)+1)*sizeof(void *)];

CTYPEP *IntrnTypes[]={&ctype_char,&ctype_short,&ctype_int,&ctype_long,
		&ctype_longlong,&ctype_uchar,&ctype_ushort,&ctype_uint,
		&ctype_ulong,&ctype_ulonglong,&ctype_float,&ctype_double,&ctype_void,
		&ctype_longdouble};

#if	defined(ADEBUG)
extern char *internal_a6;

#if	defined(BDEBUG)
static __inline void Illegal(void)
{
	if (**(long**)0x10 == 0x7c0700)	/* adebug: OR #$700,SR */
	__asm __volatile ("illegal");
}
#endif	BDEBUG


void nothing() {}

/* reservation par la routine d'Adebug */
static __inline char *Reserve(ulong allocsize)
{
	register char* _res __asm("d0");
	register ulong d0 __asm("d0") = allocsize;
	register char* a6 __asm("a6") = internal_a6;

	__asm __volatile ("moveq #1,d1;"
		"moveq #2,d2;"
		"jsr reserve_memory"
		: "=r" (_res)
		: "r" (d0), "r" (a6)
		: "d0","d1","d2","a0","a1","memory");
	return _res;
}

/* liberation par la routine d'Adebug */
static __inline void Free(void *buf,ulong sz)
{
	register int d0 __asm("d0") = sz;
	register void* a0 __asm("a0") = buf;
	register char* a6 __asm("a6") = internal_a6;

	__asm __volatile (
		"jsr free_memory"
		: /* void */
		: "r" (a6), "r" (d0), "r" (a0)
		: "d0","d1","a0","a1","memory");
}

/* recherche d'une var dans les symboles d'Adebug */
static __inline ulong AdbgFindVar(char *name)
{
	register char* a0 __asm("a0") = name;
	register char* a6 __asm("a6") = internal_a6;
	register ulong res __asm("d0");

	__asm __volatile (
		"jsr bsdfind_ld_sym"
		: "=r" (res)
		: "r" (a6), "r" (a0)
		: "d0","d1","a0","a1","memory");
	return res;
}
#endif	ADEBUG

#if	defined(WDB)
static __inline char *Reserve(ulong allocsize)
{
  return (char*)malloc(allocsize);
}

static __inline void Free(void *buf,ulong sz)
{
  free(buf);
}
#endif	WDB

static void *BsdMalloc(ulong size)
{
	struct MemBlk *m=CurMemBlk;
	void *ret;
	ulong allsz;

	if (size&1) size++; /* forcer a pair */
	if (m && m->cursz+size<=m->allocsz) {
		ret=m->buf+m->cursz;
		m->cursz+=size;
		return ret;
	}
	else {
		allsz=(size<=MEMBLK_SIZE)?MEMBLK_SIZE:size;
		m=(struct MemBlk*)Reserve(allsz+sizeof(struct MemBlk));
		if (!m)
			return NULL;
		m->buf=(char*)m+sizeof(struct MemBlk);
		m->allocsz=allsz;
		m->cursz=size;
		m->next=CurMemBlk;
		CurMemBlk=m;
		return m->buf;
	}
}

void BsdFreeMemBlocks(void)
{
	struct MemBlk *m=CurMemBlk,*m1;
	while (m) {
		m1=m->next;
		Free(m,m->allocsz+sizeof(struct MemBlk));
		m=m1;
	}
	CurMemBlk=NULL;
}

void FreeBsdInfos(void)
{
	BsdFreeMemBlocks();
	if (LineTab) {
		Free(LineTab,TotNbl*sizeof(struct LineEntry));
		LineTab=NULL;
	}
	if (ModTab) {
		Free(ModTab,NbMods*sizeof(struct Module));
		ModTab=NULL;
	}
	if (ScopeTab) {
		Free(ScopeTab,NbScopes*sizeof(struct scope));
		ScopeTab=NULL;
	}
	if (CSymGlblMem.tab) {
		Free(CSymGlblMem.tab,CSymGlblMem.cursz);
		CSymGlblMem.tab=NULL; CSymGlblMem.cursz=0;
	}
	if (CSymLoclMem.tab) {
		Free(CSymLoclMem.tab,CSymLoclMem.cursz);
		CSymLoclMem.tab=NULL; CSymLoclMem.cursz=0;
	}
	if (CSymFileMem.tab) {
		Free(CSymFileMem.tab,CSymFileMem.cursz);
		CSymFileMem.tab=NULL; CSymFileMem.cursz=0;
	}
	if (LocsTab) {
		Free(LocsTab,MaxLocSyms*sizeof(CSYMP));
		LocsTab=NULL;
	}
	if (StaticsTab) {
		Free(StaticsTab,MaxStaticSyms*sizeof(CSYMP));
		StaticsTab=NULL;
	}
	MaxLocSyms=MaxStaticSyms=TotNbl=NbMods=NbScopes=0;
}

/* size: nouvelle taille en bytes de la table de CSYMP  */
CSYMP *ReallocPSym(struct SymMemCtxt *mem,ulong size)
{
	CSYMP *p;
	long dsize=size-mem->cursz;	/* valeur d'agrandissement */

	if (dsize<=0)
		return mem->tab;
	else {
		if (dsize<512*sizeof(CSYMP))
			dsize=512*sizeof(CSYMP); /* agrandissement minimal 512 ptrs */
		p=(CSYMP*)Reserve(mem->cursz+dsize);
		if (!p)
			return NULL;
		if (mem->cursz && mem->tab) {
			memcpy(p,mem->tab,mem->cursz);
			Free(mem->tab,mem->cursz);
		}
		mem->cursz += dsize;
		mem->tab=p;
		return p;
	}
}

CTYPEP *ReallocPType(CTYPEP *oldptr,ulong size)
{
	CTYPEP *p;

	if (size<=PTypeCurSz)
		return oldptr;
	else {
		p=(CTYPEP*)Reserve(PTypeCurSz+(512*sizeof(CSYMP)));
		if (!p)
			return NULL;
		if (PTypeCurSz && oldptr) {
			memcpy(p,oldptr,PTypeCurSz);
			Free(oldptr,PTypeCurSz);
		}
		PTypeCurSz+=512*sizeof(CSYMP);
		return p;
	}
}

char	*AllocCName(char *src,ulong len)
{
	char	*name;

	if ((len) && ((name=MALLOC(len))!=NULL)) {
		memcpy(name,src,len-1L);
		name[len-1L]=0;
		return(name);
	}
	PERROR("%s: Memory error while allocating %ld for name %s\n",PrgName,len,src);
	return(NULL);
}

CSYMP	AllocCSym(char *str)
{
	CSYMP	csymp;

	if ((csymp=MALLOC(sizeof(CSYM)))!=NULL)
		memset(csymp,0,sizeof(CSYM));
	else
		PERROR("%s: Memory error while allocating CSYM for %s\n",PrgName,str);
	return(csymp);
}

CTYPE_FIELDP	AllocCTypeField(ulong nb)
{
	CTYPE_FIELDP	fieldp;

	if ((fieldp=MALLOC(sizeof(CTYPE_FIELD)*nb))!=NULL)
		memset(fieldp,0,sizeof(CTYPE_FIELD)*nb);
	else
		PERROR("%s: Memory error while allocating %ld CTYPE_FIELD\n",PrgName,nb);
	return(fieldp);
}

CTYPEP	InitCType(CTYPE_CODE code,long size,short uns,char *name)
{
	CTYPEP	ctypep;

	if ((ctypep=AllocCType(NULL))!=NULL) {
		ctypep->code=code;
		ctypep->size=size;
		ctypep->flags=uns?CTYPEF_UNSIGNED|CTYPEF_PERM:CTYPEF_PERM;
		ctypep->fieldsnb=0;
		ctypep->name=name;
	}
	return(ctypep);
}

/*short	AddCSym(CSYMP **root,ulong *nb,CSYMP csymp)*/
short	AddCSym(struct SymMemCtxt *mem,ulong *nb,CSYMP csymp)
{
	CSYMP	*ntab;

	if ((ntab=ReallocPSym(mem,(*nb+1L)*sizeof(CSYMP)))!=NULL) {
		ntab[*nb]=csymp;
/*		*root=ntab;*/
		(*nb)++;
		return(1);
	}
	PERROR("%s: Memory error while storing CSYM\n",PrgName);
	return(-1);
}

CTYPEP	*GetCType(long *typenums)
{
	long	fnb=typenums[0],ndx=typenums[1];
	CTYPEP	*ntab;

	if (fnb<0L) {
		PRINTF("(Invalid file index:%ld)",fnb);
		return(NULL);
	}
	/* + */
	if (ndx>=CTypeNb) {
		if ((ntab=ReallocPType(CTypeTab,(ndx+1L)*sizeof(CTYPEP)))!=NULL) {
			memset(ntab+CTypeNb,0,(ndx+1-CTypeNb)*sizeof(CTYPEP));
			CTypeTab=ntab;
			CTypeNb=ndx+1;
		}
	}
	return(&(CTypeTab[ndx]));
}

CTYPEP	AllocCType(long *typenums)
{
	CTYPEP	ctypep=NULL,*type_addr=NULL;

	if (typenums) {
		if (typenums[1]!=-1L) {
			type_addr=GetCType(typenums);
			ctypep=*type_addr;
		}
	}
	if (ctypep==NULL) {
		if ((ctypep=MALLOC(sizeof(CTYPE)))!=NULL)
			memset(ctypep,0,sizeof(CTYPE));
		else
			PERROR("%s: Memory error while allocating CTYPE\n",PrgName);
		if (type_addr)
			*type_addr=ctypep;
	}
	return(ctypep);
}

CTYPEP	GetCTypeFct(CTYPEP ctypep)
{
	CTYPEP	ptype;

	if (ctypep->fct)
		return(ctypep->fct);
	if ((ptype=AllocCType(NULL))!=NULL) {
		ptype->target=ctypep;
		ctypep->fct=ptype;
		if ((ctypep->flags)&CTYPEF_PERM)
			ptype->flags|=CTYPEF_PERM;
		ptype->size=1;	/* fake size means defined */
		ptype->code=CTYPEC_FUNC;
	}
	return(ptype);
}

CTYPEP	GetCTypePtr(CTYPEP ctypep)
{
	CTYPEP	ptype;

	if (ctypep->ptr)
		return(ctypep->ptr);
	if ((ptype=AllocCType(NULL))!=NULL) {
		ptype->target=ctypep;
		ctypep->ptr=ptype;
		if ((ctypep->flags)&CTYPEF_PERM)
			ptype->flags|=CTYPEF_PERM;
		ptype->size=sizeof(void*);	/* 1;*/	/* fake size means defined */
		ptype->code=CTYPEC_PTR;
	}
	return(ptype);
}

#define	DBX_CONT(pppp)	\
do {				\
	if ((**pppp=='\\') || ((**pppp=='?') && (*(pppp)[1]==0))) {	\
		inf->csym++;	\
		*pppp=inf->strs+getil(inf->csym->strx)-4L;	\
	}	\
} while (0)


/* s<index type><elem>:<type>,<bitpos>,<bitsize>;(...) */
CTYPEP	BReadCTypeStruct(char **ptr,CTYPEP ctypep,DBXINFP inf)
{
	short	fieldsnb=0,nbits;
	CTYPE_FIELDP	fields=NULL,field;
	char	*lookc,*saveptr;
	BSD_SYM *savecsym;
	ctypep->code=CTYPEC_STRUCT;
	ctypep->size=BReadCNb(ptr,0,&nbits);
	if (nbits)
		return(NULL);

	/* daniel: 1ere passe pour connaitre fieldsnb final
	   but: eviter realloc() */
	saveptr=*ptr; savecsym=inf->csym;
	while (**ptr!=';') {
		DBX_CONT(ptr);
		fieldsnb++;
		lookc=strchr(*ptr,':');
		*ptr=lookc+1;
		BReadCType(ptr,inf);
		(*ptr)++;
		BReadCNb(ptr,',',&nbits);
		BReadCNb(ptr,';',&nbits);
	}
	fields=MALLOC(sizeof(CTYPE_FIELD)*fieldsnb);
	if (!fields)
		return NULL;
	fieldsnb=0; *ptr=saveptr; inf->csym=savecsym;

	while (**ptr!=';') {
		DBX_CONT(ptr);
		fieldsnb++;
		/* fields=realloc(fields,sizeof(CTYPE_FIELD)*fieldsnb);*/
		field=&(fields[fieldsnb-1]);
		lookc=strchr(*ptr,':');
		field->name=AllocCName(*ptr,lookc-*ptr+1L);
		*ptr=lookc+1;
		field->type=BReadCType(ptr,inf);
		if (**ptr!=',')
			PRINTF("(`,' expected in struct definition)\n");
		(*ptr)++;
		field->bitpos=BReadCNb(ptr,',',&nbits);
		field->bitsize=BReadCNb(ptr,';',&nbits);
		if (((field->type->code)!=CTYPEC_INT) && ((field->type->code)!=CTYPEC_ENUM))
			field->bitsize=0;
		if (((field->bitsize==8*field->type->size)
			|| ((field->type->code==CTYPEC_ENUM) && (field->bitsize==8*ctype_int->size)))
			&& ((field->bitpos%8)==0))
			field->bitsize=0;
	}
	(*ptr)++;
	ctypep->fieldsnb=fieldsnb;
	ctypep->fields=fields;
	return(ctypep);
}

/* ar<index type>;<lower>;<upper>;<array_contents_type> */
CTYPEP	BReadCTypeArray(char **ptr,CTYPEP ctypep,DBXINFP inf)
{
	short	adjus=0,nbits;
	long	lower,upper;
	CTYPEP	index,elemt,range;

	index=BReadCType(ptr,inf);
	if (*(*ptr)++!=';')
		PRINTF("(`;' expected in array declaration)\n");
	if ((((**ptr)<'0') || ((**ptr)>'9')) && ((**ptr)!='-')) {
		(*ptr)++;
		adjus=1;
	}
	lower=BReadCNb(ptr,';',&nbits);
	if (nbits)
		return(NULL);
	if ((((**ptr)<'0') || ((**ptr)>'9')) && ((**ptr)!='-')) {
		(*ptr)++;
		adjus=1;
	}
	upper=BReadCNb(ptr,';',&nbits);
	if (nbits)
		return(NULL);
	elemt=BReadCType(ptr,inf);
	if (adjus) {
		lower=0L;
		upper=-1L;
	}
	range=AllocCType(NULL);
	range->code=CTYPEC_RANGE;
	range->target=index;
	range->size=index->size;
	range->fieldsnb=2;
	range->fields=AllocCTypeField(2L);
	range->fields[0].bitpos=lower;
	range->fields[1].bitpos=upper;
	range->fields[0].type=ctype_int;
	range->fields[1].type=ctype_int;
	ctypep->code=CTYPEC_ARRAY;
	ctypep->target=elemt;
	ctypep->size=(upper-lower+1)*elemt->size;
	ctypep->fieldsnb=1;
	range->fields=AllocCTypeField(1L);
	range->fields[0].type=range;
	return(ctypep);
}

/* e<index type><name>:<value>,(...) */
CTYPEP	BReadCTypeEnum(char **ptr,CTYPEP ctypep,DBXINFP inf)
{
	short	nbits;
	ulong	nb,symnb,*tabnb,otabnb;
	char	*lookc,*name;
	CSYMP	csymp,**tab;
	CTYPE_FIELDP	fieldp;

	tab=&(CSymFileMem.tab);
	tabnb=&CSymFileNb;
	otabnb=*tabnb;
	symnb=0L;
	while ((**ptr) && (**ptr!=';') && (**ptr!=',')) {
		DBX_CONT(ptr);
		lookc=strchr(*ptr,':');
		name=AllocCName(*ptr,lookc-*ptr+1);
		*ptr=lookc+1;
		nb=BReadCNb(ptr,',',&nbits);
		if (nbits)
			return(NULL);
		csymp=AllocCSym(*ptr);
		csymp->name=name;
		csymp->class=CLASS_CONST;
		csymp->scope=inf->scope;
		csymp->value.i=nb;
		AddCSym(&CSymFileMem,tabnb,csymp);
		symnb++;
	}
	if (**ptr==';')
		(*ptr)++;
	ctypep->size=sizeof(int);
	ctypep->code=CTYPEC_ENUM;
	ctypep->flags&=~CTYPEF_STUB;
	ctypep->fieldsnb=symnb;
	fieldp=AllocCTypeField(symnb);
	ctypep->fields=fieldp;
	for (nb=0L;nb<symnb;nb++,fieldp++) {
		csymp=(*tab)[otabnb+nb];
		csymp->type=ctypep;
		fieldp->name=csymp->name;
		*(ulong *)&(fieldp->type)=0L;
		fieldp->bitpos=csymp->value.i;
		fieldp->bitsize=0L;
	}
	return(ctypep);
}

#define	MAX_OF_TYPE(t)	((1L<<(sizeof(t)-1L))-1L)
#define	MIN_OF_TYPE(t)	(-(1L<<(sizeof(t)-1L)))

CTYPEP	BReadCTypeRange(char **ptr,long typenums[2],DBXINFP inf)
{
	short	self,lbits,ubits;
	long	rangenums[2],lower,upper;
	CTYPEP	result;
	char	*debug_ptr=*ptr;

	BReadCTypeNb(ptr,rangenums);
	self=((rangenums[0]==typenums[0]) && (rangenums[1]==typenums[1]));

	if (**ptr==';')
		(*ptr)++;
	lower=BReadCNb(ptr,';',&lbits);
	upper=BReadCNb(ptr,';',&ubits);

	if ((lbits==-1) || (ubits==-1))
		return(NULL);

	if ((self) && (lower==0L) && (upper==0L))
		return(ctype_void);
	if ((upper==0L) && (lower>0L)) {
		if (lower==sizeof(float))
			return(ctype_float);
		return(ctype_double);
	}
	if ((lower==0L) && (upper==-1L))
		return(ctype_ulong);
	if ((lower==-32768L) && (upper==32767L) && (typenums[1]==1L))	/* -mshort */
		return(ctype_short);
	if ((self) && (lower==0L) && (upper==127L))
		return(ctype_char);
	if (lower==0L) {
		if (upper<0L)
			return(ctype_ushort);
		if (upper==0xff)
			return(ctype_uchar);
		if (upper==0xffff)
			return(ctype_ushort);
	}
	else
	if ((upper==0L) && (lower<0L) && ((self) || (lower==-sizeof(long long))))
		return(ctype_longlong);
	else
	if (lower==-upper-1L) {
		if (upper==0x7fL)
			return(ctype_char);
		if (upper==0x7fffL)
			return(ctype_short);
		if (upper==0x7fffffffL)
			return(ctype_long);
	}
	if (self)
		PRINTF("(Self subrange type)");
	result=AllocCType(NULL);
	result->target=(self?ctype_int:*GetCType(rangenums));
	if ((lower>=MIN_OF_TYPE(char)) && (upper<=MAX_OF_TYPE(char)))
		result->size=1;
	else
	if ((lower>=MIN_OF_TYPE(short)) && (upper<=MAX_OF_TYPE(short)))
		result->size=sizeof(short);
	else
/*	if ((lower>=MIN_OF_TYPE(int)) && (upper<=MAX_OF_TYPE(int)))
		result->size=sizeof(int);
	else*/
	if ((lower>=MIN_OF_TYPE(long)) && (upper<=MAX_OF_TYPE(long)))
		result->size=sizeof(long);
	else
		PRINTF("(Ranged type %s doesn't fit within known sizes)\n",debug_ptr);
	result->size=result->target->size;
	result->code=CTYPEC_RANGE;
	result->fieldsnb=2;
	result->fields=AllocCTypeField(2);
	result->fields[0].bitpos=lower;
	result->fields[1].bitpos=upper;
	return(result);
}

long	BReadCNb(char **ptr,char c,short *bits)
{
	char	d;
	short	over=0,nbits=0;
	long	radix=10L,sign=1L,res=0L;
	ulong	limit;

	if (**ptr=='-') {
		sign=-1L;
		(*ptr)++;
	}
	if (**ptr=='0') {
		radix=8L;
		(*ptr)++;
	}
	limit=-1L;
	while (((d=*(*ptr)++)>='0') && (d<('0'+radix))) {
		if (res<=limit) {
			res*=radix;
			res+=d-'0';
		}
		else
			over=1;
		if (radix==8) {
			if (nbits==0) {
				switch (d) {
					case '0':
					break;
					case '1':
						nbits=1;
					break;
					case '2': case '3':
						nbits=2;
					break;
					default:
						nbits=3;
					break;
				}
			}
			else
				nbits+=3;
		}
	}
	if (c) {
		if ((d) && (d!=c)) {
			PRINTF("(`%c' expected after number, found `%c', in BReadCNb)\n",c,d);
			if (bits)
				*bits=-1;
			return(0);
		}
	}
	else
		(*ptr)--;
	if (over) {
		if (nbits==0) {
			if (bits)
				*bits=-1;
			return(0);
		}
		if (sign==-1)
			nbits++;
		if (bits)
			*bits=nbits;
		return(0);
	}
	if (bits)
		*bits=0;
	return(res*sign);
}

short	BReadCTypeNb(char **ptr,long *typenums)
{
	short	nbits;

	if (**ptr=='(') {
		(*ptr)++;
		typenums[0]=BReadCNb(ptr,',',&nbits);
		typenums[1]=BReadCNb(ptr,')',&nbits);
	}
	else {
		typenums[0]=0;
		typenums[1]=BReadCNb(ptr,0,&nbits);
	}
	return(0);
}

CTYPEP	BReadCType(char **ptr,DBXINFP inf)
{
	long	typenums[2],xtypenums[2];
	CTYPEP	ctypep=NULL,ctypep1;

	if ((isdigit(**ptr)) || ((**ptr)=='(') || ((**ptr)=='-')) {
		if (BReadCTypeNb(ptr,typenums))
			return(NULL);
		if ((**ptr)!='=') {
			return(AllocCType(typenums));
		}
		/* + */
		(*ptr)+=2;
	}
	else {
		typenums[0]=-1L;
		typenums[1]=-1L;
		(*ptr)++;
	}
	switch ((*ptr)[-1]) {
		case 'x': {
			CTYPE_CODE	code;
			char	*prename,*name,*lookc;

			switch (**ptr) {
				case 's':
					code=CTYPEC_STRUCT;
					prename="struct ";
				break;
				case 'u':
					code=CTYPEC_UNION;
					prename="union ";
				break;
				default:
					PRINTF("(unknown x modifier %c)",**ptr);
				case 'e':
					code=CTYPEC_ENUM;
					prename="enum ";
				break;
			}
			lookc=strchr(*ptr,':');
			if ((name=MALLOC(strlen(prename)+lookc-*ptr+1))==NULL) {
				PRINTF("(memory error while allocating name %s)",*ptr);
				return(NULL);
			}
			strcpy(name,prename);
			strncpy(name+strlen(prename),*ptr,lookc-*ptr+1);
			name[strlen(prename)+lookc-*ptr]=0;
			*ptr=lookc+1;
			/* + */
			ctypep=AllocCType(typenums);
			ctypep->code=code;
			ctypep->tag=name;
			ctypep->flags|=CTYPEF_STUB;
			/* + */
		}
 		break;
		case '0': case '1': case '2': case '3': case '4':
		case '5': case '6': case '7': case '8': case '9':
		case '(': case '-':
			(*ptr)--;
			if (BReadCTypeNb(ptr,xtypenums))
				return(NULL);
			if ((typenums[0]==xtypenums[0]) && (typenums[0]==xtypenums[0]))
				ctypep=ctype_void;
			else {
				if ((ctypep=*GetCType(xtypenums))==NULL)
					ctypep=ctype_void;
			}
			if (typenums[0]!=-1L)
				*GetCType(typenums)=ctypep;
		break;
		case '*': case '&':	/* ptr */
			ctypep1=BReadCType(ptr,inf);
			ctypep=GetCTypePtr(ctypep1);
			if (typenums[0]!=-1)
				*GetCType(typenums)=ctypep;
		break;
		case 'f':	/* function */
			ctypep1=BReadCType(ptr,inf);
			ctypep=GetCTypeFct(ctypep1);
			if (typenums[0]!=-1)
				*GetCType(typenums)=ctypep;
		break;
		case 'r':	/* range */
			ctypep=BReadCTypeRange(ptr,typenums,inf);
			if (typenums[0]!=-1)
				*GetCType(typenums)=ctypep;
		break;
		case 'e':	/* enum */
			ctypep=AllocCType(typenums);
			ctypep=BReadCTypeEnum(ptr,ctypep,inf);
			*GetCType(typenums)=ctypep;
		break;
		case 's':	/* struct */
			ctypep=AllocCType(typenums);
			ctypep=BReadCTypeStruct(ptr,ctypep,inf);
		break;
		case 'u':	/* union */
			ctypep=AllocCType(typenums);
			ctypep=BReadCTypeStruct(ptr,ctypep,inf);
			ctypep->code=CTYPEC_UNION;
		break;
		case 'a':	/* array */
			if ((*(*ptr)++)!='r')
				PRINTF("(`r' expected after `a' in BReadCType)\n");
			ctypep=AllocCType(typenums);
			ctypep=BReadCTypeArray(ptr,ctypep,inf);
		break;
		default:
			PRINTF("(`%s':Invalid type-code)\n",*ptr-1);
		break;
	}
	return(ctypep);
}

ulong	BMakeCType(DBXINFP inf)
{
	short	deftype,synflag;
	ulong	strsz,stroff;
	CSYMP	csymp;
	char	*strs,*str,*tmp;
	BSD_SYM	*sym;

	sym=inf->csym;
	strs=inf->strs;
	strsz=inf->strsz;
	stroff=getil(sym->strx)-4L;
	if (stroff<strsz) {
		str=&(strs[stroff]);
		if (*str==0)
			return(0);
/*		PRINTF("%s:\n",str);*/
#ifdef BDEBUG
		if (!strncmp(str,BreakSym,BRKSYMLEN))
			Illegal();
#endif
		if ((tmp=strchr(str,':'))!=NULL) {
			if ((csymp=AllocCSym(str))==NULL)
				return(-1);
			if ((csymp->name=AllocCName(str,tmp-str+1))==NULL) {
				FREE(csymp);
				return(-1);
			}
			csymp->scope=inf->scope;
			tmp++;
			if ((isdigit(*tmp)) || (*tmp=='(') || (*tmp=='-'))
				deftype='l';
			else
				deftype=*tmp++;
/*
			if ((deftype=='T') && (*tmp=='t')) {
				deftype='t';
				tmp++;
			}
*/
			switch (deftype) {
				case 'c':
					if (*tmp++!='=')
						PRINTF("(%s: Invalid c-code)\n",str);
					switch (*tmp++) {
						case 'r':	/* SYMBOL:c=rVALUE */
						{
							double	d=STRTOD(tmp,NULL);
							char	*value;

							csymp->type=ctype_double;
							if ((value=MALLOC(sizeof(double)))==NULL) {
								PERROR("%s:(%s:Memory error (value))\n",PrgName,str);
								return(-1);
							}
							memmove(value,&d,sizeof(double));
							csymp->value.p=value;
							csymp->class=CLASS_CONST_BYTES;
						}
						break;
						case 'i':	/* SYMBOL:c=iVALUE */
							csymp->type=ctype_int;
							csymp->value.i=atoi(tmp);
							csymp->class=CLASS_CONST;
						break;
						case 'e':	/* SYMBOL:c=eTYPE,INTVALUE */
						{
							long	typenums[2];

							BReadCTypeNb(&tmp,typenums);
							if (*tmp++!=',')
								PRINTF("(`,' expected in enum const symbol)\n");
							csymp->type=ctype_int;
/*							cstmp->type=*GetCType(typenums); */
							csymp->value.i=atoi(tmp);
							csymp->class=CLASS_CONST;
						}
						break;
						default:
							PRINTF("(%s:Invalid c-code)\n",str);
						break;
					}
					AddCSym(&CSymFileMem,&CSymFileNb,csymp);
				return(1);
				case 'C':	/* caught exception */
					if ((csymp->type=BReadCType(&tmp,inf))==NULL)
						return(-1);
					csymp->class=CLASS_LOCAL;
					csymp->value.i=sym->value;
					AddCSym(&CSymLoclMem,&CSymLoclNb,csymp);
				case 'f':	/* file symbol */
					if ((csymp->type=BReadCType(&tmp,inf))==NULL)
						return(-1);
					csymp->class=CLASS_BLOCK;
					AddCSym(&CSymFileMem,&CSymFileNb,csymp);
					/* + func */
					/* + proto */
				break;
				case 'F':	/* global symbol */
					if ((csymp->type=BReadCType(&tmp,inf))==NULL)
						return(-1);
					csymp->class=CLASS_BLOCK;
					AddCSym(&CSymGlblMem,&CSymGlblNb,csymp);
				break;
				case 'G':	/* global symbol */
					if ((csymp->type=BReadCType(&tmp,inf))==NULL)
						return(-1);
					csymp->class=CLASS_STATIC;
					csymp->value.i=sym->value;
					/* + look into linker symbols fo value */
					AddCSym(&CSymGlblMem,&CSymGlblNb,csymp);
				break;
				case 's': case 'l':	/* faked local symbol */
					if ((csymp->type=BReadCType(&tmp,inf))==NULL)
						return(-1);
					csymp->class=CLASS_LOCAL;
					csymp->value.i=sym->value;
					AddCSym(&CSymLoclMem,&CSymLoclNb,csymp);
				break;
				case 'p':	/* stacked parameter */
					/* pF for Fortran */
					if ((csymp->type=BReadCType(&tmp,inf))==NULL)
						return(-1);
					csymp->class=CLASS_ARG;
					csymp->value.i=sym->value;	/* stack offset */
					AddCSym(&CSymLoclMem,&CSymLoclNb,csymp);
				break;
				case 'P':	/* register parameter */
					if (sym->type==N_FUN) {	/* function prototype */
						if ((csymp->type=BReadCType(&tmp,inf))==NULL)
							return(-1);
						break;
					}
				case 'R':	/* register parameter */
					if ((csymp->type=BReadCType(&tmp,inf))==NULL)
						return(-1);
					csymp->class=CLASS_REGPARM;
					csymp->value.i=sym->value;	/* reg nb */
					AddCSym(&CSymLoclMem,&CSymLoclNb,csymp);
				break;
				case 'r':	/* register local */
					if ((csymp->type=BReadCType(&tmp,inf))==NULL)
						return(-1);
					csymp->class=CLASS_REG;
					csymp->value.i=sym->value;	/* reg nb */
					AddCSym(&CSymLoclMem,&CSymLoclNb,csymp);
				break;
				case 'S':	/* static to file symbol */
					if ((csymp->type=BReadCType(&tmp,inf))==NULL)
						return(-1);
					csymp->class=CLASS_STATIC;
					csymp->value.i=sym->value;
					AddCSym(&CSymFileMem,&CSymFileNb,csymp);
				break;
				case 't':	/* typedef */
					if ((csymp->type=BReadCType(&tmp,inf))==NULL)
						return(-1);
					csymp->class=CLASS_TYPEDEF;
					csymp->value.i=sym->value;
					if (((csymp->type->name)==NULL) && ((csymp->type->flags&CTYPEF_PERM)==0))
						csymp->type->name=AllocCName(csymp->name,strlen(csymp->name)+1);
					AddCSym(&CSymFileMem,&CSymFileNb,csymp);
				break;
				case 'T':	/* typedef struct/union/enum */
					synflag=(*tmp=='t');
					if (synflag) {
						tmp++;
/*						synname=AllocCName(csymp->name,strlen(csymp->name)+1);*/
					}
					if ((csymp->type=BReadCType(&tmp,inf))==NULL)
						return(-1);
					csymp->class=CLASS_TYPEDEF;
					csymp->value.i=sym->value;
					if (csymp->type->tag==NULL)
						csymp->type->tag=AllocCName(csymp->name,strlen(csymp->name)+1);
					AddCSym(&CSymFileMem,&CSymFileNb,csymp);
					if (synflag) {
						CSYMP	tsym=AllocCSym(tmp);
						*tsym=*csymp;
						tsym->class=CLASS_TYPEDEF;
						tsym->value.i=csymp->value.i;
						if (csymp->type->name==NULL)
							csymp->type->name=AllocCName(csymp->name,strlen(csymp->name)+1);
						AddCSym(&CSymFileMem,&CSymFileNb,tsym);
					}
				break;
				case 'V':	/* static symbol in local scope */
					if ((csymp->type=BReadCType(&tmp,inf))==NULL)
						return(-1);
					csymp->class=CLASS_STATIC;
					csymp->value.i=sym->value;
					AddCSym(&CSymLoclMem,&CSymLoclNb,csymp);
				break;
				case 'v':	/* reference parameter */
					if ((csymp->type=BReadCType(&tmp,inf))==NULL)
						return(-1);
					csymp->class=CLASS_REF_ARG;
					csymp->value.i=sym->value;
					AddCSym(&CSymLoclMem,&CSymLoclNb,csymp);
				break;
				default:
					PRINTF("(%s:Invalid type-code)\n",str);
				break;
			}
		}
		else
			PRINTF("(%s:????)\n",str);
	}
	else
		PRINTF("(%#lX)\n",stroff);

	return(1);
}

int InitBsdTypes(void)
{
	int i;

	CTypeUnsigned[sizeof(unsigned char)]="uchar";
	CTypeUnsigned[sizeof(unsigned short)]="ushort";
	CTypeUnsigned[sizeof(unsigned long)]="ulong";
	CTypeUnsigned[sizeof(unsigned int)]="uint";

	CTypeSigned[sizeof(char)]="char";
	CTypeSigned[sizeof(short)]="short";
	CTypeSigned[sizeof(long)]="long";
	CTypeSigned[sizeof(int)]="int";

	CTypeFloat[sizeof(float)]="float";
	CTypeFloat[sizeof(double)]="double";

	i=0;
	*IntrnTypes[i++]=InitCType(CTYPEC_INT,sizeof(char),0,"char");
	*IntrnTypes[i++]=InitCType(CTYPEC_INT,sizeof(short),0,"short");
	*IntrnTypes[i++]=InitCType(CTYPEC_INT,sizeof(int),0,"int");
	*IntrnTypes[i++]=InitCType(CTYPEC_INT,sizeof(long),0,"long");
	*IntrnTypes[i++]=InitCType(CTYPEC_INT,sizeof(long long),0,"llong");
	*IntrnTypes[i++]=InitCType(CTYPEC_INT,sizeof(uchar),1,"uchar");
	*IntrnTypes[i++]=InitCType(CTYPEC_INT,sizeof(ushort),1,"ushort");
	*IntrnTypes[i++]=InitCType(CTYPEC_INT,sizeof(unsigned int),1,"uint");
	*IntrnTypes[i++]=InitCType(CTYPEC_INT,sizeof(ulong),1,"ulong");
	*IntrnTypes[i++]=InitCType(CTYPEC_INT,sizeof(unsigned long long),0,"ullong");
	*IntrnTypes[i++]=InitCType(CTYPEC_FLT,sizeof(float),0,"float");
	*IntrnTypes[i++]=InitCType(CTYPEC_FLT,sizeof(double),0,"double");
	*IntrnTypes[i++]=InitCType(CTYPEC_VOID,0,0,"void");
	*IntrnTypes[i++]=InitCType(CTYPEC_FLT,sizeof(long double),0,"long double");

	while (--i>=0)
		if (!*IntrnTypes[i])
			return 0;
	return 1;
} /* InitBsdTypes() */


/* offset -> ligne de source + smallblk */
ulong CBsdGetSource(ulong off,struct smallblk *info)
{
	struct LineEntry *le;
	ulong i,j;
	ulong prev,nbl;

	for (i=0;i<NbMods;i++) {
		nbl=ModTab[i].nbl;
		if (nbl==0) continue;
		le=ModTab[i].lines;
		if (nbl==1) {
			if (ModTab[i].lines->pc==off) {
				info->mod=ModTab+i;
				info->blkstrt=le->pc;
				info->blksz=0;	/* ? */
				return le->line;
			}
			else
				continue;
		}
		if (le) {	/* toujours vrai ? */
			for (j=1,prev=(le++)->pc;j<nbl;j++,le++) {
				if (prev<=off && le->pc>off) {
					info->mod=ModTab+i;
					info->blkstrt=prev;
					info->blksz=le->pc-prev;
					return (le-1)->line;
				}
				prev=le->pc;
			}
			/* cas special du dernier */
			if ((--le)->pc==off) {
				info->mod=ModTab+i;
				info->blkstrt=off;
				/* a voir: la fin du dernier module est connue comme la
				valeur du dernier symbole N_TEXT */
				info->blksz=ModTab[i].scope->end-off;
				return le->line;
			}
		}
	}
	return 0;
}

int AllocModNames()
{
	int i,ret=1;
	struct Module *mod=ModTab;
	char *p,buf[256],*name;

	for (i=0;i<NbMods;i++,mod++) {
		if (mod->dirname) {
			strcpy(buf,mod->dirname);
		}
		else
			*buf=0;
		strcat(buf,mod->name);
#ifdef __AMIGA__
		/* gnu->amigados - remplacer /vol/xxx par vol:xxx */
		if (*buf==DIR_SEP) {
			for (p=buf+1;*p && *p!=DIR_SEP;p++);
			if (*p)
				*p=VOL_SEP;
			name=buf+1;
		}
		else
			name=buf;
#else
		name=buf;
#endif
		p=(char*)MALLOC(strlen(name)+1);
		if (!p)
			ret=0;
		else {
			strcpy(p,name);
		}
		mod->dirname=NULL;
		mod->name=p;
	}
	return ret;
}

char *CBsdGetSrcName(struct Module *mod)
{
	return mod->name;
}

/* renvoie l'offset de la ligne line */
ulong CBsdGetCodeAddr(ulong line,struct Module *mod)
{
	ulong i;
	struct LineEntry *le;

	le=mod->lines;
	if (le) {
		for (i=0;i<mod->nbl;i++,le++)
			if (le->line==line)
				return le->pc;
	}
	return -1;
}

struct Module *CBsdGetMod(int n)
{
	return ModTab+n;
}

/* retourne le scope courant le + interieur */
struct scope *CBsdGetCurScope(ulong pc)
{
	int i,j=-1;
	short lvl;

	for (i=0;i<NbScopes;i++) {
		if (pc>=ScopeTab[i].start && pc<ScopeTab[i].end) {
			j=i;	/* scope possible */
			lvl=ScopeTab[i].level;
		}
		else
			if (j>=0 && ScopeTab[i].level<=lvl)
				return (CurScope=&ScopeTab[j]);
	}
	if (j>=0)
		return (CurScope=&ScopeTab[j]);
	else
		return (CurScope=NULL);
}

/* ds les globales; juste pour test */
CSYMP CBsdFindVar(char *name)
{
	ulong i;
	CSYMP *symtab=CSymGlblMem.tab;
	extern CBsdPrintVar(CSYMP,char*,int,int);

	for (i=0;i<CSymGlblNb;i++,symtab++)
		if (!strcmp((*symtab)->name,name)) {
/*			sprintf(name,"0x%lx",*symtab);*/
			CBsdPrintVar(*symtab,name,100,0);
			return *symtab;
		}
	strcpy(name,"0");
	return NULL;
}

/* patche les CSYM globaux avec les valeurs des linker-symbols correspondants
* pareil pour les statiques (a voir: les statiques de meme nom)
*  stocke les infos necessaires a l'evaluateur:
*	@d0_buf(a6) -> HardRegs
*	frameptr(a6) -> FramePtr (a voir)
*  retourne le nbre de globales patchees
*/
int CBsdUpdateGlobals(CSYMP **table,ulong *regs)
{
	int i;
	CSYMP *tab=CSymGlblMem.tab,s;

	HardRegs=regs; FramePtr=8+5;	/* a5: a voir (prefs) */
#ifdef ADEBUG
	for (i=0;i<CSymGlblNb;i++,tab++) {
		(*tab)->value.i=AdbgFindVar((*tab)->name);
	}
	tab=CSymFileMem.tab;
	for (i=0;i<CSymFileNb;i++,tab++) {
		s=*tab;
		if (s->class==CLASS_STATIC)
			s->value.i=AdbgFindVar(s->name);
	}
	*table=CSymGlblMem.tab;
#endif
	return CSymGlblNb;
}

CSYMP *CBsdAllocStatics(void)
{
	if (MaxStaticSyms)
		StaticsTab=(CSYMP*)Reserve(MaxStaticSyms*sizeof(CSYMP));
	return StaticsTab;
}

CSYMP *CBsdAllocLocals(void)
{
	if (MaxLocSyms)
		LocsTab=(CSYMP*)Reserve(MaxLocSyms*sizeof(CSYMP));
	return LocsTab;
}

#define RECORD \
do { \
	*(curtab++)=sym; \
	prevsym=sym; \
	cnt++; \
} while(0)

static int BuildVarsArray(SCOPE *scope,CSYMP **table,
		CSYMP *curtab,CSYMP *alltab,ulong tabnb,int securnb)
{
	int i,j,cnt=0,args=0;
	CSYMP sym,prevsym;
	CSYMP *tab;

	if (!curtab || !scope) {
		*table=NULL;
		return 0;
	}
	*table=tab=curtab;
	for (i=0;i<tabnb && cnt<securnb;i++,alltab++) {
		sym=*alltab;
		if (IN_SCOPE(sym->scope,scope) && sym->class!=CLASS_TYPEDEF &&
				sym->class!=CLASS_CONST) {
			if (sym->class==CLASS_ARG) {
				args++;
				RECORD;
			}
			else {
				/* si un symbole REG cache le meme symbole en ARG, eliminer
				   le symbole ARG */
				if (sym->class==CLASS_REG && args>0) {
					for (j=0;j<args;j++) {
						if (tab[j]->class==CLASS_ARG &&
								tab[j]->scope==sym->scope &&
								!strcmp(tab[j]->name,sym->name)) {
							tab[j]=sym;
							break;
						}
					}
					if (j==args)
						RECORD;
				}
				else {
					RECORD;
				}
			}
		}
	}
	if (!cnt)
		*table=NULL;
	return cnt;
}

/* retourne un scope particulier a partir du scope le + interieur */
static SCOPE *GetScope(SCOPE *locscop,short lvl)
{
	if (locscop->level<lvl)
		return NULL;
	while (locscop>=ScopeTab && locscop->level>lvl)
		locscop--;
	return locscop>=ScopeTab?locscop:NULL;
}

int CBsdBuildLocalsArray(SCOPE *scope,CSYMP **table)
{
	locals_nb=BuildVarsArray(GETFUNCSCOPE(scope),table,LocsTab,
		CSymLoclMem.tab,CSymLoclNb,MaxLocSyms);
	return locals_nb;
}

int CBsdBuildStaticsArray(SCOPE *scope,CSYMP **table)
{
	statics_nb=BuildVarsArray(GETFILESCOPE(scope),table,StaticsTab,
		CSymFileMem.tab,CSymFileNb,MaxStaticSyms);
	return statics_nb;
}

/* debut d'un scope: N_LBRAC et debut de module */
static void UpCtxt(int *level,int *idx,int *IdxLvlTab,ulong value)
{
	if (*level<MAX_BRACK_LEVEL) {
		ScopeTab[*idx].start=value;
		ScopeTab[*idx].level=*level;
		IdxLvlTab[(*level)++]=(*idx)++;
	}
	else
		WARN("max nested lexical contexts reached");
}

/* fin d'un scope: N_RBRAC et fin de module */
static void DownCtxt(int *level,int *IdxLvlTab,ulong value)
{
	if (*level>0 && *level<MAX_BRACK_LEVEL) {
		ScopeTab[IdxLvlTab[--(*level)]].end=value;
	}
	else
		WARN("skipping spurious end of lexical context");
}

int CGetBsdDebug(int symsz,BSD_SYM *symtbl,int strsz,char *strtbl)
{
	BSD_SYM *syms=symtbl,*sym;
	uchar prev_type=0;
	char *dir,lastc;
	int nbsyms=symsz/sizeof(BSD_SYM),nbsyms1,nbmods,i,err;
	int curmod,Lbrack=0,Rbrack=0,BrackLev=0,BrackIdx=0;
	int IdxLvlTab[MAX_BRACK_LEVEL];
	struct Module mods[MAX_MODS];
	struct LineEntry *lines,*le;
	ulong ModCurOffs,last_offs;
	int LocSyms=0,StaticSyms=0,NbFuncs=0;
	DBXINF	dbxinf;

	TotNbl=MaxLocSyms=MaxStaticSyms=0;
	nbsyms1=nbsyms; nbmods=0; curmod=0;
	/* 1ere passe: compter le nbre de modules et d'infos ligne */
	while (nbsyms--) {
		switch(syms->type) {
		case N_SO:
			lastc=*(strtbl+getil(syms->strx)+strlen(strtbl+getil(syms->strx))-1);
			if (prev_type==N_SO || lastc!=DIR_SEP) {
				ADD_MODULE(prev_type==N_SO?dir:NULL);
				END_SYMS(LocSyms,MaxLocSyms);
				END_SYMS(StaticSyms,MaxStaticSyms);
			}
			else
				dir=strtbl+getil(syms->strx);	/* juste le repertoire */
			break;
		case N_SOL:
			if ((i=nbmods)==0)
				return 0;	/* include avant le 1er module ! */
			while (i>=0 && strcmp(mods[i].name,strtbl+getil(syms->strx))) i--;
			if (i<0) {
				/* si ca commence par DIR_SEP, c'est un nom complet
				   donc pas de dirname separe */
				ADD_MODULE(*(strtbl+getil(syms->strx))==DIR_SEP?NULL:dir);
			}
			else
				curmod=i;
			break;
		case N_SLINE:
			if (!nbmods)
				return 0;
			mods[curmod].nbl++;
			TotNbl++;
			break;
		case N_LBRAC:
			Lbrack++;
			break;
		case N_RBRAC:
			Rbrack++;
			break;
		case N_GSYM:
			/*MaxGloSyms++;*/
			break;
		case N_FUN:
			/*MaxGloSyms++;*/
			NbFuncs++;
			END_SYMS(LocSyms,MaxLocSyms);
			break;
		case N_RSYM:
		case N_LSYM:
		case N_SSYM:
		case N_PSYM:
			LocSyms++;
			break;
		case N_STSYM:
			StaticSyms++;
			break;
		default:
			break;
		}
		prev_type=syms->type;
		syms++;
	}
	END_SYMS(StaticSyms,MaxStaticSyms);
	END_SYMS(LocSyms,MaxLocSyms);

	/* allouer les lignes, modules, scopes, symboles */
	NbMods = nbmods;
	if (TotNbl)
		LineTab=lines=(struct LineEntry*)Reserve(TotNbl*sizeof(struct LineEntry));
	ModTab=(struct Module*)Reserve(NbMods*sizeof(struct Module));
	if (Lbrack!=Rbrack)
		WARN("unbalanced lexical contexts");
	NbScopes=MAX(Lbrack,Rbrack)+NbMods+NbFuncs;
	ScopeTab=(struct scope*)Reserve(NbScopes*sizeof(struct scope));
/*	if (MaxGloSyms)
		GlosTab=(CSYMP*)Reserve(MaxGloSyms*sizeof(CSYMP));*/

	if ((!lines && TotNbl) || !ModTab || !ScopeTab) {
		FreeBsdInfos();
		return 0;
	}
	memcpy(ModTab,mods,NbMods*sizeof(struct Module));

	/* affecter les structs LineEntry a leurs modules */
	le=lines;
	for (i=0;i<NbMods;i++) {
		ModTab[i].lines=ModTab[i].curline=le;
		le += ModTab[i].nbl;
	}
	
	if (!AllocModNames() || !InitBsdTypes()) {
		FreeBsdInfos();
		return 0;
	}

	/* 2eme passe: stocker */
	syms=symtbl; curmod=0;
	dbxinf.syms=syms;
	dbxinf.csym=syms;
	dbxinf.snb=nbsyms1;
	dbxinf.strs=strtbl+4;
	dbxinf.strsz=strsz;
	BrackLev=BrackIdx=0;
	while (dbxinf.csym<&(dbxinf.syms[dbxinf.snb])) {
		sym=dbxinf.csym;
		switch(sym->type) {
		case N_SO:
			if (prev_type==N_SO ||
			  *(strtbl+getil(sym->strx)+strlen(strtbl+getil(sym->strx))-1)!=DIR_SEP) {
				if (curmod) { /* fermer le module precedent */
					while (BrackLev>0) {
						DownCtxt(&BrackLev,IdxLvlTab,sym->value);
					}
					ModTab[curmod-1].ttab=CTypeTab;
					ModTab[curmod-1].tnb=CTypeNb;
					CTypeTab=NULL; CTypeNb=0; PTypeCurSz=0;
				}
				ModTab[curmod].binoffs=ModCurOffs=sym->value;
				UpCtxt(&BrackLev,&BrackIdx,IdxLvlTab,sym->value);
				ModTab[curmod].scope=&ScopeTab[BrackIdx-1];
				curmod++;
			}
			break;
		case N_SOL:
			i=curmod-1;
			while (i>=0 && strcmp(ModTab[i].name,strtbl+getil(sym->strx))) i--;
			if (i<0) {	/* #include */
				curmod++;
				UpCtxt(&BrackLev,&BrackIdx,IdxLvlTab,getil(sym->value));
			}
			else { /* fin d'include */
				curmod=i+1;
				DownCtxt(&BrackLev,IdxLvlTab,getil(sym->value)+ModCurOffs);
			}
			break;
		case N_SLINE:
			ModTab[curmod-1].curline->line=sym->desc;
			last_offs=ModTab[curmod-1].curline->pc=getil(sym->value);
			ModTab[curmod-1].curline++;
			break;
		case N_LBRAC:
			UpCtxt(&BrackLev,&BrackIdx,IdxLvlTab,getil(sym->value)+ModCurOffs);
			break;
		case N_RBRAC:
			DownCtxt(&BrackLev,IdxLvlTab,getil(sym->value)+ModCurOffs);
			break;
		case N_FUN:
			while (BrackLev>1) {
				DownCtxt(&BrackLev,IdxLvlTab,getil(sym->value));
			}
			UpCtxt(&BrackLev,&BrackIdx,IdxLvlTab,getil(sym->value));
			dbxinf.scope=&ScopeTab[BrackIdx-1];
			goto make_it;
			break;
		case N_GSYM:
			dbxinf.scope=NULL;	/* a voir: fonction statique */
			goto make_it;
		case N_STSYM:
			dbxinf.scope=ModTab[curmod-1].scope;
			goto make_it;
		case N_RSYM:
		case N_LSYM:
		case N_SSYM:
		case N_PSYM:
			dbxinf.scope=&ScopeTab[BrackIdx-1];
		make_it:
			if ((err=BMakeCType(&dbxinf))<0) {
				FreeBsdInfos();
				return 0;
			}
			break;
		case N_TEXT:
		case N_TEXT|N_EXT:
			last_offs=getil(sym->value);
			break;
		/* a voir */
		case N_FN:
		case N_DSLINE:
		case N_BSLINE:
		case N_ASLINE:
		case N_ENTRY:
		case N_NSYMS:
		default:
			break;
		}
		prev_type=sym->type;
		dbxinf.csym++;
	}
	/* fermer le dernier module */
	if (curmod) {
		while (BrackLev>0)
			DownCtxt(&BrackLev,IdxLvlTab,last_offs);
		ModTab[curmod-1].ttab=CTypeTab;
		ModTab[curmod-1].tnb=CTypeNb;
	}
	return NbMods;
}

CSYMP BsdFindVar(char *name)
{
	CSYMP *table;
	ulong nb;

	table=LocsTab;
	for (nb=0;nb<locals_nb;nb++,table++) {
		if (!strcmp((*table)->name,name))
			return *table;
	}
	table=StaticsTab;
	for (nb=0;nb<statics_nb;nb++,table++) {
		if (!strcmp((*table)->name,name))
			return *table;
	}
	table=CSymGlblMem.tab;
	for (nb=0;nb<CSymGlblNb;nb++,table++) {
		if (!strcmp((*table)->name,name))
			return *table;
	}
	return NULL;
}
