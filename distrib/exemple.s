	;exemple.s exemple de programme à tracer pour Adebug.

	opt	d+

Start:
	move.w	#$1234,d0
	moveq	#2,d1
	;flèche vers le bas
	bsr	routin_1
	move.w	#$4321,d0
	moveq	#-2,d1
	;[Ctl_A]
	bsr	routin_1
	moveq	#-2,d0
	move.w	#$4321,d1
	;[W]atch
	bsr	routin_2
	;Terminaison de programme
	rts

routin_1:
	nop
	dbf	d0,routin_1
	rts
routin_2:
	nop
	dbf	d1,routin_2
	rts
