;
; Copyright 1990-2006 Alexandre Lemaresquier, Raphael Lemoine
;                     Laurent Chemla (Serial support), Daniel Verite (AmigaOS support)
;
; This file is part of Adebug.
;
; Adebug is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; Adebug is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with Adebug; if not, write to the Free Software
; Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
;
	opt	p=68030,p=68882
	XDEF	_modf

BIAS8 = $3ff - 1

_modf:
	lea	4(sp),a0		; a0 -> float argument
	movem.l	d2-d7,-(sp)
	movem.l	(a0)+,d0-d1
	move.l	(a0),a1		; a1 -> ipart result

	move.l	d0,d2		; calculate exponent
	swap	d2
	bclr	#15,d2		; kill sign bit
	lsr.w	#4,d2		; exponent in lower 12 bits of d2

	cmp.w	#BIAS8,d2
	bgt.s	.1		; fabs(value) >= 1.0
;				; return entire value as fractional part
	clr.l	(a1)+		; d0, d1 already ok
	clr.l	(a1)		; make integer part 0

.0:	movem.l	(sp)+,d2-d7	; restore saved d2-d7
	rts

.1:	move.w	#BIAS8+53,d3
	sub.w	d2,d3		; compute position of "binary point"
	bgt.s	.2		; branch if we do have fractional part

	movem.l	d0-d1,(a1)	; store entire value as the integer part
	moveq	#0,d0		; return zero as fractional part
	move.l	d0,d1
	bra.s	.0

.2:	move.l	d1,d5		; save for computation of fractional part
	moveq	#32,d6
	cmp.w	d6,d3
	blt.s	.3		; jump if "binary point" in a lower part
	move.l	d0,d4
	sub.w	d6,d3
	moveq	#0,d6		; compute mask for splitting
	bset	d3,d6
	neg.l	d6
	and.l	d6,d0		; this is integer part
	moveq	#0,d1
	not.l	d6
	and.l	d6,d4		; and denormalized fractional part
	bra.s	.4
.3:	moveq	#0,d6		; splitting on lower part
	bset	d3,d6
	neg.l	d6
	and.l	d6,d1		; this is integer part
	moveq	#0,d4		; nothing in an upper fraction
	not.l	d6
	and.l	d6,d5		; and clear those unneded bits
.4:	movem.l	d0-d1,(a1)	; store computed integer part
	swap	d0
	exg	d0,d2		; set registers for norm_df
	clr.w	d1		; rounding = 0
;				; normalize fractional part
	bra	norm_df		; norm_df will pop d2/d7 we saved before
				; it will return to our caller via rts
				; with result in d0-d1

fpu_modf:
	fmove.d	4(sp),fp0		; load arg
	move.l	12(sp),a0		; get pointer to IP
	fintrz.x	fp0,fp1		; get int part
	fmove.d	fp1,(a0)		; return it to IP
	fsub.x	fp1,fp0		; get remainder
	fmove.d	fp0,-(sp)		; return it
	movem.l	(sp)+,d0-d1
	rts

