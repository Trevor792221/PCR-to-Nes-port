; ===========================================================================
; ppu.s -- screen, text, sprite and CHR helpers (fixed bank)
; ===========================================================================

.segment "BSS"
attr_shadow: .res 64
vb_tmp:     .res 1
ar_p:       .res 1
ar_cx:      .res 1
ar_cy:      .res 1
ar_w:       .res 1
ar_h:       .res 1

.segment "FIXED"

; ---------------------------------------------------------------------------
; ppu_off: blank the screen at the next vblank and stop NMIs, so the main
; thread may write to the PPU directly.  ppu_on: turn it back on.
; ---------------------------------------------------------------------------
ppu_off:
        jsr wait_frame
        lda #0
        sta PPUMASK
        sta PPUCTRL
        sta ppu_mask
        rts

ppu_on:
        lda #0
        sta scroll_x
        sta scroll_y
        sta scroll_nt
        lda #$1E
        sta ppu_mask
        bit PPUSTATUS
@vb:    bit PPUSTATUS           ; enable NMI at the start of a vblank
        bpl @vb
        lda ppu_ctrl
        sta PPUCTRL
        jmp wait_frame

; vram_addr: set PPU address to A (hi) / X (lo)
vram_addr:
        bit PPUSTATUS
        sta PPUADDR
        stx PPUADDR
        rts

; clear_nt: clear both nametables (and their attributes) to tile 0
clear_nt:
        lda ppu_ctrl
        and #$7B                ; +1 increment, NMI stays off
        sta PPUCTRL
        lda #$20
        ldx #$00
        jsr vram_addr
        lda #0
        ldy #8
        ldx #0
@l:     sta PPUDATA
        inx
        bne @l
        dey
        bne @l
        ldx #63
@a:     sta attr_shadow,x
        dex
        bpl @a
        rts

; fill_row: tile A across row Y (cols X..X+tmp2-1) of nametable 0, PPU off
fill_row:
        pha
        jsr nt_addr
        lda ptr3+1
        ldx ptr3
        jsr vram_addr
        pla
        ldx tmp2
@l:     sta PPUDATA
        dex
        bne @l
        rts

; nt_addr: ptr3 = $2000 + Y*32 + X
nt_addr:
        tya
        lsr a
        lsr a
        lsr a
        ora #$20
        sta ptr3+1
        tya
        asl a
        asl a
        asl a
        asl a
        asl a
        sta ptr3
        txa
        clc
        adc ptr3
        sta ptr3
        rts

; ---------------------------------------------------------------------------
; Text.  Strings are zero terminated ASCII.  text_attr = $20 prints letters
; in the colour-3 font.
; print: ptr0 = string, X = column, Y = row.  PPU must be off.
; ---------------------------------------------------------------------------
print:
        jsr nt_addr
        lda ptr3+1
        ldx ptr3
        jsr vram_addr
        ldy #0
@l:     lda (ptr0),y
        beq @done
        jsr hi_char
        sta PPUDATA
        iny
        bne @l
@done:  rts

hi_char:
        ldx text_attr
        beq @r
        cmp #$40
        bcc @r
        cmp #$60
        bcs @r
        adc #$20
@r:     rts

; print_num: print numbuf from index X to the end at (tmp4 col, tmp5 row)
print_numbuf:
        txa
        clc
        adc #<numbuf
        sta ptr0
        lda #>numbuf
        adc #0
        sta ptr0+1
        ldx tmp4
        ldy tmp5
        jmp print

; ---------------------------------------------------------------------------
; VRAM queue (used while rendering).  vb_open: A = count, ptr3 = PPU address
; -> X = write index in vbuf.  Call vb_close with X after the data.
; ---------------------------------------------------------------------------
vb_open:
        ldx vbuf_len
        pha
        lda ptr3+1
        sta vbuf,x
        lda ptr3
        sta vbuf+1,x
        pla
        sta vbuf+2,x
        inx
        inx
        inx
        rts
vb_close:
        stx vbuf_len
        lda #0
        sta vbuf,x
        rts

; vb_str: queue string ptr0 at column X row Y (nametable 0)
vb_str:
        jsr nt_addr
        ldy #0
@len:   lda (ptr0),y
        beq @got
        iny
        bne @len
@got:   tya
        beq @none
        jsr vb_open
        ldy #0
@c:     lda (ptr0),y
        beq @end
        stx vb_tmp
        jsr hi_char
        ldx vb_tmp
        sta vbuf,x
        inx
        iny
        bne @c
@end:   jmp vb_close
@none:  rts

; vb_fill: queue tile A x tmp2 at column X row Y
vb_fill:
        pha
        jsr nt_addr
        lda tmp2
        jsr vb_open
        pla
        ldy tmp2
@l:     sta vbuf,x
        inx
        dey
        bne @l
        jmp vb_close

; vb_numbuf: queue numbuf (all 8 chars) at col X row Y, last tmp2 chars only
vb_numbuf:
        jsr nt_addr
        lda tmp2
        jsr vb_open
        lda #8
        sec
        sbc tmp2
        tay
@l:     lda numbuf,y
        sta vbuf,x
        inx
        iny
        cpy #8
        bne @l
        jmp vb_close

; ---------------------------------------------------------------------------
; Attributes.  set_attr: palette A for the 16x16 block at block coords
; (X = 0..15, Y = 0..14) in attr_shadow (uses tmp4-tmp6).
; attr_rect: tmp0=x tmp1=y tmp2=w tmp3=h (blocks), A = palette.
; attr_upload: write the shadow to nametable 0 (PPU off).
; ---------------------------------------------------------------------------
set_attr:
        and #3
        sta tmp6
        ; byte index = (y/2)*8 + x/2
        tya
        lsr a
        asl a
        asl a
        asl a
        sta tmp5
        txa
        lsr a
        ora tmp5
        sta tmp5
        ; shift = (y&1)*4 + (x&1)*2
        tya
        and #1
        asl a
        sta tmp4
        txa
        and #1
        ora tmp4
        asl a
        tay                     ; shift amount 0,2,4,6
        lda #$03
        sta tmp4
        lda tmp6
@sh:    cpy #0
        beq @go
        asl a
        asl tmp4
        asl tmp4
        asl a
        dey
        dey
        jmp @sh
@go:    sta tmp6
        lda tmp4
        eor #$FF
        ldx tmp5
        and attr_shadow,x
        ora tmp6
        sta attr_shadow,x
        rts

attr_rect:
        sta ar_p
        lda tmp1
        sta ar_cy
        lda tmp3
        sta ar_h
@row:   lda tmp0
        sta ar_cx
        lda tmp2
        sta ar_w
@col:   ldx ar_cx
        ldy ar_cy
        lda ar_p
        jsr set_attr
        inc ar_cx
        dec ar_w
        bne @col
        inc ar_cy
        dec ar_h
        bne @row
        rts

attr_upload:
        lda #$23
        ldx #$C0
        jsr vram_addr
        ldx #0
@l:     lda attr_shadow,x
        sta PPUDATA
        inx
        cpx #64
        bne @l
        rts

; ---------------------------------------------------------------------------
; Palette: load_palette copies 32 bytes from ptr0.
; ---------------------------------------------------------------------------
load_palette:
        ldy #31
@l:     lda (ptr0),y
        sta palette,y
        dey
        bpl @l
        lda #1
        sta pal_dirty
        rts

; ---------------------------------------------------------------------------
; Sprites
; ---------------------------------------------------------------------------
; oam_clear: hide sprites from oam_idx onward
oam_clear:
        ldx oam_idx
        lda #$F8
@l:     sta oam,x
        inx
        inx
        inx
        inx
        bne @l
        rts

; spr_add: one sprite from sp_x/sp_y/sp_tile/sp_attr
spr_add:
        ldx oam_idx
        beq @full
        lda sp_y
        sta oam,x
        lda sp_tile
        sta oam+1,x
        lda sp_attr
        sta oam+2,x
        lda sp_x
        sta oam+3,x
        inx
        inx
        inx
        inx
        stx oam_idx
@full:  rts

; draw_car: 32x16 car.  sp_x, sp_y = top-left; sp_tile = first tile;
; sp_attr = palette for the top row (bottom row uses sp_attr+tmp0);
; tmp1 = wheel frame (0/1).  Sprites off the left/right edge are clipped.
draw_car:
        lda sp_x
        sta tmp2                ; left x
        lda sp_tile
        sta tmp3
        ; top row
        ldy #0
@top:   jsr @one
        iny
        cpy #4
        bne @top
        ; bottom row
        lda sp_y
        clc
        adc #8
        sta sp_y
        lda sp_attr
        clc
        adc tmp0
        sta sp_attr
        lda tmp1
        beq @fa
        lda tmp3
        clc
        adc #4
        sta tmp3
@fa:    ldy #4
@bot:   jsr @one
        iny
        cpy #8
        bne @bot
        ; restore
        lda sp_y
        sec
        sbc #8
        sta sp_y
        lda sp_attr
        sec
        sbc tmp0
        sta sp_attr
        lda tmp2
        sta sp_x
        rts
@one:   tya
        and #3
        asl a
        asl a
        asl a
        clc
        adc tmp2
        bcs @skip               ; wrapped past the right edge
        sta sp_x
        tya
        clc
        adc tmp3
        sta sp_tile
        sty tmp5
        jsr spr_add
        ldy tmp5
@skip:  rts

; draw_big_car: 64x32 car from tiles sp_tile..+31 (8 per row).
; Top two rows use sp_attr, bottom two sp_attr+1.
draw_big_car:
        lda sp_x
        sta tmp2
        lda sp_y
        sta tmp3
        lda sp_tile
        sta tmp4
        lda sp_attr
        sta tmp6
        ldy #0
@l:     tya
        and #7
        asl a
        asl a
        asl a
        clc
        adc tmp2
        sta sp_x
        tya
        and #$18                ; row * 8
        clc
        adc tmp3
        sta sp_y
        tya
        clc
        adc tmp4
        sta sp_tile
        lda tmp6
        cpy #16
        bcc :+
        adc #0                  ; carry set: +1 palette for the lower half
:       sta sp_attr
        sty tmp7
        jsr spr_add
        ldy tmp7
        iny
        cpy #32
        bne @l
        lda tmp2
        sta sp_x
        lda tmp3
        sta sp_y
        lda tmp6
        sta sp_attr
        rts

; ---------------------------------------------------------------------------
; CHR loading (PPU off).  chr_copy: tmp0/tmp1 = byte count, ptr0 = source
; in bank copy_bank (normally BANK_GFX = 0; reset to 0 afterwards),
; A/X = PPU address hi/lo.
; ---------------------------------------------------------------------------
chr_copy:
        jsr vram_addr
        lda cur_bank
        pha
        lda copy_bank
        jsr set_bank
        ldy #0
@l:     lda (ptr0),y
        sta PPUDATA
        iny
        bne :+
        inc ptr0+1
:       lda tmp0
        bne :+
        dec tmp1
:       dec tmp0
        lda tmp0
        ora tmp1
        bne @l
        lda #BANK_GFX
        sta copy_bank
        pla
        jmp set_bank

.macro CHR_LOAD src, dst, len
        MOVI16 ptr0, src
        lda #<(len)
        sta tmp0
        lda #>(len)
        sta tmp1
        lda #>(dst)
        ldx #<(dst)
        jsr chr_copy
.endmacro

load_common_chr:
        CHR_LOAD gfx_common, $0000, $0800
        CHR_LOAD gfx_sprites, $1000, $0400
        rts

; load_race_chr: BG tiles $80-$FF for race_scene
load_race_chr:
        ldx race_scene
        lda scene_chr_lo,x
        sta ptr0
        lda scene_chr_hi,x
        sta ptr0+1
        lda scene_len_lo,x
        sta tmp0
        lda scene_len_hi,x
        sta tmp1
        lda scene_bank,x
        sta copy_bank
        lda #$08
        ldx #$00
        jmp chr_copy

; scenes 0-2: day, sunset, night (bank 4); 3-5: the same, overcast (bank 5)
scene_chr_lo: .byte <scene_chr0, <scene_chr1, <scene_chr2, <scene_chr3, <scene_chr4, <scene_chr5
scene_chr_hi: .byte >scene_chr0, >scene_chr1, >scene_chr2, >scene_chr3, >scene_chr4, >scene_chr5
scene_map_lo: .byte <scene_map0, <scene_map1, <scene_map2, <scene_map3, <scene_map4, <scene_map5
scene_map_hi: .byte >scene_map0, >scene_map1, >scene_map2, >scene_map3, >scene_map4, >scene_map5
scene_bank:   .byte BANK_SCENE, BANK_SCENE, BANK_SCENE, BANK_PW, BANK_PW, BANK_PW
SCENE_LEN3 = scene_chr4 - scene_chr3
SCENE_LEN4 = scene_chr5 - scene_chr4
SCENE_LEN5 = scene_chr_end - scene_chr5
scene_len_lo: .byte 0, 0, 0, <SCENE_LEN3, <SCENE_LEN4, <SCENE_LEN5
scene_len_hi: .byte 8, 8, 8, >SCENE_LEN3, >SCENE_LEN4, >SCENE_LEN5

load_menu_chr:
        CHR_LOAD gfx_menu, $0800, $0800
        rts

; load_car_chr: shape A -> 12 sprite tiles at tile X (PPU off)
load_car_chr:
        stx tmp2
        sta m_a
        lda #192
        sta m_b
        jsr mul8
        clc
        lda m_r
        adc #<gfx_cars
        sta ptr0
        lda m_r+1
        adc #>gfx_cars
        sta ptr0+1
        lda tmp2
        jsr tile_addr_spr
        lda #192
        sta tmp0
        lda #0
        sta tmp1
        lda ptr3+1
        ldx ptr3
        jmp chr_copy

; tile_addr_spr: ptr3 = $1000 + A*16
tile_addr_spr:
        sta ptr3
        lda #0
        sta ptr3+1
        ldx #4
@s:     asl ptr3
        rol ptr3+1
        dex
        bne @s
        lda ptr3+1
        ora #$10
        sta ptr3+1
        rts

; big_car_stream: copy the 2x tiles of shape A into WBUF and stream them to
; sprite tile X (32 tiles) through the NMI over 16 frames.
big_car_stream:
        stx tmp2
        asl a                   ; shape*512: high byte shape*2, low byte 0
        clc
        adc #>gfx_bigcars
        sta ptr0+1
        lda #<gfx_bigcars
        sta ptr0
        MOVI16 ptr1, WBUF
        lda cur_bank
        pha
        lda #BANK_GFX
        jsr set_bank
        ldx #2
        ldy #0
@c:     lda (ptr0),y
        sta (ptr1),y
        iny
        bne @c
        inc ptr0+1
        inc ptr1+1
        dex
        bne @c
        pla
        jsr set_bank
        lda tmp2
        jsr tile_addr_spr
        lda #0
        sta chr_cnt             ; stop any stream while we set it up
        MOVI16 chr_src, WBUF
        lda ptr3
        sta chr_dst
        lda ptr3+1
        sta chr_dst+1
        lda #16
        sta chr_cnt
        rts

; big_car_direct: like big_car_stream but writes straight away (PPU off)
big_car_direct:
        jsr big_car_stream
        lda #0
        sta chr_cnt
        lda chr_dst+1
        ldx chr_dst
        jsr vram_addr
        MOVI16 ptr0, WBUF
        ldx #2
        ldy #0
@l:     lda (ptr0),y
        sta PPUDATA
        iny
        bne @l
        inc ptr0+1
        dex
        bne @l
        rts

; ---------------------------------------------------------------------------
; Screen setup helper: PPU off, clear, load common + one BG set.
; A = 0 menu set, 1 race set.
; ---------------------------------------------------------------------------
screen_begin:
        pha
        jsr ppu_off
        jsr clear_nt
        lda #0
        sta oam_idx
        jsr oam_clear
        pla
        bne @race
        jmp load_menu_chr
@race:  jmp load_race_chr

; bank0_copy: copy tmp0/tmp1 bytes from ptr0 (bank copy_bank, normally
; BANK_GFX; reset afterwards) to ptr1 (RAM/WRAM)
bank0_copy:
        lda cur_bank
        pha
        lda copy_bank
        jsr set_bank
        ldy #0
@l:     lda (ptr0),y
        sta (ptr1),y
        iny
        bne :+
        inc ptr0+1
        inc ptr1+1
:       lda tmp0
        bne :+
        dec tmp1
:       dec tmp0
        lda tmp0
        ora tmp1
        bne @l
        lda #BANK_GFX
        sta copy_bank
        pla
        jmp set_bank

; ---------------------------------------------------------------------------
; draw_garage_bg: garage backdrop on nametable rows 4-12 with its palettes
; (ceiling and lamps, brick walls, roll-up door, pegboard, tyres, tool
; chest, floor).  PPU off.  Used by the garage, dealer and paint shop.
; ---------------------------------------------------------------------------
draw_garage_bg:
        MOVI16 ptr0, gfx_garage_map
        lda garage_look
        beq @day
        ldy #0                  ; night or sunset colours for BG palettes 1-3
        MOVI16 ptr0, gfx_garage_night_map
        lda garage_look
        cmp #GL_SUNSET
        bne :+
        ldy #12
        MOVI16 ptr0, gfx_garage_sunset_map
:       ldx #0
@np:    lda pal_garage_night,y
        sta palette+4,x
        iny
        inx
        cpx #12
        bne @np
        lda #1
        sta pal_dirty
@day:       lda #<288
        sta tmp0
        lda #>288
        sta tmp1
        lda #$20
        ldx #$80                ; row 4
        jsr chr_copy
        lda #0
        sta gb_i                ; table index
        lda #2                  ; block rows 2-6
        sta gb_y
@row:   lda #0
        sta gb_x
@col:   ldx gb_i
        lda garage_attr,x
        ldy garage_look         ; (night and sunset: the same blocks)
        beq :+
        lda garage_night_attr,x
:
        ldx gb_x
        ldy gb_y
        jsr set_attr            ; (uses tmp4-tmp6)
        inc gb_i
        inc gb_x
        lda gb_x
        cmp #16
        bne @col
        inc gb_y
        lda gb_y
        cmp #7
        bne @row
        rts

.segment "BSS"
gb_x:       .res 1
gb_y:       .res 1
gb_i:       .res 1
.segment "FIXED"

garage_attr: .incbin "build/garage_attr.bin"
garage_night_attr: .incbin "build/garage_night_attr.bin"
; night: 1 = sky through the open door (black, navy skyline, lit windows,
; pale moon and stars), 2 = tool chest in shadow, 3 = walls and floor in
; dark blues
pal_garage_night:
        .byte $0F,$01,$28,$38,  $0F,$0F,$06,$16,  $0F,$01,$02,$0C
; sunset (follows night): 1 = sky through the open door (purple high up,
; red lower down, the sun and the glow on the horizon pale gold, the
; skyline black), 2 = tool chest, 3 = walls and floor in warm light
pal_garage_sunset:
        .byte $0F,$04,$16,$38,  $0F,$0F,$16,$27,  $0F,$07,$17,$27
