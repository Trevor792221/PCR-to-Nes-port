; ===========================================================================
; password.s -- the two passwords that replace the battery save (bank 5)
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

.segment "BANK5"

PW_BUF    = DYNO_BMP            ; 48-byte bit buffer (dyno work area)
PW_BUFSZ  = 48
PW_TEXT   = DYNO_BMP + $40      ; up to 72 symbols (0-31)
PW_PL     = DYNO_BMP + $90      ; decoded player fields (25 bytes, see pw_apply)
PW_N      = DYNO_BMP + $B0      ; decoded garage: cars
PW_CUR    = DYNO_BMP + $B1      ;   car in use
PW_CARS   = DYNO_BMP + $C0      ;   8 x 16: model, 14 parts, colour index
PWC_SIZE  = 16
PWC_PAINT = 1 + NPARTS

PW_PL_SIZE   = 25
SEED_PLAYER  = $5A
SEED_GARAGE  = $C3
PLAYER_LEN   = 15               ; version 1 (v3.0): no stats
PLAYER_LEN2  = 32               ; version 2: with stats
GARAGE_MAX   = 74

pw_alpha:   .byte "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
garage_len: .byte 12, 21, 30, 39, 48, 56, 65, 74    ; version 3: (16 + 44*cars + 4) / 5
garage_len2: .byte 11, 19, 27, 35, 43, 50, 58, 66   ; versions 1-2: 12 parts, 39 bits a car
garage_pad: .byte 0, 1, 2, 3, 4, 0, 1, 2            ; 5*len - bits (the same for both)

; ---------------------------------------------------------------------------
; Bit buffer
; ---------------------------------------------------------------------------
pw_reset:
        lda #0
        ldx #PW_BUFSZ-1
:       sta PW_BUF,x
        dex
        bpl :-
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
        lda #3                  ; version 3: CRC, 14 parts
        ldx #2
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
        beq @next
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
@next:  inc pw_s
        lda pw_s
        cmp #NSLOTS
        bne @car
        lda pw_chk
        ldx #8
        jsr pw_putb
        ldx pw_i
        lda garage_len-1,x
        sta pw_len
        jmp pw_to_text

; pw_dec_garage: PW_TEXT -> PW_N, PW_CUR, PW_CARS.  Carry set if wrong.
pw_dec_garage:
        lda pw_len
        cmp #11
        jcc pw_bad
        jsr pw_from_text
        ldx #2                  ; version 1 (v3.0) field sum, 2 CRC,
        jsr pw_getb             ; 3 (v4.2) CRC and 14 parts
        sta pw_ver
        beq @bad
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
        cmp pw_ver
        beq :+
@bad:   jmp pw_bad
:
        ldx #3
        jsr pw_get
        tax
        inx
        stx PW_N
        lda garage_len-1,x
        ldy pw_ver
        cpy #3
        beq :+
        lda garage_len2-1,x
:       cmp pw_len
        jne pw_bad
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
        clc
        lda ptr2
        adc #PWC_SIZE
        sta ptr2
        bcc :+
        inc ptr2+1
:       inc pw_s
        lda pw_s
        cmp PW_N
        bne @car
        lda pw_chk
        sta pw_want
        ldx #8
        jsr pw_getb
        cmp pw_want
        jne pw_bad
        ldx PW_N                ; the spare bits in the last letter must be 0
        lda garage_pad-1,x
        beq :+
        tax
        jsr pw_getb
        jne pw_bad
:       clc
        rts

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
        lda #14
        jsr pw_print_rows
        PRINT str_pw_note1, 2, 24
        PRINT str_pw_note2, 2, 25
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
        inc pw_row
        inc pw_row
        lda pw_i
        cmp pw_len
        bne @row
        rts

; pw_title: TITLE > PASSWORD.  A = 0 when both passwords were taken and the
; game is loaded, 1 if the player backed out.  (A, not carry: farcall's bank
; switch shifts through the carry.)
pw_title:
        lda #0
        sta pw_kind
        jsr pw_enter
        bcs @no
        lda #1
        sta pw_kind
        jsr pw_enter
        bcs @no
        jsr pw_apply
        lda #0
        rts
@no:    lda #1
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
        jsr attr_upload
        lda #0
        sta oam_idx
        jsr oam_clear
        jsr ppu_on
        lda #0
        sta pw_len
        sta pw_sel
        lda #PLAYER_LEN2
        ldx pw_kind
        beq :+
        lda #GARAGE_MAX
:       sta pw_max
@loop:  jsr wait_frame
        jsr read_pad
        lda pw_sel
        sta pw_i
        jsr pw_grid_xy
        dex
        jsr ui_cursor
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
        beq @loop
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
        tay
        lda pw_alpha,y
        jsr pw_show_char
        inc pw_len
        lda #SFX_SELECT
        jsr sfx_play
        jsr pw_clear_msg
        jmp @loop
@del:   ldx pw_len
        jeq @loop
        dex
        stx pw_len
        lda #' '
        jsr pw_show_char
        lda #SFX_BACK
        jsr sfx_play
        jsr pw_clear_msg
        jmp @loop
@done:  lda pw_kind
        bne :+
        jsr pw_dec_player
        jmp :++
:       jsr pw_dec_garage
:       bcs @err
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

pw_titles_lo: .byte <str_pw_t1, <str_pw_t2
pw_titles_hi: .byte >str_pw_t1, >str_pw_t2
pw_hints_lo:  .byte <str_pw_h1, <str_pw_h2
pw_hints_hi:  .byte >str_pw_h1, >str_pw_h2
str_pw_t1:     .byte "PASSWORD 1: PLAYER", 0
str_pw_t2:     .byte "PASSWORD 2: GARAGE", 0
str_pw_h1:     .byte "32 LETTERS", 0
str_pw_h2:     .byte "12 LETTERS, MORE WITH MORE CARS", 0
str_pw_help1:  .byte "A:ADD  B:DELETE  START:DONE", 0
str_pw_help2:  .byte "SELECT:BACK TO THE TITLE", 0
str_pw_wrong:  .byte "WRONG PASSWORD, CHECK IT", 0
str_pw_clear:  .byte "                        ", 0
str_pw_yours:  .byte "YOUR PASSWORDS", 0
str_pw_player: .byte "1: PLAYER", 0
str_pw_garage: .byte "2: GARAGE", 0
str_pw_note1:  .byte "WRITE BOTH DOWN. TITLE >", 0
str_pw_note2:  .byte "PASSWORD BRINGS YOU BACK.", 0
str_pw_back:   .byte "B:BACK", 0
