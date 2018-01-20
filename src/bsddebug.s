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
	XREF	_CBsdGetSrcName,_CBsdGetSource,_CBsdGetCodeAddr
	XREF	_CBsdGetMod,_CBsdGetCurScope,_CBsdUpdateGlobals
	XREF	_CBsdPrintVar,_CBsdAllocLocals,_CBsdAllocStatics
	XREF	_CBsdBuildLocalsArray,_CBsdBuildStaticsArray

	XDEF	bsdfind_ld_sym

	rsreset
SRC_MOD:		rs.l	1	;struct Module*
SRC_BLKSTRT:	rs.l	1	;ulong blkstrt
SRC_BLKSZ:	rs.l	1	;ulong blksz
SRC_SIZEOF:	rs.w	0

;In:
;d0=adresse binaire
;Out:
;d0=@ source
;d1=# de ligne
bsdget_source_addr:
	movem.l	d3-d7/a2-a5,-(sp)
	sub.l	text_buf(a6),d0
	bmi	.error_2
	cmp.l	text_size(a6),d0
	bgt	.error_2
	lea	-SRC_SIZEOF(sp),sp
	move.l	sp,a2
	move.l	a2,-(sp)	;SRC*
	move.l	d0,-(sp)
	jsr	_CBsdGetSource	;out:d0=line#
	move.l	SRC_MOD(a2),a0	;struct Module*
	move.l	SRC_BLKSTRT(a2),a5	;offset debut de bloc
	move.l	SRC_BLKSZ(a2),d2	;taille du bloc
	lea	SRC_SIZEOF+8(sp),sp
	subq.l	#1,d0
	bmi	.error_2
	move.l	d0,a3
	add.l	text_buf(a6),a5
	cmp.l	SrcCurModPtr(a6),a0
	beq.s	.already_loaded
	move.l	a0,SrcCurModPtr(a6)
	bsr	bsdget_source_name
	move.l	a0,source_name_addr(a6)
	move.l	main_source_ptr(a6),d0
	move.l	d0,source_ptr(a6)
	beq.s	.error
	move.l	d0,a1
	moveq	#-1,d0
	moveq	#-1,d1
	moveq	#-1,d2
	bsr	load_file
	bmi.s	.error
	move.l	d0,source_len(a6)
	move.l	source_ptr(a6),a0
	move.l	a0,a1
	add.l	d0,a1
	bsr	count_source_lines
	move.l	d0,source_lines_nb(a6)

	lea	src_line_format_buf(a6),a0
	move.l	d0,-(sp)
	pea	decimal_format_text
	bsr	sprintf3
	addq.w	#8,sp	
	move.w	d0,-(sp)
	lea	src_line_format_text,a1
	exg	a0,a1
	bsr	strcpy3
	moveq	#'0',d0
	add.w	(sp)+,d0
	move.b	d0,2(a1)
.already_loaded:
	move.l	a3,d0
	move.l	source_ptr(a6),a0
	move.l	source_len(a6),d1
	bsr	get_source_line
.end:	move.l	a5,a1
	tst.l	d0
	movem.l	(sp)+,d3-d7/a2-a5
	rts
.error:	clr.l	source_name_addr(a6)
.error_2:	moveq	#0,d0
	bra.s	.end

;In: a0=@struct module
bsdget_mod_name:
bsdget_source_name:
	move.l	a0,-(sp)
	jsr	_CBsdGetSrcName
	addq.l	#4,sp
	move.l	d0,a0
	rts

;renvoie l'adresse du binaire correspondant a la ligne de source pointee par a0
;In:
;a0=source addr
;Out:
;d0=code addr
;a0=module ptr
bsdget_code_addr:
	movem.l	d3-d7/a2-a5,-(sp)
	move.l	source_ptr(a6),a1
	move.l	a1,d0
	beq.s	.error
	cmp.l	a1,a0
	blt.s	.error
	exg	a0,a1
	bsr	count_source_lines
	move.l	SrcCurModPtr(a6),-(sp)
	addq.l	#1,d0
	move.l	d0,-(sp)	;line #
	jsr	_CBsdGetCodeAddr
	addq.l	#8,sp
	tst.l	d0
	bmi.s	.error
	add.l	text_buf(a6),d0
.end:	movem.l	(sp)+,d3-d7/a2-a5
	rts
.error:	moveq	#0,d0
	bra.s	.end

bsdupdate_source:
	movem.l	d2/d6/d7/a2,-(sp)
	moveq	#0,d7
	moveq	#0,d6
	subq.l	#4,sp

.l1:	move.l	d6,(sp)
	jsr	_CBsdGetMod
	move.l	d0,a0
	bsr	bsdget_source_name
	move.l	a0,a2
	moveq	#-1,d0
	bsr	find_file
	bne.s	.next		;pas trouve, tant pis
	tst.b	src_checkmodtime_flag(a6)
	beq.s	.chcksz
	lea	exec_timestamp(a6),a0
	lea	my_dta+DTA_TIME(a6),a1
	bsr	CmpDates
	blo.s	.warn
.chcksz:	cmp.l	my_dta+DTA_SIZE(a6),d7
	bhs.s	.next
	move.l	my_dta+DTA_SIZE(a6),d7
.next:	addq.l	#1,d6
	cmp.l	BsdNbMods(a6),d6
	blo.s	.l1

	move.l	d7,d0
	st	d1
	moveq	#2,d2
	jsr	reserve_memory
	bne.s	.ok
	moveq	#0,d7
.ok:	move.l	d0,main_source_ptr(a6)
	move.l	d7,main_source_len(a6)
	addq.l	#4,sp
	movem.l	(sp)+,d2/d6/d7/a2
	rts

.warn:	move.l	a2,-(sp)		;src name
	pea	src_more_recent_format
	lea	line_buffer(a6),a2
	move.l	a2,a0
	_JSR	sprintf
	addq.l	#8,sp
	bsr	print_press_key
	bra.s	.chcksz

;Input: a0=source_addr,d0=line nb
;Output: d0=-1->not code,=0->code
bsdcheck_if_code:
	move.l	source_ptr(a6),d1
	beq.s	.error
	cmp.l	d1,a0
	blt.s	.error
	move.l	SrcCurModPtr(a6),-(sp)
	addq.l	#1,d0
	move.l	d0,-(sp)
	jsr	_CBsdGetCodeAddr	;-1->no code
	addq.l	#8,sp
	tst.l	d0
	bmi.s	.end
	moveq	#0,d0
.end:	rts
.error:	moveq	#-1,d0
	rts

;In: a0=@
bsdget_next_code_addr:
	movem.l	d3-d7/a2,-(sp)
	move.l	a0,d3
	move.l	a0,d7
	sub.l	text_buf(a6),d7
	bmi	.error
	cmp.l	text_size(a6),d7
	bgt	.error
	lea	-SRC_SIZEOF(sp),sp
	move.l	sp,a2
	move.l	a2,-(sp)	;SRC*
	move.l	d7,-(sp)
	jsr	_CBsdGetSource	;out:d0=line#
	addq.l	#8,sp
	move.l	SRC_MOD(a2),a0	;struct Module*
	move.l	SRC_BLKSTRT(a2),d4	;offset debut de bloc
	add.l	text_buf(a6),d4
	move.l	d4,d6
	add.l	SRC_BLKSZ(a2),d6
	move.l	d6,d4		;@fin de bloc
	sub.l	d3,d6		;longueur restant a scanner
	lea	SRC_SIZEOF(sp),sp
	subq.l	#1,d0
	bmi	.error		;offset pas trouve !

	moveq	#0,d5		;retour par defaut

	;y-a-t-il un jsr ds le bloc courant?
	;oui, alors renvoyer l'@ de branchement du jsr et d5 a 1
.sameblk:	move.l	d3,a0
	bsr	get_instr_type
	bne.s	.chck
.again:	add.l	d2,d3
	sub.l	d2,d6
	ble.s	.end
	bra.s	.sameblk
.chck:	cmp.w	#4,d0		;trap/linea/linef/
	blt.s	.no_action
	cmp.w	#11,d0
	blt.s	.branch
.rts:	add.l	text_buf(a6),d7	;rts/rte/rtr
	cmp.l	d3,d7
	beq.s	.no_action

.end:	move.l	d3,a0
	move.l	d5,d0
.end2:	movem.l	(sp)+,d3-d7/a2
	rts
.error:
.no_action:
	moveq	#-1,d5
	bra.s	.end
.branch:	cmp.w	#8,d0		;bsr/jsr/bcc/dbcc/jmp
	bhi.s	.again
	move.l	d3,d1
	move.l	a0,a1
	move.l	d4,a0
	moveq	#1,d0
	bra.s	.end2

bsdbegin_source_debug:
	movem.l	d2/a2,-(sp)
	pea	d0_buf(a6)
	pea	globals_array_ptr(a6)
	jsr	_CBsdUpdateGlobals
	addq.l	#8,sp
	move.l	d0,globals_nb(a6)
	jsr	_CBsdAllocLocals		;retourne CSYMP **LocsTab
	jsr	_CBsdAllocStatics		;retourne CSYMP **StaticsTab
	tst.b	src_untilmain_flag(a6)	;run until main
	beq.s	.end
	lea	bsd_main_var_text,a2
	move.w	#LAWORD,d0
	moveq	#0,d1
	moveq	#0,d2
	bsr	find_in_table
	bmi.s	.end
	cmp.l	text_buf(a6),d1
	beq.s	.end
	move.l	d1,a0
	jsr	__ctrl_a
	bmi.s	.end
	jsr	p0p1
.end:	movem.l	(sp)+,d2/a2
	rts

bsdupdate_vars_array:
	move.l	pc_buf(a6),d0
	sub.l	text_buf(a6),d0
	cmp.l	text_size(a6),d0
	bhs.s	.end
	move.l	d0,-(sp)
	jsr	_CBsdGetCurScope
	addq.l	#4,sp
	pea	locals_array_ptr(a6)
	move.l	d0,-(sp)		;SCOPE* (pas touche par la routine)
	jsr	_CBsdBuildLocalsArray
	move.l	d0,locals_nb(a6)
	lea	statics_array_ptr(a6),a0
	move.l	a0,4(sp)
	jsr	_CBsdBuildStaticsArray
	addq.l	#8,sp
	move.l	d0,statics_nb(a6)
.end:	rts

;cherche le symbole '_toto' correspondant a 'toto' en global
;In: a0=@nom
;Out: d0=valeur ou 0 (ambigu mais pas genant)
bsdfind_ld_sym:
	movem.l	a2-a4,-(sp)
	move.l	a0,a2
	move.l	current_var_addr(a6),a4
	move.l	table_var_addr(a6),a3
	tst.l	current_var_nb(a6)
	ble.s	.nf
	subq.l	#6,a3
.nx:	addq.l	#6,a3
	cmp.l	a3,a4
	ble.s	.nf
	move.l	(a3)+,a0	;@asciiz symbole
	move.l	a2,a1
	bsr.s	.varcmp
	bne.s	.nx
	cmp.w	#LAWORD,(a3)
	bne.s	.nx
	move.l	2(a3),d0		;valeur
.end:	movem.l	(sp)+,a2-a4
	rts
.nf:	moveq	#0,d0
	bra.s	.end

.varcmp:	cmp.b	#'_',(a0)+
	bne.s	.rts
.l1:	move.b	(a0)+,d0
	beq.s	.send1
	move.b	(a1)+,d1
	beq.s	.send2
	cmp.b	d0,d1
	beq.s	.l1
	rts
.send1:	tst.b	(a1)+
	rts
.send2:	moveq	#-1,d0
.rts:	rts

;In:
;a0=var addr
;a1=buffer
;a2=window struct
;d0=shifting value
bsdprint_source_var:
	ext.l	d0
	move.l	d0,-(sp)
	move.l	curwind_columns(a6),d0
	addq.l	#2,d0
	move.l	d0,-(sp)
	move.l	a1,-(sp)
	move.l	a0,-(sp)
	jsr	_CBsdPrintVar	;>d0
	move.l	4(sp),a0		;buffer
	move.l	a2,a1		;window @
	move.l	12(sp),d1	;shift
	lea	16(sp),sp
	bra	_print_source_var
