; ===========================================================================
; save.s -- battery-backed save in WRAM (fixed bank)
; ===========================================================================

save_magic: .byte "PXR1"

; save_load: keep a valid save, otherwise start a new game
save_load:
        ldx #3
@m:     lda SAVE_MAGIC,x
        cmp save_magic,x
        bne new_game
        dex
        bpl @m
        jsr save_sum
        lda tmp0
        cmp SV_SUM
        bne new_game
        lda tmp1
        cmp SV_SUM+1
        bne new_game
        rts

; new_game: wipe the save and give the player a starter car
new_game:
        lda #0
        tax
@z:     sta $6000,x
        sta $6100,x
        inx
        bne @z
        ldx #3
@m:     lda save_magic,x
        sta SAVE_MAGIC,x
        dex
        bpl @m
        lda #<3000
        sta SV_CASH
        lda #>3000
        sta SV_CASH+1
        lda #5
        sta SV_GEMS
        lda #1
        sta SV_LEVEL
        lda frame
        eor rng
        sta SV_SEED
        lda #$5A
        sta SV_SEED+1
        ; empty slots
        ldx #NSLOTS-1
@e:     txa
        jsr slot_ptr
        ldy #CR_MODEL
        lda #$FF
        sta (ptr1),y
        dex
        bpl @e
        ; starter car in slot 0
        lda #0
        jsr slot_ptr
        lda #0
        jsr init_record
        ldy #CR_PAINT
        lda #$27                ; orange
        sta (ptr1),y
        ; fall through to save
; save_write: update the checksum
save_write:
        lda rng
        sta SV_SEED
        lda rng+1
        sta SV_SEED+1
        jsr save_sum
        lda tmp0
        sta SV_SUM
        lda tmp1
        sta SV_SUM+1
        rts

; save_sum: tmp0/tmp1 = 16-bit sum of $6004..SV_END-1 (rotating)
save_sum:
        lda #0
        sta tmp0
        sta tmp1
        MOVI16 ptr2, $6004
@l:     ldy #0
        lda (ptr2),y
        clc
        adc tmp0
        sta tmp0
        lda tmp1
        adc #0
        asl tmp0                ; mix bits so swapped bytes change the sum
        rol a
        sta tmp1
        bcc :+
        inc tmp0
:       inc ptr2
        bne :+
        inc ptr2+1
:       lda ptr2
        cmp #<SV_END
        bne @l
        lda ptr2+1
        cmp #>SV_END
        bne @l
        rts

; slot_ptr: A = slot -> ptr1 = SV_CARS + slot*32  (preserves X)
slot_ptr:
        asl a
        asl a
        asl a
        asl a
        asl a
        clc
        adc #<SV_CARS
        sta ptr1
        lda #>SV_CARS
        adc #0
        sta ptr1+1
        rts

; cur_car_ptr: ptr1 = record of the car in use, A = its model
cur_car_ptr:
        lda SV_CURCAR
        jsr slot_ptr
        ldy #CR_MODEL
        lda (ptr1),y
        rts

; free_slot: carry clear and A = first empty slot; carry set if garage full
free_slot:
        ldx #0
@l:     txa
        jsr slot_ptr
        ldy #CR_MODEL
        lda (ptr1),y
        cmp #$FF
        beq @found
        inx
        cpx #NSLOTS
        bne @l
        sec
        rts
@found: txa
        clc
        rts

; count_cars: A = number of owned cars
count_cars:
        ldx #0
        stx tmp3
@l:     txa
        jsr slot_ptr
        ldy #CR_MODEL
        lda (ptr1),y
        cmp #$FF
        beq :+
        inc tmp3
:       inx
        cpx #NSLOTS
        bne @l
        lda tmp3
        rts
