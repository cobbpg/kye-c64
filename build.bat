java kickass.KickAssembler startup.asm -o kye-pal-uncompressed.prg
java kickass.KickAssembler startup.asm -define NTSC -o kye-ntsc-uncompressed.prg
exomizer sfx sys -x3 -o kye-pal.prg kye-pal-uncompressed.prg
exomizer sfx sys -x3 -o kye-ntsc.prg kye-ntsc-uncompressed.prg