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
/* evfnbsd.c */

#include "bsdeval.h"
#include "bsdgenop.h"

extern OP *StackPtr;

#ifdef TARGET_PUREC
INT GetBitsSVal(INT *addr,RTYPE_PTR t)
{
	return (*addr<<t->t.b.off) >> (INTSIZE-t->t.b.width);
}

UINT GetBitsUVal(UINT *addr,RTYPE_PTR t)
{
	return (*addr & (((UINT)-1)>>t->t.b.off)) >>
	(INTSIZE-t->t.b.off-t->t.b.width);
	return 0;
}
#endif /* TARGET_PUREC */

#ifdef TARGET_GCC
INT BsdGetBitsSVal(INT *addr,CTYPE_FIELDP field)
{
	return (*addr<<(field->bitpos&0x1f)) >> (INTSIZE-field->bitsize);
}

UINT BsdGetBitsUVal(UINT *addr,CTYPE_FIELDP field)
{
	int bitp=field->bitpos&0x1f;

	return (*addr & (-1UL>>bitp)) >> (INTSIZE-bitp-field->bitsize);
	return 0;
}
#endif /* TARGET_GCC */

void BsdPutBitsVal(UINT *addr,UINT v,CTYPE_FIELDP field)
{
	int bitp=field->bitpos&0x1f;
	UINT msk=(-1UL)>>bitp;

	*addr &= (~msk) | (msk>>field->bitsize);
	*addr |= (v<<(INTSIZE-bitp-field->bitsize))&msk;
}

long BsdObjectSize(TYPE_PTR t)
{
	TOPTYPE top;

	if (!t)
		BsdInternalError("ObjectSize():t=NULL");
	top=EXTRACT_TOPTYPE(t);
	if (IS_SCALAR(top))
		return t->size;
	switch(top) {
	case TT_VOID:
	case TT_POINTER:
		return sizeof(void*);
	case TT_ARRAY:
/*		return BsdObjectSize(MK_TYPEPTR(t->target));*/
	case TT_STRUCT:
	case TT_UNION:
	default:
		return t->size;
	}
}

/* dest = @p0, addr = @p1 */
int BsdReadMem(char *dest,char *addr,ulong size)
{
	/* controler la validite de addr, bus error etc. */
/* NEED_FIXING: la taille d'un ptr */
	EVGETMEM(dest,(void*)addr,size);
	return 0;
}

/* addr = @p1 -- src = @p0 */
int BsdWriteMem(char *addr,char *src,ulong size)
{
	/* controler la validite de addr, bus error etc. */
	EVPUTMEM((void*)addr,src,size);
	return 0;
}

/* dst et src pointent ds l'espace p1 */
int BsdCopyMem(char *dst,char *src,ulong size)
{
#ifdef WDB
	char *tmp=(char*)MyMalloc(size);
	int err;
	if (tmp==NULL)
	return EVERR_NO_MEM;
	err = BsdReadMem(tmp,src,size);
	if (!err)
	err = BsdWriteMem(dst,tmp,size);
	MyMfree(tmp,size);
	return err;
#endif
#ifdef ADEBUG
	memcpy(dst,src,size);
	return 0;
#endif
}

int BsdDerefPtr(int afct)
{
	OP *o=StackPtr;
	int err=0;
	TOPTYPE top=GET_TOPTYPE(o);

	if (top!=TT_POINTER && top!=TT_ARRAY)
		return EVERR_TYPE_MISMATCH;
	o->type=*(MK_TYPEPTR(o->type.target));
	o->addr=(void*)(*(ulong*)o->buf);
	top=EXTRACT_TOPTYPE(&o->type);
	SET_TOPTYPE(o,top);
	if ((IS_SCALAR(top) || top==TT_POINTER)) {
		o->val=&o->buf;
		if (afct)
			err=BsdReadMem(o->buf,o->addr,o->type.size);
	}
	else
		o->val=o->addr;
	if (IS_SCALAR(top) || top==TT_STRUCT || top==TT_UNION || top==TT_POINTER)
		o->class=C_LVALUE;
	else
		o->class=0;
	return err;
}

int BsdRefPtr()
{
	OP *o=StackPtr;
	TYPE_PTR nt;
	TOPTYPE top=GET_TOPTYPE(o);

	if (o->class!=C_LVALUE && top!=TT_FUNC && top!=TT_ARRAY)
		return EVERR_LVALUE_REQ;
	if (o->sym->class==CLASS_REG || o->sym->class==CLASS_REGPARM || top==TT_BIT)
		return EVERR_NO_ADDR;
	nt=BsdAllocType();
	if (!nt)
		return EVERR_NO_MEM;
	*(MK_TYPEPTR(nt))=o->type;
	o->class=0;
	o->val=&o->buf;
	o->bsize=DEF_BSIZE;
	*(ulong*)o->buf=(ulong)o->addr; /* (ulong)GetObjAddr(o->sym,o->type.size); */
	o->sym=NULL;
	o->type.target=nt;
	o->type.name=NULL;
	o->type.code=CTYPEC_PTR;
	o->type.size=sizeof(void*);
	SET_TOPTYPE(o,TT_POINTER);
	return 0;
}

int BsdDoAffect(int afct)
{
	OP *b=StackPtr,*op=StackPtr->link;
	TOPTYPE optop,btop;
	int err=0,u;

	if (op->class!=C_LVALUE)
		return EVERR_LVALUE_REQ;

	optop=GET_TOPTYPE(op);
	btop=GET_TOPTYPE(b);
	if (IS_SCALAR(optop) && IS_SCALAR(btop) && afct) {
	/* affecte la valeur ds la struct operande */
		switch(optop) {
		case TT_CHAR:
			*(char*)op->buf=BsdGetChar(b);
			break;
		case TT_UCHAR:
			*(uchar*)op->buf=BsdGetUChar(b);
			break;
		case TT_SHORT:
			*(short*)op->buf=BsdGetShort(b);
			break;
		case TT_USHORT:
			*(ushort*)op->buf=BsdGetUShort(b);
			break;
		case TT_ENUM:
		case TT_INT:
			*(INT*)op->buf=BsdGetInt(b);
			break;
		case TT_UINT:
			*(UINT*)op->buf=BsdGetUInt(b);
			break;
		case TT_LONG:
			*(long*)op->buf=BsdGetLong(b);
			break;
		case TT_ULONG:
			*(ulong*)op->buf=BsdGetULong(b);
			break;
		case TT_FLOAT:
			*(float*)op->buf=BsdGetFloat(b);
			break;
		case TT_DOUBLE:
			*(double*)op->buf=BsdGetDouble(b);
			break;
		case TT_LDOUBLE:
			*(long double*)op->buf=BsdGetLDouble(b);
			break;
		case TT_BIT:
			if ((u=op->field->type->flags&CTYPEF_UNSIGNED)) /*(op->modifier!=TT_INT)*/
				*(UINT*)op->buf=BsdGetInt(b);
			else
				*(INT*)op->buf=BsdGetInt(b);
			break;
		}
	/* affecte la valeur en memoire ou registre */
		if (optop!=TT_BIT) {
		if (IS_REG_OP(op))
		SET_REGISTER(op->sym->value.i,op->buf,op->type.size);
		else {
#ifdef ENDIAN_REVERSE
		char tmp[MAX_SCALAR_SIZEOF];
		memcpy(tmp,op->buf,op->type.size);
		ENDIAN_REVERSE(tmp,op->type.size);
		err=BsdWriteMem(op->addr,tmp,op->type.size); /* BsdObjectSize(&op->type) */
#else
			err=BsdWriteMem(op->addr,op->buf,op->type.size); /* BsdObjectSize(&op->type) */
#endif
		}
	}
		else {
		if (op->field)
		u=op->field->type->flags&CTYPEF_UNSIGNED;
		else
		u=0;
		BsdPutBitsVal(op->addr,u?BsdGetUInt(b):BsdGetInt(b),op->field);
	}
	}
	else {
		if (optop==TT_POINTER && IS_INT(btop) && BsdGetLong(b)==0L) {
			/* mettre le 0 a la taille du pointeur */
			*(long*)op->buf=0L;
		}
		else {
			if (!BsdEqTypes(&op->type,&b->type))
				return EVERR_TYPE_MISMATCH;
		}
		if (afct) {
			*(long double*)op->buf=*(long double*)b->buf;
#ifdef ENDIAN_REVERSE
		if (IS_SCALAR(btop))
		ENDIAN_REVERSE(b->buf,b->type.size);
#endif
			err = BsdCopyMem(op->addr,b->val,BsdObjectSize(&op->type));
		}
		op->bsize=b->bsize;
		op->val=op->addr;
	}
	op->sym=NULL;
	BsdPopOp();
	return err;
}

char BsdGetChar(OP *o)
{
	char r;
	GENGETBUF(o,r);
	return r;
} /* BsdGetChar() */

uchar BsdGetUChar(OP *o)
{
	uchar r;
	GENGETBUF(o,r);
	return r;
} /* BsdGetUChar() */

short BsdGetShort(OP *o)
{
	short r;
	GENGETBUF(o,r);
	return r;
} /* BsdGetShort() */

ushort BsdGetUShort(OP *o)
{
	unsigned short r;
	GENGETBUF(o,r);
	return r;
} /* BsdGetUShort() */

INT BsdGetInt(OP *o)
{
	INT r;
	GENGETBUF(o,r);
	return r;
} /* BsdGetInt() */

UINT BsdGetUInt(OP *o)
{
	UINT r;
	GENGETBUF(o,r);
	return r;
} /* BsdGetUInt() */

long BsdGetLong(OP *o)
{
	long r;
	GENGETBUF(o,r);
	return r;
} /* BsdGetLong() */

ulong BsdGetULong(OP *o)
{
	ulong r;
	GENGETBUF(o,r);
	return r;
} /* BsdGetULong() */

float BsdGetFloat(OP *o)
{
	float r;
	GENGETBUF(o,r);
	return r;
} /* BsdGetFloat() */

double BsdGetDouble(OP *o)
{
	double r;
	GENGETBUF(o,r);
	return r;
} /* BsdGetDouble() */

long double BsdGetLDouble(OP *o)
{
	long double r;
	GENGETBUF(o,r);
	return r;
} /* BsdGetLDouble() */

void BsdIntPromote(OP *o)
{
	TOPTYPE top;
	switch(GET_TOPTYPE(o)) {
	case TT_CHAR:
	case TT_UCHAR:
	case TT_SHORT:
#ifndef INT16
	case TT_USHORT:
#endif
		*(INT*)o->buf=BsdGetInt(o);
		SET_ITYPE(o,TT_INT);
		SET_TOPTYPE(o,TT_INT);
		break;
#ifdef INT16
	case TT_USHORT:
		SET_ITYPE(o,TT_INT);	/* NEED_FIXING */
		SET_TOPTYPE(o,TT_INT);
		break;
#endif
	case TT_BIT:
		/* o->buf est deja en INT ou UINT */
#ifdef TARGET_PUREC
		o->type.top=o->type.modifier;
		/* SET_TOPTYPE(o,o->type->modifier) ? */
#endif
#ifdef TARGET_GCC
	if (o->field)
		top=o->field->type->flags&CTYPEF_UNSIGNED?TT_UINT:TT_INT;
	else
		top=TT_INT;
		SET_ITYPE(o,top);
		SET_TOPTYPE(o,top);
#endif
		break;
	}
}

/* convertit les 2 operandes scalaires en pile au type
* le plus fort des deux - fait la promotion entiere
*/
void BsdUsualTypeConvert(void)
{
	OP *m,*n;
	/* m operande de type superieur ou egal a celui de n */
	if (GET_TOPTYPE(StackPtr)>GET_TOPTYPE(StackPtr->link)) {
		n=StackPtr->link;
		m=StackPtr;
	}
	else {
		m=StackPtr->link;
		n=StackPtr;
	}
	switch (GET_TOPTYPE(m)) {
	case TT_LDOUBLE:
		*(long double*)n->buf=BsdGetLDouble(n);
		SET_TOPTYPE(n,TT_LDOUBLE);
		SET_ITYPE(n,TT_LDOUBLE);
		break;
	case TT_DOUBLE:
		*(double*)n->buf=BsdGetDouble(n);
		SET_TOPTYPE(n,TT_DOUBLE);
		SET_ITYPE(n,TT_DOUBLE);
		break;
	case TT_FLOAT:
		*(float*)n->buf=BsdGetFloat(n);
		SET_TOPTYPE(n,TT_FLOAT);
		SET_ITYPE(n,TT_FLOAT);
		break;
	default:
		BsdIntPromote(n);
		BsdIntPromote(m);
		if (GET_TOPTYPE(m)==TT_ULONG) {
			*(ulong*)n->buf=BsdGetULong(n);
			SET_TOPTYPE(n,TT_ULONG);
			SET_ITYPE(n,TT_ULONG);
		}
		if (GET_TOPTYPE(m)==TT_LONG) {
			if (GET_TOPTYPE(n)==TT_UINT) {
#ifdef INT16
				*(long*)n->buf=BsdGetLong(n);
				SET_TOPTYPE(n,TT_LONG);
				SET_ITYPE(n,TT_ULONG);
#else
				*(ulong*)n->buf=BsdGetULong(n);
				SET_TOPTYPE(n,TT_ULONG);
				SET_ITYPE(n,TT_ULONG);
				*(ulong*)m->buf=BsdGetULong(m);
				SET_TOPTYPE(m,TT_ULONG);
				SET_ITYPE(m,TT_ULONG);
#endif
			}
			else {
				*(long*)n->buf=BsdGetLong(n);
				SET_TOPTYPE(n,TT_LONG);
				SET_ITYPE(n,TT_LONG);
			}
		}
		else {
			if (GET_TOPTYPE(m)==TT_UINT) {
				*(UINT*)n->buf=BsdGetUInt(n);
				SET_TOPTYPE(n,TT_UINT);
				SET_ITYPE(n,TT_UINT);
			}
		}
	}
} /* UsualTypeConvert() */

int BsdDoSftRight(void)
{
	OP *b=StackPtr,*a=StackPtr->link;
	INT count;

	BsdIntPromote(a); BsdIntPromote(b);
	if (!IS_INT(GET_TOPTYPE(a)) || !IS_INT(GET_TOPTYPE(b)))
		return EVERR_INTT_REQ;
	count=BsdGetInt(b);
	switch(GET_TOPTYPE(a)) {
		GEN_INT_BOPC(a->buf,>>,count,a->buf)
	}
	a->class &= b->class&C_CONST;
	BsdPopOp();
	return 0;
} /* DoSftRight() */

int BsdDoXor(void)
{
	OP *b=StackPtr,*a=StackPtr->link;

	BsdUsualTypeConvert();
	if (!(IS_INT(GET_TOPTYPE(a)) && IS_INT(GET_TOPTYPE(b))))
		return EVERR_INTT_REQ;
	switch(GET_TOPTYPE(a)) {
		GEN_INT_BOP(a->buf,^,b,a->buf)
	}
	a->class &= b->class&C_CONST;
	BsdPopOp();
	return 0;
} /* DoXor() */

int BsdCheckCmpTypes(void)
{
	int err=0;
	OP *a=StackPtr->link,*b=StackPtr;

	if (IS_SCALAR(GET_TOPTYPE(a)) && IS_SCALAR(GET_TOPTYPE(b)))
		BsdUsualTypeConvert();
	else {
		switch(GET_TOPTYPE(a)) {
		case TT_FLOAT:
		case TT_DOUBLE:
		case TT_LDOUBLE:
			err=EVERR_CANT_CMP; /* b est non scalaire */
			break;
		case TT_VOID:
			err=EVERR_VOID_USED;
			break;
		case TT_POINTER:
			if (!( IS_INT(GET_TOPTYPE(b)) && (b->class&C_CONST) && BsdGetLong(b)==0L )) {
				if (!BsdEqTypes(&a->type,&b->type))
					err=EVERR_CANT_CMP;
			}
			break;
		case TT_STRUCT:
		case TT_UNION:
			if (!BsdEqTypes(&a->type,&b->type))
				err=EVERR_CANT_CMP;
			break;
		default: /* a entier,b pas entier */
			if (!( (a->class&C_CONST) &&	BsdGetLong(a)==0L && GET_TOPTYPE(b)==TT_POINTER ))
				err=EVERR_CANT_CMP;
		}
	}
	return err;
} /* CheckCmpTypes() */

int BsdDoEq(void)
{
	int err;
	OP *b=StackPtr,*a=StackPtr->link;

	err=BsdCheckCmpTypes(); /* fait aussi la conversion usuelle */
	if (!err) {
		switch(GET_TOPTYPE(a)) {
			GEN_CMP_OP(a->buf,a,==,b);
		}
	}
	SET_ITYPE(a,TT_INT);
	SET_TOPTYPE(a,TT_INT);
	/* a voir: liberation du type */
	a->class &= b->class&C_CONST;
	BsdPopOp();
	return err;
} /* DoEq() */

int BsdDoLt(void)
{
	int err;
	OP *b=StackPtr,*a=StackPtr->link;

	err=BsdCheckCmpTypes(); /* fait aussi la conversion usuelle */
	if (!err) {
		switch(GET_TOPTYPE(a)) {
			GEN_CMP_OP(a->buf,a,<,b);
		}
	}
	SET_ITYPE(a,TT_INT);
	SET_TOPTYPE(a,TT_INT);
	/* a voir: liberation du type */
	a->class &= b->class&C_CONST;
	BsdPopOp();
	return err;
} /* DoLt() */

int BsdDoGt(void)
{
	int err;
	OP *b=StackPtr,*a=StackPtr->link;

	err=BsdCheckCmpTypes(); /* fait aussi la conversion usuelle */
	if (!err) {
		switch(GET_TOPTYPE(a)) {
			GEN_CMP_OP(a->buf,a,>,b);
		}
	}
	SET_ITYPE(a,TT_INT);
	SET_TOPTYPE(a,TT_INT);
	/* a voir: liberation du type */
	a->class &= b->class&C_CONST;
	BsdPopOp();
	return err;
} /* DoGt() */

int BsdDoNe(void)
{
	int err=BsdDoEq();
	if (!err)
		*(INT*)StackPtr->buf=!*(INT*)StackPtr->buf;
	return err;
}

int BsdDoLe(void)
{
	int err=BsdDoGt();
	if (!err)
		*(INT*)StackPtr->buf=!*(INT*)StackPtr->buf;
	return err;
} /* DoLe() */

int BsdDoGe(void)
{
	int err=BsdDoLt();
	if (!err)
		*(INT*)StackPtr->buf=!*(INT*)StackPtr->buf;
	return err;
} /* DoGe() */

int BsdDoAnd(void)
{
	OP *b=StackPtr,*a=StackPtr->link;

	BsdUsualTypeConvert();
	if (!IS_INT(GET_TOPTYPE(a)) || !IS_INT(GET_TOPTYPE(b)))
		return EVERR_INTT_REQ;
	switch(GET_TOPTYPE(a)) {
		GEN_INT_BOP(a->buf,&,b,a->buf)
	}
	a->class &= b->class & C_CONST;
	BsdPopOp();
	return 0;
} /* DoAnd() */

int BsdDoOr(void)
{
	OP *b=StackPtr,*a=StackPtr->link;

	BsdUsualTypeConvert();
	if (!IS_INT(GET_TOPTYPE(a)) || !IS_INT(GET_TOPTYPE(b)))
		return EVERR_INTT_REQ;
	switch(GET_TOPTYPE(a)) {
		GEN_INT_BOP(a->buf,|,b,a->buf)
	}
	a->class &= b->class & C_CONST;
	BsdPopOp();
	return 0;
} /* DoOr() */

int BsdDoCmpAnd(void)
{
	OP *b=StackPtr,*a=StackPtr->link;
	if (!(IS_SCALAR(GET_TOPTYPE(b)) || GET_TOPTYPE(b)==TT_POINTER))
		return EVERR_TYPE_MISMATCH;
	SET_ITYPE(a,TT_INT);
	SET_TOPTYPE(a,TT_INT);
	a->class &= b->class & C_CONST;
	*(INT*)a->buf=(BsdGetLong(a) && BsdGetLong(b));
	BsdPopOp();
	return 0;
} /* DoCmpAnd() */

int BsdDoCmpOr(void)
{
	OP *b=StackPtr,*a=StackPtr->link;

	if (!(IS_SCALAR(GET_TOPTYPE(b)) || GET_TOPTYPE(b)==TT_POINTER))
		return EVERR_TYPE_MISMATCH;
	SET_ITYPE(a,TT_INT);
	SET_TOPTYPE(a,TT_INT);
	a->class &= b->class & C_CONST;
	*(INT*)a->buf=(BsdGetLong(a) || BsdGetLong(b));
	BsdPopOp();
	return 0;
} /* DoCmpOr() */

int BsdDoDiv(int afct)
{
	OP *b=StackPtr,*a=StackPtr->link;

	if (IS_SCALAR(GET_TOPTYPE(a)) && IS_SCALAR(GET_TOPTYPE(b)))
		BsdUsualTypeConvert();
	else
		return (GET_TOPTYPE(a)==TT_VOID && GET_TOPTYPE(b)==TT_VOID)?
			 EVERR_VOID_USED:EVERR_TYPE_MISMATCH;

	if (BsdGetLong(b)==0L)
		return EVERR_ZERO_DIVIDE;

	if (afct) {
		switch(GET_TOPTYPE(a)) {
			GEN_INT_BOP(a->buf,/,b,a->buf)
			GEN_FLOAT_BOP(a->buf,/,b,a->buf);
		}
	}
	a->class &= b->class & C_CONST;
	BsdPopOp();
	return 0;
} /* DoDiv() */

int BsdDoSftLeft(void)
{
	OP *b=StackPtr,*a=StackPtr->link;
	INT count;

	BsdIntPromote(a); BsdIntPromote(b);
	if (!IS_INT(GET_TOPTYPE(a)) || !IS_INT(GET_TOPTYPE(b)))
		return EVERR_INTT_REQ;
	count=BsdGetInt(b);
	switch(GET_TOPTYPE(a)) {
		GEN_INT_BOPC(a->buf,<<,count,a->buf)
	}
	a->class &= b->class & C_CONST;
	BsdPopOp();
	return 0;
} /* DoSftLeft() */

/* met le resultat dans StackPtr->link (=p)*/
int BsdPointerAdd(OP *p,OP *a)
{
	int err=0;
	long adder;

	if (IS_INT(GET_TOPTYPE(a))) { /* NEED_FIXING (type->target) */
		adder = BsdGetLong(a) * BsdObjectSize(MK_TYPEPTR(p->type.target));
		*(ulong*)StackPtr->link->buf = (*(ulong*)p->buf) + adder;
		(ulong)StackPtr->link->addr += adder;
	}
	else {
		err=EVERR_TYPE_MISMATCH;
	}
	return err;
}

/* p pointeur, met le resultat dans StackPtr->link (=a) */
int BsdPointerSub(OP *p,OP *a)
{
	long adder;
	OP *o=StackPtr->link;
	TOPTYPE atop=GET_TOPTYPE(a);

	if (!IS_INT(atop)) {
		if (atop!=TT_POINTER && atop!=TT_ARRAY)
			return EVERR_TYPE_MISMATCH;
		/* ptrp-ptra */
		if (!BsdEqTypes(&p->type,&a->type))
			return EVERR_TYPE_MISMATCH;
		*(long*)o->buf=(BsdGetLong(p)-BsdGetLong(a))/BsdObjectSize(MK_TYPEPTR
			(p->type.target)); /* NEED_FIXING */
		SET_ITYPE(o,TT_LONG);
		SET_TOPTYPE(o,TT_LONG);
		/* a voir: FreeType ? */
	}
	else {	/* NEED_FIXING */
		adder = BsdGetLong(a) * BsdObjectSize(MK_TYPEPTR(p->type.target));
		*o=*p;
		*(ulong*)o->buf = BsdGetULong(p) - adder;
		(ulong)o->addr -= adder;
	}
	return 0;
}

int BsdDoPlus(void)
{
	OP *b=StackPtr,*a=StackPtr->link;
	int err=0;
	void *res;

	if (IS_SCALAR(GET_TOPTYPE(a)) && IS_SCALAR(GET_TOPTYPE(b)))
		BsdUsualTypeConvert();

	/* a operande de type superieur ou egal a celui de b */
	if (GET_TOPTYPE(StackPtr)>GET_TOPTYPE(StackPtr->link)) {
		b=StackPtr->link;
		a=StackPtr;
	}
	else {
		a=StackPtr->link;
		b=StackPtr;
	}
	res=StackPtr->link->buf;
	switch(GET_TOPTYPE(a)) {
	GEN_INT_BOP(a->buf,+,b,res)
	GEN_FLOAT_BOP(a->buf,+,b,res)
	case TT_VOID:
		err = EVERR_VOID_USED;
		break;
	case TT_POINTER:
	case TT_ARRAY:
		err = BsdPointerAdd(a,b);
		break;
	case TT_FUNC:
	case TT_UNION:
	case TT_STRUCT:
		err = EVERR_TYPE_MISMATCH;
		break;
	}
	StackPtr->link->class = a->class & b->class & C_CONST;
	BsdPopOp();
	return err;
} /* DoPlus() */

int BsdDoUMinus(void)
{
	OP *a=StackPtr;
	int err=0;

	switch(GET_TOPTYPE(a)) {
	GEN_INT_UOP(-,a->buf,a->buf)
	GEN_FLOAT_UOP(-,a->buf,a->buf)
	case TT_VOID:
		err = EVERR_VOID_USED;
		break;
	case TT_POINTER:
	case TT_FUNC:
	case TT_UNION:
	case TT_STRUCT:
		err = EVERR_TYPE_MISMATCH;
		break;
	}
	a->class &= ~C_LVALUE;
	return err;
} /* DoUMinus() */

int BsdDoMul(void)
{
	OP *b=StackPtr,*a=StackPtr->link;
	void *res;

	if (IS_SCALAR(GET_TOPTYPE(a)) && IS_SCALAR(GET_TOPTYPE(b)))
		BsdUsualTypeConvert();
	else
		return (GET_TOPTYPE(a)==TT_VOID && GET_TOPTYPE(b)==TT_VOID)?
			 EVERR_VOID_USED:EVERR_TYPE_MISMATCH;

	/* a operande de type superieur ou egal a celui de b */
	if (GET_TOPTYPE(StackPtr)>GET_TOPTYPE(StackPtr->link)) {
		b=StackPtr->link;
		a=StackPtr;
	}
	else {
		a=StackPtr->link;
		b=StackPtr;
	}
	res=StackPtr->link->buf;
	switch(GET_TOPTYPE(a)) {
		GEN_INT_BOP(a->buf,*,b,res)
		GEN_FLOAT_BOP(a->buf,*,b,res);
	}
	StackPtr->link->class = a->class & b->class & C_CONST;
	BsdPopOp();
	return 0;
} /* DoMul() */

int BsdDoModulo(int afct)
{
	OP *b=StackPtr,*a=StackPtr->link;

	BsdUsualTypeConvert();
	if (!(IS_INT(GET_TOPTYPE(a)) && IS_INT(GET_TOPTYPE(b))))
		return EVERR_INTT_REQ;

	if (afct && BsdGetLong(b)==0L)
		return EVERR_ZERO_DIVIDE;

	if (afct) {
		switch(GET_TOPTYPE(a)) {
			GEN_INT_BOP(a->buf,%,b,a->buf)
		}
	}
	StackPtr->link->class = a->class & b->class & C_CONST;
	BsdPopOp();
	return 0;
} /* DoModulo() */

int BsdDoBinaryNot(void)
{
	BsdIntPromote(StackPtr);
	if (!IS_INT(GET_TOPTYPE(StackPtr)))
		return EVERR_INTT_REQ;
	switch(GET_TOPTYPE(StackPtr)) {
		GEN_INT_UOP(~,StackPtr->buf,StackPtr->buf)
	}
	StackPtr->class &= ~C_LVALUE;
	return 0;
} /* DoBinaryNot() */

int BsdDoLogicalNot(void)
{
	OP *a=StackPtr;

	BsdIntPromote(a);
	if (!IS_INT(GET_TOPTYPE(a)))
		return EVERR_TYPE_MISMATCH;
	*(INT*)a->buf=!BsdGetInt(a);
	a->class &= ~C_LVALUE;
	return 0;
} /* DoLogicalNot() */

int BsdDoMinus(void)
{
	OP *b=StackPtr,*a=StackPtr->link;
	int err=0;
	void *res;
	TOPTYPE btop;

	if (IS_SCALAR(GET_TOPTYPE(a)) && IS_SCALAR(GET_TOPTYPE(b)))
		BsdUsualTypeConvert();
	else {
		btop=GET_TOPTYPE(b);
		if (!IS_INT(btop)) {
			if (btop!=TT_POINTER && btop!=TT_ARRAY) {
				return btop==TT_VOID?EVERR_VOID_USED:EVERR_TYPE_MISMATCH;
			}
			else {
				/* si b est un ptr, a doit etre un ptr aussi */
				if (GET_TOPTYPE(a)!=TT_POINTER && GET_TOPTYPE(a)!=TT_ARRAY)
					return EVERR_TYPE_MISMATCH;
			}
		}
	}
	res=StackPtr->link->buf;
	switch(GET_TOPTYPE(a)) {
		GEN_INT_BOP(a->buf,-,b,res)
		GEN_FLOAT_BOP(a->buf,-,b,res)
	case TT_VOID:
		err = EVERR_VOID_USED;
		break;
	case TT_POINTER:
	case TT_ARRAY:
		err = BsdPointerSub(a,b);
		break;
	case TT_FUNC:
	case TT_UNION:
	case TT_STRUCT:
		err = EVERR_TYPE_MISMATCH;
		break;
	}
	BsdPopOp();
	StackPtr->class = a->class & b->class & C_CONST;
	return err;
} /* DoMinus() */

int BsdPushInt(INT val)
{
	OP one;

	SET_ITYPE(&one,TT_INT);
	SET_TOPTYPE(&one,TT_INT);
	one.class=C_CONST;
	one.val=one.buf;
	*(INT*)one.buf=val;
	one.bsize=DEF_BSIZE;
	one.sym=NULL;
	one.addr=NULL;
	return BsdPushOp(&one);
}

int BsdDoIncr(int afct)
{
	int err=BsdPushOp(StackPtr); /* dupliquer l'element */
	if (!err) {
		err=BsdPushInt(1);
		if (!err)
			err=BsdDoPlus();
	}
	return err?err:BsdDoAffect(afct);
}

int BsdDoDecr(int afct)
{
	int err=BsdPushOp(StackPtr); /* dupliquer l'element */
	if (!err) {
		err=BsdPushInt(1);
		if (!err)
			err=BsdDoMinus();
	}
	return err?err:BsdDoAffect(afct);
}

int BsdDoSizeof(void)
{
	INT s=StackPtr->type.size;	/* NEED_FIXING */
	BsdPopOp();
	return BsdPushInt(s);
}

