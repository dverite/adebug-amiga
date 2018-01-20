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
/* genop.h <- evfoncs.c */
 
#define GEN_INT_BOP(src,op,b,res)  \
  case TT_CHAR: \
    *(char*)res=*(char*)src op BsdGetInt(b); \
    break; \
  case TT_UCHAR: \
    *(uchar*)res=*(uchar*)src op BsdGetInt(b); \
    break; \
  case TT_SHORT: \
    *(short*)res=*(short*)src op BsdGetInt(b); \
    break; \
  case TT_USHORT: \
    *(ushort*)res=*(ushort*)src op BsdGetInt(b); \
    break; \
  case TT_ENUM: \
  case TT_BIT:  \
  case TT_INT:  \
    *(INT*)res=*(INT*)src op BsdGetInt(b); \
    break; \
  case TT_UINT: \
    *(UINT*)res=*(UINT*)src op BsdGetInt(b); \
    break; \
  case TT_LONG: \
    *(long*)res=*(long*)src op BsdGetLong(b); \
    break; \
  case TT_ULONG: \
    *(ulong*)res=*(ulong*)src op BsdGetLong(b); \
    break;

#define  GEN_FLOAT_BOP(src,op,b,res) \
  case TT_FLOAT: \
    *(float*)res=*(float*)src op BsdGetFloat(b); \
    break; \
  case TT_DOUBLE: \
    *(double*)res=*(double*)src op BsdGetDouble(b); \
    break; \
  case TT_LDOUBLE: \
    *(long double*)res=*(long double*)src op BsdGetLDouble(b); \
    break;

#define GEN_INT_BOPC(src,op,c,res)  \
  case TT_CHAR: \
    *(char*)res=*(char*)src op c; \
    break; \
  case TT_UCHAR: \
    *(uchar*)res=*(uchar*)src op c; \
    break; \
  case TT_SHORT: \
    *(short*)res=*(short*)src op c; \
    break; \
  case TT_USHORT: \
    *(ushort*)res=*(ushort*)src op c; \
    break; \
  case TT_ENUM: \
  case TT_BIT:  \
  case TT_INT:  \
    *(INT*)res=*(INT*)src op c; \
    break; \
  case TT_UINT: \
    *(UINT*)res=*(UINT*)src op c; \
    break; \
  case TT_LONG: \
    *(long*)res=*(long*)src op c; \
    break; \
  case TT_ULONG: \
    *(ulong*)res=*(ulong*)src op c; \
    break;

#define GEN_INT_UOP(op,src,res)  \
  case TT_CHAR: \
    *(char*)res=op (*(char*)src); \
    break; \
  case TT_UCHAR: \
    *(uchar*)res=op (*(uchar*)src); \
    break; \
  case TT_SHORT: \
    *(short*)res=op (*(short*)src); \
    break; \
  case TT_USHORT: \
    *(ushort*)res=op (*(ushort*)src); \
    break; \
  case TT_ENUM: \
  case TT_BIT:  \
  case TT_INT:  \
    *(INT*)res=op (*(INT*)src); \
    break; \
  case TT_UINT: \
    *(UINT*)res=op (*(UINT*)src); \
    break; \
  case TT_LONG: \
    *(long*)res=op (*(long*)src); \
    break; \
  case TT_ULONG: \
    *(ulong*)res=op (*(ulong*)src); \
    break;

#define GEN_FLOAT_UOP(op,src,res) \
  case TT_FLOAT: \
    *(float*)res = op (*(float*)src); \
    break; \
  case TT_DOUBLE: \
    *(double*)res = op (*(double*)src); \
    break; \
  case TT_LDOUBLE: \
    *(long double*)res = op (*(long double*)src); \
    break;

#define GENGETBUF(o,r) \
  switch(GET_TOPTYPE(o)) { \
  case TT_CHAR: \
    r=*(char*)o->buf; \
    break; \
  case TT_UCHAR: \
    r=*(uchar*)o->buf; \
    break; \
  case TT_SHORT: \
    r=*(short*)o->buf; \
    break; \
  case TT_USHORT: \
    r=*(ushort*)o->buf; \
    break; \
  case TT_ENUM: \
  case TT_INT: \
    r=*(INT*)o->buf; \
    break; \
  case TT_UINT: \
    r=*(UINT*)o->buf; \
    break; \
  case TT_LONG: \
    r=*(long*)o->buf; \
    break; \
  case TT_ULONG: \
  case TT_POINTER: \
    r=*(ulong*)o->buf; \
    break; \
  case TT_FLOAT: \
    r=*(float*)o->buf; \
    break; \
  case TT_DOUBLE: \
    r=*(double*)o->buf; \
    break; \
  case TT_LDOUBLE: \
    r=*(long double*)o->buf; \
    break; \
  case TT_BIT: \
/* NEED_FIXING */ \
/*    r=(o->type.modifier==TT_INT?*(INT*)o->buf:*(UINT*)o->buf); */ \
    break; \
  }

#define GEN_CMP_OP(res,a,op,b) \
    case TT_ENUM: \
    case TT_INT: \
      *(INT*)res=(*(INT*)a->buf op *(INT*)b->buf); \
      break; \
    case TT_UINT: \
      *(INT*)res=(*(UINT*)a->buf op *(UINT*)b->buf); \
      break; \
    case TT_LONG: \
      *(INT*)res=(*(long*)a->buf op *(long*)b->buf); \
      break; \
    case TT_ULONG: \
    case TT_POINTER: \
      *(INT*)res=(*(ulong*)a->buf op *(ulong*)b->buf); \
      break; \
    case TT_FLOAT: \
      *(INT*)res=(*(float*)a->buf op *(float*)b->buf); \
      break; \
    case TT_DOUBLE: \
      *(INT*)res=(*(double*)a->buf op *(double*)b->buf); \
      break; \
    case TT_LDOUBLE: \
      *(INT*)res=(*(long double*)a->buf op *(long double*)b->buf); \
      break; \
    case TT_VOID: \
      err=EVERR_VOID_USED; \
      break; \
    case TT_STRUCT: \
    case TT_UNION: \
    case TT_ARRAY: \
    case TT_BIT: \
    case TT_FUNC: \
      err=EVERR_CANT_CMP; \
      break;

