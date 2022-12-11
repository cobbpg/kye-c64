gt2reloc sound/kye-pal.sng sound/kye-pal.sid
gt2reloc sound/kye-ntsc.sng sound/kye-ntsc.sid -N -G423.88 -AFF0F -Benabled
gt2reloc sound/kye-pal.sng sound/music-pal.bin -D1 -W40 -G440
gt2reloc sound/kye-ntsc.sng sound/music-ntsc.bin -D1 -W40 -G423.88 -Benabled
ins2snd2 sound/death.ins sound/sfx-death.bin -b
ins2snd2 sound/diamond.ins sound/sfx-diamond.bin -b