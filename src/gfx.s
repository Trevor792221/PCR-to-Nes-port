; ===========================================================================
; gfx.s -- tile data and background maps (bank 0).  Built by tools/mkchr.py.
; ===========================================================================
gfx_common:     .incbin "build/common.chr"
gfx_menu:       .incbin "build/menu.chr"
gfx_sprites:    .incbin "build/sprites.chr"
gfx_cars:       .incbin "build/cars.chr"
gfx_bigcars:    .incbin "build/bigcars.chr"
gfx_logo_map:   .incbin "build/logo_map.bin"
gfx_garage_map: .incbin "build/garage_map.bin"
gfx_garage_night_map: .incbin "build/garage_night_map.bin"
