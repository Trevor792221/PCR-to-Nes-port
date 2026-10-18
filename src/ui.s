; ===========================================================================
; ui.s -- shared menu helpers (fixed bank)
; ===========================================================================

.segment "BSS"
ui_sel:     .res 1
ui_count:   .res 1
ui_x:       .res 1          ; cursor column
ui_y0:      .res 1          ; first item row
ui_dy:      .res 1          ; rows per item
ui_cols:    .res 1          ; 1 or 2 columns
ui_x2:      .res 1          ; second column x
ui_anim:    .res 1

.segment "FIXED"

.macro PRINT str, col, row
        MOVI16 ptr0, str
        ldx #col
        ldy #row
        jsr print
.endmacro

.macro VBSTR str, col, row
        MOVI16 ptr0, str
        ldx #col
        ldy #row
        jsr vb_str
.endmacro

; ---------------------------------------------------------------------------
; Palettes
; ---------------------------------------------------------------------------
pal_menu:
        .byte $0F,$30,$10,$28,  $0F,$28,$18,$27,  $0F,$06,$16,$27,  $0F,$00,$10,$2D
        .byte $0F,$0F,$16,$21,  $0F,$0F,$16,$10,  $0F,$16,$27,$30,  $0F,$0F,$12,$10
pal_race:
        .byte $0F,$30,$2A,$00,  $0F,$30,$16,$28,  $0F,$01,$12,$38,  $0F,$2D,$10,$30
        .byte $0F,$0F,$16,$21,  $0F,$0F,$16,$10,  $0F,$0F,$12,$10,  $0F,$0F,$10,$21

use_menu_palette:
        MOVI16 ptr0, pal_menu
        jmp load_palette

; set_car_palette: ptr1 = car record -> sprite palettes 0 (body+glass) and
; 1 (body+rims) use its colours
set_car_palette:
        ldy #CR_PAINT
        lda (ptr1),y
        sta palette+$12
        sta palette+$16
        iny
        lda (ptr1),y
        sta palette+$17
        iny
        lda (ptr1),y
        sta palette+$13
        lda #1
        sta pal_dirty
        rts

; ---------------------------------------------------------------------------
; draw_box: tmp0 = x, tmp1 = y, tmp2 = w, tmp3 = h (tiles, inclusive frame)
; ---------------------------------------------------------------------------
draw_box:
        lda tmp2
        sec
        sbc #2
        sta tmp4                ; inner width
        ; top
        ldx tmp0
        ldy tmp1
        jsr nt_addr
        lda ptr3+1
        ldx ptr3
        jsr vram_addr
        lda #$04
        sta PPUDATA
        ldx tmp4
        lda #$05
:       sta PPUDATA
        dex
        bne :-
        lda #$06
        sta PPUDATA
        ; sides
        lda tmp3
        sec
        sbc #2
        sta tmp5
        ldy tmp1
@side:  iny
        sty tmp6
        ldx tmp0
        jsr nt_addr
        lda ptr3+1
        ldx ptr3
        jsr vram_addr
        lda #$07
        sta PPUDATA
        lda tmp2
        sec
        sbc #1
        clc
        adc ptr3
        tax
        lda ptr3+1
        adc #0
        jsr vram_addr
        lda #$08
        sta PPUDATA
        ldy tmp6
        dec tmp5
        bne @side
        ; bottom
        iny
        ldx tmp0
        jsr nt_addr
        lda ptr3+1
        ldx ptr3
        jsr vram_addr
        lda #$09
        sta PPUDATA
        ldx tmp4
        lda #$0A
:       sta PPUDATA
        dex
        bne :-
        lda #$0B
        sta PPUDATA
        rts

.macro BOX bx, by, bw, bh
        lda #bx
        sta tmp0
        lda #by
        sta tmp1
        lda #bw
        sta tmp2
        lda #bh
        sta tmp3
        jsr draw_box
.endmacro

; ---------------------------------------------------------------------------
; Money / numbers
; ---------------------------------------------------------------------------
; cash_text: SV_CASH -> numbuf as "$" + digits, left aligned; ptr0 -> text
cash_text:
        lda SV_CASH
        sta m_a
        lda SV_CASH+1
        sta m_a+1
        lda SV_CASH+2
        sta m_a+2
; money_text: m_a(24) -> ptr0 = "$1234" (left aligned, zero terminated)
money_text:
        jsr fmt_u24
        txa
        beq num_ptr             ; 8 digits: no room for "$" (cash is capped below this)
        dex
        lda #'$'
        sta numbuf,x
        txa
        clc
        adc #<numbuf
        sta ptr0
        lda #>numbuf
        adc #0
        sta ptr0+1
        rts

; num_text: m_a(16) -> ptr0 = digits, left aligned
num_text:
        jsr fmt_u16
num_ptr:
        txa
        clc
        adc #<numbuf
        sta ptr0
        lda #>numbuf
        adc #0
        sta ptr0+1
        rts

; ---------------------------------------------------------------------------
; Header: "TITLE" on row 1, cash and gems on row 2 (PPU off).
; ptr0 = title.
; ---------------------------------------------------------------------------
draw_header:
        lda #$20
        sta text_attr
        ldx #2
        ldy #1
        jsr print
        lda #0
        sta text_attr
        jsr cash_text
        ldx #18
        ldy #1
        jsr print
        PRINT str_gems, 2, 2
        lda SV_GEMS
        sta m_a
        lda SV_GEMS+1
        sta m_a+1
        jsr num_text
        ldx #8
        ldy #2
        jsr print
        PRINT str_lv, 18, 2
        lda SV_LEVEL
        jsr fmt_8
        jsr num_ptr
        ldx #21
        ldy #2
        jsr print
        ; rule under the header
        lda #31
        sta tmp2
        ldx #1
        ldy #3
        lda #$1E
        jmp fill_row

; header_update: refresh the cash / gems figures through the VRAM queue
header_update:
        jsr cash_text
        jsr pad_ptr0_10
        ldx #18
        ldy #1
        jsr vb_str
        lda SV_GEMS
        sta m_a
        lda SV_GEMS+1
        sta m_a+1
        jsr num_text
        jsr pad_ptr0_10
        ldx #8
        ldy #2
        jsr vb_str
        rts

; pad_ptr0_10: copy the text at ptr0 to padbuf, padded with spaces to 10
; characters; ptr0 -> padbuf
pad_ptr0_10:
        lda #10
pad_ptr0:
        sta tmp3
        ldy #0
@c:     lda (ptr0),y
        beq @sp
        sta padbuf,y
        iny
        cpy tmp3
        bne @c
        beq @end
@sp:    lda #' '
@s:     sta padbuf,y
        iny
        cpy tmp3
        bne @s
@end:   lda #0
        sta padbuf,y
        MOVI16 ptr0, padbuf
        rts

.segment "BSS"
padbuf:     .res 33
.segment "FIXED"

; paint colours offered in the paint shop (and for rivals)
NPAINTS = 24
paint_list:
        .byte $16, $06, $26, $27, $17, $28, $38, $2A, $1A, $0A, $2C, $1C
        .byte $21, $11, $12, $02, $13, $14, $24, $07, $00, $10, $30, $2D

; ---------------------------------------------------------------------------
; World map regions (see map.s).  Each one opens at a level; rivals there
; are tougher and pay more.
; ---------------------------------------------------------------------------
region_lv:  .byte 1, 2, 4, 6, 8, 11, 14         ; level that opens each region

; has_wheelie: ptr1 = car record -> Z clear (A = 1) if it has wheelie bars
T_WBAR  = $28                   ; sprite tile: wheelie bars (races)
has_wheelie:
        ldy #CR_PARTS+P_WHEELIE
        lda (ptr1),y
        beq @no
        lda #1
@no:    rts

; region_max: A = the last region open at the player's level
region_max:
        ldx #NREGIONS-1
@l:     lda SV_LEVEL
        cmp region_lv,x
        bcs @d
        dex
        bne @l
@d:     txa
        rts

; region_name_ptr: A = region -> ptr0 = its name
region_name_ptr:
        asl a
        tax
        lda region_names,x
        sta ptr0
        lda region_names+1,x
        sta ptr0+1
        rts

region_names:
        .word str_rg0, str_rg1, str_rg2, str_rg3, str_rg4, str_rg5, str_rg6
str_rg0:    .byte "FUKUOKA", 0
str_rg1:    .byte "HIROSHIMA", 0
str_rg2:    .byte "OSAKA", 0
str_rg3:    .byte "NAGOYA", 0
str_rg4:    .byte "GUNMA", 0
str_rg5:    .byte "SAPPORO", 0
str_rg6:    .byte "TOKYO", 0

str_gems:   .byte "GEMS", 0
str_lv:     .byte "LV", 0

; ---------------------------------------------------------------------------
; Cursor sprite (OAM slot 0 in menus).  ui_cursor: X = column, Y = row
; ---------------------------------------------------------------------------
ui_cursor:
        txa
        asl a
        asl a
        asl a
        sta oam+3
        tya
        asl a
        asl a
        asl a
        sec
        sbc #1
        sta oam
        lda #$01
        sta oam+1
        lda #$02
        sta oam+2
        rts

ui_cursor_hide:
        lda #$F8
        sta oam
        rts

; ---------------------------------------------------------------------------
; list_select: ui_sel / ui_count / ui_x / ui_y0 / ui_dy / ui_cols.
; One frame of list navigation.  Returns:
;   A = 0 nothing, 1 = A pressed, 2 = B pressed, 3 = moved, 4 = START,
;   5 = SELECT, 6 = left, 7 = right (single column lists only)
; ---------------------------------------------------------------------------
list_select:
        lda pad_rpt
        and #BTN_UP
        beq @nu
        lda ui_cols
        cmp #2
        bne :+
        lda ui_sel
        sec
        sbc #2
        jcs @set
        adc ui_count
        jcs @set                ; (always)
:       ldx ui_sel
        bne :+
        ldx ui_count
:       dex
        txa
        jmp @set
@nu:    lda pad_rpt
        and #BTN_DOWN
        beq @nd
        lda ui_sel
        clc
        adc ui_cols
        cmp ui_count
        bcc @set
        sbc ui_count
        jmp @set
@nd:    lda ui_cols
        cmp #2
        bne @lr1
        lda pad_rpt
        and #BTN_LEFT|BTN_RIGHT
        beq @btn
        lda ui_sel
        eor #1
        cmp ui_count
        bcs @btn
        jmp @set
@lr1:   lda pad_rpt
        and #BTN_LEFT
        beq :+
        lda #6
        rts
:       lda pad_rpt
        and #BTN_RIGHT
        beq @btn
        lda #7
        rts
@btn:   lda pad_new
        and #BTN_A
        beq :+
        lda #SFX_SELECT
        jsr sfx_play
        lda #1
        rts
:       lda pad_new
        and #BTN_B
        beq :+
        lda #SFX_BACK
        jsr sfx_play
        lda #2
        rts
:       lda pad_new
        and #BTN_START
        beq :+
        lda #4
        rts
:       lda pad_new
        and #BTN_SELECT
        beq :+
        lda #5
        rts
:       lda #0
        rts
@set:   sta ui_sel
        lda #SFX_MOVE
        jsr sfx_play
        lda #3
        rts

; list_cursor: place the cursor sprite for ui_sel
list_cursor:
        lda ui_sel
        ldx ui_cols
        cpx #2
        bne @one
        lsr a
        pha
        lda ui_sel
        and #1
        beq :+
        ldx ui_x2
        bne @gotx
:       ldx ui_x
@gotx:  pla
        jmp @row
@one:   ldx ui_x
@row:   sta m_a
        lda ui_dy
        sta m_b
        stx tmp7
        jsr mul8
        lda m_r
        clc
        adc ui_y0
        tay
        ldx tmp7
        jmp ui_cursor

; ---------------------------------------------------------------------------
; Message line (row Y, 30 chars from column 1) through the VRAM queue
; ---------------------------------------------------------------------------
vb_msg:
        sty tmp7
        lda #30
        jsr pad_ptr0
        ldx #1
        ldy tmp7
        jmp vb_str

; wait_ab: wait for A or B.  Carry clear = A, set = B.
wait_ab:
        jsr wait_frame
        jsr read_pad
        lda pad_new
        and #BTN_A|BTN_START
        bne @a
        lda pad_new
        and #BTN_B
        beq wait_ab
        sec
        rts
@a:     clc
        rts

; confirm: show ptr0 on row Y with " A:YES B:NO", carry clear = yes
confirm:
        sty tmp7
        lda tmp7
        pha
        jsr vb_msg
        pla
        tay
        VBSTR str_yesno, 20, 0
        jsr wait_frame
        jsr wait_ab
        rts

str_yesno:  .byte "A:YES B:NO", 0

; ---------------------------------------------------------------------------
; Rewards: add_xp: m_a(16) xp.  Returns carry set on level up.
; xp needed = 100 + 40 * level
; ---------------------------------------------------------------------------
add_xp:
        clc
        lda SV_XP
        adc m_a
        sta SV_XP
        lda SV_XP+1
        adc m_a+1
        sta SV_XP+1
        lda #0
        sta tmp3                ; level-up flag
@chk:   jsr xp_needed
        lda SV_XP
        cmp m_r
        lda SV_XP+1
        sbc m_r+1
        bcc @done
        lda SV_LEVEL
        cmp #99
        bcs @done
        sec
        lda SV_XP
        sbc m_r
        sta SV_XP
        lda SV_XP+1
        sbc m_r+1
        sta SV_XP+1
        inc SV_LEVEL
        ; level up gems: 2 + level/4
        lda SV_LEVEL
        lsr a
        lsr a
        clc
        adc #2
        adc SV_GEMS
        sta SV_GEMS
        bcc :+
        inc SV_GEMS+1
:       lda #1
        sta tmp3
        jmp @chk
@done:  lda tmp3
        cmp #1
        rts

; xp_needed: m_r(16) = 100 + 40*level
xp_needed:
        lda SV_LEVEL
        sta m_a
        lda #40
        sta m_b
        jsr mul8
        clc
        lda m_r
        adc #100
        sta m_r
        bcc :+
        inc m_r+1
:       rts

; ---------------------------------------------------------------------------
; Car stats for the menus: car_stats: ptr1 = record -> phys slot 1 set up,
; m_a = peak hp.  (Uses physics slot 1; harmless outside races.)
; ---------------------------------------------------------------------------
; car_setup: the same without the peak HP measurement (a few frames' work),
; for screens that only need the gearing
.segment "BSS"
cs_hp:      .res 1
.segment "FIXED"
car_setup:
        lda #0
        beq :+
car_stats:
        lda #1
:       sta cs_hp
        ldx #7
@sv:    lda tmp0,x              ; phys_setup uses tmp0-tmp7: keep the caller's
        pha
        dex
        bpl @sv
        lda ptr0
        pha
        lda ptr0+1
        pha
        lda ptr2
        pha
        lda ptr2+1
        pha
        lda ptr1
        sta ptr0
        lda ptr1+1
        sta ptr0+1
        ldx #1
        jsr phys_setup
        lda cs_hp
        beq :+
        ldx #1
        jsr phys_peak_hp
:       pla
        sta ptr2+1
        pla
        sta ptr2
        pla
        sta ptr0+1
        pla
        sta ptr0
        ldx #0
@ld:    pla
        sta tmp0,x
        inx
        cpx #8
        bne @ld
        rts

; stats_line: "123HP 1234KG RWD" for record ptr1 on row Y
.segment "BSS"
stat_row:   .res 1
.segment "FIXED"
stats_line:
        sty stat_row
        jsr car_stats
        ; build "8682HP 970KG AWD" in linebuf (17 characters at most)
        jsr num_text
        ldy #0
        jsr cat_ptr0
        lda #'H'
        sta linebuf,y
        iny
        lda #'P'
        sta linebuf,y
        iny
        lda #' '
        sta linebuf,y
        iny
        sty tmp6
        ldx #1
        lda ph_mass_l,x
        sta m_a
        lda ph_mass_h,x
        sta m_a+1
        jsr num_text
        ldy tmp6
        jsr cat_ptr0
        lda #'K'
        sta linebuf,y
        iny
        lda #'G'
        sta linebuf,y
        iny
        lda #' '
        sta linebuf,y
        iny
        sty tmp6
        ldx ph_model+1
        lda car_drive,x
        jsr drive_name_ptr
        ldy tmp6
        jsr cat_ptr0
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        lda #28
        jsr pad_ptr0
        ldx #2
        ldy stat_row
        rts                     ; caller prints (direct or vb) with X/Y set

.segment "BSS"
linebuf:    .res 33
.segment "FIXED"

; cat_ptr0: append zero-terminated ptr0 to linebuf at Y -> Y = new end
; (preserves tmp0-tmp7)
cat_ptr0:
        sty cat_d
        ldy #0
@l:     lda (ptr0),y
        beq @e
        sty cat_s
        ldy cat_d
        sta linebuf,y
        inc cat_d
        ldy cat_s
        iny
        bne @l
@e:     ldy cat_d
        rts

.segment "BSS"
cat_s:      .res 1
cat_d:      .res 1
.segment "FIXED"
