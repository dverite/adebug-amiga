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
;  #[ CopperListe:
	even
copperlist_datas:
	IFNE	A4000
	dc.w	diwstrt,$2c81
	dc.w	diwstop,$2cc1
	dc.w	ddfstrt,$38
	dc.w	ddfstop,$d8
	dc.w	bpl1mod,-8
	dc.w	bpl2mod,-8
	ELSEIF
	dc.w	diwstrt,$2981
	dc.w	diwstop,$29c1
	dc.w	ddfstrt,$3c
	dc.w	ddfstop,$d4
	dc.w	bpl1mod,0
	dc.w	bpl2mod,0
	ENDC
	dc.w	bplcon0,%1001001000000000
	dc.w	bplcon1,0
	dc.w	bplcon2,$224
	dc.w	bpl1pt,0
	dc.w	bpl1pt+2,0
	dc.w	$180,0
	dc.w	$182,$fff
	dc.w	$1e4,$2100
	dc.w	$1fc,3
	dc.w	$096,$20
	dc.w	$096,$8180
	dc.w	$144,0
	dc.w	$146,0
	dc.w	$14c,0
	dc.w	$14e,0
	dc.w	$154,0
	dc.w	$156,0
	dc.w	$15c,0
	dc.w	$15e,0
	dc.w	$164,0
	dc.w	$166,0
	dc.w	$16c,0
	dc.w	$16e,0
	dc.w	$174,0
	dc.w	$176,0
	dc.w	$17c,0
	dc.w	$17e,0
	dc.w	$ffff,$fffe
taille_copperlist	EQU *-copperlist_datas	;128
;  #] CopperListe:
amiga_font:	incbin	font_8x8.bin
normal_task_entry_format:	dc.b	"%19s   % 8lx   % 3d    %s",0
waiting_task_entry_format:	dc.b	"%19s   % 8lx   % 3d    %s  %0lx",0
copperlist_format_text:	dc.b	"$%=lx",0
daniel_text: 	dc.b	"Amiga version by Daniel Vérité",0

	IFNE	english_text
set_copperlist_text:	dc.b	"Copperlist Address <@>",0
update_intena_text:	dc.b	"Internal Intena <0~$7fff>",0
reloc_copperlist_text:	dc.b	"Adebug's Copperlist Address <@>",0
reloc_screen_text:	dc.b	"Adebug's Screen Address <@>",0
ask_screensave_text:	dc.b	"Save screen <f>",0
	IFNE	amiga_avbl
ask_copperlist_text:	dc.b	"Display with C)opperlist V)bl A)lways vbl",0
	ELSEIF
ask_copperlist_text:	dc.b	"Display with C)opperlist V)bl",0
	ENDC
allocabs_failed_text: dc.b	"AllocAbs failed. Continue",0
reset_copperlist_text:	dc.b	"System Copperlist set",0
vbl_set_text:		dc.b	"Vbl display set",0
warning_vbl_message:	dc.b	"Display switched from Vbl to Copper",0
intena_updated_text:	dc.b	"Internal Intena set to %=x",0
goodreloc_copperlist_text: dc.b	"Copperlist moved to $%=lx",0
goodreloc_screen_text:	dc.b	"Screen moved to $%=lx",0
returned_from_multi_text: dc.b	"Returned from multitasking access",0
evaluating_vars_text:	dc.b	"Evaluating vars..",0
shell_result_text:	dc.b	"Shell result: %=ld",0
present_screen_copper_text: dc.b "CopperList: $%lx-$%lx, Screen: $%lx-$%lx",0
present_screen_intui_text:	dc.b "CopperList: None, Screen: Intuition",0
present_reloc_text:
	dc.b	"  Name       Start     Length       End",0
present_freemem_text:	dc.b	"Free memory: Chip %ld, Fast %ld, All %ld",0
idle_system_text:	dc.b	"No running task",0
present_task_text:	dc.b	" NAME                  ADDRESS   PRI    STATE   (SIGWAIT)",0
taskready_text:		dc.b	"Ready",0
taskwait_text:		dc.b	"Waiting",0
taskstopped_text:	dc.b	"Stopped",0

system_m103:	dc.b 	"Insufficient free store",0
system_m104:	dc.b	"Task table full",0
system_m120:	dc.b	"Argument line invalid or too long",0
system_m121:	dc.b	"File is not an object module",0
system_m122:	dc.b	"Invalid resident library during load",0
system_m202:	dc.b	"Object in use",0
system_m203:	dc.b	"Object already exists",0
system_m204:	dc.b	"Directory not found",0
system_m205:	dc.b	"Object not found",0
system_m206:	dc.b	"Invalid window",0
system_m209:	dc.b	"Packet requested type unknown",0
system_m210:	dc.b	"Invalid stream component name",0
system_m211:	dc.b	"Invalid object lock",0
system_m212:	dc.b	"Object of not required type",0
system_m213:	dc.b	"Disk not validated",0
system_m214:	dc.b	"Disk write protected",0
system_m216:	dc.b	"Directory not empty",0
system_m218:	dc.b	"Device not mounted",0
system_m219:	dc.b	"Seek error",0
system_m220:	dc.b	"Comment too big",0
system_m221:	dc.b	"Disk full",0
system_m222:	dc.b	"File is protected from datation",0
system_m223:	dc.b	"File is protected from writing",0
system_m224:	dc.b	"File is protected from reading",0
system_m225:	dc.b	"Not a dos disk",0
system_m226:	dc.b	"No disk in drive",0
system_m232:	dc.b	"No more entries in directory",0

no_task_error_text: dc.b 'You must load a task or disable the "separate task" mode',0
already_multi_error_text: dc.b	"Multitasking access already active",0
shell_multi_error_text:	dc.b	"Cannot call shell in multitasking access",0
multi_twice_error_text:	dc.b	"Current task is not loaded task",0
acia_ikbd_error_text:	dc.b	"No disk operation allowed in IPL>0 or low Intena",0
createproc_error_text:	dc.b	"Error in task creation",0
unknown_hunk_error_text:dc.b	"Unknown hunk",0
;--- LOAD PRG VARIABLES ---
notprocess_error_text:	dc.b	"Current task is not a Process",0
matching_error_text:	dc.b	"File doesn't match with program in memory",0
lpv_noname_error_text:	dc.b	"No name in cli_CommandName field",0
cli_damaged_error_text:	dc.b	"CLI structure damaged",0
lpv_fromwb_text:	dc.b	"Program hasn't been launched by CLI",0
ask_lpv_filename_text:	dc.b	"Load variables from file",0
lpv_fnf_error_text:	dc.b	"File not found",0
lpv_searching_text:	dc.b	"Searching for symbols in file <%s>...",0
guru_text:	dc.b	"Guru %lx:%lx caught",0
vbl_error_text:	dc.b	"The Vbl interrupt is disabled",0
	ENDC	;english_text
;		#[ Amiga internal messages:
	IFNE	daniel_version
;results
ttf_off_text:		dc.b	"Trace task flag switched to OFF",0
ttf_on_text:		dc.b	"Trace task flag switched to ON",0
vbl_stop_off_text:	dc.b	"Vbl stop flag switched to OFF",0
vbl_stop_on_text:	dc.b	"Vbl stop flag switched to ON",0

internal_infos_title_text:	dc.b	"INTERNAL INFOS",0
internal_values_format:		dc.b	" = $%=lx",0
	even
; FLAGS
internal_flags_table:
	dc.l	.acia_ikbd_text,acia_ikbd
	dc.l	.tracetask_flag_text,trace_task_flag
	dc.l	.idle_flag_text,idle_flag
	dc.l	.multi_flag_text,multitask_access_flag
	dc.l	.kick2x_text,kick2x_flag
	dc.l	0
.acia_ikbd_text:	dc.b	"acia_ikbd",0
.tracetask_flag_text:	dc.b	"trace_task_flag",0
.idle_flag_text:	dc.b	"idle_flag",0
.multi_flag_text:	dc.b	"multitasking_access_flag",0
.kick2x_text:		dc.b	"kick2x_flag",0
	even

; VALUES
internal_values_table:
	dc.l	.p1_task_text,p1_task
	dc.l	.p1_current_task_text,p1_current_task
	dc.l	.external_kbdvec_text,external_kbdvec
	dc.l	.timers_ctl_text,external_mfp_ctl_struct
	dc.l	.timers_speed_text,external_mfp_speed_struct
	dc.l	.keybdev_text,keybdev
	dc.l	.inputdev_text,inputdev
	dc.l	0
.p1_task_text:		dc.b	"p1_task",0
.p1_current_task_text:	dc.b	"p1_current_task",0
.external_kbdvec_text:	dc.b	"external_kbdvec",0
.timers_ctl_text:	dc.b	"timers ctl",0
.timers_speed_text:	dc.b	"timers speed",0
.keybdev_text:		dc.b	"keyboard.device",0
.inputdev_text:		dc.b	"input.device",0
	even

;BYTES
internal_bytes_table:
	dc.l	.spec_keys_text,stat_spec_keys
	dc.l	0
.spec_keys_text:	dc.b	"stat_spec_keys",0
	even
	ENDC	;de daniel_version
;		#] Amiga internal messages:
	IFNE	french_text
set_copperlist_text:	dc.b	"Adresse Copperlist <@>",0
update_intena_text:	dc.b	"Intena Interne <0~$7fff>",0
reloc_copperlist_text:	dc.b	"Adresse de la Copperlist d'Adebug <@>",0
reloc_screen_text:	dc.b	"Adresse de l'écran d'Adebug <@>",0
ask_screensave_text:	dc.b	"Sauver l'écran <f>",0
ask_copperlist_text:	dc.b	"Affichage avec C)opperlist V)bl",0
allocabs_failed_text: dc.b	"Echec de l'allocation absolue. Continuer",0
reset_copperlist_text:	dc.b	"Copperlist système mise",0
vbl_set_text:		dc.b	"Affichage Vbl selectionné",0
warning_vbl_message:	dc.b	"Affichage changé de Vbl à Copper",0
intena_updated_text:	dc.b	"Intena interne mise à %=x",0
goodreloc_copperlist_text: dc.b	"Copperlist déplacée en $%=lx",0
goodreloc_screen_text:	dc.b	"Ecran déplacé en $%=lx",0
returned_from_multi_text: dc.b	"Commande d'accès multitache terminée",0
evaluating_vars_text:	dc.b	"Evaluation des variables en cours..",0
present_screen_copper_text: dc.b "CopperList: $%lx-$%lx, Ecran: $%lx-$%lx",0
present_screen_intui_text:	dc.b "CopperListe: aucune, Ecran: Intuition",0
present_freemem_text:	dc.b	"Mémoire libre: Chip %ld, Fast %ld, All %ld",0
present_reloc_text:
	dc.b	" Nom        Début     Longueur      Fin",0
idle_system_text:	dc.b	"Aucune tache active",0
present_task_text:	dc.b	" NOM                    ADRESSE   PRI     ETAT  (attente de)",0
taskready_text:		dc.b	"Prêt",0
taskwait_text:		dc.b	"Attente",0
taskstopped_text:	dc.b	"Stoppé",0
system_m103:	dc.b 	"Espace mémoire insuffisant",0
system_m104:	dc.b	"Table des tâches pleine",0
system_m120:	dc.b	"Ligne de commande invalide ou trop longue",0
system_m121:	dc.b	"Le fichier n'est pas un exécutable",0
system_m122:	dc.b	"Bibliothèque résidente invalide durant chargement",0
system_m202:	dc.b	"Objet actuellement utilisé",0
system_m203:	dc.b	"Objet existant déja",0
system_m204:	dc.b	"Répertoire introuvable",0
system_m205:	dc.b	"Objet introuvable",0
system_m206:	dc.b	"Fenêtre invalide",0
system_m209:	dc.b	"Type du paquet demandé inconnu",0
system_m210:	dc.b	"Composante du nom de canal invalide",0
system_m211:	dc.b	"Lock d'objet invalide",0
system_m212:	dc.b	"Objet pas du type requis",0
system_m213:	dc.b	"Disque non validé",0
system_m214:	dc.b	"Disque protegé en écriture",0
system_m216:	dc.b	"Répertoire non vide",0
system_m218:	dc.b	"Périphérique non monté",0
system_m219:	dc.b	"Erreur de seek",0
system_m220:	dc.b	"Commentaire trop grand",0
system_m221:	dc.b	"Disque plein",0
system_m222:	dc.b	"Fichier protégé contre le changement de date",0
system_m223:	dc.b	"Fichier protégé contre l'écriture",0
system_m224:	dc.b	"Fichier protegé contre la lecture",0
system_m225:	dc.b	"Disque de type non DOS",0
system_m226:	dc.b	"Pas de disque dans le lecteur",0
system_m232:	dc.b	"Plus d'entrées dans le répertoire",0

no_task_error_text: dc.b "Vous devez charger une tache ou inhiber le mode ",34,"tache séparée",34,0
already_multi_error_text: dc.b	"Accès au multitâche déja actif",0
shell_multi_error_text:	dc.b	"Accès shell impossible en accès multitâche"
multi_twice_error_text:	dc.b	"La tache courante n'est pas la tache chargée",0
acia_ikbd_error_text:	dc.b	"Opérations disque non autorisées en IPL>0 ou basse Intena",0
createproc_error_text:	dc.b	"Erreur dans la création de la tache",0
unknown_hunk_error_text:dc.b	"Hunk inconnu",0
;--- LOAD PRG VARIABLES ---
notprocess_error_text:	dc.b	"La tache courante n'est pas un Process",0
matching_error_text:	dc.b	"Le fichier ne correspond pas au programme en mémoire",0
lpv_noname_error_text:	dc.b	"Pas de nom dans le champ cli_CommandName",0
cli_damaged_error_text:	dc.b	"Structure CLI endommagée",0
lpv_fromwb_text:	dc.b	"Programme non lancé par le CLI",0
ask_lpv_filename_text:	dc.b	"Charger les variables du fichier",0
lpv_fnf_error_text:	dc.b	"Fichier non trouvé",0
lpv_searching_text:	dc.b	"Recherche des symboles dans le fichier <%s>...",0
guru_text:	dc.b	"Guru %lx:%lx intercepté",0
vbl_error_text:	dc.b	"L'interruption Vbl est inactive",0
	ENDC	;de french_text
	even
system_messages_table: ;>=200 uniquement
	dc.l	system_unknown
	dc.l	system_unknown
	dc.l	system_m202
	dc.l	system_m203
	dc.l	system_m204
	dc.l	system_m205
	dc.l	system_m206
	dc.l	system_m209
	dc.l	system_m210
	dc.l	system_m211
	dc.l	system_m212
	dc.l	system_m213
	dc.l	system_m214
	dc.l	system_m216
	dc.l	system_m218
	dc.l	system_m219
	dc.l	system_m220
	dc.l	system_m221
	dc.l	system_m222
	dc.l	system_m223
	dc.l	system_m224
	dc.l	system_m225
	dc.l	system_m226
	dc.l	system_m232

adebug_task_name:
	IFEQ	debug
	dc.b	"Adebug",0
	ELSEIF
	dc.b	"Adebug (debug)",0
	ENDC
	even
Amiga_window_data:
	dc.w	$1a0,0,160,10	;$1b4,16,160,10
	dc.b	-1,-1
	dc.l	CLOSEWINDOW
	dc.l	WINDOWDRAG|WINDOWDEPTH|WINDOWCLOSE|RMBTRAP
	dc.l	0,0,Amiga_window_title,0,0
	dc.w	0,0,0,0
	dc.w	WBENCHSCREEN

NewScreenStruct:
	dc.w	0,0,640,256
	dc.w	1	;nplanes
	dc.b	0,1	;detail and block pens
	dc.w	V_HIRES	;display modes for this screen
	dc.w	CUSTOMSCREEN|SCREENQUIET	;|CUSTOMBITMAP
	dc.l	0	;pointer to default screen font
	dc.l	Amiga_window_title	;screen title
	dc.l	0	;first in list of custom screen gadgets
	dc.l	0 ; BitmapStruct	;pointer to custom BitMap structure

;BitmapStruct:
	
Amiga_window_title:
	dc.b	" Adebug ",0
amiga_printer_name:	dc.b	"prt:",0
fichier_var:	dc.b	"adebug.var",0
save_var:	dc.b	"adebug.prefs",0
def_mac_text:	dc.b	"a_debug.mac",0
mac_ext_text:	dc.b	".mac",0
win_ext_text:	dc.b	".prinfo",0

ascii_table:	incbin	"tables.bin"
