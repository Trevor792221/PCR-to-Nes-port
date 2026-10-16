; ===========================================================================
; sound.s -- music player, sound effects and the engine synthesizer
; (fixed bank; sound_update runs in the NMI every frame)
;
; Channel use:
;   pulse 1   music lead, or the player's engine during races
;   pulse 2   music harmony / effects / the opponent's engine
;   triangle  music bass, or the engine's low octave
;   noise     drums / effects / exhaust, tyre squeal, nitrous hiss
; ===========================================================================

SFX_MOVE    = 1
SFX_SELECT  = 2
SFX_BACK    = 3
SFX_BUY     = 4
SFX_ERROR   = 5
SFX_AMBER   = 6
SFX_GREEN   = 7
SFX_SHIFT   = 8
SFX_BLOWOFF = 9
SFX_NOS     = 10
SFX_CRATE   = 11
SFX_LEVELUP = 12
SFX_CRASH   = 13
SFX_FOUL    = 14
SFX_TICK    = 15

MUS_TEMPO   = 8                 ; frames per sixteenth

.segment "BSS"
mus_on:     .res 1
mus_tick:   .res 1
mus_ptr_l:  .res 4
mus_ptr_h:  .res 4
mus_timer:  .res 4
mus_len:    .res 4
mus_inst:   .res 4
mus_vol:    .res 4
mus_vcnt:   .res 4
mus_note:   .res 4
mus_act:    .res 4
mus_trig:   .res 4
mus_lasthi: .res 4
sfx2_t:     .res 1
sfxn_t:     .res 1
sfx_q2:     .res 1
sfx_qn:     .res 1
eng_on:     .res 1          ; engine synth active (race)
eng_rpm:    .res 2
eng_thr:    .res 1
eng_duty:   .res 1
eng_orpm:   .res 2          ; opponent rpm (0 = silent)
eng_noise:  .res 1          ; 0 exhaust, 1 nitrous, 2 tyre squeal

.segment "ZEROPAGE"
snd_tmp:    .res 3
sfx2_ptr:   .res 2
sfxn_ptr:   .res 2

.segment "FIXED"
.include "build/music.inc"

sound_init:
        lda #$0F
        sta APUSTATUS
        lda #$08                ; sweep off (negate to avoid mute on low notes)
        sta SQ1_SWP
        sta SQ2_SWP
        lda #$30
        sta SQ1_VOL
        sta SQ2_VOL
        sta NOI_VOL
        lda #$80
        sta TRI_LIN
        lda #0
        sta mus_on
        sta eng_on
        sta sfx2_t
        sta sfxn_t
        rts

; music_play: A = song.  Respects the "music off" option.
music_play:
        tax
        lda SV_OPTIONS
        and #OPT_NOMUSIC
        beq :+
        cpx #SONG_GARAGE
        bne :+
        jmp music_stop
:       lda #0
        sta mus_on              ; stop the NMI player while we set up
        txa
        asl a
        asl a
        asl a
        tax                     ; song*8
        ldy #0
@c:     lda song_table,x
        sta mus_ptr_l,y
        lda song_table+1,x
        sta mus_ptr_h,y
        lda #1
        sta mus_timer,y
        sta mus_act,y
        sta mus_len,y
        lda #0
        sta mus_note,y
        sta mus_inst,y
        sta mus_vol,y
        lda #$FF
        sta mus_lasthi,y
        inx
        inx
        iny
        cpy #4
        bne @c
        lda #MUS_TEMPO-1
        sta mus_tick
        lda #1
        sta mus_on
        rts

music_stop:
        lda #0
        sta mus_on
        lda #$30
        sta SQ1_VOL
        sta SQ2_VOL
        sta NOI_VOL
        lda #$80
        sta TRI_LIN
        rts

; sfx_play: A = effect id.  Safe to call from the main thread.
sfx_play:
        tax
        lda sfx_chan-1,x
        bne @n
        stx sfx_q2
        rts
@n:     stx sfx_qn
        rts

; engine_start / engine_stop (race)
engine_start:
        jsr music_stop
        lda #1
        sta eng_on
        rts
engine_stop:
        lda #0
        sta eng_on
        lda #$30
        sta SQ1_VOL
        sta SQ2_VOL
        sta NOI_VOL
        lda #$80
        sta TRI_LIN
        rts

; ---------------------------------------------------------------------------
sound_update:
        ; --- start queued effects ----------------------------------------
        ldx sfx_q2
        beq :+
        lda #0
        sta sfx_q2
        lda sfx_lo-1,x
        sta sfx2_ptr
        lda sfx_hi-1,x
        sta sfx2_ptr+1
        lda #1
        sta sfx2_t
        lda #$FF
        sta mus_lasthi+1
:       ldx sfx_qn
        beq :+
        lda #0
        sta sfx_qn
        lda sfx_lo-1,x
        sta sfxn_ptr
        lda sfx_hi-1,x
        sta sfxn_ptr+1
        lda #1
        sta sfxn_t
:
        ; --- music sequencer ---------------------------------------------
        lda mus_on
        beq @nomus
        inc mus_tick
        lda mus_tick
        cmp #MUS_TEMPO
        bcc @env
        lda #0
        sta mus_tick
        ldx #3
@ch:    lda mus_act,x
        beq @nextch
        dec mus_timer,x
        bne @nextch
        jsr mus_events
@nextch:
        dex
        bpl @ch
@env:   ; envelopes
        ldx #3
@ev:    ldy mus_inst,x
        lda instr_rate,y
        beq @evn
        dec mus_vcnt,x
        bne @evn
        sta mus_vcnt,x
        lda mus_vol,x
        cmp instr_floor,y
        beq @evn
        bcc @evn
        dec mus_vol,x
@evn:   dex
        bpl @ev
@nomus:
        ; --- pulse 1: engine or music ------------------------------------
        lda eng_on
        beq @p1mus
        jsr eng_pulse1
        jmp @p2
@p1mus: lda mus_on
        beq @p2
        ldx #0
        jsr mus_out_pulse
        ; --- pulse 2: effect, opponent engine or music --------------------
@p2:    lda sfx2_t
        beq @p2n
        jsr sfx2_run
        jmp @tri
@p2n:   lda eng_on
        beq @p2mus
        jsr eng_pulse2
        jmp @tri
@p2mus: lda mus_on
        beq @tri
        ldx #1
        jsr mus_out_pulse
        ; --- triangle ----------------------------------------------------
@tri:   lda eng_on
        beq @trimus
        jsr eng_tri
        jmp @noi
@trimus:
        lda mus_on
        beq @noi
        jsr mus_out_tri
        ; --- noise --------------------------------------------------------
@noi:   lda sfxn_t
        beq @noin
        jmp sfxn_run
@noin:  lda eng_on
        beq @noimus
        jmp eng_noise_out
@noimus:
        lda mus_on
        beq @done
        jmp mus_out_noise
@done:  rts

; mus_events: channel X reached the end of a note; read the next events
mus_events:
        lda mus_ptr_l,x
        sta snd_tmp
        lda mus_ptr_h,x
        sta snd_tmp+1
        ldy #0
@rd:    lda (snd_tmp),y
        iny
        cmp #$FF
        bne @nj
        lda (snd_tmp),y
        pha
        iny
        lda (snd_tmp),y
        sta snd_tmp+1
        pla
        sta snd_tmp
        ldy #0
        jmp @rd
@nj:    cmp #$FE
        bne @ne
        lda #0
        sta mus_act,x
        sta mus_note,x
        rts
@ne:    cmp #$C0
        bcc @nins
        and #$3F
        sta mus_inst,x
        jmp @rd
@nins:  cmp #$80
        bcc @note
        and #$3F
        sta mus_len,x
        jmp @rd
@note:  sta mus_note,x
        lda mus_len,x
        sta mus_timer,x
        lda #1
        sta mus_trig,x
        tya
        clc
        adc snd_tmp
        sta mus_ptr_l,x
        lda snd_tmp+1
        adc #0
        sta mus_ptr_h,x
        ldy mus_inst,x
        lda instr_vol,y
        sta mus_vol,x
        lda instr_rate,y
        sta mus_vcnt,x
        rts

; mus_out_pulse: X = 0/1, write pulse channel X from music state
mus_out_pulse:
        txa
        asl a
        asl a
        tay                     ; register offset 0 or 4
        lda mus_note,x
        beq @off
        sty snd_tmp
        ldy mus_inst,x
        lda instr_duty,y
        ora #$30
        ora mus_vol,x
        ldy snd_tmp
        sta SQ1_VOL,y
        lda mus_note,x
        stx snd_tmp+1
        tax
        lda note_lo,x
        sta SQ1_LO,y
        lda note_hi,x
        ldx snd_tmp+1
        cmp mus_lasthi,x
        beq @same
        sta mus_lasthi,x
        sta SQ1_HI,y
@same:  lda #0
        sta mus_trig,x
        rts
@off:   lda #$30
        sta SQ1_VOL,y
        rts

mus_out_tri:
        lda mus_note+2
        beq @off
        lda #$FF
        sta TRI_LIN
        ldx mus_note+2
        lda note_lo,x
        sta TRI_LO
        lda note_hi,x
        cmp mus_lasthi+2
        beq :+
        sta mus_lasthi+2
        sta TRI_HI
:       rts
@off:   lda #$80
        sta TRI_LIN
        rts

mus_out_noise:
        lda mus_note+3
        beq @off
        lda mus_vol+3
        ora #$30
        sta NOI_VOL
        lda mus_note+3
        sec
        sbc #1
        sta NOI_LO
        lda mus_trig+3
        beq :+
        lda #0
        sta mus_trig+3
        lda #$08
        sta NOI_HI
:       rts
@off:   lda #$30
        sta NOI_VOL
        rts

; --- effects -----------------------------------------------------------------
; pulse 2 steps: frames, vol, lo, hi (frames = 0 ends)
sfx2_run:
        dec sfx2_t
        bne @r
        ldy #0
        lda (sfx2_ptr),y
        beq @end
        sta sfx2_t
        iny
        lda (sfx2_ptr),y
        sta SQ2_VOL
        iny
        lda (sfx2_ptr),y
        sta SQ2_LO
        iny
        lda (sfx2_ptr),y
        sta SQ2_HI
        clc
        lda sfx2_ptr
        adc #4
        sta sfx2_ptr
        bcc @r
        inc sfx2_ptr+1
@r:     rts
@end:   lda #$30
        sta SQ2_VOL
        lda #$FF
        sta mus_lasthi+1
        rts

; noise steps: frames, vol, period
sfxn_run:
        dec sfxn_t
        bne @r
        ldy #0
        lda (sfxn_ptr),y
        beq @end
        sta sfxn_t
        iny
        lda (sfxn_ptr),y
        sta NOI_VOL
        iny
        lda (sfxn_ptr),y
        sta NOI_LO
        lda #$08
        sta NOI_HI
        clc
        lda sfxn_ptr
        adc #3
        sta sfxn_ptr
        bcc @r
        inc sfxn_ptr+1
@r:     rts
@end:   lda #$30
        sta NOI_VOL
        rts

; --- engine synth ------------------------------------------------------------
; eng_period: rpm in snd_tmp.. -> snd_tmp = period (from table), uses X
eng_period:
        lda eng_rpm+1
        ldx eng_rpm
eng_period_ax:
        ; idx = rpm >> 7 = hi*2 + (lo>>7)
        stx snd_tmp
        asl snd_tmp
        rol a
        cmp #96
        bcc :+
        lda #95
:       tax
        lda engine_period_l,x
        sta snd_tmp
        lda engine_period_h,x
        sta snd_tmp+1
        rts

eng_pulse1:
        jsr eng_period
        lda eng_thr
        beq :+
        lda #11
        bne :++
:       lda #6
:       ora eng_duty
        ora #$30
        sta SQ1_VOL
        ; a little roughness: wobble the period by the frame counter
        lda frame
        and #3
        clc
        adc snd_tmp
        sta SQ1_LO
        lda snd_tmp+1
        adc #0
        cmp mus_lasthi
        beq :+
        sta mus_lasthi
        sta SQ1_HI
:       rts

eng_tri:
        jsr eng_period
        asl snd_tmp
        rol snd_tmp+1
        lda snd_tmp+1
        cmp #8
        bcc :+
        lda #$80
        sta TRI_LIN
        rts
:       lda #$FF
        sta TRI_LIN
        lda snd_tmp
        sta TRI_LO
        lda snd_tmp+1
        cmp mus_lasthi+2
        beq :+
        sta mus_lasthi+2
        sta TRI_HI
:       rts

eng_pulse2:
        lda eng_orpm
        ora eng_orpm+1
        bne :+
        lda #$30
        sta SQ2_VOL
        rts
:       lda eng_orpm+1
        ldx eng_orpm
        jsr eng_period_ax
        lda #$B3
        sta SQ2_VOL
        lda snd_tmp
        sta SQ2_LO
        lda snd_tmp+1
        cmp mus_lasthi+1
        beq :+
        sta mus_lasthi+1
        sta SQ2_HI
:       rts

eng_noise_out:
        lda eng_noise
        cmp #1
        beq @nos
        cmp #2
        beq @squeal
        ; exhaust rumble
        lda eng_thr
        beq :+
        lda #$33
        bne :++
:       lda #$31
:       sta NOI_VOL
        lda frame
        and #1
        ora #$0C
        sta NOI_LO
        rts
@nos:   lda #$36
        sta NOI_VOL
        lda #$02
        sta NOI_LO
        rts
@squeal:
        lda #$37
        sta NOI_VOL
        lda frame
        and #1
        ora #$84
        sta NOI_LO
        rts

; --- effect data -----------------------------------------------------------
; channel per effect: 0 = pulse 2, 1 = noise
sfx_chan:
        .byte 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0, 0
sfx_lo:
        .byte <sfxd_move, <sfxd_select, <sfxd_back, <sfxd_buy, <sfxd_error
        .byte <sfxd_amber, <sfxd_green, <sfxd_shift, <sfxd_blowoff, <sfxd_nos
        .byte <sfxd_crate, <sfxd_levelup, <sfxd_crash, <sfxd_foul, <sfxd_tick
sfx_hi:
        .byte >sfxd_move, >sfxd_select, >sfxd_back, >sfxd_buy, >sfxd_error
        .byte >sfxd_amber, >sfxd_green, >sfxd_shift, >sfxd_blowoff, >sfxd_nos
        .byte >sfxd_crate, >sfxd_levelup, >sfxd_crash, >sfxd_foul, >sfxd_tick

sfxd_move:    .byte 2,$B8,126,0, 2,$B4,126,0, 0
sfxd_select:  .byte 3,$B9,84,0, 4,$B9,63,0, 3,$B4,63,0, 0
sfxd_back:    .byte 3,$B8,126,0, 4,$B6,168,0, 0
sfxd_buy:     .byte 3,$B9,126,0, 3,$B9,100,0, 3,$B9,84,0, 8,$BA,63,0, 6,$B5,63,0, 0
sfxd_error:   .byte 6,$7A,$FB,1, 6,$76,$FB,1, 0
sfxd_amber:   .byte 10,$BA,253,0, 0
sfxd_green:   .byte 24,$BC,126,0, 0
sfxd_shift:   .byte 2,$3A,$05, 2,$36,$07, 0
sfxd_blowoff: .byte 3,$3C,$02, 3,$3A,$02, 3,$38,$03, 3,$36,$03, 3,$34,$04, 3,$32,$04, 0
sfxd_nos:     .byte 4,$3E,$01, 6,$3B,$02, 6,$38,$02, 0
sfxd_crate:   .byte 4,$B9,213,0, 4,$B9,169,0, 4,$B9,142,0, 4,$B9,106,0
              .byte 4,$BA,84,0, 12,$BB,70,0, 8,$B5,70,0, 0
sfxd_levelup: .byte 5,$B9,169,0, 5,$B9,142,0, 5,$B9,106,0, 5,$B9,142,0
              .byte 5,$BA,106,0, 16,$BB,84,0, 0
sfxd_crash:   .byte 4,$3F,$0C, 6,$3C,$0D, 8,$38,$0E, 8,$34,$0F, 0
sfxd_foul:    .byte 30,$7A,$FB,$01, 0
sfxd_tick:    .byte 1,$B6,84,0, 0
