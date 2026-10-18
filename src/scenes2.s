; ===========================================================================
; scenes2.s -- overcast race backgrounds (bank 5): the day, sunset and night
; scenes under a low cloud bank, for cloudy, rainy and snowy races.  Built by
; tools/mkchr.py; only the tiles each scene uses are stored.
; ===========================================================================
scene_chr3:     .incbin "build/race3.chr"       ; day, overcast
scene_chr4:     .incbin "build/race4.chr"       ; sunset, overcast
scene_chr5:     .incbin "build/race5.chr"       ; night, overcast
scene_chr_end:
scene_map3:     .incbin "build/race_map3.bin"
scene_map4:     .incbin "build/race_map4.bin"
scene_map5:     .incbin "build/race_map5.bin"
