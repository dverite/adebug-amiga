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
/*
 *     double my_strtod (str, endptr);
 *     const char *str;
 *     char **endptr;
 *		if !NULL, on return, points to char in str where conv. stopped
 *
 *     double my_atof (str)
 *     const char *str;
 *
 * recognizes:
 [spaces] [sign] digits [ [.] [ [digits] [ [e|E|d|D] [space|sign] [int][F|L]]]]
 *
 * returns:
 *	the number
 *		on overflow: HUGE_VAL and errno = ERANGE
 *		on underflow: -HUGE_VAL and errno = ERANGE
 */

#define Ise(c)		((c == 'e') || (c == 'E') || (c == 'd') || (c == 'D'))
#define Isdigit(c)	((c <= '9') && (c >= '0'))
#define Isspace(c)	((c == ' ') || (c == '\t'))
#define Issign(c)	((c == '-') || (c == '+'))
#define IsValidTrail(c) ((c == 'F') || (c == 'L'))
#define Val(c)		((c - '0'))

#ifndef __HAVE_68881__

#include <stddef.h>
#include <stdlib.h>
#include <float.h>

#define MAXDOUBLE	DBL_MAX
#define MINDOUBLE	DBL_MIN

#define MAXF  1.797693134862316
#define MINF  2.225073858507201
#define MAXE  308
#define MINE  (-308)

/* another alias for ieee double */
struct ldouble {
    unsigned long hi, lo;
};

static int __ten_mul (double *acc, int digit);
static double __adjust (double *acc, int dexp, int sign);

/*
 * mul 64 bit accumulator by 10 and add digit
 * algorithm:
 *	10x = 2( 4x + x ) == ( x<<2 + x) << 1
 *	result = 10x + digit
 */
static int __ten_mul(acc, digit)
double *acc;
int digit;
{
    register unsigned long d0, d1, d2, d3;
    register          short i;
    
    d2 = d0 = ((struct ldouble *)acc)->hi;
    d3 = d1 = ((struct ldouble *)acc)->lo;

    /* check possibility of overflow */
/*    if( (d0 & 0x0FFF0000L) >= 0x0ccc0000L ) */
/*    if( (d0 & 0x70000000L) != 0 ) */
    if( (d0 & 0xF0000000L) != 0 )
	/* report overflow somehow */
	return 1;
    
    /* 10acc == 2(4acc + acc) */
    for(i = 0; i < 2; i++)
    {  /* 4acc == ((acc) << 2) */
	asm volatile("	lsll	#1,%1;
 			roxll	#1,%0"	/* shift L 64 bit acc 1bit */
	    : "=d" (d0), "=d" (d1)
	    : "0"  (d0), "1"  (d1) );
    }

    /* 4acc + acc */
    asm volatile(" addl    %2,%0" : "=d" (d1) : "0" (d1), "d" (d3));
    asm volatile(" addxl   %2,%0" : "=d" (d0) : "0" (d0), "d" (d2));

    /* (4acc + acc) << 1 */
    asm volatile("  lsll    #1,%1;
 		    roxll   #1,%0"	/* shift L 64 bit acc 1bit */
	    : "=d" (d0), "=d" (d1)
	    : "0"  (d0), "1"  (d1) );

    /* add in digit */
    d2 = 0;
    d3 = digit;
    asm volatile(" addl    %2,%0" : "=d" (d1) : "0" (d1), "d" (d3));
    asm volatile(" addxl   %2,%0" : "=d" (d0) : "0" (d0), "d" (d2));


    /* stuff result back into acc */
    ((struct ldouble *)acc)->hi = d0;
    ((struct ldouble *)acc)->lo = d1;

    return 0;	/* no overflow */
}

/*#include "flonum.h"*/

static double __adjust(acc, dexp, sign)
double *acc;	/* the 64 bit accumulator */
int     dexp;	/* decimal exponent       */
int	sign;	/* sign flag		  */
{
    register unsigned long  d0, d1, d2, d3;
    register          short i;
    register 	      short bexp = 0; /* binary exponent */
    unsigned short tmp[4];
    double r;

#ifdef __STDC__
    double __normdf( double d, int exp, int sign, int rbits );
    double ldexp(double d, int exp);
#else
    extern double __normdf();
    extern double ldexp();
#endif    
    d0 = ((struct ldouble *)acc)->hi;
    d1 = ((struct ldouble *)acc)->lo;
    while(dexp != 0)
    {	/* something to do */
	if(dexp > 0)
	{ /* need to scale up by mul */
	    while(d0 > 429496729 ) /* 2**31 / 5 */
	    {	/* possibility of overflow, div/2 */
		asm volatile(" lsrl	#1,%1;
 			       roxrl	#1,%0"
		    : "=d" (d1), "=d" (d0)
		    : "0"  (d1), "1"  (d0));
		bexp++;
	    }
	    /* acc * 10 == 2(4acc + acc) */
	    d2 = d0;
	    d3 = d1;
	    for(i = 0; i < 2; i++)
	    {  /* 4acc == ((acc) << 2) */
		asm volatile("	lsll	#1,%1;
 				roxll	#1,%0"	/* shift L 64 bit acc 1bit */
			     : "=d" (d0), "=d" (d1)
			     : "0"  (d0), "1"  (d1) );
	    }

	    /* 4acc + acc */
	    asm volatile(" addl    %2,%0" : "=d" (d1) : "0" (d1), "d" (d3));
	    asm volatile(" addxl   %2,%0" : "=d" (d0) : "0" (d0), "d" (d2));

	    /* (4acc + acc) << 1 */
	    bexp++;	/* increment exponent to effectively acc * 10 */
	    dexp--;
	}
	else /* (dexp < 0) */
	{ /* scale down by 10 */
	    while((d0 & 0xC0000000L) == 0)
	    {	/* preserve prec by ensuring upper bits are set before div */
		asm volatile(" lsll  #1,%1;
 			       roxll #1,%0" /* shift L to move bits up */
		    : "=d" (d0), "=d" (d1)
		    : "0"  (d0), "1"  (d1) );
		bexp--;	/* compensate for the shift */
	    }
	    /* acc/10 = acc/5/2 */
	    *((unsigned long *)&tmp[0]) = d0;
	    *((unsigned long *)&tmp[2]) = d1;
	    d2 = (unsigned long)tmp[0];
	    asm volatile(" divu #5,%0" : "=d" (d2) : "0" (d2));
	    tmp[0] = (unsigned short)d2;	/* the quotient only */
	    for(i = 1; i < 4; i++)
	    {
		d2 = (d2 & 0xFFFF0000L) | (unsigned long)tmp[i]; /* REM|next */
		asm volatile(" divu #5,%0" : "=d" (d2) : "0" (d2));
		tmp[i] = (unsigned short)d2;
	    }
	    d0 = *((unsigned long *)&tmp[0]);
	    d1 = *((unsigned long *)&tmp[2]);
	    /* acc/2 */
	    bexp--;	/* div/2 taken care of by decrementing binary exp */
	    dexp++;
	}
    }
    
    /* stuff the result back into acc */
    ((struct ldouble *)acc)->hi = d0;
    ((struct ldouble *)acc)->lo = d1;

    /* normalize it */
    r = __normdf( *acc, ((0x03ff - 1) + 53), (sign)? -1 : 0, 0 );
    /* now shove in the binary exponent */
    return ldexp(r, bexp);
}

/* flags */
#define SIGN	0x01
#define ESIGN	0x02
#define DECP	0x04
#define CONVF	0x08

double my_strtod (s, endptr)
register const char *s;
char **endptr;
{
    double         accum = 0.0;
    register short flags = 0;
    register short texp  = 0;
    register short e     = 0;
    double	   zero = 0.0;
    const char 	   *tmp;
 
/*    assert ((s != NULL));*/

    if(endptr != NULL) *endptr = (char *)s;
    while(Isspace(*s)) s++;
    if(*s == '\0')
    {	/* just leading spaces */
	return zero;
    }

    if(Issign(*s))
    {
	if(*s == '-') flags = SIGN;
	if(*++s == '\0')
	{   /* "+|-" : should be an error ? */
	    return zero;
	}
    }

    do {
	if (Isdigit(*s))
	{
	    flags |= CONVF;
	    if( __ten_mul(&accum, Val(*s)) ) texp++;
	    if(flags & DECP) texp--;
	}
	else if(*s == '.')
	{
	    if (flags & DECP)  /* second decimal point */
		break;
	    flags |= DECP;
	}
	else
	    break;
	s++;
    } while (1);

    if(Ise(*s))
    {
	if(*++s != '\0') /* skip e|E|d|D */
	{  /* ! ([s]xxx[.[yyy]]e)  */
 	    tmp = s;
	    while(Isspace(*s)) s++; /* Ansi allows spaces after e */
	    if(*s != '\0')
	    { /*  ! ([s]xxx[.[yyy]]e[space])  */

		if(Issign(*s))
		    if(*s++ == '-') flags |= ESIGN;

		if(*s != '\0')
		{ /*  ! ([s]xxx[.[yyy]]e[s])  -- error?? */

		    for(; Isdigit(*s); s++)
			e = (((e << 2) + e) << 1) + Val(*s);

		    if(IsValidTrail(*s)) s++;
		
		    /* dont care what comes after this */
		    if(flags & ESIGN)
			texp -= e;
		    else
			texp += e;
		}
	    }
	    if(s == tmp) s++;	/* back up pointer for a trailing e|E|d|D */
	}
    }

    if((endptr != NULL) && (flags & CONVF))
	*endptr = (char *) s;
/* daniel: comparaison entiere pour eviter l'appel a la librairie
    if(accum == zero) return zero;*/
	if (((struct ldouble*)&accum)->hi==0 && ((struct ldouble*)&accum)->lo==0)
	  return zero;
    return __adjust(&accum, (int)texp, (int)(flags & SIGN));
}

#else __HAVE_68881__

#include <string.h>
#include <ctype.h>
#include <math.h>
#include <float.h>
#include <errno.h>
/*#include "flonum.h"*/

/* Format of packed decimal (from left to right):

    1 Bit: sign of mantissa
    1 Bit: sign of exponent
    2 Bits zero
   12 Bits: three digits exponent
    4 Bits unused, fourth (higher order) digit of exponent
    8 Bits zero
   68 Bits: 17 digits of mantissa, decimal point after first digit
  --------
   96 Bits == 12 Bytes

   All digits in BCD format.  */

/* double IEEE: 64 bits */
union double_di {
  double d;
  long i[2];
};

extern int float_errno;

double
my_strtod (const char *str, const char **endptr)
{
  char packed_buf[12];
  char *p;
  int exponent, i, digits_seen;
  union double_di di;

  if (endptr)
    *endptr = str;
  while (Isspace (*str))
    str++;
  p = packed_buf;
  for (i = 0; i < sizeof (packed_buf); i++)
    *p++ = 0;
  if (*str == '-')
    {
      packed_buf[0] = 0x80;
      str++;
    }
  else if (*str == '+')
    str++;
  else if (*str == '\0')
    return 0.0;
  i = 0;
  exponent = -1;
  digits_seen = 0;
  p = packed_buf + 3;
  /* Ignore leading 0's. */
  while (*str == '0')
    {
      digits_seen++;
      str++;
    }
  while (Isdigit (*str))
    {
      digits_seen++;
      if (i < 17)
	{
	  if (i & 1)
	    *p = (*str - '0') << 4;
	  else
	    *p++ |= *str - '0';
	  i++;
	}
      exponent++;
      str++;
    }
  if (*str == '.')
    {
      str++;
      if (i == 0)
	{
	  /* Skip leading 0's.  */
	  while (*str == '0')
	    {
	      digits_seen++;
	      exponent--;
	      str++;
	    }
	}
      while (Isdigit (*str))
	{
	  digits_seen++;
	  if (i < 17)
	    {
	      if (i++ & 1)
		*p = (*str - '0') << 4;
	      else
		*p++ |= *str - '0';
	    }
	  str++;
	}
    }
  /* Check that there were any digits.  */
  if (!digits_seen)
    return 0.0;

  if (*str == 'e' || *str == 'E' || *str == 'd' || *str == 'D')
    {
      const char *eptr = str;
      int exp_given, exp_neg;

      str++;
      while (Isspace (*str))
	str++;
      exp_neg = 0;
      if (*str == '-')
	{
	  exp_neg = 1;
	  str++;
	}
      else if (*str == '+')
	str++;
      if (!Isdigit (*str))
	{
	  str = eptr;
	  goto convert;
	}
      while (*str == '0')
	str++;
      exp_given = 0;
      while (Isdigit (*str) && exp_given < 900)
	{
	  exp_given = exp_given * 10 + *str - '0';
	  str++;
	}
      while (Isdigit (*str))
	str++;
      if (exp_given >= 900)
	{
	  /* Must be overflow/underflow.  */
	  if (endptr)
	    *endptr = str;
	  if (exp_neg)
	    return 0.0;
	  goto overflow;
	}
      if (exp_neg)
	exponent -= exp_given;
      else
	exponent += exp_given;
    }
 convert:
  if (endptr)
    *endptr = str;
  if (exponent < 0)
    {
      packed_buf[0] |= 0x40;
      exponent = -exponent;
    }
  packed_buf[1] = exponent % 10;
  packed_buf[1] |= ((exponent /= 10) % 10) << 4;
  packed_buf[0] |= exponent / 10 % 10;
  __asm ("fmovep %1,%0" : "=f" (di.d) : "m" (packed_buf[0]));

  /* Check for overflow.  */
  if ((di.i[0] & 0x7fffffff) >= 0x7ff00000)
    {
    overflow:
      float_errno = ERANGE;
      if (packed_buf[0] & 0x80)
	return -DBL_MAX;
      else
	return DBL_MAX;
    }
  return di.d;
}
#endif __HAVE_68881__

double
my_atof (const char *str)
{
  return my_strtod (str, NULL);
}
