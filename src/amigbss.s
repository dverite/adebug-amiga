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
;bss amiga

	cnop	0,4
bcpl_prog_name: ds.b	100
my_dta:	ds.b	DTA_BUFFER_SIZE

dosbase:			ds.l	1
gfxbase:			ds.l	1
ExecBase:			ds.l	1
intuibase:		ds.l	1
amiga_stop_flag:		ds.b	1
vbl_stop_flag:		ds.b	1
stop_req_flag:		ds.b	1
trace_task_flag:		ds.b	1
multitask_access_flag:	ds.b	1
amiga_call_shell_flag:	ds.b	1
kick2x_flag:		ds.b	1
WBstart_flag:		ds.b	1
multi_stack:		ds.l	1
amiga_stop_sr:		ds.w	1
amiga_stop_address:		ds.l	1
Adebug_task:		ds.l	1
current_lock:		ds.l	1
is_super:			ds.w	1
tmp_a7_buf:		ds.l	1
supexec_ssp:		ds.l	1
amiga_stack_size:		ds.l	1
internal_am_ssp:		ds.l	1
am_stack_len	EQU	1024
amiga_sup_stack:		ds.b	am_stack_len
system_autoreq:		ds.l	1 ; boite initiale
actual_autoreq:		ds.l	1 ; boite de p1
initial_alert_addr:		ds.l	1
server_clav:		ds.l	1
server_vbl:		ds.l	1
vbl_counter:		ds.l	1
current_ipl:		ds.w	1
conhandle:		ds.l	1
amiga_window:		ds.l	1
amiga_stdin:		ds.l	1
amiga_stdout:		ds.l	1
ciaares:			ds.l	1
keybdev:			ds.l	1
inputdev:			ds.l	1
inputdev_task:		ds.l	1
gameportdev:		ds.l	1
initial_cia_kbd:		ds.l	1
initial_tc:		ds.l	1	;reg. TC initial
	IFNE	amigarevue
protected_text:		ds.l	1
protec_routine_1:		ds.l	1
protec_routine_2:		ds.l	1
protec_addr:		ds.l	1
protec_checksum:		ds.l	1
	ENDC
old_ikbd_buffer:		ds.l	1
stat_spec_keys:		ds.w	1
amiga_scancode:		ds.w	1
down_key_flag:		ds.b	1
repeating_key_flag:		ds.b	1

;donnees task initiales
initial_trapcode:		ds.l	1
initial_task_name:		ds.l	1
initial_pr_COS:		ds.l	1
initial_pr_CIS:		ds.l	1
initial_pr_ReturnAddr:	ds.l	1
initial_pr_WindowPtr:	ds.l	1
initial_cli_Module:		ds.l	1
initial_cli_CommandName:	ds.l	1
initial_pr_CLI:		ds.l	1
;structures pour recup keymap
read_reply_port:		ds.b	MP_SIZE
write_reply_port:		ds.b	MP_SIZE
iorequest:		ds.b	IOSTD_SIZE

ciaa_icr:	ds.b	1
ciab_icr:	ds.b	1
external_tmp_copperlist:ds.l	1
external_copperlist:	ds.l	1
external_intena:	ds.w	1
external_dmacon:	ds.w	1
	IFNE	amiga_avbl
external_vbl:	ds.l	1
	ENDC
external_return_addr:	ds.l	1
external_kbdvec:	ds.l	1
p1_initial_usp:		ds.l	1
initial_regs:	ds.l	15
	even
internal_intena:	ds.w	1
internal_dmacon:	ds.w	1
internal_copperlist:	ds.l	1
IntuiScr:		ds.l	1
internal_return_addr:	ds.l	1
internal_vbr:		ds.l	1
copper_active:		ds.b	1
	IFNE	amiga_avbl
always_vbl_flag:	ds.b	1
vbl_patchkey:		ds.b	1
	ENDC
	even
initial_intena:		ds.w	1
initial_dmacon:		ds.w	1
amiga_printer_file:	ds.l	1
coplist_allocation_flag:ds.b	1
screen_allocation_flag:	ds.b	1
amiga_command_line:
	ds.b	$100
other_exec_sym_nb:	ds.l	1
;TASKS
p1_task:		ds.l	1
p1_task_sigwait:	ds.l	1
p1_current_task:	ds.l	1
p1_current_task_sigwait:ds.l	1
p1_current_task_state:	ds.b	1
p1_task_state:		ds.b	1
adebug_sigwait:		ds.l	1
exec_supervisor:	ds.l	1

p1_start_flag:		ds.b	1
idle_flag:		ds.b	1
force_ipl_flag:		ds.b	1
term_task_flag:		ds.b	1
no_inputdev_flag:		ds.b	2
	even
old_internal_sr:		ds.w	1
PrgSegList:		ds.l	1
SrcSegList:		ds.l	1	;trie par adresses croissantes
other_nb_segs:		ds.w	1
n_amiga_segs: 		ds.w	1
nb_text_segs:		ds.w	1
nb_data_segs:		ds.w	1
nb_bss_segs:		ds.w	1
long_buffer: 		ds.l	1
cur_text_section:		ds.w	1
cur_data_section:		ds.w	1
cur_bss_section:		ds.w	1
nb_draw_sections:		ds.w	1
multitask_context_buffer:	ds.b	EXTERNAL_CONTEXT_SIZE
adbg_multi_context_buf:	ds.b	4+2+16*4+8
reply_port:	ds.b	MP_SIZE
input_req:	ds.b	IOSTD_SIZE
input_int:	ds.b	IS_SIZE
sftalthelp_msk:	ds.l	1
inputdev_string:	ds.b	100
adebug_keymap	ds.b	128*3	;[],[Sft],[Sft_Alt]
capsable_table:	ds.b	128/8	;1 bit par scan
;  #[ Multitasking stacks
		ds.b	1024
multi_ssp:	ds.l	1
		ds.b	4096
multi_usp:	ds.l	1
;  #] Multitasking stacks

nb_mem_headers:	ds.w	1
amig_mem_tab:	ds.l	2*20
;*** PROVISOIRE
w3len:		ds.w	1
alt_s_sub1:	ds.w	1
alt_s_sub2:	ds.w	1
CopListFlg:	ds.b	1	;coplist d'adbg ou screen ?
	even
