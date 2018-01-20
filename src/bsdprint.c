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
/* bsdprint.c - affichage des types et variables BSD */

#include "bsdincl.h"
#include <stdarg.h>

#define MPRINTF MemPrint
#define MDPRINTF(str,val) PrintIdx+=DSPRINTF(PrintBuf+PrintIdx,str,val)
#define PRINTINDENT(i)
#define EOPRTBUF (PrintIdx>PrintCols)

/* le nbre de caracteres du nom dans l'affichage des globales,
   un espace obligatoire compris */
#define NAME_FIELDLEN 10

extern CTYPEP ctype_char,ctype_short,ctype_int,ctype_long,ctype_longlong;
extern CTYPEP ctype_uchar,ctype_ushort,ctype_uint,ctype_ulong,ctype_ulonglong;
extern CTYPEP ctype_float,ctype_double,ctype_void;
extern char	*CTypeUnsigned[(sizeof(unsigned long)+1)*sizeof(void *)];
extern char	*CTypeSigned[(sizeof(long)+1)*sizeof(void *)];
extern char	*CTypeFloat[(sizeof(double)+1)*sizeof(void *)];

short	DispCType(CTYPEP type,char *name,short show,short level);
void BsdPrintElt(CTYPEP t,char *addr,short class);
char *BsdGetSymValAddr(CSYMP s);

static int PrintIdx;
static int PrintCols;
static char *PrintBuf;

int MemPrint(char *fmt,...)
{
	va_list argp;
	int len;
#if 0
	char c,*p=fmt;

	/* remplace les '\n' par ' 'dans le format */
	while ((c=*p++))
		if (c=='\n')
			*(p-1)=' ';
#endif
	va_start(argp,fmt);
	PrintIdx+=len=vsprintf(PrintBuf+PrintIdx,fmt,argp);
	va_end(argp);
	return len;
}

void	PrintIndent(short nb)
{
	while (nb--)
		MPRINTF("\t");
}

short	DispCTypeBase(CTYPEP type,short show,short level)
{
	short	i;
	long	gap;
	ulong	lastval;
	char	*name;
	CTYPE_FIELDP	field;

	if (type==NULL) {
		MPRINTF("(NULL type)");
		return(0);
	}
	if ((type->name) && (show<=0)) {
		MPRINTF("%s",type->name);
		return(1);
	}
	/* + stub */
	switch (type->code) {
		case CTYPEC_UNDEF:
			MPRINTF("struct <unknown>");
		break;
		case CTYPEC_ERROR:
			MPRINTF("<unknown type>");
		break;
		case CTYPEC_RANGE:
			MPRINTF("<range type>");
		break;
		case CTYPEC_ARRAY: case CTYPEC_PTR: case CTYPEC_FUNC:
		case CTYPEC_MEMBER: case CTYPEC_REF: case CTYPEC_METHOD:
			DispCTypeBase(type->target,show,level);
		break;
		case CTYPEC_STRUCT:
			MPRINTF("struct ");
			goto	as_union;
		case CTYPEC_UNION:
			MPRINTF("union ");
as_union:	if (type->tag) {
				MPRINTF("%s",type->tag);
				if (show>0)
					MPRINTF(" ");
			}
			if (show<0) {
				if (type->tag==NULL)
					MPRINTF("{...}");
			}
			else {
				if ((show>0) || (type->tag==NULL)) {
					MPRINTF("{");
					field=type->fields;
					for (i=0;i<type->fieldsnb;i++,field++) {
						PRINTINDENT(level+1);
						if (field->bitsize) {
							gap=field->bitpos-(i>0?((field-1)->bitpos+((field-1)->bitsize?(field-1)->bitsize:(field-1)->type->size*8)):0);
/*							if (gap) {
								MPRINTF("(gap: %ld bits);\n",gap);
								PRINTINDENT(level+1);
							}
*/
						}
						DispCType(field->type,field->name,show-1,level+1);
						if (field->bitsize)
							MPRINTF(":%ld",field->bitsize);
						MPRINTF(";");
					}
					PRINTINDENT(level);
					MPRINTF("}");
				}
			}
		break;
		case CTYPEC_ENUM:
			MPRINTF("enum ");
			if (type->tag) {
				MPRINTF("%s",type->tag);
				if (show>0)
					MPRINTF(" ");
			}
			if (show<0) {
				if (type->tag==NULL)
					MPRINTF("{...}");
			}
			else {
				if ((show>0) || (type->tag==NULL)) {
					MPRINTF("{");
					field=type->fields;
					lastval=0L;
					for (i=0;i<type->fieldsnb;i++,field++) {
						if (i)
							MPRINTF(",");
						MPRINTF("%s",field->name);
						if (lastval!=field->bitpos) {
							MPRINTF("=%ld",field->bitpos);
							lastval=field->bitpos;
						}
						lastval++;
					}
					MPRINTF("}");
				}
			}
		break;
		case CTYPEC_INT:
			if ((type->flags)&CTYPEF_UNSIGNED)
				name=CTypeUnsigned[type->size];
			else
				name=CTypeSigned[type->size];
			MPRINTF("%s",name);
		break;
		case CTYPEC_FLT:
			MPRINTF("%s",CTypeFloat[type->size]);
		break;
		case CTYPEC_VOID:
			MPRINTF("void");
		break;
		default:
			MPRINTF("Invalid type-code");
		break;
	}
	return(1);
}

short	DispCTypePrefix(CTYPEP type,short show,short ptrflag)
{
	if (type==NULL) {
		MPRINTF("(NULL type)");
		return(0);
	}
	if ((type->name) && (show<=0))
		return(1);
	if (type->flags&CTYPEF_STUB)
		MPRINTF("(STUB)");
	switch (type->code) {
		case CTYPEC_PTR:
			DispCTypePrefix(type->target,0,1);
			MPRINTF("*");
		break;
		case CTYPEC_FUNC:	case CTYPEC_ARRAY:	case CTYPEC_PASCAL_ARRAY:
			DispCTypePrefix(type->target,0,0);
			if (ptrflag)
				MPRINTF("(");
		break;
		case CTYPEC_UNDEF:	case CTYPEC_STRUCT:	case CTYPEC_UNION:
		case CTYPEC_ENUM:	case CTYPEC_INT:	case CTYPEC_FLT:
		case CTYPEC_VOID:	case CTYPEC_SET:	case CTYPEC_RANGE:
		case CTYPEC_ERROR:	case CTYPEC_MEMBER:	case CTYPEC_METHOD:
		case CTYPEC_REF:	case CTYPEC_CHAR:	case CTYPEC_BOOL:
		break;
	}
	return(1);
}

short	DispCTypeSuffix(CTYPEP type,short show,short ptrflag)
{
	if (type==NULL) {
		MPRINTF("(NULL type)");
		return(0);
	}
	if ((type->name) && (show<=0))
		return(1);
	switch (type->code) {
		case CTYPEC_ARRAY: case CTYPEC_PASCAL_ARRAY:
			if (ptrflag)
				MPRINTF(")");
			MPRINTF("[");
			if ((type->size>0L) && (type->target->size>0L))
				MPRINTF("%ld",type->size/type->target->size);
			MPRINTF("]");
			DispCTypeSuffix(type->target,0,0);
		break;
		case CTYPEC_PTR: case CTYPEC_REF:
			DispCTypeSuffix(type->target,0,1);
		break;
		case CTYPEC_FUNC:
			if (ptrflag)
				MPRINTF(")");
			MPRINTF("()");
			DispCTypeSuffix(type->target,0,ptrflag);
		break;
		default:
			/*MPRINTF("(Sizeof:%ld)",type->size);*/
		break;
	}
	return(1);
}

short	DispCType(CTYPEP type,char *name,short show,short level)
{
	CTYPE_CODE	code;

	if (type) {
		DispCTypeBase(type,show,level);
		code=type->code;
		if (((name) && (*name)) || (((show>0) || (type->name==NULL))
			&& ((code==CTYPEC_PTR) || (code==CTYPEC_FUNC) || (code==CTYPEC_ARRAY)
			|| (code==CTYPEC_METHOD) || (code==CTYPEC_MEMBER) || (code==CTYPEC_REF))))
			MPRINTF(" ");
		DispCTypePrefix(type,show,0);
		if (name)
			MPRINTF("%s",name);
		DispCTypeSuffix(type,show,0);
	}
	else
		MPRINTF("(NULL type)");
	return(1);
}

/* shift pas reellement utilise pour le moment */
int CBsdPrintVar(CSYMP sym,char *buf,int cols,int shift)
{
	PrintIdx=0; PrintBuf=buf; PrintCols=cols+shift;
/*	buf[NAME_FIELDLEN-1]=' '; buf[NAME_FIELDLEN]='\0';*/
	DispCType(sym->type,sym->name,0,1);
	MPRINTF(sym->class==CLASS_BLOCK?"() = ":" = ");
	BsdPrintElt(sym->type,BsdGetSymValAddr(sym),sym->class);
	return PrintIdx;
}

void BsdPrintEvalRes(char *buf,CTYPEP type,void *addr,short class)
{
	PrintIdx=0; PrintBuf=buf; PrintCols=80;
	BsdPrintElt(type,addr,class);
	MPRINTF(" (");
	DispCType(type,NULL,0,1);
	if (class==CLASS_BLOCK)
		MPRINTF("()");
	MPRINTF(")");
}

char *BsdGetSymValAddr(CSYMP s)
{
	extern short FramePtr;
	extern ulong *HardRegs; /* d0_buf */

	switch(s->class) {
	case CLASS_CONST:
	case CLASS_BLOCK:
	case CLASS_LABEL:
		return (char*)&(s->value.p);
		break;
	case CLASS_REG:
	case CLASS_REGPARM:
		return (char*)(HardRegs+s->value.i);
		break;
	case CLASS_LOCAL:
	case CLASS_ARG:
		return (char*)(HardRegs[FramePtr]+(long)s->value.i);
		break;
	case CLASS_STATIC:
	default:
		return s->value.p;
		break;
	}
}

void BsdPrintStruct(CTYPEP type,char *a,short class)
{
	int i,level;
	CTYPE_FIELDP field;
	char *addr;
	long bitbuf;
	ulong bitp,*fieldaddr;

	level=1;
	MPRINTF("{");
	field=type->fields;
	for (i=0;i<type->fieldsnb && !EOPRTBUF;i++,field++) {
		if (i)
			MPRINTF(",");
		PRINTINDENT(level+1);
		if (field->name)
			MPRINTF("%s=",field->name);
		if (field->bitsize) {
/*			gap=field->bitpos-(i>0?((field-1)->bitpos+((field-1)->bitsize?
					(field-1)->bitsize:(field-1)->type->size*8)):0);
*/
			bitp=field->bitpos&0x1f;
			fieldaddr=(ulong*)(a+((field->bitpos/8)&3));
			if (field->type->flags&CTYPEF_UNSIGNED)
				bitbuf=(*fieldaddr & (-1UL>>bitp)) >>
					(32-bitp-field->bitsize);
			else
				bitbuf=(((long)(*fieldaddr))<<bitp) >>
					(32-field->bitsize);
			addr=(char*)&bitbuf;
		}
		else
			addr=a+((ulong)field->bitpos)/8;

/*		DispCType(field->type,field->name,0,level+1);
*/
		BsdPrintElt(field->type,addr,class);
		if (field->bitsize) {
			MPRINTF(":%ld",field->bitsize);
			if (field->type->flags&CTYPEF_UNSIGNED)
				MPRINTF("U");
		}
	}
	MPRINTF("}");
}

/* voir typedef enum */
void BsdPrintEnum(CTYPEP type,ulong val)
{
	CTYPE_FIELDP field=type->fields;
	ulong lastval=0L;
	int i;

	for (i=0;i<type->fieldsnb;i++,field++) {
/*		if (i)
			MPRINTF(",");*/
		if (val==field->bitpos) {
			MPRINTF("%s",field->name);
			return;
		}
		lastval=field->bitpos+1;
	}
	MPRINTF("%d",val);
}

/* a: adresse de base du tableau */
void BsdPrintArray(CTYPEP type,char *a,short class)
{
	ulong nbe;
	int i;

	if (!type->target) {	/* houla !*/
		MPRINTF("%p",a);
		return;
	}
	MPRINTF("{");
	nbe=type->size/(type->target->size);
	for (i=0;i<nbe && !EOPRTBUF;i++) {
		if (i>0)
			MPRINTF(",");
		BsdPrintElt(type->target,a,class);
		a+=type->target->size;
	}
	MPRINTF("}");
}

void BsdPrintElt(CTYPEP t,char *addr,short class)
{
	int u;	  /* 'unsigned' flag */
	ulong ul; /* ulong tmp buffer */
	char buf[sizeof(long double)]; /* value buffer */

	if (!t) return;
	if (class==CLASS_BLOCK || class==CLASS_LABEL) {
	  MPRINTF("%p",*(long*)addr);
	}
	else {
		switch (t->code) {
		case CTYPEC_ARRAY:
			BsdPrintArray(t,addr,class);
			break;
		case CTYPEC_PTR:
			ul=*(long*)addr;
			if (ul)
				MPRINTF("%p",ul);
			else
				MPRINTF("NULL");
			break;
		case CTYPEC_STRUCT:
		case CTYPEC_UNION:
			BsdPrintStruct(t,addr,class);
			break;
		case CTYPEC_ENUM:
			BsdPrintEnum(t,*(ulong*)addr);
			break;
		case CTYPEC_FUNC:
			MPRINTF("func");
			break;
		case CTYPEC_VOID:
			MPRINTF("void");
			break;
		case CTYPEC_INT:
			u=t->flags & CTYPEF_UNSIGNED;
			switch(t->size) {
			case sizeof(char):	/* a voir: non signe */
				if (isprint(*addr))
					MPRINTF("'%c'",*addr);
				else {
					switch(*addr) {
					case 0: MPRINTF("'\\0'"); break;
					case '\t': MPRINTF("'\\t'"); break;
					case '\n': MPRINTF("'\\n'"); break;
					case '\r': MPRINTF("'\\r'"); break;
					default:
						MPRINTF("'\\x%02.2x'",((int)*addr)&0xff);
						break;
					}
				}
				break;
			case sizeof(short):
				MPRINTF(u?"%hu":"%hd",*(short*)addr);
				break;
			case sizeof(long):
				MPRINTF(u?"%lu":"%ld",*(long*)addr);
				break;
			case sizeof(long long):
				MPRINTF(u?"%llu":"%lld",*(long long*)addr);
				break;
			}
			break;
		case CTYPEC_FLT: /* gerer long double */
			switch(t->size) {
			case sizeof(float):
				MDPRINTF("%lg",(double)(*(float*)addr));
				break;
			case sizeof(double):
				MDPRINTF("%lg",*(double*)addr);
				break;
#ifndef __GNUC__	/* double==long double */
			case sizeof(long double):
				MDPRINTF("%g",(double)(*(long double*)addr));
				break;
#endif
			}
			break;
		default:
			MPRINTF("type %d not supported",t->code);
			break;
		} /* switch(t->code) */
	}
}
