; ===========================================================================
; swap.s -- the SWAP screen (bank 6): engine and drivetrain swaps, paid in
; gems.  What a swap does to the car is in tune.s (tune_calc).
;
;   engine      any dealer car's engine or a crate engine (eng_* tables,
;               from tools/gamedata.py).  The old engine's parts go back to
;               stock and are bought back at 3/4 of what they cost, and the
;               engine tune (fuel map, timing, boost, 2-step, nitrous) is reset.
;   drivetrain  FWD, RWD or AWD for DRIVE_GEMS.
;   Going back to the car's own engine or drivetrain is free.  The crate
;   car can't be swapped.
; ===========================================================================

.segment "BSS"
sw_sel:     .res 1          ; row
sw_e:       .res 1          ; engine being looked at (index into swap_eng)
sw_d:       .res 1          ; drivetrain being looked at
sw_line:    .res 1          ; info line being drawn
sw_cost:    .res 1
sw_tier:    .res 1
sw_p:       .res 1
sw_pt:      .res 1
sw_l:       .res 1
sw_acc:     .res 3
sw_q:       .res 3
.segment "BANK6"

SW_X  = 3                       ; labels
SW_VX = 14                      ; values
SW_Y0 = 9                       ; rows 9, 11, 13
SW_N  = 3
SW_ENG  = 0
SW_DRV  = 1
SW_BACK = 2
SW_IY = 17                      ; info box lines 17-22
SW_MY = 24                      ; message line

; ---------------------------------------------------------------------------
; swap_screen
; ---------------------------------------------------------------------------
swap_screen:
        lda #0
        jsr screen_begin
        jsr use_menu_palette
        MOVI16 ptr0, str_swap
        jsr draw_header
        jsr cur_car_ptr
        jsr car_name_ptr
        lda #$20
        sta text_attr
        ldx #2
        ldy #5
        jsr print
        lda #0
        sta text_attr
        jsr cur_car_ptr
        ldy #6
        jsr stats_line
        jsr print
        PRINT str_sw0, SW_X, SW_Y0
        PRINT str_sw1, SW_X, SW_Y0+2
        PRINT str_sw2, SW_X, SW_Y0+4
        BOX 1, 16, 30, 11
        jsr attr_upload
        lda #0
        sta oam_idx
        jsr oam_clear
        jsr ppu_on
        ; start on what's fitted
        jsr sw_engine
        ldx #NSWAP_ENG-1
:       cmp swap_eng,x
        beq :+
        dex
        bne :-
:       stx sw_e
        jsr sw_drive
        sta sw_d
        lda #0
        sta sw_sel
        sta ui_sel
        lda #SW_N
        sta ui_count
        lda #SW_X-2
        sta ui_x
        lda #1
        sta ui_cols
        lda #SW_Y0
        sta ui_y0
        lda #2
        sta ui_dy
        jsr sw_values
        jsr sw_info
@loop:  jsr wait_frame
        jsr read_pad
        jsr list_cursor
        jsr list_select
        ldx ui_sel
        stx sw_sel
        cmp #3
        bne :+
        jsr sw_clear_msg
        jsr sw_info
        jmp @loop
:       cmp #2
        beq @exit
        cmp #6
        beq @left
        cmp #7
        beq @right
        cmp #1
        bne @loop
        lda sw_sel
        cmp #SW_BACK
        beq @exit
        jsr sw_locked
        bcs @loop
        lda sw_sel
        bne :+
        jsr sw_buy_engine
        jmp @loop
:       jsr sw_buy_drive
        jmp @loop
@exit:  rts
@left:  lda #$FF
        bne :+
@right: lda #1
:       sta tmp7
        lda sw_sel
        cmp #SW_BACK
        beq @loop
        jsr sw_locked
        bcs @loop
        lda sw_sel
        bne @drv
        clc                     ; engines wrap around the list
        lda sw_e
        adc tmp7
        bpl :+
        lda #NSWAP_ENG-1
:       cmp #NSWAP_ENG
        bcc :+
        lda #0
:       sta sw_e
        jmp @moved
@drv:   clc                     ; FWD, RWD, AWD
        lda sw_d
        adc tmp7
        bpl :+
        lda #2
:       cmp #3
        bcc :+
        lda #0
:       sta sw_d
@moved: lda #SFX_TICK
        jsr sfx_play
        jsr sw_clear_msg
        jsr sw_values
        jsr sw_info
        jmp @loop

; sw_locked: the crate car can't be swapped: say so, carry set
sw_locked:
        jsr cur_car_ptr
        cmp #CRATE_CAR
        bne :+
        MOVI16 ptr0, str_sw_x400
        jsr sw_refuse
        sec
        rts
:       clc
        rts

; sw_engine: A = engine id in use.  sw_drive: A = drivetrain in use.
; (ptr1 = record)
sw_engine:
        jsr cur_car_ptr         ; A = model
        tax
        ldy #CR_SWAP
        lda (ptr1),y
        and #SWAP_ENG
        beq :+
        tax
        dex
:       txa
        rts
sw_drive:
        jsr cur_car_ptr
        tax
        ldy #CR_SWAP
        lda (ptr1),y
        and #SWAP_DRV
        beq :+
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        sec
        sbc #1
        rts
:       lda car_drive,x
        rts

; eng_name_ptr: A = engine id -> ptr0 (13 bytes per name)
eng_name_ptr:
        sta m_a
        lda #13
        sta m_b
        jsr mul8
        clc
        lda m_r
        adc #<eng_names
        sta ptr0
        lda m_r+1
        adc #>eng_names
        sta ptr0+1
        rts

; sw_values: "< TWIN ROTOR   >" and "< AWD >" (or LOCKED for the crate car)
sw_values:
        jsr cur_car_ptr
        cmp #CRATE_CAR
        bne :+
        MOVI16 ptr0, str_sw_locked
        jsr sw_val
        jsr wait_frame
        MOVI16 ptr0, str_sw_locked
        lda #2
        jmp sw_val2
:       ldx sw_e
        lda swap_eng,x
        jsr eng_name_ptr
        jsr sw_arrows
        jsr sw_val
        jsr wait_frame
        lda sw_d
        jsr drive_name_ptr
        jsr sw_arrows
        lda #2
sw_val2:
        clc
        adc #SW_Y0
        tay
        jmp sw_val_y
sw_val:
        ldy #SW_Y0
sw_val_y:
        sty tmp7
        lda #16
        jsr pad_ptr0
        ldx #SW_VX
        ldy tmp7
        jmp vb_str

; sw_arrows: linebuf = "< " + ptr0 (trailing spaces trimmed) + " >"; ptr0 -> it
sw_arrows:
        lda #'<'
        sta linebuf
        lda #' '
        sta linebuf+1
        ldy #2
        jsr cat_ptr0
:       dey                     ; names are padded to 12: trim them
        lda linebuf,y
        cmp #' '
        beq :-
        iny
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

; ---------------------------------------------------------------------------
; sw_info: the box, one line a frame
; ---------------------------------------------------------------------------
sw_info:
        lda #0
        sta sw_line
@line:  jsr cur_car_ptr
        cmp #CRATE_CAR
        bne :+
        lda sw_line             ; the crate car: one line
        bne @blank
        MOVI16 ptr0, str_sw_x400
        jmp @put
:       lda sw_sel
        cmp #SW_BACK
        beq @blank
        asl a                   ; row * 6 + line -> handler
        sta tmp7
        asl a
        adc tmp7
        asl a                   ; *12 (words)
        sta tmp7
        lda sw_line
        asl a
        adc tmp7
        tax
        lda sw_lines,x
        sta ptr2
        lda sw_lines+1,x
        sta ptr2+1
        jsr @call
        jmp @put
@blank: MOVI16 ptr0, str_sw_none
@put:   lda sw_line
        bne :+
        lda #$20                ; first line in yellow
        sta text_attr
:       lda #28
        jsr pad_ptr0
        lda sw_line
        clc
        adc #SW_IY
        tay
        ldx #2
        jsr vb_str
        lda #0
        sta text_attr
        jsr wait_frame
        inc sw_line
        lda sw_line
        cmp #6
        bne @line
        rts
@call:  jmp (ptr2)

sw_lines:
        .word si_ename, si_espec, si_ekg, si_estat, si_eparts, si_none
        .word si_dname, si_d1, si_d2, si_dstat, si_none, si_none

si_none:
        MOVI16 ptr0, str_sw_none
        rts
si_ename:
        ldx sw_e
        lda swap_eng,x
        jmp eng_name_ptr
si_espec:                       ; "255HP  9000 RPM"
        ldx sw_e
        ldy swap_eng,x
        lda eng_hp_l,y
        sta m_a
        lda eng_hp_h,y
        sta m_a+1
        jsr num_text
        ldy #0
        jsr cat_ptr0
        sty tmp6
        MOVI16 ptr0, str_sw_hp
        ldy tmp6
        jsr cat_ptr0
        sty tmp6
        ldx sw_e
        ldy swap_eng,x
        lda eng_redline_l,y
        sta m_a
        lda eng_redline_h,y
        sta m_a+1
        jsr num_text
        ldy tmp6
        jsr cat_ptr0
        sty tmp6
        MOVI16 ptr0, str_sw_rpm
        jmp si_end
si_ekg:                         ; "WEIGHS 106KG"
        MOVI16 ptr0, str_sw_weighs
        ldy #0
        jsr cat_ptr0
        sty tmp6
        ldx sw_e
        ldy swap_eng,x
        lda eng_kg2,y
        asl a
        sta m_a
        lda #0
        rol a
        sta m_a+1
        jsr num_text
        ldy tmp6
        jsr cat_ptr0
        sty tmp6
        MOVI16 ptr0, str_sw_kg
        jmp si_end
si_estat:
        jsr sw_engine
        ldx sw_e
        cmp swap_eng,x
        jeq si_fitted
        jsr cur_car_ptr
        ldx sw_e
        cmp swap_eng,x
        jeq si_free
        ldy swap_eng,x          ; locked below its level?
        lda SV_LEVEL
        cmp eng_level,y
        bcs :+
        lda eng_level,y
        jmp si_level
:       lda eng_gems,y
        jmp si_gems
si_eparts:
        jsr sw_engine
        ldx sw_e
        cmp swap_eng,x
        jeq si_none
        MOVI16 ptr0, str_sw_parts
        rts
si_dname:
        lda sw_d
        jmp drive_name_ptr
si_d1:
        lda sw_d
        asl a
        tax
        lda sw_dtext,x
        sta ptr0
        lda sw_dtext+1,x
        sta ptr0+1
        rts
si_d2:
        lda sw_d
        asl a
        tax
        lda sw_dtext+6,x
        sta ptr0
        lda sw_dtext+7,x
        sta ptr0+1
        rts
si_dstat:
        jsr sw_drive
        cmp sw_d
        beq si_fitted
        jsr cur_car_ptr
        tax
        lda car_drive,x
        cmp sw_d
        beq si_free
        lda #DRIVE_GEMS
si_gems:                        ; "A: SWAP FOR 10 GEMS"
        sta m_a
        MOVI16 ptr0, str_sw_for
        ldy #0
        jsr cat_ptr0
        sty tmp6
        lda #0
        sta m_a+1
        jsr num_text
        ldy tmp6
        jsr cat_ptr0
        sty tmp6
        MOVI16 ptr0, str_sw_gems
        jmp si_end
si_level:                       ; "REACH LEVEL 10"
        sta m_a
        MOVI16 ptr0, str_sw_reach
        ldy #0
        jsr cat_ptr0
        sty tmp6
        lda #0
        sta m_a+1
        jsr num_text
si_end: ldy tmp6
        jsr cat_ptr0
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        rts
si_fitted:
        MOVI16 ptr0, str_sw_fitted
        rts
si_free:
        MOVI16 ptr0, str_sw_free
        rts

sw_dtext:
        .word str_sw_f1, str_sw_r1, str_sw_a1
        .word str_sw_f2, str_sw_r2, str_sw_a2

; ---------------------------------------------------------------------------
; Buying
; ---------------------------------------------------------------------------
; sw_buy_engine: fit the engine being looked at
sw_buy_engine:
        jsr sw_engine
        ldx sw_e
        cmp swap_eng,x
        bne :+
        MOVI16 ptr0, str_sw_already
        jmp sw_refuse
:       jsr cur_car_ptr
        ldx sw_e
        cmp swap_eng,x
        beq @free               ; back to its own engine
        ldy swap_eng,x
        lda SV_LEVEL
        cmp eng_level,y
        bcs :+
        MOVI16 ptr0, str_sw_level
        jmp sw_refuse
:       lda eng_gems,y
        jsr sw_pay
        bcs @free
        rts
@free:  jsr cur_car_ptr
        jsr sw_refund           ; old engine's parts: back to stock, 3/4 back
        ldy #CR_FUEL            ; and its tune: fuel map, timing,
        lda #0
:       sta (ptr1),y
        iny
        cpy #CR_TIMING+1
        bne :-
        ldy #CR_BOOST           ; boost, 2-step and nitrous
        sta (ptr1),y
        iny
        sta (ptr1),y
        iny
        sta (ptr1),y
        jsr cur_car_ptr         ; A = model
        ldx sw_e
        cmp swap_eng,x
        beq :+                  ; own engine: 0
        lda swap_eng,x
        clc
        adc #1
        .byte $2C               ; (skip the lda #0)
:       lda #0
        sta sw_cost
        ldy #CR_SWAP            ; keep the drivetrain bits
        lda (ptr1),y
        and #SWAP_DRV
        ora sw_cost
        sta (ptr1),y
        ldx #2
:       lda sw_acc,x
        sta m_a,x
        dex
        bpl :-
        jsr cash_add
        jsr save_write
        ; "SWAPPED! PARTS BACK: $1234"
        MOVI16 ptr0, str_sw_done
        ldy #0
        jsr cat_ptr0
        sty tmp6
        ldx #2
:       lda sw_acc,x
        sta m_a,x
        dex
        bpl :-
        jsr money_text
        ldy tmp6
        jsr cat_ptr0
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        jmp sw_bought

; sw_buy_drive: fit the drivetrain being looked at
sw_buy_drive:
        jsr sw_drive
        cmp sw_d
        bne :+
        MOVI16 ptr0, str_sw_already
        jmp sw_refuse
:       jsr cur_car_ptr
        tax
        lda car_drive,x
        cmp sw_d
        beq @free
        lda #DRIVE_GEMS
        jsr sw_pay
        bcs @free
        rts
@free:  jsr cur_car_ptr
        tax
        lda car_drive,x
        cmp sw_d
        beq :+
        ldx sw_d
        inx
        txa
        asl a                   ; into bits 5-6
        asl a
        asl a
        asl a
        asl a
        .byte $2C
:       lda #0
        sta sw_cost
        ldy #CR_SWAP            ; keep the engine bits
        lda (ptr1),y
        and #SWAP_ENG
        ora sw_cost
        sta (ptr1),y
        jsr save_write
        MOVI16 ptr0, str_sw_swapped
sw_bought:
        ldy #SW_MY
        jsr sw_msg
        lda #SFX_SELECT
        jsr sfx_play
        jsr wait_frame
        jsr header_update
        jsr wait_frame
        jsr cur_car_ptr         ; the car's new figures
        ldy #6
        jsr stats_line
        jsr vb_str
        jsr wait_frame
        jmp sw_info

; sw_pay: A = gems.  Carry set and paid, or carry clear (and said why).
sw_pay:
        sta sw_cost
        lda SV_GEMS+1
        bne :+
        lda SV_GEMS
        cmp sw_cost
        bcs :+
        MOVI16 ptr0, str_sw_nogems
        jmp sw_refuse
:       sec
        lda SV_GEMS
        sbc sw_cost
        sta SV_GEMS
        lda SV_GEMS+1
        sbc #0
        sta SV_GEMS+1
        sec
        rts

; sw_refund: ptr1 = record.  Every engine part goes back to stock; sw_acc =
; SWAP_REFUND/4 of what its levels cost.
sw_refund:
        lda #0
        sta sw_acc
        sta sw_acc+1
        sta sw_acc+2
        sta sw_p
        ldy #CR_MODEL
        lda (ptr1),y
        tax
        lda car_tier,x
        sta sw_tier
@part:  ldx sw_p
        lda eng_parts,x
        sta sw_pt
        clc
        adc #CR_PARTS
        tay
        lda (ptr1),y
        sta sw_l
        lda #0
        sta (ptr1),y
@lvl:   lda sw_l
        beq @next
        tay
        ldx sw_tier
        lda sw_pt
        jsr part_price          ; m_a = this level's price
        ldx #2
:       lda m_a,x
        sta sw_q,x
        dex
        bpl :-
        lsr sw_q+2              ; price - price/4
        ror sw_q+1
        ror sw_q
        lsr sw_q+2
        ror sw_q+1
        ror sw_q
        sec
        ldx #0
        ldy #3
:       lda m_a,x
        sbc sw_q,x
        sta m_a,x
        inx
        dey
        bne :-
        clc
        ldx #0
        ldy #3
:       lda sw_acc,x
        adc m_a,x
        sta sw_acc,x
        inx
        dey
        bne :-
        dec sw_l
        jmp @lvl
@next:  inc sw_p
        lda sw_p
        cmp #NENG_PARTS
        bne @part
        rts

; sw_refuse: ptr0 on the message line, error sound
sw_refuse:
        ldy #SW_MY
        jsr sw_msg
        lda #SFX_ERROR
        jsr sfx_play
        clc
        rts

sw_clear_msg:
        MOVI16 ptr0, str_sw_none
        ldy #SW_MY
; sw_msg: ptr0 on row Y inside the box (columns 2-29)
sw_msg:
        sty tmp7
        lda #28
        jsr pad_ptr0
        ldx #2
        ldy tmp7
        jmp vb_str

str_swap:       .byte "SWAP", 0
str_sw0:        .byte "ENGINE", 0
str_sw1:        .byte "DRIVETRAIN", 0
str_sw2:        .byte "BACK", 0
str_sw_none:    .byte 0
str_sw_locked:  .byte "LOCKED", 0
str_sw_x400:    .byte "THE X400 CAN'T BE SWAPPED", 0
str_sw_hp:      .byte "HP  ", 0
str_sw_rpm:     .byte " RPM", 0
str_sw_weighs:  .byte "WEIGHS ", 0
str_sw_kg:      .byte "KG", 0
str_sw_for:     .byte "A: SWAP FOR ", 0
str_sw_gems:    .byte " GEMS", 0
str_sw_reach:   .byte "REACH LEVEL ", 0
str_sw_fitted:  .byte "FITTED", 0
str_sw_free:    .byte "A: SWAP BACK (FREE)", 0
str_sw_parts:   .byte "OLD ENGINE PARTS: 3/4 BACK", 0
str_sw_already: .byte "ALREADY FITTED", 0
str_sw_level:   .byte "YOUR LEVEL IS TOO LOW", 0
str_sw_nogems:  .byte "NOT ENOUGH GEMS", 0
str_sw_done:    .byte "SWAPPED! PARTS BACK: ", 0
str_sw_swapped: .byte "SWAPPED!", 0
str_sw_f1:      .byte "LIGHTEST, BUT THE LEAST", 0
str_sw_f2:      .byte "GRIP AT LAUNCH", 0
str_sw_r1:      .byte "THE BALANCE: SOME WEIGHT,", 0
str_sw_r2:      .byte "GOOD LAUNCH GRIP", 0
str_sw_a1:      .byte "LAUNCHES HARDEST, BUT HEAVY", 0
str_sw_a2:      .byte "AND LOSES A LITTLE POWER", 0
