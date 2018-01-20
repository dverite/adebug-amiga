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
   /**************************************************/
   /* EVAL.C : evaluation d'une expression numerique */
   /**************************************************/

#include "bsdeval.h"
#define FUTURE 0

/* a faire:
- les fonctions
- comparer champs differents d'une struct
*/

#ifdef ADEBUG
char *Adebug_msg;
struct SrcDbgPtrs *LTabs;
#endif

void PrintStruct(char *res,TYPE_PTR t,char *addr);
extern void BsdPrintEvalRes(char*,TYPE_PTR,void*,short);
extern CTYPEP ctype_char,ctype_short,ctype_int,ctype_long,ctype_longlong;
extern CTYPEP ctype_uchar,ctype_ushort,ctype_uint,ctype_ulong,ctype_ulonglong;
extern CTYPEP ctype_float,ctype_double,ctype_void;

static int nbrack,npar,IfThenElse;
int float_errno;
uchar *evp,*start_evp;
extern char iscsym[256];
extern char *eval_error_strings[];
OP *StackPtr;
static int NbPush,NbPop;
extern TYPE_STRUCT htypes[];

/* dst peut valoir src */
void BsdIndianReverse(char *buf,ulong sz)
{
  char c,*right=buf+sz;
  while (buf<right) {
	c = *buf;
	*buf++ = *(--right);
	*right = c;
  }
}

int BsdPushOp(OP *op)
{
  OP *new=(OP*)MyMalloc(sizeof(OP));
  if (!new)
    return EVERR_NO_MEM;
  *new=*op;
  new->link=StackPtr;
  /* translater le buffer si necessaire */
  if (new->bsize<=DEF_BSIZE)
    new->val=&new->buf;
  StackPtr=new;
  NbPush++;
  return 0;
}

void BsdPopOp()
{
  OP *next;
  if (StackPtr) {
    next=StackPtr->link;
    if (StackPtr->bsize>DEF_BSIZE)
      MyMfree(StackPtr->val,StackPtr->bsize);
    MyMfree(StackPtr,sizeof(OP));
    StackPtr=next;
    NbPop++;
  }
}

/* pareil que BsdPopOp() mais sans liberer le buffer de valeur
appele par l'affectation */
void BsdPopOpNofree()
{
  OP *next;
  if (StackPtr) {
    next=StackPtr->link;
    MyMfree(StackPtr,sizeof(OP));
    StackPtr=next;
    NbPop++;
  }
}

int BsdReallocBuf(OP *o,ulong size)
{
  if (o->bsize<sizeof(long double))
    MyMfree(o->buf,o->bsize);
  o->val=(char*)MyMalloc(size);
  if (!o->val)
    return EVERR_NO_MEM;
  o->bsize=size;
  return 0;
}

TYPE_PTR BsdAllocType(void)
{
  RTYPE_PTR t=(RTYPE_PTR)MyMalloc(sizeof(TYPE_STRUCT));
  if (t) {
    memset(t,0,sizeof(TYPE_STRUCT));
    return (TYPE_PTR)(UNMK_TYPEPTR(t));
  }
  return t?:NULL;
}

void *BsdGetObjAddr(SYM_PTR s,ulong size)
{
	char *charp;
	extern short FramePtr;
	extern ulong *HardRegs; /* d0_buf */

	switch(s->class) {
	case CLASS_CONST:
		return &(s->value.p);
		break;
	case CLASS_REG:
	case CLASS_REGPARM:
		charp=(char*)(HardRegs+s->value.i);
		switch(size) {
		case 1: /* (u)char */
			return charp+3;
		case 2: /* (u)short et/ou (u)int */
			return charp+2;
		case 4:
		default:
			return charp;
		}
		break;
	case CLASS_LOCAL:
	case CLASS_ARG:
		return (void*)(HardRegs[FramePtr]+(long)s->value.i);
		break;
	case CLASS_BLOCK:
	case CLASS_LABEL:
	case CLASS_STATIC:
	default:
		return s->value.p;
		break;
	}
}

void BsdReadSym(void *dst,SYM_PTR sym,ulong size)
{
  EVGETMEM(dst,BsdGetObjAddr(sym,size),size);
}

/* NEED_FIXING: TT_BIT */
TOPTYPE BsdGenTopType(TYPE_PTR t)
{
  TOPTYPE top;
  int u;

  switch(t->code) {
  case CTYPEC_PTR:
    top=TT_POINTER;
    break;
  case CTYPEC_ARRAY:
    top=TT_ARRAY;
    break;
  case CTYPEC_STRUCT:
    top=TT_STRUCT;
    break;
  case CTYPEC_UNION:
    top=TT_UNION;
    break;
  case CTYPEC_ENUM:
    top=TT_ENUM;
    break;
  case CTYPEC_FUNC:
    top=TT_FUNC;
    break;
  case CTYPEC_INT:
    u=t->flags & CTYPEF_UNSIGNED;
    switch(t->size) {
    case sizeof(char):
      top=u?TT_UCHAR:TT_CHAR;
      break;
    case sizeof(short):
      top=u?TT_USHORT:TT_SHORT;
      break;
    case sizeof(int):
      /* NEED_FIXING */
      if (t->name && !strcmp(t->name,"int"))
        top=u?TT_UINT:TT_INT;
      else
        top=u?TT_ULONG:TT_LONG;
      break;
    case sizeof(long long):
      top=u?TT_ULLONG:TT_LLONG;
      break;
    }
    break;
  case CTYPEC_FLT:
    switch(t->size) {
    case sizeof(float):
      top=TT_FLOAT;
      break;
    case sizeof(double):
      top=TT_DOUBLE;
      break;
#ifndef __GNUC__	/* NEED_FIXING */
    case sizeof(long double):
      top=TT_LDOUBLE;
      break;
#endif
    }
    break;
  case CTYPEC_VOID:
    top=TT_VOID;
    break;
  case CTYPEC_UNDEF:
  case CTYPEC_ERROR:
  case CTYPEC_RANGE:
  case CTYPEC_METHOD:
  case CTYPEC_REF:
  case CTYPEC_SET:
  case CTYPEC_PASCAL_ARRAY:
  default:
    top=TT_NOTYPE;
    break;
  }
  return top;
} /* BsdGenTopType() */

int BsdGetSymVal(int afct)
{
  uchar *p=evp,c;
  TOPTYPE toptype;
  SYM_PTR sym;
  OP op;
  ulong size;
  /* les classes BSD qui correspondent a des symboles utilisables */
  static char Allowed[13]={0,1,1,1,1,1,1,1,0,0,1,0,0};
  int err=0;

  while (iscsym[*(++p)]);
  c=*p; *p='\0';
  sym=BsdFindVar(evp);
  *p=c;
  if (sym && Allowed[sym->class]) {
    if (sym->class==CLASS_BLOCK) {
      toptype=TT_FUNC;
      op.type.code=CTYPEC_FUNC;
      op.type.target=sym->type;
      op.type.size=sym->type->size;	/*FUNCTYPE_SIZE ?*/
      op.type.ptr=op.type.fct=NULL;
      op.type.flags=op.type.fieldsnb=0;
      op.type.fields=NULL;
      op.type.name=op.type.tag=NULL;
    }
    else {
      op.type=*(MK_TYPEPTR(sym->type));
      toptype=EXTRACT_TOPTYPE(&op.type);
    }
    SET_TOPTYPE(&op,toptype);
    op.sym=sym;
    size=BsdObjectSize(&op.type);
    op.bsize=DEF_BSIZE;
    op.addr=BsdGetObjAddr(sym,size);
    op.val=&op.buf;
    if (IS_SCALAR(toptype) || toptype==TT_POINTER) {
      if (toptype!=TT_BIT) {
        if (afct) {
          err = BsdReadMem(op.val,op.addr,size);
#ifdef ENDIAN_REVERSE
		  ENDIAN_REVERSE(op.buf,size);
#endif
		}
      }
      else {
/* NEED_FIXING: bitfields */
#if 0
        op.modifier=GetTopType(MK_TYPEPTR(op.type.t.b.base));
        if (op.modifier==TT_INT)
          *(INT*)op.buf=BsdGetBitsSVal(op.addr,&op.type);
        else
          *(UINT*)op.buf=BsdGetBitsUVal(op.addr,&op.type);
#endif
      }
    }
    else {
      /* valeur du tableau=son adresse de base, non modifiable */
      *(ulong*)op.val=(ulong)op.addr;
    }
    op.class=(toptype==TT_ARRAY||toptype==TT_FUNC)?0:C_LVALUE;
    BsdPushOp(&op);
  }
  else
    return EVERR_UNDFND_SYMBOL;
  evp=p;
  return err;
} /* GetSymVal() */

TYPE_PTR BsdGetIType(TOPTYPE t)
{
  CTYPEP ret;

  switch(t) {
  case TT_CHAR:
    ret = ctype_char;
    break;
  case TT_UCHAR:
    ret = ctype_uchar;
    break;
  case TT_SHORT:
    ret = ctype_short;
    break;
  case TT_USHORT:
    ret = ctype_ushort;
    break;
  case TT_INT:
    ret = ctype_int;
    break;
  case TT_UINT:
    ret = ctype_uint;
    break;
  case TT_LONG:
    ret = ctype_long;
    break;
  case TT_ULONG:
    ret = ctype_ulong;
    break;
  case TT_LLONG:
    ret = ctype_longlong;
    break;
  case TT_ULLONG:
    ret = ctype_ulonglong;
    break;
  case TT_FLOAT:
    ret = ctype_float;
    break;
  case TT_DOUBLE:
  case TT_LDOUBLE:
    ret = ctype_double;
    break;
  case TT_VOID:
    ret = ctype_void;
    break;
  default:
   BsdInternalError("BsdGetIType(): type inattendu");
   ret = NULL;
  }
  return ret;
}

TOPTYPE BsdGetPostInt(void)
{
  TOPTYPE t;

  switch (*evp) {
  case 'u':
  case 'U':
    evp++;
    if (*evp=='l' || *evp=='L') {
      t=TT_ULONG;
      evp++;
    }
    else
      t=TT_UINT;
    break;
  case 'l':
  case 'L':
    evp++;
    if (*evp=='u' || *evp=='U') {
      t=TT_ULONG;
      evp++;
    }
    else
      t=TT_LONG;
    break;
  default:
    t=TT_INT;
  }
  return t;
}

TOPTYPE BsdGetPostFloat(void)
{
  TOPTYPE t;
  switch (*evp) {
  case 'l':
  case 'L':
    t=TT_LDOUBLE;
    evp++;
    break;
  case 'f':
  case 'F':
    t=TT_FLOAT;
    evp++;
    break;
  default:
    t=TT_DOUBLE;
    break;
  }
  return t;
}

int BsdPushIConst(long n,TOPTYPE top)
{
  OP op;

  op.type=*(GET_ITYPE(top));
  SET_TOPTYPE(&op,top);
  op.val=&op.buf;
  op.bsize=DEF_BSIZE;
  op.class=C_CONST;
  op.addr=NULL;
  switch(top) {
  case TT_CHAR:
  case TT_UCHAR:
    *(char*)op.buf=n;
    break;
  case TT_SHORT:
  case TT_USHORT:
    *(short*)op.buf=n;
    break;
  case TT_INT:
  case TT_UINT:
    *(INT*)op.buf=n;
    break;
  case TT_LONG:
  case TT_ULONG:
    *(long*)op.buf=n;
    break;
  case TT_LLONG:
  case TT_ULLONG:
    *(long long*)op.buf=n;
    break;
  }
  return BsdPushOp(&op);
}

int BsdGetHexNum()
{
  INT n=0;
  char c;

  c=*evp++;
  if (!(isxdigit(c))) {
    return EVERR_BAD_HEXA;
  }
  do {
    if (c>='0' && c<='9')
      n=(n<<4)+(int)(c-'0');
    else
      if (c>='A' && c<='F')
        n=(n<<4)+(int)c-'A'+10;
      else
        if (c>='a' && c<='f')
          n=(n<<4)+(int)c-'a'+10;
        else break;

  } while ((c=*evp++)!='\0');
  evp--;
  return BsdPushIConst(n,BsdGetPostInt());
} /* GetHexNum() */

int BsdGetDecNum()
{
  char c,*p,*err;
  INT n=0;
  double res;
  OP op;
  TOPTYPE top;

  p=evp;
  while (isdigit(c=*evp++))
    n=n*10 + c-'0';
  c=*(--evp);
  if (c=='.' || c=='e' || c=='E') {
    /* c'est un float */
    res=STRTOD(p,&err);
    if (err==p) {
      evp=p;
      return EVERR_BAD_FLOAT;	/* voir float_errno? */
    }
    evp=err;
    top=BsdGetPostFloat();
    op.type=*(GET_ITYPE(top));
    switch(top) {
    case TT_FLOAT:
      *(float*)op.buf=res;
      break;
    case TT_DOUBLE:
      *(double*)op.buf=res;
      break;
    case TT_LDOUBLE:
      *(long double*)op.buf=res;
      break;
    }
    op.val=&op.buf;
    op.bsize=DEF_BSIZE;
    op.class=C_CONST;
    SET_TOPTYPE(&op,top);
    op.addr=NULL;
    BsdPushOp(&op);
    return 0;
  }
  else {
    /* valeur entiere */
    return BsdPushIConst(n,BsdGetPostInt());
  }
} /* GetDecNum() */

int BsdGetOctalNum(void)
{
  char c;
  INT n=0;

  if (*evp=='.') {
    evp--;
    return BsdGetDecNum();
  }
  while ((c=*evp++)!='\0') {
    if (c<'0' || c>'7')
      break;
    n=(n<<3) + c-'0';
  }
  evp--;
  return BsdPushIConst(n,BsdGetPostInt());
} /* GetOctalNum() */

int BsdEvalChar()
{
  char c;
  INT n;

  c=*evp++;
  if (c=='\0') {
    return EVERR_UNEXP_EOE;
  }
  if (c=='\\') {
    switch((c=*evp++)) {
    case 'a':
      c='\a';
      break;
    case 'b':
      c='\b';
      break;
    case 'f':
      c='\f';
      break;
    case 'n':
      c='\n';
      break;
    case 'r':
      c='\r';
      break;
    case 't':
      c='\t';
      break;
    case 'v':
      c='\v';
      break;
/*
    case '\\':
      c='\\';
      break;
    case '?':
      c='\?';
      break;
    case '\'':
      c='\'';
      break;
    case '\"':
      c='\"';
      break;
*/
    case 'x':
      c=*evp++;
      if (isxdigit(c)) {
        if (c>='0' && c<='9')
          c-='0';
        else
          c=tolower(c)-'a'+10;
        if (isxdigit(*evp)) {
          c=c<<4;
          if (*evp>='0' && *evp<='9')
            c+=*evp-'0';
          else
            c+=tolower(*evp)-'a'+10;
          evp++;
        }
      }
      else
        c='x'; /* erreur? */
      break;
    default:
      if (c>='0' && c<='7') {
        n=0;
        do {
          n=(n<<3)+(c-'0');
          c=*evp++;
        } while (c>='0' && c<='7');
        c=n;
        evp--;
      }
      break;
    }
  }
  if (*evp++ != '\'') {
    return EVERR_MISSING_SINGLE_QUOTE;
  }
  return BsdPushIConst((INT)c,TT_CHAR);
} /* EvalChar() */

/*****************************************/
int BsdEval (int level,int afct)
/*****************************************/
{
  uchar c,*start;
  BOOL endexpr=FALSE;
  TYPE_PTR t;
  TOPTYPE top;
  int err=0;
  long l;

  /* OPERANDE */
  while ((c=*evp++)==' ' || c=='\t');
  switch(c) {
  case '(':
    start=evp;
    t=BsdCheckCast(&err);
    if (!err) {
      if (t) {
        if (level<=UNARY_PRI) { /* CAST_PRI */
          err=BsdEval(UNARY_PRI,afct); /* CAST_PRI */
          if (!err) {
            /* conversion du type */
            err=BsdDoCast(t);
          }
        }
        else {
          evp=start;
          endexpr=TRUE;
        }
      }
      else {
        npar++;
        err=BsdEval(0,afct);
        if (!err && *evp++ != ')') {
          evp--;
          return EVERR_UNMATCHED_PARENT;
        }
        else
          npar--;
      }
    }
    break;
  case ')':
    err=EVERR_UNEXP_CLOSEPAR;
    break;
  case ']':
    err=EVERR_UNEXP_CLOSEBRACK;
    break;
  case '+':
    if (*evp!='+') {
      if (level<=UNARY_PRI)
        err=BsdEval(level,afct);
      else
        endexpr=TRUE;
    }
    else { /* ++ */
      if (level<=UNARY_PRI) {
        evp++;
        err=BsdEval(UNARY_PRI,afct);
        if (!err)
          err=BsdDoIncr(afct);
      }
      else
        endexpr=TRUE;
    }
    break;
  case '-':
    if (*evp!='-') {
      if (level<=UNARY_PRI) {
        err=BsdEval(UNARY_PRI,afct);
        if (!err)
          err=BsdDoUMinus();
      }
      else
        endexpr=TRUE;
    }
    else { /* -- */
      if (level<=UNARY_PRI) {
        evp++;
        err=BsdEval(UNARY_PRI,afct);
        if (!err)
          err=BsdDoDecr(afct);
      }
      else
        endexpr=TRUE;
    }
    break;
  case '~':
    if (level<=UNARY_PRI) {
      err=BsdEval(UNARY_PRI,afct);
      if (!err)
        err=BsdDoBinaryNot();
    }
    else
      endexpr=TRUE;
    break;
  case '!':
    if (level<=UNARY_PRI) {
      err=BsdEval(UNARY_PRI,afct);
      if (!err)
        err=BsdDoLogicalNot();
    }
    else
      endexpr=TRUE;
    break;
  case '0':
    if ((c=*evp)=='x' || c=='X') {
      evp++;
      err=BsdGetHexNum();
    }
    else {
      err=BsdGetOctalNum();
    }
    break;
  case '1':
  case '2':
  case '3':
  case '4':
  case '5':
  case '6':
  case '7':
  case '8':
  case '9':
    evp--;
    err=BsdGetDecNum();
    break;
  case '\'':
    err=BsdEvalChar();
    break;
  case '/':
  case '|':
  case '<':
  case '>':
  case '=':
  case '^':
  case '%':
    err=EVERR_UNEXP_BOP;
    break;
  case '*':
    if (level<=UNARY_PRI) {
      err=BsdEval(UNARY_PRI,afct);
      if (!err)
        err=BsdDerefPtr(afct);
    }
    else
      endexpr=TRUE;
    break;
  case '&':
    if (level<=UNARY_PRI) {
      err=BsdEval(UNARY_PRI,afct);
      if (!err)
        err=BsdRefPtr();
    }
    else
      endexpr=TRUE;
    break;
  default:
    if (c>0) {
      evp--;
      if (!strncmp(evp,"sizeof",6) &&
         (evp[6]==' ' || evp[6]=='\t' || evp[6]=='(')) {
        evp+=6;
        while (*evp==' ' || *evp=='\t') evp++;
        if (*evp=='(') {
          evp++;
          if ((t=BsdCheckCast(&err))!=NULL) {
            if (!err) {
              /*evp++;*/
              err=BsdPushInt(t->size);
            }
          }
          else {
            evp--;
            err=BsdEval(UNARY_PRI,0);
            if (!err)
              err=BsdDoSizeof();
          }
        }
        else {
          err=BsdEval(UNARY_PRI,0);
          if (!err)
            err=BsdDoSizeof();
        }
      }
      else
        err=BsdGetSymVal(afct);
    }
    else
      err=EVERR_ERR_CHAR;
    break;
  }
  if (err)
    return err;

  /**** OPERATEUR ****/
  while (!endexpr) {
    while ((c=*evp++)==' ' || c=='\t');
    switch (c) {
    case '.':
      if (level<=POSTFIX_PRI) {
        while ((c=*evp++)==' ' || c=='\t');
        start=--evp;
        while (iscsym[*evp]) evp++;
        err=BsdDoStruct(start,evp-start,afct);
      }
      else
        endexpr=TRUE;
      break;
    case ')':
      if (npar==0) {
        err=EVERR_UNEXP_CLOSEPAR;
      }
    case '\0':
      endexpr=TRUE;
      break;
/* #[ [,]: a[b] */
    case ']':
      if (nbrack==0)
        err=EVERR_UNEXP_CLOSEBRACK;
      endexpr=TRUE;
      break;
    case '[':
      if (level<=POSTFIX_PRI) {
        top=GET_TOPTYPE(StackPtr);
        if (top==TT_ARRAY || top==TT_POINTER) {
          nbrack++;
          err=BsdEval(POSTFIX_PRI,afct);
          if (*evp++!=']')
            err=EVERR_UNMATCHED_BRACK;
          else {
            nbrack--;
            err=BsdDerefArray(afct);
          }
        }
        else
          err=EVERR_TYPE_MISMATCH;
      }
      else
        endexpr=TRUE;
      break;          
/* #] [,]: a[b] */ 
/* #[ =: a=b,a==b */
    case '=':
      c=*evp;
      if (c=='=') {
        if (level<=EQ_PRI) {
          evp++;
          err=BsdEval(EQ_PRI,afct);
          if (!err)
           err=BsdDoEq();
        }
        else
          endexpr=TRUE;
      }
      else {
        if (level<=AFFECT_PRI) {
          err=BsdEval(AFFECT_PRI,afct);
          if (!err)
            err=BsdDoAffect(afct);
        }
        else
          endexpr=TRUE;
      }
      break;
/* #] =: a=b,a==b */ 
/* #[ !: a!=b */
    case '!':
      if (*evp=='=') {
        if (level<EQ_PRI) {
          evp++;
          err=BsdEval(EQ_PRI,afct);
          if (!err)
            err=BsdDoNe();
        }
      }
      else
        err=EVERR_UNEXP_UOP;
/* #] !: a!=b */
/* #[ a?b:c */
    case '?':
      top=GET_TOPTYPE(StackPtr);
      if (IS_SCALAR(top) || top==TT_POINTER) {
        IfThenElse++;
        l=BsdGetLong(StackPtr);
        /* 2eme arg */
        err=BsdEval(IFE_PRI,afct && l!=0L);
        if (err)
          break;
        if (*evp!=':') {
          err=EVERR_IFE_NOMATCH;
          break;
        }
        evp++;
        if (l==0L) {
          /* 3eme arg */
          BsdPopOp();
          err=BsdEval(IFE_PRI,afct);
        }
        else {
          /* skipper 3eme arg */
          err=BsdEval(IFE_PRI,0);
          BsdPopOp();
        }
        IfThenElse--;
      }
      else
        err=EVERR_TYPE_MISMATCH;
      break;
    case ':':
      if (!IfThenElse) {
        err=EVERR_SPURIOUS_DBLEP;
      }
      endexpr=TRUE;
      break;
/* #] a?b:c */ 
/* #[ +: a+b, a++, a+=b */
    case '+':
      switch (*evp) {
      case '+':
        if (level < POSTFIX_PRI) {
          evp++;
          err=BsdPushOp(StackPtr);
          if (!err)
            err=BsdDoIncr(afct);
          BsdPopOp();
          StackPtr->class &= ~C_LVALUE;
        }
        else
          endexpr=TRUE;
        break;
      case '=':
        if (level<=AFFECT_PRI) {
          evp++;
          err=BsdPushOp(StackPtr);
          if (!err) {
            err=BsdEval(AFFECT_PRI,afct);
            if (!err) {
              err=BsdDoPlus();
              if (!err)
                err=BsdDoAffect(afct);
            }
          }
        }
        else
          endexpr=TRUE;
        break;
      default:
        if (level < ADD_PRI) {
          err=BsdEval(ADD_PRI,afct);
          if (!err)
            err=BsdDoPlus();
        }
        else
          endexpr=TRUE;
        break;
      }
      break;
/* #] +: */ 
/* #[ -: a-b, a--, a-=b, a->b */
    case '-':
      switch (*evp) {
      default:
        if (level < ADD_PRI) {
          err=BsdEval(ADD_PRI,afct);
          if (!err)
            err=BsdDoMinus();
        }
        else
          endexpr=TRUE;
        break;
      case '>': /* struct pointer */
        if (level<=POSTFIX_PRI) {
          evp++;
          while (*evp==' ' || *evp=='\t') evp++;
          start=evp;
          while (iscsym[*evp]) evp++;
          err=BsdDoPStruct(start,evp-start,afct);
        }
        else
          endexpr=TRUE;
        break;
      case '-': /* -- */
        if (level < POSTFIX_PRI) {
          evp++;
          err=BsdPushOp(StackPtr);
          if (!err)
            err=BsdDoDecr(afct);
          BsdPopOp();
          StackPtr->class &= ~C_LVALUE;
        }
        else
          endexpr=TRUE;
        break;
      case '=':
        if (level<=AFFECT_PRI) {
          evp++;
          err=BsdPushOp(StackPtr);
          if (!err) {
            err=BsdEval(AFFECT_PRI,afct);
            if (!err) {
              err=BsdDoMinus();
              if (!err)
                err=BsdDoAffect(afct);
            }
          }
        }
        else
          endexpr=TRUE;
        break;
      }
      break;
/* #] -: */ 
/* #[ *,/,%: a*b,a*=b,a/b,a/=b,a%b,a%=b */
    case '*':
      if (*evp!='=') {
        if (level < MUL_PRI) {
          err=BsdEval(MUL_PRI,afct);
          if (!err)
            err=BsdDoMul();
        }
        else
          endexpr=TRUE;
      }
      else {
        if (level<=AFFECT_PRI) {
          evp++;
          err=BsdPushOp(StackPtr);
          if (!err) {
            err=BsdEval(AFFECT_PRI,afct);
            if (!err) {
              err=BsdDoMul();
              if (!err)
                err=BsdDoAffect(afct);
            }
          }
        }
        else
          endexpr=TRUE;
      }
      break;

    case '/':
      if (*evp!='=') {
        if (level < MUL_PRI) {
          err=BsdEval(MUL_PRI,afct);
          if (!err)
            err=BsdDoDiv(afct);
        }
        else
          endexpr=TRUE;
      }
      else {
        if (level<=AFFECT_PRI) {
          evp++;
          err=BsdPushOp(StackPtr);
          if (!err) {
            err=BsdEval(AFFECT_PRI,afct);
            if (!err) {
              err=BsdDoDiv(afct);
              if (!err)
                err=BsdDoAffect(afct);
            }
          }
        }
        else
          endexpr=TRUE;
      }
      break;
    case '%':
      if (*evp!='=') {
        if (level < MUL_PRI) {
          err=BsdEval(MUL_PRI,afct);
          if (!err)
            err=BsdDoModulo(afct);
        }
        else
          endexpr=TRUE;
      }
      else {
        if (level<=AFFECT_PRI) {
          evp++;
          err=BsdPushOp(StackPtr);
          if (!err) {
            err=BsdEval(AFFECT_PRI,afct);
            if (!err) {
              err=BsdDoModulo(afct);
              if (!err)
                err=BsdDoAffect(afct);
            }
          }
        }
        else
          endexpr=TRUE;
      }
      break;
/* #] *,/,%: */ 
/* #[ |: a|b,a||b,a|=b */
    case '|':
      switch (*evp) {
      case '|':
        if (level<=LOR_PRI) {
          evp++;
          top=GET_TOPTYPE(StackPtr);
          if (IS_SCALAR(top) || top==TT_POINTER) {
            err=BsdEval(LOR_PRI,afct && !BsdGetLong(StackPtr));
            if (!err)
              err=BsdDoCmpOr();
          }
          else
            err=EVERR_TYPE_MISMATCH;
        }
        else
          endexpr=TRUE;
        break;
      case '=':
        if (level<=AFFECT_PRI) {
          evp++;
          err=BsdPushOp(StackPtr);
          if (!err) {
            err=BsdEval(AFFECT_PRI,afct);
            if (!err) {
              err=BsdDoOr();
              if (!err)
                err=BsdDoAffect(afct);
            }
          }
        }
        else
          endexpr=TRUE;
        break;
      default:
        if (level<=OR_PRI) {
          err=BsdEval(OR_PRI,afct);
          if (!err)
            err=BsdDoOr();
        }
        else
          endexpr=TRUE;
        break;
      }
      break;
/* #] |: a|b,a||b,a|=b */ 
/* #[ &: a&b, a&&b, a&=b */
    case '&':
      switch (*evp) {
      case '&':
        if (level<=LAND_PRI) {
          evp++;
          top=GET_TOPTYPE(StackPtr);
          if (IS_SCALAR(top) || top==TT_POINTER) {
            err=BsdEval(LAND_PRI,afct && BsdGetLong(StackPtr));
            if (!err)
              err=BsdDoCmpAnd();
          }
          else
            err=EVERR_TYPE_MISMATCH;
        }
        else
          endexpr=TRUE;
        break;
      case '=':
        if (level<=AFFECT_PRI) {
          evp++;
          err=BsdPushOp(StackPtr);
          if (!err) {
            err=BsdEval(AFFECT_PRI,afct);
            if (!err) {
              err=BsdDoAnd();
              if (!err)
                err=BsdDoAffect(afct);
            }
          }
        }
        else
          endexpr=TRUE;
        break;
      default:
        if (level<=AND_PRI) {
          err=BsdEval(AND_PRI,afct);
          if (!err)
            err=BsdDoOr();
        }
        else
          endexpr=TRUE;
        break;
      }
      break;
/* #] &: a&b, a&&b, a&=b */ 
/* #[ ^: a^b,a^=b */
    case '^':
      if (*evp=='=') {
        if (level<=AFFECT_PRI) {
          evp++;
          err=BsdPushOp(StackPtr);
          if (!err) {
            err=BsdEval(AFFECT_PRI,afct);
            if (!err) {
              err=BsdDoXor();
              if (!err)
                err=BsdDoAffect(afct);
            }
          }
        }
        else
          endexpr=TRUE;
      }
      else {
        if (level<=XOR_PRI) {
          err=BsdEval(XOR_PRI,afct);
          if (!err)
            err=BsdDoXor();
        }
        else
          endexpr=TRUE;
      }
      break;
/* #] ^: a^b,a^=b */ 
/* #[ >: a>b,a>=b,a>>b,a>>=b */
    case '>':
      if (*evp=='>') {
        if (*(evp+1)!='=') { /*a>>b*/
          if (level<SFT_PRI) {
            evp++;
            err=BsdEval(SFT_PRI,afct);
            if (!err)
              err=BsdDoSftRight();
          }
          else
            endexpr=TRUE;
        }
        else { /*a>>=b*/
          if (level<=AFFECT_PRI) {
            evp+=2;
            err=BsdPushOp(StackPtr);
            if (!err) {
              err=BsdEval(AFFECT_PRI,afct);
              if (!err) {
                err=BsdDoSftRight();
                if (!err)
                  err=BsdDoAffect(afct);
              }
            }
          }
          else
            endexpr=TRUE;
        }
      }
      else {
        if (level<REL_PRI) {
          if ((c=*evp)=='=')
            evp++;
          err=BsdEval(REL_PRI,afct);
          if (!err)
            err=(c=='='?BsdDoGe():BsdDoGt());
        }
        else
          endexpr=TRUE;
      }
      break;
/* #] >: a>b,a>=b,a>>b,a>>=b */ 
/* #[ <: a<b,a<=b,a<<b,a<<=b */
    case '<':
      if (*evp=='<') {
        if (*(evp+1)!='=') { /*a<<b*/
          if (level<SFT_PRI) {
            evp++;
            err=BsdEval(SFT_PRI,afct);
            if (!err)
              err=BsdDoSftLeft();
          }
          else
            endexpr=TRUE;
        }
        else { /*a<<=b*/
          if (level<=AFFECT_PRI) {
            evp+=2;
            err=BsdPushOp(StackPtr);
            if (!err) {
              err=BsdEval(AFFECT_PRI,afct);
              if (!err) {
                err=BsdDoSftLeft();
                if (!err)
                  err=BsdDoAffect(afct);
              }
            }
          }
          else
            endexpr=TRUE;
        }
      }
      else {
        if (level<REL_PRI) {
          if ((c=*evp)=='=')
            evp++;
          err=BsdEval(REL_PRI,afct);
          if (!err)
            err=(c=='='?BsdDoLe():BsdDoLt());
        }
        else
          endexpr=TRUE;
      }
      break;
/* #] <: a<b,a<=b,a<<b,a<<=b */ 
    default:
      err=EVERR_BOP_EXPECTED;
      break;
    } /* switch bin op */
    if (err)
      return err;
  } /* while !endexpr */
  evp--;
  return err;
} /* BsdEval() */

void PEvalError(char *msg,int err)
{
#ifndef ADEBUG
  int i;
  if (err) {
  if (msg)
    PRINTF("%s",msg);
  PRINTF("%s\n",start_evp);
  i=0;
  while (i++<evp-start_evp-1)
    PERROR(" ");
  PERROR("^ Error: %s\n",eval_error_strings[err]);
  }
#else
  if (msg)
    strcpy(Adebug_msg,msg);
  strcpy(Adebug_msg,eval_error_strings[err]);
#endif
} /* PEvalError() */

long EvalC(char *expr,char *res,ulong ltabs)
{
  static OP v;
  int err;
  long ret;
  TOPTYPE top;
  TYPE_PTR t;
  short class;
/*
  LTabs=(struct SrcDbgPtrs*)ltabs;
  LTabs->nb_types = LTabs->nb_types/sizeof(TYPE_STRUCT);
  InitHTypes();
*/

  if (expr==NULL)
    return 0;
  nbrack=npar= IfThenElse=0;
  NbPush=NbPop=0; StackPtr=NULL;
  start_evp=evp=expr;
  err=BsdEval(0,1);
  *res='\0';
  if (!err) {
        v=*StackPtr;
        top=GET_TOPTYPE(&v);
#ifdef TARGET_PUREC
        PrintElt(res,&v.type,(top==TT_STRUCT || top==TT_UNION || top==TT_BIT)?
            v.addr:v.val);
        strcat(res," (");
        PrintType(&v.type,res+strlen(res));
        strcat(res,")");
#endif
#ifdef TARGET_GCC
		if (top==TT_FUNC) {
		  class=CLASS_BLOCK;
		  t=v.type.target;
		}
		else {
		  class=CLASS_STATIC;
		  t=&v.type;
		}
        BsdPrintEvalRes(res,t,(top==TT_STRUCT || top==TT_UNION ||
							   top==TT_ARRAY)?v.addr:v.val,class);
#endif
        if (IS_SCALAR(top))
          ret=BsdGetLong(&v);
        else
          ret=(long)v.addr;
  }
  else {
#ifdef ADEBUG
    Adebug_msg=res;
#endif
    PEvalError(NULL,err);
    ret=0;
  }
  BsdPopOp();
  return ret;
}
