;**************************************
;	openlib.s
;	source de openlib.ro
;**************************************
OpenLibrary	EQU	-552

	move.l	4.w,a6
; 2ème paramètre: version minimale de la bibliothèque
	move.l	4(a1),d0
; 1er paramètre: pointeur sur le nom de la bibliothèque
	move.l	(a1),a1
	jsr	OpenLibrary(a6)
	rts			;résultat dans d0
