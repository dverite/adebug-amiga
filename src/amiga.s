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
SHUNT_BSD_DEBUG	EQU	1

;rethink_display:  ; interne aux routines amiga
set_system_break:
get_system_break_name:
ctrl_alt_d:
	rts
ZMAGIC	EQU	$10b

;	XDEF	_ixemulbase
	XDEF	reserve_memory,free_memory,_internal_a6
	XREF	_CGetBsdDebug
	XREF	_SysBase	;a virer

;		#[ Amiga_init:
machine_init:
	sf	CopListFlg(a6)	;affichage par screen
	move.l	4.w,a0
	move.l	a0,ExecBase(a6)
	move.l	a0,_SysBase		;a virer (libgcc)
	move.l	internal_usp(a6),a0
	move.l	(a0)+,internal_return_addr(a6)
	move.l	(a0),amiga_stack_size(a6)
	OPENLIB	dos_name
	move.l	d0,dosbase(a6)
	OPENLIB	gfx_name
	move.l	d0,gfxbase(a6)
	move.l	d0,a0
	move.l	$26(a0),external_copperlist(a6)
	OPENLIB	intui_name
	move.l	d0,intuibase(a6)
	move.l	d0,a0	
	move.l	-$15c+2(a0),system_autoreq(a6)

	suba.l	a1,a1
	CALLEXEC FindTask
	move.l	d0,Adebug_task(a6)
	move.l	d0,a0
	tst.l	pr_CLI(a0)
	seq	WBstart_flag(a6)
	bsr	save_task_struct
	move.l	Adebug_task(a6),a0
	move.l	#adebug_task_name,ln_name(a0)
	moveq	#-1,d0
	move.l	d0,pr_WindowPtr(a0)
	bsr	add_vbl_server
	bsr	put_adebug_clav
	st	mid_rez(a6)
	move.w	#256,screen_size_y(a6)
	move.w	#80,line_size(a6)
	move.w	#79,line_len(a6)
	IFNE	amigarevue
	move.l	#end_of_data,protec_addr(a6)
	move.l	#protec1-25000,protec_routine_1(a6)
	move.l	#protec2-25000,protec_routine_2(a6)
	ENDC
	move.w	#31,column_len(a6)
	move.w	#32,w3len(a6)
	move.l	#amiga_font,font8x8_addr(a6)
	move.l	#amiga_font,font_addr(a6)

	lea	keytbl_descriptor(a6),a0
	move.l	a0,keytbl_addr(a6)
	lea	ascii_table,a1
	move.l	a1,(a0)+
	move.l	a1,keys_table1(a6)
	lea	128(a1),a1
	move.l	a1,(a0)+
	move.l	a1,keys_table2(a6)
	lea	128(a1),a1
	move.l	a1,(a0)
	move.l	a1,keys_table3(a6)

	tst.b	CopListFlg(a6)
	bne.s	.coplist
; affichage par screen
	lea	NewScreenStruct(pc),a0
	CALLINT	OpenScreen
	move.l	d0,IntuiScr(a6)
	beq	.exit_in_super
	move.l	d0,a0
	move.l	sc_BitMap+bm_Planes(a0),physbase(a6)
	bra.s	.hard

.coplist:	move.l	#taille_copperlist,d0
	moveq	#2,d1
	CALLEXEC	AllocMem
copstop	equ	*
	move.l	d0,internal_copperlist(a6)
	beq	.exit_in_super
	st	coplist_allocation_flag(a6)
	move.l	d0,a0
	bsr	update_copperlist
	st	copper_active(a6)
;allouer l'ecran
	move.l	#AMIGA_NB_LINES*LINE_SIZE,d0
	moveq	#2,d1
	CALLEXEC	AllocMem
	tst.l	d0
	beq	.exit_in_super
.good2:	move.l	d0,initial_physbase(a6)
	move.l	d0,physbase(a6)
; clearer l'ecran
	move.l	d0,a0
	st	screen_allocation_flag(a6)
	move.w	#AMIGA_NB_LINES*LINE_SIZE/4-1,d0
	moveq	#0,d1
.l1:	move.l	d1,(a0)+
	dbf	d0,.l1

.hard:	lea	custom,a0
	move.w	intenar(a0),d0
	move.w	d0,external_intena(a6)
	move.w	d0,initial_intena(a6)
	move.w	d0,internal_intena(a6)
	move.w	dmaconr(a0),d0
	move.w	d0,external_dmacon(a6)
	move.w	d0,initial_dmacon(a6)
	move.w	d0,internal_dmacon(a6)
	bsr	timers_init
;divers
	bsr	machine_cmd_line
	bsr	Memory_detection

; Guru logiciel
	move.l	ExecBase(a6),a1
	move.w	#-$6c,a0
	move.l	#my_alert,d0
	CALLEXEC	SetFunction
	move.l	d0,initial_alert_addr(a6)

	st	d0
	bsr	set_windows
	moveq	#1,d0
	move.l	d0,device_number(a6)
	st	vbl_stop_flag(a6)
	move.l	ExecBase(a6),a0
	move.l	Supervisor+2(a0),exec_supervisor(a6)
	cmp.w	#34,LIB_VERSION(a0)
	sgt	kick2x_flag(a6)
	bls.s	.attn_pas_bon
	bsr.s	.get_exec_chip
.attn_pas_bon:
	bsr	recup_keymap
	IFNE	amiga_avbl
	move.l	$6c.w,external_vbl(a6)
	ENDC
	moveq	#-1,d0
	CALLEXEC	AllocSignal
	tst.b	d0
	bmi.s	.nosig
	moveq	#1,d1
	lsl.l	d0,d1
	move.l	d1,sftalthelp_msk(a6)
.nosig:	rts

.exit_in_super:
	jmp	exit_in_super

;a0={4}
;retrouve chip_type a partir du systeme en attendant
;une routine de reconnaissance beton
.get_exec_chip:
	move.b	AttnFlags+1(a0),d0
	and.b	#$f,d0
;	1->68010,3->20,7->30,15->40
	moveq	#1,d1
	subq.b	#1,d0
	beq.s	.out_chip
	addq.b	#1,d1
	subq.b	#2,d0
	beq.s	.out_chip
	addq.b	#1,d1
	subq.b	#4,d0
	beq.s	.out_chip
	addq.b	#1,d1
	subq.b	#8,d0
	beq.s	.out_chip
	moveq	#0,d1
.out_chip:
	move.b	d1,chip_type(a6)
	IFNE	A3000
	move.b	#1,fpu_type(a6)		;FIXME
	ELSE
	clr.b	fpu_type(a6)
	ENDC
	rts

safe_getbyte_a3:
	move.l	a1,-(sp)
	move.l	a3,a1
	bsr	amig_test_if_readable3
	tst.b	readable_buffer(a6)
	bne.s	.end
	move.b	(a3),d0
.end:	addq.w	#1,a3
	move.l	(sp)+,a1
	rts

;pas de BSS a ce stade
;reception du message workbench si present
;renvoie 0 si OK
amiga_start1:
	move.l	a6,-(sp)
	move.l	4.w,a6
	suba.l	a1,a1
	jsr	FindTask(a6)
	move.l	d0,a2
	tst.l	pr_CLI(a2)
	bne.s	.cli
	lea	$5c(a2),a0
	jsr	WaitPort(a6)
	lea	$5c(a2),a0
	jsr	GetMsg(a6)
.cli:	moveq	#0,d0
	move.l	(sp)+,a6
	rts

;quelques inits qu'il faut faire tout de suite
;la BSS est allouee a ce stade
amiga_start2:
	move.l	a6,internal_a6
	move.l	a6,-(sp)
	move.l	4.w,a6
	IFNE	A3000
	tst.b	AttnFlags+1(a6)
	beq.s	._end
	lea	.get_vbr(pc),a5
	jsr	Supervisor(a6)
	ENDC
._end:	moveq	#0,d0
.out:	move.l	(sp)+,a6
	rts
	IFNE	A3000
.get_vbr:	_30
	move.l	internal_a6,a1
	movec	vbr,a0
	move.l	a0,internal_vbr(a1)		;VBR systeme
	pmove	tc,tc_buf(a1)		;TC systeme
	move.l	tc_buf(a1),initial_tc(a1)
	pea	$00800000
	pmove	(sp),tc			;aveugle Enforcer
	addq.l	#4,sp
	_00
	rte
	ENDC

	IFNE	amigarevue
protec1:	movem.l	d0/d1,-(sp)
	moveq	#0,d1
	move.l	d1,d0
	move.l	protec_addr(a6),a0
	sub.l	#end_of_data-present_adebug_format,a0
	move.b	(a0)+,d0
	beq.s	.end
.l1:	add.l	d0,d1
	ror.l	#1,d1
	move.b	(a0)+,d0
	bne.s	.l1
	move.l	d1,protec_checksum(a6)
.end:	movem.l	(sp)+,d0/d1
protec2:	rts
	ENDC ; de amigarevue

supexec:	move.l	a0,a1
	bsr	super_on
	move.l	d0,supexec_ssp(a6)
	jsr	(a1)
	move.l	supexec_ssp(a6),d0
	beq.s	.end
	move.l	d0,a0
	bra	super_off
.end:	rts

rethink_display:
	lea	custom,a0
	move.w	internal_dmacon(a6),d0
	bset	#15,d0
	move.w	d0,dmacon(a0)
	not.w	d0
	move.w	d0,dmacon(a0)
	rts

put_adebug_clav:
	movem.l	a2/a5,-(sp)
	lea	inputdev_name,a1
	CALLEXEC	FindTask
	move.l	d0,inputdev_task(a6)
	move.l	ExecBase(a6),a5
	lea	$150(a5),a0
	lea	ciaares_name,a1
	CALLEXEC	FindName
	move.l	d0,ciaares(a6)
	lea	$15e(a5),a0
	lea	keybdev_name,a1
	CALLEXEC	FindName
	move.l	d0,keybdev(a6)
	lea	$15e(a5),a0
	lea	inputdev_name,a1
	CALLEXEC	FindName
	move.l	d0,inputdev(a6)
	lea	$15e(a5),a0
	lea	gameportdev_name,a1
	CALLEXEC	FindName
	move.l	d0,gameportdev(a6)
;installation handler input.device
	lea	reply_port(a6),a2
	moveq	#-1,d0
	CALLEXEC	AllocSignal
	move.b	d0,MP_SIGBIT(a2)
	move.b	#NT_MSGPORT,ln_type(a2)
	move.b	#PA_SIGNAL,MP_FLAGS(a2)
	suba.l	a1,a1
	CALLEXEC	FindTask
	move.l	d0,MP_SIGTASK(a2)
	move.l	a2,a1
	CALLEXEC	AddPort
	move.l	d0,input_req+IO_DEVICE(a6)

	moveq	#0,d0
	move.l	d0,d1
	lea	inputdev_name,a0
	lea	input_req(a6),a1
	CALLEXEC	OpenDevice
	move.l	a2,input_req+MN_REPLYPORT(a6)
;place le handler
	lea	input_int(a6),a2
	move.l	#input_handler,IS_CODE(a2)
	clr.l	IS_DATA(a2)
	move.b	#127,ln_pri(a2)
	lea	input_req(a6),a1
	move.l	a2,IO_DATA(a1)
	move.w	#IND_ADDHANDLER,IO_COMMAND(a1)
	CALLEXEC	DoIO
	movem.l	(sp)+,a2/a5
	rts

amiga_desinit:
	move.l	a2,-(sp)
	tst.b	CopListFlg(a6)
	bne.s	.noscr
	move.l	IntuiScr(a6),d0
	beq.s	.noscr		;secur
	move.l	d0,a0
	CALLINT	CloseScreen
.noscr:	move.l	ExecBase(a6),a0
	moveq	#-1,d0
	move.w	d0,IDNestCnt(a0)
;retire le handler input.device
	lea	input_int(a6),a2
	lea	input_req(a6),a1
	move.l	a2,IO_DATA(a1)
	move.w	#IND_REMHANDLER,IO_COMMAND(a1)
	CALLEXEC	DoIO
	lea	input_req(a6),a1
	CALLEXEC	CloseDevice
	lea	reply_port(a6),a2
	move.b	MP_SIGBIT(a2),d0
	CALLEXEC	FreeSignal
	move.l	a2,a1
	CALLEXEC	RemPort
	move.l	(sp)+,a2
	rts

add_vbl_server:
	move.l	#300,d0
	moveq	#0,d1
	moveq	#3,d2
	jsr	reserve_memory
	tst.l	d0
	beq.s	.err
	move.l	d0,server_vbl(a6)
	move.l	d0,a2
	add.l	#32,d0
	move.l	d0,14(a2) ; is_data
	clr.b	9(a2) ; ln_pri
	clr.l	10(a2)
	move.b	#2,8(a2) ; ln_type
	move.l	#my_vbl,18(a2) ; is_code
	moveq	#5,d0
	move.l	a2,a1
	CALLEXEC	AddIntServer
	moveq	#0,d0
	rts
.err:	moveq	#-1,d0
	rts

my_autoreq:
	movem.l	d0/a0/a6,-(sp)
	GETA6
	tst.b	screen0_flag(a6)
	seq	-(sp)		;deja ecran user ?
	beq.s	.already
	sf	screen0_flag(a6)
	move.l	gfxbase(a6),a0
	move.l	$26(a0),d0
	move.l	external_copperlist(a6),external_tmp_copperlist(a6)
	move.l	d0,external_copperlist(a6)
	lea	custom,a0
	move.l	d0,$80(a0)
	clr.w	$88(a0)
	move.w	initial_dmacon(a6),d0
	bset	#15,d0
	move.w	d0,dmacon(a0)
	not.w	d0
	move.w	d0,dmacon(a0)
.already:	pea	.suite(pc)
	move.l	system_autoreq(a6),-(sp)
	movem.l	10(sp),d0/a0/a6
	rts 	; saut
.suite:	tst.b	(sp)+
	beq.s	.chg_screen	;remettre screen 0
	lea	12(sp),sp
	bra.s	.end
.chg_screen:
	movem.l	d0/a0/a6,-(sp)
	GETA6
	st	screen0_flag(a6)
	lea	custom,a0
	tst.b	copper_active(a6)
	beq.s	.no_copper
	move.l	external_tmp_copperlist(a6),external_copperlist(a6)
	move.l	internal_copperlist(a6),$80(a0)
	clr.w	$88(a0)
.no_copper:
	move.w	internal_dmacon(a6),d0
	bset	#15,d0
	move.w	d0,dmacon(a0)
	not.w	d0
	move.w	d0,dmacon(a0)
	movem.l	(sp),d0/a0/a6
	lea	24(sp),sp
.end:	rts

machine_cmd_line:
	move.l	initial_regs+8*4(a6),a1
	move.l	a1,a2
	moveq	#10,d0
	moveq	#0,d1
.l1:	addq.w	#1,d1
	cmp.b	(a2)+,d0
	bne.s	.l1
	lea	argv_buffer(a6),a0
	subq.w	#2,d1
	bmi.s	.end
.l2:	move.b	(a1)+,(a0)+
	dbf	d1,.l2
.end:	clr.b	(a0)
	rts

system_off:
	tst.b	CopListFlg(a6)
	bne.s	.copper
	move.l	IntuiScr(a6),d0
	beq.s	.copper		;secur
	move.l	d0,a0
	CALLINT	ScreenToFront
.copper:	lea	custom,a0
	move.w	dmaconr(a0),external_dmacon(a6)
	tst.b	copper_active(a6)
	beq.s	.dma
	move.l	internal_copperlist(a6),cop1lc(a0)
	clr.w	copjmp1(a0)
.dma:	move.w	internal_dmacon(a6),d0
	bset	#15,d0
	move.w	d0,dmacon(a0)
	not.w	d0
	move.w	d0,dmacon(a0)
	rts

system_on:
	tst.b	CopListFlg(a6)
	bne.s	.copper
	move.l	IntuiScr(a6),d0
	beq.s	.copper		;secur
	move.l	d0,a0
	CALLINT	ScreenToBack
.copper:	lea	custom,a0
	tst.b	copper_active(a6)
	beq.s	.dma
	move.l	external_copperlist(a6),cop1lc(a0)
	clr.w	copjmp1(a0)
.dma:	move.w	external_dmacon(a6),d0
	bset	#15,d0
	move.w	d0,dmacon(a0)
	not.w	d0
	move.w	d0,dmacon(a0)
	rts

;		#] Amiga_init:
;  #[ Guru:
my_alert:	SWITCHA6
	move.l	internal_vbr(a6),a0
	move.l	$20(a0),long_buffer(a6)
	move.l	#.except,$20(a0)
	or.w	#$2000,sr
	move.l	long_buffer(a6),$20(a0)
	move.b	#-3,exception(a6) ; non utilise
	subq.w	#6,sp
	clr.w	(sp)
	move.l	initial_alert_addr(a6),a0
	move.l	a0,2(sp)
	bra	p1p0
.except:	or.w	#$2000,(sp)
	rte

treat_guru:
	move.l	a5_buf(a6),d0
	btst	#0,d0
	beq.s	.pair
	moveq	#0,d0
	bra.s	.suite
.pair:	move.l	d0,a0
	move.l	(a0),d0
.suite:	move.l	d0,-(sp)
	move.l	d7_buf(a6),-(sp)
	pea	guru_text
	lea	lower_level_buffer(a6),a2
	move.l	a2,a0
	jsr	sprintf
	lea	12(sp),sp
	bra	print_result
;  #] Guru:

;  #[ Vbl:
my_vbl:	movem.l	d1/a0/a6,-(sp)
	GETA6
	addq.l	#1,vbl_counter(a6)
;chez moi ?
	tst.b	profiler_flag(a6)
	beq.s	.not_in_clip
	tst.b	p_number(a6)
	beq.s	.not_in_clip
	tst.b	valid_var_tree_flag(a6)
	beq.s	.not_in_clip
	lea	$34(sp),a1
	tst.b	kick2x_flag(a6)
	beq.s	.kick1
	addq.w	#6,a1
.kick1:	move.l	(a1),a1
	tst.b	unclip_profile_flag(a6)
	bne.s	.in_clip
	bsr	test_if_in_prg
	bne.s	.not_in_clip
.in_clip:	move.l	var_tree_nb(a6),d0
	move.l	var_tree_addr(a6),d1
	lea	comp_var_tree_2,a0
	jsr	_trouve
	bpl.s	.symbol_found
	tst.l	exec_sym_nb(a6)
	beq.s	.not_in_clip
	move.l	var_tree_nb(a6),d0
	subq.l	#1,d0
	bmi.s	.not_in_clip
	move.l	var_tree_addr(a6),a0
	mulu	#VAR_TREE_SIZE,d0
	add.l	d0,a0
.symbol_found:
	addq.l	#1,VAR_TREE_COUNT(a0)
.not_in_clip:
	tst.b	copper_active(a6)
	bne.s	.suite		;copper actif
	tst.b	CopListFlg(a6)
	beq.s	.suite		;en screen
	tst.b	p_number(a6)
	bne.s	.suite
	tst.b	screen0_flag(a6)
	beq.s	.suite
	; move VBL
	lea	custom,a0
	move.l	physbase(a6),bpl1pt(a0) 
	move.w	color0_value+2(a6),$180(a0)
	move.w	color1_value+2(a6),$182(a0)
	move.w	#%1001001000000000,bplcon0(a0)
	moveq	#0,d0
	move.l	d0,bplcon1(a0)
	move.l	#$003c00d4,ddfstrt(a0)
	move.l	#$298129c1,diwstrt(a0)
	move.l	d0,bpl1mod(a0)
	move.l	d0,$144(a0) ; sprite 0
	move.w	#$20,dmacon(a0)
.suite:
	IFNE	daniel_version
;swap d'ecran ([Amg_Amd])
	tst.b	CopListFlg(a6)
	beq.s	.no_copper_chg
	move.b	stat_spec_keys(a6),d0
	and.b	#$cf,d0
	cmp.b	#$c0,d0
	bne.s	.no_copper_chg
	clr.b	stat_spec_keys(a6)
	not.b	.debug_screen_flag
	beq.s	.our_screen
	move.l	external_copperlist(a6),$dff080
	clr.w	$dff088
	move.w	initial_dmacon(a6),d0
	bset	#15,d0
	move.w	d0,$dff096
	not.w	d0
	move.w	d0,$dff096
	bra.s	.no_copper_chg
.our_screen:
	move.l	internal_copperlist(a6),d0
	beq.s	.no_copper_chg
	move.l	d0,$dff080
	clr.w	$dff088
.no_copper_chg:
	ENDC	;de daniel_version

;[Sft_Amg_Amd_Sft]
	IFNE	daniel_version
	tst.b	vbl_stop_flag(a6)
	beq.s	.no_stop
	ENDC
	tst.b	stop_req_flag(a6)
	beq.s	.no_stop
	tst.b	p_number(a6)
	beq.s	.no_stop
	move.l	ExecBase(a6),a0
	move.l	ThisTask(a0),a0
;ne pas arreter l'input.device
	cmp.l	inputdev_task(a6),a0
	beq.s	.no_stop
	tst.b	trace_task_flag(a6)
	bne.s	.taskflag_ok
	tst.b	multitask_access_flag(a6)
	bne.s	.taskflag_ok
;ne pas arreter d'autre tache qu'Adebug (p1)...
	cmp.l	Adebug_task(a6),a0
	beq.s	.taskflag_ok
;...sauf si on est en idle
	cmp.b	#2,tc_State(a0)
	beq.s	.no_stop
.taskflag_ok:
	lea	$34(sp),a0	;a voir
	tst.b	kick2x_flag(a6)
	beq.s	.kick_ok
	addq.w	#6,a0
.kick_ok:	move.b	-2(a0),d0	;ipl appelant
	and.b	#$f,d0
	bne.s	.no_stop	;on ne coupe pas une interruption
	move.l	(a0),amiga_stop_address(a6)
	move.l	#vbl_stop_routine,(a0)
	move.w	-2(a0),amiga_stop_sr(a6)
	or.w	#$2700,-2(a0)
	st	amiga_stop_flag(a6)
	sf	stop_req_flag(a6)
.no_stop:	movem.l	(sp)+,d1/a0/a6
	moveq	#0,d0
	rts
	IFNE	daniel_version
.debug_screen_flag:	dc.w	0
	ENDC

vbl_stop_routine:
	SWITCHA6
	IFNE	_68030
	tst.b	chip_type(a6)
	beq.s	.68000
	clr.w	-(sp)	;null stack frame
.68000:	ENDC	;_68030
	move.l	amiga_stop_address(a6),-(sp)
	move.w	amiga_stop_sr(a6),-(sp)
	RESTOREA6
	bra	breakpt

	IFNE	amiga_avbl
always_vbl_routine:
	movem.l	d0/d1-a0/a1/a6,-(sp)
	lea	custom,a0
	move.w	intreqr(a0),d0
	and.w	intenar(a0),d0
	btst	#5,d0
	beq.s	.end
	move.w	#$20,intreq(a0)
	GETA6
	tst.b	always_vbl_flag(a6)
	beq.s	.end
	tst.b	copper_active(a6)
	bne.s	.end
	tst.b	p_number(a6)
	bne.s	.end
	tst.b	screen0_flag(a6)
	beq.s	.end
	move.l	physbase(a6),bpl1pt(a0) 
	move.w	color0_value+2(a6),$180(a0)
	move.w	color1_value+2(a6),$182(a0)
	move.w	#%1001001000000000,bplcon0(a0)
	moveq	#0,d0
	move.l	d0,bplcon1(a0)
	move.l	#$003c00d4,ddfstrt(a0)
	move.l	#$298129c1,diwstrt(a0)
	move.l	d0,bpl1mod(a0)
	move.l	d0,$144(a0) ; sprite 0
	move.w	#$20,dmacon(a0)
.end:	movem.l	(sp)+,d0/d1-a0/a1/a6
	rte
	ENDC	;de amiga_avbl

;  #] Vbl:

;  #[ Put_internal_Intena:
;--INPUT--
; d0 nouvelle intena interne
put_internal_intena:
	IFNE	amiga_avbl
	tst.b	always_vbl_flag(a6)
	beq.s	.not_always_vbl
	move.w	#$4020,d0
	move.w	d0,internal_intena(a6)
	move.l	#always_vbl_routine,$6c.w
	bra.s	in_put_internal_intena
.not_always_vbl:
	ENDC	;de amiga_avbl
	tst.w	d0
	bpl.s	.upper_ok
	moveq	#-1,d0
	rts
.upper_ok:
	move.l	ExecBase(a6),a0
	tst.b	TDNestCnt(a0)
	bmi.s	.TD_ok
	bclr	#14,d0
	bra.s	.idev_ok
.TD_ok:	tst.b	no_inputdev_flag(a6)
	beq.s	.idev_ok
	bclr	#3,d0
.idev_ok:	cmp.w	#2,current_ipl(a6)
	bge.s	.ipl_haut
	sf	acia_ikbd(a6)
.ipl_haut:
	move.w	d0,internal_intena(a6)
	btst	#3,d0
	bne.s	.suite
	st	acia_ikbd(a6)	;pas d'int clavier
.suite:	btst	#14,d0
	bne.s	.suite1
	st	acia_ikbd(a6)	;aucune int
.ctrl_vbl:
	tst.b	copper_active(a6)
	bne.s	in_put_internal_intena
	tst.b	CopListFlg(a6)
	beq.s	in_put_internal_intena
	;desactiver l'affichage VBL si plus de VBL !
	st	copper_active(a6)
	move.l	internal_copperlist(a6),d0
	beq.s	.nocop
	move.l	d0,$dff080
	clr.w	$dff088
.nocop:	or.w	#$4080,internal_dmacon(a6)
	bsr	rethink_display
	lea	warning_vbl_message,a2
	jsr	print_press_key
	bra.s	in_put_internal_intena
.suite1:	btst	#5,d0
	beq.s	.ctrl_vbl
in_put_internal_intena:
	lea	custom,a0
	move.w	d0,intreq(a0)
	bset	#15,d0
	move.w	d0,intena(a0)
	not.w	d0
	move.w	d0,intena(a0)
	moveq	#0,d0
	rts
;  #] Put_internal_Intena:
;  #[ Update_Intena: [Alt_I]
update_intena:
	suba.l	a0,a0
	lea	update_intena_text(pc),a2
	jsr	get_expression
	bmi.s	.end
	beq.s	.suite
.err:	bsr	flash
	bra.s	update_intena
.suite:	bsr	put_internal_intena
	bne.s	.err
	jsr	redraw_all_windows
	jmp	build_lock
.end:	rts
;  #] Update_Intena
;  #[ View: [V]
view:	moveq	#2,d0
	cmp.l	device_number(a6),d0
	beq.s	.end
	tst.b	screen0_flag(a6)
	bne.s	.user
	sf	v_screen1_flag(a6)
	st	screen0_flag(a6)
; notre ecran (sbase1_sbase0)
	bra	system_off
; ecran de p1 (sbase0_sbase1)
.user:	st	v_screen1_flag(a6)
	sf	screen0_flag(a6)
	bra	system_on
.end:	rts
;  #] View:
;  #[ Screen functions:
	; #[ wait_vbl:
wait_vbl:	move.w	#$20,$dff09a
	lea	$dff01e+1,a0
.wvbl:	move.b	(a0),d0
	btst	#5,d0
	beq.s	.wvbl
	move.w	#$20,$dff09c
	btst	#5,internal_intena+1(a6)
	beq.s	.end
	move.w	#$8020,$dff09a
.end:	rts
	; #] wait_vbl:
	; #[ Sbase0_sbase1:
sbase0_sbase1:
	movem.l	d6-d7,-(sp)
	tst.b	screen0_flag(a6)
	beq.s	.end
	bsr	system_on
	sf	screen0_flag(a6)
.end:	movem.l	(sp)+,d6-d7
	rts
	; #] Sbase0_sbase1:
	; #[ Sbase1_sbase0:
sbase1_sbase0:
	movem.l	d6-d7,-(sp)
	cmp.l	#2,device_number(a6)
	beq	.end
	tst.b	screen0_flag(a6)
	bne	.end
	bsr	system_off
	st	screen0_flag(a6)
.end:	movem.l	(sp)+,d6-d7
	rts
	; #] Sbase1_sbase0:
;	 #[ Flash:
flash:	cmp.l	#2,device_number(a6)
	bne.s	.no_rs
	moveq	#7,d0
	bra	rs_put
.no_rs:	movem.l	d2/a0/a1,-(sp)
	bsr	wait_vbl
	move.w	#$fff,d1
	move.w	color0_value+2(a6),d2
	not.w	d2
	and.w	d2,d1
	move.w	d1,color0_value+2(a6)	;pour l'affchg vbl
	moveq	#0,d0
	bsr	SetColor
;attente
	move.w	#20000,d0
	tst.b	chip_type(a6)
	beq.s	.l1
	moveq	#-1,d0
.l1:	dbf	d0,.l1
	bsr	wait_vbl
	not.w	d2
	move.w	d2,color0_value+2(a6)
	moveq	#0,d0
	bsr	SetColor
.end:	movem.l	(sp)+,d2/a0/a1
	rts
;	 #] Flash:
;	 #[ Draw window:
LINE_SIZE	EQU	80
draw_window:
	tst.l	device_number(a6)
	bne.s	.__0
.___0:	rts
.__0:	tst.b	acia_ikbd(a6)
	beq.s	._1
	bsr	internal_inkey
._1:	cmp.l	#2,device_number(a6)
	beq	terminal_draw_window
	cmp.l	#3,device_number(a6)
	beq.s	.___0
	movem.l	d0-a2,-(sp)
	move.l	physbase(a6),a0
	move.w	upper_x(a6),d0
	move.w	upper_y(a6),d1
	move.w	lower_x(a6),d2
	move.w	lower_y(a6),d3
	move.w	d1,d4
	lsl.w	#3,d4
	subq.w	#5,d4 
	mulu	#LINE_SIZE,d4
	add.w	d4,a0
	move.w	d2,d6
	move.w	d0,d5
	subq.w	#1,d5
	sub.w	d5,d6
	add.w	d5,a0
	move.l	a0,-(sp)
	move.w	d3,d5
	lsl.w	#3,d5
	subq.w	#6,d5
	tst.b	current_window_flag(a6)
	bne.s	._4
	moveq	#%00000100,d4
	moveq	#%00100000,d7
._3:	move.b	d4,(a0)
	move.b	d7,0(a0,d6.w)
	lea	LINE_SIZE(a0),a0
	dbf	d5,._3
	bra.s	._5
._4:	moveq	#%00011100,d4
	moveq	#%00111000,d7
.__4:	move.b	d4,(a0)
	move.b	d7,0(a0,d6.w)
	lea	LINE_SIZE(a0),a0
	dbf	d5,.__4
._5:	lea	-LINE_SIZE(a0),a0
	move.l	a0,-(sp)
	move.l	4(sp),a0
	clr.b	line_pattern(a6)
	addq.w	#1,d0
	subq.w	#1,d2
	move.l	a0,-(sp)
	lea	LINE_SIZE+1(a0),a0
	bsr	high_horiz_line
	subq.w	#1,d0
	addq.w	#1,d2
	move.l	(sp)+,a0
	st	line_pattern(a6)
	moveq	#0,d4
	tst.b	current_window_flag(a6)
	beq.s	._6
	moveq	#2,d4
._6:	move.w	d4,-(sp)
._8:	bsr	high_horiz_line
	lea	-LINE_SIZE(a0),a0
	dbf	d4,._8
	clr.b	line_pattern(a6)
	move.w	(sp)+,d4
	subq.w	#2,d4
	neg.w	d4
._9:	bsr.s	high_horiz_line
	lea	-LINE_SIZE(a0),a0
	dbf	d4,._9
	move.l	(sp)+,a0
	st	line_pattern(a6)
	moveq	#0,d4
	moveq	#1,d5
	tst.b	current_window_flag(a6)
	beq.s	._7
	moveq	#2,d4
	moveq	#0,d5
._7:	bsr.s	high_horiz_line
	lea	LINE_SIZE(a0),a0
	dbf	d4,._7
	clr.b	line_pattern(a6)
	tst.w	d5
	beq.s	._10
._11:	bsr.s	high_horiz_line
	lea	LINE_SIZE(a0),a0
	dbf	d5,._11
._10:	addq.w	#4,sp
	movem.l	(sp)+,d0-a2
	rts

high_horiz_line:
	movem.l	d2/d7/a0,-(sp)
	move.b	line_pattern(a6),d7
	sub.w	d0,d2
	subq.w	#1,d2
	clr.b	(a0)+
	tst.b	d7
	beq.s	.5
	move.b	#%00000111,-1(a0)
	tst.b	current_window_flag(a6)
	beq.s	.5
	move.b	#%00011111,-1(a0)
.5:	move.b	d7,(a0)+
	dbf	d2,.5
.end:	clr.b	(a0)
	tst.b	d7
	beq.s	.4
	move.b	#%11100000,(a0)
	tst.b	current_window_flag(a6)
	beq.s	.4
	move.b	#%11111000,(a0)
.4:	movem.l	(sp)+,d2/d7/a0
	rts
;	 #] Draw window:
;	 #[ Print instruction:
print_instruction:
	movem.l	d0-d7/a1-a4,-(sp)
	tst.b	acia_ikbd(a6)
	beq.s	.1
	bsr	internal_inkey
.1:	move.l	device_number(a6),d0
	beq	.4
	cmp.l	#RS232_OUTPUT,d0
	bne.s	.2
	bsr	poscur
.2:	cmp.l	#6,d0
	bge	disk_display
	move.l	font_addr(a6),a0
	move.l	physbase(a6),a1
	move.w	x_pos(a6),d0
	move.w	y_pos(a6),d1
	lsl.w	#3,d1
	moveq	#79,d7
._1:	add.w	d0,a1
	subq.w	#3,d1
	bpl.s	.no_plantage
	clr.w	d1
.no_plantage:
	move.w	line_size(a6),d4
	mulu	d4,d1
	add.l	d1,a1
	moveq	#0,d3
	tst.b	c_line(a6)
	beq.s	.no_cline
	REPT 3
	adda.w	d4,a1
	ENDR
	bra.s	.print
.no_cline:
	tst.b	m_line(a6)
	bne.s	.print
.no_mline:
	lea	line_buffer(a6),a2
.before_print:
	lea	w1_db(a6),a3
	move.w	window_redrawed(a6),d0
	lsl.w	#4,d0
	move.w	x_pos(a6),d7
	cmp.w	0(a3,d0.w),d7
	beq.s	.0
	move.w	4(a3,d0.w),d7
	sub.w	0(a3,d0.w),d7
	sub.w	x_pos(a6),d7
	bra.s	.print
.0:	move.w	4(a3,d0.w),d7
	sub.w	0(a3,d0.w),d7
	subq.w	#1,d7
.print:	move.l	a1,a3
	move.b	(a2)+,d0
	and.w	#$ff,d0
	beq.s	.end
	move.l	a0,a4
	add.w	d0,a4
	bsr.s	print_character
	dbf	d7,.print
	bra.s	.really_end
.end:	tst.b	c_line(a6)
	bne.s	.really_end
	tst.b	m_line(a6)
	bne.s	.really_end

	cmp.l	#SCREEN_OUTPUT,device_number(a6)
	bne.s	.last_loop
	bsr	clear_till_end_of_line
	bra.s	.really_end
.last_loop:
	move.l	a1,a3
	moveq	#" ",d0
	move.l	a0,a4
	add.w	d0,a4
	bsr.s	print_character
	dbf	d7,.last_loop
.really_end:
	cmp.l	#PRINTER_OUTPUT,device_number(a6)
	bne.s	.4
	bsr	init_printer_display
.4:	movem.l	(sp)+,d0-d7/a1-a4
	rts

print_character:
	cmp.l	#RS232_OUTPUT,device_number(a6)
	beq	terminal_display
	cmp.l	#PRINTER_OUTPUT,device_number(a6)
	beq	printer_display
	tst.b	alt_e_flag(a6)
	bne.s	.1
	REPT	8
	move.b	(a4),(a3)
	adda.w	d4,a3
	lea	$100(a4),a4
	ENDR
	addq.w	#1,a1
	rts
.1:
	REPT	8
	not.b	(a3)
	adda.w	d4,a3
	ENDR
	addq.w	#1,a1
	rts

clear_till_end_of_line:
	moveq	#0,d0
	addq.w	#1,d7
	moveq	#7,d5
.line_loop:
	moveq	#0,d6
	move.w	d7,d6
	ror.l	#2,d6
	move.l	a3,-(sp)
	subq.w	#1,d6
	bmi.s	.now_small
.high_loop:
	move.b	d0,(a3)+
	move.b	d0,(a3)+
	move.b	d0,(a3)+
	move.b	d0,(a3)+
	dbf	d6,.high_loop
.now_small:
	swap	d6
	rol.w	#2,d6
	subq.w	#1,d6
	bmi.s	.end_small_line
.small_line:
	move.b	d0,(a3)+
	dbf	d6,.small_line
.end_small_line:
	move.l	(sp)+,a3
	add.w	d4,a3
	dbf	d5,.line_loop
	rts

; ----- IMPRIMANTE -----
init_printer_display:
	tst.b	system_prt_flag(a6)
	beq.s	.ok
	tst.l	amiga_printer_file(a6)
	bne.s	.ok
	movem.l	d1/a0/a1,-(sp)
	lea	amiga_printer_name,a0
	bsr	create_file
	movem.l	(sp)+,d1/a0/a1
	bmi.s	.error
	move.l	d0,amiga_printer_file(a6)
.ok:	moveq	#$a,d0
	bsr	prt_char
	tst.w	d0
	beq.s	.end
.error:	moveq #-1,d0
.end:	rts

prt_char:
	tst.b	system_prt_flag(a6)
	bne.s	.system_prt_char
	moveq	#5,d1
.l2:	moveq	#-1,d2
.l1:	btst	#0,$bfd000	;busy
	beq.s	.lolo
	dbf	d2,.l1
	dbf	d1,.l2
.pas_good:
	moveq	#-1,d0
	bra.s	.end
.lolo:
;passe le port B en emission
	st	$bfe301
	move.b	d0,$bfe101
	moveq	#0,d0
	bra.s	.end
.system_prt_char:
	move.l	amiga_printer_file(a6),d1
	bne.s	.opened
	move.w	d0,-(sp)
	bsr	init_printer_display
	move.w	(sp)+,d0
	move.l	amiga_printer_file(a6),d1
	beq.s	.pas_good
.opened:
	lea	long_buffer(a6),a0
	move.b	d0,(a0)
	moveq	#1,d0
	bsr	write_file
	subq.l	#1,d0
.end:	rts
;	 #] Print instruction:
;	 #[ Print window cursor:
print_window_cursor:
	movem.l	d0-d4/a0-a4,-(sp)
	cmp.l	#2,device_number(a6)
	bne.s	.0
	move.l	x_pos(a6),-(sp)
	move.l	ex_cursor(a6),x_pos(a6)
	bsr	poscur
	move.l	(sp)+,x_pos(a6)
	movem.l	(sp)+,d0-d4/a0-a4
	rts
.0:	move.l	physbase(a6),a3
	move.l	a3,-(sp)
	move.w	line_size(a6),d2
	move.w	old_ex_cursor(a6),d0
	move.w	old_ey_cursor(a6),d1
	bmi.s	.new
	bsr.s	.internal_pos
.new:	move.l	(sp)+,a3
	move.w	line_size(a6),d2
	move.w	ex_cursor(a6),d0
	move.w	ey_cursor(a6),d1
	bsr.s	.internal_pos
	move.l	ex_cursor(a6),old_ex_cursor(a6)
	movem.l	(sp)+,d0-d4/a0-a4
	rts
.internal_pos:
	lsl.w	#3,d1
	tst.b	c_line(a6)
	bne.s	.4
	subq.w	#3,d1
.4:	mulu	d2,d1
	add.w	d1,a3
	add.w	d0,a3
	move.w	line_size(a6),d4
	moveq	#1,d1
	bra	print_character
;	 #] Print window cursor:
;	 #[ Print cursor:
;d0=y
;d1=x
print_cursor:
	movem.l	d2-d3/a0-a1,-(sp)
	move.w	#-1,old_ey_cursor(a6)
	move.w	d0,ey_cursor(a6)
	move.w	d1,ex_cursor(a6)
	st	alt_e_flag(a6)
	bsr	print_window_cursor
	sf	alt_e_flag(a6)
	movem.l	(sp)+,d2-d3/a0-a1
	rts
;	 #] Print cursor:
;  #] Screen functions:
;	 #[ p1 registers init:
p1_registers_init:
	move.l	internal_usp(a6),a7_buf(a6)
p1_registers_init2:
	move.l	text_buf(a6),pc_buf(a6)
	move.l	initial_ssp(a6),ssp_buf(a6)
	movem.l	initial_regs(a6),d0-d7
	movem.l	d0-d7,d0_buf(a6)
	movem.l	initial_regs+8*4(a6),d0-d6
	movem.l	d0-d6,a0_buf(a6)

	IFNE	_68030
	tst.b	chip_type(a6)
	beq	.68000
	bsr	super_on
	move.l	d0,-(sp)
	dc.l	$4e7a0002	;movec	cacr,d0
	move.l	d0,cacr_buf(a6)
	dc.l	$4e7a0801	;movec	vbr,d0
	move.l	d0,vbr_buf(a6)

	IFEQ	A4000
	dc.l	$4e7a0000	;movec	sfc,d0
	move.w	d0,sfc_buf(a6)
	dc.l	$4e7a0001	;movec	dfc,d0
	move.w	d0,dfc_buf(a6)
	cmp.b	#4,chip_type(a6)
	bge.s	.proc40
	dc.l	$4e7a0802	;movec	caar,d0 (pas 68040)
	move.l	d0,caar_buf(a6)
.proc40:	dc.l	$4e7a0803	;movec	msp,d0
	move.l	d0,msp_buf(a6)
	dc.l	$4e7a0804	;movec	isp,d0
	move.l	d0,isp_buf(a6)
	cmp.b	#4,chip_type(a6)
	bge.s	.proc40_2
; pmmu
	lea	.pmmu_error(pc),a1
	jsr	get_vbr
	move.l	$e0(a0),d2
	moveq	#0,d1
	move.l	a1,$e0(a0)

	lea	crp_buf(a6),a0
;	pmove.d	crp,(a0)
	dc.w	$f010,$4e00
	addq.w	#8,a0
;	pmove.d	crp,(a0)	pour l'instant crp->srp
	dc.w	$f010,$4e00
	addq.w	#8,a0
;	pmove.l	tc,(a0)
;	dc.w	$f010,$4200	;Enforcer -> pas touche a TC
	addq.w	#4,a0
;	pmove.l	tt0,(a0)
	dc.w	$f010,$0a00
	addq.w	#4,a0
;	pmove.l	tt1,(a0)
	dc.w	$f010,$0e00
	addq.w	#4,a0
;	pmove.w	mmusr,(a0)
	dc.w	$f010,$6200
.proc40_2:
	tst.b	fpu_type(a6)
	beq.s	.no_fpu
	addq.w	#2,a0
;	fmovem.x	fp0-fp7,(a0)
	dc.w	$f210,$f0ff
	lea	8*3*4(a0),a0
;	fmovem.l	fpcr/fpsr/fpiar,(a0)
	dc.w	$f210,$bc00
.no_fpu:
	ENDC	;A4000
	move.l	(sp)+,d0
	beq.s	.already_super
	move.l	d0,a0
	bsr	super_off
.already_super:
.68000:
	ENDC	;de _68030
	rts
.pmmu_error:
	rte
;	 #] p1 registers init:
;	 #[ update_ro:
; -- Input --
;d0=process #
;a0=process loaded @
; -- IN --
; a0 = @ courante
; a1 = @ fin du fichier
; a2 = @ table segments
; a3 = @ hunk courant
; d5 = taille a reserver (a cause de la bss)
; -- Out --
;d0=ro size to reserve
update_ro:
	tst.b	internal_ros_flag(a6)
	beq.s	.not_internal
	moveq	#0,d0
	rts
.not_internal:
	movem.l	d2-d7/a2-a5,-(sp)
	move.l	a0,d7
	move.l	d0,d5
	lea	0(a0,d0.l),a1
	cmp.w	#$3f3,2(a0)
	bne	ro_error
	addq.l	#4,a0
	move.l	(a0)+,d0
	lsl.l	#2,d0
	adda.l	d0,a0
	move.l	(a0)+,d0 ; nb de hunks
	move.l	a0,a2	 ; @ taille des hunks -> adresses
	addq.l	#8,a0
	move.l	d0,d1
	lsl.l	#2,d1
	adda.l	d1,a0 ; skippe les tailles
	cmp.l	a1,a0
	bge	ro_error ; si on a deja atteint la fin

; 1ere PASSE POUR LOCALISER LES SEGMENTS
	move.l	a0,a5
	move.l	a1,a4
	moveq	#0,d6
ro_first_pass:
	cmp.l	a1,a0
	bge	ro_first_end
	move.l	(a0)+,d0
	cmp.w	#$3e7,d0
	blt	ro_unknown_hunk
	cmp.w	#$3e9,d0
	beq.s	ro_firsthunkcode
	cmp.w	#$3ea,d0
	beq.s	ro_firsthunkdata
	cmp.w	#$3eb,d0
	beq	ro_firsthunkbss
	cmp.w	#$3ec,d0
	beq	ro_firstreloc32
	cmp.w	#$3f0,d0
	beq	ro_firsthunksymbol
	cmp.w	#$3f2,d0
	beq.s	ro_first_pass
	cmp.w	#$3f4,d0
	beq	ro_unknown_hunk

ro_first_skip:
	move.l	(a0)+,d0
	and.l	#$1fffffff,d0
	lsl.l	#2,d0
	adda.l	d0,a0
	bra.s	ro_first_pass
ro_firsthunkcode:
	move.l	d7,a3
	move.l	a0,d7
	sub.l	a3,d7
	addq.l	#2,d7
	move.w	#$6000,(a3)
	move.w	d7,2(a3)
	lea	4(a0),a3
	move.l	a3,0(a2,d6.l)
	addq.l	#4,d6
	bra.s	ro_first_skip
ro_firsthunkdata:
	lea	4(a0),a3
	move.l	a3,0(a2,d6.l)
	addq.l	#4,d6
	bra.s	ro_first_skip
ro_firsthunkbss:
	move.l	(a0)+,d0
	and.l	#$1fffffff,d0
	lsl.l	#2,d0
	add.l	d0,d5
	move.l	a4,0(a2,d6.l)
	adda.l	d0,a4
	addq.l	#4,d6
	bra	ro_first_pass
ro_firsthunksymbol:
	move.l	(a0)+,d0
	beq	ro_first_pass
.another:
	lsl.l	#2,d0
	lea	4(a0,d0.l),a0
	move.l	(a0)+,d0
	bne.s	.another
	bra	ro_first_pass
ro_firstreloc32:
	move.l	(a0)+,d1
	beq	ro_first_pass
	lsl.l	#2,d1
	lea	4(a0,d1.l),a0
	bra.s	ro_firstreloc32
ro_first_end:
	move.l	a5,a0

; 2de PASSE POUR RELOGER
	moveq	#0,d6
ro_treat_hunk:
	cmp.l	a1,a0
	bge	ro_end
	move.l	(a0)+,d0
	cmp.w	#$3e9,d0
	beq.s	ro_hunkcodedata
	cmp.w	#$3ea,d0
	beq.s	ro_hunkcodedata
	cmp.w	#$3eb,d0
	bne.s	ro_nobss
	addq.l	#4,a0
	bra.s	ro_treat_hunk
ro_nobss:
	cmp.w	#$3ec,d0
	beq	ro_reloc32
	cmp.w	#$3f0,d0
	beq	ro_hunksymbol
	cmp.w	#$3f2,d0
	beq.s	ro_treat_hunk
	bra.s	ro_skip
ro_hunkcodedata
	lea	4(a0),a3
ro_skip:
	move.l	(a0)+,d0
	and.l	#$1fffffff,d0
	lsl.l	#2,d0
	adda.l	d0,a0
	bra.s	ro_treat_hunk

ro_reloc32:
	move.l	(a0)+,d1
	beq.s	ro_treat_hunk
	move.l	(a0)+,d0
	lsl.l	#2,d0
	move.l	(a2,d0.l),d2 ; adresse segment
	subq.w	#1,d1
	bmi.s	ro_reloc32
ro_rel1offset:
	move.l	(a0)+,d0
	add.l	d2,0(a3,d0.l) ; reloger
	dbf	d1,ro_rel1offset
	bra.s	ro_reloc32

ro_hunksymbol:
	move.l	(a0)+,d0
	beq.s	ro_treat_hunk
.another:
	lsl.l	#2,d0
	lea	4(a0,d0.l),a0
	move.l	(a0)+,d0
	bne.s	.another
	bra.s	ro_treat_hunk

ro_unknown_hunk:
ro_error:
	moveq	#-1,d5
ro_end:	move.l	d5,d0
	movem.l	(sp)+,d2-d7/a2-a5
	rts

;recherche des ros deja chargees avec adebug
;INPUT d0=@1er segment
extract_ros:
	movem.l	d7/a5,-(sp)
.next:	move.l	d0,a5
	move.l	4(a5),d7	;nbre de sections de la ro
	addq.l	#8,d0
	move.l	d0,a0
	move.l	(a5),d0
	add.l	d0,d0
	add.l	d0,d0
	move.l	d0,current_internal_ro_addr(a6)
	jsr	create_one_var
.skip:	move.l	(a5),d0
	add.l	d0,d0
	add.l	d0,d0
	move.l	d0,a5
	dbeq	d7,.skip
	tst.l	d0
	bne.s	.next
	movem.l	(sp)+,d7/a5
	rts
;	 #] update_ro:

;  #[ ScreenDump:[Alt_Help]
screen_dump:
	tst.b	rs232_output_flag(a6)
	beq.s	.no_rs232
	moveq	#-1,d0
	rts
.no_rs232:
	movem.l	d2/d5/a2,-(sp)
	lea	ro_usp-4096(a6),a1
	move.l	physbase(a6),a0
	add.l	#(AMIGA_NB_LINES-8)*LINE_SIZE,a0
	move.w	#(LINE_SIZE*8)/4-1,d0
.cp:	move.l	(a0)+,(a1)+
	dbf	d0,.cp
	suba.l	a0,a0
	st	no_eval_flag(a6)
	lea	ask_screensave_text,a2
	jsr	get_expression
	bne	.end
	move.l	a0,a2
	bsr	create_file
	bmi	.create_error
	move.l	d0,d5
	move.l	a2,a0
	lea	piped_file(a6),a1
	jsr	strcpy
	pea	piped_file(a6)
	pea	saving_file_text
	lea	line_buffer(a6),a2
	move.l	a2,a0
	jsr	sprintf
	jsr	print_result
	addq.w	#8,sp
	
	lea	lower_level_buffer(a6),a0
	move.l	#'FORM',(a0)+
;taille du fichier-8 (pokee + tard)
	addq.l	#4,a0
	move.l	#'ILBM',(a0)+
; bitmap header
	move.l	#'BMHD',(a0)+
	moveq	#20,d0
	move.l	d0,(a0)+
	move.w	#LINE_SIZE*8,(a0)+
	move.w	#AMIGA_NB_LINES,(a0)+
	clr.l	(a0)+		;pos. X,Y
	move.w	#$0100,(a0)+	;1 plan de bits, pas de masquage
	clr.l	(a0)+		;pas de compression, transparent=0
	move.w	#$0101,(a0)+	;aspects X et Y
	move.w	#LINE_SIZE*8,(a0)+
	move.w	#AMIGA_NB_LINES,(a0)+
; color map
	move.l	#'CMAP',(a0)+
	moveq	#6,d0
	move.l	d0,(a0)+	;2 couleurs->6 octets
	move.l	color0_value(a6),d0
	bsr	.compute_color
	move.l	color1_value(a6),d0
	bsr	.compute_color
; body
	move.l	#'BODY',(a0)+
	move.l	#LINE_SIZE*AMIGA_NB_LINES,(a0)+
	lea	lower_level_buffer(a6),a1
	move.l	a0,d0
	move.l	a1,a0
	sub.l	a0,d0
	move.l	d0,4(a0) ; la taille actuelle
	add.l	#LINE_SIZE*AMIGA_NB_LINES-8,4(a0) ;+le reste -8
	move.l	d5,d1
	bsr	write_file
;l'ecran moins la ligne de commande
	move.l	physbase(a6),a0
	move.l	d5,d1
	move.l	#LINE_SIZE*(AMIGA_NB_LINES-8),d0
	bsr	write_file
;la ligne de commande
	lea	ro_usp-4096(a6),a0
	move.l	#LINE_SIZE*8,d0
	move.l	d5,d1
	bsr	write_file
	move.l	d5,d0
	bsr	close_file
	lea	line_buffer(a6),a0
	move.l	a0,a2
	move.l	lower_level_buffer+4(a6),d0
	addq.l	#8,d0
	move.l	d0,-(sp)
	pea	piped_file(a6)
	pea	file_saved_text
	jsr	sprintf
	lea	12(sp),sp
	jsr	print_result
	bra.s	.end
.create_error:
	lea	create_error_text,a2
	jsr	print_error
	moveq	#-1,d0
.end:	movem.l	(sp)+,d2/d5/a2
	rts

.compute_color:
	moveq	#2,d2
.shift:	move.w	d0,d1
	and.w	#$f,d1
	lsl.w	#4,d1
	move.b	d1,0(a0,d2.w)
	lsr.w	#4,d0
	dbf	d2,.shift
	addq.l	#3,a0
	rts
;  #] ScreenDump:[Alt_Help]

;  #[ Not_palette:[Ctl_Alt_I]
not_palette:
	not.b	inverse_video_flag(a6)
_not_palette:
	move.l	internal_copperlist(a6),a1
	move.w	46(a1),d0	;fond
	move.w	50(a1),d1	;avant-plan
	move.w	d0,50(a1)
	move.w	d1,46(a1)
	rts
;  #] Not_palette:

;  #[ Reset:([shift-]ctrl_alt_del)
warm_reset:
cold_reset:
	rts
;  #] Reset:
;  #[ Call_shell:[!]
call_shell:
	tst.b	multitask_access_flag(a6)
	bne.s	.err
	st	no_eval_flag(a6)
	suba.l	a0,a0
	lea	call_shell_text,a2
	bsr	get_expression
	bne.s	.end
	move.l	a0,long_buffer(a6)
	lea	call_shell_routine(pc),a0
	st	amiga_call_shell_flag(a6)
	bsr	amiga_system_call
	sf	amiga_call_shell_flag(a6)
.end:	rts
.err:	lea	shell_multi_error_text,a2
	jmp	print_error

call_shell_routine:
	GETA6
	move.l	long_buffer(a6),d1
	moveq	#0,d2
	move.l	d2,d3
	CALLDOS	Execute
	bra	end_multi_routine
;  #] Call_shell:

;  #[ Set_copperlist:
set_copperlist:
	move.l	a2,-(sp)
	tst.b	CopListFlg(a6)
	beq	.end2		;si on est en screen
	suba.l	a0,a0
	lea	ask_copperlist_text,a2
	jsr	print_a2
.again:	bsr	get_char
	cmp.b	#$1b,d0
	beq.s	.esc
	and.b	#$df,d0
	cmp.b	#'V',d0
	beq.s	.set_vbl
	cmp.b	#'C',d0
	beq.s	.set_copper
	IFNE	amiga_avbl
	cmp.b	#'A',d0
	beq	.set_always
	ENDC
	bsr	flash
	bra.s	.again
.esc:	clr.w	x_pos(a6)
	jsr	clr_c_line
	bra	.end2
.set_copper:
	IFNE	amiga_avbl
	bsr	.switch_6c
	ENDC
	lea	line_buffer(a6),a0
	move.l	external_copperlist(a6),-(sp)
	pea	copperlist_format_text
	jsr	sprintf
	addq.w	#8,sp
	lea	line_buffer(a6),a0
	lea	set_copperlist_text,a2
	bsr	get_expression
	bmi.s	.end2
	move.l	d0,external_copperlist(a6)
	or.w	#$4080,internal_dmacon(a6)
	tst.b	copper_active(a6)
	bne.s	.already
	move.l	internal_copperlist(a6),$dff080
	clr.w	$dff088
.already:
	st	copper_active(a6)
	bra.s	.end
.set_vbl:
	move.w	internal_intena(a6),d0
	btst	#5,d0
	beq.s	.warn
	btst	#14,d0
	beq.s	.warn
	cmp.w	#3,current_ipl(a6)
	blt.s	.ok
.warn:	lea	vbl_error_text,a2
	bsr	print_error
	bra.s	.end2
.ok:
	IFNE	amiga_avbl
	bsr	.switch_6c
	ENDC
	sf	copper_active(a6)
	bclr	#7,internal_dmacon+1(a6)
	lea	vbl_set_text,a2
	bsr	print_result
	bsr	wait_vbl
	move.l	external_copperlist(a6),$dff080
.end:	bsr	rethink_display
.end2:	move.l	(sp)+,a2
	rts

	IFNE	amiga_avbl
.set_always:
	tst.b	always_vbl_flag(a6)
	bne.s	.end2			;deja ds ce mode
	st	always_vbl_flag(a6)
	move.w	#$4020,d0
	move.w	d0,internal_intena(a6)
	bset	#15,d0
	move.w	d0,$dff09a
	not.w	d0
	move.w	d0,$dff09a
	st	acia_ikbd(a6)
	sf	copper_active(a6)
	bclr	#7,internal_dmacon+1(a6)
	lea	vbl_set_text,a2
	bsr	print_result
	move.l	#always_vbl_routine,$6c.w
	move.l	external_copperlist(a6),$dff080
	jsr	redraw_all_windows
	bra.s	.end

.switch_6c:
	tst.b	always_vbl_flag(a6)
	beq.s	.ok_man
	sf	always_vbl_flag(a6)
	;faire gaffe le systeme va prendre la main avec la vbl de toute facon
	;puisqu'on pouvait pas monter l'IPL dans ce mode
	st	vbl_patchkey(a6)
	move.l	external_vbl(a6),$6c.w
.ok_man:	rts
	ENDC	;de amiga_avbl
;  #] Set_copperlist:

;  #[ Reset_copperlist:
reset_copperlist:
	move.l	gfxbase(a6),a0
	move.l	$26(a0),external_copperlist(a6)
	move.w	initial_dmacon(a6),external_dmacon(a6)
	lea	reset_copperlist_text,a2
	bra	print_result
;  #] Reset_copperlist:

reloc_copperlist:
	movem.l	d6/d7/a2,-(sp)
	tst.b	CopListFlg(a6)
	beq	.end
	suba.l	a0,a0
	lea	reloc_copperlist_text,a2
	bsr	get_expression
	bmi	.end
	move.b	coplist_allocation_flag(a6),d6
	move.l	d0,a1
	move.l	d0,d7
	move.l	#taille_copperlist,d0
	CALLEXEC	AllocAbs
	tst.l	d0
	bne.s	.ok
.ask:	lea	allocabs_failed_text,a2
	suba.l	a0,a0
	jsr	yesno
	beq.s	.flash
	subq.w	#1,d0
	beq.s	.yes
	subq.w	#1,d0
	beq.s	.end
.flash:	bsr	flash
	bra.s	.ask
.yes:	sf	coplist_allocation_flag(a6)
.ok:	;liberer l'ancienne coplist
	move.l	internal_copperlist(a6),d0
	beq.s	.nofree
	tst.b	d6
	beq.s	.nofree
	move.l	d0,a1
	move.l	#taille_copperlist,d0
	CALLEXEC	FreeMem
;updater nouvelle
.nofree:	move.l	d7,internal_copperlist(a6)
	move.l	d7,a0
	bsr	update_copperlist
	tst.b	copper_active(a6)
	beq.s	.not_now
	move.l	d7,$dff080
.not_now:	move.l	d7,-(sp)
	pea	goodreloc_copperlist_text
	lea	line_buffer(a6),a2
	move.l	a2,a0
	jsr	sprintf
	addq.l	#8,sp
	jsr	print_result
.end:	movem.l	(sp)+,d6/d7/a2
	rts

update_copperlist:
;-- INPUT: a0=@coplist a updater
;garbage d0,a0,a1
	move.l	a0,-(sp)
	lea	copperlist_datas,a1
	move.w	#-1+taille_copperlist/4,d0
.cp:	move.l	(a1)+,(a0)+
	dbf	d0,.cp
	move.l	(sp)+,a0
	move.l	physbase(a6),d0
	move.w	d0,42(a0)
	swap	d0
	move.w	d0,38(a0)
	rts

reloc_screen:
	movem.l	d7/a2,-(sp)
	tst.b	CopListFlg(a6)	;pour le moment
	beq	.end		;ne pas reloger la bitmap systeme
	suba.l	a0,a0
	lea	reloc_screen_text,a2
	bsr	get_expression
	bmi	.end
	move.l	d0,a1
	move.l	d0,d7
	move.l	#AMIGA_NB_LINES*LINE_SIZE,d0
	CALLEXEC AllocAbs
	tst.l	d0
	bne.s	.ok
.ask:	lea	allocabs_failed_text,a2
	suba.l	a0,a0
	jsr	yesno
	beq.s	.flash
	subq.w	#1,d0
	beq.s	.yes
	subq.w	#1,d0
	beq.s	.end
.flash:	bsr	flash
	bra.s	.ask
.yes:	sf	screen_allocation_flag(a6)
.ok:
;liberer l'ancien ecran
	move.l	physbase(a6),a1
	move.l	#AMIGA_NB_LINES*LINE_SIZE,d0
	CALLEXEC FreeMem
;updater
	move.l	d7,physbase(a6)
	move.l	d7,initial_physbase(a6)
	move.l	internal_copperlist(a6),a0
	move.w	d7,42(a0)
	swap	d7
	move.w	d7,38(a0)
	swap	d7
	jsr	draw_all_windows
	move.l	d7,-(sp)
	pea	goodreloc_screen_text
	lea	line_buffer(a6),a2
	move.l	a2,a0
	jsr	sprintf
	addq.l	#8,sp
	jsr	print_result
.end:	movem.l	(sp)+,d7/a2
	rts

	IFEQ	bridos
;  #[ Load_prg:(ctrl_l)
_load_prg:
	movem.l	d3-d7/a2-a5,-(sp)
	move.b	overwrite_var_flag(a6),-(sp)
	moveq	#0,d7
	st	overwrite_var_flag(a6)
	lea	exec_name_buf(a6),a5
	tst.b	(a5)
	bne.s	.suite
	moveq	#-1,d0
	bra	.end
.suite:	move.l	a5,a0
	moveq	#-1,d0	;*pas* cd sur le repertoire
	bsr	find_file	;remplit my_dta(a6)=struct FileInfoBlock
	bne	.open_error

	lea	exec_name_buf(a6),a0
	bsr	open_file
	bmi	.open_error

	lea	my_dta+DTA_TIME(a6),a0
	lea	exec_timestamp(a6),a1
	move.l	(a0)+,(a1)+	;days
	move.l	(a0)+,(a1)+	;mins
	move.l	(a0),(a1)		;secs

	;handle	ds d5
	move.l	d0,d5
	moveq	#0,d0
	move.l	d0,p1_disk_len(a6)
	move.l	d0,p1_mem_len(a6)
	move.l	d0,exec_sym_nb(a6)
	move.w	d0,nb_text_segs(a6)
	move.w	d0,nb_data_segs(a6)
	move.w	d0,nb_bss_segs(a6)

	move.l	current_var_addr(a6),before_ctrll_addr(a6)
	move.l	current_la_addr(a6),before_ctrll_la_addr(a6)
	clr.l	PrgSegList(a6)
	clr.l	SrcSegList(a6)

	pea	my_dta+DTA_NAME(a6)
	pea	loading_file_text
	lea	line_buffer(a6),a2
	move.l	a2,a0
	jsr	sprintf
	addq.w	#8,sp
	jsr	print_result

	lea	long_buffer(a6),a5
	bsr	.readlmtoa5
	bne	.executable_error
	cmp.w	#$3f3,2(a5)
	bne	.executable_error

; c'est 1 executable:
	bsr	.readlmtoa5
	bne	.fin_reloc
	move.l	(a5),d7
	beq.s	.nohunkname
	subq.w	#1,d7
.skip_hunk_name:
	bsr	.readlmtoa5
	bne	.executable_error
	dbf	d7,.skip_hunk_name

.nohunkname:
	bsr	.readlmtoa5 ; lire nb de hunks
	bne	.executable_error
	move.l	(a5),d7
	bsr	.readlmtoa5 ; on charge sec pour le moment
	bsr	.readlmtoa5
	bne	.executable_error

; lecture des longueurs et allocations (nb de hunks dans d7)
; SrcSegList suit PrgSegList
	move.w	d7,n_amiga_segs(a6)
	move.l	d7,d0
	lsl.l	#3,d0 ; 8 octets / hunk
	move.l	d0,d3
	add.l	d0,d0 ; 2 tableaux
	moveq	#0,d1
	moveq	#3,d2
	jsr	reserve_memory
	move.l	d0,PrgSegList(a6)
	beq	.memory_error
	add.l	d0,d3
	move.l	d3,SrcSegList(a6)
	move.l	d3,a2
	move.l	d0,a4
	subq.w	#1,d7
	moveq	#0,d4
.lire_hunk_long:
	bsr	.readlmtoa5
	bne	.executable_error
	move.l	(a5),d0 ; taille
	moveq	#0,d1
	moveq	#3,d2
	lsl.l	#2,d0
	bcc.s	.hunk_chip_ok
	moveq	#0,d2
.hunk_chip_ok:
	add.l	d0,p1_mem_len(a6)
	move.l	d0,4(a2)
	addq.l	#8,d0  ; +2 longs pour taille et @ BCPL
	move.l	d0,4(a4)
	move.l	d0,d6
;	moveq	#-1,d1
	moveq	#0,d1		;CLEAR MEM
	jsr	reserve_memory
	move.l	d0,(a4)
	beq	.memory_error
	move.l	d0,d2
	addq.l	#8,d2
	move.l	d2,(a2)
;	move.w	d4,d1
;	bsr	ins_seg
; chainer
	move.l	d0,a0
	move.l	d6,(a0) ; taille
	tst.l	d4
	beq.s	.first
	move.l	-8(a4),a0
	addq.l	#4,d0
	lsr.l	#2,d0
	move.l	d0,4(a0) ; BCPL
.first:	addq.l	#1,d4
	addq.l	#8,a4
	addq.l	#8,a2
	dbf	d7,.lire_hunk_long
; terminer chainage
	move.l	-8(a4),a0
	clr.l	4(a0)

;  Lecture des hunks 
	clr.w	d6
	move.l	PrgSegList(a6),a2  ; ptstsegs
.lirehunk:
	bsr	.readlmtoa5
	bne	.fin_reloc
	move.w	2(a5),d0 ; type du hunk
	sub.w	#$3e7,d0
	bmi	.executable_error
	cmp.w	#$3f6-$3e7,d0
	bgt	.executable_error
	lea	.tab_saut_hunk(pc),a4
	add.w	d0,d0
	add.w	d0,d0
	move.l	(a4,d0.w),a4
	jsr	(a4) ; renvoie <>0 si pas ok
	beq.s	.lirehunk
.unknown_hunk:
	bra	.some_error

.tab_saut_hunk:
	dc.l	.hunk_unit,.hunk_name,.hunk_code,.hunk_data,.hunk_bss
	dc.l	.hunk_reloc32,.hunk_reloc16,.hunk_reloc8,.hunk_ext
	dc.l	.hunk_symbol,.hunk_debug,.hunk_end,.hunk_header
	dc.l	.hunk_overlay,.hunk_break

.hunk_code:
	moveq	#7,d4
	addq.w	#1,nb_text_segs(a6)
	bra.s	.code_or_data
.hunk_data:
	moveq	#6,d4
	addq.w	#1,nb_data_segs(a6)
.code_or_data:
	bsr	.readlmtoa5
	bne.s	.hunk_cd_err
	move.l	(a5),d0
	lsl.l	#2,d0
	move.l	d0,d3
	add.l	d0,p1_disk_len(a6)
	move.l	PrgSegList(a6),a0
	move.w	d6,d0
	lsl.w	#3,d0
	move.l	(a0,d0.w),d2  ; @

;	move.l	4(a0,d0.w),d1
;	sub.l	d3,d1		;allocated_size - hunk_size
;	ble.s	.datasz_equ
;	move.l	d2,a1
;	add.l	d3,a1
;	sub.l	d1,a1
;.dataclr:
;	clr.l	(a1)+
;	subq.l	#4,d1
;	bhi.s	.dataclr
;.datasz_equ:
	bset	d4,4(a0,d0.w) ; length

	addq.l	#8,d2
	move.l	d5,d1
	move.l	d3,d0
	move.l	d2,a0
	bsr	read_file
	move.l	(a2),a3
	addq.l	#8,a2
	addq.w	#1,d6
	moveq	#0,d0
	rts
.hunk_cd_err:
	moveq	#-1,d0
	rts

.hunk_bss:
	addq.w	#1,nb_bss_segs(a6)
	bsr	.readlmtoa5 ; sauter longueur
	bne.s	.hunk_bss_err
	move.l	PrgSegList(a6),a0
	move.w	d6,d0
	lsl.w	#3,d0
	move.l	4(a0,d0.w),d1	;taille PrgSegList
	bset	#5,4(a0,d0.w)
	move.l	SrcSegList(a6),a0
	clr.l	4(a0,d0.w)	;taille SrcSegList
	move.l	(a2),a3
	lea	8(a3),a0
	subq.l	#8,d1
	lsr.l	#2,d1
	beq.s	.bss_0
.clr:	clr.l	(a0)+
	subq.l	#1,d1
	bne.s	.clr
.bss_0:	addq.w	#8,a2
	addq.w	#1,d6
	moveq	#0,d0
	rts
.hunk_bss_err:
	moveq	#-1,d0
	rts

.hunk_reloc32: 	 ; dans a3 adresse de base du segment
	move.l	d6,-(sp)  ; hunk actuel
.hr32:	bsr	.readlmtoa5 ; lire nbre d'offsets
	bne.s	.hunk_reloc32_err
	move.l	(a5),d7
	beq.s	.fin_reloc32
	
	move.l	d7,d0
	lsl.l	#2,d0
	addq.l	#4,d0
	moveq	#0,d1
	moveq	#3,d2
	jsr	reserve_memory
	tst.l	d0
	beq.s	.hunk_reloc32_err

	move.l	d0,a0
	move.l	a0,a4
	move.l	d5,d1
	move.l	d7,d0
	addq.l	#1,d0
	lsl.l	#2,d0
	bsr	read_file ; voir traitement d'erreur

	move.l	PrgSegList(a6),a1
	move.l	a4,a0
	move.l	d7,d4
; a0 -> table reloc
	move.l	(a0)+,d0
	lsl.l	#3,d0 ; 8 octets /lm dans PrgSegList
	move.l	(a1,d0.l),d6 ; adresse segment
	addq.l	#8,d6
	subq.w	#1,d7
.rel1offset:
	move.l	(a0)+,d0
	add.l	d6,8(a3,d0.l) ; reloger
	dbf	d7,.rel1offset

	move.l	a4,a0
	move.l	d4,d0
	addq.l	#1,d0
	lsl.l	#2,d0
	jsr	free_memory
	bra.s	.hr32

.fin_reloc32:
	move.l	(sp)+,d6
	moveq	#0,d0
	rts	
.hunk_reloc32_err:
	move.l	(sp)+,d6
	moveq	#-1,d0
	rts

.hunk_symbol: ; dans a3 adresse de base du segment
	addq.l	#8,a3
	movem.l	d6/d7,-(sp)
	move.l	#$ffffff,d6
	moveq	#0,d4
	bsr.s	.next_block
	tst.l	d7
	beq.s	.fin_symboles	; on n'a rien lu (rare!)
.next_symbol:
	move.l	(a4)+,d3 	; taille nom en longs mots
	beq.s	.fin_symboles1
	and.l	d6,d3
	lsl.l	#2,d3

	move.l	d7,d4
	sub.l	d3,d7
	subq.l	#8,d7
	seq	d2		; = 0 , a retenir
	bpl.s	.continue	; > 0
.need_new:
	bsr.s	.next_block
	bra.s	.next_symbol
.continue:
	move.l	(a4,d3.l),d4	; offset
	lea	(a3,d4.l),a1	; + base = adresse
	clr.b	(a4,d3.l) 	; ascii du symbole en (a4)
	move.w	#'la',d0
	move.l	a4,a0
	addq.l	#1,exec_sym_nb(a6)
	bsr	put_in_table
	bmi.s	.hunk_symbol_err
	lea	4(a4,d3.l),a4
	tst.b	d2
	beq.s	.next_symbol
	moveq	#0,d4
	bra.s	.need_new

.next_block:
; d4 = taille deja en memoire
; si d4 <> 0, a4 = @ donnees
TAILLE_LOAD_BUF	equ	4096
	lea	ro_usp-4096(a6),a0
	move.l	a0,a1
	move.l	d4,d0
	beq.s	.read
	lsr.w	#2,d0
	subq.l	#4,a4	; recupere aussi longueur symbole
	subq.w	#1,d0
.copy:	move.l	(a4)+,(a0)+
	dbf	d0,.copy
.read:	move.l	d5,d1
	move.l	#TAILLE_LOAD_BUF,d0
	sub.l	d4,d0
	move.l	a1,a4
	bsr	read_file
	move.l	d0,d7
	add.l	d4,d7
	rts

.hunk_symbol_err:
	bsr.s	.go_seek
	movem.l	(sp)+,d6/d7
	subq.l	#8,a3
	moveq	#-1,d0
	rts
.fin_symboles1:
	subq.l	#4,d7
.fin_symboles:
	bsr.s	.go_seek
	movem.l	(sp)+,d6/d7
	subq.l	#8,a3
	moveq	#0,d0
	rts

.go_seek:
	move.l	d7,d0 ; offset
	beq.s	.fin_seek
	neg.l	d0
	move.l	d5,d1
	bsr	seek_file
.fin_seek:
	rts

.hunk_end:
	moveq	#0,d0
	rts
.hunk_debug:
	bsr	.readlmtoa5
	bne.s	.hd_err
	move.l	d5,d1
	moveq	#0,d0		;ftell
	bsr	seek_file		;d0<-offset disk courant
	move.l	(a5),d1		;d1<-taille du hunk en LM
	movem.l	d0/d1,-(sp)
	bsr	.readlmtoa5
	move.l	d5,d0		;handle
	cmp.l	#'QDB1',(a5)
	bne.s	.not_asm
	bsr	GetAsmDebug
	bra.s	.not_bsd
.not_asm:	cmp.l	#ZMAGIC,(a5)
	IFEQ	SHUNT_BSD_DEBUG
	bne.s	.not_bsd
	bsr	GetBsdDebug
	ENDC
.not_bsd:	movem.l	(sp)+,d0/d1
	;on se place a la fin du hunk debug vu
	;qu'on sait pas combien on a lu
	lsl.l	#2,d1
	add.l	d1,d0
	move.l	d5,d1
	bsr	abs_seek_file
.hd_end:	moveq	#0,d0
	rts
.hd_err:	moveq	#-1,d0
	rts

.hunk_unit:
.hunk_name:
.hunk_reloc16:
.hunk_reloc8:
.hunk_ext:
.hunk_header:
.hunk_break:
.skip_hunk:
	bsr	.readlmtoa5
	move.l	(a5),d0
	lsl.l	#2,d0
	move.l	d5,d1
	bsr	seek_file
	moveq	#0,d0
	rts
.hunk_overlay:
	lea	unknown_hunk_error_text,a2
	jsr	print_press_key
	moveq	#-1,d0
	rts

.fin_reloc:
	bsr	.close

	;trier les symboles par ordre alpha
	move.l	exec_sym_nb(a6),d0
	move.l	before_ctrll_addr(a6),d1
	lea	comp_var_alpha(pc),a0
	lea	inv_var_alpha(pc),a1
	jsr	_tri

	move.l	PrgSegList(a6),a0
	move.l	(a0),d1
	move.l	d1,p1_basepage_addr(a6)
	addq.l	#8,d1	; adresse du pc debut de prog
	move.l	d1,text_buf(a6)
	move.l	4(a0),d0
	and.l	#$1fffffff,d0
	move.l	d0,text_size(a6)	;pour bsddebug
	bsr	update_for_p1
	moveq	#0,d0
	bra	.end
	
.readlmtoa5:
	move.l	d5,d1
	move.l	a5,a0
	moveq	#4,d0
	bsr	read_file
	subq.l	#4,d0
	rts

.some_error:
	bsr.s	.close
	clr.w	x_pos(a6)
	jsr	clr_c_line
	bra.s	.free
.memory_error:
	bsr.s	.close
	lea	memory_error_text,a2
	bra.s	.print
.executable_error:
	bsr.s	.close
	lea	executable_error_text,a2
	bra.s	.print
.open_error:
	lea	higher_level_buffer(a6),a2
	move.l	a5,-(sp)
	pea	fnf_error_text
	move.l	a2,a0
	jsr	sprintf
	addq.w	#8,sp
;	bra.s	.print
; toujours sauter ici si erreur
.print:	jsr	print_error
.free:	bsr	free_amiga_sections
	clr.b	exec_name_buf(a6)
	clr.l	exec_sym_nb(a6)
	moveq	#-1,d0
	bra.s	.end
.close:	move.l	d5,d0
	bra	close_file
;	rts
.end:	move.b	(sp)+,overwrite_var_flag(a6)
	movem.l	(sp)+,d3-d7/a2-a5
	tst.l	d0
	rts

	IFNE	0	;finalement, ca sert a rien de trier les segments
;insere le segment ds la liste triee
;In: d1.w=#segment, d0.l=@segment, d6.l=taille segment
ins_seg:	movem.l	d2-d3/a0-a2,-(sp)
	move.l	SortSegList(a6),a0
	move.l	a0,a2
	move.w	d1,d2		;=nb d'elems deja ds la liste
	subq.w	#1,d1
	bmi.s	.put
;recherche
.l2:	cmp.l	(a0),d0
	addq.l	#8,a0
	dblo	d1,.l2
	bhs.s	.put
	subq.l	#8,a0
;decalage
	move.w	d2,d3
	lsl.w	#3,d3
	add.w	d3,a2
	lea	8(a2),a1
.l1:	move.l	-(a2),-(a1)
	move.l	-(a2),-(a1)
	dbf	d1,.l1
;insertion
.put:	move.l	d0,(a0)+
	move.l	d6,(a0)
	movem.l	(sp)+,d2-d3/a0-a2
	rts
	ENDC	;0

;In: handle ds d0 -- 'QDB1' a deja ete lu
GetAsmDebug:
	movem.l	d2-d7/a2-a5,-(sp)
	move.l	d0,d4
	lea	tcdebug_head(a6),a5
	move.l	#'QDB1',(a5)	;par compatibilite
	lea	4(a5),a0
	moveq	#$20-4,d0
	move.l	d4,d1
	bsr	read_file
	cmp.l	#$20-4,d0
	bne	.err
	lea	4(a5),a0
	move.l	a5,tcdebug_ptr(a6)
	move.l	(a0)+,d0		;l1
	add.l	(a0)+,d0		;l2
	add.l	(a0)+,d0		;l3
	add.l	(a0)+,d0		;l4
	add.l	(a0)+,d0		;l5
	add.l	(a0)+,d0		;l6
	add.l	(a0),d0		;names
	move.l	d0,tcdebug_len(a6)
	beq	.err
	st	d1
	moveq	#2,d2
	jsr	reserve_memory
	beq	.err
	move.l	d0,sourcedebug_info_ptr(a6)
	lea	l1_ptr(a6),a0
	lea	l1_len(a6),a1
	move.l	d0,(a0)+		;l1
	add.l	(a1)+,d0
	move.l	d0,(a0)+		;l2
	add.l	(a1)+,d0
	move.l	d0,(a0)+		;l3
	add.l	(a1)+,d0
	move.l	d0,(a0)+		;l4
	add.l	(a1)+,d0
	move.l	d0,(a0)+		;l5
	add.l	(a1)+,d0
	move.l	d0,(a0)+		;l6
	add.l	(a1)+,d0
	move.l	d0,(a0)+		;names
	move.l	tcdebug_len(a6),d0
	move.l	l1_ptr(a6),a0
	move.l	d4,d1
	bsr	read_file
	move.w	#SOURCE_PC,source_type(a6)
	bsr	tcget_vars_max	;alloue les tableaux de ptr des blocs courants
	bsr	tcupdate_source	;alloue un buffer pour le plus gros source + verif date
	bsr.s	GetSrcSecSizes
	bne.s	.err
.end:	movem.l	(sp)+,d2-d7/a2-a5
	rts
.err:	clr.l	tcdebug_ptr(a6)
	clr.w	source_type(a6)
	moveq	#-1,d0
	bra.s	.end

;lit les tailles reelles des sections (non padees au long)
;In: d4=handle
;Out:
;d0=-1 si le fichier se termine prematurement ou si les tailles
; ne concordent pas a 3 octets pres
;0 sinon
GetSrcSecSizes:
	movem.l	d2/d3,-(sp)
	moveq	#0,d2
	move.w	n_amiga_segs(a6),d2
	lsl.l	#2,d2
	sub.l	d2,sp
	move.l	d2,d0
	move.l	sp,a0
	move.l	d4,d1
	bsr	read_file
	cmp.l	d2,d0
	bne.s	.err
	move.l	SrcSegList(a6),a1
	addq.l	#4,a1		;pointer les tailles
	move.l	sp,a0
	move.l	d2,d0
.l1:	move.l	(a1),d1		;taille lue dans le hunk header
	move.l	(a0)+,d3
	sub.l	d3,d1
	bmi.s	.err
	subq.l	#4,d1		;tr<=th<=tr+3
	bpl.s	.err
	move.l	d3,(a1)
	addq.l	#8,a1
	subq.l	#4,d0
	bne.s	.l1
.end:	add.l	d2,sp
	movem.l	(sp)+,d2/d3
	rts
.err:	moveq	#-1,d0
	bra.s	.end

;In: handle ds d0; ZMAGIC a deja ete lu
;Out: d0=0 si le format semble OK, -1 sinon
GetBsdDebug:
	movem.l	d2-d7/a2-a5,-(sp)
	clr.l	BsdStrSize(a6)
	clr.l	BsdSymSize(a6)
	clr.l	BsdSymTbl(a6)
	clr.l	BsdStrTbl(a6)
	move.l	d0,d5
	subq.l	#8,sp
	move.l	sp,a0
	move.l	d5,d1
	moveq	#8,d0
	bsr	read_file
	movem.l	(sp)+,d3/d4
	subq.l	#8,d0
	bne.s	.out	;si on a lu moins de 8 octets
	move.l	d3,BsdSymSize(a6)
	move.l	d4,BsdStrSize(a6)
	move.l	d3,d0
	add.l	d4,d0
	beq.s	.out	;rien a reserver => pas de src level
	move.l	d0,d6
	moveq	#-1,d1	;don't clear
	moveq	#3,d2
	jsr	reserve_memory
.l1:	move.l	d0,BsdSymTbl(a6)
	beq.s	.out
	move.l	d0,a0
	add.l	d3,d0
	move.l	d0,BsdStrTbl(a6)
	move.l	d6,d0
	move.l	BsdSymTbl(a6),a0
	move.l	d5,d1
	jsr	read_file
	cmp.l	d6,d0
	bne.s	.err
	move.l	BsdStrTbl(a6),-(sp)
	move.l	d4,-(sp)
	move.l	BsdSymTbl(a6),-(sp)
	move.l	d3,-(sp)
	jsr	_CGetBsdDebug	;renvoie nb de modules
	lea	4*4(sp),sp
	move.l	d0,BsdNbMods(a6)
	beq.s	.out

	move.w	#SOURCE_BSD,source_type(a6)
	bsr	bsdupdate_source
.out:	movem.l	(sp)+,d2-d7/a2-a5
	rts
.err:	pea	.out(pc)	;bsr.s	FreeBsdDebug
			;bra.s	.out
;fall through!
FreeBsdDebug:
	move.l	BsdSymSize(a6),d0
	beq.s	.l1
	add.l	BsdStrSize(a6),d0
	move.l	BsdSymTbl(a6),a0
	jmp	free_memory
.l1:	rts

;In: d0=addr absolue
;Out:
; d0=offset absolu sur tout le code,-1 si pas ds le code
; CCR
UnSectionize:
	movem.l	d1-d5/a1,-(sp)
	move.w	n_amiga_segs(a6),d1
	subq.w	#1,d1
	bmi.s	.nf
	move.l	SrcSegList(a6),a1
	moveq	#0,d4		;somme des offsets
.l1:	move.l	d0,d5
	move.l	(a1)+,d2	;@
	move.l	(a1)+,d3	;size
	beq.s	.nx	;skip bss
	sub.l	d2,d5	;addr>=@sec et size<addr-@sec
	bmi.s	.nx
	cmp.l	d3,d5
	blt.s	.found
.nx:	add.l	d3,d4
	dbf	d1,.l1
.nf:	moveq	#-1,d0
.end:	movem.l	(sp)+,d1-d5/a1
	rts
.found:	add.l	d5,d4
	move.l	d4,d0
	bra.s	.end

;In: d0=offset absolu
;Out:d0=@ dans le code
Sectionize:
	movem.l	d1/d2/a1,-(sp)
	move.l	SrcSegList(a6),a1
	move.w	n_amiga_segs(a6),d2
	subq.w	#1,d2
	bmi.s	.end
.l1:	move.l	4(a1),d1
	sub.l	d1,d0
	addq.l	#8,a1
	dbmi	d2,.l1
	add.l	d1,d0
	add.l	-8(a1),d0
.end:	movem.l	(sp)+,d1/d2/a1
	rts

;Tri des variables par ordre alpha
comp_var_alpha:
	;tri par ordre d'adresse croissante
	move.l	d5,d0
	mulu	#VAR_SIZE,d0
	move.l	d6,d1
	mulu	#VAR_SIZE,d1
	move.l	VAR_NAME(a0,d0.l),a1
	move.l	VAR_NAME(a0,d1.l),a2
	movem.l	d0-d1,-(sp)
	moveq	#22-1,d1
.l1:	move.b	(a2)+,d0
	cmp.b	(a1)+,d0
	dbne	d1,.l1
	movem.l	(sp)+,d0-d1
	rts

inv_var_alpha:
	lea	(a0,d0.l),a1
	lea	(a0,d1.l),a2
	;name
	move.l	(a1),d0
	move.l	(a2),(a1)+
	move.l	d0,(a2)+
	;type
	move.w	(a1),d0
	move.w	(a2),(a1)+
	move.w	d0,(a2)+
	;value
	move.l	(a1),d0
	move.l	(a2),(a1)+
	move.l	d0,(a2)+
	rts

update_for_p1:
	move.b	trace_task_pref_flag(a6),trace_task_flag(a6)
	bsr	install_recup_process
	bsr	p1_registers_init2
; cmd_line p1 -> (a0) de p1
	lea	argv_buffer(a6),a0
	tst.b	(a0)
	bne.s	.suite
	clr.w	argc(a6)
.suite:
	lea	amiga_command_line(a6),a1
	move.l	a1,a0_buf(a6)
	move.l	a1,d1_buf(a6)
	move.w	argc(a6),d0
	move.w	d0,d1
.1:	move.b	(a0)+,(a1)+
	dbf	d0,.1
	move.b	#10,-1(a1)
; clr le reste de la ligne
	neg.w	d1
	add.w	#$100-1,d1
.2:	clr.b	(a1)+
	dbf	d1,.2
	move.w	argc(a6),d0
	ext.l	d0
	addq.l	#1,d0
	move.l	d0,d0_buf(a6)
	move.l	d0,d4_buf(a6)
	tst.b	WBstart_flag(a6)
	bne	.from_WB
;inits specifiques aux progs CLI
	move.l	internal_usp(a6),a0
	move.l	8(a0),a0
;a0=ptr cli interne
	move.l	a0,a3_buf(a6)
	move.l	4(a0),a0
	move.l	d0,12(a0)	;longueur ligne com.
	move.l	a0_buf(a6),d0
	lsr.l	#2,d0
	move.l	d0,8(a0)	;ptr cli interne
	move.l	Adebug_task(a6),a0
	move.l	pr_CIS(a0),a2
	add.l	a2,a2
	add.l	a2,a2
	move.l	fh_Buf(a2),a0
	add.l	a0,a0
	add.l	a0,a0
	move.l	a0_buf(a6),a1
	move.l	d0_buf(a6),d0
	cmp.w	#200,d0
	blt.s	.len_ok
	move.w	#199,d0
.len_ok:
	move.l	d0,fh_End(a2)
	subq.w	#1,d0
.cpcli_args:
	move.b	(a1)+,(a0)+
	dbf	d0,.cpcli_args
	clr.l	fh_Pos(a2)

	move.l	p1_task(a6),a0
	tst.b	trace_task_flag(a6)
	bne.s	.task_got
	move.l	Adebug_task(a6),a0
.task_got:
	move.l	pr_CLI(a0),a2
	add.l	a2,a2
	add.l	a2,a2
	lea	bcpl_prog_name(a6),a1
	move.l	a1,d0
	lsr.l	#2,d0
	move.l	d0,cli_CommandName(a2)
	lea	exec_name_buf(a6),a0
	addq.l	#1,a1
	jsr	strcpy
	subq.b	#1,d0
	move.b	d0,-1(a1)
.from_WB:	tst.b	create_sections_var_flag(a6)
	beq	.end
	;initialiser symboles text data bss
	move.w	n_amiga_segs(a6),d7
	subq.w	#1,d7
	moveq	#0,d6 ; compteur code
	move.w	d6,d5 ; data
	move.w	d6,d4 ; bss
	move.l	PrgSegList(a6),a4
	lea	lower_level_buffer(a6),a3
.put_label:
	movem.l	(a4)+,d1/d3
	exg	d1,d3
	addq.l	#8,d3

	btst	#31,d1
	bne.s	.text
	btst	#30,d1
	bne.s	.data
;.bss
	addq.w	#1,d4
	move.w	d4,-(sp)
	pea	bss_text
	bra.s	.put
.data:	addq.w	#1,d5
	move.w	d5,-(sp)
	pea	data_text
	bra.s	.put
.text:	addq.w	#1,d6
	move.w	d6,-(sp)
	pea	text_text
.put:	pea	amiga_section_format
	move.l	a3,a0
	jsr	sprintf
	lea	10(sp),sp
	move.l	a3,a0
	move.w	#'la',d0
	move.l	d3,a1
	bsr	put_in_table
	addq.l	#1,exec_sym_nb(a6)
	dbf	d7,.put_label
.end:	IFNE	sourcedebug
	bra	begin_source_debug
	ELSEIF
	rts
	ENDC
;  #] Load_prg:

;prendre les infos dans le chainage systeme plutot que ds PrgSegList
;a cause des progs qui se detachent du CLI
free_amiga_sections:
	move.l	PrgSegList(a6),d0
	beq.s	.no_segs
	move.l	d0,a2
	move.l	(a2),a2
.nxseg:	move.l	(a2),d0		;taille
	move.l	a2,a0
	move.l	4(a2),d3
	jsr	free_memory
	move.l	d3,d0		;suivant
	beq.s	.list
	add.l	d0,d0
	add.l	d0,d0
	subq.l	#4,d0
	move.l	d0,a2
	bra.s	.nxseg
.list:	move.l	PrgSegList(a6),a0
	moveq	#0,d0
	move.w	n_amiga_segs(a6),d0
	lsl.l	#4,d0	;*8*2
	jsr	free_memory
.no_segs:	moveq	#0,d0
	move.l	d0,PrgSegList(a6)
	move.l	d0,SrcSegList(a6)
	move.w	d0,n_amiga_segs(a6)
	move.w	d0,nb_text_segs(a6)
	move.w	d0,nb_data_segs(a6)
	move.w	d0,nb_bss_segs(a6)
	rts

;	[# Machine_term:
machine_term:
	tst.b	trace_task_flag(a6)
	beq.s	.no_task
	move.l	p1_task(a6),d0
	beq.s	.no_task
	move.l	d0,a1
	move.l	a1,-(sp)
	move.l	pr_CurrentDir(a1),d1
	beq.s	.nocwd
	CALLDOS	UnLock
.nocwd:	move.l	(sp)+,a1
	CALLEXEC	RemTask
	move.l	p1_task(a6),d0
	clr.l	p1_task(a6)
	cmp.l	p1_current_task(a6),d0
	bne.s	.no_task
	clr.l	p1_current_task(a6)
.no_task:	move.l	internal_usp(a6),a7_buf(a6)
	bsr	free_amiga_sections

	IFNE	sourcedebug
	IFNE	turbodebug
	cmp.w	#SOURCE_PC,source_type(a6)
	bne.s	.no_pc
	move.l	sourcedebug_info_ptr(a6),d0
	beq.s	.no_pc
	move.l	d0,a0
	move.l	tcdebug_len(a6),d0
	jsr	free_memory
	clr.l	sourcedebug_info_ptr(a6)
.no_pc:	ENDC	;tcdebug
	IFNE	bsddebug
	cmp.w	#SOURCE_BSD,source_type(a6)
	bne.s	.nobsd
	bsr	FreeBsdDebug
.nobsd:	ENDC	;bsddebug
	ENDC	;sourcedebug
	clr.l	p1_basepage_addr(a6)
	rts
;	#] Machine_term:

;	[# Get_Cmd_Line:
; entree a0 = ptr sur ligne de com. sans -options
get_cmd_line:
	lea	exec_name_buf(a6),a1
	moveq	#0,d0
.next:	move.b	(a0)+,d1
	beq.s	.fini
	cmp.b	#' ',d1
	beq.s	.space
	move.b	d1,(a1)+
	bra.s	.next
.space:	clr.b	(a1)
	lea	argv_buffer(a6),a1
.next1:	move.b	(a0)+,d1
	beq.s	.fini
	move.b	d1,(a1)+
	addq.w	#1,d0
	bra.s	.next1
.fini:	clr.b	(a1)
	move.w	d0,argc(a6)
	rts
;	#] Get_Cmd_Line:

;	 #[ Install_recup_process:
install_recup_process:
	tst.b	trace_task_flag(a6)
	beq	.no_task
	move.l	text_buf(a6),a0
	moveq	#0,d0
	move.l	def_break_vec(a6),d1
	move.l	def_break_eval_addr(a6),a1
	bsr	set_break
	st	run_flag(a6)
	sf	trace_flag(a6)
	sf	trace_task_flag(a6)
	move.b	nowatch_flag(a6),-(sp)
	sf	nowatch_flag(a6)
	lea	dummy_p1_start(pc),a0
	move.l	a0,pc_buf(a6)
	move.l	text_buf(a6),a1
	st	p1_start_flag(a6)
	bsr	p0p1
	sf	p1_start_flag(a6)
	move.l	p1_current_task(a6),d0
	beq.s	.taskerr
	move.l	d0,p1_task(a6)
	move.l	d0,a0
;comparer la tache courante a la tache lancee au cas ou
;une exception se serait produite dans 1 autre tache
	move.l	10(a0),a0
	lea	exec_name_buf(a6),a1
.charcmp:	move.b	(a1)+,d0
	beq.s	.zerofnd
	cmp.b	(a0)+,d0
	beq.s	.charcmp
.taskerr:	lea	createproc_error_text,a2
	bsr	print_press_key
	moveq	#-1,d0
	bra.s	.end
.zerofnd:	tst.b	(a0)
	bne.s	.taskerr
.task_ok:	move.b	(sp)+,nowatch_flag(a6)
	move.l	Adebug_task(a6),a0
	move.l	p1_current_task(a6),a1
	move.l	pr_CurrentDir(a0),d0
	bsr.s	.duplock
	move.l	d0,pr_CurrentDir(a1)
	movem.l	$9c(a0),d0-d1	;pr_CIS,pr_COS
	movem.l	d0-d1,$9c(a1)
	tst.b	WBstart_flag(a6)
	bne.s	.no_task
;inits specifiques CLI
	move.l	pr_CLI(a0),d0
	move.l	d0,pr_CLI(a1)
	add.l	d0,d0
	add.l	d0,d0
	move.l	d0,a0
	move.l	text_buf(a6),d0
	subq.l	#4,d0
	lsr.l	#2,d0
	move.l	d0,cli_Module(a0)
	move.l	a7_buf(a6),a0
	addq.l	#4,a0
	move.l	a0,pr_ReturnAddr(a1)
.no_task:	move.l	a7_buf(a6),a0
	move.l	a0,p1_initial_usp(a6)
	lea	recup_process(pc),a1
	move.l	a1,(a0)
	move.l	a1,p1_return_addr(a6)
	move.l	a1,external_return_addr(a6)
	moveq	#0,d0
.end:	rts
.duplock:	move.l	d0,d1
	movem.l	a0/a1,-(sp)
	CALLDOS	DupLock
	movem.l	(sp)+,a0/a1
	rts
	
dummy_p1_start:
	GETA6
	lea	exec_name_buf(a6),a0
	st	trace_task_flag(a6)
	move.l	a0,d1
	moveq	#0,d2
;meme priorite qu'adebug pour p1, indispensable si >0
;sinon p1 ne prend pas la main quand on veut le lancer
	move.l	Adebug_task(a6),a0
	move.b	ln_pri(a0),d2
	move.l	text_buf(a6),d3
	subq.l	#4,d3
	lsr.l	#2,d3
	move.l	amiga_stack_size(a6),d4
	CALLDOS	CreateProc
.l1:	bra.s	.l1
;	 #] Install_recup_process:

recup_process:
	SWITCHA6
	movem.l	d0-a5,d0_buf(a6)
	move.b	#1,exception(a6)
	clr.b	exec_name_buf(a6)
	clr.l	exec_sym_nb(a6)
	IFNE	_68030
	tst.b	chip_type(a6)
	beq.s	.68000
	clr.w	-(sp)	;null stack frame
.68000:
	ENDC	; _68030
	lea	pterm1(pc),a0
	move.l	a0,-(sp)
	clr.w	-(sp)	;sr=0
	bra	p1p0
		ENDC	;de bridos
;  #[ Timers stuff:
;	 #[ timers_exit:
timers_exit:
	lea	initial_mfp_speed_struct(a6),a0
	lea	initial_mfp_ctl_struct(a6),a1
	bra.s	unstore_timers
;	 #] timers_exit:
;	 #[ timer0_timer1:
timer0_timer1:
	IFNE	amiga_avbl
	tst.b	always_vbl_flag(a6)
	beq.s	.no_vbl
	move.l	external_vbl(a6),$6c.w
.no_vbl:
	ENDC
	lea	custom,a0
	move.w	external_intena(a6),d0
	bset	#15,d0
	move.w	d0,intena(a0)
	not.w	d0
	move.w	d0,intena(a0)
	lea	external_mfp_speed_struct(a6),a0
	lea	external_mfp_ctl_struct(a6),a1
unstore_timers:
;a0=speed,a1=ctrl
	move.l	a2,-(sp)
	lea	$bfee01,a2
	move.b	ciaa_icr(a6),d0
	bset	#7,d0
	move.b	d0,-$100(a2)
;timer AA
	move.b	(a0)+,d0
	tst.b	(a1)+
	beq.s	.l1
	bset	#0,d0
	bra.s	.l11
.l1:	bclr	#0,d0
.l11:	move.b	d0,(a2)
;timer AB
	move.b	(a0)+,d0
	tst.b	(a1)+
	beq.s	.l2
	bset	#0,d0
	bra.s	.l21
.l2:	bclr	#0,d0
.l21:	move.b	d0,$100(a2)
;timer BA
	lea	$bfde00,a2
	move.b	ciab_icr(a6),d0
	bset	#7,d0
	move.b	d0,-$100(a2)
	move.b	(a0)+,d0
	tst.b	(a1)+
	beq.s	.l3
	bset	#0,d0
	bra.s	.l33
.l3:	bclr	#0,d0
.l33:	move.b	d0,(a2)
;timer BB
	move.b	(a0),d0
	tst.b	(a1)
	beq.s	.l4
	bset	#0,d0
	bra.s	.l44
.l4:	bclr	#0,d0
.l44:	move.b	d0,$100(a2)
	move.l	(sp)+,a2
	rts
;	 #] timer0_timer1:
;	 #[ timers_init:
timers_init:
	lea	initial_mfp_speed_struct(a6),a0
	lea	initial_mfp_ctl_struct(a6),a1
	bsr.s	store_timers
	move.l	initial_mfp_speed_struct(a6),external_mfp_speed_struct(a6)
	move.l	initial_mfp_ctl_struct(a6),external_mfp_ctl_struct(a6)
;	 #] timers_init:
;	 #[ timer1_timer0:
timer1_timer0:
	IFNE	amiga_avbl
	move.l	$6c.w,external_vbl(a6)
	ENDC
	lea	custom,a0
	move.w	intenar(a0),d0
	move.w	d0,external_intena(a6)
	tst.b	follow_intena_flag(a6)
	bne.s	.put
	move.w	internal_intena(a6),d0
.put:	bsr	put_internal_intena
	lea	external_mfp_ctl_struct(a6),a1
	lea	external_mfp_speed_struct(a6),a0
store_timers:
;a0=speed,a1=ctrl
	move.l	a2,-(sp)
	moveq	#0,d0
	lea	$bfee01,a2
	move.b	-$100(a2),ciaa_icr(a6)
	btst	d0,(a2)
	sne	(a1)+
	move.b	(a2),(a0)+
	btst	d0,$100(a2)
	sne	(a1)+
	move.b	$100(a2),(a0)+
	lea	$bfde00,a2
	move.b	-$100(a2),ciab_icr(a6)
	btst	d0,(a2)
	sne	(a1)+
	move.b	(a2),(a0)+
	btst	d0,$100(a2)
	sne	(a1)
	move.b	$100(a2),(a0)
	move.l	(sp)+,a2
clear_timers:
	rts
;	 #] timer1_timer0:
;  #] Timers stuff:
;  #[ Keyboard functions:
;	 #[ Recup Keymap:
recup_keymap:
	movem.l	d2-a5,-(sp)
	suba.l	a1,a1
	CALLEXEC FindTask
	lea	read_reply_port(a6),a1
	move.l	d0,$10(a1)
	CALLEXEC AddPort
	lea	write_reply_port(a6),a1
	CALLEXEC AddPort
	lea	consoledev_name,a0
	lea	iorequest(a6),a1
	move.l	#4*8,IO_LENGTH(a1)
	moveq	#-1,d0
	moveq	#0,d1
	CALLEXEC OpenDevice
	tst.l	d0
	bne.s	.end
	lea	iorequest(a6),a1
	move.w	#CD_ASKDEFAULTKEYMAP,IO_COMMAND(a1)
	lea	higher_level_buffer(a6),a0
	move.l	a0,IO_DATA(a1)
	lea	read_reply_port(a6),a0
	move.l	a0,14(a1)
	move.w	#km_SIZEOF,IO_SIZE(a1)
	CALLEXEC DoIO
	lea	iorequest(a6),a0
	tst.b	IO_ERROR(a0)
	bne.s	.pascool
	bsr.s	make_keymap
	moveq	#0,d7
	bra.s	.close
.pascool:	moveq	#-1,d7
.close:	lea	iorequest(a6),a1
	CALLEXEC CloseDevice
	lea	read_reply_port(a6),a1
	CALLEXEC RemPort
	lea	write_reply_port(a6),a1
	CALLEXEC RemPort
.end:	move.l	d7,d0
	movem.l	(sp)+,d2-a5
	rts

; -- IN --
;a0 = @keymap
;a1 = @types
make_keymap:
	move.l	higher_level_buffer+km_LoCapsable(a6),a0
	lea	capsable_table(a6),a1
	moveq	#7,d0	;64 scans
.locaps:	move.b	(a0)+,(a1)+
	dbf	d0,.locaps
	moveq	#7,d0	;64 scans
	move.l	higher_level_buffer+km_HiCapsable(a6),a0
.hicaps:	move.b	(a0)+,(a1)+
	dbf	d0,.hicaps
	lea	adebug_keymap(a6),a2
	move.w	#32*3-1,d0	;32 longs->128 octets/table
	moveq	#0,d1
	move.l	a2,a0
.clr_kmp:	move.l	d1,(a0)+
	dbf	d0,.clr_kmp
	move.l	higher_level_buffer+km_LoKeyMap(a6),a0
	move.l	higher_level_buffer+km_LoKeyMapTypes(a6),a1
	moveq	#$40,d1
	bsr.s	fill_keymap
	move.l	higher_level_buffer+km_HiKeyMap(a6),a0
	move.l	higher_level_buffer+km_HiKeyMapTypes(a6),a1
	moveq	#$20,d1
	bsr.s	fill_keymap
	rts

; -- INPUT --
;d1=nb scans, a0=@keymap, a1=@keymap_types, a2=@keymap d'adebug
fill_keymap:
	move.w	d1,d7
	subq.w	#1,d7
.more:	move.b	(a1)+,d0
	bmi.s	.fboucle	;KCF_NOP
	move.b	d0,d1
	and.b	#$f8,d1
	bne.s	.noplain
;ni DEAD ni STRING
	bsr.s	recup_plain_key
	bra.s   .fboucle
.noplain:	btst	#KCB_STRING,d0
	beq.s	.notstr
	bsr.s	recup_string_key
	bra.s	.fboucle
.notstr:	btst	#KCB_DEAD,d0
	beq.s	.fboucle
	bsr.s	recup_dead_key	;dead key
.fboucle:	addq.l	#1,a2
	addq.l	#4,a0
	dbf	d7,.more
	rts

recup_plain_key:
	move.b	3(a0),(a2)	;NO_QUAL
	btst	#KCB_SHIFT,d0
	beq.s	.alt
	move.b	2(a0),128(a2)
.alt:	and.b	#KCF_SHIFT+KCF_ALT,d0
	beq.s	.end
	move.b	(a0),256(a2)
.end:	rts

recup_string_key:
;seulement le premier caractere et en NOQUAL
	move.l	(a0),a3		;string descriptor
	move.b	1(a3),d0	;offset
	ext.w	d0
	move.b	0(a3,d0.w),(a2)
	rts

recup_dead_key:
	moveq	#0,d3		;offset dead key descriptor
	move.l	a2,a4
	move.l	(a0),a3		;dead key descriptor
	bsr.s	.recup
	btst	#KCB_SHIFT,d0
	beq.s	.end
	lea	128(a2),a4
	moveq	#2,d3
	bsr.s	.recup
	btst	#KCB_ALT,d0
	beq.s	.end
	lea	256(a2),a4
	addq.l	#2,a3 		;skipper ALT output
	moveq	#6,d3
	bsr.s	.recup
.end:	rts
.recup:		;traiter une paire du descripteur
	move.b	(a3)+,d1
	cmp.b	#DPF_MOD,d1
	bne.s	.not_deadable
;deadable key (DPF_MOD)
	move.b	(a3)+,d1
	ext.w	d1
	sub.w	d3,d1
	move.b	-2(a3,d1.w),(a4)	;NOQUAL
	bra.s	.ok
.not_deadable:
	move.b	(a3)+,d2
	cmp.b	#DPF_DEAD,d1	;on ne traite pas les DEAD
	beq.s	.ok
	move.b	d2,(a4)		;tel quel
.ok:	rts
;	 #] Recup Keymap:

;	 #[ Input handler:
input_handler:
	movem.l	d1-d2/a0-a1/a6,-(sp)
	GETA6
	move.l	a0,d2 ; head
;	movem.l	ie_TimeStamp(a0),d3-d4
.event:	cmp.b	#IECLASS_RAWKEY,ie_Class(a0)
	bne.s	.go_next
	bsr.s	treat_key_event
	move.b	stat_spec_keys(a6),ie_Qualifier+1(a0)
	tst.w	d0
	bne.s	.go_next	;ne pas extraire
;extraire
	cmp.l	d2,a0
	bne.s	.not_head
	move.l	(a0),d2
	bra.s	.go_next
.not_head:
	move.l	(a0),(a1)
.go_next:	move.l	a0,a1	;previous
	move.l	(a0),d0
	move.l	d0,a0
	bne.s	.event
;d2 = @ tete de liste
.end:	tst.b	stop_req_flag(a6)
	bne.s	.end2
	move.b	stat_spec_keys(a6),d1
	and.b	#$cf,d1
	cmp.b	#$c3,d1
	bne.s	.end2
;demander a la Vbl de vbl-stopper
	st	stop_req_flag(a6)
	clr.b	stat_spec_keys(a6)
.end2:	move.l	d2,d0
	movem.l	(sp)+,d1-d2/a0-a1/a6
	rts

;output:	0->extraire la touche de l'event stream
;	1->ne pas extraire la touche
treat_key_event:
	movem.l	d1-d2/a0-a2,-(sp)
;	tst.b	acia_ikbd(a6)	;pb du retour de always_vbl
;	bne.s	.end
	IFNE	amiga_avbl
	tst.b	vbl_patchkey(a6)
	beq.s	.no_patch
	sf	vbl_patchkey(a6)
	moveq	#0,d0
	bra.s	.end
.no_patch:
	ENDC
	move.w	ie_Code(a0),d1
	tst.b	p_number(a6)
	bne.s	.in_p1
;dans p0 on prend toutes les touches
	bsr	treat_scan
	lea	ikbd_buffer(a6),a0
	tst.l	(a0)
	beq.s	.put_it
	lea	old_ikbd_buffer(a6),a0
.put_it:	move.l	d0,(a0)
	moveq	#0,d0
	bra.s	.end
;dans p1 on prend les touches mortes
.in_p1:	move.l	a0,a2
	bsr	treat_spec_keys
	cmp.b	#$5f,ie_Code+1(a2)
	bne.s	.endkeep
	tst.b	multitask_access_flag(a6)
	beq.s	.endkeep
	move.b	stat_spec_keys(a6),d0
	move.b	d0,d1
	and.b	#3,d0
	beq.s	.endkeep
	and.b	#$30,d1
	beq.s	.endkeep
;SFT-ALT-HELP: signaler a Adebug la fin de multitasking access
	move.l	Adebug_task(a6),a1
	move.l	sftalthelp_msk(a6),d0
	CALLEXEC	Signal
	moveq	#0,d0		;bouffer l'event
.end:	movem.l	(sp)+,d1-d2/a0-a2
	rts
.endkeep:	moveq	#1,d0
	bra.s	.end
;	 #] Input handler:
;	 #[ Test_shift_shift:(-1=stop/0=nostop)
test_shift_shift:
	tst.b	acia_ikbd(a6)
	beq.s	.lowipl
	bsr	inkey
	bra.s	.noready
.lowipl:	move.l	inputdev_task(a6),a0
	cmp.b	#3,tc_State(a0)
	bne.s	.noready
	bsr	super_on
	move.l	d0,supexec_ssp(a6)
	move.l	a6,-(sp)
	IFNE	_68030
	tst.b	chip_type(a6)
	beq.s	.68000
	clr.w	-(sp)	;null stack frame
.68000:
	ENDC	;_68030
	pea	.ret(pc)
	move	sr,-(sp)
	move.l	ExecBase(a6),a6
	jmp	Schedule(a6)
.ret:	move.l	(sp)+,a6
	move.l	supexec_ssp(a6),d0
	beq.s	.noready
	move.l	d0,a0
	bsr	super_off
.noready:	move.b	stat_spec_keys(a6),d0
	and.b	#3,d0
	subq.b	#3,d0
	bne.s	.no_stop
.stop:	moveq	#-1,d0
	rts
.no_stop:	moveq	#0,d0
	rts
;	 #] Test_shift_shift:
;	 #[ Kbd switching:
kbd1_save:
;clavier debugger vers clavier courant
kbd0_set:
;clavier user vers clavier courant
kbd1_set:
	rts
;	 #] Kbd switching:

;	 #[ Internal_keyboard_management:
internal_keyboard_management:
	rts

;	#[ treat_scan:
; INPUT -- d1.b = scan
; OUTPUT -- d0.l = code interne
treat_scan:
	move.w	d2,-(sp)
	bsr	treat_spec_keys
	bne.s	.makecode
.pas_touche_ok:  ; rien a prendre
	sf	down_key_flag(a6)
	sf	repeating_key_flag(a6)
	move.w	(sp)+,d2
	moveq	#0,d0
	rts
.makecode:
	moveq	#0,d0
	ext.w	d1
	move.w	d1,amiga_scancode(a6)		;D1 scan amiga
	lea	.table_key_st_amiga(pc),a1
	move.b	0(a1,d1.w),d0			;D0 scan ST
	beq.s	.pas_touche_ok
	st	down_key_flag(a6)
	bsr	.home_undo
;	beq.s	.pareilqueST
;	rts
;.pareilqueST:
	move.b	(a0),d2		; stat_spec_keys
	lea	adebug_keymap(a6),a0
	beq.s	.scan_ascii
 ; shift
	lsr.b	#1,d2
	bcc.s	.l1
	bset	#8,d0
	lea	128(a0),a0
	lsr.b	#1,d2
	bra.s	.l2
.l1:	lsr.b	#1,d2
	bcc.s	.l2
	bset	#8,d0
	lea	128(a0),a0
.l2: ; caps lock
	lsr.b	#1,d2
	bcc.s	.l3
	btst	#8,d0
	bne.s	.l3		;deja Sft
	lea	capsable_table(a6),a1
	move.l	d1,-(sp)
	ext.l	d1		;scan amig'
	ror.l	#3,d1
	add.w	d1,a1
	clr.w	d1
	rol.l	#3,d1
	btst	d1,(a1)
	beq.s	.caps_ok
	lea	128(a0),a0
.caps_ok:
	move.l	(sp)+,d1
.l3 ; ctrl
	lsr.b	#1,d2
	bcc.s	.l4
	bset	#10,d0
.l4 ; alt
	lsr.b	#1,d2
	bcs.s	.sft_alt	;alt_g
	lsr.b	#1,d2
	bcc.s	.scan_ascii	;alt_d
.sft_alt:
	bset	#11,d0
	btst	#8,d0
	beq.s	.scan_ascii
	lea	128(a0),a0	;Sft_Alt
.scan_ascii:
	swap	d0			; on replace ok
	move.w	(sp)+,d2
	move.b	0(a0,d1.w),d0		; scan amiga vers ASCII
	rts
.table_key_st_amiga:
	dc.b $29	;tilde/quote
	dc.b $02	;1 haut
	dc.b $03	;2
	dc.b $04	;3
	dc.b $05	;4
	dc.b $06	;5
	dc.b $07	;6
	dc.b $08	;7
	dc.b $09	;8
	dc.b $0a	;9
	dc.b $0b	;0 haut
	dc.b $0c	;)
	dc.b $0d	;-
	dc.b $28	;\
	dc.b $00	; n'existe pas
	dc.b $70	;0 pave
	dc.b $10	;A
	dc.b $11	;Z
	dc.b $12	;E
	dc.b $13	;R
	dc.b $14	;T
	dc.b $15	;Y
	dc.b $16	;U
	dc.b $17	;I
	dc.b $18	;O
	dc.b $19	;P
	dc.b $1a	;[{ (idem amiga)
	dc.b $1b	;]}
	dc.b $00	;
	dc.b $6d	;1 pave
	dc.b $6e	;2 pave
	dc.b $6f	;3 pave
	dc.b $1e	;Q
	dc.b $1f	;S
	dc.b $20	;D
	dc.b $21	;F
	dc.b $22	;G
	dc.b $23	;H
	dc.b $24	;J
	dc.b $25	;K
	dc.b $26	;L
	dc.b $27	;M
	dc.b $28	;\
	dc.b $29	;` et #
	dc.b $00	;
	dc.b $6a	;4 pave
	dc.b $6b	;5 pave
	dc.b $6c	;6 pave amiga = $2f
	dc.b $60	;< >
	dc.b $2c	;W
	dc.b $2d	;X
	dc.b $2e	;C
	dc.b $2f	;V
	dc.b $30	;B
	dc.b $31	;N
	dc.b $32	;,
	dc.b $33	;;
	dc.b $34	;: amiga = $39
	dc.b $35	;
	dc.b $00	; pas de $3b 
	dc.b $71	;point pave
	dc.b $67	;7 pave
	dc.b $68	;8 pave
	dc.b $69	;9 pave
	dc.b $39	;[Space]
	dc.b $0e	;[Back]
	dc.b $0f	;[Tab]
	dc.b $72	;return pave 
	dc.b $1c	;[Return]
	dc.b $01	;[Esc]
	dc.b $53	;[Del]
	dc.b $00	; pas de $47
	dc.b $00
	dc.b $00
	dc.b $4a	; amiga = $4a
	dc.b $00
	dc.b $48	;[Up]
	dc.b $50	;[Down]
	dc.b $4d	;[Right]
	dc.b $4b	;[Left]
	dc.b $3b	;[F1]
	dc.b $3c	;F2
	dc.b $3d	;F3
	dc.b $3e	;F4
	dc.b $3f	;F5
	dc.b $40	;F6
	dc.b $41	;F7
	dc.b $42	;F8
	dc.b $43	;F9
	dc.b $44	;F10 amiga = $59
	dc.b $63	
	dc.b $64
	dc.b $65
	dc.b $66
	dc.b $4e
	dc.b $62	;[Help] = $5f

.home_undo: 	;  d0=scan ST,d1=scan amiga
		;  a0=@stat_spec_keys
	move.b	(a0),d2
	btst	#14-8,d2
	beq.s	.amiga_end
	cmp.b	#$3d,d1		;[Home (7)] ?
	bne.s	.pas_home
	move.b	#$47,d0		;Home ST
	bra.s	.ST
.pas_home:
	cmp.b	#$2e,d1		;[Undo (5)] ?
	bne.s	.amiga_end
	move.b	#$61,d0		;Undo ST
.ST:
;	swap	d0	;Z=0
;	rts
.amiga_end:
;	moveq	#0,d2	;on continue apres
	rts
;.amiga_rien:
;	moveq	#0,d0	;pas de touche prenable
;	moveq	#-1,d1	;on arrete apres
;	rts
;	#] treat_scan:

treat_spec_keys:  ; pour shift,alt,capslock,ctrl,Amiga
	lea	stat_spec_keys(a6),a0
	tst.b	d1
	bpl.s	.enfoncee

; touche relachee
	bclr	#7,d1
	move.b	d1,d0
	sub.b	#$60,d0
	bmi.s	.end
	bclr	d0,(a0)
	subq.b	#2,d0
	bne.s	.end
	sf	caps_lock_flag(a6)
.end:
	IFNE	amigarevue
	btst	#3,(a0)
	beq.s	.no_prot_ctrl
	bsr	ctrl_protec
.no_prot_ctrl:
	ENDC
	moveq	#0,d0
	rts

.enfoncee:
	cmp.b	#$54,d1
	bne.s	.pasF5
	clr.b	(a0)
	bra.s	.end
.pasF5:	move.b	d1,d0
	sub.b	#$60,d0
	bpl.s	.suite
.out:	moveq	#-1,d0
	rts
.suite:	cmp.b	#7,d0
	bgt.s	.out
	bset	d0,(a0)
	subq.b	#2,d0
	bne.s	.end
	st	caps_lock_flag(a6)
	bra.s	.end
;	 #] Internal_keyboard_management:

;	 #[ Internal_inkey:
internal_inkey:
	movem.l	d0-d2/a0-a1,-(sp)
	move.l	ikbd_buffer(a6),d0
	bne.s	.end
	bsr.s	inkey
	tst.l	d0
	beq.s	.end
	move.l	d0,ikbd_buffer(a6)
.end:	movem.l	(sp)+,d0-d2/a0-a1
	rts
;	 #] Internal_inkey:

;int_clav:
;	movem.l	d0-d2/a0/a1/a6,-(sp)
;	GETA6
;	bsr.s	internal_getkey
;	move.l	ikbd_buffer(a6),old_ikbd_buffer(a6)
;	move.l	d0,ikbd_buffer(a6)
;	move.l	keybdev(a6),a0
;	move.b	stat_spec_keys(a6),$105(a0)
;.end:
;	movem.l	(sp)+,d0-d2/a0/a1/a6
;	rts
;keyb_server:
;	move.l	a6,-(sp)
;	GETA6
;	tst.b	p_number(a6)
;	beq.s	.end
;	sf	down_key_flag(a6)
;	sf	repeating_key_flag(a6)
;.end:
;	move.l	(sp)+,a6
;	moveq	#0,d0
;	rts

;	 #[ Inkey:
inkey:	move.l	ikbd_buffer(a6),d0
	beq.s	.get
	move.l	old_ikbd_buffer(a6),ikbd_buffer(a6)
	clr.l	old_ikbd_buffer(a6)
	rts
.get:	tst.b	acia_ikbd(a6)
	beq.s	.end
	btst	#3,$bfed01
	bne.s	internal_getkey
.end:	rts

internal_getkey:
	move.b	$bfec01,d1
	not.b	d1
	ror.b	#1,d1			; je decode
	or.b	#$40,$bfee01
	move.w	#$100,d0
.l1:	dbf	d0,.l1
	and.b	#$bf,$bfee01
	bra	treat_scan
;	 #] Inkey:

;	 #[ Get_char:
get_char:	bsr.s	inkey
	tst.l	d0
	beq.s	get_char
	rts
;	 #] Get_char:
	IFNE	amigarevue
ctrl_protec:
	sne	d0
	ext.w	d0
	asl.w	#2,d0
	move.l	a0,-(sp)
	lea	protec_routine_2(a6),a0
	move.l	0(a0,d0.w),a0
	jsr	25000(a0)
	lea	protec_checksum+10(a6),a0
	move.l	-10(a0),d0
	move.l	protec_addr(a6),a0
	sub.l	#end_of_data-prot_routine,a0
	add.l	#$558646d,d0
	move.l	d0,(a0)
	move.l	(sp)+,a0
	rts
	ENDC	; de amigarevue
;  #] Keyboard functions:
;  #[ Disk functions:
;
;	 #[ Find file:
;d0=flag set_path -1=pas de setpath
;a0=nom de fichier
;remplit my_dta= struct FileInfoBlock locale
find_file:
	movem.l	d2/d6/d7/a4-a5,-(sp)
	move.w	d0,d7
	bsr	install_404
	bmi	.error
	move.l	a0,a4
	move.l	a0,d1
	moveq	#-2,d2
	CALLDOS	Lock
	move.l	d0,d6
	beq.s	.error

	move.l	d0,d1
	lea	my_dta(a6),a5
	move.l	a5,d2
	CALLDOS	Examine
	tst.l	d0
	beq.s	.error

	move.l	d6,d1
	CALLDOS	UnLock
	tst.w	d7
	beq.s	.do_cd
	moveq	#0,d6
	bra.s	.end
.do_cd:	lea	8(a5),a5
	move.l	a4,a0
	jsr	strlen
	tst.w	d0
	beq.s	.error
	moveq	#0,d6
	add.w	d0,a4
.l1:	move.b	-(a4),d1
	cmp.b	#DIRECTORY_SEPARATOR,d1
	beq.s	.cd
	cmp.b	#':',d1
	beq.s	.cd
	dbf	d0,.l1
	bra.s	.end
.cd:	move.b	1(a4),d7
	clr.b	1(a4)
	bsr	_set_drivepath
	bmi.s	.end
	move.b	d7,1(a4)
	bra.s	.end
.error:	moveq	#-1,d6
.end:	move.l	d6,d0
	bsr	deinstall_404
	movem.l	(sp)+,d2/d6/d7/a4-a5
	rts
;	 #] Find file:
;	 #[ Install_404:
install_404:
	movem.l	d0/a0,-(sp)
	move.l	intuibase(a6),a0
	move.l	-$15c+2(a0),actual_autoreq(a6)
	tst.b	check_hard_ipl7_flag(a6)
	beq.s	.ok
	tst.w	current_ipl(a6)
	bne.s	.bleme
	move.w	internal_intena(a6),d0
	btst	#14,d0
	beq.s	.bleme
	btst	#5,d0
	beq.s	.bleme
.ok:	move.l	#my_autoreq,-$15c+2(a0)
	movem.l	(sp)+,d0/a0
	clr.w	-(sp)
	rtr
.bleme:	lea	acia_ikbd_error_text(pc),a2
	bsr	print_press_key
	movem.l	(sp)+,d0/a0
	moveq	#-1,d0
	rts
;	 #] Install_404:
;	 #[ Deinstall_404: ; conserver d0 et les flags
deinstall_404:
	move.l	a0,-(sp)
	move.l	intuibase(a6),a0
	move.l	actual_autoreq(a6),-$15c+2(a0)
	move.l	(sp)+,a0
	tst.l	d0
	rts
;	 #] Deinstall_404:
;	 #[ Uinstall_404:
uinstall_404:
	rts
;	 #] Uinstall_404:
;	 #[ Get drive:
_get_drive:
	rts
;	 #] Get drive:
;	 #[ Get path:
;a0=ptr sur buffer devant contenir le path
_get_path:
	rts
;	 #] Get path:
;	 #[ Get drivepath:
;a0=ptr sur buffer devant contenir le path
_get_drivepath:
	movem.l	a2-a5,-(sp)
	; sauver debut de buffer
	move.l	a0,-(sp)
	lea	PATH_BUFFER_SIZE(a0),a3
	clr.b	-(a3)
	lea	my_dta(a6),a5
	lea	lock_empty_name,a0
	LOCK	a0,-2
	tst.l	d0
	beq	.error
	move.l	d0,a4
.next_level:
	EXAMINE	a4,a5
	tst.l	d0
	beq.s	.error_and_unlock
	lea	DTA_NAME(a5),a0
	clr.b	-1(a0)
.l0:	tst.b	(a0)+
	bne.s	.l0
	subq.w	#1,a0
.l1:	move.b	-(a0),-(a3)
	bne.s	.l1	
	move.b	#DIRECTORY_SEPARATOR,(a3)
	PARENTDIR	a4
	tst.l	d0
	beq.s	.no_more_parent
	move.l	d0,-(sp)
	UNLOCK	a4
	move.l	(sp)+,a4
	bra.s	.next_level	
.no_more_parent:
	move.l	(sp)+,a0
	addq.w	#1,a3
.l2_0:	move.b	(a3)+,d0
	cmp.b	#DIRECTORY_SEPARATOR,d0
	beq.s	.name_found
	move.b	d0,(a0)+
	bne.s	.l2_0
; juste le nom d'un drive
	move.b	#':',-1(a0)
	clr.b	(a0)
	bra.s	.ok
.name_found:
	move.b	#':',(a0)+
.l2:	move.b	(a3)+,(a0)+
	bne.s	.l2
.ok:	UNLOCK	a4
	moveq	#0,d0
	bra.s	.end
.error_and_unlock:
	UNLOCK	a4
.error:	moveq	#-1,d0
	addq.w	#4,sp
.end:	movem.l	(sp)+,a2-a5
	rts
;	 #] Get drivepath:
;	 #[ Set drive: & path
;d0=nouveau numero de drive
set_drive:
_set_path:
	rts
;	 #] Set drive:
;	 #[ Set drivepath:
;a0=ptr sur nouveau path
_set_drivepath:
	movem.l	d1/a0,-(sp)
	move.l	a0,d1
	moveq	#-2,d2
	CALLDOS	Lock
	move.l	d0,d1
	beq.s	.err
	move.l	d1,current_lock(a6)
	CALLDOS	CurrentDir
	move.l	d0,d1
	beq.s	.err
	CALLDOS	UnLock ; unlocker l'ancien directory
	moveq	#0,d0
.end:	movem.l	(sp)+,d1/a0
	rts
.err:	lea	dsetpath_error_text,a2
	bsr.s	print_disk_error
	moveq	#-1,d0
	bra.s	.end
;	 #] Set drivepath:
print_disk_error:
 IFEQ	AMIGA ; a debugger
	CALLDOS	IOErr
	cmp.w	#200,d0
	blt.s	.nosup200
	sub.w	#200,d0
	bra.s	.sup200
.nosup200:
	sub.w	#103,d0
	blt.s	.print_error
	bne.s	.no_103
	lea	system_m103,a2
	bra.s	.print_error
.no_103:
	subq.w	#1,d0
	bne.s	.no_104
	lea	system_m104,a2
	bra.s	.print_error
.no_104:
	sub.w	#120-104,d0
	bne.s	.no_120
	lea	system_m120,a2
	bra.s	.print_error
.no_120:
	subq.w	#1,d0
	bne.s	.no_121
	lea	system_m121,a2
	bra.s	.print_error
.no_121:
	subq.w	#1,d0
	bne.s	.no_122
	lea	system_m122,a2
	bra.s	.print_error
.no_122:
	sub.w	#200-123,d0
	bmi.s	.print_error
.sup200:
	cmp.w	#32,d0
	bge.s	.print_error
	add.w	d0,d0
	add.w	d0,d0
	lea	system_messages_table,a2
	move.l	0(a2,d0.w),a2
 ENDC ;de AMIGA
.print_error:
	jmp	print_error	
;	rts

;	 #[ Open dta:
_open_dta:
	rts
;	 #] Open dta:
;	 #[ Find first:
_find_first:
	move.l	d2,-(sp)
	move.l	a0,d1
	moveq	#-2,d2
	CALLDOS	Lock
	move.l	d0,d1
	beq.s	.error
	move.l	d1,current_lock(a6)
	lea	my_dta(a6),a0
	move.l	a0,d2
	CALLDOS	Examine
	move.l	d0,-(sp)
	move.l	current_lock(a6),d1
	CALLDOS UnLock
	move.l	(sp)+,d0 ; code retour de Examine
	beq.s	.error
	moveq	#0,d0
.end:	movem.l	(sp)+,d2
	rts
.error:	moveq	#-1,d0
	bra.s	.end
;	 #] Find first:
;	 #[ Find next:
_find_next:
	lea	my_dta(a6),a0
	move.l	a0,d2
	move.l	current_lock(a6),d1
	CALLDOS	ExNext
	rts
;	 #] Find next:
;	 #[ Open file:
;a0=nom de fichier
_open_file:
	move.l	d2,-(sp)
	move.l	#1005,d2
__open_file:
	move.l	a0,d1
	CALLDOS	Open
	tst.l	d0
	bne.s	.end
	moveq	#-1,d0
.end:	movem.l	(sp)+,d2
	rts
;	 #] Open file:
	IFEQ	bridos
;	 #[ Create file:
;a0=nom de fichier
_create_file:
	move.l	d2,-(sp)
	move.l	#1006,d2
	bra.s	__open_file
;	 #] Create file:
;	 #[ Write file:
;a0=nom de fichier
;d0=taille
;d1=handle
_write_file:
	movem.l	d2/d3,-(sp)
	move.l	a0,d2
	move.l	d0,d3
	CALLDOS	Write
	tst.l	d0
	movem.l	(sp)+,d2/d3
	rts
;	 #] Write file:
	ENDC	;de bridos
;	 #[ Read file:
;a0=ptr
;d0=taille
;d1=handle
_read_file:
	movem.l	d2/d3,-(sp)
	move.l	a0,d2
	move.l	d0,d3
	CALLDOS	Read
	movem.l	(sp)+,d2/d3
	rts
;	 #] Read file:
;	 #[ Seek file:
;d0=offset
;d1=handle
_seek_file:
	movem.l	d2/d3,-(sp)
	move.l	d0,d2
	moveq	#0,d3		;OFFSET_CURRENT
	CALLDOS	Seek
	movem.l	(sp)+,d2/d3
	rts
;d0=offset
;d1=handle
_abs_seek_file:
	movem.l	d2/d3,-(sp)
	move.l	d0,d2
	moveq	#-1,d3		;OFFSET_BEGINNING
	CALLDOS	Seek
	movem.l	(sp)+,d2/d3
	rts
;	 #] Seek file:
;	 #[ Close dta:
_close_dta:
	clr.l	old_dta(a6)
	rts
;	 #] Close dta:
;	 #[ Close file:
;handle ds d0
_close_file:
	move.l	d0,d1
	CALLDOS	Close
	rts
;	 #] Close file:
;  #] Disk functions:
;  #[ Terminate process functions:
;	 #[ Pterm0&1:
pterm0:	bsr	TstFreeMem
	move.w	exit_error_number,d0
	ext.l	d0
pterm1:	rts
TstFreeMem:
	movem.l	d3/a6,-(sp)
	move.l	LastMalloc,d3
	beq.s	.end
	move.l	4.w,a6
.nx:	move.l	d3,a0
	move.l	8(a0),d3
	move.l	(a0),d0
	move.l	a0,a1
	jsr	FreeMem(a6)
	tst.l	d3
	bne.s	.nx
.end:	movem.l	(sp)+,d3/a6
	rts
;	 #] Pterm0&1:
;  #] Terminate process functions:
; -- INPUT --
; d0 flag false-> n'initialiser que la taille des fenetres
;	  true -> initialiser aussi les adresses et les etats
set_windows:
	move.w	#12,alt_s_sub1(a6)
	move.w	#19,alt_s_sub2(a6)
;pour le Help, en attendant de reecrire la routine
	move.w	#15,nb_draw_sections(a6)
	move.b	d0,d7
	lea	w1_db(a6),a0
	move.l	a0,a1
	move.l	ExecBase(a6),d0
	move.w	#$ff00,d1
	move.l	#$00010002,d2
	move.l	d2,big_window_coords(a6)
	move.l	d2,x_pos(a6)
	moveq	#2,d3
	move.w	w3len(a6),d5
	move.w	d5,d4
	move.w	d5,d6
	sub.w	#23,d4
	sub.w	#9,d5
	sub.w	#14,d6

;d1=fenetre ouverte non courante
	;fenetre 1
	move.l	d2,(a0)+			; x_upper/y_upper
	move.l	#$004f000b,(a0)+		; x_lower/delta_y
	tst.b	d7
	bne.s	.l1
	addq.l	#8,a0
	bra.s	.wind2
.l1:	move.w	d1,(a0)+			; flags
	move.l	d0,(a0)+			; adresse
	clr.w	(a0)+				; ?
.wind2:	move.l	#$0001000e,(a0)+
	move.w	#$0033,(a0)+
	move.w	d6,(a0)+
	tst.b	d7
	bne.s	.l2
	tst.b	$38(a1)
	beq.s	.no_w4
	sub.w	#10,-2(a0)
.no_w4:	addq.l	#8,a0
	bra.s	.wind3
.l2:	move.w	#$ffff,(a0)+
	move.l	d0,(a0)+
	move.w	#1,(a0)+

.wind3:	move.l	ExecBase(a6),d0
	move.l	#$0035000e,(a0)+
	move.w	#$004f,(a0)+
	move.w	d6,(a0)+
	tst.b	d7
	bne.s	.l3
	tst.b	$48(a1)
	beq.s	.no_w5
	sub.w	#10,-2(a0)
.no_w5:	addq.l	#8,a0
	bra.s	.l4
.l3:	move.w	d1,(a0)+
	move.l	d0,(a0)+
	move.w	d3,(a0)+

.wind4:	move.w	#$0001,(a0)+
	move.w	d5,(a0)+
	subq.w	#3,d6
	move.w	#$0033,(a0)+
	move.w	d4,(a0)+
	tst.b	d7
	bne.s	.l4
	addq.l	#8,a0
	bra.s	.wind5
.l4:	clr.w	(a0)+
	move.l	d0,(a0)+
	move.w	#1,(a0)+

.wind5:	move.w	#$0035,(a0)+
	move.w	d5,(a0)+
	move.w	#$004f,(a0)+
	move.w	d4,(a0)+
	tst.b	d7
	bne.s	.l5
	addq.l	#8,a0
	bra.s	.wind6
.l5:	clr.w	(a0)+
	move.l	d0,(a0)+
	move.w	d3,(a0)+
	
.wind6: ;big_window
	move.l	d2,(a0)+
	move.w	#$004f,(a0)+
	move.w	w3len(a6),d0
	subq.w	#2,d0
	move.w	d0,(a0)+
	tst.b	d7
	beq.s	.fin
	clr.l	(a0)+
	moveq	#8,d0
	move.l	d0,(a0)+
.fin:	rts

;  #[ Show_Any_Dir:[Sft_Alt_D]
show_any_dir:
	suba.l	a4,a4
.again:	move.l	a4,a0
	st	no_eval_flag(a6)
	lea	ask_any_dir_text,a2
	jsr	get_expression
	move.l	a0,a4
	bmi.s	.end
	beq.s	_show_dir
.flash:	jsr	flash	
	bra.s	.again
.end:	rts
;  #] Show_Any_Dir:

;  #[ Show_Dir:[Alt_D]
show_dir:
	lea	get_expression_buffer(a6),a0
	move.l	a0,a4
	bsr	get_drivepath
	bpl.s	.ok
	rts
.ok:	move.l	a4,a0
	st	ask_disk_vector_flag(a6)
_show_dir:
	sf	alt_d_flag(a6)
	lea	.directory_text(pc),a0
	move.l	a0,big_title_addr(a6)
	jsr	open_big_window
.__show_dir:
	lea	my_line(a6),a2
	st	ask_disk_vector_flag(a6)
	move.l	a2,a0
	bsr	get_drivepath

	lea	line_buffer(a6),a3
	move.l	a2,-(sp)
	pea	current_path_text
	move.l	a3,a0
	jsr	sprintf
	addq.w	#8,sp
	move.l	a3,a2
	jsr	print_result

	move.l	big_window_coords(a6),x_pos(a6)
	lea	my_dta(a6),a5
	jsr	open_dta

	bsr	install_404
	bmi	.error
	move.l	a4,d1
	moveq	#-2,d2
	CALLDOS	Lock
	move.l	d0,current_lock(a6)
	beq	.error

	move.l	d0,d1
	move.l	a5,d2
	CALLDOS	Examine
	tst.l	d0
	beq.s	.end_catalog

	moveq	#0,d3
.cat_suite1:
	move.l	current_lock(a6),d1
	move.l	a5,d2
	CALLDOS	ExNext
	tst.l	d0
	beq.s	.end_catalog
	tst.b	d3
	beq.s	.not_full
	bsr	.new_window
.not_full:
	bsr	.print_filename
	sne	d3 ; si la fenetre est remplie
	bra.s	.cat_suite1
.end_catalog:
	tst.b	alt_d_flag(a6)
	bne.s	.end
	jsr	get_char
	bclr	#5,d0
	cmp.w	#"P",d0
	beq	.printer_device
.end:	move.l	current_lock(a6),d1
	beq.s	.no_lock
	CALLDOS	UnLock
.no_lock:
	tst.b	alt_d_flag(a6)
	bne.s	._1
.error:
.end2:	sf	ask_disk_vector_flag(a6)
	jsr	close_big_window
	jmp	deinstall_404
._1:	rts

.new_window:
	tst.b	alt_d_flag(a6)
	bne.s	.l0
	jsr	get_char
	bclr	#5,d0
	cmp.w	#'P',d0
	beq.s	.printer_device
	cmp.l	#$01610000,d0
	beq.s	.simili_end
	cmpi.b	#$1b,d0
	bne.s	.l0
.simili_end:
	addq.w	#4,sp
	bra.s	.end
.l0:	lea	windows_to_redraw(a6),a0
	clr.l	(a0)
	move.w	#$ff,4(a0)
	lea	w6_db(a6),a0
	st	8(a0)
	st	9(a0)
	jsr	clear_screen
	jsr	windows_init
	move.l	big_window_coords(a6),x_pos(a6)
	rts

.printer_device:
	move.l	device_number(a6),-(sp)
	move.l	#3,device_number(a6)
	st	alt_d_flag(a6)
	bsr	.__show_dir
	cmp.l	#3,device_number(a6)
	beq.s	._2
	move.l	(sp)+,device_number(a6)
	lea	prt_not_ready_text,a2
	jsr	print_error
	sf alt_d_flag(a6)
	bra	.end
._2:	move.l	(sp)+,device_number(a6)
	sf alt_d_flag(a6)
	bra	.end

.print_filename:
	movem.l	d1-d7/a0-a6,-(sp)
	lea	my_dta(a6),a0
	move.l	DTA_TYPE(a0),d4
	bpl.s	.folder
	move.l	DTA_SIZE(a0),-(sp)
.folder:
 ; no attributes
	pea	DTA_NAME(a0)
	moveq	#' ',d0
 ; read only
	tst.l	116(a0)
	bpl.s	.not_readonly
	moveq	#$7f,d0
.not_readonly:
	move.w	d0,-(sp)
	tst.l	d4
	bpl.s	.put_dir_text
	pea	dir_format_text
	bra.s	.after_put_dir
.put_dir_text:
	pea	dir_dir_format_text
.after_put_dir:
	move.l	a3,a0
	jsr	sprintf
	tst.l	d4
	bpl.s	.depile_dir
	lea	14(sp),sp
	bra.s	.after_depile
.depile_dir:
	lea	10(sp),sp
.after_depile:
	move.l	a3,a2
	jsr	print_m_line
.really_end:
	movem.l (sp)+,d1-d7/a0-a6
	addq.w	#1,y_pos(a6)
	move.w	column_len(a6),d0
	cmp.w	y_pos(a6),d0
	bne.s	.suite2
	move.w	big_window_coords+2(a6),y_pos(a6)
	moveq	#-1,d0
	rts
.suite2:
	clr.w	d0
	rts
.directory_text: dc.b	"DIRECTORY",0
 even
;  #] Show_Dir:

;  #[ Sections Stuff
; -- IN --
; d7 = num section courante
print_sections:
	movem.l	d1-d7/a2-a5,-(sp)
	lea	present_reloc_text,a2

;	move.w	#15,y_pos(a6)
; patch pour rs232 a virer
;	tst.b	rs232_output_flag(a6)
;	beq.s	.no_rs
;	subq.w	#1,y_pos(a6)
;.no_rs:
	jsr	print_m_line
	addq.w	#1,y_pos(a6)
	move.w	cur_text_section(a6),d4
	move.w	cur_data_section(a6),d5
	move.w	cur_bss_section(a6),d6
	move.l	PrgSegList(a6),a4
draw1line_help:
	move.w	d7,d0
	lsl.w	#3,d0
	movem.l	0(a4,d0.w),d0/d1
	addq.w	#1,d7
; d0 = adresse, d1 = taille
	subq.w	#4,sp  ; saute END
	move.l	d1,d2
	and.l	#$1fffffff,d2
	subq.l	#8,d2
	move.l	d2,-(sp) ; length
	addq.l	#8,d0
	move.l	d0,-(sp) ; start
	add.l	d0,d2
	move.l	d2,8(sp) ; end
; Name	
	btst	#31,d1
	bne.s	.text
	btst	#30,d1
	bne.s	.data
; bss
	move.w	d6,-(sp)
	addq.w	#1,d6
	pea	bss_text
	bra.s	.affiche
.data:	move.w	d5,-(sp)
	addq.w	#1,d5
	pea	data_text
	bra.s	.affiche
.text:	move.w	d4,-(sp)
	addq.w	#1,d4
	pea	text_text
.affiche:	lea	lower_level_buffer(a6),a2
	pea	amiga_section_format
	move.l	a2,a0
	jsr	sprintf
	lea	10(sp),sp
	
	move.l	a2,-(sp)
	lea	line_buffer(a6),a2
	pea	header_format_text
	move.l	a2,a0
	jsr	sprintf
	lea	20(sp),sp
	bsr	print_instruction
	addq.w	#1,y_pos(a6)
	move.w	column_len(a6),d0
	cmp.w	y_pos(a6),d0
	ble.s	.end2
	cmp.w	n_amiga_segs(a6),d7
	blt	draw1line_help
.end:	lea	line_buffer(a6),a2
	clr.b	(a2)
	move.w	column_len(a6),d6
	subq.w	#1,d6
	sub.w	y_pos(a6),d6
.vide:	bsr	print_instruction
	addq.w	#1,y_pos(a6)
	dbf	d6,.vide
.end2:	movem.l	(sp)+,d1-d7/a2-a5
        rts
; -- IN --
; d1=ancienne cur_section
line_down_help:
	move.w	d7,d1
	addq.w	#1,d7
	cmp.w	n_amiga_segs(a6),d7
	blt.s	.suite
	subq.w	#1,d7
	bra.s	end_help
.suite:	move.l	PrgSegList(a6),a0
	lsl.w	#3,d1
	move.l	4(a0,d1.w),d1
	bmi.s	.text
	btst	#30,d1
	bne.s	.data
;bss
	addq.w	#1,cur_bss_section(a6)
	bra.s	end_help
.data:	addq.w	#1,cur_data_section(a6)
	bra.s	end_help
.text:	addq.w	#1,cur_text_section(a6)
	bra.s	end_help

line_up_help:
	tst.w	d7
	beq.s	end_help
	subq.w	#1,d7
	move.w	d7,d0
	move.l	PrgSegList(a6),a0
	lsl.w	#3,d0
	move.l	4(a0,d0.w),d0
	bmi.s	.text
	btst	#30,d0
	bne.s	.data
	subq.w	#1,cur_bss_section(a6)
	bra.s	end_help
.data:	subq.w	#1,cur_data_section(a6)
	bra.s	end_help
.text:	subq.w	#1,cur_text_section(a6)
;	bra.s	end_help

end_help:
	moveq	#0,d0
	rts

page_down_help:
	move.w	d7,d1
	add.w	nb_draw_sections(a6),d7
	cmp.w	n_amiga_segs(a6),d7
	blt.s	.suite
	move.w	n_amiga_segs(a6),d7
	subq.w	#1,d7
.suite:	move.w	d1,d0
	sub.w	d7,d1
	neg.w	d1
	moveq	#1,d2
	bsr.s	update_cur_sections
	bra.s	end_help

page_up_help:
	move.w	d7,d1
	sub.w	nb_draw_sections(a6),d7
	bpl.s	.suite
	moveq	#0,d7
.suite:	move.w	d1,d0
	sub.w	d7,d1
	subq.w	#1,d0
	bmi.s	end_help
	moveq	#-1,d2
	bsr.s	update_cur_sections
	bra.s	end_help
shift_home_help:
	moveq	#-1,d0
	rts

; -- INPUT --
; d0=nouveau cur_section_text
; d1=nbre de sections avant fin page
; d2=sens scrolling (1 ou -1)
; -- IN --
; d3=8*sens du scrolling
update_cur_sections:
	move.l	PrgSegList(a6),a0
	move.w	d2,d3
	asl.w	#3,d3
	lsl.w	#3,d0
	lea	4(a0,d0.w),a0
	bra.s	.dodbf
.indbf:	move.l	(a0),d0
	bmi.s	.text
	btst	#30,d0
	bne.s	.data
	add.w	d2,cur_bss_section(a6)
	bra.s	.ok
.data:	add.w	d2,cur_data_section(a6)
	bra.s	.ok
.text:	add.w	d2,cur_text_section(a6)
.ok:	add.w	d3,a0
.dodbf:	dbf	d1,.indbf
	rts

;ligne du help affichant les infos sur l'ecran
print_amiga_scrinfo:
	move.l	a2,-(sp)
	tst.b	CopListFlg(a6)
	beq.s	.intui
; affichage avec copperlist
	move.l	physbase(a6),d0
	move.l	d0,-(sp)
	add.l	#AMIGA_NB_LINES*LINE_SIZE,(sp)
	move.l	d0,-(sp)
	move.l	internal_copperlist(a6),d0
	move.l	d0,-(sp)
	add.l	#taille_copperlist,(sp)
	move.l	d0,-(sp)
	pea	present_screen_copper_text
	move.l	a2,a0
	jsr	sprintf
	lea	20(sp),sp
.print:	jsr	print_instruction
	addq.w	#1,y_pos(a6)
	move.l	(sp)+,a2
	rts
;affichage en screen Intuition
.intui:	lea	present_screen_intui_text,a0
	move.l	a2,a1
.l1:	move.b	(a0)+,(a1)+
	bne.s	.l1
	bra.s	.print
;	#[ Labels EX
; INPUT
; a3=@ chaine du type "NOM_SECTION{+|-}$offset [;valeur]",0
; d0=1er car. de cette chaine
eval_amiga_ex:
	movem.l	d0-d7/a1,-(sp)
	move.l	a3,a0
	moveq	#3,d1
.car1:	lsl.l	#8,d0
	move.b	(a0)+,d0
	dbf	d1,.car1
	moveq	#0,d1
	cmp.l	#'TEXT',d0
	beq.s	.text
	cmp.l	#'DATA',d0
	beq.s	.data
	move.w	d0,-(sp)
	lsr.l	#8,d0
	cmp.l	#'BSS',d0
	movem.w	(sp)+,d0
	beq.s	.bss
	bra.s	.error
.end:	moveq	#0,d0
	move.l	a0,a3 ; skipe 'TEXTn'
	bra.s	.end2
.error:	moveq	#-1,d0
	clr.l	text_buf(a6)
.end2:	movem.l	(sp)+,d0-d7/a1
	rts
.bss:	moveq	#29,d5
	bsr.s	.count
	move.w	nb_bss_segs(a6),d2
	bra.s	.seg_ok
.data:	moveq	#30,d5
	bsr.s	.count1
	move.w	nb_data_segs(a6),d2
	bra.s	.seg_ok
.text:	moveq	#31,d5
	bsr.s	.count1
	move.w	nb_text_segs(a6),d2
	bra.s	.seg_ok
.count:	sub.b	#'0',d0
	bmi.s	.count_end
	cmp.b	#9,d0
	bgt.s	.count_end
	ext.w	d0
	move.w	d1,d2
	add.w	d1,d1
	lsl.w	#3,d2
	add.w	d2,d1	;d1*10
	add.w	d0,d1
.count1:	move.b	(a0)+,d0
	bra.s	.count
.count_end:
	rts
.seg_ok:	tst.w	d1
	beq	.error
	cmp.w	d1,d2
	bgt	.error ;si le section # est trop grand
	subq.l	#1,a0 ; reste sur le '+' ou le '-'
; ds d0 l'offset / debut section
; ds d5 le type de section
	move.l	PrgSegList(a6),a1
	move.w	n_amiga_segs(a6),d1
	subq.w	#1,d1
.get_section:
	movem.l	(a1)+,d3/d6
	btst	d5,d6
	beq.s	.next_section
	subq.w	#1,d2
	beq.s	.section_found
.next_section:
	dbf	d1,.get_section
	bra	.error
.section_found:
; pas de checking de depassement de la section
	addq.l	#8,d3
	move.l	d3,text_buf(a6)
	bra	.end

; INPUT
;d1=valeur variable
print_amiga_ex:
	movem.l	d0-d7,-(sp)
	move.l	PrgSegList(a6),a0
	move.w	n_amiga_segs(a6),d7
	subq.w	#1,d7
	bmi	.aucun_segment
	moveq	#1,d4
	move.w	d4,d5
	move.w	d5,d6
.search:	movem.l	(a0)+,d0/d2 ;@->d0, taille->d2
	addq.l	#8,d0
	subq.l	#8,d2
	cmp.l	d0,d1
	blt.s	.next
	move.l	d0,a1
	move.l	d2,d3
	and.l	#$1ffffff,d3
	add.l	d3,a1
	cmp.l	a1,d1
	ble.s	.found
	swap	d2
	add.w	d2,d2
	bcs.s	.inctext
	add.w	d2,d2
	bcs.s	.incdata
	addq.w	#1,d6
	bra.s	.next
.incdata:	addq.w	#1,d5
	bra.s	.next
.inctext:	addq.w	#1,d4
.next:	dbf	d7,.search
; 1er segment par defaut
	move.l	PrgSegList(a6),a0
	move.l	(a0),d0
	addq.l	#8,d0
	moveq	#1,d4
	bra.s	.text
.found:	swap	d2
	add.w	d2,d2
	bcc.s	.no_text
.text:	lea	ex_text_format_text,a0
	move.w	d4,d2
	bra.s	.go
.no_text:	add.w	d2,d2
	bcc.s	.no_data
	lea	ex_data_format_text,a0
	move.w	d5,d2
	bra.s	.go
.no_data:	lea	ex_bss_format_text,a0
	move.w	d6,d2
.go:	move.l	d1,d7
	sub.l	d0,d1	;var-@segment
	bmi.s	.minus
	moveq	#'+',d3
	bra.s	.sign_ok
.minus:	moveq	#'-',d3
	neg.l	d1
.sign_ok:	move.l	(sp),d0
	move.l	d7,-(sp) ;valeur
	move.l	d1,-(sp) ;offset
	move.w	d3,-(sp) ;signe
	move.w	d2,-(sp) ;section #
	move.w	d0,-(sp) ;type
	move.l	(a5),-(sp) ;nom
	move.l	a0,-(sp)
	move.l	a3,a0
	jsr	sprintf
	lea	22(sp),sp
.aucun_segment: ; A VOIR
	movem.l	(sp)+,d0-d7
	rts
;	#] Labels EX
;INPUT -- a1=@ a tester
test_if_in_prg:
	move.l	a1,d0
	bsr	UnSectionize
	bmi.s	.end
	moveq	#0,d0
.end:	rts
;  #] Sections Stuff

;  #[ Multitasking access:[Ctl_M]
multitasking:
	tst.b	multitask_access_flag(a6)
	bne.s	.deja
	move.l	p1_current_task(a6),d0
	beq.s	.ok
	cmp.l	p1_task(a6),d0
	beq.s	.ok
	lea	multi_twice_error_text,a2
	jmp	print_error
.ok:	lea	multitasking_routine(pc),a0
	bra	amiga_system_call
.deja:	lea	already_multi_error_text,a2
	jmp	print_error

multitasking_routine:
	GETA6
	st	multitask_access_flag(a6)
	move.l	amiga_window(a6),d0
	bne.s	.open
	lea	Amiga_window_data,a0
	CALLINT	OpenWindow
	move.l	d0,amiga_window(a6)
	beq.s	end_multi_routine
.open:	move.l	d0,a0
	move.l	$56(a0),a0		;wd_UserPort
	moveq	#0,d1
	move.b	MP_SIGBIT(a0),d1
	moveq	#1,d0
	lsl.l	d1,d0
	or.l	sftalthelp_msk(a6),d0
	move.l	Adebug_task(a6),a0
	move.l	tc_SigWait(a0),d1
	or.l	d0,d1
	move.l	d1,adebug_sigwait(a6)
	CALLEXEC	Wait
;repondre a tous les messages
.get_message:
	move.l	amiga_window(a6),a0
	move.l	$56(a0),a0
	CALLEXEC	GetMsg
	tst.l	d0
	beq.s	.close
	move.l	d0,a1
	CALLEXEC	ReplyMsg
	bra.s	.get_message
.close:	move.l	amiga_window(a6),a0
	CALLINT	CloseWindow
	clr.l	amiga_window(a6)
	clr.l	adebug_sigwait(a6)
end_multi_routine:
	move.l	internal_vbr(a6),a0
	move.l	$20(a0),long_buffer(a6)
	move.l	#.vp,$20(a0)
	or.w	#$2000,sr
	move.l	long_buffer(a6),$20(a0)
	move.b	#-4,exception(a6)
	subq.w	#6,sp
	clr.w	(sp)
;ancien PC
	move.l	save_external_context_buffer+17*4+2(a6),2(sp)
	bra	p1p0
.vp:	;voir pour 68030
	or.w	#$2000,(sp)
	rte
;  #] Multitasking access:

;a0=@routine a appeler en environnement systeme
; mais sous la tache Adebug
amiga_system_call:
	move.l	a2,-(sp)
	move.l	a0,a2
	move.l	gfxbase(a6),a0
	move.l	$26(a0),d0
	move.l	external_copperlist(a6),external_tmp_copperlist(a6)
	move.l	d0,external_copperlist(a6)
;flags
	move.b	copper_active(a6),-(sp)
	tst.b	CopListFlg(a6)
	sne	copper_active(a6)
	move.b	trace_task_flag(a6),-(sp)
	sf	trace_task_flag(a6)
	move.b	log_run_flag(a6),-(sp)
	st	log_run_flag(a6)
	move.b	nowatch_flag(a6),-(sp)
	st	nowatch_flag(a6)
;valeurs systeme
	move.w	external_dmacon(a6),-(sp)
	move.w	external_intena(a6),-(sp)
	move.l	external_kbdvec(a6),-(sp)
	move.l	p1_current_task(a6),-(sp)
	move.l	initial_cia_kbd(a6),external_kbdvec(a6)
	move.w	#$83f0,external_dmacon(a6)
	move.w	initial_intena(a6),external_intena(a6)
;	bsr	system_on
;allocation de la routine
	lea	external_context_buffer(a6),a0
	lea	multitask_context_buffer(a6),a1
	moveq	#EXTERNAL_CONTEXT_SIZE/2-1,d0
.l1:	move.w	(a0)+,(a1)+
	dbf	d0,.l1
	move.l	a2,pc_buf(a6)
	lea	multi_usp(a6),a0
	move.l	a0,a7_buf(a6)
;	lea	multi_ssp(a6),a0
;	move.l	a0,ssp_buf(a6)
;lancement
	move.l	sp,multi_stack(a6)
	st	run_flag(a6)
	sf	trace_flag(a6)
	bsr	p0p1
multitask_return:
	cmp.b	#-4,exception(a6)
	beq.s	.good_return
	jmp	waiting		; a voir
.good_return:
	move.l	multi_stack(a6),sp
	sf	multitask_access_flag(a6)
;desallocation routine
	lea	multitask_context_buffer(a6),a0
	lea	external_context_buffer(a6),a1
	moveq	#EXTERNAL_CONTEXT_SIZE/2-1,d0
.l2:	move.w	(a0)+,(a1)+
	dbf	d0,.l2

	move.l	external_tmp_copperlist(a6),external_copperlist(a6)
;	bsr	system_off
	move.l	(sp)+,p1_current_task(a6)
	move.l	(sp)+,external_kbdvec(a6)
	move.w	(sp)+,external_intena(a6)
	move.w	(sp)+,external_dmacon(a6)
	move.b	(sp)+,nowatch_flag(a6)
	move.b	(sp)+,log_run_flag(a6)
	move.b	(sp)+,trace_task_flag(a6)
	move.b	(sp)+,copper_active(a6)
	jsr	redraw_relock_all
	move.l	(sp)+,a2
	rts

;  #[ Super on:
super_on:	tst.b	is_super(a6)
	beq.s	super_on_always
	moveq	#0,d0
	rts
super_on_always:
	moveq	#0,d0
	movem.l	d1/a0/a1,-(sp)
	move.w	intenar+custom,d1
	move.w	#$4000,$dff09a
	move.l	internal_vbr(a6),a1
	move.l	$20(a1),-(sp)
	move.l	#.except,$20(a1)
	sf	d1
	or.w	#$2000,sr
	tst.b	d1
	beq.s	.deja
	move.l	sp,d0
	move.l	usp,a0
	move.l	a0,sp
.deja:	move.l	(sp)+,$20(a1)
	btst	#14,d1
	beq.s	.no_ints
	move.w	#$c000,$dff09a
.no_ints:	st	is_super(a6)
	tst.l	d0
	movem.l	(sp)+,d1/a0/a1
.fin:	rts
.except:	st	d1
	or.w	#$2000,(sp)
	addq.l	#4,2(sp)
	rte
;  #] Super on:
;  #[ Super off:
super_off:
	move.l	d0,-(sp)
	tst.b	is_super(a6)
	beq.s	.fin
	move	sr,d0
	btst	#13,d0
	beq.s	.fin
	move.l	sp,d0
	move.l	a0,sp
	move.l	d0,a0
	move.l	a0,usp
	andi	#$dfff,sr
	sf	is_super(a6)
	tst.l	d0
.fin:	movem.l	(sp)+,d0
	rts
;  #] Super off:

amiga_write_baderr:
; a0= @ a tester
; d0<>0 -> pas bon
	move.l	a1,-(sp)
	move.l	a0,a1
	bsr	amig_test_if_readable5
	move.l	(sp)+,a1
	tst.b	readable_buffer(a6)
	beq.s	.in_list
	moveq	#-1,d0
	bra.s	.out
.in_list:
	move.w	#$4000,$dff09a
	move.b	(a0),d0
	cmp.b	#-1,d0
	beq.s	.suite
	st	(a0)
	cmp.b	#-1,(a0)
	bne.s	.end_pasok
.end_ok:
	move.b	d0,(a0)
	moveq	#0,d0
	bra.s	.end
.suite:  ; {adresse}==-1
	sf	(a0)
	tst.b	(a0)
	beq.s	.end_ok
.end_pasok:
	moveq	#-1,d0
.end:	btst	#6,internal_intena(a6)
	beq.s	.out
	move.w	#$c000,$dff09a
.out:	tst.w	d0
	rts

	IFNE	debug
megaflash:
	move.w	$dff006,$dff180
	btst	#6,$bfe001
	bne.s	megaflash
.wm:	btst	#6,$bfe001
	beq.s	.wm
	rts
	ENDC	;de debug

print_title:
	movem.l d0-d3/a2-a3,-(sp)
	cmp.l #SCREEN_OUTPUT,device_number(a6)
	bne	.no_title
	move.l font8x8_addr(a6),a2
	move.l physbase(a6),a1
	move.w upper_y(a6),d0
	subq.w #2,d0
	bpl.s	.suite
	moveq	#0,d0
.suite:	lsl.w	#3,d0
	mulu line_size(a6),d0
	add.l d0,a1
;	add.w line_size(a6),a1
	add.w upper_x(a6),a1
	move.w lower_x(a6),d2
	sub.w upper_x(a6),d2
;	subq.w #1,d2
	clr.b	-1(a1)
	clr.b	80-1(a1)
	clr.b	160-1(a1)
	clr.b	240-1(a1)
	clr.b	320-1(a1)
	clr.b	400-1(a1)
	clr.b	480-1(a1)
	clr.b	560-1(a1)
	move.l a1,-(sp)
.character_loop:
	move.l (sp),a1
	move.l a2,a3
	moveq #0,d0
	move.b (a0)+,d0
	beq.s .end_string
	add.w d0,a3
	move.w #$100,d0 
	move.w line_size(a6),d1
	bsr.s .print
	addq.l #1,(sp)
	dbf d2,.character_loop
	bra.s .end
.end_string:
	move.l (sp),a1
	move.l a2,a3
	moveq #' ',d0
	add.w d0,a3
	move.w #$100,d0 
	move.w line_size(a6),d1
	bsr.s .print
	addq.l #1,(sp)
	dbf d2,.end_string 
.end:	addq.w #4,sp
.no_title:
	movem.l (sp)+,d0-d3/a2-a3
	rts

.print:
	rept 8
	move.b (a3),(a1)
	add.w d0,a3
	add.w d1,a1
	endr
	rts

rs232_init:
	move.l	rs232_speed(a6),d0
	and.l	#$f,d0
	add	d0,d0
	lea	.datas(pc),a0
	move	0(a0,d0),d0
	move.l	rs232_parity(a6),d1
	btst	#2,d1
	beq.s	.8bits
	btst	#5,d1
	bne.s	.8bits
	or	#$8000,d0
.8bits:	move	d0,$dff000+serper
	moveq	#-1,d0
.l1:	dbf	d0,.l1
	rts

.datas:
	dc.w	185,372,745,993,1490,1789,1988,2982,5965
	dc.w	11931,17897,23863,26712,32540,32540,32540

rs_put:
	movem.l	d1-d5,-(sp)
	move.l	rs232_parity(a6),d1
	and	#$ff,d0
	moveq	#6,d2
	moveq	#0,d3
	btst	#5,d1
	move	d0,d4
	bne.s	.search_parity
	addq	#1,d2
.search_parity:
	addq	#1,d2
	btst	#2,d1
	beq.s	.no_parity
	subq	#1,d2
	move	d2,d5
.loop:	lsr.b	#1,d4
	bcc.s	.next_bit
	addq	#1,d3
.next_bit:
	dbf	d5,.loop
	addq	#1,d2
	btst	#1,d1
	beq.s	.impaire
	btst	#0,d3
	beq.s	.no_parity
	bset	d2,d0
	bra.s	.no_parity
.impaire:
	btst	#0,d3
	bne.s	.no_parity
	bset	d2,d0	;parite
.no_parity:
	addq	#1,d2
	bset	d2,d0	;stop 1
	btst	#4,d1
	beq.s	.stopped
	addq	#1,d2
	bset	d2,d0	;stop 2
.stopped:
	move	$dff000+serdatr,d2
	btst	#13,d2
	beq.s	.stopped
	move	d0,$dff000+serdat
	movem.l	(sp)+,d1-d5
	rts

rs_in:	moveq	#-1,d7
	and.b	#7,$bfd200
	or.b	#$c0,$bfd200
	and.b	#$1f,$bfd000
	and.b	#$c7,$bfd200
.la:	move	$dff000+intreqr,d0
	btst	#11,d0
	bne.s	.la1
	dbf	d7,.la
	rts
.la1:	move	#$800,intreq+$dff000
	move	serdatr+$dff000,d0
	rts

wind_screen_to_term:
	move.w	d3,-(sp)
	move.w	#11,alt_s_sub1(a6)
	move.w	#12,alt_s_sub2(a6)
	move.l	#$10001,d0
	move.l	d0,big_window_coords(a6)
	move.w	#15-(32-25+1),nb_draw_sections(a6)

	lea	w1_db(a6),a0
	moveq	#0,d3
	cmp.w	#2,$12(a0)
	bgt.s	.title1
	cmp.w	#2,$22(a0)
	bgt.s	.title1
	st	d3		;flag de alt-s sur fenetre 1
.title1:
;1
	subq.w	#1,2(a0)
;2-3-4-5
	lea	$10(a0),a1
	bsr	.recalc_two_windows
	lea	$20(a0),a1
	bsr	.recalc_two_windows
;6
	move.w	#1,$52(a0)
	move.w	#$18,$56(a0)

	tst.b	window_magnified(a6)
	beq	.end
;recalcul du buffer de alt-z
	move.w	window_selected(a6),d0
	move.w	d0,d1
	lsl.w	#4,d0
	lea	-$10(a0,d0.w),a1
	move.w	#1,2(a1)
	move.w	#$18,6(a1)
	lea	window_buffer(a6),a1
	subq.w	#1,d1
	bne.s	.not_1
	subq.w	#1,2(a1)
	bra.s	.end
.not_1:	subq.w	#1,d1
	bne.s	.not_2
	tst.b	d3
	bne.s	.alt_s_2
	move.w	#$c,2(a1)
	move.w	#7,6(a1)
	bra.s	.suite2
.alt_s_2:
	move.w	#1,2(a1)
	move.w	#$12,6(a1)
.suite2:
	tst.b	$13(a1)		;fenetre 4 existe ?
	bne.s	.end
	addq.w	#6,6(a1)
	bra.s	.end
.not_2:	subq.w	#1,d1
	bne.s	.not_3
	tst.b	d3
	bne.s	.alt_s_3
	move.w	#$c,2(a1)
	move.w	#7,6(a1)
	bra.s	.suite3
.alt_s_3:
	move.w	#1,2(a1)
	move.w	#$12,6(a1)
.suite3:
	tst.b	$14(a1)		;fenetre 5 existe ?
	bne.s	.end
	addq.w	#6,6(a1)
	bra.s	.end
.not_3:	move.w	#$13,2(a1)
	move.w	#6,6(a1)
.end:	move.w	(sp)+,d3
	rts

.recalc_two_windows:
	move.w	#$13,$22(a1)
	move.w	#6,$26(a1)
	tst.b	d3
	bne.s	.alt_s_1
	move.w	#$c,2(a1)
	move.w	#7,6(a1)
	bra.s	.split
.alt_s_1:
	move.w	#1,2(a1)
	move.w	#$12,6(a1)
.split:	tst.b	window_magnified(a6)
	beq.s	.no_zoom
	move.l	a1,d0
	sub.l	a0,d0
	lsr.w	#4,d0
	move.l	a1,-(sp)
	lea	window_buffer+$10(a6),a1
	tst.b	2(a1,d0.w)
	movem.l	(sp)+,a1
	bra.s	.split_test
.no_zoom:
	tst.b	$28(a1)
.split_test:
	bne.s	.splitted
	addq.w	#6,6(a1)
.splitted:
	rts

wind_term_to_screen:
	move.w	d3,-(sp)
	move.w	#12,alt_s_sub1(a6)
	move.w	#19,alt_s_sub2(a6)
	move.w	#15,nb_draw_sections(a6)
	move.l	#$10002,big_window_coords(a6)

	lea	w1_db(a6),a0
	moveq	#0,d3
	cmp.w	#1,$12(a0)
	bgt.s	.title1
	cmp.w	#1,$22(a0)
	bgt.s	.title1
	st	d3		;flag de alt-s sur fenetre 1
.title1:
;1
	addq.w	#1,2(a0)
;2-3-4-5
	lea	$10(a0),a1
	bsr	.recalc_two_windows
	lea	$20(a0),a1
	bsr	.recalc_two_windows
;6
	move.w	#2,$52(a0)
	move.w	#30,$56(a0)

	tst.b	window_magnified(a6)
	beq	.end
;recalcul du buffer de alt-z
	move.w	window_selected(a6),d0
	move.w	d0,d1
	lsl.w	#4,d0
	lea	-$10(a0,d0.w),a1
	move.w	#2,2(a1)
	move.w	#30,6(a1)
	lea	window_buffer(a6),a1
	subq.w	#1,d1
	bne.s	.not_1
	addq.w	#1,2(a1)
	bra.s	.end
.not_1:	subq.w	#1,d1
	bne.s	.not_2
	tst.b	d3
	bne.s	.alt_s_2
	move.w	#$e,2(a1)
	move.w	#8,6(a1)
	bra.s	.suite2
.alt_s_2:
	move.w	#2,2(a1)
	move.w	#20,6(a1)
.suite2:
	tst.b	$13(a1)		;fenetre 4 existe ?
	bne.s	.end
	add.w	#10,6(a1)
	bra.s	.end
.not_2:	subq.w	#1,d1
	bne.s	.not_3
	tst.b	d3
	bne.s	.alt_s_3
	move.w	#$e,2(a1)
	move.w	#8,6(a1)
	bra.s	.suite3
.alt_s_3:
	move.w	#2,2(a1)
	move.w	#20,6(a1)
.suite3:
	tst.b	$14(a1)		;fenetre 5 existe ?
	bne.s	.end
	add.w	#10,6(a1)
	bra.s	.end
.not_3:	move.w	#32-9,2(a1)
	move.w	#9,6(a1)
.end:	move.w	(sp)+,d3
	rts

.recalc_two_windows:
	move.w	#32-9,$22(a1)
	move.w	#9,$26(a1)
	tst.b	d3
	bne.s	.alt_s_1
	move.w	#$e,2(a1)
	move.w	#8,6(a1)
	bra.s	.split
.alt_s_1:
	move.w	#2,2(a1)
	move.w	#20,6(a1)
.split:
	tst.b	window_magnified(a6)
	beq.s	.no_zoom
	move.l	a1,d0
	sub.l	a0,d0
	lsr.w	#4,d0
	move.l	a1,-(sp)
	lea	window_buffer+$10(a6),a1
	tst.b	2(a1,d0.w)
	movem.l	(sp)+,a1
	bra.s	.split_test
.no_zoom:
	tst.b	$28(a1)
.split_test:
	bne.s	.splitted
	add.w	#10,6(a1)
.splitted:
	rts

;--INPUT--
;a0=@message
system_print:
	movem.l	d0-d2/a0-a6,-(sp)
	move.l	a0,a3
	move.l	4.w,a5	;ExecBase pas encore mis
	move.l	a5,a6
	moveq	#0,d1
	move.l	#200,d0
	jsr	AllocMem(a6)
	tst.l	d0
	beq.s	.end
	move.l	d0,a2
	lea	dos_name,a1
	moveq	#0,d0
	jsr	OldOpenLib(a6)
	tst.l	d0
	beq.s	.end
	move.l	d0,a6
	jsr	Output(a6)
	move.l	d0,d2
	beq.s	.closedos
	move.l	a3,a0
	move.l	a2,a1
	jsr strcpy
	move.l	a2,a0
	moveq	#0,d0
	jsr	strlen
	move.b	#10,0(a2,d0.w)
	addq.l	#1,d0
	move.l	d2,d1
	move.l	a2,d2
	move.l	d0,d3
	jsr	Write(a6)
.closedos:
	move.l	a6,a1
	move.l	a5,a6
	jsr	CloseLib(a6)
	move.l	a2,a1
	move.l	#200,d0
	jsr	FreeMem(a6)
.end:	movem.l	(sp)+,d0-d2/a0-a6
system_getkey:
	rts

;liberer ecran & bss
amiga_fast_desinit:
	move.l	initial_physbase(a6),d0
	beq.s	.suite
	move.l	d0,a0
	move.l	#AMIGA_NB_LINES*LINE_SIZE,d0
	jsr	free_memory
.suite:	move.l	#end_of_offset_base,d0
	move.l	a6,a0
	jmp	free_memory

;	#[ Task Stuff
;  #[ Test_Task:
test_task:
	tst.b	idle_flag(a6)
	bne.s	.ok
	tst.b	trace_task_flag(a6)
	beq.s	.ok
	tst.l	p1_current_task(a6)
	bne.s	.ok
	move.l	a2,-(sp)
	lea	no_task_error_text,a2
	jsr	print_error
	move.l	(sp)+,a2
	moveq	#-1,d0
	rts
.ok:	moveq	#0,d0
	rts
;  #] Test_Task:
	
;  #[ Stop Task:
; est appele en IPL7 par breakpt/p1p0
; a6 est OK
; passe la tache actuelle (p1) en waiting
; passe la main a Adebug (p0)
stop_task:
	movem.l	d0/d1/a0/a3,-(sp)
	move.l	ExecBase(a6),a3
	move.l	ThisTask(a3),a0
	cmp.l	inputdev_task(a6),a0
	seq	no_inputdev_flag(a6)
	tst.b	trace_task_flag(a6)
	beq.s	.no_cmp
	cmp.l	Adebug_task(a6),a0
	beq	.end ;internal error
.no_cmp:	cmp.b	#2,tc_State(a0)
	beq.s	.not_idle
	st	idle_flag(a6)
	move.w	internal_sr(a6),old_internal_sr(a6)
	or.w	#$700,internal_sr(a6)
	st	force_ipl_flag(a6)
	bra.s	.end
.not_idle:
	sf	idle_flag(a6)
	tst.b	trace_task_flag(a6)
	bne.s	.go
	tst.b	multitask_access_flag(a6)
	beq.s	.end
;erreur en multitasking: on force task trace pour poursuivre
	st	trace_task_flag(a6)
	bsr	save_adbg_multi_context
; on switche si (trace_task) ou (multitasking) et (!idle)
.go:	move.l	a0,p1_current_task(a6)
	cmp.l	p1_task(a6),a0
	beq.s	.current_task
	tst.b	p1_start_flag(a6)
	bne.s	.current_task
;la tache interrompue n'est pas p1 -> on interrompt p1
;	move.w	internal_sr(a6),old_internal_sr(a6)
;	or.w	#$700,internal_sr(a6)
;	st	force_ipl_flag(a6)
;stoppe la tache chargee s'il y en a une et si (!multitask)
	tst.b	multitask_access_flag(a6)
	bne.s	.current_task
	bsr	stop_loaded_task
	move.l	p1_current_task(a6),a0
.current_task:
	move.l	tc_SigWait(a0),p1_current_task_sigwait(a6)
	move.b	tc_State(a0),p1_current_task_state(a6)

;endort ThisTask
	clr.l	tc_SigWait(a0)
	bsr	put_task_to_sleep
.wake_up_adebug:
	move.l	Adebug_task(a6),a0
	move.l	a0,ThisTask(a3)
;	move.l	tc_SigWait(a0),adebug_sigwait(a6)
	move.b	#2,tc_State(a0)		;waiting ->running
	bsr	remove_from_tasklist
.end:	movem.l	(sp)+,d0/d1/a0/a3
	rts
;  #] Stop Task:

;  #[ Reactive Task:
; est appele en IPL7
; passe la main a la tache p1
; passe Adebug en waiting de l'event 0 ou de l'ancien event en multitasking
reactive_task:
	tst.b	term_task_flag(a6)
	bne	term_task
	tst.b	multitask_access_flag(a6)
	bne.s	.ok2
	tst.b	trace_task_flag(a6)
	beq.s	.out
.ok2:	tst.b	idle_flag(a6)
	beq.s	.ok1
.out:	; si (idle) ou (!trace_task et !multi) alors pas de switch
	rts
.ok1:	move.l	a3,-(sp)
	move.l	ExecBase(a6),a3
; (re)endort Adebug
	move.l	Adebug_task(a6),a0
	moveq	#0,d0
	tst.b	multitask_access_flag(a6)
	beq.s	.sigwait_ok
	move.l	adebug_sigwait(a6),d0 ;pour continuer a attendre le UserPort
	bsr	restore_adbg_multi_context
;	bra.s	.sigwait_suite
.sigwait_ok:
	move.l	d0,tc_SigWait(a0)
;.sigwait_suite:
	bsr	put_task_to_sleep
; reveille p1
	move.l	p1_current_task(a6),a0
	cmp.l	p1_task(a6),a0
	beq.s	.same_tasks
	tst.b	multitask_access_flag(a6)
	bne.s	.same_tasks
;reactive tache chargee si presente et si (!multitask)
	bsr	reactive_loaded_task
	move.l	p1_current_task(a6),a0
.same_tasks:
	move.l	a0,ThisTask(a3)
	move.l	p1_current_task_sigwait(a6),tc_SigWait(a0)
	move.b	p1_current_task_state(a6),tc_State(a0)
; enlever des taches waiting
	bsr	remove_from_tasklist
.end:	clr.l	p1_current_task(a6)
	move.l	(sp)+,a3
	rts
;  #] Reactive Task:

;  #[ Miscellaneous Task Functions
stop_loaded_task:
	movem.l	a0/a2,-(sp)
	move.l	p1_task(a6),d0
	beq.s	.end
	move.l	d0,a0
	move.l	a0,a2
	move.l	tc_SigWait(a0),p1_task_sigwait(a6)
	move.b	tc_State(a0),d0
	move.b	d0,p1_task_state(a6)
	subq.b	#3,d0
	bne.s	.waiting
	bsr.s	remove_from_tasklist	;enlever des taches Ready
	move.l	a2,a0
	bsr.s	put_task_to_sleep
.waiting:	move.b	#4,tc_State(a2)
	clr.l	tc_SigWait(a2)
.end:	movem.l	(sp)+,a0/a2
	rts

put_task_to_sleep:
;-- INPUT --
;a0=@struct task
;a3=Execbase
;-- garbage a0,a1,d0,d1
	move.b	#4,tc_State(a0) ;Waiting
	move.l	a0,d0
	lea	TaskWait+4(a3),a1
	move.l	4(a1),a0 ;lh_tailPred
	move.l	d0,(a0)
	move.l	a0,d1
	move.l	d0,a0
	move.l	d0,4(a1)
	move.l	a1,(a0)+ ;ln_Succ
	move.l	d1,(a0)
	rts

remove_from_tasklist:
;-- INPUT --
;a0=@struct task
;-- garbage a0,a1
	movem.l	(a0),a0/a1 ;ln_Succ,ln_Pred
	tst.l	(a1)
	bne.s	.not0
	move.l	a1,-4(a1)
	lea	-4(a1),a0
	move.l	a0,4(a1)
	rts
.not0:	move.l	a0,(a1)
	move.l	a1,4(a0)
	rts

reactive_loaded_task:
;-- INPUT --
;a3=Execbase
;-- garbage a0,a1,d0,d1
	move.l	p1_task(a6),d0
	beq.s	.end
	move.l	d0,a0
	move.l	p1_task_sigwait(a6),tc_SigWait(a0)
	move.b	p1_task_state(a6),d0
	move.b	d0,tc_State(a0)
	subq.b	#3,d0
	bne.s	.end
;p1 etait ready
	move.l	a0,-(sp)
	bsr.s	remove_from_tasklist
	move.l	(sp)+,a1
	bra.s	enqueue_task
.end:	rts

enqueue_task:
;-- INPUT --
;a1=@struct task
;a3=Execbase
;-- garbage a0,a1,d0,d1
	lea	TaskReady(a3),a0
	move.b	ln_pri(a1),d1
	move.l	(a0),d0
.l1:	movea.l	d0,a0
	move.l	(a0),d0
	beq.s	.found
	cmp.b	ln_pri(a0),d1
	ble.s	.l1
.found:	move.l	4(a0),d0
	move.l	a1,4(a0)
	move.l	a0,(a1)
	move.l	d0,4(a1)
	movea.l	d0,a0
	move.l	a1,(a0)
	rts

term_task:
	move.l	a3,-(sp)
	move.l	ExecBase(a6),a3
	tst.b	trace_task_flag(a6)
	beq	.quit_idle
;p1_task: waiting->ready
	move.l	p1_task(a6),a0
	move.b	#-1,tc_IDNestCnt(a0)
	bsr	remove_from_tasklist
	move.l	p1_task(a6),a1
	move.b	#3,tc_State(a1)
	clr.l	tc_SigWait(a1)
	bsr.s	enqueue_task
	move.l	p1_task(a6),a0
	move.l	tc_SPReg(a0),a0
	move.l	#recup_process,(a0)
	tst.b	idle_flag(a6)
	bne.s	.end
; (re)endort Adebug
	move.l	Adebug_task(a6),a0
	moveq	#0,d0
	tst.b	multitask_access_flag(a6)
	beq.s	.sigwait_ok
	move.l	adebug_sigwait(a6),d0 ;pour continuer a attendre le UserPort
.sigwait_ok:
	move.l	d0,tc_SigWait(a0)
	bsr	put_task_to_sleep
; reveille p1
	move.l	p1_current_task(a6),a0
	move.l	a0,ThisTask(a3)
	move.l	p1_current_task_sigwait(a6),tc_SigWait(a0)
	move.b	p1_current_task_state(a6),tc_State(a0)	;running
; enlever des taches waiting
	bsr	remove_from_tasklist
.end:	clr.l	p1_current_task(a6)
	move.l	(sp)+,a3
	sf	term_task_flag(a6)
	rts
;trace task no, mais idle
;adebug est waiting ou ready
.quit_idle:
	move.l	Adebug_task(a6),a0
	move.b	#-1,tc_IDNestCnt(a0)
	cmp.b	#3,tc_State(a0)
	beq.s	.recup
;adebug est waiting
	bsr	remove_from_tasklist
	move.l	Adebug_task(a6),a1
	move.b	#3,tc_State(a1)
	clr.l	tc_SigWait(a1)
	bsr	enqueue_task
	move.l	Adebug_task(a6),a0
.recup:	move.l	tc_SPReg(a0),a0
	move.l	#recup_process,(a0)
	bra.s	.end	;quitte

;ne rien garbager
save_adbg_multi_context:
	movem.l	d0/a0-a1,-(sp)
	move.l	Adebug_task(a6),a0
	move.l	tc_SPReg(a0),a0
	lea	adbg_multi_context_buf(a6),a1
	move.l	a0,(a1)+
	moveq	#(15*2+2+1)-1,d0 ;D0-A6 +PC +SR
.l1:	move.w	(a0)+,(a1)+
	dbf	d0,.l1
	movem.l	(sp)+,d0/a0-a1
	rts

;ne rien garbager
restore_adbg_multi_context:
	movem.l	d0/a0-a1,-(sp)
	move.l	Adebug_task(a6),a0
	lea	adbg_multi_context_buf(a6),a1
	move.l	(a1)+,d0
	move.l	d0,tc_SPReg(a0)
	move.l	d0,a0
	moveq	#(15*2+2+1)-1,d0	;D0-A6 +PC +SR
.l1:	move.w	(a1)+,(a0)+
	dbf	d0,.l1
	movem.l	(sp)+,d0/a0-a1
	rts
;  #] Miscellaneous Task Functions

;  #[ Show_tasks: [Ctl_Alt_T]
show_tasks:
	movem.l	d2-d7/a2-a5,-(sp)
	move.l	#task_title_text,big_title_addr(a6)
	lea	line_buffer(a6),a3
	jsr	open_big_window
	move.l	big_window_coords(a6),x_pos(a6)
	lea	present_task_text,a0
	move.l	a3,a1
	jsr	strcpy
	bsr	print_instruction
	addq.w	#1,y_pos(a6)
	move.w	#$4000,$dff09a	; no ints
	move.b	acia_ikbd(a6),-(sp)
	st	acia_ikbd(a6)
	move.l	ExecBase(a6),a4
	lea	TaskReady(a4),a5
	lea	taskready_text,a4
	bsr.s	.task_list
	bne.s	.bye
	move.l	ExecBase(a6),a4
	lea	TaskWait(a4),a5
	lea	taskwait_text,a4
	bsr.s	.task_list
.bye:	move.w	internal_intena(a6),d0
	bset	#15,d0
	move.w	d0,$dff09a
	not.w	d0
	move.w	d0,$dff09a
	move.b	(sp)+,acia_ikbd(a6)
;effacement reste de la fenetre
	clr.b	(a3)
	move.w	y_pos(a6),d2
	cmp.w	column_len(a6),d2
	bge.s	.getch
.fill:	bsr	print_instruction
	addq.w	#1,d2
	move.w	d2,y_pos(a6)
	cmp.w	column_len(a6),d2
	blt.s	.fill
.getch:	tst.b	d3
	bne.s	.end3
.getchar:
	bsr	get_char
	cmp.b	#$1b,d0
	bne.s	.getchar
.end3:	jsr	close_big_window
	movem.l	(sp)+,d2-d7/a2-a5
	rts

;INPUT -- a3=@line_buffer
;OUTPUT -- d3=sortie par [Esc]
.task_list:
	move.l	(a5),a5
	tst.l	(a5)
	beq	.end
	move.l	a4,a0
	sf	d7
	cmp.l	Adebug_task(a6),a5
	beq.s	.task_list
	lea	normal_task_entry_format,a2
	cmp.l	p1_current_task(a6),a5
	beq.s	.stopped
	cmp.l	p1_task(a6),a5
	bne.s	.not_stopped
.stopped:
	lea	taskstopped_text,a0
	bra.s	.suite
.not_stopped:
	cmp.b	#4,tc_State(a5)
	bne.s	.suite
	st	d7
	lea	waiting_task_entry_format,a2
	move.l	tc_SigWait(a5),-(sp)
.suite:
	move.l	a0,-(sp)		;state
	move.b	ln_pri(a5),d0
	ext.w	d0
	move.w	d0,-(sp)		;pri
	move.l	a5,-(sp)		;@ struct task
	move.l	ln_name(a5),-(sp)	;name
	move.l	a2,-(sp)
	move.l	a3,a0
	jsr	sprintf
	lea	18(sp),sp
	tst.b	d7
	beq.s	.not_waiting
	addq.w	#4,sp
.not_waiting:
	move.l	a3,a2
	bsr	print_instruction
	addq.w	#1,y_pos(a6)
	move.w	y_pos(a6),d0
	cmp.w	column_len(a6),d0
	blt	.task_list
	bsr	get_char
	cmp.b	#$1b,d0
	seq	d3
	beq.s	.end2
	move.l	big_window_coords(a6),d0
	addq.w	#1,d0	;1ere ligne
	move.l	d0,x_pos(a6)
	bra	.task_list
.end:	sf	d3
.end2:	tst.b	d3	;si sortie par [Esc]
	rts
;  #] Show_tasks: (Ctl-Alt-T)
;  #[ Task structs switchings
save_task_struct:
;INPUT
;a0=@struct task (d'adebug en l'occurence)
	move.l	ln_name(a0),initial_task_name(a6) ; pour tcsh surtout
	move.l	tc_TrapCode(a0),initial_trapcode(a6)
	move.l	pr_CLI(a0),d0
	move.l	d0,initial_pr_CLI(a6)
	add.l	d0,d0
	add.l	d0,d0
	move.l	d0,a1
	move.l	cli_Module(a1),initial_cli_Module(a6)
	move.l	cli_CommandName(a1),initial_cli_CommandName(a6)
	move.l	pr_COS(a0),initial_pr_COS(a6)
	move.l	pr_CIS(a0),initial_pr_CIS(a6)
	move.l	pr_ReturnAddr(a0),initial_pr_ReturnAddr(a6)
	move.l	pr_WindowPtr(a0),initial_pr_WindowPtr(a6)
	rts

reput_task_struct:
;INPUT
;a0=@struct task (d'adebug en l'occurence)
	move.l	initial_task_name(a6),ln_name(a0)	;pour tcsh
	move.l	initial_trapcode(a6),tc_TrapCode(a0)
	move.l	initial_pr_CLI(a6),d0
	move.l	d0,pr_CLI(a0)
	add.l	d0,d0
	add.l	d0,d0
	move.l	d0,a1
	move.l	initial_cli_Module(a6),cli_Module(a1)
	move.l	initial_cli_CommandName(a6),cli_CommandName(a1) ;pour tcsh
;	on vide ca car ca kill le shell pere sous Kick2
;	move.l	initial_pr_COS(a6),pr_COS(a0)
;	move.l	initial_pr_CIS(a6),d0
;	move.l	d0,pr_CIS(a0)
;	add.l	d0,d0
;	add.l	d0,d0
;	move.l	d0,a1
;	move.l	fh_Pos(a1),fh_End(a1)
	move.l	initial_pr_ReturnAddr(a6),pr_ReturnAddr(a0)
	move.l	initial_pr_WindowPtr(a6),pr_WindowPtr(a0)
	rts
;  #] Task structs switchings
;	#] Task Stuff

;  #[ _load_prg_vars:(ctrl_alt_v)
_load_prg_vars:
	movem.l	d2-d7/a2-a5,-(sp)
	move.l	var_tree_nb(a6),-(sp)
	move.l	var_tree_addr(a6),-(sp)
	move.l	p1_current_task(a6),d0
	beq	.end
	move.l	d0,a0
	cmp.l	p1_task(a6),a0
	beq	.end
	cmp.b	#13,ln_type(a0)
	bne	.proc_err
	move.l	pr_CLI(a0),d2
	add.l	d2,d2
	add.l	d2,d2		;d2=pr_CLI
	bne.s	.fromcli
	move.l	pr_SegList(a0),d0
	beq	.cli_err
	add.l	d0,d0
	add.l	d0,d0
	move.l	d0,a1
	lea	12(a1),a3
	tst.l	(a3)
	bne.s	.from_wb
	bra	.cli_err
.fromcli:	move.l	d2,a1
	lea	cli_Module(a1),a3
.seg_found:
	move.l	d2,a0
	move.l	cli_CommandName(a0),d0
	beq	.noname_err
	add.l	d0,d0
	add.l	d0,d0
	move.l	d0,a0
	move.b	(a0)+,d0		;chaine format BCPL
	beq	.noname_err
	ext.w	d0
	bra.s	.findfile
.from_wb:	lea	lpv_fromwb_text,a2
	jsr	print_press_key
	suba.l	a0,a0
.getname:	st	no_eval_flag(a6)
	lea	ask_lpv_filename_text,a2
	jsr	get_expression
	bmi	.end
	jsr	strlen
.findfile:lea	higher_level_buffer(a6),a5 ;nom courant
	move.l	a5,a1
	subq.w	#1,d0
.cp:	move.b	(a0)+,(a1)+
	dbf	d0,.cp
	clr.b	(a1)
	move.l	a5,a0
	lea	my_dta+DTA_NAME(a6),a1
	jsr	strcpy
	moveq	#1,d0	;pas cd sur le repertoire
	bsr	find_file
	bpl.s	.file_found
	lea	lpv_fnf_error_text,a2
	jsr	print_press_key
	move.l	a5,a0
	bra	.getname
.file_found:
	move.l	a5,a0
	bsr	open_file
	bmi	.open_err
	move.l	d0,d5
	clr.l	other_exec_sym_nb(a6)
	move.l	a5,-(sp)
	pea	lpv_searching_text
	lea	line_buffer(a6),a0
	move.l	a0,a2
	jsr	sprintf
	addq.w	#8,sp
	jsr	print_result
	lea	long_buffer(a6),a5
	bsr	.readlmtoa5
	bne	.exec_err
	cmp.w	#$3f3,2(a5)
	bne	.exec_err
	bsr	.readlmtoa5
	bne	.exec_err
	move.l	(a5),d7
	beq.s	.nohname
	; skippe le nom du hunk
	subq.w	#1,d7
.l1:	bsr	.readlmtoa5
	bne	.exec_err
	dbf	d7,.l1

.nohname:	bsr	.readlmtoa5 ; lire nb de hunks
	bne	.exec_err
	move.l	(a5),d7
	bsr	.readlmtoa5 	;on charge sec pour le moment
	bsr	.readlmtoa5 	;voir pour overlays
	bne	.exec_err

	move.w	d7,other_nb_segs(a6)
	add.l	d7,d7
	add.l	d7,d7
	move.l	d7,d0
	move.l	d5,d1
	bsr	seek_file
	moveq	#0,d6	;hunk courant
; ----- TRAITEMENT HUNKS -----
.nxhunk:	bsr	.readlmtoa5
	bne	.test_matching
	move.w	2(a5),d0 ; type du hunk
	cmp.w	#$3e7,d0
	blt	.unknown_hunk_error
	cmp.w	#$3f6,d0
	bgt	.unknown_hunk_error
	cmp.w	#$3f0,d0
	bne.s	.not_symbol
	bsr	.get_symbols
	bra.s	.nxhunk
.not_symbol:
	cmp.w	#$3e9,d0
	beq.s	.hunk_found
	cmp.w	#$3ea,d0
	beq.s	.hunk_found
	cmp.w	#$3eb,d0
	beq.s	.hunk_bss
	cmp.w	#$3ec,d0
	beq.s	.hunk_reloc
	cmp.w	#$3f2,d0
	beq.s	.nxhunk
.skip_hunk:
	bsr	.readlmtoa5
	move.l	(a5),d0
	add.l	d0,d0
	add.l	d0,d0
	move.l	d5,d1
	bsr	seek_file
	bra.s	.nxhunk

.hunk_found:
	move.l	a3,d0
	beq	.match_err	;1 hunk de trop
	move.l	(a3),a3
	add.l	a3,a3
	add.l	a3,a3
	addq.w	#1,d6
	bra.s	.skip_hunk

.hunk_reloc:
	bsr	.readlmtoa5 	;lire nbre d'offsets
	bne	.exec_err
	move.l	(a5),d0
	beq.s	.nxhunk		;c'est fini
	move.l	d5,d1
	addq.l	#1,d0
	add.l	d0,d0
	add.l	d0,d0
	bsr	seek_file		;voir traitement d'erreur
	bra.s	.hunk_reloc

.hunk_bss:	;pareil que hunk_found sauf qu'on skippe pas
	move.l	a3,d0
	beq	.match_err	;1 hunk de trop
	move.l	(a3),a3
	add.l	a3,a3
	add.l	a3,a3
	addq.w	#1,d6
	bsr	.readlmtoa5	;skippe la taille de la bss
	bra	.nxhunk

;fin de chargement on compare les hunks aux sections
.test_matching:
	cmp.w	other_nb_segs(a6),d6
	beq	.good_load
	bra	.match_err

; ----- SYMBOLES -----
.get_symbols: ; dans a3 adresse APTR du segment
	addq.l	#4,a3
	movem.l	d6/d7,-(sp)
	move.l	#$ffffff,d6
	moveq	#0,d4
	bsr.s	.next_block
	tst.l	d7
	beq.s	.fin_symboles	; on n'a rien lu (rare!)
.next_symbol:
	move.l	(a4)+,d3 	; taille nom en longs mots
	beq.s	.fin_symboles1
	and.l	d6,d3
	lsl.l	#2,d3

	move.l	d7,d4
	sub.l	d3,d7
	subq.l	#8,d7
	seq	d2		; = 0 , a retenir
	bpl.s	.continue	; > 0
.need_new:
	bsr.s	.next_block
	bra.s	.next_symbol
.continue:
	move.l	0(a4,d3.l),d4	; offset
	lea	0(a3,d4.l),a1	; + base = adresse
	clr.b	0(a4,d3.l) 	; ascii du symbole en (a4)
	move.w	#'la',d0
	move.l	a4,a0
	addq.l	#1,other_exec_sym_nb(a6)
	jsr	put_in_table
	bmi.s	.hunk_symbol_err
	lea	4(a4,d3.l),a4
	tst.b	d2
	beq.s	.next_symbol
	moveq	#0,d4
	bra.s	.need_new

.next_block:
; d4 = taille deja en memoire
; si d4 <> 0, a4 = @ donnees
	lea	ro_usp-4096(a6),a0
	move.l	a0,a1
	move.l	d4,d0
	beq.s	.read
	lsr.w	#2,d0
	subq.l	#4,a4	; recupere aussi longueur symbole
	subq.w	#1,d0
.copy:	move.l	(a4)+,(a0)+
	dbf	d0,.copy
.read:	move.l	d5,d1
	move.l	#TAILLE_LOAD_BUF,d0
	sub.l	d4,d0
	move.l	a1,a4
	bsr	read_file
	move.l	d0,d7
	add.l	d4,d7
	rts
.hunk_symbol_err:
	bsr.s	.go_seek
	movem.l	(sp)+,d6/d7
	subq.l	#4,a3
	moveq	#-1,d0
	rts
.fin_symboles1:
	subq.l	#4,d7
.fin_symboles:
	bsr.s	.go_seek
	movem.l	(sp)+,d6/d7
	subq.l	#4,a3
	moveq	#0,d0
	rts
.go_seek:	move.l	d7,d0 ; offset
	beq.s	.fin_seek
	neg.l	d0
	move.l	d5,d1
	bra	seek_file
.fin_seek:
	rts

; -------------------------
.readlmtoa5:
	move.l	d5,d1
	move.l	a5,a0
	moveq	#4,d0
	bsr	read_file
	subq.l	#4,d0
	rts

; ----- ERREURS & FIN -----
.cli_err:	lea	cli_damaged_error_text,a2
	bra.s	.erprint
.proc_err:lea	notprocess_error_text,a2
	bra.s	.erprint
.match_err:
	lea	matching_error_text,a2
	bra.s	.erprint_close
.unknown_hunk_error:
	lea	unknown_hunk_error_text,a2
	bra.s	.erprint_close
.open_err:lea	lpv_fnf_error_text,a2
	bra.s	.erprint
.exec_err:lea	executable_error_text,a2
	bra.s	.erprint_close
.noname_err:
	lea	lpv_noname_error_text,a2
	bra.s	.erprint

.erprint_close:
	move.l	d5,d0
	jsr	close_file
.erprint:	jsr	print_press_key
	clr.w	x_pos(a6)
	jsr	clr_c_line
	move.l	(sp),var_tree_addr(a6)	;annuler
	move.l	4(sp),var_tree_nb(a6)	;chargement des vars
	moveq	#-1,d0
	bra.s	.end
.good_load:
	move.l	d5,d0
	jsr	close_file
	jsr	create_var_tree
	jsr	redraw_all_windows
	pea	my_dta+DTA_NAME(a6)
	move.l	other_exec_sym_nb(a6),-(sp)
	pea	prg_vars_loaded_text
	lea	higher_level_buffer(a6),a2
	move.l	a2,a0
	jsr	sprintf
	lea	12(sp),sp
	jsr	print_result
	moveq	#0,d0
.end:	addq.l	#8,sp
	movem.l	(sp)+,d2-d7/a2-a5
	rts
;  #] _load_prg_vars:(ctrl_alt_v)

update_for_prefs:
	move.l	#$fff,d0
	and.l	d0,color0_value(a6)
	and.l	d0,color1_value(a6)
.screen:	moveq	#0,d0
	move.w	color0_value+2(a6),d1
	bsr.s	SetColor
	moveq	#1,d0
	move.w	color1_value+2(a6),d1
	bsr.s	SetColor
.l1:	tst.l	p1_basepage_addr(a6)
	bne.s	.nochg
	move.b	trace_task_pref_flag(a6),trace_task_flag(a6)
.nochg:	rts

;In: d0=color#, d1=RGB
SetColor:	tst.b	CopListFlg(a6)
	bne.s	.copper
	movem.l	d2-d4,-(sp)
	move.l	IntuiScr(a6),a0
	lea	sc_ViewPort(a0),a0
	moveq	#$f,d4
	move.w	d1,d3
	and.w	d4,d3
	move.w	d1,d2
	lsr.w	#4,d2
	move.w	d2,d1
	and.w	d4,d2
	lsr.w	#4,d1
	and.w	d4,d1
	CALLGFX	SetRGB4
	movem.l	(sp)+,d2-d4
	bra.s	.end
.copper:	move.l	internal_copperlist(a6),a0
	lsl.w	#2,d0	;d0=0 ou 1 (2 planes)
	move.w	d0,46(a0,d0.w)
.end:	rts

;  #[ My commands
	IFNE	daniel_version
change_vbl_stop_flag:
	lea	vbl_stop_off_text,a2
	not.b	vbl_stop_flag(a6)
	beq.s	.print
	lea	vbl_stop_on_text,a2
.print:	jmp	print_result

force_redraw_relock:
	jmp	redraw_relock_all

change_trace_task_flag:
	lea	ttf_off_text,a2
	not.b	trace_task_pref_flag(a6)
	move.b	trace_task_pref_flag(a6),trace_task_flag(a6)
	beq.s	.print
	lea	ttf_on_text,a2
.print:	jmp	print_result
	
amiga_internal_infos:
	movem.l	d2-d7/a2-a5,-(sp)
	move.l	#internal_infos_title_text,big_title_addr(a6)
	lea	line_buffer(a6),a3
	jsr	open_big_window
	move.l	big_window_coords(a6),x_pos(a6)
;bss
	move.l	a6,d0
	move.l	d0,d1
	add.l	#end_of_offset_base,d1
	move.l	d1,-(sp)
	move.l	d0,-(sp)
	pea	.bss_text(pc)
	move.l	a3,a0
	jsr	sprintf
	lea	12(sp),sp
	bsr	print_instruction
	addq.w	#1,y_pos(a6)
;user stack
	move.l	a3,a0
	move.l	a7,-(sp)
	move.l	top_stack_addr(a6),-(sp)
	move.l	reserved_stack_addr(a6),-(sp)
	pea	.user_stack_text(pc)
	jsr	sprintf
	lea	16(sp),sp
	bsr	print_instruction
	addq.w	#1,y_pos(a6)
;super stack
	move.l	internal_am_ssp(a6),-(sp)
	lea	amiga_sup_stack(a6),a0
	lea	am_stack_len(a0),a1
	move.l	a1,-(sp)
	move.l	a0,-(sp)
	pea	.super_stack_text(pc)
	move.l	a3,a0
	jsr	sprintf
	lea	16(sp),sp
	bsr	print_instruction
	addq.w	#1,y_pos(a6)

	lea	internal_values_table,a4
.next_value:
	move.l	(a4)+,d0
	beq.s	.end_values
	move.l	a3,a1
	move.l	d0,a0
	jsr	strcpy
	move.l	a3,a0
	jsr	strlen
	lea	0(a0,d0.w),a5
	move.l	(a4)+,a0
	add.l	a6,a0
	bsr	.add_address
	move.l	(a0),-(sp)
	pea	internal_values_format
	lea	lower_level_buffer(a6),a0
	jsr	sprintf
	addq.w	#8,sp
	lea	lower_level_buffer(a6),a0
	move.l	a5,a1
	jsr	strcpy
	bsr	print_instruction
	addq.w	#1,y_pos(a6)
	bra.s	.next_value
.end_values:
	lea	internal_flags_table,a4
	addq.w	#1,y_pos(a6)
.next_flag:
	move.l	(a4)+,d0
	beq.s	.end_flags
	move.l	a3,a1
	move.l	d0,a0
	jsr	strcpy
	move.l	a3,a0
	jsr	strlen
	lea	0(a0,d0.w),a5
	move.l	(a4)+,a0
	lea	lower_level_buffer(a6),a1
	add.l	a6,a0
	bsr	.add_address
	move.b	#' ',(a5)+
	move.b	#':',(a5)+
	move.b	#' ',(a5)+
	clr.b	(a5)
	tst.b	(a0)
	beq.s	.no
	move.l	#'Yes'<<8,(a1)
	bra.s	.after_test
.no:	move.l	#'No'<<16,(a1)
.after_test:
	move.l	a1,a0
	move.l	a5,a1
	jsr	strcpy
	bsr	print_instruction
	addq.w	#1,y_pos(a6)
	bra.s	.next_flag
.end_flags:
	lea	internal_bytes_table,a4
	addq.w	#1,y_pos(a6)
.next_byte:
	move.l	(a4)+,d0
	beq.s	.end_bytes
	move.l	a3,a1
	move.l	d0,a0
	jsr	strcpy
	move.l	a3,a0
	jsr	strlen
	lea	0(a0,d0.w),a5
	move.l	(a4)+,a0
	add.l	a6,a0
	bsr	.add_address
	moveq	#0,d0
	move.b	(a0),d0
	move.l	d0,-(sp)
	pea	internal_values_format
	lea	lower_level_buffer(a6),a0
	jsr	sprintf
	addq.w	#8,sp
	lea	lower_level_buffer(a6),a0
	move.l	a5,a1
	jsr	strcpy
	bsr	print_instruction
	addq.w	#1,y_pos(a6)
	bra.s	.next_byte
.end_bytes:
	bsr	get_char
	jsr	close_big_window
	movem.l	(sp)+,d2-d7/a2-a5
	rts
.add_address:
	move.l	a0,-(sp)
	move.l	a5,a0
	pea	.long_format
	jsr	sprintf
	addq.w	#4,sp
	move.l	a3,a0
	jsr	strlen
	lea	0(a3,d0.w),a5
	move.l	(sp)+,a0
	rts
.long_format: dc.b  "($%=lx)",0
.user_stack_text:	dc.b	"User  Stack: %=lx - %lx (%lx)",0
.super_stack_text:	dc.b	"Super Stack: %=lx - %lx (%lx)",0
.bss_text:		dc.b	"BSS: %=lx - %lx",0
	even
	ENDC	;de daniel_version
;  #] My commands

do_amiga_pterm1:
	tst.b	idle_flag(a6)
	bne.s	.not_same_tasks
	tst.b	trace_task_flag(a6)
	beq.s	.no_task
	move.l	p1_current_task(a6),d0
	cmp.l	p1_task(a6),d0
	beq.s	.no_task
.not_same_tasks:
	st	term_task_flag(a6)
	bra.s	.run
.no_task:	lea	pterm1(pc),a0
	move.l	a0,pc_buf(a6)
	move.l	p1_initial_usp(a6),a0
	move.l	a0,a7_buf(a6)
	move.l	external_return_addr(a6),(a0)
	move.w	initial_sr(a6),sr_buf(a6)
.run:	st	run_flag(a6)
	jmp	p0p1

;Emulation bus error
amig_test_if_readable:
	movem.l	d0-d1/d6-d7/a0-a2/a4,-(sp)
	bsr	save_for_readable
	move.l	a1,d7
	IFNE	_68030
	tst.b	chip_type(a6)
	bne.s	.no_and
	ENDC
	and.l	#$ffffff,d7
.no_and:	move.l	d7,a0
	moveq	#4,d6
;	bra.s	do_the_test

do_the_test:
	move.l	a0,d7
	add.l	d6,d7
	IFNE	_68030
	tst.b	chip_type(a6)
	bne.s	._30
	ENDC
	and.l	#$ffffff,d7
._30:	move.l	d7,a1
	cmp.l	a0,a1
;chevauchement en 0 ?
	IFEQ	_68030
	bcs.s	end_if_test
	ELSEIF
	bcc.s	.positif
	tst.b	chip_type(a6)
	beq.s	end_if_test	;ROM en xxffffff
	moveq	#0,d6
	sub.l	a0,d6	;d6.w seulement
	bra.s	fill_a4
	ENDC	;_68030
.positif:
	move.w	nb_mem_headers(a6),d7
	subq.w	#1,d7
	lea	amig_mem_tab(a6),a2
.bb:	move.l	(a2)+,d0
	move.l	(a2)+,d1
	cmp.l	d1,a0
	bcc.s	.next
	cmp.l	d0,a1
	bls.s	.next
	cmp.l	d0,a0
	bcc.s	.ok
;autour de d0
	sub.l	a0,d0
	move.w	d0,d6
	bra.s	fill_a4
.ok:	cmp.l	d1,a1
	bls.s	end_if_test
;autour de d1
	sub.l	d1,a1
	move.w	a1,d6
	sub.l	a0,d1
	add.w	d1,a4
	bra.s	fill_a4
.next:	dbf	d7,.bb
	subq.w	#1,d6
tir_fill:	st	(a4)+
fill_a4:	dbf	d6,tir_fill
end_if_test:
	movem.l (sp)+,d0-d1/d6-d7/a0-a2/a4
	rts

amig_test_if_readable5:
	movem.l	d0-d1/d6-d7/a0-a2/a4,-(sp)
	bsr.s	save_for_readable
	move.l	a1,d7
	IFNE	_68030
	tst.b	chip_type(a6)
	bne.s	.no_and
	ENDC
	and.l	#$ffffff,d7
.no_and:	move.l	d7,a0
	moveq	#1,d6
	bra.s	do_the_test

amig_test_if_readable2:
	movem.l	d0-d1/d6-d7/a0-a2/a4,-(sp)
	bsr.s	save_for_readable
	move.l	a1,d7
	IFNE	_68030
	tst.b	chip_type(a6)
	bne.s	.no_and
	ENDC
	and.l	#$ffffff,d7
.no_and:	move.l	d7,a0
	moveq	#2,d6
	bra	do_the_test

amig_test_if_readable3:
	movem.l	d0-d1/d6-d7/a0-a2/a4,-(sp)
	move.l	a4,d7
	bsr.s	save_for_readable
	IFNE	_68030
	tst.b	chip_type(a6)
	bne.s	.no_and
	ENDC
	and.l	#$ffffff,d7
.no_and:	move.l	d7,a0
	moveq	#1,d6
	bra	do_the_test

amig_test_if_readable4:
	movem.l	d0-d1/d6-d7/a0-a2/a4,-(sp)
	bsr.s	save_for_readable
	move.l	a2,d7
	IFNE	_68030
	tst.b	chip_type(a6)
	bne.s	.no_and
	ENDC
	and.l	#$ffffff,d7
.no_and:
	move.l	d7,a0
	moveq	#10,d6
	bra	do_the_test

save_for_readable:
	lea	readable_buffer(a6),a4
	clr.l	(a4)
	clr.l	4(a4)
	clr.w	8(a4)
	rts

Memory_detection:
	movem.l	d2-d5/a2,-(sp)
	move.l	ExecBase(a6),a0
	lea	amig_mem_tab(a6),a1
	lea	MemList(a0),a0
	moveq	#3,d2
	move.l	#$000000,(a1)+
	move.l	#$c00000,(a1)+
	move.l	#$dff000,(a1)+
	move.l	#$dff020,(a1)+
	IFNE	daniel_version
	move.l	#$e90000,(a1)+
	move.l	#$ea0000,(a1)+
	moveq	#4,d2
	ENDC
	move.l	#$f00000,(a1)+
	move.l	#$1000000,(a1)+
	bra.s	.bb
.next:	move.l	20(a0),d0	;mh_lower
	clr.w	d0
	move.l	24(a0),d1	;mh_upper
	tst.w	d1
	beq.s	.ok
	clr.w	d1
	add.l	#$10000,d1
.ok:	bsr.s	.add_table
.bb:	move.l	(a0),a0
	tst.l	(a0)
	bne.s	.next
	move.w	d2,nb_mem_headers(a6)
	movem.l	(sp)+,d2-d5/a2
	rts

;4 cas
;-le nouveau bloc (d0,d1) n'a rien de commun
;-jointure gauche
;-jointure droite
;-inclus ds 1 autre bloc
.add_table:
	move.w	d2,d5
	lea	amig_mem_tab(a6),a2
.next1:	subq.w	#1,d5
	bmi.s	._add
	move.l	(a2)+,d3
	move.l	(a2)+,d4
	cmp.l	d4,d1
	bls.s	.gauche
	cmp.l	d4,d0
	bhi.s	.next1
	move.l	d3,d0
	bra.s	.dbf_ins	;reinjecter bloc
.gauche:	cmp.l	d3,d0
	bcc.s	.end	;inclus
	cmp.l	d1,d3
	bhi.s	.next1
;reinjecter bloc
	move.l	d4,d1
;suppression du bloc de la liste
	bra.s	.dbf_ins
.ins:	move.l	(a2),-8(a2)
	move.l	4(a2),-4(a2)
	addq.w	#8,a2
.dbf_ins:	dbf	d5,.ins
	subq.w	#1,d2		;maj
	subq.w	#8,a1
	bsr.s	.add_table	;recursion
	bra.s	.end
._add:	move.l	d0,(a1)+
	move.l	d1,(a1)+
	addq.w	#1,d2
.end:	rts

;ixemul_name:	dc.b	"ixemul.library",0
;	even

;compare les dates en (a0) et (a1), retour ds CCR
CmpDates:	move.l	(a0)+,d0	;days
	cmp.l	(a1)+,d0
	bne.s	.1
	move.l	(a0)+,d0	;mins
	cmp.l	(a1)+,d0
	bne.s	.1
	move.l	(a0)+,d0	;secs
	cmp.l	(a1)+,d0
.1:	rts

;appele avant la sortie d'adebug
amiga_exit:
; remettre Alert
	move.l	ExecBase(a6),a1
	move.w	#-$6c,a0
	move.l	initial_alert_addr(a6),d0
	CALLEXEC	SetFunction

	move.l	server_vbl(a6),d0
	beq.s	.no_vbl
	move.l	d0,a1
	moveq	#5,d0
	CALLEXEC	RemIntServer
	move.l	server_vbl(a6),a0
	move.l	#300,d0
	_JSR	free_memory
.no_vbl:
	move.l	gfxbase(a6),a0
	move.l	$26(a0),external_copperlist(a6)
	lea	custom,a0
; remettre INTENA
	move.w	initial_intena(a6),d0
	move.w	d0,external_intena(a6)
	bset	#15,d0
	move.w	d0,intena(a0)
	not.w	d0
	move.w	d0,intena(a0)
; remettre DMA
	move.w	initial_dmacon(a6),d0
	move.w	d0,external_dmacon(a6) ; a suivre par sbase0_sbase1
	_JSR	reput_exceptions
	_JSR	timers_exit
	_JSR	sbase0_sbase1
; remettre TC
	IFNE	_68030
	tst.b	chip_type(a6)
	beq.s	.00
	jsr	super_on
	move.l	d0,-(sp)
	_30
	pmove	initial_tc(a6),tc
	_00
	move.l	(sp)+,d0
	beq.s	.00
	move.l	d0,a0
	jsr	super_off
.00:	ENDC	;_68030
	move.l	initial_cia_kbd(a6),initial_kbdvec(a6)
	rts
