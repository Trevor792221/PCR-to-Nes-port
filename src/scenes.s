; ===========================================================================
; scenes.s -- race background themes (bank 4).  Built by tools/mkchr.py.
; Each theme: BG tiles $80-$FF (road tiles first, at the same numbers in
; every theme, then that theme's skyline) and nametable rows 6-29.
; ===========================================================================
scene_chr0:     .incbin "build/race0.chr"       ; day
scene_chr1:     .incbin "build/race1.chr"       ; sunset
scene_chr2:     .incbin "build/race2.chr"       ; night
scene_map0:     .incbin "build/race_map0.bin"
scene_map1:     .incbin "build/race_map1.bin"
scene_map2:     .incbin "build/race_map2.bin"
