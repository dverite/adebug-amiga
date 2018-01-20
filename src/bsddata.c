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
/* data.c: donnees de l'evaluateur */
#include "bsdeval.h"

char *eval_error_strings[NB_ERRORS]={
  "",
  "unexpected close parenthesis",
  "missing close parenthesis",
  "binary operator expected",
  "value expected",
  "undefined symbol",
  "zero divide",
  "forbidden affectation",
  "bad hexadecimal number",
  "unexpected end of expression",
  "missing ending quote",
  "unexpected binary operator",
  "unexpected unary operator",
  "illegal character",
  "no '?' matching with ':'",
  "no ':' matching with '?'",
  "illegal floating point constant",
  "boolean value expected in expr?arg1:arg2",
  "illegal type",
  "illegal pointer type",
  "unknown type",
  "significant precision loose in type conversion",
  "no memory",
  "forbidden use of void value",
  "lvalue required",
  "object has no address",
  "unexpected closing bracket",
  "missing closing bracket",
  "negative index",
  "index greater than array size",
  "invalid cast",
  "struct required at left side of '.'",
  "pointer to struct required at left side of '->'",
  "no such member in structure",
  "integer type required",
  "illegal comparison",
  "cannot dereference null pointer",
  "bad address for reading",
  "bad address for writing"
};

/* tableau des caracteres valides pour un nom de symbole */
char iscsym[256] = {
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  /* 0-47 */
  1,1,1,1,1,1,1,1,1,1,    /* chiffres */
  0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,  /* A-Z */
  0,0,0,0,1,0,  /* _ */
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,  /* a-z */
  0,0,0,0,
  /* 128->255 */
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
};


char *DSTypesText[]={
  "????",
  "char",
  "uchar",
#ifndef TARGET_PUREC
  "short",
  "ushort",
#endif
  "int",
  "uint",
  "long",
  "ulong",
#ifdef TARGET_GCC
  "long long",
  "unsigned long long",
#endif
  "float",
  "double",
  "long double",
  "void",
  "pointer",
  "array",
  "enum",
  "struct",
  "union",
  "func",
  "bitfield"
};

