; ===========================================================================
; map.s -- the world map (bank 6)
;
; Japan, drawn from Natural Earth coastline data by tools/mkmap.py.  Pick the
; region the races happen in; more open up as the player levels up.  Rivals
; in later regions have better cars and drive harder, and pay more.
; ===========================================================================

.segment "BSS"
map_max:    .res 1          ; last open region
map_row:    .res 1          ; info panel line being drawn
.segment "BANK6"

map_chr:    .incbin "build/map.chr"
map_nt:     .incbin "build/map_nt.bin"
map_attr:   .incbin "build/map_attr.bin"
.include "build/map.inc"

; BG 0: text on the sea, BG 1: land (shore, fields), BG 2/3 unused.
; Sprites: 0 cursor, 1 markers (red open, grey locked), 2 the arrow.
pal_map:
        .byte $01,$30,$10,$28,  $01,$0F,$1A,$2A,  $01,$30,$10,$28,  $01,$30,$10,$28
        .byte $01,$0F,$16,$21,  $01,$0F,$16,$00,  $01,$16,$27,$30,  $01,$0F,$12,$10

MAP_TX   = 3                    ; region list: names at column 3,
MAP_LVX  = 13                   ; "OPEN" / "LV11" at column 13,
MAP_Y0   = 5                    ; rows 5-11
INFO_X   = 18                   ; info panel: columns 18-31, rows 23-28
INFO_Y   = 23
INFO_W   = 14
T_MARK   = $0E                  ; sprite tiles: open / locked marker
T_LOCK   = $0F
T_ARROW  = $08

; ---------------------------------------------------------------------------
; map_screen: A = 0 a region was picked (in region), 1 = back to the garage
; ---------------------------------------------------------------------------
map_screen:
        jsr region_max
        sta map_max
        cmp map_region              ; a region from an earlier game may be shut
        bcs :+
        sta map_region
:       lda #0
        jsr screen_begin
        MOVI16 ptr0, map_chr
        lda #<$0800
        sta tmp0
        lda #>$0800
        sta tmp1
        lda #BANK_MAP
        sta copy_bank
        lda #$08
        ldx #$00
        jsr chr_copy
        MOVI16 ptr0, map_nt
        lda #<960
        sta tmp0
        lda #>960
        sta tmp1
        lda #BANK_MAP
        sta copy_bank
        lda #$20
        ldx #$00
        jsr chr_copy
        ldx #63
:       lda map_attr,x
        sta attr_shadow,x
        dex
        bpl :-
        MOVI16 ptr0, pal_map
        jsr load_palette
        lda #SONG_MAP           ; the map's own theme ("Road to Tokyo")
        jsr music_play
        ; title, level, the list of regions
        lda #$20
        sta text_attr
        MOVI16 ptr0, str_map_title
        ldx #2
        ldy #2
        jsr print
        lda #0
        sta text_attr
        ldy #0
:       lda str_map_lv,y
        beq :+
        sta linebuf,y
        iny
        bne :-
:       sty tmp7
        lda SV_LEVEL
        sta m_a
        lda #0
        sta m_a+1
        jsr num_text
        ldy tmp7
        jsr cat_ptr0
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        ldx #2
        ldy #3
        jsr print
        lda #0
        sta map_row
@list:  lda map_row
        jsr region_name_ptr
        lda map_row
        clc
        adc #MAP_Y0
        tay
        ldx #MAP_TX
        jsr print
        ldx map_row
        cpx map_max
        bcc @open
        beq @open
        lda #'L'                ; "LV11"
        sta linebuf
        lda #'V'
        sta linebuf+1
        lda region_lv,x
        sta m_a
        lda #0
        sta m_a+1
        jsr num_text
        ldy #2
        jsr cat_ptr0
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        jmp @lv
@open:  MOVI16 ptr0, str_map_open
@lv:    lda map_row
        clc
        adc #MAP_Y0
        tay
        ldx #MAP_LVX
        jsr print
        inc map_row
        lda map_row
        cmp #NREGIONS
        bne @list
        MOVI16 ptr0, str_map_help
        ldx #2
        ldy #13
        jsr print
        jsr attr_upload
        lda #0
        sta oam_idx
        jsr oam_clear
        jsr ppu_on
        lda map_region
        sta ui_sel
        lda #NREGIONS
        sta ui_count
        lda #MAP_TX-1
        sta ui_x
        lda #MAP_Y0
        sta ui_y0
        lda #1
        sta ui_dy
        sta ui_cols
        jsr map_info
@loop:  jsr wait_frame
        jsr read_pad
        jsr list_cursor
        jsr map_marks
        jsr list_select
        cmp #3
        bne :+
        jsr map_info
        jmp @loop
:       cmp #6                  ; left/right step through the list too
        beq @up
        cmp #7
        beq @down
        cmp #2
        beq @back
        cmp #4
        beq @pick
        cmp #1
        bne @loop
@pick:  lda ui_sel
        cmp map_max
        beq @go
        bcc @go
        lda #SFX_ERROR          ; not open yet
        jsr sfx_play
        jmp @loop
@go:    sta map_region
        lda #0
        rts
@back:  lda #1
        rts
@up:    ldx ui_sel
        bne :+
        ldx #NREGIONS
:       dex
        stx ui_sel
        jmp @moved
@down:  ldx ui_sel
        inx
        cpx #NREGIONS
        bcc :+
        ldx #0
:       stx ui_sel
@moved: lda #SFX_MOVE
        jsr sfx_play
        jsr map_info
        jmp @loop

; map_marks: a marker on every city (OAM 1-7), the arrow over the one picked
map_marks:
        ldx #0
        ldy #4
@m:     lda map_mark_y,x
        sec
        sbc #5                  ; sprites draw a line low; centre the 8x8 dot
        sta oam,y
        lda #T_MARK
        cpx map_max
        bcc :+
        beq :+
        lda #T_LOCK
:       sta oam+1,y
        lda #1
        sta oam+2,y
        lda map_mark_x,x
        sec
        sbc #4
        sta oam+3,y
        iny
        iny
        iny
        iny
        inx
        cpx #NREGIONS
        bne @m
        ldx ui_sel              ; the arrow bobs over the selected city
        lda frame
        and #16
        lsr a
        lsr a
        lsr a
        lsr a
        sta tmp7
        lda map_mark_y,x
        sec
        sbc #14
        sbc tmp7
        sta oam,y
        lda #T_ARROW
        sta oam+1,y
        lda #2
        sta oam+2,y
        lda map_mark_x,x
        sec
        sbc #4
        sta oam+3,y
        rts

; map_info: the panel for ui_sel (one line per frame)
map_info:
        lda #0
        sta map_row
@line:  lda map_row
        asl a
        tax
        lda info_lines,x
        sta ptr1
        lda info_lines+1,x
        sta ptr1+1
        jsr @call
        lda map_row
        bne :+
        lda #$20                ; the name in yellow
        sta text_attr
:       lda #INFO_W
        jsr pad_ptr0
        lda map_row
        clc
        adc #INFO_Y
        tay
        ldx #INFO_X
        jsr vb_str
        lda #0
        sta text_attr
        jsr wait_frame
        jsr map_marks
        inc map_row
        lda map_row
        cmp #6
        bne @line
        rts
@call:  jmp (ptr1)

info_lines: .word info_name, info_tag, info_rivals, info_prize, info_boss, info_open

info_name:
        lda ui_sel
        jmp region_name_ptr
info_tag:
        ldx ui_sel
        lda rg_tags_lo,x
        sta ptr0
        lda rg_tags_hi,x
        sta ptr0+1
        rts
info_rivals:
        ldy #0
:       lda str_map_riv,y
        beq :+
        sta linebuf,y
        iny
        bne :-
:       ldx ui_sel              ; one star per region
        inx
        lda #'*'
:       sta linebuf,y
        iny
        dex
        bne :-
        jmp end_line
info_prize:
        MOVI16 ptr0, str_map_prize
        ldy #0
        jsr cat_ptr0
        ldx ui_sel
        lda rg_prize_lo,x
        sta ptr0
        lda rg_prize_hi,x
        sta ptr0+1
        jsr cat_ptr0
        jmp end_line
info_boss:
        MOVI16 ptr0, str_map_boss
        ldy #0
        jsr cat_ptr0
        ldx ui_sel
        lda rg_boss_lo,x
        sta ptr0
        lda rg_boss_hi,x
        sta ptr0+1
        jsr cat_ptr0
        jmp end_line
info_open:
        lda ui_sel
        cmp map_max
        beq :+
        bcs @shut
:       MOVI16 ptr0, str_map_go
        rts
@shut:  MOVI16 ptr0, str_map_reach
        ldy #0
        jsr cat_ptr0
        sty tmp7
        ldx ui_sel
        lda region_lv,x
        sta m_a
        lda #0
        sta m_a+1
        jsr num_text
        ldy tmp7
        jsr cat_ptr0
end_line:
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        rts

str_map_title:  .byte "JAPAN", 0
str_map_lv:     .byte "YOUR LEVEL ", 0
str_map_open:   .byte "OPEN", 0
str_map_help:   .byte "A:RACE  B:BACK", 0
str_map_riv:    .byte "RIVALS ", 0
str_map_prize:  .byte "PRIZES ", 0
str_map_boss:   .byte "BOSSES ", 0
str_map_go:     .byte "A: RACE HERE", 0
str_map_reach:  .byte "REACH LEVEL ", 0

rg_tags_lo: .byte <rgt0, <rgt1, <rgt2, <rgt3, <rgt4, <rgt5, <rgt6
rg_tags_hi: .byte >rgt0, >rgt1, >rgt2, >rgt3, >rgt4, >rgt5, >rgt6
rgt0:       .byte "HARBOR DRAGS", 0
rgt1:       .byte "RIVERSIDE RUNS", 0
rgt2:       .byte "THE LOOP LINE", 0
rgt3:       .byte "FACTORY ROADS", 0
rgt4:       .byte "MOUNTAIN PASS", 0
rgt5:       .byte "SNOW HIGHWAYS", 0
rgt6:       .byte "BAYSHORE ROUTE", 0
rg_prize_lo: .byte <rgp0, <rgp1, <rgp2, <rgp3, <rgp4, <rgp5, <rgp6
rg_prize_hi: .byte >rgp0, >rgp1, >rgp2, >rgp3, >rgp4, >rgp5, >rgp6
rgp0:       .byte "X1", 0
rgp1:       .byte "X1.5", 0
rgp2:       .byte "X2", 0
rgp3:       .byte "X2.5", 0
rgp4:       .byte "X3", 0
rgp5:       .byte "X3.5", 0
rgp6:       .byte "X4", 0
rg_boss_lo: .byte <rgb0, <rgb1, <rgb2, <rgb3, <rgb4, <rgb5, <rgb6
rg_boss_hi: .byte >rgb0, >rgb1, >rgb2, >rgb3, >rgb4, >rgb5, >rgb6
rgb0:       .byte "1-2", 0
rgb1:       .byte "3-4", 0
rgb2:       .byte "5-6", 0
rgb3:       .byte "7", 0
rgb4:       .byte "8", 0
rgb5:       .byte "9", 0
rgb6:       .byte "10-11", 0
