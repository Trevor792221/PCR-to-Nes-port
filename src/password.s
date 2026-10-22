; ===========================================================================
; password.s -- the passwords, alongside the battery save (bank 5)
;
; PLAYER (32 chars): version 2 | cash 24 | gems 12 | level 7 | xp 12 |
;                    ladder 4 | secret 1 | options 3 | races 12 | wins 12 |
;                    losses 12 | crates 10 | street wins 8 | best 1/4 15 |
;                    its car 4 | top mph 10 | its car 4 | checksum 8
;                    (15-char version 1 passwords from v3.0 stop after
;                    options and still work)
; GARAGE (12-74 chars): version 3 | cars-1 3 | car in use 3 |
;                    per car: model 4, parts as 7 pairs (a*5+b) x 5 bits,
;                    body colour 5 | checksum 8
;                    (versions 1-2, 11-66 chars, have 6 pairs: no wheelie
;                    bars or injectors; they still work)
;                    Version 4 (0 in the field), 14-85 chars, only when a
;                    car is swapped: after each colour, engine 5 | drive 2
;                    (from the record's CR_SWAP byte; engine 31, drive 0 =
;                    a car won from a boss: CR_SWAP SWAP_BOSS)
;                    Version 5 (0 too, but longer than version 4), up to 119
;                    chars, only when a car has paid for swaps it hasn't
;                    fitted: after the swaps, spare 1 | if 1: engines 17 |
;                    drivetrains 3 (the slot's SV_OWNED bits)
; Bits go MSB first; each 5 bits is one character XORed with a mask that
; steps by 13 per position.  The checksum (rotate left, add) runs over every
; field and is seeded differently per password.  tools/password.py is the
; reference implementation.
; ===========================================================================

.segment "BSS"
pw_byte:    .res 1          ; bit buffer position: byte index
pw_bit:     .res 1          ;   and bit mask ($80 .. $01)
pw_v:       .res 1
pw_cnt:     .res 1
pw_chk:     .res 1
pw_want:    .res 1
pw_lo:      .res 1
pw_len:     .res 1          ; characters in PW_TEXT
pw_max:     .res 1
pw_sel:     .res 1          ; letter grid cursor
pw_kind:    .res 1          ; 0 player, 1 garage
pw_m:       .res 1
pw_i:       .res 1
pw_j:       .res 1
pw_s:       .res 1
pw_row:     .res 1
pw_hb:      .res 1
pw_mode:    .res 1          ; checksum: 0 field sum (version 1), 1 CRC-8
pw_crcon:   .res 1          ; $80 while a field's bits go through the CRC
pw_tb:      .res 1
pw_ver:     .res 1
pw_win:     .res 1          ; typed text: first row shown (long passwords scroll)
pw_tlen:    .res 1          ; length of the tune password (0: none)
pw_rstep:   .res 1          ; pw_print_rows: rows apart
pw_any:     .res 1
pw_ng:      .res 1
pw_d:       .res 2
kb_now:     .res 18         ; keyboard: keys down this scan, a nibble per
kb_old:     .res 18         ;   row and column (bit 0 = $4017 bit 1); last scan's
kb_n:       .res 1          ; keys down this scan

.segment "BANK5"

PW_BUF    = DYNO_BMP            ; bit buffer (dyno work area)
PW_BUFSZ  = 144
PW_TEXT   = DYNO_BMP + $100     ; up to 255 symbols (0-31)
PW_PL     = DYNO_BMP + $200     ; decoded player fields (25 bytes, see pw_apply)
PW_N      = DYNO_BMP + $220     ; decoded garage: cars
PW_CUR    = DYNO_BMP + $221     ;   car in use
PW_CARS   = DYNO_BMP + $240     ;   8 x 21: model, 14 parts, colour index,
PWC_SIZE  = 21                  ;   engine and drivetrain swap bytes
PWC_PAINT = 1 + NPARTS
PWC_ENGINE = PWC_PAINT + 1
PWC_DRIVE  = PWC_PAINT + 2
PWC_OWNED  = PWC_PAINT + 3      ;   and 3 SV_OWNED bytes
PW_TUNE   = DYNO_BMP + $300     ; decoded tunes: 8 x 32
PWT_SIZE  = 32                  ;   13 tune bytes (as in the record),
PWT_TUNE  = CR_NOS - CR_FUEL + 1
PWT_GEARS = PWT_TUNE            ;   gears tuned (0/1),
PWT_RATIO = PWT_TUNE + 1        ;   final + 7 gears (8.8)

PW_PL_SIZE   = 25
SEED_PLAYER  = $5A
SEED_GARAGE  = $C3
SEED_TUNE    = $A5
TUNE_MAX     = 237              ; letters (8 fully tuned cars, nitrous too, need up to 237)
PLAYER_LEN   = 15               ; version 1 (v3.0): no stats
PLAYER_LEN2  = 32               ; version 2: with stats
PW_BOSS      = 31               ; garage engine field: a car won from a boss
GARAGE_MAX   = 119              ; version 5: 8 cars, each with spare swaps

pw_alpha:   .byte "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
garage_len: .byte 12, 21, 30, 39, 48, 56, 65, 74    ; version 3: (16 + 44*cars + 4) / 5
garage_len2: .byte 11, 19, 27, 35, 43, 50, 58, 66   ; versions 1-2: 12 parts, 39 bits a car
garage_pad: .byte 0, 1, 2, 3, 4, 0, 1, 2            ; 5*len - bits (the same for both)
garage_len4: .byte 14, 24, 34, 44, 55, 65, 75, 85   ; version 4: + swaps, 51 bits a car
garage_pad4: .byte 3, 2, 1, 0, 4, 3, 2, 1

; ---------------------------------------------------------------------------
; Family keyboard: type passwords on it.  $4016 writes: bit 0 resets to row
; 0, bit 1 picks the column (the row steps when it goes 1 -> 0), bit 2
; turns the keyboard on.  $4017 bits 1-4 read a row's column, 0 = key down.
; Nothing plugged in reads every key as down, and so does anything else on
; the expansion port (it can only drive some of the bits), so a scan with
; more than KB_MAXDOWN keys down counts as no keyboard.
; ---------------------------------------------------------------------------
KB_MAXDOWN = 4
KB_DEL  = $40
KB_RET  = $41
KB_BAD  = $42                   ; I, O, 0, 1: not in passwords
KB_NONE = $FF

; kb_scan: A = the key (0-71: row*8 + column*4 + bit) that went down this
; scan, or $FF.  Clobbers X, Y.
kb_scan:
        lda #$05                ; row 0, keyboard on
        sta JOY1
        jsr kb_wait
        ldy #0
        sty kb_n
@row:   lda #$04                ; column 0 (the next row after column 1)
        jsr kb_col
        lda #$06                ; column 1
        jsr kb_col
        cpy #18
        bne @row
        lda #0                  ; keyboard off
        sta JOY1
        lda kb_n
        cmp #KB_MAXDOWN + 1
        bcc :+
        lda #0                  ; no keyboard
        ldy #17
@clr:   sta kb_now,y
        dey
        bpl @clr
:       lda #KB_NONE
        sta pw_tb
        ldy #17
@new:   lda kb_old,y
        eor #$FF
        and kb_now,y
        beq @nx
        ldx #$FF                ; lowest new bit
@bit:   inx
        lsr a
        bcc @bit
        stx pw_tb
        tya
        asl a
        asl a
        ora pw_tb
        sta pw_tb
@nx:    lda kb_now,y
        sta kb_old,y
        dey
        bpl @new
        lda pw_tb
        rts

; kb_col: write A to $4016, wait, keys down -> kb_now,y (1 = down); y++
kb_col:
        sta JOY1
        jsr kb_wait
        lda JOY2
        lsr a
        and #$0F
        eor #$0F
        sta kb_now,y
        tax
        lda kb_n
        clc
        adc kb_bits,x
        sta kb_n
        iny
        rts

; kb_wait: the keyboard needs about 50 cycles after a write (this is 59)
kb_wait:
        ldx #9
:       dex
        bne :-
        rts

kb_bits:    .byte 0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4

; kb_map: key -> letter (0-31, pw_alpha), KB_DEL, KB_RET, KB_BAD or KB_NONE
kb_map:
        .byte KB_NONE, KB_RET, KB_NONE, KB_NONE  ; row 0: F8 RETURN [ ]
        .byte KB_NONE, KB_NONE, KB_NONE, KB_NONE ;        KANA RSHIFT YEN STOP
        .byte KB_NONE, KB_NONE, KB_NONE, KB_NONE ; row 1: F7 @ : ;
        .byte KB_NONE, KB_NONE, KB_NONE, KB_NONE ;        _ / - ^
        .byte KB_NONE, KB_BAD, 10, 9             ; row 2: F6 O L K
        .byte KB_NONE, KB_NONE, 13, KB_BAD       ;        . , P 0
        .byte KB_NONE, KB_BAD, 18, 8             ; row 3: F5 I U J
        .byte 11, 12, 31, 30                     ;        M N 9 8
        .byte KB_NONE, 22, 6, 7                  ; row 4: F4 Y G H
        .byte 1, 19, 29, 28                      ;        B V 7 6
        .byte KB_NONE, 17, 15, 3                 ; row 5: F3 T R D
        .byte 5, 2, 27, 26                       ;        F C 5 4
        .byte KB_NONE, 20, 16, 0                 ; row 6: F2 W S A
        .byte 21, 23, 4, 25                      ;        X Z E 3
        .byte KB_NONE, KB_NONE, 14, KB_NONE      ; row 7: F1 ESC Q CTR
        .byte KB_NONE, KB_NONE, KB_BAD, 24       ;        LSHIFT GRPH 1 2
        .byte KB_NONE, KB_NONE, KB_NONE, KB_NONE ; row 8: CLR UP RIGHT LEFT
        .byte KB_NONE, KB_NONE, KB_DEL, KB_NONE  ;        DOWN SPACE DEL INS

; ---------------------------------------------------------------------------
; Bit buffer
; ---------------------------------------------------------------------------
pw_reset:
        lda #0
        ldx #PW_BUFSZ
:       sta PW_BUF-1,x
        dex
        bne :-
pw_rewind:
        lda #0
        sta pw_byte
        lda #$80
        sta pw_bit
        rts

; pw_sum: checksum = rol(checksum) + A.  Keeps A.
pw_sum:
        pha
        lda pw_chk
        asl a
        adc #0
        sta pw_chk
        pla
        pha
        clc
        adc pw_chk
        sta pw_chk
        pla
        rts

; pw_crc_bit: CRC-8 (poly $07) step for the data bit in A (0/1).  Keeps X, Y.
pw_crc_bit:
        sta pw_tb
        lda pw_chk
        rol a                   ; C = top bit
        lda #0
        rol a
        eor pw_tb               ; feedback
        asl pw_chk
        lsr a
        bcc :+
        lda pw_chk
        eor #$07
        sta pw_chk
:       rts

; pw_put: write the low X bits of A, MSB first, and run it through the
; checksum (pw_mode).  pw_putb: no checksum.  Clobbers X, Y.
pw_put:
        pha
        lda pw_mode
        bne @crc
        pla
        jsr pw_sum
        jmp pw_putb
@crc:   lda #$80
        sta pw_crcon
        pla
        jsr pw_putb
        lda #0
        sta pw_crcon
        rts
pw_putb:
        sta pw_v
        stx pw_cnt
        lda #8
        sec
        sbc pw_cnt
        tax
        beq :++
:       asl pw_v                ; left-align the field
        dex
        bne :-
:       ldx pw_cnt
@b:     asl pw_v
        lda #0
        rol a                   ; A = the bit
        bit pw_crcon
        bpl :+
        pha
        jsr pw_crc_bit
        pla
:       tay
        beq @z
        ldy pw_byte
        lda PW_BUF,y
        ora pw_bit
        sta PW_BUF,y
@z:     lsr pw_bit
        bne :+
        ror pw_bit              ; carry from the lsr: back to $80
        inc pw_byte
:       dex
        bne @b
        rts

; pw_get: read X bits -> A and run it through the checksum.  pw_getb: no
; checksum.  Clobbers X, Y.
pw_get:
        lda pw_mode
        bne @crc
        jsr pw_getb
        jmp pw_sum
@crc:   lda #$80
        sta pw_crcon
        jsr pw_getb
        ldy #0
        sty pw_crcon
        tay                     ; flags from the value
        rts
pw_getb:
        lda #0
        sta pw_v
@b:     ldy pw_byte
        lda PW_BUF,y
        and pw_bit
        cmp #1                  ; carry = the bit
        rol pw_v
        bit pw_crcon
        bpl :+
        lda pw_v
        and #1
        jsr pw_crc_bit
:       lsr pw_bit
        bne :+
        ror pw_bit
        inc pw_byte
:       dex
        bne @b
        lda pw_v
        rts

; pw_to_text: buffer -> pw_len symbols in PW_TEXT
pw_to_text:
        jsr pw_rewind
        lda #7
        sta pw_m
        lda #0
        sta pw_i
@c:     ldx #5
        jsr pw_getb
        eor pw_m
        ldx pw_i
        sta PW_TEXT,x
        jsr pw_next_mask
        inc pw_i
        lda pw_i
        cmp pw_len
        bne @c
        rts

; pw_from_text: PW_TEXT -> buffer, rewound for reading
pw_from_text:
        jsr pw_reset
        lda #7
        sta pw_m
        lda #0
        sta pw_i
@c:     ldx pw_i
        lda PW_TEXT,x
        eor pw_m
        ldx #5
        jsr pw_putb
        jsr pw_next_mask
        inc pw_i
        lda pw_i
        cmp pw_len
        bne @c
        jmp pw_rewind

pw_next_mask:
        lda pw_m
        clc
        adc #13
        and #31
        sta pw_m
        rts

; pw_put_w: (X+8)-bit field: A = high byte (X bits), pw_lo = low byte.
; Values too big for the field are clamped to its maximum.
pw_put_w:
        stx pw_hb
        cpx #8
        bcs @ok
        cmp pw_lim,x
        bcc @ok
        lda #$FF
        sta pw_lo
        lda pw_lim,x
        sec
        sbc #1
@ok:    ldx pw_hb
        jsr pw_put
        lda pw_lo
        ldx #8
        jmp pw_put
pw_lim: .byte 1, 2, 4, 8, 16, 32, 64, 128

; pw_get_w: read an (X+8)-bit field -> A = high byte, pw_lo = low byte
pw_get_w:
        jsr pw_get
        pha
        ldx #8
        jsr pw_get
        sta pw_lo
        pla
        rts

; ---------------------------------------------------------------------------
; PLAYER password
; ---------------------------------------------------------------------------
pw_enc_player:
        jsr pw_reset
        lda #1
        sta pw_mode
        lda #SEED_PLAYER
        sta pw_chk
        lda #2                  ; version 2: with stats
        ldx #2
        jsr pw_put
        lda SV_CASH+2
        ldx #8
        jsr pw_put
        lda SV_CASH+1
        ldx #8
        jsr pw_put
        lda SV_CASH
        ldx #8
        jsr pw_put
        lda SV_GEMS
        sta pw_lo
        lda SV_GEMS+1
        ldx #4
        jsr pw_put_w
        lda SV_LEVEL
        ldx #7
        jsr pw_put
        lda SV_XP
        sta pw_lo
        lda SV_XP+1
        ldx #4
        jsr pw_put_w
        lda SV_LADDER
        and #15
        ldx #4
        jsr pw_put
        lda SV_SECRET
        and #1
        ldx #1
        jsr pw_put
        lda SV_OPTIONS
        and #7
        ldx #3
        jsr pw_put
        ; stats
        lda SV_RACES
        sta pw_lo
        lda SV_RACES+1
        ldx #4
        jsr pw_put_w
        lda SV_WINS
        sta pw_lo
        lda SV_WINS+1
        ldx #4
        jsr pw_put_w
        lda SV_LOSSES
        sta pw_lo
        lda SV_LOSSES+1
        ldx #4
        jsr pw_put_w
        lda SV_CRATES
        sta pw_lo
        lda SV_CRATES+1
        ldx #2
        jsr pw_put_w
        lda SV_STREET
        ldx #8
        jsr pw_put
        lda SV_PBEST
        sta pw_lo
        lda SV_PBEST+1
        ldx #7
        jsr pw_put_w
        lda SV_PBCAR
        and #15
        ldx #4
        jsr pw_put
        lda SV_TOPSPD           ; top speed: mph (10 bits), then its car
        sta pw_lo
        lda SV_TOPSPD+1
        and #3
        ldx #2
        jsr pw_put_w
        lda SV_TOPSPD+1
        lsr a
        lsr a
        lsr a
        lsr a
        ldx #4
        jsr pw_put
        lda pw_chk
        ldx #8
        jsr pw_putb
        lda #PLAYER_LEN2
        sta pw_len
        jmp pw_to_text

; pw_dec_player: PW_TEXT -> PW_PL.  Carry set if the password is wrong.
; 32 letters (version 2, with stats) or 15 (version 1 from v3.0: no stats).
pw_dec_player:
        ldx #1
        lda pw_len
        cmp #PLAYER_LEN
        beq :+
        inx
        cmp #PLAYER_LEN2
        jne pw_bad
:       stx pw_ver
        dex                     ; version 2 checks with the CRC
        stx pw_mode
        jsr pw_from_text
        lda #SEED_PLAYER
        sta pw_chk
        ldx #2
        jsr pw_get
        cmp pw_ver
        jne pw_bad
        ldx #8
        jsr pw_get
        sta PW_PL+2             ; cash
        ldx #8
        jsr pw_get
        sta PW_PL+1
        ldx #8
        jsr pw_get
        sta PW_PL
        ldx #4
        jsr pw_get
        sta PW_PL+4             ; gems
        ldx #8
        jsr pw_get
        sta PW_PL+3
        ldx #7
        jsr pw_get
        sta PW_PL+5             ; level
        ldx #4
        jsr pw_get
        sta PW_PL+7             ; xp
        ldx #8
        jsr pw_get
        sta PW_PL+6
        ldx #4
        jsr pw_get
        sta PW_PL+8             ; ladder
        ldx #1
        jsr pw_get
        sta PW_PL+9             ; secret boss
        ldx #3
        jsr pw_get
        sta PW_PL+10            ; options
        ldx #PW_PL_SIZE-12      ; stats: none in a version 1 password
        lda #0
:       sta PW_PL+11,x
        dex
        bpl :-
        lda pw_ver
        cmp #2
        jne @sum
        ldx #4
        jsr pw_get_w
        sta PW_PL+12            ; races
        lda pw_lo
        sta PW_PL+11
        ldx #4
        jsr pw_get_w
        sta PW_PL+14            ; wins
        lda pw_lo
        sta PW_PL+13
        ldx #4
        jsr pw_get_w
        sta PW_PL+16            ; losses
        lda pw_lo
        sta PW_PL+15
        ldx #2
        jsr pw_get_w
        sta PW_PL+18            ; crates
        lda pw_lo
        sta PW_PL+17
        ldx #8
        jsr pw_get
        sta PW_PL+19            ; street wins
        ldx #7
        jsr pw_get_w
        sta PW_PL+21            ; best 1/4 ms
        lda pw_lo
        sta PW_PL+20
        ldx #4
        jsr pw_get
        sta PW_PL+22            ; its car
        cmp #NCARS
        jcs pw_bad
        ldx #2
        jsr pw_get_w
        sta PW_PL+24            ; top speed (mph high bits)
        lda pw_lo
        sta PW_PL+23
        ldx #4
        jsr pw_get              ; its car
        cmp #NCARS
        jcs pw_bad
        asl a
        asl a
        asl a
        asl a
        ora PW_PL+24
        sta PW_PL+24
@sum:   lda pw_chk
        sta pw_want
        ldx #8
        jsr pw_getb
        cmp pw_want
        jne pw_bad
        lda pw_ver              ; version 1 has 2 spare bits; they must be 0
        cmp #2
        beq :+
        ldx #2
        jsr pw_getb
        jne pw_bad
:
        lda PW_PL+5             ; level 1-99
        beq pw_bad
        cmp #100
        bcs pw_bad
        lda PW_PL+8             ; 11 bosses
        cmp #12
        bcs pw_bad
        lda #<CASH_MAX          ; cash <= CASH_MAX
        cmp PW_PL
        lda #>CASH_MAX
        sbc PW_PL+1
        lda #^CASH_MAX
        sbc PW_PL+2
        bcc pw_bad
        clc
        rts
pw_bad: sec
        rts

; ---------------------------------------------------------------------------
; GARAGE password
; ---------------------------------------------------------------------------
pw_enc_garage:
        jsr pw_reset
        lda #1
        sta pw_mode
        lda #SEED_GARAGE
        sta pw_chk
        lda #3                  ; version 3: CRC, 14 parts; 4 (written as
        sta pw_ver              ; 0) when a car is swapped; 5 (0 too) when
        lda #0                  ; a car has paid for swaps it hasn't fitted
        sta pw_s
@sw:    lda pw_s
        jsr slot_ptr
        ldy #CR_MODEL
        lda (ptr1),y
        cmp #$FF
        beq @swn
        jsr pw_owned_ptr
        lda SV_OWNED,x
        ora SV_OWNED+1,x
        ora SV_OWNED+2,x
        beq :+
        lda #5
        sta pw_ver
:       ldy #CR_SWAP
        lda (ptr1),y
        beq @swn
        lda pw_ver
        cmp #4
        bcs @swn
        lda #4
        sta pw_ver
@swn:   inc pw_s
        lda pw_s
        cmp #NSLOTS
        bne @sw
        lda pw_ver
        cmp #4
        bcc :+
        lda #0                  ; versions 4 and 5
:       ldx #2
        jsr pw_put
        ; count the cars and find the one in use
        lda #0
        sta pw_i
        sta pw_j
        sta pw_s
@cnt:   lda pw_s
        jsr slot_ptr
        ldy #CR_MODEL
        lda (ptr1),y
        cmp #$FF
        beq @cn
        lda pw_s
        cmp SV_CURCAR
        bne :+
        lda pw_i
        sta pw_j
:       inc pw_i
@cn:    inc pw_s
        lda pw_s
        cmp #NSLOTS
        bne @cnt
        lda pw_i
        sec
        sbc #1
        ldx #3
        jsr pw_put
        lda pw_j
        ldx #3
        jsr pw_put
        ; the cars
        lda #0
        sta pw_s
@car:   lda pw_s
        jsr slot_ptr
        ldy #CR_MODEL
        lda (ptr1),y
        cmp #$FF
        jeq @next
        ldx #4
        jsr pw_put
        lda #CR_PARTS
        sta pw_j
@pair:  ldy pw_j                ; a*5 + b
        lda (ptr1),y
        sta pw_lo
        asl a
        asl a
        adc pw_lo
        iny
        adc (ptr1),y
        iny
        sty pw_j
        ldx #5
        jsr pw_put
        lda pw_j
        cmp #CR_PARTS+NPARTS
        bne @pair
        ldy #CR_PAINT           ; body colour -> paint_list index
        lda (ptr1),y
        ldx #23
:       cmp paint_list,x
        beq :+
        dex
        bpl :-
        ldx #0
:       txa
        ldx #5
        jsr pw_put
        lda pw_ver
        cmp #4
        jcc @next
        ldy #CR_SWAP            ; versions 4-5: the swaps
        lda (ptr1),y
        bpl @swe
        lda #PW_BOSS            ; a boss's car: engine 31, drivetrain 0
        ldx #5
        jsr pw_put
        lda #0
        beq @swd
@swe:   and #SWAP_ENG
        ldx #5
        jsr pw_put
        ldy #CR_SWAP
        lda (ptr1),y
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
@swd:   ldx #2
        jsr pw_put
        lda pw_ver              ; version 5: the swaps paid for
        cmp #5
        bne @next
        jsr pw_owned_ptr
        lda SV_OWNED,x
        sta pw_d
        lda SV_OWNED+1,x
        sta pw_d+1
        lda SV_OWNED+2,x
        sta pw_any
        ora pw_d
        ora pw_d+1
        beq :+
        lda #1
:       ldx #1
        jsr pw_put
        lda pw_d
        ora pw_d+1
        ora pw_any
        beq @next
        lda pw_any              ; engines 16 .. 0
        ldx #1
        jsr pw_put
        lda pw_d+1
        ldx #8
        jsr pw_put
        lda pw_d
        ldx #8
        jsr pw_put
        lda pw_any              ; drivetrains
        lsr a
        lsr a
        lsr a
        lsr a
        ldx #3
        jsr pw_put
@next:  inc pw_s
        lda pw_s
        cmp #NSLOTS
        jne @car
        lda pw_chk
        ldx #8
        jsr pw_putb
        ldx pw_i
        lda garage_len-1,x
        ldy pw_ver
        cpy #4
        bcc @len
        lda garage_len4-1,x
        cpy #4
        beq @len
        jsr pw_letters          ; version 5: as many as it took
@len:   sta pw_len
        jmp pw_to_text

; pw_owned_ptr: X = pw_s * 3 (the slot's SV_OWNED bytes).  Keeps Y.
pw_owned_ptr:
        lda pw_s
        asl a
        adc pw_s
        tax
        rts

; pw_letters: A = letters for the bits written or read so far (rounded up),
; pw_ng = the spare bits in the last one
pw_letters:
        lda pw_byte             ; pw_d = bits = byte * 8 + bit
        sta pw_d
        lda #0
        sta pw_d+1
        asl pw_d
        rol pw_d+1
        asl pw_d
        rol pw_d+1
        asl pw_d
        rol pw_d+1
        lda pw_bit
        ldx #$FF
:       inx
        asl a
        bcc :-
        txa
        clc
        adc pw_d
        sta pw_d
        bcc :+
        inc pw_d+1
:       ldx #0
        stx pw_ng
@five:  lda pw_d
        ora pw_d+1
        beq @done
        inx
        sec
        lda pw_d
        sbc #5
        sta pw_d
        lda pw_d+1
        sbc #0
        sta pw_d+1
        bcs @five
        lda #0                  ; went past: 5 - what was left
        sec
        sbc pw_d
        sta pw_ng
@done:  txa
        rts

; pw_dec_garage: PW_TEXT -> PW_N, PW_CUR, PW_CARS.  Carry set if wrong.
pw_dec_garage:
        lda pw_len
        cmp #11
        jcc pw_bad
        jsr pw_from_text
        ldx #2                  ; version 1 (v3.0) field sum, 2 CRC,
        jsr pw_getb             ; 3 (v4.2) CRC and 14 parts, 0: version 4
        bne :+                  ; (v5.0) with swaps
        lda #4
:       sta pw_ver
        cmp #1
        beq :+
        lda #2                  ; (versions 2 and 3: CRC)
:       sec
        sbc #1
        sta pw_mode
        jsr pw_rewind
        lda #SEED_GARAGE
        sta pw_chk
        ldx #2
        jsr pw_get
        sta pw_lo
        lda pw_ver
        and #3
        cmp pw_lo
        beq :+
        jmp pw_bad
:
        ldx #3
        jsr pw_get
        tax
        inx
        stx PW_N
        ldy pw_ver
        cpy #4
        bne @l13
        lda garage_len4-1,x
        cmp pw_len
        beq @lok
        jcs pw_bad              ; shorter than version 4
        lda #5                  ; longer: version 5 (its length is checked
        sta pw_ver              ; at the end)
        bne @lok
@l13:   lda garage_len-1,x
        cpy #3
        beq :+
        lda garage_len2-1,x
:       cmp pw_len
        jne pw_bad
@lok:
        ldx #3
        jsr pw_get
        sta PW_CUR
        cmp PW_N
        jcs pw_bad
        MOVI16 ptr2, PW_CARS
        lda #0
        sta pw_s
@car:   ldx #4
        jsr pw_get
        ldy #0
        sta (ptr2),y
        cmp #NCARS
        jcs pw_bad
        lda #1
        sta pw_j
@pair:  ldx #5
        jsr pw_get
        cmp #25
        jcs pw_bad
        ldx #0                  ; a = v / 5, b = v mod 5
:       cmp #5
        bcc :+
        sbc #5
        inx
        bne :-
:       ldy pw_j
        pha
        txa
        sta (ptr2),y
        iny
        pla
        sta (ptr2),y
        iny
        sty pw_j
        cpy #1+12               ; versions 1-2 stop after 12 parts
        bne :+
        lda pw_ver
        cmp #3
        bcc @old
:       cpy #1+NPARTS
        bne @pair
        jmp @col
@old:   lda #0                  ; ... wheelie bars and injectors: stock
        sta (ptr2),y
        iny
        sta (ptr2),y
@col:   ldx #5
        jsr pw_get
        ldy #PWC_PAINT
        sta (ptr2),y
        cmp #24
        jcs pw_bad
        lda #0                  ; swaps: none before version 4,
        sta pw_lo
        sta pw_hb
        sta pw_d                ; none paid for before version 5
        sta pw_d+1
        sta pw_any
        lda pw_ver
        cmp #4
        jcc @swp
        ldx #5
        jsr pw_get
        sta pw_lo
        cmp #PW_BOSS            ; a boss's car
        bne @eng
        ldx #2
        jsr pw_get              ; (never swapped)
        jne pw_bad
        sta pw_hb
        lda #SWAP_BOSS
        sta pw_lo
        bne @own
@eng:   cmp #NENGINES+1
        jcs pw_bad
        cmp #CRATE_CAR+1        ; the crate car's engine isn't for sale
        jeq pw_bad
        ldx #2
        jsr pw_get
        sta pw_hb
        ora pw_lo               ; and the crate car can't be swapped
        beq @own
        ldy #0
        lda (ptr2),y
        cmp #CRATE_CAR
        jeq pw_bad
@own:   lda pw_ver              ; version 5: swaps paid for
        cmp #5
        bne @swp
        ldx #1
        jsr pw_get
        beq @swp
        ldx #1                  ; engines 16 .. 0
        jsr pw_get
        sta pw_any
        ldx #8
        jsr pw_get
        sta pw_d+1
        ldx #8
        jsr pw_get
        sta pw_d
        ldx #3                  ; drivetrains: bits 4-6 of the third byte
        jsr pw_get
        asl a
        asl a
        asl a
        asl a
        ora pw_any
        sta pw_any
        ora pw_d                ; something, not the crate car's engine,
        ora pw_d+1              ; and not on the crate car or a boss's car
        jeq pw_bad
        lda pw_lo
        jmi pw_bad
        lda pw_d+1
        and #1 << (CRATE_CAR - 8)
        jne pw_bad
        ldy #0
        lda (ptr2),y
        cmp #CRATE_CAR
        jeq pw_bad
@swp:   ldy #PWC_ENGINE
        lda pw_lo
        sta (ptr2),y
        iny
        lda pw_hb
        sta (ptr2),y
        iny                     ; PWC_OWNED
        lda pw_d
        sta (ptr2),y
        iny
        lda pw_d+1
        sta (ptr2),y
        iny
        lda pw_any
        sta (ptr2),y
        clc
        lda ptr2
        adc #PWC_SIZE
        sta ptr2
        bcc :+
        inc ptr2+1
:       inc pw_s
        lda pw_s
        cmp PW_N
        jne @car
        lda pw_chk
        sta pw_want
        ldx #8
        jsr pw_getb
        cmp pw_want
        jne pw_bad
        ldx PW_N                ; the spare bits in the last letter must be 0
        lda garage_pad-1,x
        ldy pw_ver
        cpy #4
        bcc @pad
        lda garage_pad4-1,x
        cpy #4
        beq @pad
        jsr pw_letters          ; version 5: exactly as long as it takes
        cmp pw_len
        jne pw_bad
        lda pw_ng
@pad:   cmp #0
        beq :+
        tax
        jsr pw_getb
        jne pw_bad
:       clc
        rts

; ---------------------------------------------------------------------------
; TUNE password (optional): engine tunes and gear ratios of tuned cars
; (format in tools/password.py; version 2 adds the nitrous setting)
; ---------------------------------------------------------------------------
; pw_stock: A = model -> ptr3 = its stock gear set (7 words), pw_d = stock
; final drive
pw_stock:
        tax
        lda car_final_l,x
        sta pw_d
        lda car_final_h,x
        sta pw_d+1
        txa
        sta m_a
        lda #14
        sta m_b
        jsr mul8
        clc
        lda m_r
        adc #<car_gearset
        sta ptr3
        lda m_r+1
        adc #>car_gearset
        sta ptr3+1
        rts

; pw_stock_ratio: Y = ratio (0 final, 1-7 gears) -> m_b(16) = stock ratio
pw_stock_ratio:
        tya
        bne :+
        lda pw_d
        sta m_b
        lda pw_d+1
        sta m_b+1
        rts
:       sty pw_tb
        dey
        tya
        asl a
        tay
        lda (ptr3),y
        sta m_b
        iny
        lda (ptr3),y
        sta m_b+1
        ldy pw_tb
        rts

; pw_ratio_off: Y = ratio index -> record offset (CR_FINAL, CR_GEARS + ...)
pw_ratio_off:
        tya
        asl a
        clc
        adc #CR_FINAL           ; (CR_GEARS = CR_FINAL + 2)
        rts

; pw_bits: m_r = bits used so far in the buffer
pw_bits:
        lda pw_byte
        sta m_r
        lda #0
        sta m_r+1
        asl m_r
        rol m_r+1
        asl m_r
        rol m_r+1
        asl m_r
        rol m_r+1
        lda pw_bit
        ldx #0
:       asl a
        bcs :+
        inx
        bne :-
:       txa
        clc
        adc m_r
        sta m_r
        bcc :+
        inc m_r+1
:       rts

; pw_enc_tune: tunes of the cars in garage order -> PW_TEXT.  pw_len = 0
; when every car is stock.
pw_enc_tune:
        jsr pw_reset
        lda #1
        sta pw_mode
        lda #SEED_TUNE
        sta pw_chk
        lda #0
        sta pw_any
        lda #1                  ; version 1, or 2 (+ nitrous) when a car's
        sta pw_ver              ; nitrous is tuned
        lda #0
        sta pw_s
@nv:    lda pw_s
        jsr slot_ptr
        ldy #CR_MODEL
        lda (ptr1),y
        cmp #$FF
        beq :+
        ldy #CR_NOS
        lda (ptr1),y
        beq :+
        lda #2
        sta pw_ver
:       inc pw_s
        lda pw_s
        cmp #NSLOTS
        bne @nv
        lda pw_ver
        ldx #2
        jsr pw_put
        jsr count_cars
        sec
        sbc #1
        ldx #3
        jsr pw_put
        lda #0
        sta pw_s
@car:   lda pw_s
        jsr slot_ptr
        ldy #CR_MODEL
        lda (ptr1),y
        cmp #$FF
        jeq @next
        ; engine tuned: any tune byte not 0
        ldy #CR_FUEL
        lda #0
:       ora (ptr1),y
        iny
        cpy #CR_NOS+1
        bne :-
        cmp #0
        beq :+
        lda #1
:       sta pw_j
        ora pw_any
        sta pw_any
        ; gears tuned: any ratio not stock
        ldy #CR_MODEL
        lda (ptr1),y
        tax
        lda car_ngears,x
        sta pw_ng
        txa
        jsr pw_stock
        lda #0
        sta pw_lo
        ldy #0
@gc:    jsr pw_stock_ratio
        sty pw_i
        jsr pw_ratio_off
        tay
        lda (ptr1),y
        cmp m_b
        bne @gt
        iny
        lda (ptr1),y
        cmp m_b+1
        bne @gt
        ldy pw_i
        iny
        cpy pw_ng
        beq @gc
        bcc @gc
        bcs @gd
@gt:    lda #1
        sta pw_lo
        sta pw_any
@gd:    lda pw_j
        ldx #1
        jsr pw_put
        lda pw_lo
        pha
        ldx #1
        jsr pw_put
        lda pw_j
        beq @noeng
        ; engine: fuel x8 (+5, 4 bits), timing (+5, 4), tire psi (+14, 5),
        ; boost (+13, 5), 2-step (rpm/200, 6)
        lda #CR_FUEL
        sta pw_i
:       lda pw_s
        jsr slot_ptr
        ldy pw_i
        lda (ptr1),y
        clc
        adc #5
        ldx #4
        jsr pw_put
        inc pw_i
        lda pw_i
        cmp #CR_TIMING+1
        bne :-
        lda pw_s
        jsr slot_ptr
        ldy #CR_TIREP
        lda (ptr1),y
        clc
        adc #14
        ldx #5
        jsr pw_put
        lda pw_s
        jsr slot_ptr
        ldy #CR_BOOST
        lda (ptr1),y
        clc
        adc #13
        ldx #5
        jsr pw_put
        lda pw_s
        jsr slot_ptr
        ldy #CR_LAUNCH
        lda (ptr1),y
        lsr a
        ldx #6
        jsr pw_put
        lda pw_ver              ; version 2: nitrous (+4, 4 bits)
        cmp #2
        bne @noeng
        lda pw_s
        jsr slot_ptr
        ldy #CR_NOS
        lda (ptr1),y
        clc
        adc #4
        ldx #4
        jsr pw_put
@noeng: pla
        jeq @next
        ; gears: per ratio, changed 1 | (change / 3) 10 bits
        lda pw_s
        jsr slot_ptr
        ldy #CR_MODEL
        lda (ptr1),y
        jsr pw_stock
        lda #0
        sta pw_i
@gr:    lda pw_s
        jsr slot_ptr
        ldy pw_i
        jsr pw_stock_ratio
        jsr pw_ratio_off
        tay
        sec
        lda (ptr1),y
        sbc m_b
        sta pw_d
        iny
        lda (ptr1),y
        sbc m_b+1
        sta pw_d+1
        ora pw_d
        bne :+
        ldx #1                  ; unchanged
        jsr pw_put
        jmp @gn
:       lda #1
        ldx #1
        jsr pw_put
        lda pw_d+1              ; |d| / 3, then the sign back
        php
        bpl :+
        sec
        lda #0
        sbc pw_d
        sta pw_d
        lda #0
        sbc pw_d+1
        sta pw_d+1
:       lda pw_d
        sta m_r
        lda pw_d+1
        sta m_r+1
        lda #3
        jsr div16_8
        plp
        bpl :+
        sec
        lda #0
        sbc m_r
        sta m_r
        lda #0
        sbc m_r+1
        sta m_r+1
:       lda m_r
        sta pw_lo
        lda m_r+1
        and #3
        ldx #2
        jsr pw_put_w            ; 10 bits
@gn:    inc pw_i
        lda pw_i
        cmp pw_ng
        jeq @gr
        jcc @gr
@next:  inc pw_s
        lda pw_s
        cmp #NSLOTS
        jne @car
        lda #0
        sta pw_len
        lda pw_any
        beq @none
        lda pw_chk
        ldx #8
        jsr pw_putb
        jsr pw_bits             ; letters = (bits + 4) / 5
        clc
        lda m_r
        adc #4
        sta m_r
        bcc :+
        inc m_r+1
:       lda #5
        jsr div16_8
        lda m_r
        sta pw_len
        jmp pw_to_text
@none:  rts

; pw_dec_tune: PW_TEXT -> PW_TUNE for the PW_N cars of the garage password.
; Nothing typed: every car stock.  Carry set if wrong.
pw_dec_tune:
        ldx #0                  ; clear: all stock
        lda #0
:       sta PW_TUNE,x
        inx
        bne :-
        lda pw_len
        bne :+
        clc
        rts
:       lda #1
        sta pw_mode
        jsr pw_from_text
        lda #SEED_TUNE
        sta pw_chk
        ldx #2
        jsr pw_get              ; version 1, or 2 with nitrous
        sta pw_ver
        cmp #1
        beq :+
        cmp #2
        jne pw_bad
:       ldx #3
        jsr pw_get
        clc
        adc #1
        cmp PW_N
        jne pw_bad
        lda #0
        sta pw_s
@car:   lda pw_s                ; ptr2 = PW_TUNE + car*32
        asl a
        asl a
        asl a
        asl a
        asl a
        sta ptr2
        lda #>PW_TUNE
        sta ptr2+1
        ldx #1
        jsr pw_get
        sta pw_j                ; engine
        ldx #1
        jsr pw_get
        ldy #PWT_GEARS
        sta (ptr2),y
        lda pw_j
        jeq @gears
        ldy #0
:       sty pw_i
        ldx #4
        jsr pw_get              ; fuel cells and timing: 0-10
        cmp #11
        jcs pw_bad
        sec
        sbc #5
        ldy pw_i
        sta (ptr2),y
        iny
        cpy #CR_TIMING-CR_FUEL+1
        bne :-
        ldx #5
        jsr pw_get              ; tire psi: 0-22
        cmp #23
        jcs pw_bad
        sec
        sbc #14
        ldy #CR_TIREP-CR_FUEL
        sta (ptr2),y
        ldx #5
        jsr pw_get              ; boost: 0-22
        cmp #23
        jcs pw_bad
        sec
        sbc #13
        ldy #CR_BOOST-CR_FUEL
        sta (ptr2),y
        ldx #6
        jsr pw_get              ; 2-step: off, or 2000 rpm and up
        asl a
        beq :+
        cmp #LAUNCH_MIN_PW
        jcc pw_bad
:       ldy #CR_LAUNCH-CR_FUEL
        sta (ptr2),y
        lda pw_ver
        cmp #2
        bne @gears
        ldx #4
        jsr pw_get              ; nitrous: 0-8
        cmp #9
        jcs pw_bad
        sec
        sbc #4
        ldy #CR_NOS-CR_FUEL
        sta (ptr2),y
@gears: ldy #PWT_GEARS
        lda (ptr2),y
        jeq @next
        .assert PWC_SIZE = 21, error, "the car * 21 below"
        lda pw_s                ; model: PW_CARS + car*21
        asl a
        asl a
        sta pw_lo               ; car*4
        asl a
        asl a                   ; car*16
        adc pw_lo
        adc pw_s
        tax
        lda PW_CARS,x
        tax
        lda car_ngears,x
        sta pw_ng
        txa
        jsr pw_stock
        lda #0
        sta pw_i
@gr:    ldy pw_i
        jsr pw_stock_ratio      ; m_b = stock
        ldx #1
        jsr pw_get
        beq @st
        ldx #2
        jsr pw_get_w            ; 10-bit change / 3 (two's complement)
        cmp #2                  ; sign-extend bit 9
        bcc :+
        ora #$FC
:       sta pw_d+1
        lda pw_lo
        sta pw_d
        ldx #3                  ; m_b += 3 * change
:       clc
        lda m_b
        adc pw_d
        sta m_b
        lda m_b+1
        adc pw_d+1
        sta m_b+1
        dex
        bne :-
@st:    lda pw_i                ; store at PWT_RATIO + 2i
        asl a
        clc
        adc #PWT_RATIO
        tay
        lda m_b
        sta (ptr2),y
        iny
        lda m_b+1
        sta (ptr2),y
        ; limits: final 2.00-5.99, gears 0.50-4.99
        ldx pw_i
        beq @fin
        cmp #5
        jcs pw_bad
        cmp #0
        bne @ok
        lda m_b
        cmp #$80
        jcc pw_bad
        jmp @ok
@fin:   cmp #2
        jcc pw_bad
        cmp #6
        jcs pw_bad
@ok:    inc pw_i
        lda pw_i
        cmp pw_ng
        beq @gr
        jcc @gr
@next:  inc pw_s
        lda pw_s
        cmp PW_N
        jne @car
        lda pw_chk
        sta pw_want
        ldx #8
        jsr pw_getb
        cmp pw_want
        jne pw_bad
        jsr pw_bits             ; the length must fit exactly...
        lda m_r
        sta pw_d
        lda m_r+1
        sta pw_d+1
        clc
        lda m_r
        adc #4
        sta m_r
        bcc :+
        inc m_r+1
:       lda #5
        jsr div16_8
        lda m_r
        cmp pw_len
        jne pw_bad
        lda pw_len              ; ... and the spare bits be 0
        sta m_a
        lda #5
        sta m_b
        jsr mul8
        sec
        lda m_r
        sbc pw_d
        beq :+
        tax
        jsr pw_getb
        jne pw_bad
:       clc
        rts

LAUNCH_MIN_PW = 20             ; 2-step: 2000 rpm and up

; pw_apply_tune: decoded tunes into the garage the passwords just loaded
pw_apply_tune:
        lda #0
        sta pw_s
@car:   lda pw_s
        cmp PW_N
        bcs @done
        jsr slot_ptr
        lda pw_s
        asl a
        asl a
        asl a
        asl a
        asl a
        sta ptr2
        lda #>PW_TUNE
        sta ptr2+1
        ldx #0                  ; the tune bytes
:       txa
        tay
        lda (ptr2),y
        pha
        txa
        clc
        adc #CR_FUEL
        tay
        pla
        sta (ptr1),y
        inx
        cpx #PWT_TUNE
        bne :-
        ldy #PWT_GEARS
        lda (ptr2),y
        beq @n
        ldx #0                  ; final + 7 gears
:       txa
        clc
        adc #PWT_RATIO
        tay
        lda (ptr2),y
        pha
        txa
        clc
        adc #CR_FINAL
        tay
        pla
        sta (ptr1),y
        inx
        cpx #16
        bne :-
@n:     inc pw_s
        bne @car
@done:  jmp save_write

; pw_apply: start a fresh game, then load the decoded passwords into it
pw_apply:
        jsr new_game
        ldx #2
:       lda PW_PL,x
        sta SV_CASH,x
        dex
        bpl :-
        lda PW_PL+3
        sta SV_GEMS
        lda PW_PL+4
        sta SV_GEMS+1
        lda PW_PL+5
        sta SV_LEVEL
        lda PW_PL+6
        sta SV_XP
        lda PW_PL+7
        sta SV_XP+1
        lda PW_PL+8
        sta SV_LADDER
        lda PW_PL+9
        sta SV_SECRET
        lda PW_PL+10
        sta SV_OPTIONS
        lda PW_PL+11
        sta SV_RACES
        lda PW_PL+12
        sta SV_RACES+1
        lda PW_PL+13
        sta SV_WINS
        lda PW_PL+14
        sta SV_WINS+1
        lda PW_PL+15
        sta SV_LOSSES
        lda PW_PL+16
        sta SV_LOSSES+1
        lda PW_PL+17
        sta SV_CRATES
        lda PW_PL+18
        sta SV_CRATES+1
        lda PW_PL+19
        sta SV_STREET
        lda PW_PL+20
        sta SV_PBEST
        lda PW_PL+21
        sta SV_PBEST+1
        lda PW_PL+22
        sta SV_PBCAR
        lda PW_PL+23
        sta SV_TOPSPD
        lda PW_PL+24
        sta SV_TOPSPD+1
        MOVI16 ptr2, PW_CARS
        lda #0
        sta pw_s
@slot:  lda pw_s
        jsr slot_ptr
        lda pw_s
        cmp PW_N
        bcc @car
        ldy #CR_MODEL           ; past the last car: empty
        lda #$FF
        sta (ptr1),y
        jmp @next
@car:   lda ptr2+1
        pha
        lda ptr2
        pha
        ldy #0
        lda (ptr2),y
        jsr init_record         ; stock gearing, default rim/glass colours
        pla                     ; (init_record uses ptr2)
        sta ptr2
        pla
        sta ptr2+1
        ldy #1
:       lda (ptr2),y            ; parts: same offsets in both
        sta (ptr1),y
        iny
        cpy #1+NPARTS
        bne :-
        ldy #PWC_PAINT
        lda (ptr2),y
        tax
        lda paint_list,x
        ldy #CR_PAINT
        sta (ptr1),y
        ldy #PWC_DRIVE          ; swaps: drivetrain in bits 5-6
        lda (ptr2),y
        asl a
        asl a
        asl a
        asl a
        asl a
        ldy #PWC_ENGINE
        ora (ptr2),y
        ldy #CR_SWAP
        sta (ptr1),y
        jsr pw_owned_ptr        ; swaps paid for
        ldy #PWC_OWNED
        lda (ptr2),y
        sta SV_OWNED,x
        iny
        lda (ptr2),y
        sta SV_OWNED+1,x
        iny
        lda (ptr2),y
        sta SV_OWNED+2,x
        clc
        lda ptr2
        adc #PWC_SIZE
        sta ptr2
        bcc @next
        inc ptr2+1
@next:  inc pw_s
        lda pw_s
        cmp #NSLOTS
        bne @slot
        lda PW_CUR
        sta SV_CURCAR
        jsr region_max          ; back on the map at the furthest open region
        sta map_region
        jmp save_write

; ---------------------------------------------------------------------------
; Screens
; ---------------------------------------------------------------------------
; pw_show: both passwords for the current game (from OPTIONS)
pw_show:
        jsr pw_enc_tune         ; is there a third password?
        lda pw_len
        sta pw_tlen
        lda #2
        sta pw_rstep
        lda #0
        jsr screen_begin
        jsr use_menu_palette
        lda #$20
        sta text_attr
        PRINT str_pw_yours, 2, 3
        PRINT str_pw_player, 2, 5
        PRINT str_pw_garage, 2, 12
        lda #0
        sta text_attr
        jsr pw_enc_player
        lda #7
        jsr pw_print_rows
        jsr pw_enc_garage
        lda pw_len              ; over 80 letters (swaps): rows together
        cmp #81
        bcc :+
        dec pw_rstep
:       lda #14
        jsr pw_print_rows
        PRINT str_pw_note1, 2, 23
        PRINT str_pw_note2, 2, 24
        MOVI16 ptr0, str_pw_notune
        lda pw_tlen
        beq :+
        MOVI16 ptr0, str_pw_tune_a
:       ldx #2
        ldy #26
        jsr print
        PRINT str_pw_back, 2, 27
        jsr attr_upload
        lda #0
        sta oam_idx
        jsr oam_clear
        jsr ppu_on
:       jsr wait_frame
        jsr read_pad
        lda pad_new
        and #BTN_A|BTN_B|BTN_START
        beq :-
        and #BTN_A
        beq pw_show_out
        lda pw_tlen
        beq pw_show_out
        lda #SFX_SELECT
        jsr sfx_play
        ; page 2: the tune password, a row of 16 per line
        lda #0
        jsr screen_begin
        jsr use_menu_palette
        lda #$20
        sta text_attr
        PRINT str_pw_t3, 2, 3
        lda #0
        sta text_attr
        jsr pw_enc_tune
        ldx #2                  ; two rows apart while it fits (160 letters)
        lda pw_len
        cmp #161
        bcc :+
        dex
:       stx pw_rstep
        lda #5
        jsr pw_print_rows
        PRINT str_pw_tnote, 2, 26
        PRINT str_pw_back, 2, 27
        jsr attr_upload
        jsr ppu_on
:       jsr wait_frame
        jsr read_pad
        lda pad_new
        and #BTN_A|BTN_B|BTN_START
        beq :-
pw_show_out:
        lda #SFX_BACK
        jmp sfx_play

; pw_print_rows: print PW_TEXT (pw_len) from row A, 16 per row in groups of
; 4, two rows apart.  PPU off.
pw_print_rows:
        sta pw_row
        lda #0
        sta pw_i
@row:   ldy #0
        ldx pw_i
@ch:    lda PW_TEXT,x
        sty pw_v
        tay
        lda pw_alpha,y
        ldy pw_v
        sta linebuf,y
        iny
        inx
        cpx pw_len
        beq @out
        txa
        and #3
        bne :+
        txa
        and #15
        beq @out                ; 16 per row
        lda #' '
        sta linebuf,y
        iny
:       jmp @ch
@out:   stx pw_i
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        ldx #6
        ldy pw_row
        jsr print
        clc
        lda pw_row
        adc pw_rstep
        sta pw_row
        lda pw_i
        cmp pw_len
        bne @row
        rts

; pw_title: TITLE > PASSWORD.  A = 0 when both passwords were taken and the
; game is loaded, 1 if the player backed out.  (A, not carry: farcall's bank
; switch shifts through the carry.)
pw_title:
        lda #1                  ; the keyboard types here, it isn't a pad
        sta kb_off
        lda #0
        sta pw_kind
        jsr pw_enter
        bcs @no
        lda #1
        sta pw_kind
        jsr pw_enter
        bcs @no
        lda #2                  ; tunes (START with nothing typed: none)
        sta pw_kind
        jsr pw_enter
        bcs @no
        jsr pw_apply
        jsr pw_apply_tune
        lda #0
        sta kb_off
        rts
@no:    lda #0
        sta kb_off
        lda #1
        rts

; pw_enter: type password pw_kind.  Carry clear when it decodes.
pw_enter:
        lda #0
        jsr screen_begin
        jsr use_menu_palette
        lda #$20
        sta text_attr
        ldx pw_kind
        lda pw_titles_lo,x
        sta ptr0
        lda pw_titles_hi,x
        sta ptr0+1
        ldx #2
        ldy #3
        jsr print
        lda #0
        sta text_attr
        ldx pw_kind
        lda pw_hints_lo,x
        sta ptr0
        lda pw_hints_hi,x
        sta ptr0+1
        ldx #2
        ldy #4
        jsr print
        ; letter grid: 4 rows of 8
        lda #0
        sta pw_i
@g:     ldx pw_i
        lda pw_alpha,x
        sta linebuf
        lda #0
        sta linebuf+1
        MOVI16 ptr0, linebuf
        jsr pw_grid_xy
        jsr print
        inc pw_i
        lda pw_i
        cmp #32
        bne @g
        PRINT str_pw_help1, 2, 26
        PRINT str_pw_help2, 2, 27
        PRINT str_pw_help3, 2, 28
        jsr attr_upload
        lda #0
        sta oam_idx
        jsr oam_clear
        jsr ppu_on
        lda #0
        sta pw_len
        sta pw_sel
        sta pw_win
        ldx pw_kind
        lda pw_maxes,x
        sta pw_max
        jsr kb_scan             ; keys already down don't type
@loop:  jsr wait_frame
        jsr read_pad
        lda pw_sel
        sta pw_i
        jsr pw_grid_xy
        dex
        jsr ui_cursor
        jsr kb_scan
        tax
        bmi @pad
        lda kb_map,x
        cmp #32
        bcs :+
        sta pw_sel              ; a letter: the cursor jumps to it
        jmp @add
:       cmp #KB_DEL
        jeq @del
        cmp #KB_RET
        jeq @done
        cmp #KB_BAD
        bne @pad
        lda #SFX_ERROR
        jsr sfx_play
@pad:
        lda pad_rpt
        and #BTN_RIGHT
        beq :+
        lda pw_sel
        tax
        and #$18
        sta pw_v
        inx
        txa
        and #7
        ora pw_v
        jmp @mv
:       lda pad_rpt
        and #BTN_LEFT
        beq :+
        lda pw_sel
        tax
        and #$18
        sta pw_v
        dex
        txa
        and #7
        ora pw_v
        jmp @mv
:       lda pad_rpt
        and #BTN_DOWN
        beq :+
        lda pw_sel
        clc
        adc #8
        and #31
        jmp @mv
:       lda pad_rpt
        and #BTN_UP
        beq :+
        lda pw_sel
        sec
        sbc #8
        and #31
        jmp @mv
:       lda pad_new
        and #BTN_A
        bne @add
        lda pad_new
        and #BTN_B
        bne @del
        lda pad_new
        and #BTN_START
        bne @done
        lda pad_new
        and #BTN_SELECT
        jeq @loop
        lda #SFX_BACK
        jsr sfx_play
        sec
        rts
@mv:    sta pw_sel
        lda #SFX_MOVE
        jsr sfx_play
        jmp @loop
@add:   ldx pw_len
        cpx pw_max
        bcs @err
        lda pw_sel
        sta PW_TEXT,x
        inc pw_len
        tay
        lda pw_alpha,y
        jsr pw_type_char
        lda #SFX_SELECT
        jsr sfx_play
        jsr pw_clear_msg
        jmp @loop
@del:   ldx pw_len
        jeq @loop
        dex
        stx pw_len
        lda #' '
        jsr pw_type_char
        lda #SFX_BACK
        jsr sfx_play
        jsr pw_clear_msg
        jmp @loop
@done:  lda pw_kind
        bne :+
        jsr pw_dec_player
        jmp @dec
:       cmp #1
        bne :+
        jsr pw_dec_garage
        jmp @dec
:       jsr pw_dec_tune
@dec:   bcs @err
        lda #SFX_BUY
        jsr sfx_play
        lda #20
        jsr wait_frames
        clc
        rts
@err:   lda #SFX_ERROR
        jsr sfx_play
        MOVI16 ptr0, str_pw_wrong
        ldx #2
        ldy #24
        jsr vb_str
        jmp @loop

pw_clear_msg:
        MOVI16 ptr0, str_pw_clear
        ldx #2
        ldy #24
        jmp vb_str

pw_maxes: .byte PLAYER_LEN2, GARAGE_MAX, TUNE_MAX

; pw_type_char: A = character typed (or ' ' deleted) at position X; pw_len
; already updated.  Five rows of 16 show; a long password scrolls a row at a
; time.  Also the letter count on row 5.
pw_type_char:
        pha
        txa
        pha
        lda pw_len              ; window: the row being typed is the last shown
        lsr a
        lsr a
        lsr a
        lsr a
        sec
        sbc #4
        bcs :+
        lda #0
:       cmp pw_win
        beq @same
        sta pw_win
        pla
        pla
        jsr pw_redraw_typed
        jmp pw_count
@same:  lda pw_win
        asl a
        asl a
        asl a
        asl a
        sta pw_v
        pla
        sec
        sbc pw_v
        tax
        pla
        jsr pw_show_char
        ; fall through
; pw_count: "12 LETTERS" on row 5
pw_count:
        lda pw_len
        sta m_a
        lda #0
        sta m_a+1
        jsr num_text
        ldy #0
        jsr cat_ptr0
        sty pw_v
        MOVI16 ptr0, str_pw_letters
        ldy pw_v
        jsr cat_ptr0
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        lda #14
        jsr pad_ptr0
        ldx #2
        ldy #5
        jmp vb_str

; pw_redraw_typed: the five rows of typed letters from row pw_win
pw_redraw_typed:
        lda #0
        sta pw_row
@row:   lda pw_win
        clc
        adc pw_row
        asl a
        asl a
        asl a
        asl a
        tax                     ; first position on this row
        ldy #0
@ch:    lda #' '
        cpx pw_len
        bcs :+
        lda PW_TEXT,x
        sty pw_v
        tay
        lda pw_alpha,y
        ldy pw_v
:       sta linebuf,y
        iny
        inx
        txa
        and #15
        beq @end
        and #3
        bne @ch
        lda #' '
        sta linebuf,y
        iny
        bne @ch
@end:   lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        lda pw_row
        asl a
        clc
        adc #6
        tay
        ldx #6
        jsr vb_str
        jsr wait_frame
        inc pw_row
        lda pw_row
        cmp #5
        bne @row
        rts

; pw_show_char: A = character for typed position X (rows 6-14, 16 per row)
pw_show_char:
        sta linebuf
        lda #0
        sta linebuf+1
        txa
        lsr a
        lsr a
        lsr a
        and #$FE                ; (X / 16) * 2
        clc
        adc #6
        tay
        txa
        and #15
        sta pw_v
        lsr a
        lsr a
        clc
        adc pw_v
        adc #6
        tax
        MOVI16 ptr0, linebuf
        jmp vb_str

; pw_grid_xy: letter pw_i -> X = column, Y = row (rows 16-22, 3 columns apart)
pw_grid_xy:
        lda pw_i
        and #7
        sta pw_v
        asl a
        adc pw_v
        adc #6
        tax
        lda pw_i
        lsr a
        lsr a
        and #$FE
        clc
        adc #16
        tay
        rts

pw_titles_lo: .byte <str_pw_t1, <str_pw_t2, <str_pw_t3
pw_titles_hi: .byte >str_pw_t1, >str_pw_t2, >str_pw_t3
pw_hints_lo:  .byte <str_pw_h1, <str_pw_h2, <str_pw_h3
pw_hints_hi:  .byte >str_pw_h1, >str_pw_h2, >str_pw_h3
str_pw_t1:     .byte "PASSWORD 1: PLAYER", 0
str_pw_t2:     .byte "PASSWORD 2: GARAGE", 0
str_pw_t3:     .byte "PASSWORD 3: TUNES", 0
str_pw_h3:     .byte "NO TUNES? JUST PRESS START", 0
str_pw_letters: .byte " LETTERS", 0
str_pw_tune_a: .byte "A: PASSWORD 3 (TUNES)", 0
str_pw_notune: .byte "NO TUNED CARS: NO PASSWORD 3", 0
str_pw_tnote:  .byte "TYPE IT AFTER PASSWORD 2", 0
str_pw_h1:     .byte "32 LETTERS", 0
str_pw_h2:     .byte "12 LETTERS, MORE WITH MORE CARS", 0
str_pw_help1:  .byte "A:ADD  B:DELETE  START:DONE", 0
str_pw_help2:  .byte "SELECT:BACK TO THE TITLE", 0
str_pw_help3:  .byte "OR TYPE IT ON A KEYBOARD", 0
str_pw_wrong:  .byte "WRONG PASSWORD, CHECK IT", 0
str_pw_clear:  .byte "                        ", 0
str_pw_yours:  .byte "YOUR PASSWORDS", 0
str_pw_player: .byte "1: PLAYER", 0
str_pw_garage: .byte "2: GARAGE", 0
str_pw_note1:  .byte "WRITE THEM DOWN. TITLE >", 0
str_pw_note2:  .byte "PASSWORD BRINGS YOU BACK.", 0
str_pw_back:   .byte "B:BACK", 0
