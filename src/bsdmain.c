/*
 Copyright 1990-2006 Alexandre Lemaresquier, Raphael Lemoine
                     Laurent Chemla (Serial support), Daniel Verite (AmigaOS support)

 This file is part of Adebug.

 Adebug is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 Adebug is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Adebug; if not, write to the Free Software
 Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

*/
/* bsdmain.c */
#include "bsdeval.h"

int Sizes[TT_LDOUBLE-TT_CHAR+1]={
	1,1,2,2,4,4,
#ifdef TARGET_GCC
	4,4,
	4,4,
#endif
	sizeof(float),sizeof(double),sizeof(long double)
};

#ifdef __AMIGA
void *DOSBase;
#endif

#if defined(ALIB)
char *PrgName="alib";
long CurNbFileSyms; /* nb de symboles visibles du fichier courant */
CSYMP *CurTabFileSyms;

void BsdInternalError(char *ch)
{
	fprintf(stderr,"erreur fatale: %s\n",ch);
	exit(1);
}
#endif	ALIB

#if defined(ADEBUG)
char *PrgName="source";
ulong *HardRegs; /* d0_buf(a6) */
short FramePtr;

char MemSpace[10000];
static char *CurPt=MemSpace;
int MallocNb,FreeNb;

void *MyMalloc(ulong size)
{
	void *p=CurPt;

	if ((CurPt+=size)>MemSpace+10000)
		return NULL;
	else {
		MallocNb++;
		return p;
	}
}

void MyMfree(void *pt,ulong size)
{
	if (CurPt-size==pt) {
		CurPt-=size;
		FreeNb++;
	}
}

void BsdInternalError(char *ch) {}

#endif	ADEBUG

#if defined(WDB)
char *PrgName="source";
ulong *HardRegs; /* d0_buf(a6) */
short FramePtr;
long CurNbFileSyms; /* nb de symboles visibles du fichier courant */
CSYMP *CurTabFileSyms;

void BsdInternalError(char *ch) {}

void DBSetRegister(long n,char *buf,long sz)
{
	ulong (*comm)(OP_ENUM op,short index,long value); 	/* comm */

	comm=M68kComm;
	n++;	/* for SR! sigh. */
	switch(sz) {
		case 1:
			comm(OP_WRITE,n,(long)*(char *)buf);
		break;
		case 2:
			comm(OP_WRITE,n,(long)*(short *)buf);
		break;
		default:
		case 4:
			comm(OP_WRITE,n,(long)*(long *)buf);
		break;
	}
}
#endif	WDB

#ifdef TARGET_PURE_C
void InitHTypes(void)
{
	int i;
	for (i=0;i<=TT_LDOUBLE-TT_CHAR;i++) {
		htypes[i].top=i+TT_CHAR;
		htypes[i].modifier=0;
		htypes[i].sym=NULL;
		htypes[i].size=Sizes[i];
		memset(&(htypes[i].t),0,sizeof(htypes[i].t));
	}
}
#endif

#ifdef ADEBUG
int main()
{
/*
	char buf[1000];

	InitHTypes();
	CreateVars();

	while (gets(buf)) {
		Valeur(buf);
	}
*/
	return 0;
}
#endif
