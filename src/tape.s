; ===========================================================================
; tape.s -- save and load the game on the Famicom Data Recorder (bank 6),
; plugged into the Family BASIC keyboard's tape jacks.  $4016 writes: bit 2
; turns the tape port on, bit 0 is the signal to the tape.  $4016 reads:
; bit 1 is the signal from the tape.
;
; Each bit is one square wave: two halves of TP_SHORT (a 0) or TP_LONG (a 1)
; delay steps.  Reading times every half and adds the two halves of a bit,
; so the tape's polarity and a lopsided wave don't matter.  A tape holds:
;   lead-in: TP_LEAD 0 bits | start: one 1 bit | the save ($6000-$61FF,
;   magic and checksum included) | sum 1 | sum of sums 1 | lead-out
; Loading reads into WBUF and takes the save only when both sums and the
; save's own checks (its magic and checksum: save_valid) agree.
; The routines are cycle-timed: NMI must be off while they run.
; ===========================================================================

.segment "BSS"
tp_lvl:     .res 1          ; the tape signal last seen ($4016 & 2)
tp_n:       .res 2
tp_v:       .res 1
tp_k:       .res 1
tp_a:       .res 1
tp_len:     .res 1
tp_sum:     .res 1
tp_sum2:    .res 1
tp_t:       .res 1          ; loading: halves and silences seen, for B checks
tp_sel:     .res 1
.segment "BANK6"

TP_SHORT = 80                   ; half a 0: 80 x 5 cycles (about 2.2 kHz)
TP_LONG  = 160                  ; half a 1: about 1.1 kHz
TP_LOOP  = 17                   ; cycles per tp_half count
TP_HALF  = (TP_SHORT + TP_LONG) * 5 / 2 / TP_LOOP   ; a long half from here
TP_PAIR  = TP_HALF * 2          ; a 1 bit from here (both halves added)
TP_LEAD  = 2000                 ; lead-in bits: about 0.9 s
TP_FOUND = 255                  ; short halves in a row that make a lead-in
TP_SIZE  = $200                 ; bytes saved: $6000-$61FF

TP_OK     = 0                   ; tape_read results
TP_CANCEL = 1
TP_BAD    = 2

; ---------------------------------------------------------------------------
; tape_write: the save onto the tape (NMI off)
; ---------------------------------------------------------------------------
tape_write:
        lda #<TP_LEAD
        sta tp_n
        lda #>TP_LEAD
        sta tp_n+1
@lead:  clc
        jsr tp_bit
        lda tp_n
        bne :+
        dec tp_n+1
:       dec tp_n
        lda tp_n
        ora tp_n+1
        bne @lead
        sec                     ; start bit
        jsr tp_bit
        lda #0
        sta tp_sum
        sta tp_sum2
        MOVI16 ptr2, $6000
@byte:  ldy #0
        lda (ptr2),y
        jsr tp_byte
        inc ptr2
        bne @byte
        inc ptr2+1
        lda ptr2+1
        cmp #>($6000 + TP_SIZE)
        bne @byte
        lda tp_sum2             ; (taken before the sum goes out)
        pha
        lda tp_sum
        jsr tp_put
        pla
        jsr tp_put
        ldx #32                 ; lead-out
:       clc
        jsr tp_bit
        dex
        bne :-
        lda #0                  ; tape port off
        sta JOY1
        rts

; tp_byte: A out, low bit first, into the sums.  tp_put: just out.
tp_byte:
        pha
        clc
        adc tp_sum
        sta tp_sum
        clc
        adc tp_sum2
        sta tp_sum2
        pla
tp_put:
        sta tp_v
        ldx #8
:       lsr tp_v
        jsr tp_bit
        dex
        bne :-
        rts

; tp_bit: carry = the bit, as one square wave.  Keeps X.
tp_bit:
        ldy #TP_SHORT
        bcc :+
        ldy #TP_LONG
:       sty tp_len
        lda #$05                ; port on, signal high
        sta JOY1
:       dey
        bne :-
        ldy tp_len
        lda #$04                ; signal low
        sta JOY1
:       dey
        bne :-
        rts

; ---------------------------------------------------------------------------
; tape_read: a save from the tape into WBUF (NMI off).  Waits for a lead-in
; (B gives up).  A = TP_OK (the sums agree), TP_CANCEL or TP_BAD.
; ---------------------------------------------------------------------------
tape_read:
        lda #$04                ; port on
        sta JOY1
        lda JOY1
        and #2
        sta tp_lvl
        lda #0
        sta tp_t
@seek:  lda #0                  ; short halves in a row
        sta tp_n
@s1:    inc tp_t                ; every 256 halves or silences: B?
        bne @s2
        jsr read_pad
        lda #$04                ; (read_pad turned the port off)
        sta JOY1
        lda pad
        and #BTN_B
        beq @s2
        lda #TP_CANCEL
        rts
@s2:    jsr tp_half
        bcs @seek               ; silence
        cpx #TP_HALF
        bcs @long
        inc tp_n
        bne @s1
        dec tp_n                ; (stays at 255)
        bne @s1
@long:  lda tp_n                ; after a lead-in: the start bit
        cmp #TP_FOUND
        bcc @seek
        jsr tp_half             ; its second half
        bcs @bad
        cpx #TP_HALF
        bcc @bad
        lda #0
        sta tp_sum
        sta tp_sum2
        MOVI16 ptr2, WBUF
@byte:  jsr tp_get
        bcs @bad
        ldy #0
        sta (ptr2),y
        inc ptr2
        bne @byte
        inc ptr2+1
        lda ptr2+1
        cmp #>(WBUF + TP_SIZE)
        bne @byte
        jsr tp_get              ; the sums
        bcs @bad
        sta tp_len              ; (tp_get uses tp_a)
        jsr tp_get
        bcs @bad
        pha
        lda #0                  ; port off
        sta JOY1
        MOVI16 ptr2, WBUF       ; check them (after the tape: no hurry)
@sum:   ldy #0
        lda (ptr2),y
        clc
        adc tp_sum
        sta tp_sum
        clc
        adc tp_sum2
        sta tp_sum2
        inc ptr2
        bne @sum
        inc ptr2+1
        lda ptr2+1
        cmp #>(WBUF + TP_SIZE)
        bne @sum
        pla
        cmp tp_sum2
        bne @bad2
        lda tp_len
        cmp tp_sum
        bne @bad2
        lda #TP_OK
        rts
@bad:   lda #0
        sta JOY1
@bad2:  lda #TP_BAD
        rts

; tp_get: A = a byte off the tape, low bit first.  Carry set: the signal
; stopped.
tp_get:
        lda #8
        sta tp_k
@b:     jsr tp_half
        bcs @r
        stx tp_a
        jsr tp_half
        bcs @r
        txa
        clc
        adc tp_a
        cmp #TP_PAIR            ; carry = the bit
        ror tp_v
        dec tp_k
        bne @b
        lda tp_v
        clc
@r:     rts

; tp_half: X = how long until the tape signal changes, in TP_LOOP-cycle
; counts.  Carry set if it didn't within 255 (silence).
tp_half:
        ldx #0
:       inx                     ; 2
        beq @quiet              ; 2
        lda JOY1                ; 4
        and #2                  ; 2
        cmp tp_lvl              ; 4
        beq :-                  ; 3: TP_LOOP cycles
        sta tp_lvl
        clc
        rts
@quiet: sec
        rts

; ---------------------------------------------------------------------------
; tape_take: the save tape_read left in WBUF becomes the game, if it is one
; (its magic and checksum).  Carry clear: taken.  Otherwise the game stays.
; ---------------------------------------------------------------------------
tape_take:
        ldx #0
:       lda WBUF,x
        sta $6000,x
        lda WBUF+$100,x
        sta $6100,x
        inx
        bne :-
        jsr save_valid
        bcc @no
        jsr cash_clamp
        jsr save_write          ; sealed, and the backup too
        jsr region_max          ; on the map at the furthest open region
        sta map_region
        clc
        rts
@no:    ldx #0                  ; not a save: back to the last one
:       lda SV_BACKUP,x
        sta $6000,x
        lda SV_BACKUP+$100,x
        sta $6100,x
        inx
        bne :-
        sec
        rts

; ---------------------------------------------------------------------------
; tape_screen: OPTIONS / TITLE > DATA RECORDER.  A = 0 when a game was
; loaded (the caller goes to the garage), else 1.
; ---------------------------------------------------------------------------
TP_Y0 = 6                       ; items on rows 6, 8, 10
TP_MY = 24                      ; message line

tape_screen:
        lda #0
        jsr screen_begin
        jsr use_menu_palette
        MOVI16 ptr0, str_tape
        jsr draw_header
        PRINT str_tp0, 4, TP_Y0
        PRINT str_tp1, 4, TP_Y0+2
        PRINT str_tp2, 4, TP_Y0+4
        BOX 1, 13, 30, 9
        PRINT str_th0, 3, 14
        PRINT str_th1, 3, 15
        PRINT str_th2, 3, 17
        PRINT str_th3, 3, 18
        PRINT str_th4, 3, 19
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
        lda #TP_Y0
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
        jeq @back
        cmp #1
        bne @loop
        lda ui_sel
        cmp #2
        jeq @back
        sta tp_sel
        cmp #0
        bne @load
        ; save
        MOVI16 ptr0, str_tm_save
        jsr tp_msg
        jsr tp_quiet
        jsr tape_write
        jsr tp_loud
        MOVI16 ptr0, str_tm_saved
        jsr tp_msg
        lda #SFX_BUY
        jsr sfx_play
        jmp @loop
@load:  MOVI16 ptr0, str_tm_play
        jsr tp_msg
        jsr tp_quiet
        jsr tape_read
        sta tp_sel
        jsr tp_loud
        lda tp_sel
        cmp #TP_CANCEL
        bne :+
        MOVI16 ptr0, str_tm_cancel
        jsr tp_msg
        jmp @loop
:       cmp #TP_OK
        bne @err
        jsr tape_take
        bcs @notsave
        MOVI16 ptr0, str_tm_loaded
        jsr tp_msg
        lda #SFX_LEVELUP
        jsr sfx_play
        lda #60
        jsr wait_frames
        lda #0                  ; loaded: to the garage
        rts
@notsave:
        MOVI16 ptr0, str_tm_notsave
        jmp :+
@err:   MOVI16 ptr0, str_tm_err
:       jsr tp_msg
        lda #SFX_ERROR
        jsr sfx_play
        jmp @loop
@back:  lda #SFX_BACK
        jsr sfx_play
        lda #1
        rts

; tp_quiet: music off, then NMI off (the screen stays up) for the timed
; tape routines.  tp_loud: NMI back on at the start of a vblank.
tp_quiet:
        jsr music_stop
        jsr wait_frame
        lda ppu_ctrl
        and #$7F
        sta PPUCTRL
        rts
tp_loud:
        bit PPUSTATUS
:       bit PPUSTATUS
        bpl :-
        lda ppu_ctrl
        sta PPUCTRL
        jsr wait_frame
        lda garage_song         ; the music again (unless it's off)
        jmp music_play

; tp_msg: ptr0 on the message line
tp_msg:
        lda #28
        jsr pad_ptr0
        ldx #2
        ldy #TP_MY
        jmp vb_str

str_tape:       .byte "DATA RECORDER", 0
str_tp0:        .byte "SAVE TO TAPE", 0
str_tp1:        .byte "LOAD FROM TAPE", 0
str_tp2:        .byte "BACK", 0
str_th0:        .byte "PLUG THE DATA RECORDER INTO", 0
str_th1:        .byte "THE FAMILY BASIC KEYBOARD.", 0
str_th2:        .byte "SAVE: PRESS RECORD, THEN A.", 0
str_th3:        .byte "LOAD: REWIND, PRESS A, THEN", 0
str_th4:        .byte "PLAY. B GIVES UP.", 0
str_tm_save:    .byte "SAVING... KEEP RECORDING", 0
str_tm_saved:   .byte "SAVED! PRESS STOP", 0
str_tm_play:    .byte "PRESS PLAY... (B: GIVE UP)", 0
str_tm_cancel:  .byte "NOTHING LOADED", 0
str_tm_loaded:  .byte "LOADED!", 0
str_tm_err:     .byte "TAPE ERROR: REWIND, RETRY", 0
str_tm_notsave: .byte "NOT A SAVE FROM THIS VERSION", 0
