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
AMIGA_NB_LINES equ 256
custom = $dff000

; ints+dma
dmaconr = 2
dmacon = $96
intenar = $1c
intreqr = $1e
intena = $9a
intreq = $9c
serper	EQU	$32
serdat	EQU	$30
serdatr	EQU	$18

; copper
cop1lc = $80
copjmp1 = $88

; ecran
diwstrt = $8e
diwstop = $90
ddfstrt = $92
ddfstop = $94
bpl1pt = $e0
bpl2pt = $e4
bpl3pt = $e8
bpl4pt = $ec
bpl5pt = $f0
bpl6pt = $f4
bplcon0 = $100
bplcon1 = $102
bplcon2 = $104
bpl1mod = $108
bpl2mod = $10a

lecture_clavier	equ	$bfec01
execbase	equ	4
	;EXECLIB pas d'init
Supervisor	equ	-30
Schedule		equ	-42
Reschedule	equ	-48
Switch		equ	-54
Dispatch		equ	-60
SuperState	equ	-150
UserState	equ	-156
AllocMem	equ	-198
AllocAbs	equ	-204
FreeMem		equ	-210
AvailMem	equ	-216
OldOpenLib	equ	-408
CloseLib	equ	-414
OpenLib		equ	-552
SetFunction	equ	-420
RemTask		equ	-288
FindTask	equ	-294
Wait		equ	-$13e
Signal		equ	-$144
AddIntServer	equ	-168
RemIntServer	equ	-174
FindName	equ	-276
GetMsg		equ	-372
ReplyMsg	equ	-378
WaitPort	equ	-384
AllocSignal	equ	-330
FreeSignal	equ	-336
AddPort		equ	-354
RemPort		equ	-360
OpenDevice	equ	-444
CloseDevice	equ	-450
DoIO		equ	-456
CacheClearU	equ	-$27c

	;DOSLIB init
Open	equ	-30
Close	equ	-36
Read	equ	-42
Write	equ	-48
Input	EQU	-54 
Output	EQU	-60 
Seek	equ	-66
Lock	equ	-84
UnLock	equ	-90
DupLock	equ	-96
Examine	equ	-102
ExNext	equ	-108
IOErr	equ	-132
CreateProc	equ	-138
CurrentDir	equ	-126
Delay		equ	-198
WaitForChar	equ	-204
ParentDir	equ	-210
Execute		equ	-222
	; Intuition
OpenWindow	equ	-204
CloseWindow	equ	-72
OpenScreen	equ	-198
CloseScreen	equ	-66
ScreenToBack	equ	-246
ScreenToFront	equ	-252

	; Graphics
SetRGB4		equ	-288

; quelques equates DOS
pr_CLI		equ	$ac
pr_CurrentDir	equ	$98
pr_CIS		equ	$9c
pr_COS		equ	$a0
pr_SegList	equ	$80
pr_ReturnAddr	equ	$b0
pr_WindowPtr	equ	$b8
cli_CommandName	equ	16
cli_Module	equ	60

fh_Buf		equ	12
fh_Pos		equ	16
fh_End		equ	20

; quelques equates Exec
MP_FLAGS	equ	14
MP_SIGBIT	equ	15
MP_SIGTASK	equ	16
PA_SIGNAL	equ	0
NT_MSGPORT	equ	4

IO_DEVICE	equ	20
IO_COMMAND	equ	$1c
IO_ERROR	equ	$1f
IO_SIZE		equ	$20
IO_LENGTH	equ	$24
IO_DATA		equ	$28
IND_ADDHANDLER	equ	9
IND_REMHANDLER	equ	10
MN_REPLYPORT	equ	14
IS_DATA		equ	14
IS_CODE		equ	18

MP_SIZE		equ	$22
IOSTD_SIZE	equ	$30
IS_SIZE		equ	$16

;	Keymap
CD_ASKDEFAULTKEYMAP	EQU	11
KCB_STRING	EQU	6
KCB_DEAD	EQU	5
KCB_SHIFT	EQU	0
KCB_ALT		EQU	1
KCF_SHIFT	EQU	$01
KCF_ALT		EQU	$02
DPF_MOD		EQU	$01
DPF_DEAD	EQU	$08
km_LoKeyMapTypes	EQU	0
km_LoKeyMap		EQU	4
km_LoCapsable		EQU	8
km_HiKeyMapTypes	EQU	16
km_HiKeyMap		EQU	20
km_HiCapsable		EQU	24
km_SIZEOF		EQU	32

; structure ExecBase
LIB_VERSION	EQU	$14
SoftVer		EQU	$22
ColdCapture	EQU	$2a
CoolCapture	EQU	$2e
WarmCapture	EQU	$32
MaxExtMem	EQU	$4e
ThisTask	EQU	$114
SysFlags	EQU	$124
IDNestCnt	EQU	$126
TDNestCnt	EQU	$127
AttnFlags	EQU	$128
TaskTrapCode	EQU	$130
TaskExceptCode	EQU	$134
TaskExitCode	EQU	$138
TaskSigAlloc	EQU	$13c
TaskTrapAlloc	EQU	$140
MemList		EQU	$142
TaskReady	EQU	$196
TaskWait	EQU	$1a4

 rsreset ;structure Task
ln_succ		rs.l	1
ln_pred		rs.l	1
ln_type		rs.b	1
ln_pri		rs.b	1
ln_name		rs.l	1
tc_Flags	rs.b	1
tc_State	rs.b	1
tc_IDNestCnt	rs.b	1
tc_TDNestCnt	rs.b	1
tc_SigAlloc	rs.l	1
tc_SigWait	rs.l	1
tc_SigRecvd	rs.l	1
tc_SigExcept	rs.l	1
tc_TrapAlloc	rs.w	1
tc_TrapAble	rs.w	1
tc_ExceptData	rs.l	1
tc_ExceptCode	rs.l	1
tc_TrapData	rs.l	1
tc_TrapCode	rs.l	1
tc_SPReg	rs.l	1
tc_SPLower	rs.l	1
tc_SPUpper	rs.l	1
tc_Switch	rs.l	1
tc_Launch	rs.l	1
tc_MemEntry	rs.b	14 ;=LH_SIZE
tc_Userdata	rs.l	1
tc_SIZE	rs.w	0

; quelques equates Intuition
ie_Class		equ	4
ie_SubClass	equ	5
ie_Code		equ	6
ie_Qualifier	equ	8
ie_EventAddress	equ	10
ie_TimeStamp	equ	14 (2 longs TV_SECS et TV_MICRO)

IECLASS_RAWKEY	EQU	1
WINDOWDRAG	EQU	2
WINDOWDEPTH	EQU	4
WINDOWCLOSE	EQU	8

WBENCHSCREEN	EQU	$0001
RMBTRAP		EQU	$00010000

CLOSEWINDOW	EQU	$00000200
CUSTOMSCREEN	EQU	$f
CUSTOMBITMAP	EQU	$40
SCREENQUIET	EQU	$100

sc_BitMap		equ	$b8	;offs struct Bitmap ds struct Screen
sc_ViewPort	equ	$2c	;offs struct ViewPort ds struct Screen
bm_Planes		equ	8	;offs plans ds struct Bitmap

V_HIRES		EQU	$8000

DTA_NAME	EQU	8
DTA_TYPE	EQU	4
DTA_SIZE	EQU	124
DTA_TIME	EQU	132
DTA_BUFFER_SIZE	EQU	256
PATH_BUFFER_SIZE	EQU	256

DIRECTORY_SEPARATOR	EQU	'/'

MEMORY_EXIT_ERROR_NUMBER	EQU	-39

CALLEXEC	MACRO
	move.w	#\1,-(sp)
	jsr	call_execlib
	addq.w	#2,sp
	ENDM
CALLDOS	MACRO
	move.w	#\1,-(sp)
	jsr	call_doslib
	addq.w	#2,sp
	ENDM
CALLINT	MACRO
	move.w	#\1,-(sp)
	jsr	call_intuilib
	addq.w	#2,sp
	ENDM
CALLGFX	MACRO
	move.w	#\1,-(sp)
	jsr	call_graphlib
	addq.w	#2,sp
	ENDM

OPENLIB	MACRO	; Name
	lea	\1,a1
	CALLEXEC	OldOpenLib
	ENDM

CLOSELIB	MACRO	; LibPtr
	move.l	\1,a1
	CALLEXEC	CloseLib
	ENDM

LOCK	MACRO	; Name, Mode
	move.l	\1,d1
	moveq	#\2,d2
	CALLDOS	Lock
	ENDM

UNLOCK	MACRO	; LockPtr
	move.l	\1,d1
	CALLDOS	UnLock
	ENDM

EXAMINE	MACRO	; LockPtr, InfoBlockPtr
	move.l	\1,d1
	move.l	\2,d2
	CALLDOS	Examine
	ENDM

PARENTDIR	MACRO
	move.l	\1,d1
	CALLDOS		ParentDir
	ENDM

dos_name:
	dc.b	"dos.library"
lock_empty_name:
	dc.b	0
gfx_name:	dc.b	"graphics.library",0
intui_name:	dc.b	"intuition.library",0
keybdev_name:	dc.b	"keyboard.device",0
inputdev_name:	dc.b	"input.device",0
ciaares_name:	dc.b	"ciaa.resource",0
gameportdev_name:dc.b	"gameport.device",0
consoledev_name:dc.b	"console.device",0
 even
;	 #[ Call_execlib:
;d0=offset de library
call_execlib:
	movem.l	d3-d7/a2-a6,-(sp)
	move.l	4.w,a6
	move.w	44(sp),d7
	jsr	(a6,d7.w)
	movem.l	(sp)+,d3-d7/a2-a6
	rts
;	 #] Call_execlib:
;	 #[ Call_doslib:
;d0=offset de library
call_doslib:
	movem.l	d3-d7/a2-a6,-(sp)
	move.l	dosbase(a6),a6
	move.w	44(sp),d7
	jsr	(a6,d7.w)
	movem.l	(sp)+,d3-d7/a2-a6
	rts
;	 #] Call_doslib:
;	 #[ Call_intuilib:
;d0=offset de library
call_intuilib:
	movem.l	d3-d7/a2-a6,-(sp)
	move.l	intuibase(a6),a6
	move.w	44(sp),d7
	jsr	(a6,d7.w)
	movem.l	(sp)+,d3-d7/a2-a6
	rts
;	 #] Call_intuilib:
;	 #[ Call_graphlib:
;d0=offset de library
call_graphlib:
	movem.l	d3-d7/a2-a6,-(sp)
	move.l	gfxbase(a6),a6
	move.w	44(sp),d7
	jsr	(a6,d7.w)
	movem.l	(sp)+,d3-d7/a2-a6
	rts
;	 #] Call_graphlib:
