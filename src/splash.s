; ===========================================================================
; splash.s -- boot splash screen (bank 4).  Art: tools/mksplash.py.
; Replaces the whole BG pattern table while it is up; the title screen
; reloads the normal tiles.  Fades in, revs an engine, blinks PRESS START,
; and moves on after a button press or about five seconds.
; ===========================================================================

.segment "BSS"
spl_t:      .res 2
.segment "BANK4"

splash_chr:     .incbin "build/splash.chr"
splash_nam:     .incbin "build/splash.nam"

; BG palettes: 0 scenery/logo, 1 text, 2 (unused), 3 car
splash_pal:
        .byte $0F,$16,$27,$38,  $0F,$30,$10,$28,  $0F,$16,$27,$38,  $0F,$16,$30,$00

splash_main:
        jsr ppu_off
        lda #0
        sta oam_idx
        jsr oam_clear
        MOVI16 ptr0, splash_chr
        lda #<$1000
        sta tmp0
        lda #>$1000
        sta tmp1
        lda #BANK_SCENE
        sta copy_bank
        lda #$00
        ldx #$00
        jsr chr_copy
        MOVI16 ptr0, splash_nam
        lda #<$0400
        sta tmp0
        lda #>$0400
        sta tmp1
        lda #BANK_SCENE
        sta copy_bank
        lda #$20
        ldx #$00
        jsr chr_copy
        lda #0
        jsr spl_fade            ; start black
        jsr ppu_on
        jsr engine_start
        lda #0
        sta eng_duty
        sta eng_orpm
        sta eng_orpm+1
        sta eng_noise
        sta spl_t
        sta spl_t+1
        ; fade in
        ldx #1
@in:    txa
        pha
        jsr spl_fade
        lda #6
        jsr wait_frames_snd
        pla
        tax
        inx
        cpx #5
        bne @in
@loop:  jsr wait_frame
        jsr read_pad
        jsr spl_engine
        ; blink PRESS START (text palette colour 1)
        lda spl_t
        and #$20
        beq :+
        lda #$0F
        bne :++
:       lda #$30
:       sta palette+5
        lda #1
        sta pal_dirty
        inc spl_t
        bne :+
        inc spl_t+1
:       lda pad_new
        and #BTN_START|BTN_A|BTN_B
        bne @out
        lda spl_t+1             ; ~5 seconds
        beq @loop
        lda spl_t
        cmp #300-256
        bcc @loop
@out:   jsr engine_stop
        ldx #3
@fade:  txa
        pha
        jsr spl_fade
        lda #4
        jsr wait_frames
        pla
        tax
        dex
        bpl @fade
        lda #MODE_TITLE
        sta next_mode
        rts

; wait_frames_snd: wait A frames, keeping the engine sound going
wait_frames_snd:
        sta tmp7
:       jsr wait_frame
        jsr spl_engine
        dec tmp7
        bne :-
        rts

; spl_engine: a blip of the throttle as the screen comes up
spl_engine:
        lda spl_t+1
        bne @idle
        lda spl_t
        cmp #20
        bcc @idle
        cmp #44
        bcs @down
        lda #1                  ; rev up: +250 rpm a frame
        sta eng_thr
        clc
        lda eng_rpm
        adc #250
        sta eng_rpm
        bcc :+
        inc eng_rpm+1
:       rts
@down:  lda #0
        sta eng_thr
        lda eng_rpm+1           ; fall back to idle
        cmp #>1100
        bcc @idle
        sec
        lda eng_rpm
        sbc #150
        sta eng_rpm
        bcs :+
        dec eng_rpm+1
:       rts
@idle:  lda #<900
        sta eng_rpm
        lda #>900
        sta eng_rpm+1
        lda #0
        sta eng_thr
        rts

; spl_fade: A = brightness 0 (black) .. 4 (full).  Builds the palette.
spl_fade:
        eor #$FF                ; darkness steps = 4 - A
        clc
        adc #5
        asl a
        asl a
        asl a
        asl a
        sta tmp6                ; amount to subtract ($00-$40)
        ldx #0
@c:     lda splash_pal,x
        cmp #$0F
        beq @st
        sec
        sbc tmp6
        bcs @st
        lda #$0F                ; too dark: black
@st:    sta palette,x
        inx
        cpx #16
        bne @c
        lda #$0F
@s:     sta palette,x           ; sprite palettes black
        inx
        cpx #32
        bne @s
        lda #1
        sta pal_dirty
        rts
