Adebug for Amiga
================


Adebug was a commercial assembly-level debugger for the Motorola 68000
family.
It shipped in the early 90's under the french name Adebog for
Atari ST and Amiga computers.

This is the most recent sources from my backups, as the responsible
for the Amiga version.  They're released under the GNU GPL v2.

Some pre-compiled binaries are included in `bin/`. These are not
released binaries, but the last builds as they are, made circa 1994.

`bin/adebug`: 68000 version  
`bin/adebug.30`: includes 68020/30 support (A1200 & A3000)  
`bin/cnodebug`: probably includes C source-level debugging for GCC.  

`distrib/` should contain all the files that were copied onto a floppy
disk for customers (Adebog 1.02).

`src/` contains the last sources I have. Comments are generally in
french and with ISO-Latin1 accents. The parts in C implement an optional C
source-level support that, as far as I remember, worked for programs built with
GCC.  
The binaries can probably be built with Devpac, although in the end we
used our own assembler called `Assemble`.

The french magazine Amiga News published a test in October 1991:
http://obligement.free.fr/articles/adebog.php

If you're interested in the Atari version see:
https://github.com/frost242/adebug


- Daniel Vérité
