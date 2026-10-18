; ===========================================================================
; cardata.s -- car, part and sound tables (fixed bank).  The numbers come from
; tools/gamedata.py through tools/mkdata.py.
; ===========================================================================
.include "build/cardata.inc"

; part and level names (12 chars max)
part_names:
        .byte "INTAKE     ", 0
        .byte "EXHAUST    ", 0
        .byte "ECU TUNE   ", 0
        .byte "TURBO      ", 0
        .byte "INTERNALS  ", 0
        .byte "NITROUS    ", 0
        .byte "GEARBOX    ", 0
        .byte "TIRES      ", 0
        .byte "SUSPENSION ", 0
        .byte "WEIGHT CUT ", 0
        .byte "INTERCOOLER", 0
        .byte "AERO KIT   ", 0
        .byte "WHEELIE BAR", 0
        .byte "INJECTORS  ", 0
level_names:
        .byte "STOCK ", 0
        .byte "STREET", 0
        .byte "SPORT ", 0
        .byte "RACE  ", 0
        .byte "PRO   ", 0
drive_names:
        .byte "FWD", 0, "RWD", 0, "AWD", 0, "AWD", 0

; car_name_ptr: A = model -> ptr0 = name (13 bytes per entry)
car_name_ptr:
        sta m_a
        lda #13
        sta m_b
        jsr mul8
        clc
        lda m_r
        adc #<car_names
        sta ptr0
        lda m_r+1
        adc #>car_names
        sta ptr0+1
        rts

; part_name_ptr: A = part -> ptr0 (12 bytes per entry)
part_name_ptr:
        asl a
        asl a
        sta tmp0
        asl a
        clc
        adc tmp0                ; *12
        clc
        adc #<part_names
        sta ptr0
        lda #>part_names
        adc #0
        sta ptr0+1
        rts

; level_name_ptr: A = level -> ptr0 (7 bytes per entry)
level_name_ptr:
        sta tmp0
        asl a
        asl a
        asl a
        sec
        sbc tmp0
        clc
        adc #<level_names
        sta ptr0
        lda #>level_names
        adc #0
        sta ptr0+1
        rts

; drive_name_ptr: A = drive -> ptr0
drive_name_ptr:
        asl a
        asl a
        clc
        adc #<drive_names
        sta ptr0
        lda #>drive_names
        adc #0
        sta ptr0+1
        rts

; part_price: A = part, X = tier, Y = level (1-4) -> m_a (24-bit).  Each
; part is priced by how much speed it adds (PART_WEIGHT in gamedata.py).
; Clobbers tmp0, tmp1, ptr3, X, Y.
part_price:
        sty tmp1
        pha
        txa
        asl a
        asl a
        sta tmp0
        txa
        clc
        adc tmp0                ; tier*5
        adc tmp1                ;  + level
        asl a                   ; words
        sta tmp0
        pla
        tax
        lda part_cost_lo,x
        sta ptr3
        lda part_cost_hi,x
        sta ptr3+1
        ldy tmp0
        lda (ptr3),y            ; $10 units
        sta m_a
        iny
        lda (ptr3),y
        sta m_a+1
        lda #10
        sta m_b
        lda #0
        sta m_b+1
        jsr mul16
        lda m_r
        sta m_a
        lda m_r+1
        sta m_a+1
        lda m_r+2
        sta m_a+2
        rts

; car_price: A = model -> m_a (24-bit)
car_price:
        tax
        lda car_price0,x
        sta m_a
        lda car_price1,x
        sta m_a+1
        lda car_price2,x
        sta m_a+2
        rts

; init_record: build a stock car record for model A at ptr1 (32 bytes)
init_record:
        sta tmp0
        ldy #CR_SIZE-1
        lda #0
@z:     sta (ptr1),y
        dey
        bpl @z
        ldy #CR_MODEL
        lda tmp0
        sta (ptr1),y
        ldy #CR_PAINT
        lda #$16                ; red
        sta (ptr1),y
        iny
        lda #$10                ; silver rims
        sta (ptr1),y
        iny
        lda #$21                ; light blue glass
        sta (ptr1),y
        ldx tmp0
        ldy #CR_FINAL
        lda car_final_l,x
        sta (ptr1),y
        iny
        lda car_final_h,x
        sta (ptr1),y
        ; gears: car_gearset + model*14
        lda tmp0
        sta m_a
        lda #14
        sta m_b
        jsr mul8
        clc
        lda m_r
        adc #<car_gearset
        sta ptr2
        lda m_r+1
        adc #>car_gearset
        sta ptr2+1
        ldy #0
@g:     lda (ptr2),y
        sty tmp1
        pha
        tya
        clc
        adc #CR_GEARS
        tay
        pla
        sta (ptr1),y
        ldy tmp1
        iny
        cpy #14
        bne @g
        rts
