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
#include "bsdeval.h"

extern OP *StackPtr;
extern uchar *evp,iscsym[256];

#ifdef TARGET_PURE_C
extern TYPE_STRUCT htypes[TT_LDOUBLE-TT_CHAR+1];
extern char *DSTypesText[];
#endif

#ifdef TARGET_GCC
extern CTYPEP *IntrnTypes[];
#endif
int BsdDoStruct(char *start,int len,int afct)
{
  char c=start[len];
  OP *o=StackPtr;
  CTYPE_FIELDP member;
  int i,nb;
  TOPTYPE top;

  if (GET_TOPTYPE(o)!=TT_STRUCT && GET_TOPTYPE(o)!=TT_UNION)
    return EVERR_STRUCT_REQ;
  start[len]='\0';
  member=o->type.fields;
  nb=o->type.fieldsnb;
  for (i=0;i<nb;i++) {
    if (!strcmp(start,MK_NAMEPTR(member->name))) {
      o->sym=NULL;
      /* a voir: si la taille de l'objet est grande */
      o->val=&o->buf;
      o->bsize=DEF_BSIZE;
      o->type=*(MK_TYPEPTR(member->type));
      o->field=member;
      if (member->bitsize) {
        top=TT_BIT;
        /* pour y acceder en long l'esprit tranquille... */
        o->addr = ((char*)o->addr)+((member->bitpos/8)&3);
      }
      else {
        top=EXTRACT_TOPTYPE(&o->type);
        o->addr = ((char*)o->addr)+(member->bitpos)/8;
      }
      SET_TOPTYPE(o,top);
      if (IS_SCALAR(top) || top==TT_POINTER) {
        if (top!=TT_BIT) {
          if (afct)
            memcpy(o->val,o->addr,BsdObjectSize(&o->type));
        }
        else {
#ifdef TARGET_PUREC
          o->type.modifier=(MK_TYPEPTR(o->type.t.b.base))->top;
#endif
          if (member->type->flags&CTYPEF_UNSIGNED) /* (o->type.modifier==TT_INT)*/
            *(UINT*)o->buf=BsdGetBitsUVal(o->addr,member);
          else
            *(INT*)o->buf=BsdGetBitsSVal(o->addr,member);
        }
      }
      else {
        *(ulong*)o->val=(ulong)o->addr;
      }
      /* toto.titi est une lvalue si toto est une lvalue et titi pas un
         tableau */
      if (top==TT_ARRAY)
        o->class &= ~C_LVALUE;
      break; /* du for */
    }
    member++;
  }
  start[len]=c;
  return i<nb?0:EVERR_MEMB_NF;
}

int BsdDoPStruct(char *start,int len,int afct)
{
  OP *o=StackPtr;
  TOPTYPE top;

  if (GET_TOPTYPE(o)!=TT_POINTER || !(MK_TYPEPTR(o->type.target)))
    return EVERR_PSTRUCT_REQ;
  top=EXTRACT_TOPTYPE(MK_TYPEPTR(o->type.target));
  if (top!=TT_STRUCT &&	top!=TT_UNION)
    return EVERR_PSTRUCT_REQ;
  /* a voir: liberation du pointeur */
  o->type = *(MK_TYPEPTR(o->type.target));
  SET_TOPTYPE(o,top);
  o->addr = (void*)(*(ulong*)o->val);
  return BsdDoStruct(start,len,afct);
}

RTYPE_PTR GetStructType(char *name)
{
	return NULL;
}

TYPE_PTR BsdCheckCast(int *err)
{
  TYPE_PTR t=NULL,tt,rt;
  CSYMP *tab;
  int i,ni,locnpar=0,ptr=0;
  uchar *p=evp,name[1024],*efw;

  *err=0;
  /* skipper separateurs apres '(' */
  while (*p==' ' || *p=='\t') p++;
  /* reconnaitre le type */
  ni=0; efw=NULL;
  while (iscsym[*p]) {
    while (iscsym[*p])
      name[ni++]=*p++;
    if (*p==' ' || *p=='\t') {
      name[ni++]=' ';
      efw = name+ni ;
      while (*p==' ' || *p=='\t') p++;
    }
  }
  /* eliminer l'espace eventuel apres le nom du type */
  if (ni>0 && name[ni-1]==' ')
    ni--;
  name[ni]='\0';
  if (efw && efw-name>7 && !strncmp(name,"struct ",7)) {
    t = GetStructType(name);
  }
  else {
    /* chercher le nom d'un type eventuel */
    for (i=0;i<ITYPES_NB && strcmp(ITYPE_NAME(i),name);i++);
    if (i<ITYPES_NB)
      t=GET_ITYPE_BYNUM(i);	/*&htypes[i-1];*/
    else {
      i=0;
      /* cherche un typedef ds les types du module courant */
      tab=CUR_TABFILESYMS;
      while (!t && i<CUR_NBFILESYMS) {
        if ((*tab)->class==CLASS_TYPEDEF && (*tab)->name && !strcmp((*tab)->name,name))
          t=MK_TYPEPTR((*tab)->type);
        else {
          i++; tab++;
        }
      }
    }
  }
  if (t) {
    t=UNMK_TYPEPTR(t);
    while (locnpar>=0) {
      switch(*p) {
      case ' ':
      case '\t':
      	break;
      case '(':
        locnpar++;
        break;
      case ')':
      	locnpar--;
      	break;
      default:
        locnpar=-1;
        *err=EVERR_INVAL_CAST;
        break;
      case '*':
        ptr++;
        break;
      }
      p++;
    }
    if (!*err) {
      evp=p;
      while (ptr && !*err) {
        if ((tt=BsdAllocType())!=NULL) {
          rt=MK_TYPEPTR(tt);
          rt->code=CTYPEC_PTR; /*rt->top=TT_POINTER;*/
          rt->size=sizeof(void*);
          /* rt->sym=NULL;*/
          rt->ptr=rt->fct=NULL;
          rt->name=rt->tag=NULL;
          rt->fields=NULL;
          rt->fieldsnb=0;
          rt->target=t;
          t=tt;
        }
        else
          *err=EVERR_NO_MEM;
        ptr--;
      }
    }
  }
  return t?MK_TYPEPTR(t):NULL;
} /* CheckCast() */

int BsdDoCast(TYPE_PTR t) /* t=nouveau type */
{
  OP *op=StackPtr;
  void *res=op->val;
  TOPTYPE top=EXTRACT_TOPTYPE(t);
  
  switch(top) {
  case TT_CHAR:
    *(char*)res=BsdGetChar(op);
    break;
  case TT_UCHAR:
    *(uchar*)res=BsdGetUChar(op);
    break;
  case TT_SHORT:
    *(short*)res=BsdGetShort(op);
    break;
  case TT_USHORT:
    *(ushort*)res=BsdGetUShort(op);
    break;
  case TT_ENUM:
  case TT_BIT:
  case TT_INT:
    *(INT*)res=BsdGetInt(op);
    break;
  case TT_UINT:
    *(UINT*)res=BsdGetUInt(op);
    break;
  case TT_LONG:
    *(long*)res=BsdGetLong(op);
    break;
  case TT_POINTER:
  case TT_ULONG:
    *(ulong*)res=BsdGetULong(op);
    break;
  case TT_FLOAT:
    *(float*)res=BsdGetFloat(op);
    break;
  case TT_DOUBLE:
    *(double*)res=BsdGetDouble(op);
    break;
  case TT_LDOUBLE:
    *(long double*)res=BsdGetLDouble(op);
    break;
  /* rien faire pour le moment pour les types composes */
  }
  op->type=*t;
  op->class &= ~C_LVALUE;
  SET_TOPTYPE(op,top);
  return 0;
} /* DoCast() */

/* NEED_FIXING: controle de taille du tableau */
int BsdDerefArray(int afct)
{
  OP *o=StackPtr,			/* index */
     *op=StackPtr->link;	/* tableau */
  int err=0;
  long idx/*,arrsz*/;
  TOPTYPE top;

  if (GET_TOPTYPE(o)>TT_LONG)
    return EVERR_TYPE_MISMATCH;
  idx=BsdGetLong(o);
  if (idx<0)
    return EVERR_IDX_NEG;
/*  arrsz=op->type.size;*/
  op->type=*(MK_TYPEPTR(op->type.target));
/*  if ((idx+1)*op->type.size > arrsz)
    return EVERR_OUTOF_ARRAY;*/
  SET_TOPTYPE(op,EXTRACT_TOPTYPE(&op->type));
  op->addr = *((char**)op->val) + idx*op->type.size;
  if (IS_MEMOBJ(GET_TOPTYPE(op)) && afct) {
    err=BsdReadMem(op->val,op->addr,op->type.size);
  }
  else {
    op->val=&op->buf;
    *(ulong*)op->val=(ulong)op->addr;
  }
  top=GET_TOPTYPE(o);
  if (IS_SCALAR(top) || top==TT_STRUCT || top==TT_UNION || top==TT_POINTER)
    op->class=C_LVALUE;
  else
    op->class=0;
  BsdPopOp();
  return err;
} /* DerefArray() */

int BsdEqTypes(RTYPE_PTR t1,RTYPE_PTR t2)
{
  RTYPE_PTR ti1,ti2;
  int i,ret;
  TOPTYPE top1,top2;
  
  if (t1==t2)
    return 1;
  top1=EXTRACT_TOPTYPE(t1); top2=EXTRACT_TOPTYPE(t2);
  switch(top1) {
  case TT_CHAR:
  case TT_UCHAR:
    ret=(top2==TT_CHAR || top2==TT_UCHAR);
    break;
#ifndef TARGET_PURE_C
  case TT_SHORT:
  case TT_USHORT:
    ret=(top2==TT_SHORT || top2==TT_USHORT);
    break;
#endif
/* NEED_FIXING: peut-etre comparaison d'enum trop restrictive (t1=t2) */
  case TT_ENUM:
    ret=(top2==TT_INT || top2==TT_UINT);
    break;
  case TT_INT:
  case TT_UINT:
    ret=(top2==TT_INT || top2==TT_UINT);
    break;
  case TT_LONG:
  case TT_ULONG:
    ret=(top2==TT_LONG || top2==TT_ULONG);
    break;
#ifdef TARGET_GCC
  case TT_LLONG:
  case TT_ULLONG:
    ret=(top2==TT_LLONG || top2==TT_ULLONG);
    break;
#endif
  case TT_POINTER:
    if (EXTRACT_TOPTYPE(MK_TYPEPTR(t1->target))==TT_VOID || 
         EXTRACT_TOPTYPE(MK_TYPEPTR(t2->target))==TT_VOID) {
      ret=1;
      break;
    }
  case TT_ARRAY:
    ret=((top2==TT_POINTER || top2==TT_ARRAY) && 
         BsdEqTypes(MK_TYPEPTR(t1->target),MK_TYPEPTR(t2->target)));
    break;
  case TT_STRUCT:
  case TT_UNION:
    if (top2==top1 && t1->fieldsnb==t2->fieldsnb && t1->fields && t2->fields) {
      ti1=MK_TYPEPTR(MK_STRUCTPTR(t1->fields->type));
      ti2=MK_TYPEPTR(MK_STRUCTPTR(t2->fields->type));
      for (i=0;i<t1->fieldsnb && ret;i++) {
        ret=BsdEqTypes(ti1++,ti2++);
      }
    }
    else
      ret=0;
    break;
  case TT_FUNC:
  case TT_BIT: /* a voir -- NEED_FIXING */
    BsdInternalError("pas implante");
    break;
  default: /* void, float, double, long double */
    ret=(top2==top1);
    break;
  }
  return ret;
} /* EqTypes() */

