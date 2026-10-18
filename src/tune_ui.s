; ===========================================================================
; tune_ui.s -- the TUNE screens (bank 3): the engine tune hub and the fuel
; map.  The gear ratio screen (gear_screen) is in menus2.s.  What the
; settings do is in tune.s.
; ===========================================================================

.segment "BSS"
et_sel:     .res 1
et_val:     .res 1          ; +1 / -1
et_old:     .res 1
fm_sel:     .res 1          ; fuel map cell
fm_k:       .res 1
fm_r:       .res 1
.segment "BANK3"

ET_Y0 = 5                       ; first row (two apart)
ET_N  = 9
ET_VX = 17                      ; value column
ET_GEARS  = 0
ET_FUEL   = 1
ET_IGN    = 2
ET_BOOST  = 3
ET_TIRE   = 4
ET_LAUNCH = 5
ET_NOS    = 6
ET_RESET  = 7
ET_BACK   = 8
LAUNCH_MIN = 20                 ; 2-step: 2000 rpm ..

; ---------------------------------------------------------------------------
; tune_screen: the hub.  Gear ratios and the fuel map open their own
; screens; timing, boost, tire pressure, the 2-step and the nitrous
; (power or duration) change with Left/Right.  The box shows peak power and whether the engine knocks or
; runs lean.
; ---------------------------------------------------------------------------
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
        ldx #0
@lab:   stx tmp7
        txa
        asl a
        tax
        lda et_labels,x
        sta ptr0
        lda et_labels+1,x
        sta ptr0+1
        lda tmp7
        asl a
        clc
        adc #ET_Y0
        tay
        ldx #3
        jsr print
        ldx tmp7
        inx
        cpx #ET_N
        bne @lab
        PRINT str_et_open, ET_VX, ET_Y0
        MOVI16 ptr0, str_et_needecu ; the fuel map needs an ECU upgrade
        jsr et_ecu
        beq :+
        MOVI16 ptr0, str_et_open
:       ldx #ET_VX
        ldy #ET_Y0+2
        jsr print
        BOX 1, 22, 30, 7
        jsr attr_upload
        lda #0
        sta oam_idx
        jsr oam_clear
        jsr ppu_on
        lda et_sel
        cmp #ET_N
        bcc :+
        lda #0
:       sta et_sel
        sta ui_sel
        lda #ET_N
        sta ui_count
        lda #1
        sta ui_x
        sta ui_cols
        lda #ET_Y0
        sta ui_y0
        lda #2
        sta ui_dy
        jsr et_all
        jsr et_help
@loop:  jsr wait_frame
        jsr read_pad
        jsr list_cursor
        jsr list_select
        ldx ui_sel
        stx et_sel
        cmp #3
        bne :+
        jsr et_help
        jmp @loop
:       cmp #2
        beq et_exit
        cmp #6
        bne :+
        lda #$FF
        bne @adj
:       cmp #7
        bne :+
        lda #1
        bne @adj
:       cmp #1
        bne @loop
        ; A
        lda et_sel
        cmp #ET_GEARS
        bne :+
        jsr gear_screen
        jmp tune_screen
:       cmp #ET_FUEL
        bne :+
        jsr et_ecu
        bne @fuel
        MOVI16 ptr0, str_et_ecufuel
        jsr et_refuse
        jmp @loop
@fuel:  jsr fuel_screen
        jmp tune_screen
:       cmp #ET_BACK
        beq et_exit
        cmp #ET_RESET
        bne @loop
        jsr cur_car_ptr         ; every tune byte back to 0 (stock)
        ldy #CR_FUEL
        lda #0
:       sta (ptr1),y
        iny
        cpy #CR_NOS+1
        bne :-
        jsr save_write
        lda #SFX_SELECT
        jsr sfx_play
        jsr et_all
        jmp @loop
@adj:   sta et_val
        jsr et_adjust
        jcc @loop
        jsr save_write
        lda #SFX_TICK
        jsr sfx_play
        jsr et_all
        jmp @loop

et_exit:
        jmp save_write

; et_adjust: Left/Right on row et_sel by et_val.  Carry set if it changed.
et_adjust:
        lda et_sel
        cmp #ET_IGN
        bne :++
        jsr et_ecu
        bne :+
        MOVI16 ptr0, str_et_ecuign
        jmp et_refuse
:       ldy #CR_TIMING
        lda #<-5
        ldx #5
        jmp et_step
:       cmp #ET_TIRE
        bne :+
        ldy #CR_TIREP
        lda #<-14
        ldx #8
        jmp et_step
:       cmp #ET_BOOST
        bne @launch
        jsr cur_car_ptr
        ldy #CR_PARTS+P_TURBO
        lda (ptr1),y
        bne :+
        MOVI16 ptr0, str_et_noturbo
        jmp et_refuse
:       ldy #CR_BOOST           ; try it: tune_calc keeps psi in the turbo's
        lda (ptr1),y            ; range, so no change in psi = at the limit
        sta et_old
        clc
        adc et_val
        sta (ptr1),y
        lda tn_psi
        pha
        jsr car_setup
        pla
        cmp tn_psi
        bne @yes
        jsr cur_car_ptr
        ldy #CR_BOOST
        lda et_old
        sta (ptr1),y
        clc
        rts
@yes:   sec
        rts
@launch:
        cmp #ET_NOS
        bne :++
        jsr et_nos              ; nitrous: needs a kit
        bne :+
        MOVI16 ptr0, str_et_nonos
        jmp et_refuse
:       ldy #CR_NOS             ; -4 power .. +4 duration
        lda #<-4
        ldx #4
        jmp et_step
:       cmp #ET_LAUNCH
        bne @no
        jsr et_ecu
        bne :+
        MOVI16 ptr0, str_et_noecu
        jmp et_refuse
:       ldy #CR_LAUNCH
        lda (ptr1),y
        ldx et_val
        bmi @down
        cmp #0                  ; off -> 2000
        bne :+
        lda #LAUNCH_MIN
        bne @set
:       clc
        adc #2
        sta tmp2
        ldx #1                  ; up to the redline - 500
        lda ph_redl_l,x
        sta m_r
        lda ph_redl_h,x
        sta m_r+1
        lda #100
        jsr div16_8
        lda m_r
        sec
        sbc #5
        cmp tmp2
        bcc @no
        lda tmp2
        jmp @set
@down:  cmp #0
        beq @no
        cmp #LAUNCH_MIN+1       ; 2000 -> off
        bcs :+
        lda #0
        beq @set
:       sbc #2
@set:   pha
        jsr cur_car_ptr
        pla
        ldy #CR_LAUNCH
        sta (ptr1),y
        sec
        rts
@no:    clc
        rts

; et_step: record byte Y += et_val within signed A .. X.  Carry set if changed.
et_step:
        sta tmp2
        stx tmp3
        sty tmp4
        jsr cur_car_ptr
        ldy tmp4
        lda (ptr1),y
        clc
        adc et_val
        sta tmp5
        eor #$80                ; signed compare: flip the sign bits
        sta tmp6
        lda tmp2
        eor #$80
        cmp tmp6
        beq :+
        bcs @no                 ; below the minimum
:       lda tmp3
        eor #$80
        cmp tmp6
        bcc @no                 ; above the maximum
        lda tmp5
        sta (ptr1),y
        sec
        rts
@no:    clc
        rts

; et_msg: ptr0 on row Y inside the box (columns 2-29)
et_msg:
        sty tmp7
        lda #28
        jsr pad_ptr0
        ldx #2
        ldy tmp7
        jmp vb_str

; et_refuse: say why (ptr0) in the box, error sound.  Carry clear.
et_refuse:
        ldy #26
        jsr et_msg
        lda #SFX_ERROR
        jsr sfx_play
        clc
        rts

; et_all: measure the car, then every value and the box (over a few frames)
et_all:
        jsr cur_car_ptr
        jsr car_stats           ; slot 1, m_a = peak hp, tn_* for this tune
        jsr et_power            ; "PEAK 312HP AT 7400 RPM" while m_a is fresh
        lda #ET_IGN
        sta tmp7
@v:     lda tmp7
        jsr et_value
        lda #12
        jsr pad_ptr0
        lda tmp7
        asl a
        clc
        adc #ET_Y0
        tay
        ldx #ET_VX
        jsr vb_str
        jsr wait_frame
        inc tmp7
        lda tmp7
        cmp #ET_NOS+1
        bne @v
        jmp et_status

; et_power: row 23
et_power:
        MOVI16 ptr0, str_et_peak
        ldy #0
        jsr cat_ptr0
        sty tmp6
        jsr num_text            ; m_a = peak hp
        ldy tmp6
        jsr cat_ptr0
        MOVI16 ptr0, str_et_hp
        jsr cat_ptr0
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        ldy #23
        jsr et_msg
        jmp wait_frame

; et_status: row 24, knock / lean
et_status:
        lda tn_knock
        beq :+
        MOVI16 ptr0, str_et_knock
        lda tn_lean
        beq @say
        MOVI16 ptr0, str_et_both
        jmp @say
:       MOVI16 ptr0, str_et_lean
        lda tn_lean
        bne @say
        MOVI16 ptr0, str_et_ok
@say:   ldy #24
        jsr et_msg
        jmp wait_frame

et_needecu:
        MOVI16 ptr0, str_et_needecu
        rts

; et_value: A = row -> ptr0 = its value ("< +2 DEG >")
et_value:
        cmp #ET_IGN
        bne :+
        jsr et_ecu
        beq et_needecu
        ldy #CR_TIMING
        jsr et_rec
        jsr et_open
        jsr et_signed
        MOVI16 ptr0, str_et_deg
        jmp et_close
:       cmp #ET_TIRE
        bne :+
        ldy #CR_TIREP
        jsr et_rec
        clc
        adc #32
        jsr et_open
        jsr et_num
        MOVI16 ptr0, str_et_psi
        jmp et_close
:       cmp #ET_BOOST
        bne @launch
        lda tn_psi
        bne :+
        MOVI16 ptr0, str_et_none
        rts
:       jsr et_open
        jsr et_num
        MOVI16 ptr0, str_et_psi
        jmp et_close
@launch:
        cmp #ET_NOS
        bne :+
        jmp et_nos_value
:       jsr et_ecu
        beq et_needecu
        ldy #CR_LAUNCH
        lda (ptr1),y
        bne :+
        jsr et_open
        MOVI16 ptr0, str_et_off
        jmp et_close
:       sta m_a                 ; rpm/100 -> "4500 RPM"
        lda #100
        sta m_b
        jsr mul8
        lda m_r
        sta m_a
        lda m_r+1
        sta m_a+1
        lda #0
        jsr et_open
        jsr num_text
        ldy tmp6
        jsr cat_ptr0
        sty tmp6
        MOVI16 ptr0, str_et_rpm
        jmp et_close

; et_nos_value: "P---#----D", the nitrous between power and duration, or
; NO NITROUS without a kit
et_nos_value:
        jsr et_nos
        bne :+
        MOVI16 ptr0, str_et_nokit
        rts
:       lda #'P'
        sta linebuf
        ldx #1
        lda #'-'
:       sta linebuf,x
        inx
        cpx #10
        bne :-
        lda #'D'
        sta linebuf+10
        lda #0
        sta linebuf+11
        ldy #CR_NOS             ; the knob: column 5 + n
        lda (ptr1),y
        clc
        adc #5
        tax
        lda #'#'
        sta linebuf,x
        MOVI16 ptr0, linebuf
        rts

; et_nos: A = nitrous kit level of the car in use (Z set: none).  ptr1 = record.
et_nos:
        jsr cur_car_ptr
        ldy #CR_PARTS+P_NITROUS
        lda (ptr1),y
        rts

; et_ecu: A = ECU level of the car in use (Z set: stock ECU).  ptr1 = record.
et_ecu:
        jsr cur_car_ptr
        ldy #CR_PARTS+P_ECU
        lda (ptr1),y
        rts

; et_rec: A = record byte Y of the car in use
et_rec:
        sty tmp4
        jsr cur_car_ptr
        ldy tmp4
        lda (ptr1),y
        rts

; et_open: linebuf = "< " (keeps A), tmp6 = length
et_open:
        pha
        lda #'<'
        sta linebuf
        lda #' '
        sta linebuf+1
        lda #2
        sta tmp6
        pla
        rts

; et_num: append unsigned A
et_num:
        sta m_a
        lda #0
        sta m_a+1
        jsr num_text
        ldy tmp6
        jsr cat_ptr0
        sty tmp6
        rts

; et_signed: append signed A as "+2", "-3" or "0"
et_signed:
        tax
        beq et_num
        ldy tmp6
        lda #'+'
        cpx #$80
        bcc :+
        lda #'-'
:       sta linebuf,y
        iny
        sty tmp6
        txa
        bpl et_num
        eor #$FF
        clc
        adc #1
        jmp et_num

; et_close: append ptr0 and " >"
et_close:
        ldy tmp6
        jsr cat_ptr0
        lda #' '
        sta linebuf,y
        iny
        lda #'>'
        sta linebuf,y
        iny
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        rts

; et_help: rows 26-27 for the selected row
et_help:
        lda et_sel
        asl a
        asl a
        tax
        lda et_helps,x
        sta ptr0
        lda et_helps+1,x
        sta ptr0+1
        txa
        pha
        ldy #26
        jsr et_msg
        jsr wait_frame
        pla
        tax
        lda et_helps+2,x
        sta ptr0
        lda et_helps+3,x
        sta ptr0+1
        ldy #27
        jmp et_msg

et_labels:
        .word str_et0, str_et1, str_et2, str_et3, str_et4, str_et5, str_et8, str_et6, str_et7
str_et0:  .byte "GEAR RATIOS", 0
str_et1:  .byte "FUEL MAP", 0
str_et2:  .byte "IGNITION", 0
str_et3:  .byte "BOOST", 0
str_et4:  .byte "TIRE PRESSURE", 0
str_et5:  .byte "LAUNCH 2-STEP", 0
str_et6:  .byte "RESET ENGINE TUNE", 0
str_et7:  .byte "BACK", 0
str_et8:  .byte "NITROUS", 0
str_et_open:     .byte "A: OPEN", 0
str_et_deg:      .byte " DEG", 0
str_et_psi:      .byte " PSI", 0
str_et_rpm:      .byte " RPM", 0
str_et_off:      .byte "OFF", 0
str_et_none:     .byte "NO TURBO", 0
str_et_needecu:  .byte "NEEDS ECU", 0
str_et_noturbo:  .byte "BUY A TURBO TO SET BOOST", 0
str_et_noecu:    .byte "UPGRADE THE ECU FOR 2-STEP", 0
str_et_nonos:    .byte "BUY NITROUS TO TUNE IT", 0
str_et_nokit:    .byte "NO NITROUS", 0
str_et_ecuign:   .byte "UPGRADE THE ECU FOR TIMING", 0
str_et_ecufuel:  .byte "UPGRADE THE ECU TO MAP FUEL", 0
str_et_peak:     .byte "PEAK ", 0
str_et_hp:       .byte "HP", 0
str_et_ok:       .byte "ENGINE HAPPY", 0
str_et_knock:    .byte "KNOCK! LESS TIMING OR BOOST", 0
str_et_lean:     .byte "LEAN! MORE FUEL OR INJECTORS", 0
str_et_both:     .byte "KNOCKING AND LEAN!", 0
et_helps:
        .word str_eh0a, str_eh0b, str_eh1a, str_eh1b, str_eh2a, str_eh2b
        .word str_eh3a, str_eh3b, str_eh4a, str_eh4b, str_eh5a, str_eh5b
        .word str_eh8a, str_eh8b, str_eh6a, str_eh6b, str_eh7a, str_eh7b
str_eh0a: .byte "FINAL DRIVE AND EACH GEAR", 0
str_eh0b: .byte 0
str_eh1a: .byte "RICH OR LEAN AT EACH RPM", 0
str_eh1b: .byte "(MORE WITH BIGGER INJECTORS)", 0
str_eh2a: .byte "ADVANCE MAKES POWER UNTIL", 0
str_eh2b: .byte "IT KNOCKS. COLD AIR HELPS", 0
str_eh3a: .byte "MORE PSI, MORE POWER. NEEDS", 0
str_eh3b: .byte "FUEL AND CAN MAKE IT KNOCK", 0
str_eh4a: .byte "LOW PSI GRIPS AT LAUNCH", 0
str_eh4b: .byte "BUT DRAGS AT SPEED", 0
str_eh5a: .byte "HOLD A ON THE LINE: THE", 0
str_eh5b: .byte "REVS WAIT HERE FOR GREEN", 0
str_eh6a: .byte "FUEL, TIMING, BOOST, TIRES,", 0
str_eh6b: .byte "2-STEP AND NITROUS TO STOCK", 0
str_eh8a: .byte "LEFT: A BIGGER, SHORTER HIT", 0
str_eh8b: .byte "RIGHT: LESS, FOR LONGER", 0
str_eh7a: .byte 0
str_eh7b: .byte 0

; ===========================================================================
; FUEL MAP: one bar per eighth of the redline.  Up = lean (more power,
; until the injectors run out), down = rich (less power, less knock).
; ===========================================================================
FM_X0 = 4                       ; first column (bars 2 wide, 3 apart)
FM_Y0 = 7                       ; +5 row; 0 on row 12, -5 on row 17
T_FM_LEAN = $03
T_FM_RICH = $02
T_FM_MID  = $05

fuel_screen:
        lda #0
        jsr screen_begin
        jsr use_menu_palette
        MOVI16 ptr0, str_fuel
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
        PRINT str_fm_lean, 28, 7
        PRINT str_fm_rich, 28, 17
        PRINT str_fm_rpm, 28, 18
        PRINT str_fm_help1, 2, 26
        PRINT str_fm_help2, 2, 27
        jsr cur_car_ptr
        jsr car_setup           ; the redline for the rpm labels
        lda #0
        sta fm_k
@col:   jsr fm_bars_direct
        jsr fm_label
        inc fm_k
        lda fm_k
        cmp #NCELLS
        bne @col
        jsr attr_upload
        lda #0
        sta oam_idx
        jsr oam_clear
        jsr ppu_on
        lda fm_sel
        and #NCELLS-1
        sta fm_sel
        jsr fm_info
@loop:  jsr wait_frame
        jsr read_pad
        jsr fm_cursor
        lda pad_rpt
        and #BTN_LEFT
        beq :+
        lda fm_sel
        sec
        sbc #1
        jmp @move
:       lda pad_rpt
        and #BTN_RIGHT
        beq :+
        lda fm_sel
        clc
        adc #1
@move:  and #NCELLS-1
        sta fm_sel
        lda #SFX_MOVE
        jsr sfx_play
        jsr fm_cell_info
        jmp @loop
:       lda pad_rpt
        and #BTN_UP
        beq :+
        lda #1
        bne @chg
:       lda pad_rpt
        and #BTN_DOWN
        beq :+
        lda #$FF
@chg:   sta et_val
        lda fm_sel
        clc
        adc #CR_FUEL
        tay
        lda #<-5
        ldx #5
        jsr et_step
        bcc @loop
        lda fm_sel
        sta fm_k
        jsr fm_changed
        jmp @loop
:       lda pad_new
        and #BTN_A              ; A: this cell's value in every cell
        beq @nota
        jsr cur_car_ptr
        lda fm_sel
        clc
        adc #CR_FUEL
        tay
        lda (ptr1),y
        jmp @fill
@nota:  lda pad_new
        and #BTN_SELECT         ; SELECT: all back to 0
        beq @notsel
        jsr cur_car_ptr
        lda #0
@fill:  ldy #CR_FUEL
@fl:    sta (ptr1),y
        iny
        cpy #CR_FUEL+NCELLS
        bne @fl
        lda #SFX_SELECT
        jsr sfx_play
        jsr fm_redraw
        jmp @loop
@notsel:
        lda pad_new
        and #BTN_B
        jeq @loop
        lda #SFX_BACK
        jsr sfx_play
        jmp save_write

; fm_changed: cell fm_k changed: save, redraw it, re-measure
fm_changed:
        jsr save_write
        lda #SFX_TICK
        jsr sfx_play
        jsr fm_bars_vb
        jmp fm_info

; fm_redraw: every column, then the numbers
fm_redraw:
        jsr save_write
        lda #0
        sta fm_k
:       jsr fm_bars_vb
        inc fm_k
        lda fm_k
        cmp #NCELLS
        bne :-
        jmp fm_info

; fm_cell: A = row (0-10) of column fm_k -> A = tile
fm_cell:
        sta tmp5
        jsr cur_car_ptr
        lda fm_k
        clc
        adc #CR_FUEL
        tay
        lda (ptr1),y
        sta tmp4                ; f
        lda #5
        sec
        sbc tmp5                ; v = 5 - row
        beq @mid
        bmi @rich
        ; lean side: filled if f >= v
        cmp tmp4
        beq @lean
        bcs @empty              ; v > f (f may be negative: unsigned would lie)
        lda tmp4
        bmi @empty
@lean:  lda #T_FM_LEAN
        rts
@rich:  ; filled if f <= v (both negative)
        sta tmp5
        lda tmp4
        bpl @empty
        cmp tmp5
        beq :+
        bcs @empty
:       lda #T_FM_RICH
        rts
@mid:   lda #T_FM_MID
        rts
@empty: lda #' '
        rts

; fm_pair: A = tile -> linebuf = two of it
fm_pair:
        sta linebuf
        sta linebuf+1
        lda #0
        sta linebuf+2
        MOVI16 ptr0, linebuf
        rts

; fm_x: X = screen column of cell fm_k
fm_x:
        lda fm_k
        asl a
        adc fm_k
        adc #FM_X0
        tax
        rts

; fm_bars_direct: column fm_k with the PPU off
fm_bars_direct:
        lda #0
        sta fm_r
:       lda fm_r
        jsr fm_cell
        jsr fm_pair
        jsr fm_x
        lda fm_r
        clc
        adc #FM_Y0
        tay
        jsr print
        inc fm_r
        lda fm_r
        cmp #11
        bne :-
        rts

; fm_bars_vb: the same through the VRAM queue, four rows a frame
fm_bars_vb:
        lda #0
        sta fm_r
:       lda fm_r
        jsr fm_cell
        jsr fm_pair
        jsr fm_x
        lda fm_r
        clc
        adc #FM_Y0
        tay
        jsr vb_str
        inc fm_r
        lda fm_r
        and #3
        bne :+
        jsr wait_frame
        jsr fm_cursor
:       lda fm_r
        cmp #11
        bne :--
        jmp wait_frame

; fm_label: the cell's number under its bar on row 18, PPU off
fm_label:
        lda fm_k
        clc
        adc #'1'
        jsr fm_pair
        lda #' '
        sta linebuf+1
        jsr fm_x
        ldy #18
        jmp print

; fm_rpm_part: ptr0 = "d.d" for A * redline / 16 (thousands of rpm)
fm_rpm_part:
        sta m_a
        lda #0
        sta m_a+1
        ldx #1
        lda ph_redl_l,x
        sta m_b
        lda ph_redl_h,x
        sta m_b+1
        jsr mul16
        ldx #4
:       lsr m_r+2
        ror m_r+1
        ror m_r
        dex
        bne :-
        clc                     ; hundreds of rpm, rounded
        lda m_r
        adc #50
        sta m_r
        bcc :+
        inc m_r+1
:       lda #100
        jsr div16_8
        lda #10
        jsr div16_8             ; m_r = thousands, A = tenths
        ldx m_r
        cpx #10                 ; (one digit: 10000+ shows as 9.9)
        bcc :+
        lda #9
        sta m_r
:       ora #'0'
        sta linebuf+2
        lda m_r
        ora #'0'
        sta linebuf
        lda #'.'
        sta linebuf+1
        lda #0
        sta linebuf+3
        MOVI16 ptr0, linebuf
        rts

; fm_info: re-measure, then values, status, the selected cell and power
fm_info:
        jsr cur_car_ptr
        jsr car_stats
        jsr et_power
        ; row 19: every cell's value, row 20: OK / K! / L!
        lda #0
        sta fm_k
        lda #' '
        ldx #31
:       sta padbuf,x            ; (two rows of 28 built in padbuf/linebuf)
        dex
        bpl :-
@v:     jsr fm_x
        txa
        sec
        sbc #FM_X0
        sta tmp7                ; offset in the row
        jsr cur_car_ptr
        lda fm_k
        clc
        adc #CR_FUEL
        tay
        lda (ptr1),y
        ldx tmp7
        cmp #0
        bne :+
        lda #' '
        sta padbuf,x
        lda #'0'
        sta padbuf+1,x
        jmp @st
:       ldy #'+'
        cmp #$80
        bcc :+
        ldy #'-'
        eor #$FF
        clc
        adc #1
:       ora #'0'
        sta padbuf+1,x
        tya
        sta padbuf,x
@st:    inc fm_k
        lda fm_k
        cmp #NCELLS
        bne @v
        lda #0
        sta padbuf+24
        MOVI16 ptr0, padbuf
        ldx #FM_X0
        ldy #19
        jsr vb_str
        jsr wait_frame
        ; status row
        ldx #0
        lda #1
        sta tmp5                ; cell bit
@s:     lda #'O'
        sta linebuf,x
        lda #'K'
        sta linebuf+1,x
        lda tn_knock
        and tmp5
        beq :+
        lda #'K'
        sta linebuf,x
        lda #'!'
        sta linebuf+1,x
:       lda tn_lean
        and tmp5
        beq :+
        lda #'L'
        sta linebuf,x
        lda #'!'
        sta linebuf+1,x
:       lda #' '
        sta linebuf+2,x
        inx
        inx
        inx
        asl tmp5
        bne @s
        lda #0
        sta linebuf+23
        MOVI16 ptr0, linebuf
        ldx #FM_X0
        ldy #20
        jsr vb_str
        jsr wait_frame
        jmp fm_cell_info

; fm_cell_info: row 22: "2.7-3.6K RPM  AFR 12.8"
fm_cell_info:
        lda fm_sel
        asl a                   ; start: 2k/16 of the redline
        jsr fm_rpm_part
        lda linebuf
        pha
        lda linebuf+2
        pha
        lda fm_sel
        asl a
        adc #2                  ; end
        jsr fm_rpm_part
        lda linebuf             ; "s.s-e.eK RPM  AFR "
        sta padbuf+4
        lda linebuf+2
        sta padbuf+6
        pla
        sta padbuf+2
        pla
        sta padbuf
        lda #'.'
        sta padbuf+1
        sta padbuf+5
        lda #'-'
        sta padbuf+3
        ldx #0
:       lda str_fm_afr,x
        sta padbuf+7,x
        beq :+
        inx
        bne :-
:       ; AFR x10 = 125 + 3f  ("12.8")
        jsr cur_car_ptr
        lda fm_sel
        clc
        adc #CR_FUEL
        tay
        lda (ptr1),y
        sta tmp4
        asl a
        clc
        adc tmp4
        clc
        adc #125
        sta m_r
        lda #0
        sta m_r+1
        lda #10
        jsr div16_8
        ora #'0'
        sta padbuf+7+14
        lda #'.'
        sta padbuf+7+13
        lda m_r
        sta m_a
        lda #0
        sta m_a+1
        jsr num_text
        ldy #0
        lda (ptr0),y
        sta padbuf+7+11
        iny
        lda (ptr0),y
        sta padbuf+7+12
        lda #0
        sta padbuf+7+15
        MOVI16 ptr0, padbuf
        ldy #22
        jsr et_msg
        jmp wait_frame

; fm_cursor: arrow over the selected column (sprite 0)
fm_cursor:
        lda fm_k                ; (keeps fm_k: redraw loops use it)
        pha
        lda fm_sel
        sta fm_k
        jsr fm_x
        pla
        sta fm_k
        txa
        asl a
        asl a
        asl a
        clc
        adc #4
        sta oam+3
        lda #FM_Y0*8-10
        sta oam
        lda #$08                ; down arrow
        sta oam+1
        lda #2
        sta oam+2
        rts

str_fuel:     .byte "FUEL MAP", 0
str_fm_lean:  .byte "LEAN", 0
str_fm_rich:  .byte "RICH", 0
str_fm_rpm:   .byte "CELL", 0
str_fm_afr:   .byte "K RPM  AFR ", 0
str_fm_help1: .byte "L/R:CELL  U/D:LEAN/RICH", 0
str_fm_help2: .byte "A:SAME FOR ALL  SEL:ZERO", 0
