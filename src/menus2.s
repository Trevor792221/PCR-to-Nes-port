; ===========================================================================
; menus2.s -- parts, tune, paint, crates, dyno, options (bank 3)
; Called from the garage with FARCALL.
; ===========================================================================

.segment "BSS"
pt_sel:     .res 1
pt_page:    .res 1          ; 0 engine, 1 chassis
pt_part:    .res 1
pt_count:   .res 1
tn_row_y:   .res 1
tn_sel:     .res 1
pn_sel:     .res 1
pn_idx:     .res 3          ; paint list index per item
pn_orig:    .res 3
cr_sel:     .res 1
op_sel:     .res 1
dy_peak_hp: .res 2
dy_peak_hr: .res 2
dy_peak_tq: .res 2
dy_peak_tr: .res 2
dy_x:       .res 1
dy_rpm:     .res 2
dy_step:    .res 2

DY_HP   = WBUF              ; 128 words: hp per column
DY_TQ   = WBUF + 256        ; 128 words: torque (Nm) per column

.segment "BANK3"

; ===========================================================================
; PARTS
; ===========================================================================
parts_screen:
        lda #0
        jsr screen_begin
        jsr use_menu_palette
        MOVI16 ptr0, str_parts
        jsr draw_header
        jsr cur_car_ptr
        jsr car_name_ptr
        lda #$20
        sta text_attr
        ldx #2
        ldy #4
        jsr print
        ldx pt_page             ; page title and size
        lda pt_sizes,x
        sta pt_count
        lda pt_titles_lo,x
        sta ptr0
        lda pt_titles_hi,x
        sta ptr0+1
        ldx #2
        ldy #6
        jsr print
        lda #0
        sta text_attr
        ldx #0
@row:   stx tmp7
        jsr pt_index
        tax
        jsr part_line
        lda tmp7
        asl a
        clc
        adc #PT_ROW0
        tay
        ldx #3
        jsr print
        ldx tmp7
        inx
        cpx pt_count
        bne @row
        PRINT str_pt_help, 2, 28
        jsr attr_upload
        lda #0
        sta oam_idx
        jsr oam_clear
        jsr ppu_on
        jsr pt_stats
        lda pt_sel
        cmp pt_count
        bcc :+
        lda #0
        sta pt_sel
:       sta ui_sel
        lda pt_count
        sta ui_count
        lda #1
        sta ui_x
        lda #PT_ROW0
        sta ui_y0
        lda #2
        sta ui_dy
        lda #1
        sta ui_cols
        jsr pt_info
@loop:  jsr wait_frame
        jsr read_pad
        jsr list_cursor
        jsr list_select
        ldx ui_sel
        stx pt_sel
        cmp #3
        bne :+
        jsr pt_info
        jmp @loop
:       cmp #6                  ; left / right: other page
        beq @page
        cmp #7
        beq @page
        cmp #2
        bne :+
        rts
:       cmp #1
        bne @loop
        jsr pt_buy
        jmp @loop
@page:  lda pt_page
        eor #1
        sta pt_page
        lda #SFX_MOVE
        jsr sfx_play
        jmp parts_screen

; pt_index: X = row on the current page -> A = part
pt_index:
        lda pt_page
        beq :+
        lda pt_chassis,x
        rts
:       lda pt_engine,x
        rts

PT_ROW0 = 8                     ; first part row (two apart)
pt_engine:   .byte P_INTAKE, P_EXHAUST, P_ECU, P_TURBO, P_ICOOL, P_INTERNAL, P_NITROUS
pt_chassis:  .byte P_GEARBOX, P_TIRES, P_SUSP, P_WEIGHT, P_AERO
pt_sizes:    .byte 7, 5
pt_titles_lo: .byte <str_pt_eng, <str_pt_chs
pt_titles_hi: .byte >str_pt_eng, >str_pt_chs
str_pt_eng:  .byte "< ENGINE >", 0
str_pt_chs:  .byte "< CHASSIS >", 0

; part_line: X = part -> ptr0 "INTAKE     SPORT  $1800"
part_line:
        stx tmp6
        txa
        jsr part_name_ptr
        ldy #0
        jsr cat_ptr0
        lda #' '
        sta linebuf,y
        iny
        sty tmp5
        jsr cur_car_ptr
        lda tmp6
        clc
        adc #CR_PARTS
        tay
        lda (ptr1),y
        sta tmp4                ; level
        jsr level_name_ptr
        ldy tmp5
        jsr cat_ptr0
        lda #' '
        sta linebuf,y
        iny
        sty tmp5
        lda tmp4
        cmp #4
        bcc :+
        MOVI16 ptr0, str_maxed
        jmp @p
:       jsr cur_car_ptr
        tax
        lda car_tier,x
        tax
        ldy tmp4
        iny
        jsr part_price
        jsr money_text
@p:     ldy tmp5
        jsr cat_ptr0
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        lda #27
        jmp pad_ptr0

; pt_info: description of the selected part
pt_info:
        ldx pt_sel
        jsr pt_index
        asl a
        tax
        lda part_desc,x
        sta ptr0
        lda part_desc+1,x
        sta ptr0+1
        ldy #26
        jmp vb_msg

; pt_stats: HP / weight / drive line for the car (only changes on a purchase:
; measuring peak HP takes a few frames, so cursor moves don't redo it)
pt_stats:
        jsr cur_car_ptr
        ldy #4
        jsr stats_line
        lda #18
        jsr pad_ptr0
        ldy #4
        ldx #14
        jmp vb_str

pt_buy:
        ldx pt_sel
        jsr pt_index
        sta pt_part
        jsr cur_car_ptr
        lda pt_part
        clc
        adc #CR_PARTS
        tay
        lda (ptr1),y
        cmp #4
        bcs @fail
        sta tmp4
        jsr cur_car_ptr
        tax
        lda car_tier,x
        tax
        ldy tmp4
        iny
        jsr part_price
        jsr cash_cmp
        bcc @fail
        jsr cash_sub
        jsr cur_car_ptr
        lda pt_part
        clc
        adc #CR_PARTS
        tay
        lda (ptr1),y
        clc
        adc #1
        sta (ptr1),y
        jsr save_write
        lda #SFX_BUY
        jsr sfx_play
        jsr header_update
        jsr wait_frame
        ldx pt_part
        jsr part_line
        lda pt_sel
        asl a
        clc
        adc #PT_ROW0
        tay
        ldx #3
        jsr vb_str
        jsr wait_frame
        jsr pt_stats
        jsr wait_frame
        jmp pt_info
@fail:  lda #SFX_ERROR
        jmp sfx_play

str_parts:   .byte "PARTS", 0
str_maxed:   .byte "MAXED", 0
str_pt_help: .byte "A:BUY  B:BACK  L/R:PAGE", 0
part_desc:
        .word str_pd0, str_pd1, str_pd2, str_pd3, str_pd4
        .word str_pd5, str_pd6, str_pd7, str_pd8, str_pd9
        .word str_pd10, str_pd11
str_pd0: .byte "COLD AIR: +4% POWER/LEVEL", 0
str_pd1: .byte "FREE FLOW: +4% POWER/LEVEL", 0
str_pd2: .byte "+3% POWER, +200 RPM REDLINE", 0
str_pd3: .byte "BIG POWER, NEEDS RPM TO SPOOL", 0
str_pd4: .byte "FORGED PARTS: +5% POWER", 0
str_pd5: .byte "B BUTTON: A SHOT OF POWER", 0
str_pd6: .byte "FASTER SHIFTS, TUNABLE GEARS", 0
str_pd7: .byte "MORE GRIP OFF THE LINE", 0
str_pd8: .byte "+4 GRIP AT LAUNCH PER LEVEL", 0
str_pd9: .byte "-4% WEIGHT PER LEVEL", 0
str_pd10: .byte "+2% POWER, MUCH MORE W/ TURBO", 0
str_pd11: .byte "LESS DRAG, +3 GRIP PER LEVEL", 0

; ===========================================================================
; TUNE
; ===========================================================================
tune_screen:
        lda #0
        jsr screen_begin
        jsr use_menu_palette
        MOVI16 ptr0, str_tune
        jsr draw_header
        jsr cur_car_ptr
        jsr car_name_ptr
        lda #$20
        sta text_attr
        ldx #2
        ldy #4
        jsr print
        lda #0
        sta text_attr
        PRINT str_tn_head, 3, 5
        PRINT str_tn_help, 2, 27
        PRINT str_tn_help2, 2, 28
        jsr attr_upload
        lda #0
        sta oam_idx
        jsr oam_clear
        ; items: final, gears 1..n, reset, back
        jsr cur_car_ptr
        tax
        lda car_ngears,x
        clc
        adc #3
        sta ui_count
        jsr ppu_on
        lda #0
        sta tn_sel
        sta ui_sel
        lda #1
        sta ui_x
        lda #7                  ; up to 10 rows: 7..25
        sta ui_y0
        lda #2
        sta ui_dy
        lda #1
        sta ui_cols
        jsr tn_all
@loop:  jsr wait_frame
        jsr read_pad
        jsr list_cursor
        jsr list_select
        ldx ui_sel
        stx tn_sel
        cmp #2
        bne :+
        jmp tn_exit
:       cmp #6
        beq @left
        cmp #7
        beq @right
        cmp #1
        bne @loop
        ; A on reset / back
        lda tn_sel
        clc
        adc #2
        cmp ui_count
        beq @reset
        jcs tn_exit
        jmp @loop
@reset: jsr cur_car_ptr
        pha
        lda ptr1
        sta ptr2
        lda ptr1+1
        sta ptr2+1
        ; keep parts/paint, reload gearing from a fresh record
        MOVI16 ptr1, tmp_rec
        pla
        jsr init_record
        jsr cur_car_ptr
        ldy #CR_FINAL
:       lda tmp_rec,y
        sta (ptr1),y
        iny
        cpy #CR_GEARS+14
        bne :-
        lda #SFX_SELECT
        jsr sfx_play
        jsr tn_all
        jmp @loop
@left:  lda #$FD                ; -3
        bne @adj
@right: lda #3
@adj:   sta tmp6
        lda tn_sel
        beq @ok                 ; final drive is always tunable
        jsr cur_car_ptr
        tax
        lda tn_sel
        cmp car_ngears,x
        beq :+
        bcs @loop2              ; reset / back rows
:       ldy #CR_PARTS+P_GEARBOX
        lda (ptr1),y            ; any gearbox upgrade unlocks the gears
        bne @ok
        MOVI16 ptr0, str_tn_lock
        ldy #26
        jsr vb_msg
        lda #SFX_ERROR
        jsr sfx_play
@loop2: jmp @loop
@ok:    jsr cur_car_ptr
        jsr tn_offset           ; Y = record offset of the ratio
        sty tmp5
        clc
        lda (ptr1),y
        adc tmp6
        sta tmp2
        iny
        lda tmp6
        and #$80
        beq :+
        lda #$FF
:       adc (ptr1),y
        sta tmp3
        ; limits: final 2.00-6.00 ($200-$600), gears 0.50-5.00 ($80-$500)
        lda tn_sel
        bne @glim
        lda tmp3
        cmp #2
        bcc @loop2
        cmp #6
        bcs @loop2
        jmp @store
@glim:  lda tmp3
        bne :+
        lda tmp2
        cmp #$80
        bcc @loop2
:       lda tmp3
        cmp #5
        bcs @loop2
@store: ldy tmp5
        lda tmp2
        sta (ptr1),y
        iny
        lda tmp3
        sta (ptr1),y
        jsr save_write
        lda #SFX_TICK
        jsr sfx_play
        jsr tn_all
        jmp @loop

tn_exit:
        jsr save_write
        rts

; tn_offset: Y = record offset for item tn_sel (0 final, 1.. gears)
tn_offset:
        lda tn_sel
        bne :+
        ldy #CR_FINAL
        rts
:       sec
        sbc #1
        asl a
        clc
        adc #CR_GEARS
        tay
        rts

; tn_all: refresh every row (ratios and top speeds)
tn_all:
        jsr cur_car_ptr
        jsr car_setup           ; physics slot 1 holds this car
        lda tn_sel
        pha
        lda #0
        sta tn_sel
@r:     jsr tn_row
        jsr wait_frame
        inc tn_sel
        lda tn_sel
        cmp ui_count
        bne @r
        pla
        sta tn_sel
        MOVI16 ptr0, str_blank2
        ldy #26
        jmp vb_msg


; tn_row: draw row tn_sel
tn_row:
        lda tn_sel
        asl a
        clc
        adc #7
        sta tn_row_y            ; screen row
        jsr cur_car_ptr
        tax
        lda car_ngears,x
        sta tmp6
        lda tn_sel
        bne :+
        MOVI16 ptr0, str_tn_final
        jmp @label
:       cmp tmp6
        beq :+
        jcs @extra
:       ; "GEAR n"
        ldy #0
:       lda str_tn_gear,y
        beq :+
        sta linebuf,y
        iny
        bne :-
:       lda tn_sel
        ora #'0'
        sta linebuf,y
        iny
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
@label: lda #12
        jsr pad_ptr0
        ldx #3
        ldy tn_row_y
        jsr vb_str
        ; ratio value
        jsr cur_car_ptr
        jsr tn_offset
        lda (ptr1),y
        sta m_a
        iny
        lda (ptr1),y
        sta m_a+1
        jsr ratio_text
        ldx #15
        ldy tn_row_y
        jsr vb_str
        ; top speed in that gear (not for final drive)
        lda tn_sel
        beq @done
        jsr gear_top
        jsr fmt3w
        lda numbuf+5
        sta linebuf
        lda numbuf+6
        sta linebuf+1
        lda numbuf+7
        sta linebuf+2
        lda #' '
        sta linebuf+3
        lda #0
        sta linebuf+4
        MOVI16 ptr0, linebuf
        ldx #22
        ldy tn_row_y
        jmp vb_str
@extra: ; reset / back rows
        sec
        sbc tmp6
        cmp #1
        bne :+
        MOVI16 ptr0, str_tn_reset
        jmp :++
:       MOVI16 ptr0, str_tn_back
:       ldx #3
        ldy tn_row_y
        jmp vb_str
@done:  rts

; ratio_text: m_a = 8.8 ratio -> ptr0 "d.dd"
ratio_text:
        lda #100
        sta m_b
        lda #0
        sta m_b+1
        jsr mul16
        clc
        lda m_r
        adc #128
        lda m_r+1
        adc #0
        sta m_r
        lda m_r+2
        adc #0
        sta m_r+1
        lda #0
        sta m_r+2
        sta m_r+3
        lda #100
        jsr div16_8             ; m_r = integer, A = hundredths
        pha
        lda m_r
        ora #'0'
        sta linebuf
        lda #'.'
        sta linebuf+1
        pla
        jsr fmt_8
        lda numbuf+6
        cmp #' '
        bne :+
        lda #'0'
:       sta linebuf+2
        lda numbuf+7
        sta linebuf+3
        lda #0
        sta linebuf+4
        MOVI16 ptr0, linebuf
        rts

; gear_top: A = speed at the redline in gear tn_sel (physics slot 1)
gear_top:
        lda #0
        sta m_r
        ldx #1
        lda ph_redl_l,x
        sta m_r+1
        lda ph_redl_h,x
        sta m_r+2
        lda #0
        sta m_r+3
        lda #8
        clc
        adc tn_sel
        tay
        lda ph_rs_l,y
        sta m_b
        lda ph_rs_h,y
        sta m_b+1
        ora m_b
        beq @z
        jsr div32               ; v_raw = redline*256/rs
        lda m_r
        sta ph_v1+1
        lda m_r+1
        sta ph_v2+1
        ldx #1
        jmp phys_speed
@z:     lda #0
        sta spd_hi
        rts

str_tune:     .byte "TUNE", 0
str_tn_head:  .byte "SETTING     RATIO  TOP SPD", 0
str_tn_final: .byte "FINAL DRIVE", 0
str_tn_gear:  .byte "GEAR ", 0
str_tn_reset: .byte "RESET TO STOCK", 0
str_tn_back:  .byte "BACK", 0
str_tn_help:  .byte "LEFT/RIGHT:CHANGE RATIO", 0
str_tn_help2: .byte "LOWER = FASTER ACCELERATION", 0
str_tn_lock:  .byte "UPGRADE THE GEARBOX FIRST", 0
str_blank2:   .byte 0

; ===========================================================================
; PAINT
; ===========================================================================
paint_screen:
        lda #0
        jsr screen_begin
        jsr use_menu_palette
        MOVI16 ptr0, str_paint
        jsr draw_header
        jsr draw_showroom2
        PRINT str_pn0, 4, 15
        PRINT str_pn1, 4, 17
        PRINT str_pn2, 4, 19
        PRINT str_pn_help, 2, 24
        PRINT str_pn_help2, 2, 25
        PRINT str_pn_help3, 2, 26
        jsr attr_upload
        jsr cur_car_ptr
        tax
        lda car_shape,x
        ldx #$40
        jsr big_car_direct
        jsr cur_car_ptr         ; (big_car_direct used ptr1)
        ; find each colour in the list
        ldx #0
@f:     stx tmp7
        txa
        clc
        adc #CR_PAINT
        tay
        lda (ptr1),y
        ldx tmp7
        sta pn_orig,x
        ldy #0
:       cmp paint_list,y
        beq :+
        iny
        cpy #NPAINTS
        bne :-
        ldy #0
:       tya
        ldx tmp7
        sta pn_idx,x
        inx
        cpx #3
        bne @f
        jsr cur_car_ptr
        jsr set_car_palette
        jsr ppu_on
        lda #0
        sta ui_sel
        sta pn_sel
        lda #3
        sta ui_count
        lda #2
        sta ui_x
        lda #15
        sta ui_y0
        lda #2
        sta ui_dy
        lda #1
        sta ui_cols
        jsr pn_values
@loop:  jsr wait_frame
        jsr read_pad
        lda #4
        sta oam_idx
        lda #96
        sta sp_x
        lda #59
        sta sp_y
        lda #$40
        sta sp_tile
        lda #0
        sta sp_attr
        jsr draw_big_car
        jsr oam_clear
        jsr list_cursor
        jsr list_select
        ldx ui_sel
        stx pn_sel
        cmp #6
        beq @left
        cmp #7
        beq @right
        cmp #2
        jeq @cancel
        cmp #1
        beq @buy
        jmp @loop
@left:  ldx pn_sel
        lda pn_idx,x
        bne :+
        lda #NPAINTS
:       sec
        sbc #1
        sta pn_idx,x
        jmp @chg
@right: ldx pn_sel
        lda pn_idx,x
        clc
        adc #1
        cmp #NPAINTS
        bcc :+
        lda #0
:       sta pn_idx,x
@chg:   jsr pn_apply
        lda #SFX_MOVE
        jsr sfx_play
        jsr pn_values
        jmp @loop
@buy:   ; anything changed?
        ldx #2
@cmp:   txa
        clc
        adc #CR_PAINT
        tay
        jsr cur_car_ptr
        lda (ptr1),y
        cmp pn_orig,x
        bne @changed
        dex
        bpl @cmp
        rts                     ; nothing to pay for
@changed:                       ; painting is free
        jsr save_write
        lda #SFX_BUY
        jsr sfx_play
        lda #30
        jsr wait_frames
        rts
@cancel:
        jsr cur_car_ptr
        ldx #2
:       txa
        clc
        adc #CR_PAINT
        tay
        lda pn_orig,x
        sta (ptr1),y
        dex
        bpl :-
        rts

; pn_apply: write the chosen colours into the record and the palette
pn_apply:
        jsr cur_car_ptr
        ldx #2
:       ldy pn_idx,x
        lda paint_list,y
        pha
        txa
        clc
        adc #CR_PAINT
        tay
        pla
        sta (ptr1),y
        dex
        bpl :-
        jmp set_car_palette

; pn_values: "< 12/24 >" next to each item
pn_values:
        ldx #0
@l:     stx tmp7
        lda pn_idx,x
        clc
        adc #1
        jsr fmt_8
        lda #'<'
        sta linebuf
        lda #' '
        sta linebuf+1
        lda numbuf+6
        sta linebuf+2
        lda numbuf+7
        sta linebuf+3
        lda #'/'
        sta linebuf+4
        lda #'2'
        sta linebuf+5
        lda #'4'
        sta linebuf+6
        lda #' '
        sta linebuf+7
        lda #'>'
        sta linebuf+8
        lda #0
        sta linebuf+9
        MOVI16 ptr0, linebuf
        lda tmp7
        asl a
        clc
        adc #15
        tay
        ldx #14
        jsr vb_str
        ldx tmp7
        inx
        cpx #3
        bne @l
        rts

; draw_showroom2: same look as the garage (rows 4-12)
draw_showroom2:
        jmp draw_garage_bg

str_paint:    .byte "PAINT SHOP", 0
str_pn0:      .byte "BODY", 0
str_pn1:      .byte "RIMS", 0
str_pn2:      .byte "GLASS", 0
str_pn_help:  .byte "LEFT/RIGHT:PICK COLOUR", 0
str_pn_help2: .byte "A:KEEP (FREE)", 0
str_pn_help3: .byte "B:CANCEL", 0

; ===========================================================================
; CRATES
; ===========================================================================
crates_screen:
        lda #0
        jsr screen_begin
        jsr use_menu_palette
        MOVI16 ptr0, str_crates
        jsr draw_header
        ; crate graphic: 4x4 tiles at col 14, row 6
        ldy #6
        lda #0
        sta tmp6
@cr:    sty tmp7
        ldx #14
        jsr nt_addr
        lda ptr3+1
        ldx ptr3
        jsr vram_addr
        ldx tmp6
        ldy #4
:       lda crate_map,x
        sta PPUDATA
        inx
        dey
        bne :-
        stx tmp6
        ldy tmp7
        iny
        cpy #10
        bne @cr
        lda #7
        sta tmp0
        lda #3
        sta tmp1
        lda #2
        sta tmp2
        lda #2
        sta tmp3
        lda #2
        jsr attr_rect
        PRINT str_cr0, 4, 13
        PRINT str_cr1, 4, 15
        PRINT str_cr2, 4, 17
        jsr attr_upload
        lda #0
        sta oam_idx
        jsr oam_clear
        jsr ppu_on
        lda #0
        sta ui_sel
        lda #3
        sta ui_count
        lda #2
        sta ui_x
        lda #13
        sta ui_y0
        lda #2
        sta ui_dy
        lda #1
        sta ui_cols
@loop:  jsr wait_frame
        jsr read_pad
        jsr list_cursor
        jsr list_select
        cmp #2
        beq @back
        cmp #1
        bne @loop
        lda ui_sel
        cmp #2
        beq @back
        sta cr_sel
        jsr crate_buy
        jmp @loop
@back:  lda #0
        sta scroll_x
        rts

crate_buy:
        lda cr_sel
        bne @gem
        lda #<2500
        sta m_a
        lda #>2500
        sta m_a+1
        lda #0
        sta m_a+2
        jsr cash_cmp
        bcc @fail
        jsr cash_sub
        jmp @open
@gem:   lda SV_GEMS+1
        bne :+
        lda SV_GEMS
        cmp #10
        bcc @fail
:       sec
        lda SV_GEMS
        sbc #10
        sta SV_GEMS
        lda SV_GEMS+1
        sbc #0
        sta SV_GEMS+1
@open:  inc SV_CRATES
        bne :+
        inc SV_CRATES+1
:       jsr header_update
        MOVI16 ptr0, str_blank2
        ldy #22
        jsr vb_msg
        MOVI16 ptr0, str_blank2
        ldy #23
        jsr vb_msg
        ; shake
        lda #SFX_CRATE
        jsr sfx_play
        lda #40
        sta tmp7
@sh:    jsr wait_frame
        lda frame
        and #2
        beq :+
        lda #2
        bne :++
:       lda #254
:       sta scroll_x
        dec tmp7
        bne @sh
        lda #0
        sta scroll_x
        jsr crate_reward
        jsr save_write
        jsr wait_frame
        jmp header_update
@fail:  lda #SFX_ERROR
        jsr sfx_play
        MOVI16 ptr0, str_cr_poor
        ldy #22
        jmp vb_msg

; crate_reward: roll and give the reward, message on rows 22-23
crate_reward:
        ; ultra rare: the crate-only car (standard 1/256, premium 5/256).
        ; Needs a free garage slot, otherwise roll a normal reward.
        jsr rand
        ldx cr_sel
        cmp ultra_odds,x
        bcs @normal
        jsr free_slot
        bcs @normal
        jmp give_ultra
@normal:
        lda #100
        jsr rand_below
        sta tmp5
        lda cr_sel
        bne @prem
        ; standard: 45 cash, 30 part, 17 gems, 8 car
        lda tmp5
        cmp #45
        bcc @cash_s
        cmp #75
        jcc @part1
        cmp #92
        bcc @gems_s
        lda #6                  ; models 1..6
        jsr rand_below
        clc
        adc #1
        jmp give_car
@prem:  lda tmp5
        cmp #30
        bcc @cash_p
        cmp #65
        bcc @part2
        cmp #85
        bcc @gems_p
        lda #6                  ; models 4..9
        jsr rand_below
        clc
        adc #4
        jmp give_car
@cash_s:
        lda #31                 ; $1000 + 100*rand(31)
        jsr rand_below
        sta m_a
        lda #100
        sta m_b
        jsr mul8
        clc
        lda m_r
        adc #<1000
        sta m_a
        lda m_r+1
        adc #>1000
        sta m_a+1
        jmp give_cash
@cash_p:
        lda #151                ; $5000 + 100*rand(151)
        jsr rand_below
        sta m_a
        lda #100
        sta m_b
        jsr mul8
        clc
        lda m_r
        adc #<5000
        sta m_a
        lda m_r+1
        adc #>5000
        sta m_a+1
        jmp give_cash
@gems_s:
        lda #3
        jsr rand_below
        clc
        adc #1
        jmp give_gems
@gems_p:
        lda #6
        jsr rand_below
        clc
        adc #3
        jmp give_gems
@part2: jsr give_part
        MOVI16 ptr0, str_cr_part2
        ldy #23
        jsr vb_msg
        jsr wait_frame
        jmp give_part_silent
@part1: jmp give_part

give_cash:
        lda #0
        sta m_a+2
        lda m_a
        pha
        lda m_a+1
        pha
        jsr cash_add
        pla
        sta m_a+1
        pla
        sta m_a
        lda #0
        sta m_a+2
        jsr money_text
        ldy #0
:       lda str_cr_cash,y
        beq :+
        sta linebuf,y
        iny
        bne :-
:       jsr cat_ptr0
        lda #'!'
        sta linebuf,y
        iny
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        ldy #22
        jmp vb_msg

give_gems:
        pha
        clc
        adc SV_GEMS
        sta SV_GEMS
        bcc :+
        inc SV_GEMS+1
:       pla
        jsr fmt_8
        ldy #0
:       lda str_cr_gems,y
        beq :+
        sta linebuf,y
        iny
        bne :-
:       lda numbuf+7
        sta linebuf,y
        iny
        ldx #0
:       lda str_cr_gems2,x
        sta linebuf,y
        beq :+
        inx
        iny
        bne :-
:       MOVI16 ptr0, linebuf
        ldy #22
        jmp vb_msg

; give_part: +1 level on a random part of the current car (cash if maxed)
give_part:
        jsr give_part_silent
        bcs @cash
        lda tmp4
        jsr part_name_ptr
        ldy #0
:       lda str_cr_up,y
        beq :+
        sta linebuf,y
        iny
        bne :-
:       jsr cat_ptr0
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        ldy #22
        jmp vb_msg
@cash:  lda #<5000
        sta m_a
        lda #>5000
        sta m_a+1
        jmp give_cash

; give_part_silent: carry set if everything is maxed; tmp4 = part
give_part_silent:
        lda #NPARTS
        jsr rand_below
        sta tmp4
        ldx #NPARTS
@try:   jsr cur_car_ptr
        lda tmp4
        clc
        adc #CR_PARTS
        tay
        lda (ptr1),y
        cmp #4
        bcc @up
        inc tmp4
        lda tmp4
        cmp #NPARTS
        bcc :+
        lda #0
        sta tmp4
:       dex
        bne @try
        sec
        rts
@up:    adc #1
        sta (ptr1),y
        clc
        rts

; give_car: model A into a free slot (cash if the garage is full)
give_car:
        sta tmp6
        jsr free_slot
        bcs @full
        jsr slot_ptr
        lda tmp6
        jsr init_record
        ldy #CR_PAINT
        lda #NPAINTS
        jsr rand_below
        tax
        lda paint_list,x
        ldy #CR_PAINT
        sta (ptr1),y
        ldy #CR_MODEL           ; (rand_below used tmp6)
        lda (ptr1),y
        jsr car_name_ptr
        ldy #0
:       lda str_cr_car,y
        beq :+
        sta linebuf,y
        iny
        bne :-
:       jsr cat_ptr0
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        ldy #22
        jsr vb_msg
        lda #SFX_LEVELUP
        jmp sfx_play
@full:  lda #<15000
        sta m_a
        lda #>15000
        sta m_a+1
        jmp give_cash

crate_map:    .byte T_CRATE_MAP
ultra_odds:   .byte 1, 5

; give_ultra: the crate-only car, gold, with a fanfare
give_ultra:
        lda #CRATE_CAR
        jsr give_car
        ldx #NSLOTS-1           ; find the new car and paint it gold
@find:  txa
        jsr slot_ptr
        ldy #CR_MODEL
        lda (ptr1),y
        cmp #CRATE_CAR
        beq @gold
        dex
        bpl @find
        rts
@gold:  ldy #CR_PAINT
        lda #$28
        sta (ptr1),y
        jsr wait_frame
        MOVI16 ptr0, str_cr_ultra
        ldy #23
        jmp vb_msg

str_cr_ultra: .byte "*** ULTRA RARE - 400 MPH! ***", 0
str_crates:   .byte "CRATES", 0
str_cr0:      .byte "STANDARD CRATE    $2500", 0
str_cr1:      .byte "PREMIUM CRATE   10 GEMS", 0
str_cr2:      .byte "BACK", 0
str_cr_poor:  .byte "YOU CAN'T AFFORD THAT", 0
str_cr_cash:  .byte "CASH PRIZE: ", 0
str_cr_gems:  .byte "YOU GOT ", 0
str_cr_gems2: .byte " GEMS!", 0
str_cr_up:    .byte "FREE UPGRADE: ", 0
str_cr_part2: .byte "...PLUS A SECOND UPGRADE!", 0
str_cr_car:   .byte "NEW CAR! ", 0

; ===========================================================================
; DYNO
; ===========================================================================
dyno_screen:
        lda #0
        jsr screen_begin
        jsr use_menu_palette
        lda #$27
        sta palette+$0E
        lda #$21
        sta palette+$0F
        lda #$00
        sta palette+$0D
        MOVI16 ptr0, str_dyno
        jsr draw_header
        jsr cur_car_ptr
        jsr car_name_ptr
        lda #$20
        sta text_attr
        ldx #2
        ldy #4
        jsr print
        lda #0
        sta text_attr
        ; graph tiles $80-$FF at rows 7-14, cols 8-23
        ldy #7
        lda #$80
        sta tmp6
@gr:    sty tmp7
        ldx #8
        jsr nt_addr
        lda ptr3+1
        ldx ptr3
        jsr vram_addr
        ldx #16
        lda tmp6
:       sta PPUDATA
        clc
        adc #1
        dex
        bne :-
        sta tmp6
        ldy tmp7
        iny
        cpy #15
        bne @gr
        lda #4
        sta tmp0
        lda #3
        sta tmp1
        lda #8
        sta tmp2
        lda #4
        sta tmp3
        lda #3
        jsr attr_rect
        PRINT str_dy_hp, 3, 8
        PRINT str_dy_tq, 25, 8
        PRINT str_dy_rpm, 11, 16
        PRINT str_dy_help, 2, 26
        ; clear the graph tiles in CHR
        lda #$08
        ldx #$00
        jsr vram_addr
        lda #0
        ldx #0
        ldy #8
:       sta PPUDATA
        inx
        bne :-
        dey
        bne :-
        jsr attr_upload
        lda #0
        sta oam_idx
        jsr oam_clear
        jsr ppu_on
@run:   jsr dyno_compute
        jsr dyno_plot
        jsr dyno_run
        jsr dyno_text
@loop:  jsr wait_frame
        jsr read_pad
        lda pad_new
        and #BTN_A
        bne @again
        lda pad_new
        and #BTN_B
        beq @loop
        lda #SFX_BACK
        jsr sfx_play
        jsr engine_stop
        rts
@again: jmp @run

; dyno_compute: torque and power for 128 columns from 1000 rpm to the limiter
dyno_compute:
        jsr cur_car_ptr
        jsr car_setup           ; slot 1 (dyno_text measures the peak)
        lda #0
        sta dy_peak_hp
        sta dy_peak_hp+1
        sta dy_peak_tq
        sta dy_peak_tq+1
        ; step = (limiter - 1000) * 256 / 128 = (limiter-1000)*2
        ldx #1
        sec
        lda ph_lim_l,x
        sbc #<1000
        sta dy_step
        lda ph_lim_h,x
        sbc #>1000
        sta dy_step+1
        lda #<1000
        sta dy_rpm
        lda #>1000
        sta dy_rpm+1
        lda #0
        sta dy_x
        sta tmp7                ; fraction accumulator (1/128)
@col:   ; torque fraction at full boost: curve + bcurve
        lda dy_rpm+1
        cmp #47
        bcc :+
        lda #47
:       clc
        adc #48
        tay
        clc
        lda ph_curve,y
        adc ph_bcurve,y
        sta m_a
        lda #0
        adc #0
        sta m_a+1
        ; Nm = teff * frac / 255  (~ >> 8 with a small correction)
        ldx #1
        lda ph_teff_l,x
        sta m_b
        lda ph_teff_h,x
        sta m_b+1
        jsr mul16
        lda m_r+1
        sta tmp2
        lda m_r+2
        sta tmp3
        ; store torque
        lda dy_x
        asl a
        tay
        lda tmp2
        sta DY_TQ,y
        lda tmp3
        sta DY_TQ+1,y
        ; peak torque
        lda dy_peak_tq
        cmp tmp2
        lda dy_peak_tq+1
        sbc tmp3
        bcs :+
        lda tmp2
        sta dy_peak_tq
        lda tmp3
        sta dy_peak_tq+1
        lda dy_rpm
        sta dy_peak_tr
        lda dy_rpm+1
        sta dy_peak_tr+1
:       ; hp = Nm * rpm / 7121
        lda tmp2
        sta m_a
        lda tmp3
        sta m_a+1
        lda dy_rpm
        sta m_b
        lda dy_rpm+1
        sta m_b+1
        jsr mul16
        lda #<7121
        sta m_b
        lda #>7121
        sta m_b+1
        jsr div32
        lda dy_x
        asl a
        tay
        lda m_r
        sta DY_HP,y
        lda m_r+1
        sta DY_HP+1,y
        lda dy_peak_hp
        cmp m_r
        lda dy_peak_hp+1
        sbc m_r+1
        bcs :+
        lda m_r
        sta dy_peak_hp
        lda m_r+1
        sta dy_peak_hp+1
        lda dy_rpm
        sta dy_peak_hr
        lda dy_rpm+1
        sta dy_peak_hr+1
:       ; rpm += step/128 (with fraction)
        lda dy_step
        and #$7F
        clc
        adc tmp7
        sta tmp7
        lda #0
        bit tmp7
        bpl :+
        lda tmp7
        and #$7F
        sta tmp7
        lda #1
:       sta tmp4
        lda dy_step+1
        sta tmp3
        lda dy_step
        asl a
        rol tmp3                ; tmp3 = step >> 7
        lda #0
        rol a
        sta tmp2                ; hi part of step>>7
        clc
        lda dy_rpm
        adc tmp3
        sta dy_rpm
        lda dy_rpm+1
        adc tmp2
        sta dy_rpm+1
        clc
        lda dy_rpm
        adc tmp4
        sta dy_rpm
        bcc :+
        inc dy_rpm+1
:       inc dy_x
        lda dy_x
        cmp #128
        beq :+
        jmp @col
:       rts

; dyno_plot: draw grid + curves into DYNO_BMP (128 tiles, 16 per row)
dyno_plot:
        ; clear
        MOVI16 ptr2, DYNO_BMP
        ldx #8
        ldy #0
        lda #0
:       sta (ptr2),y
        iny
        bne :-
        inc ptr2+1
        dex
        bne :-
        ; grid: dotted horizontal lines every 16 px, vertical every 32 px
        lda #0
        sta tmp4                ; x
@gx:    lda tmp4
        and #1
        bne @gn
        ldy #0
:       sty tmp5
        ldx tmp4
        lda #1
        jsr dyno_pset
        lda tmp5
        clc
        adc #16
        tay
        cpy #64
        bcc :-
@gn:    inc tmp4
        lda tmp4
        cmp #128
        bne @gx
        lda #0
        sta tmp5                ; y
@gy:    lda tmp5
        and #1
        bne @gyn
        ldx #0
:       stx tmp4
        ldy tmp5
        lda #1
        jsr dyno_pset
        lda tmp4
        clc
        adc #32
        tax
        cpx #128
        bcc :-
@gyn:   inc tmp5
        lda tmp5
        cmp #64
        bne @gy
        ; curves: y = 63 - value*60/peak
        lda #0
        sta tmp4
@cx:    lda tmp4
        asl a
        tay
        lda DY_TQ,y
        sta m_a
        lda DY_TQ+1,y
        sta m_a+1
        lda dy_peak_tq
        sta m_b
        lda dy_peak_tq+1
        sta m_b+1
        jsr dyno_scale
        ldx tmp4
        lda #3
        jsr dyno_pset
        lda tmp4
        asl a
        tay
        lda DY_HP,y
        sta m_a
        lda DY_HP+1,y
        sta m_a+1
        lda dy_peak_hp
        sta m_b
        lda dy_peak_hp+1
        sta m_b+1
        jsr dyno_scale
        ldx tmp4
        lda #2
        jsr dyno_pset
        inc tmp4
        lda tmp4
        cmp #128
        bne @cx
        rts

; dyno_scale: Y = 63 - m_a*60/m_b  (m_b != 0)
dyno_scale:
        lda m_b
        ora m_b+1
        bne :+
        ldy #63
        rts
:       lda m_b
        pha
        lda m_b+1
        pha
        lda #60
        sta m_b
        lda #0
        sta m_b+1
        jsr mul16
        pla
        sta m_b+1
        pla
        sta m_b
        jsr div32
        lda #63
        sec
        sbc m_r
        bcs :+
        lda #0
:       tay
        rts

; dyno_pset: pixel X,Y (0-127, 0-63) colour A (1-3), OR'd in
dyno_pset:
        sta tmp6
        ; tile = (y>>3)*16 + (x>>3); addr = DYNO_BMP + tile*16 + (y&7)
        tya
        lsr a
        lsr a
        lsr a
        clc
        adc #>DYNO_BMP
        sta ptr3+1
        txa
        and #$78                ; (x>>3)*16 = (x & $78) * 2
        asl a
        sta ptr3
        tya
        and #7
        ora ptr3
        sta ptr3
        txa
        and #7
        tax
        lda bitmask,x
        sta tmp7
        ldy #0
        lda tmp6
        lsr a
        bcc :+
        lda (ptr3),y
        ora tmp7
        sta (ptr3),y
:       lda tmp6
        and #2
        beq :+
        ldy #8
        lda (ptr3),y
        ora tmp7
        sta (ptr3),y
:       rts

bitmask: .byte $80, $40, $20, $10, $08, $04, $02, $01

; dyno_run: stream the bitmap into CHR while the engine sweeps the revs
dyno_run:
        jsr engine_start
        lda #1
        sta eng_thr
        lda #0
        sta eng_duty
        sta eng_orpm
        sta eng_orpm+1
        sta eng_noise
        lda #<1000
        sta eng_rpm
        lda #>1000
        sta eng_rpm+1
        MOVI16 chr_src, DYNO_BMP
        MOVI16 chr_dst, $0800
        lda #64
        sta chr_cnt
@l:     jsr wait_frame
        ; rpm follows the streaming progress
        lda #64
        sec
        sbc chr_cnt
        sta m_a
        ldx #1
        lda ph_lim_h,x
        sta m_b
        jsr mul8                ; progress*lim_hi -> /64
        lda m_r
        sta m_a
        lda m_r+1
        ldx #6
:       lsr a
        ror m_a
        dex
        bne :-
        lda m_a
        clc
        adc #4
        sta eng_rpm+1
        lda chr_cnt
        bne @l
        lda #0
        sta eng_thr
        lda #<900
        sta eng_rpm
        lda #>900
        sta eng_rpm+1
        lda #20
        jsr wait_frames
        jmp engine_stop

; dyno_text: peak figures on rows 18-21
dyno_text:
        ldx #1                  ; same peak figures as the menus
        jsr phys_peak_hp
        lda ep_hp
        sta m_a
        lda ep_hp+1
        sta m_a+1
        lda ep_hp_rpm
        sta tmp2
        lda ep_hp_rpm+1
        sta tmp3
        MOVI16 ptr2, str_dy_php
        ldy #18
        jsr dyno_line
        lda ep_tq
        sta m_a
        lda ep_tq+1
        sta m_a+1
        lda ep_tq_rpm
        sta tmp2
        lda ep_tq_rpm+1
        sta tmp3
        MOVI16 ptr2, str_dy_ptq
        ldy #20
        jmp dyno_line

; dyno_line: "PEAK HP  412 AT 7100 RPM" ptr2 = label, m_a = value,
; tmp2/3 = rpm, Y = row
dyno_line:
        sty tmp7
        lda tmp2
        pha
        lda tmp3
        pha
        jsr num_text
        ldy #0
        sty tmp5
:       sty tmp4
        lda (ptr2),y
        beq :+
        ldy tmp5
        sta linebuf,y
        inc tmp5
        ldy tmp4
        iny
        bne :-
:       ldy tmp5
        jsr cat_ptr0
        sty tmp5
        pla
        sta m_a+1
        pla
        sta m_a
        ; round rpm to 100
        jsr num_text
        MOVI16 ptr2, str_dy_at
        ldy tmp5
        ldx #0
:       lda str_dy_at,x
        beq :+
        sta linebuf,y
        iny
        inx
        bne :-
:       jsr cat_ptr0
        ldx #0
:       lda str_dy_rpm2,x
        sta linebuf,y
        beq :+
        iny
        inx
        bne :-
:       MOVI16 ptr0, linebuf
        ldy tmp7
        jsr vb_msg
        jmp wait_frame

str_dyno:     .byte "DYNO", 0
str_dy_hp:    .byte "HP", 0
str_dy_tq:    .byte "TQ", 0
str_dy_rpm:   .byte "RPM ->", 0
str_dy_help:  .byte "A:RUN AGAIN  B:BACK", 0
str_dy_php:   .byte " PEAK HP ", 0
str_dy_ptq:   .byte " PEAK NM ", 0
str_dy_at:    .byte " AT ", 0
str_dy_rpm2:  .byte " RPM", 0

; ===========================================================================
; OPTIONS
; ===========================================================================
options_screen:
        lda #0
        jsr screen_begin
        jsr use_menu_palette
        MOVI16 ptr0, str_options
        jsr draw_header
        PRINT str_op0, 4, 5
        PRINT str_op1, 4, 7
        PRINT str_op2, 4, 9
        PRINT str_op3, 4, 11
        PRINT str_op5, 4, 13
        PRINT str_op4, 4, 15
        BOX 1, 17, 30, 12
        PRINT str_c0, 3, 18
        PRINT str_c1, 3, 19
        PRINT str_c2, 3, 20
        PRINT str_c3, 3, 21
        PRINT str_c4, 3, 22
        PRINT str_c5, 3, 23
        PRINT str_c6, 3, 24
        PRINT str_c7, 3, 25
        PRINT str_c8, 3, 26
        PRINT str_c9, 3, 27
        jsr attr_upload
        lda #0
        sta oam_idx
        jsr oam_clear
        jsr ppu_on
        lda #0
        sta ui_sel
        lda #6
        sta ui_count
        lda #2
        sta ui_x
        lda #5
        sta ui_y0
        lda #2
        sta ui_dy
        lda #1
        sta ui_cols
        jsr op_values
@loop:  jsr wait_frame
        jsr read_pad
        jsr list_cursor
        jsr list_select
        cmp #2
        jeq @back
        cmp #1
        beq @a
        cmp #6
        beq @toggle
        cmp #7
        beq @toggle
        jmp @loop
@a:     lda ui_sel
        cmp #5
        beq @back
        cmp #4
        beq @title
        cmp #3
        beq @erase
@toggle:
        ldx ui_sel
        cpx #3
        bcs @loop
        lda SV_OPTIONS
        eor op_bits,x
        sta SV_OPTIONS
        jsr save_write
        lda #SFX_MOVE
        jsr sfx_play
        lda SV_OPTIONS
        and #OPT_NOMUSIC
        beq :+
        jsr music_stop
        jmp :++
:       lda mus_on
        bne :+
        lda #SONG_GARAGE
        jsr music_play
:       jsr op_values
        jmp @loop
@title: jsr save_write
        lda #MODE_TITLE
        sta next_mode
        rts
@erase: MOVI16 ptr0, str_op_sure
        ldy #16
        jsr confirm
        bcs :+
        jsr new_game
        lda #MODE_TITLE
        sta next_mode
        rts
:       MOVI16 ptr0, str_blank2
        ldy #28
        jsr vb_msg
        jmp @loop
@back:  rts

op_bits: .byte OPT_KMH, OPT_NOMUSIC, OPT_AUTO

op_values:
        lda SV_OPTIONS
        and #OPT_KMH
        beq :+
        MOVI16 ptr0, str_ov_kmh
        jmp :++
:       MOVI16 ptr0, str_ov_mph
:       ldx #18
        ldy #5
        jsr vb_str
        lda SV_OPTIONS
        and #OPT_NOMUSIC
        beq :+
        MOVI16 ptr0, str_ov_off
        jmp :++
:       MOVI16 ptr0, str_ov_on
:       ldx #18
        ldy #7
        jsr vb_str
        lda SV_OPTIONS
        and #OPT_AUTO
        beq :+
        MOVI16 ptr0, str_ov_auto
        jmp :++
:       MOVI16 ptr0, str_ov_man
:       ldx #18
        ldy #9
        jmp vb_str

str_options:  .byte "OPTIONS", 0
str_op0:      .byte "SPEED UNITS", 0
str_op1:      .byte "MUSIC", 0
str_op2:      .byte "GEAR SHIFTS", 0
str_op3:      .byte "ERASE SAVE", 0
str_op4:      .byte "BACK", 0
str_op5:      .byte "QUIT TO TITLE", 0
str_ov_mph:   .byte "< MPH  >", 0
str_ov_kmh:   .byte "< KM/H >", 0
str_ov_on:    .byte "< ON   >", 0
str_ov_off:   .byte "< OFF  >", 0
str_ov_man:   .byte "< MANUAL >", 0
str_ov_auto:  .byte "< AUTO   >", 0
str_op_sure:  .byte "REALLY ERASE EVERYTHING?", 0
str_c0:       .byte "RACE CONTROLS", 0
str_c1:       .byte "A      GAS (HOLD TO REV)", 0
str_c2:       .byte "RIGHT  SHIFT UP / LAUNCH", 0
str_c3:       .byte "LEFT   SHIFT DOWN", 0
str_c4:       .byte "B      NITROUS", 0
str_c5:       .byte "UP/DN  CHANGE LANE (STREET)", 0
str_c6:       .byte "START  PAUSE / QUIT", 0
str_c7:       .byte "LAUNCH ON GREEN, NOT BEFORE!", 0
str_c8:       .byte "SHIFT IN THE RED ZONE, JUST", 0
str_c9:       .byte "BEFORE THE LIMIT: PERFECT!", 0
