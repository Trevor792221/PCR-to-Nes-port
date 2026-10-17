; ===========================================================================
; race.s -- drag, street and test races (bank 2)
;
; Screen: rows 0-5 HUD (fixed), rows 6-14 skyline (1/4 speed parallax),
; rows 15-29 road (full speed).  Sprite 0 marks the end of the HUD; the
; road split is timed from there.
; ===========================================================================

RS_TREE    = 0
RS_RUN     = 1
RS_END     = 2

LANE0_Y    = 147
LANE1_Y    = 179
LANE2_Y    = 211
NTRAFFIC   = 3
MAP_COPY   = WBUF               ; rows 6-29 of the race map (768 bytes)

.segment "BSS"
rc_state:   .res 1
rc_t:       .res 2          ; frames since the tree started / since green
rc_tree:    .res 1          ; lights lit (0-4)
rc_green:   .res 1
rc_ms:      .res 2          ; running clock (ms)
rc_ms3:     .res 1          ; 0-2 for the 17/17/16 ms pattern
clk:        .res 5          ; clock digits: s10 s1 ms100 ms10 ms1
lag:        .res 1          ; frames the race loop missed (debug/test)
last_fr:    .res 1
rc_launch:  .res 2          ; car launched
rc_fin:     .res 2          ; car finished
rc_fin_t_l: .res 2          ; finish frame
rc_fin_t_h: .res 2
rc_t60:     .res 2
rc_rt:      .res 2          ; player reaction frames
rc_endt:    .res 1          ; frames until results
rc_opp:     .res 1          ; opponent present
rc_street:  .res 1
cam:        .res 2
fin_x:      .res 2          ; world x of the finish line
fin_done:   .res 1          ; 0 not drawn, 1 drawn, 2 restored
start_done: .res 1
msg_ptr:    .res 2
msg_dirty:  .res 1
msg_t:      .res 1
tree_dirty: .res 1
tach_k:     .res 2
prog_k:     .res 2
ai_launch:  .res 2
ai_shift:   .res 2
ai_react:   .res 1
car_y:      .res 2          ; sprite y of each car
car_lane:   .res 2          ; target lane
flame_t:    .res 2
crash_t:    .res 2
paused:     .res 1
foul:       .res 1
quit:       .res 1
split_dly:  .res 1
tr_x_l:     .res NTRAFFIC   ; traffic: world x (16) + fraction
tr_x_h:     .res NTRAFFIC
tr_x_f:     .res NTRAFFIC
tr_lane:    .res NTRAFFIC
tr_spd:     .res NTRAFFIC   ; px/frame * 64
tr_on:      .res NTRAFFIC
tr_type:    .res NTRAFFIC   ; vehicle type 0-4 (see tr_shape)
tr_pal:     .res NTRAFFIC   ; sprite palette (3, or 2 when cruising)
tr_spawn:   .res 1
hud_gear:   .res 1
mark_x:     .res 2
nos_k:      .res 1          ; 48*256/nos_frames
sx_l:       .res 1          ; signed screen x scratch
sx_h:       .res 1
sky_x:      .res 2
road_x:     .res 2

.segment "BANK2"

; ===========================================================================
race_main:
        jsr race_setup
@loop:  jsr wait_frame
        ; cheap, PPU-free work fits before sprite 0 is hit
        lda paused
        bne :++
        lda rc_street
        beq :+
        jsr traffic_update
:       jsr hud_update          ; shows last frame's state (1 frame late)
:       jsr race_split
        lda frame
        sec
        sbc last_fr
        cmp #2
        bcc :+
        inc lag
:       lda frame
        sta last_fr
        jsr read_pad
        lda paused
        beq :+
        jsr race_pause
        jmp @loop
:       jsr race_frame
        lda rc_state
        cmp #RS_END
        bne @loop
        lda rc_endt
        bne @loop
        ; done
        jsr engine_stop
        jsr race_results
        lda quit
        beq :+
        lda #MODE_GARAGE
        sta next_mode
        rts
:       lda #MODE_RESULTS
        sta next_mode
        rts

; ---------------------------------------------------------------------------
race_setup:
        jsr rng_stir
        lda #NTHEMES            ; random background: day, sunset or night
        jsr rand_below
        sta race_theme
        lda #1
        jsr screen_begin        ; race tiles for that theme
        MOVI16 ptr0, pal_race
        jsr load_palette
        lda race_theme          ; sky and road palettes (BG 2 and 3)
        asl a
        asl a
        asl a
        tax
        ldy #0
:       lda theme_pal,x
        sta palette+8,y
        inx
        iny
        cpy #8
        bne :-
        ; clear state
        lda #0
        ldx #(tr_x_h - rc_state)
:       sta rc_state-1,x
        dex
        bne :-
        ldx #NTRAFFIC-1
:       sta tr_on,x
        dex
        bpl :-
        lda #0
        sta res_flags
        sta res_et
        sta res_et+1
        sta res_opp_et
        sta res_opp_et+1
        sta res_t60
        sta res_t60+1
        sta res_rt
        sta res_rt+1
        sta res_trap
        sta res_trap+1
        sta res_mph
        sta res_mph+1
        sta scroll_x
        sta scroll_nt
        lda #$FF
        sta hud_gear
        lda race_kind
        cmp #RK_TEST
        beq :+
        cmp #RK_CRUISE
        beq :+
        lda #1
        sta rc_opp
:       lda race_kind
        cmp #RK_STREET
        beq :+
        cmp #RK_CRUISE
        bne :++
:       lda #1
        sta rc_street
:
        ; copy the map to WRAM, then draw it in both nametables
        ldx race_theme
        lda scene_map_lo,x
        sta ptr0
        lda scene_map_hi,x
        sta ptr0+1
        MOVI16 ptr1, MAP_COPY
        lda #<768
        sta tmp0
        lda #>768
        sta tmp1
        lda #BANK_SCENE
        sta copy_bank
        jsr bank0_copy
        lda #$20
        jsr draw_map
        lda #$24
        jsr draw_map
        ; start line (column 12, NT0)
        lda #12
        ldx #T_START
        jsr col_direct
        jsr draw_hud
        ; attributes: HUD, sky, road -- both nametables
        jsr race_attrs
        ; car tiles
        jsr cur_car_ptr
        tax
        lda car_shape,x
        ldx #$10
        jsr load_car_chr
        lda opp_rec+CR_MODEL
        tax
        lda car_shape,x
        ldx #$1C
        jsr load_car_chr
        ; traffic vehicles: sprite tiles $40, $4C, $58, $64, $70
        ldx #NTRTYPE-1
:       stx tmp7
        lda tr_tile,x
        pha
        lda tr_shape,x
        tay
        pla
        tax
        tya
        jsr load_car_chr
        ldx tmp7
        dex
        bpl :-
        ; palettes
        jsr cur_car_ptr
        jsr set_car_palette
        lda opp_rec+CR_PAINT
        sta palette+$1A
        lda race_kind           ; cruise: no rival, so palette 2 is a
        cmp #RK_CRUISE          ; second traffic colour
        bne :+
        lda #NTRCOL
        jsr rand_below
        tax
        lda tr_colours,x
        sta palette+$1A
:       lda #NTRGREY            ; traffic grey/silver/white for this race
        jsr rand_below
        tax
        lda tr_greys,x
        sta palette+$1E
        ; physics
        jsr cur_car_ptr
        lda ptr1
        sta ptr0
        lda ptr1+1
        sta ptr0+1
        ldx #0
        jsr phys_setup
        lda rc_opp
        beq :+
        MOVI16 ptr0, opp_rec
        ldx #1
        jsr phys_setup
        jsr ai_setup
:       ; scales: tach_k = $A00000 / limiter ; prog_k = 208*65536 / dist
        lda #0
        sta m_r
        sta m_r+1
        sta m_r+3
        lda #$A0
        sta m_r+2
        lda ph_lim_l
        sta m_b
        lda ph_lim_h
        sta m_b+1
        jsr div32
        lda m_r
        sta tach_k
        lda m_r+1
        sta tach_k+1
        lda #0
        sta m_r
        sta m_r+1
        sta m_r+3
        lda #208
        sta m_r+2
        lda race_dist
        sta m_b
        lda race_dist+1
        sta m_b+1
        jsr div32
        lda m_r
        sta prog_k
        lda m_r+1
        sta prog_k+1
        ; nitrous bar factor
        lda ph_nos_fr
        beq :+
        lda #0
        sta m_r
        lda #48
        sta m_r+1
        lda ph_nos_fr
        jsr div16_8
        lda m_r
        sta nos_k
:       clc
        lda race_dist
        adc #96
        sta fin_x
        lda race_dist+1
        adc #0
        sta fin_x+1
        ; lanes
        lda #LANE2_Y
        sta car_y
        lda #2
        sta car_lane
        lda #LANE1_Y
        sta car_y+1
        lda #1
        sta car_lane+1
        ; split delay for this region
        ldx region
        lda split_tab,x
        sta split_dly
        ; sprite 0
        lda #40
        sta oam
        lda #$00
        sta oam+1
        lda #$20                ; behind the background
        sta oam+2
        lda #128
        sta oam+3
        ; engine sound
        jsr engine_start
        ldx ph_model
        lda car_curve,x
        cmp #1
        bne :+
        lda #$40
        bne :++
:       lda #$00
:       sta eng_duty
        MOVI16 msg_ptr, str_m_rev
        lda #1
        sta msg_dirty
        sta tree_dirty
        lda race_kind           ; cruise: no lights, no finish line
        cmp #RK_CRUISE
        bne :+
        lda #RS_RUN
        sta rc_state
        lda #4
        sta rc_tree
        sta rc_green
        lda #2
        sta fin_done
        MOVI16 msg_ptr, str_m_cruise
:
        jsr hud_update
        lda frame
        sta last_fr
        jsr ppu_on_race
        rts

split_tab: .byte 69, 64, 69     ; NTSC, PAL, Dendy

; sky (BG palette 2) and road (BG palette 3) colours per theme
theme_pal:
        .byte $0F,$31,$00,$30,  $0F,$00,$10,$30     ; day: pale sky, grey city
        .byte $0F,$04,$27,$38,  $0F,$2D,$10,$30     ; sunset: purple to orange
        .byte $0F,$01,$12,$38,  $0F,$2D,$10,$30     ; night: navy, lit windows

ppu_on_race:
        lda #0
        sta scroll_x
        sta scroll_nt
        lda #$1E
        sta ppu_mask
        bit PPUSTATUS
:       bit PPUSTATUS
        bpl :-
        lda ppu_ctrl
        sta PPUCTRL
        rts

; draw_map: A = nametable high byte; rows 6-29 from MAP_COPY (PPU off)
draw_map:
        ldx #$C0
        jsr vram_addr
        MOVI16 ptr0, MAP_COPY
        ldx #3
        ldy #0
:       lda (ptr0),y
        sta PPUDATA
        iny
        bne :-
        inc ptr0+1
        dex
        bne :-
        rts

; col_direct: column A of NT0 rows 17-28 = tile X (PPU off)
col_direct:
        stx tmp2
        clc
        adc #<($2000 + 17*32)
        sta ptr3
        lda #>($2000 + 17*32)
        adc #0
        sta ptr3+1
        lda ppu_ctrl
        and #$7F
        ora #$04
        sta PPUCTRL
        lda ptr3+1
        ldx ptr3
        jsr vram_addr
        ldx #12
        lda tmp2
:       sta PPUDATA
        dex
        bne :-
        lda ppu_ctrl
        and #$7B
        sta PPUCTRL
        rts

race_attrs:
        ; NT0: HUD rows
        ldx #63
        lda #0
:       sta attr_shadow,x
        dex
        bpl :-
        ; sky blocks rows 3..7 -> palette 2 ; road rows 8..14 -> 3
        lda #0
        sta tmp0
        lda #3
        sta tmp1
        lda #16
        sta tmp2
        lda #5
        sta tmp3
        lda #2
        jsr attr_rect
        lda #0
        sta tmp0
        lda #8
        sta tmp1
        lda #16
        sta tmp2
        lda #7
        sta tmp3
        lda #3
        jsr attr_rect
        ; NT1 gets the same sky/road attributes
        lda #$27
        ldx #$C0
        jsr vram_addr
        ldx #0
:       lda attr_shadow,x
        sta PPUDATA
        inx
        cpx #64
        bne :-
        ; HUD: redline blocks (x 10-11, y 1) and amber lights (x 0-2, y 2)
        ldx #10
        ldy #1
        lda #1
        jsr set_attr
        ldx #11
        ldy #1
        lda #1
        jsr set_attr
        ldx #0
        ldy #2
        lda #1
        jsr set_attr
        ldx #1
        ldy #2
        lda #1
        jsr set_attr
        ldx #2
        ldy #2
        lda #1
        jsr set_attr
        jmp attr_upload

; draw_hud: static HUD text (PPU off)
draw_hud:
        lda race_kind
        cmp #RK_CRUISE
        bne @track
        PRINT str_h_cruise, 1, 1
        jmp @rest
@track: ; row 1: progress track
        lda #$20
        ldx #$21
        jsr vram_addr
        lda #$19
        sta PPUDATA
        ldx #26
        lda #$18
:       sta PPUDATA
        dex
        bne :-
        lda #$1A
        sta PPUDATA
        lda race_dist+1
        cmp #>6436
        bne :+
        PRINT str_h_mile, 29, 1
        jmp :+++
:       cmp #>3218
        bne :+
        PRINT str_h_half, 29, 1
        jmp :++
:       PRINT str_h_quart, 29, 1
:
@rest:  PRINT str_h_rpm, 1, 2
        PRINT str_h_g, 25, 2
        jsr speed_unit_r
        ldx #1
        ldy #3
        jsr print
        PRINT str_h_nos, 19, 3
        ; tree lights off
        ldx #0
:       stx tmp7
        lda tree_cols,x
        tax
        ldy #4
        jsr nt_addr
        lda ptr3+1
        ldx ptr3
        jsr vram_addr
        lda #$15
        sta PPUDATA
        ldx tmp7
        inx
        cpx #4
        bne :-
        ; row 5 edge line
        lda #32
        sta tmp2
        ldx #0
        ldy #5
        lda #T_HUD_EDGE
        jsr fill_row
        ; opponent name on row 0? (row 0 hides in overscan) -> row 4 message
        rts

tree_cols: .byte 1, 3, 5, 7

speed_unit_r:
        lda SV_OPTIONS
        and #OPT_KMH
        beq :+
        MOVI16 ptr0, str_h_kmh
        rts
:       MOVI16 ptr0, str_h_mph
        rts

; traffic vehicle types: body shape, sprite tile, speed range (px/frame*64)
NTRTYPE = 5
tr_shape:   .byte 2, 0, 4, 7, 8         ; sedan, hatch, pickup, van, box truck
tr_tile:    .byte $40, $4C, $58, $64, $70
tr_smin:    .byte 56, 60, 48, 48, 36    ; box trucks crawl, hatches nip along
tr_srng:    .byte 44, 48, 40, 32, 28
NTRCOL = 8
tr_colours: .byte $16, $12, $1A, $28, $14, $27, $21, $06
NTRGREY = 4
tr_greys:   .byte $10, $10, $3D, $30

str_h_quart: .byte "1/4", 0
str_h_cruise: .byte "CRUISE   START:PAUSE", 0
str_h_half:  .byte "1/2", 0
str_h_mile:  .byte "1MI", 0
str_h_rpm:   .byte "RPM", 0
str_h_g:     .byte "G", 0
str_h_mph:   .byte "MPH", 0
str_h_kmh:   .byte "KMH", 0
str_h_nos:   .byte "NOS", 0

; ---------------------------------------------------------------------------
; race_split: wait for sprite 0, set the sky scroll, wait, set the road scroll
; ---------------------------------------------------------------------------
race_split:
        ; wait for the end of vblank (sprite 0 flag clears)
        ldx #0
:       bit PPUSTATUS
        bvc :+
        dex
        bne :-
:       ldx #0
        ldy #12
@w:     bit PPUSTATUS
        bvs @hit
        dex
        bne @w
        dey
        bne @w
        rts                     ; no hit (shouldn't happen)
@hit:   lda sky_x+1
        and #1
        ora ppu_ctrl
        sta PPUCTRL
        lda sky_x
        sta PPUSCROLL
        sta PPUSCROLL
        ; delay to the top of the road (line ~120)
        ldy split_dly
@d1:    ldx #24
@d2:    dex
        bne @d2
        dey
        bne @d1
        lda road_x+1
        and #1
        ora ppu_ctrl
        tay
        lda road_x
        sty PPUCTRL
        sta PPUSCROLL
        sta PPUSCROLL
        rts

; ---------------------------------------------------------------------------
; race_frame: one frame of game logic
; ---------------------------------------------------------------------------
race_frame:
        lda pad_new
        ora pad2_new            ; either player can pause
        and #BTN_START
        beq :+
        lda rc_state
        cmp #RS_END
        beq :+
        lda #1
        sta paused
        MOVI16 msg_ptr, str_m_pause
        lda #1
        sta msg_dirty
        jmp race_draw
:       lda rc_state
        cmp #RS_TREE
        bne :+
        jsr race_tree
        jmp @phys
:       cmp #RS_RUN
        bne @end
        jsr race_run
        jmp @phys
@end:   dec rc_endt
        ; let both cars coast
        lda #0
        sta ph_thr
        sta ph_thr+1
@phys:  ldx #0
        jsr phys_step
        lda race_kind
        cmp #RK_CRUISE
        beq :+                  ; endless: no finish
        jsr check_finish0
:
        lda rc_opp
        beq :+
        ldx #1
        jsr phys_step
        jsr check_finish1
:       lda msg_t
        beq :+
        dec msg_t
        bne :+
        MOVI16 msg_ptr, str_blank3
        lda #1
        sta msg_dirty
:       jmp race_draw

; --- tree / staging ------------------------------------------------------------
race_tree:
        ; player revs with A
        lda pad
        and #BTN_A
        beq :+
        lda #1
:       sta ph_thr
        ; jump start?
        lda pad_new
        and #BTN_RIGHT
        beq @nofoul
        lda #1
        sta foul
        lda #RF_FOUL
        sta res_flags
        lda #SFX_FOUL
        jsr sfx_play
        MOVI16 msg_ptr, str_m_foul
        lda #1
        sta msg_dirty
        lda #5                  ; red lights
        sta rc_tree
        sta tree_dirty
        lda #RS_END
        sta rc_state
        lda #120
        sta rc_endt
        rts
@nofoul:
        lda race_kind
        cmp #RK_2P
        beq :+
        jsr ai_tree
        jmp @tick
:       jsr p2_tree
        lda rc_state
        cmp #RS_END
        bne @tick
        rts
@tick:  inc rc_t
        lda rc_t
        cmp #60
        beq @light
        cmp #90
        beq @light
        cmp #120
        beq @light
        cmp #150
        beq @go
        rts
@light: inc rc_tree
        lda #1
        sta tree_dirty
        lda #SFX_AMBER
        jmp sfx_play
@go:    lda #4
        sta rc_tree
        lda #1
        sta tree_dirty
        sta rc_green
        lda #SFX_GREEN
        jsr sfx_play
        MOVI16 msg_ptr, str_m_go
        lda #1
        sta msg_dirty
        lda #40
        sta msg_t
        lda #RS_RUN
        sta rc_state
        lda #0
        sta rc_t
        sta rc_t+1
        sta rc_ms
        sta rc_ms+1
        sta rc_ms3
        rts

; --- running ----------------------------------------------------------------------
race_run:
        ; clock
        inc rc_t
        bne :+
        inc rc_t+1
:       ldx rc_ms3
        lda ms_step,x
        pha
        clc
        adc rc_ms
        sta rc_ms
        bcc :+
        inc rc_ms+1
:       pla
        jsr clk_add
        ldx rc_ms3
        inx
        cpx #3
        bcc :+
        ldx #0
:       stx rc_ms3
        ; time limit 60 s -> end (not when cruising)
        lda race_kind
        cmp #RK_CRUISE
        beq :+
        ldy #>3600              ; 60 s, or 64 s for a mile (ms clock limit)
        lda race_dist+1
        cmp #>6436
        bne @lim
        ldy #>3840
@lim:   tya
        cmp rc_t+1
        beq @end
        bcs :+
@end:
        lda #RS_END
        sta rc_state
        lda #30
        sta rc_endt
        rts
:       ; player controls (unless finished)
        lda rc_fin
        jne @ai
        lda pad
        and #BTN_A
        beq :+
        lda #1
:       sta ph_thr
        lda pad_new
        and #BTN_RIGHT
        beq @nr
        jsr player_shift_up
@nr:    lda pad_new
        and #BTN_LEFT
        beq @nl
        ldx #0
        jsr phys_shift_down
        bcc @nl
        lda #SFX_SHIFT
        jsr sfx_play
@nl:    lda race_kind           ; cruise: unlimited nitrous, the bottle
        cmp #RK_CRUISE          ; refills as soon as a shot ends
        bne @nf
        lda ph_nos_on
        bne @nf
        sta ph_nos_t
@nf:    lda pad_new
        and #BTN_B
        beq @nb
        ldx #0
        jsr phys_nitrous
        bcc @nb
        lda #SFX_NOS
        jsr sfx_play
        MOVI16 msg_ptr, str_m_nos
        lda #1
        sta msg_dirty
        lda #40
        sta msg_t
@nb:    ; auto shift option
        lda SV_OPTIONS
        and #OPT_AUTO
        beq @na
        lda ph_gear
        beq @na
        jsr near_redline0
        bcc @na
        jsr player_shift_up
@na:    lda rc_street
        beq @ai
        lda pad_new
        and #BTN_UP
        beq :+
        lda car_lane
        beq :+
        dec car_lane
:       lda pad_new
        and #BTN_DOWN
        beq @ai
        lda car_lane
        cmp #2
        bcs @ai
        inc car_lane
@ai:    lda rc_opp
        beq :+
        lda race_kind
        cmp #RK_2P
        beq @p2
        jsr ai_run
        jmp :+
@p2:    jsr p2_run
:       ; 0-60
        lda rc_t60
        ora rc_t60+1
        bne :+
        ldx #0
        jsr mph_raw
        cmp #60
        bcc :+
        lda rc_t
        sta rc_t60
        lda rc_t+1
        sta rc_t60+1
:       rts

ms_step: .byte 17, 17, 16

; clk_add: add A (< 20) milliseconds to the decimal clock
clk_add:
        clc
        adc clk+4
@m1:    cmp #10
        bcc @m1ok
        sbc #10
        inc clk+3
        jmp @m1
@m1ok:  sta clk+4
        ldx #3
@c:     lda clk,x
        cmp #10
        bcc @ok
        sbc #10
        sta clk,x
        inc clk-1,x
@ok:    dex
        bne @c
        lda clk                 ; wrap 99.999 -> 00.000 (cruising)
        cmp #10
        bcc :+
        lda #0
        sta clk
:       rts


; mph_raw: X = car -> A = mph (ignores the km/h option)
mph_raw:
        lda ph_v1,x
        sta m_a
        lda ph_v2,x
        sta m_a+1
        lda #34
        sta m_b
        lda #0
        sta m_b+1
        jsr mul16
        lda m_r+2
        bne :+
        lda m_r+1
        rts
:       lda #255
        rts

; near_redline0: carry set if player rpm >= redline - 250 and not shifting
near_redline0:
        lda ph_shift_t
        ora ph_slip
        bne @no
        lda ph_gear
        cmp ph_ngears
        bcs @no
        sec
        lda ph_redl_l
        sbc #250
        sta tmp0
        lda ph_redl_h
        sbc #0
        sta tmp1
        lda ph_rpm_l
        cmp tmp0
        lda ph_rpm_h
        sbc tmp1
        rts
@no:    clc
        rts

; player_shift_up: launch or shift, with shift-quality feedback
player_shift_up:
        lda ph_gear
        bne @shift
        ; launch (only after green)
        ldx #0
        jsr phys_shift_up
        jcc @r
        lda #1
        sta rc_launch
        lda rc_t
        sta rc_rt
        lda rc_t+1
        sta rc_rt+1
        lda #SFX_SHIFT
        jmp sfx_play
@shift: ; quality from rpm vs redline (before the shift)
        sec
        lda ph_redl_l
        sbc ph_rpm_l
        sta tmp4
        lda ph_redl_h
        sbc ph_rpm_h
        sta tmp5
        ldx #0
        lda ph_spool
        sta tmp6
        jsr phys_shift_up
        bcc @r
        lda #SFX_SHIFT
        jsr sfx_play
        lda tmp6
        cmp #160
        bcc :+
        lda #SFX_BLOWOFF
        jsr sfx_play
        lda #10
        sta flame_t
:       lda tmp5
        bmi @late               ; rpm above redline
        bne @early              ; >= 256 below
        lda tmp4
        cmp #<450
        bcc @perfect
        jmp @good
@early: lda tmp5
        cmp #>1200
        bcc @good
        bne :+
        lda tmp4
        cmp #<1200
        bcc @good
:       MOVI16 msg_ptr, str_m_early
        jmp @msg
@good:  MOVI16 msg_ptr, str_m_good
        jmp @msg
@late:  MOVI16 msg_ptr, str_m_late
        jmp @msg
@perfect:
        ; perfect shift: quicker gear change
        lsr ph_shift_t
        inc ph_shift_t
        MOVI16 msg_ptr, str_m_perf
@msg:   lda #1
        sta msg_dirty
        lda #45
        sta msg_t
@r:     rts

; --- finish checks --------------------------------------------------------------
check_finish0:
        lda rc_fin
        jne @r
        lda ph_p1
        cmp race_dist
        lda ph_p2
        sbc race_dist+1
        jcc @r
        lda #1
        sta rc_fin
        lda rc_t
        sta rc_fin_t_l
        lda rc_t+1
        sta rc_fin_t_h
        ldx #0
        jsr phys_speed
        sta res_trap
        lda spd_hi
        sta res_trap+1
        ldx #0
        jsr phys_mph
        sta res_mph
        lda spd_hi
        sta res_mph+1
        lda rc_street
        bne :+
        ; win if the opponent hasn't finished (or there is none)
:       lda rc_opp
        beq @solo
        lda rc_fin+1
        bne @lost
        lda res_flags
        ora #RF_WIN
        sta res_flags
        MOVI16 msg_ptr, str_m_win
        lda race_kind
        cmp #RK_2P
        bne @m
        MOVI16 msg_ptr, str_m_p1win
        jmp @m
@lost:  MOVI16 msg_ptr, str_m_lose
        lda race_kind
        cmp #RK_2P
        bne @m
        MOVI16 msg_ptr, str_m_p2win
        jmp @m
@solo:  MOVI16 msg_ptr, str_m_fin
@m:     lda #1
        sta msg_dirty
        lda #0
        sta msg_t
        lda #0
        sta ph_thr
        ; end when the opponent has finished too (or after a while)
        lda rc_opp
        beq @end
        lda rc_fin+1
        bne @end
        rts
@end:   lda #RS_END
        sta rc_state
        lda #90
        sta rc_endt
@r:     rts

check_finish1:
        lda rc_fin+1
        bne @r
        lda ph_p1+1
        cmp race_dist
        lda ph_p2+1
        sbc race_dist+1
        bcc @r
        lda #1
        sta rc_fin+1
        lda rc_t
        sta rc_fin_t_l+1
        lda rc_t+1
        sta rc_fin_t_h+1
        lda #0
        sta ph_thr+1
        lda race_kind           ; two players: player 2 got there first
        cmp #RK_2P
        bne :+
        lda rc_fin
        bne :+
        MOVI16 msg_ptr, str_m_p2win
        lda #1
        sta msg_dirty
        lda #0
        sta msg_t
:       lda rc_fin
        beq @r
        ; player already done: wrap up
        lda rc_state
        cmp #RS_END
        beq @r
        lda #RS_END
        sta rc_state
        lda #60
        sta rc_endt
@r:     rts

; ---------------------------------------------------------------------------
; Player 2 (controller 2) drives car 1 in two-player races
; ---------------------------------------------------------------------------
; p2_tree: rev with A; Right before green is a foul start (player 1 wins)
p2_tree:
        lda pad2
        and #BTN_A
        beq :+
        lda #1
:       sta ph_thr+1
        lda pad2_new
        and #BTN_RIGHT
        beq @r
        lda #RF_WIN|RF_P2FOUL
        sta res_flags
        lda #SFX_FOUL
        jsr sfx_play
        MOVI16 msg_ptr, str_m_p2foul
        lda #1
        sta msg_dirty
        lda #5                  ; red lights
        sta rc_tree
        sta tree_dirty
        lda #RS_END
        sta rc_state
        lda #120
        sta rc_endt
@r:     rts

; p2_run: the same controls as player 1 (no shift-quality messages)
p2_run:
        lda rc_fin+1
        bne @r
        lda pad2
        and #BTN_A
        beq :+
        lda #1
:       sta ph_thr+1
        lda pad2_new
        and #BTN_RIGHT
        beq @nr
        lda ph_gear+1
        sta tmp7
        ldx #1
        jsr phys_shift_up
        bcc @nr
        lda tmp7
        bne :+
        lda #1                  ; that was the launch
        sta rc_launch+1
:       lda #SFX_SHIFT
        jsr sfx_play
@nr:    lda pad2_new
        and #BTN_LEFT
        beq @nl
        ldx #1
        jsr phys_shift_down
        bcc @nl
        lda #SFX_SHIFT
        jsr sfx_play
@nl:    lda pad2_new
        and #BTN_B
        beq @r
        ldx #1
        jsr phys_nitrous
        bcc @r
        lda #SFX_NOS
        jsr sfx_play
@r:     rts

; ---------------------------------------------------------------------------
; AI
; ---------------------------------------------------------------------------
ai_setup:
        ldx #1
        jsr phys_best_launch
        ; error = (255 - skill) * 6 ; launch += rand(err) - err/2
        lda #255
        sec
        sbc opp_skill
        sta tmp7
        sta m_a
        lda #6
        sta m_b
        jsr mul8
        lda m_r
        sta tmp4
        lda m_r+1
        sta tmp5
        ; rand 16 below err: (rand16 * err) >> 16 approximated with 8 bits
        jsr rand
        sta m_a
        lda tmp4
        sta m_b
        lda tmp5
        sta m_b+1
        lda #0
        sta m_a+1
        jsr mul16               ; m_r+1..2 = rand*err/256
        clc
        lda tmp2
        adc m_r+1
        sta ai_launch
        lda tmp3
        adc m_r+2
        sta ai_launch+1
        lsr tmp5
        ror tmp4
        sec
        lda ai_launch
        sbc tmp4
        sta ai_launch
        lda ai_launch+1
        sbc tmp5
        sta ai_launch+1
        ; at least 1500
        lda ai_launch+1
        cmp #>1500
        bcs :+
        lda #<1500
        sta ai_launch
        lda #>1500
        sta ai_launch+1
:       ; shift point = redline - 250 - rand((255-skill)*3)
        lda tmp7
        sta m_a
        lda #3
        sta m_b
        jsr mul8
        lda m_r
        sta tmp4
        lda m_r+1
        sta tmp5
        jsr rand
        sta m_a
        lda #0
        sta m_a+1
        lda tmp4
        sta m_b
        lda tmp5
        sta m_b+1
        jsr mul16
        sec
        lda ph_redl_l+1
        sbc #250
        sta ai_shift
        lda ph_redl_h+1
        sbc #0
        sta ai_shift+1
        sec
        lda ai_shift
        sbc m_r+1
        sta ai_shift
        lda ai_shift+1
        sbc m_r+2
        sta ai_shift+1
        ; reaction: 8 + rand((255-skill)/8 + 1) frames
        lda tmp7
        lsr a
        lsr a
        lsr a
        clc
        adc #1
        jsr rand_below
        clc
        adc #8
        sta ai_react
        rts

; ai_tree: rev to the launch rpm
ai_tree:
        lda rc_opp
        beq @r
        lda ph_rpm_l+1
        cmp ai_launch
        lda ph_rpm_h+1
        sbc ai_launch+1
        lda #0
        bcs :+
        lda #1
:       sta ph_thr+1
@r:     rts

ai_run:
        lda rc_fin+1
        bne @r
        lda rc_launch+1
        bne @driving
        ; still on the line: keep revving, launch after the reaction time
        jsr ai_tree
        lda rc_t+1
        bne :+
        lda rc_t
        cmp ai_react
        bcc @r
:       ldx #1
        jsr phys_shift_up
        lda #1
        sta rc_launch+1
        sta ph_thr+1
@r:     rts
@driving:
        lda #1
        sta ph_thr+1
        ; shift at the shift point
        lda ph_shift_t+1
        ora ph_slip+1
        bne @nos
        lda ph_gear+1
        cmp ph_ngears+1
        bcs @nos
        lda ph_rpm_l+1
        cmp ai_shift
        lda ph_rpm_h+1
        sbc ai_shift+1
        bcc @nos
        ldx #1
        jsr phys_shift_up
@nos:   lda ph_gear+1
        cmp #2
        bcc @lane
        ldx #1
        jsr phys_nitrous
@lane:  lda rc_street
        beq @done
        lda frame
        and #3
        bne @done
        jsr ai_lane
@done:  rts

; ai_lane: dodge traffic ahead in the opponent's lane
ai_lane:
        ldx #NTRAFFIC-1
@t:     lda tr_on,x
        beq @n
        lda tr_lane,x
        cmp car_lane+1
        bne @n
        ; distance = traffic x - (96 + opp pos px)
        clc
        lda ph_p1+1
        adc #96
        sta tmp0
        lda ph_p2+1
        adc #0
        sta tmp1
        sec
        lda tr_x_l,x
        sbc tmp0
        sta tmp2
        lda tr_x_h,x
        sbc tmp1
        bne @n                  ; behind (negative) or far ahead
        lda tmp2
        cmp #110
        bcs @n
        ; change lane: prefer lane 0/1 away from traffic
        lda car_lane+1
        beq @to1
        cmp #2
        beq @to1
        lda #0
        sta car_lane+1
        rts
@to1:   lda #1
        sta car_lane+1
        rts
@n:     dex
        bpl @t
        rts

; ---------------------------------------------------------------------------
; Street traffic
; ---------------------------------------------------------------------------
traffic_update:
        ; spawn
        lda rc_state
        cmp #RS_RUN
        jne @move
        lda race_kind           ; empty-road cruise: no traffic
        cmp #RK_CRUISE
        bne :+
        lda cruise_empty
        jne @move
:       dec tr_spawn
        bpl @move
        lda #40
        jsr rand_below
        clc
        adc #25
        sta tr_spawn
        ldx #NTRAFFIC-1
:       lda tr_on,x
        beq @spawn
        dex
        bpl :-
        jmp @move
@spawn: lda #1
        sta tr_on,x
        ; x = cam + 300 + rand(64)
        stx tmp7
        lda #64
        jsr rand_below
        ldx tmp7
        clc
        adc #<300
        adc cam
        sta tr_x_l,x
        lda cam+1
        adc #>300
        sta tr_x_h,x
        lda #0
        sta tr_x_f,x
        lda #3
        jsr rand_below
        ldx tmp7
        sta tr_lane,x
        lda #NTRTYPE            ; vehicle type sets the speed range
        jsr rand_below
        ldx tmp7
        sta tr_type,x
        tay
        lda tr_srng,y           ; px/frame (*64)
        jsr rand_below
        ldx tmp7
        ldy tr_type,x
        clc
        adc tr_smin,y
        sta tr_spd,x
        lda #3                  ; colour: palette 3, or 2 when cruising
        sta tr_pal,x
        lda race_kind
        cmp #RK_CRUISE
        bne @move
        jsr rand
        and #1
        ldx tmp7
        ora #2
        sta tr_pal,x
@move:  ldx #NTRAFFIC-1
@m:     lda tr_on,x
        beq @mn
        ; x += spd/64 (fraction kept in tr_x_f, 6 bits used)
        lda tr_spd,x
        asl a
        asl a                   ; *4 -> fraction byte units of 1/256
        clc
        adc tr_x_f,x
        sta tr_x_f,x
        lda tr_spd,x
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        adc tr_x_l,x
        sta tr_x_l,x
        lda tr_x_h,x
        adc #0
        sta tr_x_h,x
        ; despawn when 64 px behind the camera
        sec
        lda tr_x_l,x
        sbc cam
        sta tmp0
        lda tr_x_h,x
        sbc cam+1
        bpl @ok
        cmp #$FF
        bne @off
        lda tmp0
        cmp #$C0
        bcs @ok
@off:   lda #0
        sta tr_on,x
        jmp @mn
@ok:    stx tmp7
        ldy #0
        jsr crash_check
        ldy #1
        lda rc_opp
        beq :+
        jsr crash_check
:       ldx tmp7
@mn:    dex
        bpl @m
        ; crash timers
        ldx #1
:       lda crash_t,x
        beq :+
        dec crash_t,x
:       dex
        bpl :--
        rts

; crash_check: traffic tmp7 vs car Y
crash_check:
        ldx tmp7
        lda crash_t,y
        jne @r
        lda tr_lane,x
        cmp car_lane,y
        jne @r
        ; same lane and the car's sprite is near its lane centre?
        ; overlap: car front (96+pos) > tr_x+4 and car rear (64+pos) < tr_x+28
        clc
        lda ph_p1,y
        adc #<(96-4)
        sta tmp0
        lda ph_p2,y
        adc #0
        sta tmp1
        lda tmp0
        cmp tr_x_l,x
        lda tmp1
        sbc tr_x_h,x
        bcc @r                  ; front behind the traffic car
        clc
        lda ph_p1,y
        adc #<(64-28)
        sta tmp0
        lda ph_p2,y
        adc #0
        sta tmp1
        lda tmp0
        cmp tr_x_l,x
        lda tmp1
        sbc tr_x_h,x
        bcs @r                  ; rear past the traffic car
        ; crash: drop to the traffic car's speed, bump it ahead
        lda #60
        sta crash_t,y
        lda #0
        sta tmp1
        lda tr_spd,x            ; v_raw = spd*4 (px/frame*256)
        asl a
        rol tmp1
        asl a
        rol tmp1
        sta ph_v1,y
        lda tmp1
        sta ph_v2,y
        lda #0
        sta ph_v0,y
        sta ph_w0,y
        lda ph_v1,y
        sta ph_w1,y
        lda ph_v2,y
        sta ph_w2,y
        lda #0
        sta tr_on,x
        cpy #0
        bne @r
        lda #SFX_CRASH
        jsr sfx_play
        MOVI16 msg_ptr, str_m_crash
        lda #1
        sta msg_dirty
        lda #40
        sta msg_t
@r:     rts

; ---------------------------------------------------------------------------
; Drawing: camera, scroll, columns, HUD, sprites, sound
; ---------------------------------------------------------------------------
race_draw:
        ; camera follows the player.  Two players: the trailing car stays at
        ; x 64 until the leader is 128 px ahead, then the camera follows the
        ; leader (x 192).  cam = max(trailer, leader - 128): never backwards.
        lda race_kind
        cmp #RK_2P
        bne @cam1
        ldx #0                  ; X = leader, Y = trailer
        ldy #1
        lda ph_p1+1
        cmp ph_p1
        lda ph_p2+1
        sbc ph_p2
        bcc :+
        ldx #1
        ldy #0
:       sec
        lda ph_p1,x
        sbc #128
        sta tmp0
        lda ph_p2,x
        sbc #0
        sta tmp1
        bcs :+
        lda #0                  ; leader still inside the first 128 px
        sta tmp0
        sta tmp1
:       lda tmp0                ; trailer >= leader - 128 ?
        cmp ph_p1,y
        lda tmp1
        sbc ph_p2,y
        bcs :+
        lda ph_p1,y
        sta tmp0
        lda ph_p2,y
        sta tmp1
:       lda tmp0
        sta cam
        lda tmp1
        sta cam+1
        jmp @cam2
@cam1:  lda ph_p1
        sta cam
        lda ph_p2
        sta cam+1
@cam2:  lda cam
        sta road_x
        lda cam+1
        sta road_x+1
        lda cam+1
        lsr a
        sta sky_x+1
        lda cam
        ror a
        lsr sky_x+1
        ror a
        sta sky_x
        ; lane movement
        ldx #1
@ly:    ldy car_lane,x
        lda lane_y,y
        cmp car_y,x
        beq @lyn
        bcc :+
        inc car_y,x
        inc car_y,x
        jmp @lyn
:       dec car_y,x
        dec car_y,x
@lyn:   dex
        bpl @ly
        jsr columns
        jsr race_sprites
        ; sound
        lda ph_rpm_l
        sta eng_rpm
        lda ph_rpm_h
        sta eng_rpm+1
        lda ph_thr
        sta eng_thr
        lda #0
        sta eng_orpm
        sta eng_orpm+1
        lda rc_opp
        beq :+
        lda ph_rpm_l+1
        sta eng_orpm
        lda ph_rpm_h+1
        sta eng_orpm+1
:       lda #0
        ldx ph_nos_on
        beq :+
        lda #1
        bne :++
:       ldx ph_spin
        beq :+
        lda #2
:       sta eng_noise
        rts

lane_y: .byte LANE0_Y, LANE1_Y, LANE2_Y

; columns: draw the finish line when it is about to come on screen, and
; put the road back behind the start and finish lines
columns:
        lda start_done
        bne @fin
        ; cam >= 128 -> restore column 12
        lda cam+1
        bne :+
        lda cam
        cmp #128
        bcc @fin
:       lda #1
        sta start_done
        lda #12
        jsr col_restore
        rts
@fin:   lda fin_done
        cmp #2
        beq @r
        cmp #1
        beq @restore
        ; cam >= fin_x - 264 ?
        sec
        lda fin_x
        sbc #<264
        sta tmp0
        lda fin_x+1
        sbc #>264
        sta tmp1
        lda cam
        cmp tmp0
        lda cam+1
        sbc tmp1
        bcc @r
        lda #1
        sta fin_done
        jsr fin_col
        ldx #T_FINISH_A
        jsr col_fill
        jsr fin_col
        clc
        adc #1
        ldx #T_FINISH_B
        jmp col_fill
@restore:
        ; cam >= fin_x + 16 -> restore
        clc
        lda fin_x
        adc #16
        sta tmp0
        lda fin_x+1
        adc #0
        sta tmp1
        lda cam
        cmp tmp0
        lda cam+1
        sbc tmp1
        bcc @r
        lda #2
        sta fin_done
        jsr fin_col
        jsr col_restore
        jsr fin_col
        clc
        adc #1
        jmp col_restore
@r:     rts

; fin_col: A = finish column (0-63)
fin_col:
        lda fin_x+1
        sta tmp1
        lda fin_x
        lsr tmp1
        ror a
        lsr tmp1
        ror a
        lsr tmp1
        ror a
        and #63
        rts

; col_ptr3: A = column 0-63 -> ptr3 = PPU address of row 17 in that column
col_ptr3:
        pha
        and #31
        clc
        adc #<(17*32)
        sta ptr3
        lda #>(17*32)
        adc #0
        sta ptr3+1
        pla
        and #32
        beq :+
        lda #4
:       ora #$20
        ora ptr3+1
        sta ptr3+1
        rts

; col_fill: column A rows 17-28 = tile X (vbuf)
col_fill:
        stx tmp2
        jsr col_ptr3
        lda #12|$80
        jsr vb_open
        lda tmp2
        ldy #12
:       sta vbuf,x
        inx
        dey
        bne :-
        jmp vb_close

; col_restore: column A rows 17-28 from the map copy (vbuf)
col_restore:
        sta tmp2
        jsr col_ptr3
        lda tmp2
        and #31
        clc
        adc #<(MAP_COPY + (17-6)*32)
        sta ptr0
        lda #>(MAP_COPY + (17-6)*32)
        adc #0
        sta ptr0+1
        lda #12|$80
        jsr vb_open
        ldy #12
@r:     sty tmp3
        ldy #0
        lda (ptr0),y
        sta vbuf,x
        inx
        clc
        lda ptr0
        adc #32
        sta ptr0
        bcc :+
        inc ptr0+1
:       ldy tmp3
        dey
        bne @r
        jmp vb_close

; ---------------------------------------------------------------------------
; HUD
; ---------------------------------------------------------------------------
hud_update:
        ; tach: fill px = rpm * tach_k >> 16 (0-160)
        lda ph_rpm_l
        sta m_a
        lda ph_rpm_h
        sta m_a+1
        lda tach_k
        sta m_b
        lda tach_k+1
        sta m_b+1
        jsr mul16
        lda m_r+3
        bne @full
        lda m_r+2
        cmp #161
        bcc :+
@full:  lda #160
:       sta tmp4
        MOVI16 ptr3, $2044      ; row 2, col 4
        lda #20
        jsr vb_open
        ldy #20
@t:     lda tmp4
        cmp #8
        bcc @part
        sbc #8
        sta tmp4
        lda #$14
        bne @st
@part:  adc #$0C
        pha
        lda #0
        sta tmp4
        pla
@st:    sta vbuf,x
        inx
        dey
        bne @t
        jsr vb_close
        ; gear
        lda ph_gear
        cmp hud_gear
        beq @nog
        sta hud_gear
        MOVI16 ptr3, $205B      ; row 2, col 27
        lda #1
        jsr vb_open
        lda hud_gear
        bne :+
        lda #'N'
        bne :++
:       ora #'0'
:       sta vbuf,x
        inx
        jsr vb_close
@nog:   lda frame
        and #1
        beq @clock
        lda frame
        and #2
        beq @speed
        jmp @nos
@speed: ldx #0
        jsr phys_speed
        jsr fmt3w
        lda #3
        sta tmp2
        ldx #5
        ldy #3
        jsr vb_numbuf
        jmp @tree
@clock: lda rc_state
        cmp #RS_TREE
        beq @noclk
        lda rc_fin
        bne @noclk
        MOVI16 ptr3, $206A      ; row 3, col 10
        lda #6
        jsr vb_open
        lda clk
        ora #'0'
        sta vbuf,x
        lda clk+1
        ora #'0'
        sta vbuf+1,x
        lda #'.'
        sta vbuf+2,x
        lda clk+2
        ora #'0'
        sta vbuf+3,x
        lda clk+3
        ora #'0'
        sta vbuf+4,x
        lda clk+4
        ora #'0'
        sta vbuf+5,x
        txa
        clc
        adc #6
        tax
        jsr vb_close
@noclk: jmp @tree
@nos:   ; nitrous bar: 6 tiles
        lda #0
        sta tmp4
        lda ph_nos_fr
        beq @nb
        lda ph_nos_t
        bne :+
        lda #48                 ; unused bottle: full
        sta tmp4
        bne @nb
:       lda ph_nos_on
        beq @nb                 ; used up
        ; remaining*48/frames = nos_t * nos_k >> 8
        lda ph_nos_t
        sta m_a
        lda nos_k
        sta m_b
        jsr mul8
        lda m_r+1
        sta tmp4
@nb:    MOVI16 ptr3, $2078      ; row 3, col 24
        lda #6
        jsr vb_open
        ldy #6
@n:     lda tmp4
        cmp #8
        bcc :+
        lda #8
:       pha
        clc
        adc #$0C
        sta vbuf,x
        inx
        pla
        sta tmp5
        sec
        lda tmp4
        sbc tmp5
        sta tmp4
        dey
        bne @n
        jsr vb_close
@tree:  lda tree_dirty
        beq @notree
        lda #0
        sta tree_dirty
        MOVI16 ptr3, $2081      ; row 4, col 1
        lda #7
        jsr vb_open
        ldy #0
:       jsr light_tile
        sta vbuf,x
        inx
        cpy #3
        beq :+
        lda #0
        sta vbuf,x
        inx
:       iny
        cpy #4
        bne :--
        jsr vb_close
@notree:
        ; message
        lda msg_dirty
        beq @r
        lda #0
        sta msg_dirty
        lda msg_ptr
        sta ptr0
        lda msg_ptr+1
        sta ptr0+1
        lda #21
        jsr pad_ptr0
        ldx #10
        ldy #4
        jmp vb_str
@r:     rts

; light_tile: Y = light 0-3 -> A = tile
light_tile:
        lda rc_tree
        cmp #5
        beq @red
        cpy #3
        beq @green
        tya
        cmp rc_tree
        bcs @off
        lda #$17                ; amber (colour 3 of palette 1)
        rts
@green: lda rc_tree
        cmp #4
        bne @off
        lda #$16                ; green (colour 2 of palette 0)
        rts
@red:   cpy #3
        beq @off
        lda #$16                ; red (colour 2 of palette 1)
        rts
@off:   lda #$15
        rts

; ---------------------------------------------------------------------------
; Sprites
; ---------------------------------------------------------------------------
race_sprites:
        lda #4
        sta oam_idx
        ; progress markers on row 1 (not when cruising)
        lda race_kind
        cmp #RK_CRUISE
        beq :+
        ldx #0
        jsr marker
        lda rc_opp
        beq :+
        ldx #1
        jsr marker
:       ; alternate order for flicker when crowded
        lda frame
        and #1
        beq :+
        jsr spr_traffic
        jsr spr_cars
        jmp oam_clear
:       jsr spr_cars
        jsr spr_traffic
        jmp oam_clear

; marker: X = car.  The position is recomputed every other frame.
marker:
        stx tmp7
        lda frame
        and #3
        sta tmp6
        txa
        asl a
        cmp tmp6
        bne @draw
        lda ph_p1,x
        sta m_a
        lda ph_p2,x
        sta m_a+1
        lda prog_k
        sta m_b
        lda prog_k+1
        sta m_b+1
        jsr mul16
        lda m_r+3
        bne @max
        lda m_r+2
        cmp #209
        bcc :+
@max:   lda #208
:       clc
        adc #12
        ldx tmp7
        sta mark_x,x
@draw:  ldx tmp7
        lda mark_x,x
        sta sp_x
        lda #7
        sta sp_y
        lda #$07
        sta sp_tile
        lda marker_pal,x
        sta sp_attr
        jmp spr_add
marker_pal: .byte 0, 2

spr_cars:
        ; player at x 64 (two players: 64 + pos - cam, like the other car)
        lda race_kind
        cmp #RK_2P
        bne :+
        clc
        lda ph_p1
        adc #64
        sta tmp2
        lda ph_p2
        adc #0
        sta tmp3
        sec
        lda tmp2
        sbc cam
        sta sx_l
        lda tmp3
        sbc cam+1
        sta sx_h
        jmp @have
:       lda #0
        sta sx_h
        lda #64
        sta sx_l
@have:  lda crash_t
        beq :+
        lda frame
        and #2
        bne @opp                ; blink after a crash
:       lda car_y
        sta sp_y
        lda #$10
        sta sp_tile
        lda #0
        sta sp_attr
        lda #1
        sta tmp0
        ldx #0
        jsr wheel_frame
        sta tmp1
        jsr draw_car_s
        ldx #0
        jsr car_fx
@opp:   lda rc_opp
        beq @r
        ; screen x = 64 + opp_pos - cam
        clc
        lda ph_p1+1
        adc #64
        sta tmp2
        lda ph_p2+1
        adc #0
        sta tmp3
        sec
        lda tmp2
        sbc cam
        sta sx_l
        lda tmp3
        sbc cam+1
        sta sx_h
        lda car_y+1
        sta sp_y
        lda #$1C
        sta sp_tile
        lda #2
        sta sp_attr
        lda #0
        sta tmp0
        ldx #1
        jsr wheel_frame
        sta tmp1
        jsr draw_car_s
        ldx #1
        jsr car_fx
@r:     rts

; wheel_frame: X = car -> A = 0/1
wheel_frame:
        lda ph_spin,x
        beq :+
        lda frame
        and #1
        rts
:       lda ph_p1,x
        lsr a
        lsr a
        and #1
        rts

spr_traffic:
        lda rc_street
        beq @r
        ldx #NTRAFFIC-1
@t:     lda tr_on,x
        beq @n
        stx tmp7
        sec
        lda tr_x_l,x
        sbc cam
        sta sx_l
        lda tr_x_h,x
        sbc cam+1
        sta sx_h
        ldy tr_lane,x
        lda lane_y,y
        sta sp_y
        ldy tr_type,x
        lda tr_tile,y
        sta sp_tile
        lda tr_pal,x
        sta sp_attr
        lda #0
        sta tmp0
        lda frame
        lsr a
        lsr a
        lsr a
        and #1
        sta tmp1
        jsr draw_car_s
        ldx tmp7
@n:     dex
        bpl @t
@r:     rts

; draw_car_s: 32x16 car at signed 16-bit x sx_l/sx_h, y sp_y.
; sp_tile = first tile, sp_attr = top palette (+tmp0 for the bottom row),
; tmp1 = wheel frame.  Columns off screen are skipped.
draw_car_s:
        lda tmp1
        asl a
        asl a
        clc
        adc #4
        adc sp_tile
        sta tmp5                ; first bottom-row tile
        lda sp_attr
        clc
        adc tmp0
        sta tmp6                ; bottom-row attributes
        lda sp_y
        clc
        adc #8
        sta tmp3                ; bottom-row y
        ldx oam_idx
        ldy #0
@col:   cpx #249
        bcs @done               ; OAM full
        tya
        asl a
        asl a
        asl a
        clc
        adc sx_l
        sta tmp4
        lda sx_h
        adc #0
        bne @skip
        lda sp_y
        sta oam,x
        tya
        clc
        adc sp_tile
        sta oam+1,x
        lda sp_attr
        sta oam+2,x
        lda tmp4
        sta oam+3,x
        sta oam+7,x
        lda tmp3
        sta oam+4,x
        tya
        clc
        adc tmp5
        sta oam+5,x
        lda tmp6
        sta oam+6,x
        txa
        clc
        adc #8
        tax
@skip:  iny
        cpy #4
        bne @col
@done:  stx oam_idx
        rts

; car_fx: smoke when spinning, flames for nitrous / backfire.  X = car;
; sx_l/sx_h = car x, car_y,x = y
car_fx:
        stx tmp7
        lda sx_h
        bne @r
        lda ph_spin,x
        beq @flame
        ; two smoke puffs behind the rear wheel
        lda frame
        and #7
        sta tmp4
        lda sx_l
        sec
        sbc tmp4
        bcc @flame
        sta sp_x
        lda car_y,x
        clc
        adc #7
        sta sp_y
        lda frame
        and #1
        clc
        adc #$03
        sta sp_tile
        lda #3
        sta sp_attr
        jsr spr_add
        lda sp_x
        sec
        sbc #8
        bcc @flame
        sta sp_x
        lda #$02
        sta sp_tile
        jsr spr_add
@flame: ldx tmp7
        lda ph_nos_on,x
        bne @fl
        lda flame_t,x
        beq @r
        dec flame_t,x
@fl:    lda sx_l
        sec
        sbc #7
        bcc @r
        sta sp_x
        lda car_y,x
        clc
        adc #8
        sta sp_y
        lda frame
        and #2
        lsr a
        clc
        adc #$05
        sta sp_tile
        lda #3
        sta sp_attr
        jsr spr_add
@r:     rts

; ---------------------------------------------------------------------------
; Pause: START resumes, SELECT quits to the garage
; ---------------------------------------------------------------------------
race_pause:
        lda #0
        sta eng_thr
        lda pad_new
        ora pad2_new
        and #BTN_START
        beq :+
        lda #0
        sta paused
        MOVI16 msg_ptr, str_blank3
        lda #1
        sta msg_dirty
        jmp hud_update
:       lda pad_new
        ora pad2_new
        and #BTN_SELECT
        beq @r
        lda #1
        sta quit
        lda #RS_END
        sta rc_state
        lda #1                  ; ends on the next frame (race_frame counts it down)
        sta rc_endt
        lda #0
        sta paused
@r:     jmp hud_update

; ---------------------------------------------------------------------------
; race_results: fill res_* for the results screen
; ---------------------------------------------------------------------------
race_results:
        lda quit
        beq :+
        ; quitting counts as a loss (handled like a foul without a message)
        lda race_kind
        cmp #RK_TEST
        jeq @r
        lda #RF_FOUL
        sta res_flags
        rts
:       lda foul
        jne @r
        lda race_kind           ; two players, nobody finished: the leader wins
        cmp #RK_2P
        bne @fin
        lda rc_fin
        ora rc_fin+1
        bne @fin
        lda ph_p1+1
        cmp ph_p1
        lda ph_p2+1
        sbc ph_p2
        bcs @fin
        lda res_flags
        ora #RF_WIN
        sta res_flags
@fin:   lda rc_fin
        beq :+
        lda rc_fin_t_l
        ldx rc_fin_t_h
        jsr frames_ms
        sta res_et
        stx res_et+1
:       lda rc_fin+1
        beq :+
        lda res_flags
        ora #RF_OPPFIN
        sta res_flags
        lda rc_fin_t_l+1
        ldx rc_fin_t_h+1
        jsr frames_ms
        sta res_opp_et
        stx res_opp_et+1
:       lda rc_launch
        beq :+
        lda rc_rt
        ldx rc_rt+1
        jsr frames_ms
        sta res_rt
        stx res_rt+1
:       lda rc_t60
        ora rc_t60+1
        beq @r
        lda rc_t60
        ldx rc_t60+1
        jsr frames_ms
        sta res_t60
        stx res_t60+1
@r:     rts

; frames_ms: A/X = frames -> A/X = ms (frames*50/3), saturating
frames_ms:
        sta m_a
        stx m_a+1
        lda #50
        sta m_b
        lda #0
        sta m_b+1
        jsr mul16
        lda #3
        sta m_b
        lda #0
        sta m_b+1
        jsr div32
        lda m_r+2
        ora m_r+3
        beq :+
        lda #$FF
        tax
        rts
:       lda m_r
        ldx m_r+1
        rts

str_m_rev:   .byte "HOLD A TO REV", 0
str_m_cruise: .byte "RIGHT: DRIVE", 0
str_m_go:    .byte "GO! PRESS RIGHT", 0
str_m_foul:  .byte "FOUL START!", 0
str_m_perf:  .byte "PERFECT SHIFT!", 0
str_m_good:  .byte "GOOD SHIFT", 0
str_m_early: .byte "EARLY SHIFT", 0
str_m_late:  .byte "LATE SHIFT", 0
str_m_nos:   .byte "NITROUS!", 0
str_m_win:   .byte "YOU WIN!", 0
str_m_lose:  .byte "YOU LOSE", 0
str_m_p1win: .byte "PLAYER 1 WINS!", 0
str_m_p2win: .byte "PLAYER 2 WINS!", 0
str_m_p2foul: .byte "P2 FOUL START!", 0
str_m_fin:   .byte "FINISH!", 0
str_m_crash: .byte "CRASH!", 0
str_m_pause: .byte "PAUSED  SELECT:QUIT", 0
str_blank3:  .byte 0
