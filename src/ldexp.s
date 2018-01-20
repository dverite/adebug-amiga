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
	XDEF	_ldexp,___normdf,_modf

Erange	EQU	1

;FPU
fpu_ldexp:
	move.l	12(sp),d0		;get exponent
	fgetexp.d	4(sp),fp1		;extract exponent of 1st arg
	fmove.l	fp1,d1		;d1 serves as accumulator
	add.l	d0,d1		;sum of exp_s of both args

	ftwotox.l	d0,fp0		;ftwotox to fp0 (as long int!)
	fmul.d	4(sp),fp0		;fmul value,fp0
	fmove.d	fp0,-(sp)		;get double from fp0
	movem.l	(sp)+,d0-d1

	rts

;PAS DE FPU
_ldexp:	lea	4(sp),a1

	movem.l	d2-d7,-(sp)
	move.w	(a1),d0		;extract value.exp
	move.w	d0,d2		;extract value.sign
	bclr	#15,d0		;kill sign bit
	lsr.w	#4,d0

	moveq	#$f,d3		;remove exponent from value.mantissa
	and.b	d2,d3		;four upper bits of value in d3
	bset	#4,d3		;implied leading 1
	tst.w	d0		;check for zero exponent
	bne.s	.l1
	addq.w	#1,d0
	bclr	#4,d3		;nah, we do not need stinkin leadin 1
.l1:	move.w	d3,(a1)		;save results of our efforts
	ext.l	d0
	add.l	8(a1),d0		;add in exponent

	cmp.l	#-53,d0		;hmm. works only if 1 in implied position...
	ble.s	.retz		;range error - underflow
	cmp.l	#$7ff,d0
	bge.s	.rangerr		;range error - overflow

	clr.w	d1		;zero rounding bits
	movem.l	(a1),d4-d5	;value into d4,d5
	bra.s	norm_df

.retz:	moveq	#0,d0		;zero return value
	move.l	d0,d1
	lsl.w	#1,d2		;transfer argument sign
	roxr.l	#1,d0
	bra.s	.end

.rangerr:	movem.l	__infinitydf,d0-d1 ;return HUGE_VAL (same as in <math.h>)
	tst.w	d2
	bge.s	.end
	bset	#31,d0
.end:	movem.l	(sp)+,d2-d7
	rts

;PAS DE FPU
;C entry, for procs dealing with the internal representation :
;double __normdf(long long mant, int exp, int sign, int rbits);
___normdf:
	lea	4(sp),a0		; parameter pointer
	movem.l	d2-d7,-(sp)	;save working registers
	movem.l	(a0)+,d4-d5	;get mantissa

	move.l	(a0)+,d0		;get exponent
	move.l	(a0)+,d2		;get sign
	bpl.s	.plus		;or bit 31 to bit 15 for later tests
	bset	#15,d2
.plus:	move.l	(a0)+,d1		;rounding information
	move.l	#$7fff,d3
	cmp.l	d3,d0		;test exponent
	bgt	.oflow
	not.l	d3		;#-0x8000 -> d3
	cmp.l	d3,d0
	blt	.retz

;internal entry for floating point package, saves time
;d0=u.exp, d2=u.sign, d1=rounding bits, d4/d5=mantissa
;registers d2-d7 must be saved on the stack !
norm_df	EQU	*
	move.l	d4,d3		;rounding and u.mant == 0 ?
	or.l	d5,d3
	bne.s	.l1
	tst.b	d1
	beq	.retzok
.l1:	move.l	d4,d3
	and.l	#$fffff000,d3	;fast shift, 16 bits ?
	bne.s	.l2
	cmp.w	#9,d0		;shift is going to far;do normal shift
	ble.s	.l2		; (minimize shifts here : 10l = 16l + 6r)
	swap	d4		;yes, swap register halfs
	swap	d5
	move.w	d5,d4
	move.b	d1,d5		;some doubt about this one !
	lsl.w	#8,d5
	clr.w	d1
	sub.w	#16,d0		;account for swap
	bra.s	.l1
.l2:	clr.b	d2		;sticky byte
	move.l	#$ffe00000,d6
.l3:	tst.w	d0		;divide (shift)
	ble.s	.l0		; denormalized number
	move.l	d4,d3
	and.l	d6,d3		; or until no bits above 53
	beq.s	.l4
.l0:	add.w	#1,d0		;increment exponent
	lsr.l	#1,d4
	roxr.l	#1,d5
	or.b	d1,d2		;set sticky
	roxr.b	#1,d1		;shift into rounding bits
	bra.s	.l3
.l4:	and.b	#1,d2
	or.b	d2,d1		;make least sig bit sticky
	asr.l	#1,d6		;#0xfff00000 -> d6
.l5:	move.l	d4,d3		;multiply (shift) until
	and.l	d6,d3		;one in implied position
	bne.s	.l6
	subq.w	#1,d0		;decrement exponent
	beq.s	.l6		; too small. store as denormalized number
	add.b	d1,d1		;some doubt about this one *
	addx.l	d5,d5
	addx.l	d4,d4
	bra.s	.l5
.l6:	tst.b	d1		;check rounding bits
	bge.s	.l8		;round down - no action neccessary
	neg.b	d1
	bvc.s	.l7		;round up
	move.w   d5,d1		;tie case - round to even
				;dont need rounding bits any more
	and.w	#1,d1		;check if even
	beq.s	.l8		;mantissa is even - no action necessary
				;fall through
.l7:	clr.l	d1		;zero rounding bits
	addq.l	#1,d5
	addx.l	d1,d4
	tst.w	d0
	bne.s	.l00		;renormalize if number was denormalized
	addq.w	#1,d0		;correct exponent for denormalized numbers
	bra.s	.l2
.l00:	move.l	d4,d3		;check for rounding overflow
	asl.l	#1,d6		;#0xffe00000 -> d3
	and.l	d6,d3
	bne.s	.l2		;go back and renormalize
.l8:	move.l	d4,d3		;check if normalization caused an underflow
	or.l	d5,d3
	beq.s	.retz
	tst.w	d0		;check for exponent overflow or underflow
	blt.s	.retz
	cmp.w	#2047,d0
	bge.s	.oflow

	lsl.w	#5,d0		;re-position exponent - one bit too high
	lsl.w	#1,d2		;get X bit
	roxr.w	#1,d0		;shift it into sign position
	swap	d0		;map to upper word
	clr.w	d0
	and.l	#$0fffff,d4	;top mantissa bits
	or.l	d0,d4		;insert exponent and sign
	move.l	d4,d0
	move.l	d5,d1
	movem.l	(sp)+,d2-d7
	rts

.retz:	moveq	#Erange,d0
	move.w	d0,Errno
.retzok:	moveq	#0,d0		;return zero value
	move.l	d0,d1
	lsl.w	#1,d2		;set value of extension
	roxr.l	#1,d0		;and move it to hight bit of d0
.end:	movem.l	(sp)+,d2-d7
	rts

.oflow:	movem.l	__infinitydf,d0-d1	;return infinty value
	tst.w	d2
	bpl.s	.end
	bset	#31,d0
	bra.s	.end

BIAS8	=	$3ff - 1

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

;actuellement, le code inline de <math-68881.h> est utilise
;au lieu de celui-la
fpu_modf:
	fmove.d	4(sp),fp0		; load arg
	move.l	12(sp),a0		; get pointer to IP
	fintrz.x	fp0,fp1		; get int part
	fmove.d	fp1,(a0)		; return it to IP
	fsub.x	fp1,fp0		; get remainder
	fmove.d	fp0,-(sp)		; return it
	movem.l	(sp)+,d0-d1
	rts


__infinitydf:
	dc.l	$7ff00000,0

	BSS
Errno:	ds.w	1
