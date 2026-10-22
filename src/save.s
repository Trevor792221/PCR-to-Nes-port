; ===========================================================================
; save.s -- battery-backed save in WRAM (fixed bank)
; ===========================================================================

save_magic: .byte "PXR4"          ; WRAM layout (48-byte car records, SV_OWNED)

; The save lives in battery-backed WRAM at $6000 and the game changes it in
; place, then save_write seals it with a checksum and copies it to
; SV_BACKUP.  A power cut between a change and its save_write leaves a save
; that fails the checksum: the backup, the last sealed save, takes its place.
SV_BACKUP = $7000               ; $6000-$61FF as of the last save_write
.assert SV_SUM + 2 <= $6200, error, "the save outgrew its backup"

; save_load: keep the save if it's valid, else the backup if that is,
; otherwise start a new game
save_load:
        jsr save_valid
        bcs @ok
        ldx #0                  ; the backup
:       lda SV_BACKUP,x
        sta $6000,x
        lda SV_BACKUP+$100,x
        sta $6100,x
        inx
        bne :-
        jsr save_valid
        jcc new_game
@ok:    jsr cash_clamp          ; saves from before the cash cap
        jmp save_write

; save_valid: carry set if WRAM holds a save (its magic and checksum)
save_valid:
        ldx #3
@m:     lda SAVE_MAGIC,x
        cmp save_magic,x
        bne @no
        dex
        bpl @m
        jsr save_sum
        lda tmp0
        cmp SV_SUM
        bne @no
        lda tmp1
        cmp SV_SUM+1
        bne @no
        sec
        rts
@no:    clc
        rts

; new_game: wipe the save and give the player a starter car
new_game:
        lda #0
        sta map_region              ; map: back to the first region
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
        ; starter car in slot 0 (a Game Genie code can pick another)
        lda #0
        jsr slot_ptr
        lda cheat_start_car
        cmp #NCARS
        bcc :+
        lda #0
:       jsr init_record
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
        txa                     ; (keeps X)
        pha
        ldx #0                  ; and the backup
:       lda $6000,x
        sta SV_BACKUP,x
        lda $6100,x
        sta SV_BACKUP+$100,x
        inx
        bne :-
        pla
        tax
        rts

; save_sum: tmp0/tmp1 = 16-bit sum of $6004..SV_END-1 (rotating)
.segment "BSS"
sum_end:    .res 2
.segment "FIXED"
save_sum:                       ; (keeps X: save_write callers rely on it)
        lda #<SV_END
        sta sum_end
        lda #>SV_END
        sta sum_end+1
save_sum_to:                    ; sum_end = end address
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
        cmp sum_end
        bne @l
        lda ptr2+1
        cmp sum_end+1
        bne @l
        rts

; slot_ptr: A = slot -> ptr1 = SV_CARS + slot*48  (preserves X)
slot_ptr:
        asl a
        asl a
        asl a
        asl a                   ; slot*16 (< 128)
        sta ptr1
        asl a                   ; slot*32
        clc
        adc ptr1
        sta ptr1                ; slot*48 (< 384): carry is the high bit
        lda #>SV_CARS
        adc #0
        sta ptr1+1
        clc
        lda ptr1
        adc #<SV_CARS
        sta ptr1
        bcc :+
        inc ptr1+1
:       rts

; cur_car_ptr: ptr1 = record of the car in use, A = its model
cur_car_ptr:
        lda SV_CURCAR
        jsr slot_ptr
        ldy #CR_MODEL
        lda (ptr1),y
        rts

; cur_boss: Z clear if the car in use was won from a boss (ptr1 = it)
cur_boss:
        jsr cur_car_ptr
        ldy #CR_SWAP
        lda (ptr1),y
        and #SWAP_BOSS
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
