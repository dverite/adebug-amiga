CFLAGS = -g -DADEBUG -DBDEBUG -c -m68020 -m68881 -Wall
CC = gcc
HCONV = mdh0:bin/hunkconv
BIGSTACK = stack 200000
NORMSTACK = stack 50000
COBJS = bsdeval.o bsdevfn.o bsddata.o bsdmain.o bsdarray.o atof.o ftoa.o bsd.o \
	bsdprint.o
ASMOBJS = _debug.o _ldexp.o
OBJS = $(ASMOBJS) $(COBJS)
OBJS2 = _adebug.o _ldexp.o $(COBJS)
ASMSRCS = adebug.s pcdebug.s srcdebug.s databss.s adebug2.s amiga.s \
	amlabel.s amigdata.s amigbss.s alt_e.s disasmxx.s bsddebug.s
 
cdebug:	$(OBJS)
	ld -o cdebug -L/ade/lib/libm020/libnix $(OBJS) \
	-L/ade/lib/libm020 /ade/lib/libnix/ncrt0.o -lgcc -lnixmain -lnix -lgcc -lstubs -lm \
	-L/ade/lib/gcc-lib/m68k-amigaos/2.7.2.1/

deb:	$(OBJS)
	cdebug ld -o cdebgg -amiga-debug-hunk -L/ade/lib/libm020/libnix $(OBJS) \
	-L/ade/lib/gcc-lib/m68k-amigaos/2.7.2.1/ -L/ade/lib/libm020 /ade/lib/libnix/ncrt0.o \
	-lgcc -lnixmain -lnix -lgcc -lstubs -lm

adebug:	$(OBJS2)
	ld -s -o adebug -L/ade/lib/libnix $(OBJS2) /ade/lib/libnix/ncrt0.o \
	 -lgcc -lnixmain -lnix -lgcc -lstubs -lm \
	-L/ade/lib/gcc-lib/m68k-amigaos/2.7.2.1

_adebug.o: adebug.o
	$(HCONV) adebug.o _adebug.o

_debug.o: debug.o
	$(HCONV) debug.o _debug.o

_ldexp.o: ldexp.o
	$(HCONV) ldexp.o _ldexp.o
	
debug.o: $(ASMSRCS)
	asm -l -d -D=debug -D=C_EVAL adebug.s

adebug.o: $(ASMSRCS)
#	asm -l -D=C_EVAL adebug.s
	asm -l adebug.s

ldexp.o: ldexp.s
	asm -l -d ldexp.s

cleano:
	c:delete $(COBJS)

%.o: %.c
	$(CC) $(CFLAGS) $<

