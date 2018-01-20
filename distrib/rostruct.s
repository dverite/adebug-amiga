; structure de communication d'1 RO Adebug
; taille: 137 octets

	rsreset
v_number	rs.w	1
exec_version	rs.l	1
window_1	rs.l	1
window_2	rs.l	1
window_3	rs.l	1
window_4	rs.l	1
window_5	rs.l	1
prog		rs.l	1 
d0_reg		rs.l	1
d1_reg		rs.l	1
d2_reg		rs.l	1
d3_reg		rs.l	1
d4_reg		rs.l	1
d5_reg		rs.l	1
d6_reg		rs.l	1
d7_reg		rs.l	1
a0_reg		rs.l	1
a1_reg		rs.l	1
a2_reg		rs.l	1
a3_reg		rs.l	1
a4_reg		rs.l	1
a5_reg		rs.l	1
a6_reg		rs.l	1
a7_reg		rs.l	1
ssp_reg		rs.l	1
sr_reg		rs.w	1
pc_reg		rs.l	1
task_addr	rs.l	1
ro_addr:	rs.l	1
copperlist_addr	rs.l	1

;interprété par Adebug en retour de RO
string_addr	rs.l	1
reserved	rs.l	2
reput_exc	rs.b	1
IPL7		rs.b	1
timeraa		rs.b	1
timerab		rs.b	1
timerba		rs.b	1
timerbb		rs.b	1
redraw_screen	rs.b	1
rs232_output	rs.b	1
reserved2	rs.b	1
