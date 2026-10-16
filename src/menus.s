; ===========================================================================
; menus.s -- title, garage hub, race select, my cars, dealer, results
; (bank 1)
; ===========================================================================

.segment "BSS"
g_sel:      .res 1          ; garage menu selection (kept between visits)
rs_sel:     .res 1          ; race select selection
dl_model:   .res 1          ; dealer: model shown
dl_buf:     .res 1          ; big car double buffer (0/1)
mc_sel:     .res 1
t_car_x:    .res 2          ; title screen car positions
t_ready:    .res 1

.segment "BANK1"

; ===========================================================================
; TITLE
; ===========================================================================
title_main:
        lda #0
        jsr screen_begin
        jsr load_common_chr
        jsr use_menu_palette
        ; logo
        MOVI16 ptr0, gfx_logo_map
        lda #LOGO_W
        sta tmp0
        lda #0
        sta tmp1
        lda #$20
        ldx #$C5                ; row 6, col 5
        jsr chr_copy
        MOVI16 ptr0, gfx_logo_map+LOGO_W
        lda #LOGO_W
        sta tmp0
        lda #0
        sta tmp1
        lda #$20
        ldx #$E5                ; row 7, col 5
        jsr chr_copy
        lda #2
        sta tmp0
        lda #3
        sta tmp1
        lda #12
        sta tmp2
        lda #1
        sta tmp3
        lda #2
        jsr attr_rect
        PRINT str_t_sub, 7, 10
        lda #$20
        sta text_attr
        PRINT str_t_nes, 12, 4
        lda #0
        sta text_attr
        PRINT str_t_cont, 12, 15
        PRINT str_t_new, 12, 17
        PRINT str_t_fan1, 3, 26
        PRINT str_t_fan2, 5, 27
        ; road
        lda #32
        sta tmp2
        ldx #0
        ldy #20
        lda #T_FLOOR_A
        jsr fill_row
        ldx #0
        ldy #21
        lda #$01
        jsr fill_row
        ldx #0
        ldy #22
        lda #$01
        jsr fill_row
        ldx #0
        ldy #23
        lda #T_FLOOR_B
        jsr fill_row
        lda #0
        sta tmp0
        lda #10
        sta tmp1
        lda #16
        sta tmp2
        lda #2
        sta tmp3
        lda #3
        jsr attr_rect
        jsr attr_upload
        ; two cars for the parade
        lda #1
        ldx #$10
        jsr load_car_chr
        lda #5
        ldx #$1C
        jsr load_car_chr
        jsr cur_car_ptr
        jsr set_car_palette
        lda #$16
        sta palette+$1A
        lda #$0F
        sta palette+$19
        jsr ppu_on
        lda #SONG_GARAGE
        jsr music_play
        lda #0
        sta ui_sel
        sta t_car_x
        lda #2
        sta ui_count
        lda #10
        sta ui_x
        lda #15
        sta ui_y0
        lda #2
        sta ui_dy
        lda #1
        sta ui_cols
        lda #120
        sta t_car_x+1
@loop:  jsr wait_frame
        jsr read_pad
        lda #4
        sta oam_idx
        ; parade: car 1 at speed 2, car 2 at speed 3
        inc t_car_x
        inc t_car_x
        lda t_car_x+1
        clc
        adc #3
        sta t_car_x+1
        lda t_car_x
        sta sp_x
        lda #157
        sta sp_y
        lda #$10
        sta sp_tile
        lda #0
        sta sp_attr
        lda #1
        sta tmp0
        lda frame
        lsr a
        lsr a
        and #1
        sta tmp1
        jsr draw_car
        lda t_car_x+1
        sta sp_x
        lda #167
        sta sp_y
        lda #$1C
        sta sp_tile
        lda #2
        sta sp_attr
        lda #0
        sta tmp0
        jsr draw_car
        jsr oam_clear
        jsr list_cursor
        ; blink "PRESS A" style: nothing; handle input
        jsr list_select
        cmp #1
        beq @pick
        cmp #4
        beq @pick
        jmp @loop
@pick:  jsr rng_stir
        lda ui_sel
        bne @new
        lda #MODE_GARAGE
        sta next_mode
        rts
@new:   MOVI16 ptr0, str_t_sure
        ldy #23+1
        jsr confirm
        bcs @no
        jsr new_game
        lda #SFX_BUY
        jsr sfx_play
        lda #MODE_GARAGE
        sta next_mode
        rts
@no:    MOVI16 ptr0, str_blank
        ldy #24
        jsr vb_msg
        jmp @loop

str_t_sub:  .byte "- STREET DRAG RACING -", 0
str_t_nes:  .byte "NES EDITION", 0
str_t_cont: .byte "CONTINUE", 0
str_t_new:  .byte "NEW GAME", 0
str_t_fan1: .byte "UNOFFICIAL FAN-MADE DEMAKE", 0
str_t_fan2: .byte "ORIGINAL ART AND MUSIC", 0
str_t_sure: .byte "ERASE SAVE?", 0
str_blank:  .byte 0

; ===========================================================================
; GARAGE (hub)
; ===========================================================================
garage_main:
@redraw:
        jsr garage_draw
@loop:  jsr wait_frame
        jsr read_pad
        jsr garage_sprites
        lda g_sel
        sta ui_sel
        jsr list_select
        ldx ui_sel
        stx g_sel
        cmp #1
        beq @go
        cmp #5                  ; SELECT: debug menu (Game Genie only)
        bne :+
        lda cheat_debug
        beq :+
        jsr debug_screen
        bcs @redraw
        lda #MODE_RACE
        sta next_mode
        rts
:       jmp @loop
@go:    lda g_sel
        asl a
        tax
        lda garage_jump+1,x
        pha
        lda garage_jump,x
        pha
        rts                     ; jump to handler (address - 1)

garage_jump:
        .word g_race-1, g_parts-1, g_mycars-1, g_tune-1, g_dealer-1
        .word g_paint-1, g_crates-1, g_dyno-1, g_options-1, g_stats-1

g_race: jsr race_select
        bcs :+
        lda #MODE_RACE
        sta next_mode
        rts
:       jmp garage_main
g_parts:
        FARCALL BANK_MENU2, parts_screen
        jmp garage_main
g_mycars:
        jsr mycars_screen
        jmp garage_main
g_tune: FARCALL BANK_MENU2, tune_screen
        jmp garage_main
g_dealer:
        jsr dealer_screen
        jmp garage_main
g_paint:
        FARCALL BANK_MENU2, paint_screen
        jmp garage_main
g_crates:
        FARCALL BANK_MENU2, crates_screen
        jmp garage_main
g_dyno: FARCALL BANK_MENU2, dyno_screen
        jmp garage_main
g_options:
        FARCALL BANK_MENU2, options_screen
        lda next_mode
        cmp #MODE_TITLE
        beq :+
        jmp garage_main
:       rts
g_stats:
        jsr stats_screen
        jmp garage_main

; garage_draw: whole garage screen (PPU off -> on)
garage_draw:
        ; money cheat (Game Genie): keep the cash topped up
        lda cheat_money
        beq :+
        jsr cash_max
        jsr save_write
:       lda #0
        jsr screen_begin
        jsr use_menu_palette
        MOVI16 ptr0, str_garage
        jsr draw_header
        jsr draw_showroom
        ; car info
        jsr cur_car_ptr
        jsr car_name_ptr
        lda #$20
        sta text_attr
        ldx #2
        ldy #14
        jsr print
        lda #0
        sta text_attr
        jsr cur_car_ptr
        ldy #15
        jsr stats_line
        jsr print
        jsr best_line
        ldx #2
        ldy #16
        jsr print
        ; menu
        BOX 1, 17, 30, 12
        ldx #0
@items: txa
        pha
        asl a
        tay
        lda garage_items,y
        sta ptr0
        lda garage_items+1,y
        sta ptr0+1
        txa
        and #1
        beq :+
        lda #18
        bne :++
:       lda #5
:       sta tmp4
        txa
        lsr a
        asl a
        clc
        adc #18
        tay
        ldx tmp4
        jsr print
        pla
        tax
        inx
        cpx #10
        bne @items
        jsr attr_upload
        ; big car
        jsr cur_car_ptr
        tax
        lda car_shape,x
        ldx #$40
        jsr big_car_direct
        jsr cur_car_ptr
        jsr set_car_palette
        jsr ppu_on
        lda mus_on
        bne :+
        lda #SONG_GARAGE
        jsr music_play
:       lda #10
        sta ui_count
        lda #3
        sta ui_x
        lda #16
        sta ui_x2
        lda #18
        sta ui_y0
        lda #1
        sta ui_dy
        lda #2
        sta ui_cols
        lda #2
        sta ui_dy
        rts

; best_line: ptr0 = "BEST 1/4  12.345" for the current car (or "NO TIME")
best_line:
        jsr cur_car_ptr
        ldy #CR_BEST
        lda (ptr1),y
        sta m_a
        iny
        lda (ptr1),y
        sta m_a+1
        ora m_a
        bne :+
        MOVI16 ptr0, str_notime
        rts
:       jsr fmt_ms
        ldy #0
:       lda str_best,y
        beq :+
        sta linebuf,y
        iny
        bne :-
:       ldx #0
:       lda numbuf,x
        sta linebuf,y
        beq :+
        inx
        iny
        bne :-
:       MOVI16 ptr0, linebuf
        rts

; draw_showroom: wall rows 4-10, floor rows 11-12 (PPU off)
draw_showroom:
        jmp draw_garage_bg

; garage_sprites: cursor + the big car on the showroom floor
garage_sprites:
        lda #4
        sta oam_idx
        lda #96
        sta sp_x
        lda #59
        sta sp_y
        lda #$40
        sta sp_tile
        lda #0
        sta sp_attr
        jsr draw_big_car
        jsr oam_clear
        jmp list_cursor

garage_items:
        .word str_g0, str_g1, str_g2, str_g3, str_g4, str_g5, str_g6, str_g7, str_g8, str_g9
str_g0: .byte "RACE", 0
str_g1: .byte "PARTS", 0
str_g2: .byte "MY CARS", 0
str_g3: .byte "TUNE", 0
str_g4: .byte "DEALER", 0
str_g5: .byte "PAINT", 0
str_g6: .byte "CRATES", 0
str_g7: .byte "DYNO", 0
str_g8: .byte "OPTIONS", 0
str_g9: .byte "STATS", 0
str_garage: .byte "GARAGE", 0
str_notime: .byte "BEST 1/4: NO TIME YET", 0
str_best:   .byte "BEST 1/4: ", 0

; ===========================================================================
; RACE SELECT
; ===========================================================================
.segment "BSS"
bosses_left: .res 1
.segment "BANK1"

race_select:
        lda #0
        jsr screen_begin
        jsr use_menu_palette
        MOVI16 ptr0, str_rsel
        jsr draw_header
        PRINT str_rs0, 4, 4
        PRINT str_rs1, 4, 7
        PRINT str_rs2, 4, 10
        PRINT str_rs3, 4, 13
        PRINT str_rs4, 4, 16
        PRINT str_rs5, 4, 19
        lda #6
        sta ui_count
        jsr has_zenith
        bne :+
        lda #$20
        sta text_attr
        PRINT str_rs6, 4, 22
        lda #0
        sta text_attr
        lda #7
        sta ui_count
:       BOX 1, 24, 30, 5
        jsr attr_upload
        lda #0
        sta oam_idx
        jsr oam_clear
        jsr ppu_on
        lda rs_sel
        cmp ui_count
        bcc :+
        lda #0
        sta rs_sel
:       sta ui_sel
        lda #2
        sta ui_x
        lda #4
        sta ui_y0
        lda #3
        sta ui_dy
        lda #1
        sta ui_cols
        jsr rs_refresh
@loop:  jsr wait_frame
        jsr read_pad
        jsr list_cursor
        jsr list_select
        ldx ui_sel
        stx rs_sel
        cmp #3
        bne :+
        jsr rs_refresh
        jmp @loop
:       cmp #6
        beq @left
        cmp #7
        beq @right
        cmp #2
        beq @back
        cmp #1
        beq @pick
        jmp @loop
@left:  lda ui_sel
        cmp #1
        bne @dl
        lda race_diff
        beq @loop
        dec race_diff
        jmp @chg
@dl:    cmp #2
        bne @loop
        lda race_half
        eor #1
        sta race_half
        jmp @chg
@right: lda ui_sel
        cmp #1
        bne @dl
        lda race_diff
        cmp #2
        bcs @loop
        inc race_diff
@chg:   lda #SFX_MOVE
        jsr sfx_play
        jsr rs_refresh
        jmp @loop
@back:  sec
        rts
@pick:  lda ui_sel
        cmp #5
        beq @back
        cmp #2
        beq @loop               ; distance row: use left/right
        cmp #6
        bne :+
        jsr setup_secret
        clc
        rts
:       cmp #0
        bne :+
        jsr setup_ladder
        clc
        rts
:       cmp #1
        bne :+
        jsr setup_quick
        bcs @poor
        clc
        rts
:       cmp #3
        bne :+
        jsr setup_street
        clc
        rts
:       jsr setup_test
        clc
        rts
@poor:  MOVI16 ptr0, str_poor
        lda #28
        jsr pad_ptr0
        ldx #2
        ldy #26
        jsr vb_str
        lda #SFX_ERROR
        jsr sfx_play
        jmp @loop

; rs_refresh: values next to the items and the info box for the selection
rs_refresh:
        ; difficulty
        lda race_diff
        asl a
        tax
        lda diff_names,x
        sta ptr0
        lda diff_names+1,x
        sta ptr0+1
        ldx #18
        ldy #7
        jsr vb_str
        lda race_half
        asl a
        tax
        lda dist_names,x
        sta ptr0
        lda dist_names+1,x
        sta ptr0+1
        ldx #18
        ldy #10
        jsr vb_str
        ; info box rows 25..26
        lda rs_sel
        asl a
        tax
        lda rs_info,x
        sta ptr0
        lda rs_info+1,x
        sta ptr0+1
        lda #28
        jsr pad_ptr0
        ldx #2
        ldy #25
        jsr vb_str
        jsr wait_frame
        ; second info line
        lda rs_sel
        bne @n0
        ; ladder: next boss
        jsr boss_index
        jsr boss_line
        jmp @show
@n0:    cmp #1
        bne @n1
        ; bet
        jsr calc_bet
        jsr money_text
        ldy #0
:       lda str_bet,y
        beq :+
        sta linebuf,y
        iny
        bne :-
:       jsr cat_ptr0
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        jmp @show
@n1:    cmp #6
        bne @n2
        MOVI16 ptr0, str_i6b
        jmp @show
@n2:    MOVI16 ptr0, str_blank
@show:  lda #28
        jsr pad_ptr0
        ldx #2
        ldy #26
        jmp vb_str

; has_zenith: Z set if the car in use is the crate-only Zenith X400
has_zenith:
        jsr cur_car_ptr
        cmp #CRATE_CAR
        rts

str_rsel:   .byte "RACE", 0
str_rs0:    .byte "LADDER BOSS", 0
str_rs1:    .byte "QUICK RACE", 0
str_rs2:    .byte "DISTANCE", 0
str_rs3:    .byte "STREET RACE", 0
str_rs4:    .byte "TEST RUN", 0
str_rs5:    .byte "BACK", 0
str_rs6:    .byte "??? SECRET BOSS", 0
str_poor:   .byte "NOT ENOUGH CASH FOR THE BET", 0
str_bet:    .byte "BET ", 0
diff_names: .word str_easy, str_med, str_hard
str_easy:   .byte "< EASY   >", 0
str_med:    .byte "< MEDIUM >", 0
str_hard:   .byte "< HARD   >", 0
dist_names: .word str_q, str_h
str_q:      .byte "< 1/4 MILE >", 0
str_h:      .byte "< 1/2 MILE >", 0
rs_info:    .word str_i0, str_i1, str_i2, str_i3, str_i4, str_i5, str_i6
str_i0:     .byte "BEAT THE 10 STREET BOSSES", 0
str_i1:     .byte "RANDOM RIVAL, WIN THE BET", 0
str_i2:     .byte "LEFT/RIGHT: RACE LENGTH", 0
str_i3:     .byte "1/2 MILE WITH TRAFFIC", 0
str_i4:     .byte "SOLO RUN, TIME YOUR CAR", 0
str_i5:     .byte "BACK TO THE GARAGE", 0
str_i6:     .byte "ONLY AN X400 CAN TAKE IT ON", 0
str_i6b:    .byte "ECLIPSE - WIN $500000", 0

; calc_bet: m_a = bet for race_diff
calc_bet:
        ldx race_diff
        lda bet_lo,x
        sta m_a
        lda bet_hi,x
        sta m_a+1
        lda #0
        sta m_a+2
        rts
bet_lo: .byte <300, <1000, <2500
bet_hi: .byte >300, >1000, >2500

; ---------------------------------------------------------------------------
; Ladder bosses (all names made up)
; ---------------------------------------------------------------------------
NBOSS = 11                      ; ladder bosses
BOSS_SECRET = 11                ; the hidden 12th boss (table index)
boss_model: .byte 0, 1, 2, 4, 3, 5, 6, 7, 8, 9, 11, CRATE_CAR
boss_level: .byte 0, 1, 1, 1, 2, 3, 3, 3, 4, 4, 4, 4
boss_paint: .byte $2A, $11, $30, $14, $12, $28, $07, $3C, $0F, $00, $25, $13
boss_skill: .byte 40, 70, 90, 110, 130, 150, 170, 190, 210, 230, 250, 255
boss_cash0: .byte <800, <1500, <2500, <4000, <6000, <9000, <12000, <18000, <26000, <40000, <(100000 & $FFFF), <(500000 & $FFFF)
boss_cash1: .byte >800, >1500, >2500, >4000, >6000, >9000, >12000, >18000, >26000, >40000, >(100000 & $FFFF), >(500000 & $FFFF)
boss_cash2: .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ^100000, ^500000
boss_names:
        .byte "RIKU        ", 0
        .byte "DEX         ", 0
        .byte "MAYA        ", 0
        .byte "BRUNO       ", 0
        .byte "KAI         ", 0
        .byte "ROSA        ", 0
        .byte "TANK        ", 0
        .byte "VEGA        ", 0
        .byte "IRON JO     ", 0
        .byte "PHANTOM     ", 0
        .byte "THE LEGEND  ", 0
        .byte "ECLIPSE     ", 0

; boss_index: A = current boss (0-10)
boss_index:
        lda SV_LADDER
        cmp #NBOSS
        bcc :+
        lda #NBOSS-1
:       rts

; boss_line: A = boss -> ptr0 = "BOSS 3/10 MAYA" + car
boss_line:
        sta tmp6
        ldy #0
:       lda str_boss,y
        beq :+
        sta linebuf,y
        iny
        bne :-
:       lda tmp6
        clc
        adc #'1'
        cmp #':'
        bcc :+
        lda #'1'
        sta linebuf,y
        iny
        lda tmp6
        sec
        sbc #9
        clc
        adc #'0'
:       sta linebuf,y
        iny
        lda #' '
        sta linebuf,y
        iny
        sty tmp5
        lda tmp6
        jsr boss_name_ptr
        ldy tmp5
        jsr cat_ptr0
        ; trim trailing spaces
:       dey
        lda linebuf,y
        cmp #' '
        beq :-
        iny
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        rts
str_boss:   .byte "NEXT: BOSS ", 0

boss_name_ptr:
        sta m_a
        lda #13
        sta m_b
        jsr mul8
        clc
        lda m_r
        adc #<boss_names
        sta ptr0
        lda m_r+1
        adc #>boss_names
        sta ptr0+1
        rts

; opp_from_model: build opp_rec for model A with all parts at tmp6
opp_from_model:
        pha
        MOVI16 ptr1, opp_rec
        pla
        jsr init_record
        ldy #CR_PARTS
@p:     lda tmp6
        sta opp_rec,y
        iny
        cpy #CR_PARTS+NPARTS
        bne @p
        rts

; copy_opp_name: copy 12 chars at ptr0 to opp_name
copy_opp_name:
        ldy #12
:       lda (ptr0),y
        sta opp_name,y
        dey
        bpl :-
        rts

setup_ladder:
        jsr boss_index
        jsr setup_boss
        lda #RK_LADDER
        sta race_kind
        rts

; setup_secret: the hidden 12th boss
setup_secret:
        lda #BOSS_SECRET
        jsr setup_boss
        lda #RK_SECRET
        sta race_kind
        rts

; setup_boss: A = boss table index -> opponent, distance, no bet
setup_boss:
        sta tmp7
        tax
        lda boss_level,x
        sta tmp6
        lda boss_model,x
        jsr opp_from_model
        ldx tmp7
        lda boss_paint,x
        sta opp_rec+CR_PAINT
        lda boss_skill,x
        sta opp_skill
        lda tmp7
        jsr boss_name_ptr
        jsr copy_opp_name
        lda #0
        sta race_bet
        sta race_bet+1
        sta race_bet+2
        lda race_half
        jmp set_dist

; setup_quick: carry set if the player can't cover the bet
setup_quick:
        jsr calc_bet
        jsr cash_cmp
        bcs :+
        rts
:       lda m_a
        sta race_bet
        lda m_a+1
        sta race_bet+1
        lda m_a+2
        sta race_bet+2
        jsr make_rival
        lda #RK_QUICK
        sta race_kind
        lda race_half
        jsr set_dist
        clc
        rts

setup_street:
        lda #1
        sta race_diff
        jsr make_rival
        lda #0
        sta race_bet
        sta race_bet+1
        sta race_bet+2
        lda #RK_STREET
        sta race_kind
        lda #1
        jmp set_dist

setup_test:
        lda #RK_TEST
        sta race_kind
        lda #0
        sta race_bet
        sta race_bet+1
        sta race_bet+2
        lda race_half
        jmp set_dist

set_dist:
        beq :+
        lda #<3218
        sta race_dist
        lda #>3218
        sta race_dist+1
        rts
:       lda #<1609
        sta race_dist
        lda #>1609
        sta race_dist+1
        rts

; make_rival: random opponent near the player's car for race_diff
make_rival:
        jsr cur_car_ptr
        sta tmp7                ; player model
        ; average part level (sum of 8 power parts / 8 rounded)
        lda #0
        sta tmp5
        ldy #CR_PARTS
:       lda (ptr1),y
        clc
        adc tmp5
        sta tmp5
        iny
        cpy #CR_PARTS+NPARTS
        bne :-
        lda tmp5
        clc
        adc #5
        sta m_r
        lda #0
        sta m_r+1
        lda #10
        jsr div16_8
        lda m_r
        clc
        adc race_diff
        sec
        sbc #1
        bpl :+
        lda #0
:       cmp #5
        bcc :+
        lda #4
:       sta tmp6
        ; model: player model + rand(-1..1) + (diff - 1)
        lda #3
        jsr rand_below
        clc
        adc tmp7
        adc race_diff
        sec
        sbc #2
        bpl :+
        lda #0
:       cmp #NDEALER-1          ; the hypercar only appears as a boss
        bcc :+
        lda #NDEALER-2
:       pha
        jsr opp_from_model
        ; random paint from the paint list
        lda #NPAINTS
        jsr rand_below
        tax
        lda paint_list,x
        sta opp_rec+CR_PAINT
        pla
        ; name
        lda #NRIVALS
        jsr rand_below
        sta m_a
        lda #13
        sta m_b
        jsr mul8
        clc
        lda m_r
        adc #<rival_names
        sta ptr0
        lda m_r+1
        adc #>rival_names
        sta ptr0+1
        jsr copy_opp_name
        ldx race_diff
        lda diff_skill,x
        sta opp_skill
        rts

diff_skill: .byte 60, 140, 215
NRIVALS = 12
rival_names:
        .byte "ACE         ", 0
        .byte "NOVA        ", 0
        .byte "JINX        ", 0
        .byte "ZED         ", 0
        .byte "LUCKY       ", 0
        .byte "MOTO        ", 0
        .byte "RAVEN       ", 0
        .byte "SPARKY      ", 0
        .byte "DUKE        ", 0
        .byte "KIRA        ", 0
        .byte "BOLT        ", 0
        .byte "SHIFTY      ", 0

; ===========================================================================
; MY CARS
; ===========================================================================
mycars_screen:
@redraw:
        lda #0
        jsr screen_begin
        jsr use_menu_palette
        MOVI16 ptr0, str_mycars
        jsr draw_header
        ldx #0
@row:   stx tmp7
        txa
        jsr slot_ptr
        jsr slot_line
        lda tmp7
        asl a
        clc
        adc #5
        tay
        ldx #3
        jsr print
        ldx tmp7
        inx
        cpx #NSLOTS
        bne @row
        PRINT str_mc_help, 2, 22
        PRINT str_mc_help2, 2, 23
        jsr attr_upload
        lda #0
        sta oam_idx
        jsr oam_clear
        lda mc_sel
        jsr mc_preview_direct
        jsr ppu_on
        lda mc_sel
        sta ui_sel
        lda #NSLOTS
        sta ui_count
        lda #1
        sta ui_x
        lda #5
        sta ui_y0
        lda #2
        sta ui_dy
        lda #1
        sta ui_cols
@loop:  jsr wait_frame
        jsr read_pad
        jsr mc_sprites
        jsr list_select
        ldx ui_sel
        stx mc_sel
        cmp #3
        bne :+
        lda mc_sel
        jsr mc_preview
        jmp @loop
:       cmp #2
        bne :+
        rts
:       cmp #1
        beq @use
        cmp #5
        beq @sell
        jmp @loop
@use:   lda mc_sel
        jsr slot_ptr
        ldy #CR_MODEL
        lda (ptr1),y
        cmp #$FF
        beq @err
        lda mc_sel
        sta SV_CURCAR
        jsr save_write
        lda #SFX_BUY
        jsr sfx_play
        jmp @redraw
@err:   lda #SFX_ERROR
        jsr sfx_play
        jmp @loop
@sell:  lda mc_sel
        cmp SV_CURCAR
        beq @err
        jsr slot_ptr
        ldy #CR_MODEL
        lda (ptr1),y
        cmp #$FF
        beq @err
        jsr sell_value
        jsr money_text
        ldy #0
:       lda str_sellfor,y
        beq :+
        sta linebuf,y
        iny
        bne :-
:       jsr cat_ptr0
        lda #'?'
        sta linebuf,y
        iny
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        ldy #25
        jsr confirm
        bcs @nosell
        lda mc_sel
        jsr slot_ptr
        jsr sell_value
        jsr cash_add
        lda mc_sel
        jsr slot_ptr
        ldy #CR_MODEL
        lda #$FF
        sta (ptr1),y
        ; keep SV_CURCAR pointing at the same car (slots don't move)
        jsr save_write
        lda #SFX_BUY
        jsr sfx_play
        jmp @redraw
@nosell:
        jmp @redraw

; sell_value: ptr1 = record -> m_a = half the car price + 400 per part level
sell_value:
        ldy #CR_MODEL
        lda (ptr1),y
        jsr car_price
        lsr m_a+2
        ror m_a+1
        ror m_a
        ldy #CR_PARTS
        lda #0
        sta tmp4
:       lda (ptr1),y
        clc
        adc tmp4
        sta tmp4
        iny
        cpy #CR_PARTS+NPARTS
        bne :-
        lda m_a
        pha
        lda m_a+1
        pha
        lda m_a+2
        pha
        lda tmp4
        sta m_a
        lda #<400
        sta m_b
        lda #>400
        sta m_b+1
        lda #0
        sta m_a+1
        jsr mul16
        pla
        sta m_a+2
        pla
        sta m_a+1
        pla
        sta m_a
        clc
        lda m_a
        adc m_r
        sta m_a
        lda m_a+1
        adc m_r+1
        sta m_a+1
        lda m_a+2
        adc #0
        sta m_a+2
        ; at least $200
        lda m_a+2
        ora m_a+1
        bne :+
        lda m_a
        cmp #200
        bcs :+
        lda #200
        sta m_a
:       rts

; slot_line: ptr1 = slot record -> ptr0 = "* NAME        123HP" text
slot_line:
        ldy #CR_MODEL
        lda (ptr1),y
        cmp #$FF
        bne :+
        MOVI16 ptr0, str_empty
        rts
:       pha
        ldy #0
        lda tmp7
        cmp SV_CURCAR
        bne :+
        lda #'*'
        bne :++
:       lda #' '
:       sta linebuf
        lda #' '
        sta linebuf+1
        pla
        jsr car_name_ptr
        ldy #2
        jsr cat_ptr0
        sty tmp6
        jsr car_stats
        jsr num_text
        ldy tmp6
        jsr cat_ptr0
        lda #'H'
        sta linebuf,y
        iny
        lda #'P'
        sta linebuf,y
        iny
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        rts

; mc_preview: start streaming the big car for slot A (rendering on)
mc_preview:
        jsr slot_ptr
        ldy #CR_MODEL
        lda (ptr1),y
        cmp #$FF
        beq @none
        pha
        jsr set_car_palette
        pla
        tax
        lda car_shape,x
        ldx #$40
        jmp big_car_stream
@none:  rts

mc_preview_direct:
        jsr slot_ptr
        ldy #CR_MODEL
        lda (ptr1),y
        cmp #$FF
        beq @none
        pha
        jsr set_car_palette
        pla
        tax
        lda car_shape,x
        ldx #$40
        jmp big_car_direct
@none:  rts

mc_sprites:
        lda #4
        sta oam_idx
        lda mc_sel
        jsr slot_ptr
        ldy #CR_MODEL
        lda (ptr1),y
        cmp #$FF
        beq :+
        lda chr_cnt             ; wait until the new tiles are in
        bne :+
        lda #176
        sta sp_x
        lda #183
        sta sp_y
        lda #$40
        sta sp_tile
        lda #0
        sta sp_attr
        jsr draw_big_car
:       jsr oam_clear
        jmp list_cursor

str_mycars:   .byte "MY CARS", 0
str_empty:    .byte "  - EMPTY -", 0
str_mc_help:  .byte "A:DRIVE THIS CAR  B:BACK", 0
str_mc_help2: .byte "SELECT:SELL", 0
str_sellfor:  .byte "SELL FOR ", 0

; ===========================================================================
; DEALER
; ===========================================================================
dealer_screen:
        lda #0
        jsr screen_begin
        jsr use_menu_palette
        MOVI16 ptr0, str_dealer
        jsr draw_header
        jsr draw_showroom
        PRINT str_dl_help, 2, 27
        PRINT str_dl_help2, 2, 28
        jsr attr_upload
        lda dl_model
        jsr dl_record
        ldy #CR_MODEL
        lda (ptr1),y
        tax
        lda car_shape,x
        ldx #$40
        jsr big_car_direct
        lda #0
        sta dl_buf
        jsr ppu_on
        jsr dl_info
@loop:  jsr wait_frame
        jsr read_pad
        jsr dl_sprites
        lda pad_rpt
        and #BTN_LEFT
        beq :+
        ldx dl_model
        bne @dec
        ldx #NDEALER
@dec:   dex
        stx dl_model
        jmp @chg
:       lda pad_rpt
        and #BTN_RIGHT
        beq :+
        ldx dl_model
        inx
        cpx #NDEALER
        bcc @inc
        ldx #0
@inc:   stx dl_model
        jmp @chg
:       lda pad_new
        and #BTN_B
        beq :+
        lda #SFX_BACK
        jsr sfx_play
        rts
:       lda pad_new
        and #BTN_A
        beq @loop
        jsr dl_buy
        jmp @loop
@chg:   lda #SFX_MOVE
        jsr sfx_play
        lda chr_cnt
        bne @chg2               ; still streaming: wait
        lda dl_buf
        eor #1
        sta dl_buf
@chg2:  lda dl_model
        jsr dl_record
        ldy #CR_MODEL
        lda (ptr1),y
        tax
        lda car_shape,x
        ldx #$40
        ldy dl_buf
        beq :+
        ldx #$60
:       jsr big_car_stream
        jsr dl_info
        jmp @loop

; dl_record: A = model -> tmp_rec stock record (red), ptr1 = tmp_rec
dl_record:
        pha
        MOVI16 ptr1, tmp_rec
        pla
        jsr init_record
        MOVI16 ptr1, tmp_rec
        rts

dl_sprites:
        lda #4
        sta oam_idx
        lda chr_cnt
        bne :+
        lda #96
        sta sp_x
        lda #59
        sta sp_y
        lda #$40
        ldx dl_buf
        beq :++
        lda #$60
        bne :++
:       ; still streaming: show nothing
        jmp oam_clear
:       sta sp_tile
        lda #0
        sta sp_attr
        jsr draw_big_car
        jmp oam_clear

; dl_info: rows 13-25 text for dl_model
; (Spread over several frames: each NMI must finish its PPU writes in vblank)
dl_info:
        MOVI16 ptr1, tmp_rec
        jsr set_car_palette
        jsr wait_frame          ; palette upload gets a frame of its own
        lda dl_model
        jsr car_name_ptr
        lda #20
        jsr pad_ptr0
        lda #$20
        sta text_attr
        ldx #2
        ldy #14
        jsr vb_str
        lda #0
        sta text_attr
        ; "< 3/12 >"
        lda dl_model
        clc
        adc #1
        jsr fmt_8
        lda numbuf+6
        sta linebuf+1
        lda numbuf+7
        sta linebuf+2
        lda #'<'
        sta linebuf
        lda #'/'
        sta linebuf+3
        lda #'1'
        sta linebuf+4
        lda #'2'
        sta linebuf+5
        lda #'>'
        sta linebuf+6
        lda #0
        sta linebuf+7
        MOVI16 ptr0, linebuf
        ldx #23
        ldy #14
        jsr vb_str
        jsr wait_frame
        MOVI16 ptr1, tmp_rec
        ldy #16
        jsr stats_line
        jsr vb_str
        jsr wait_frame
        ; gears + redline
        ldy #0
:       lda str_gears,y
        beq :+
        sta linebuf,y
        iny
        bne :-
:       ldx dl_model
        lda car_ngears,x
        ora #'0'
        sta linebuf,y
        iny
        sty tmp6
        ldy #0
:       lda str_redl,y
        beq :+
        sty tmp5
        ldy tmp6
        sta linebuf,y
        inc tmp6
        ldy tmp5
        iny
        bne :-
:       ldx dl_model
        lda car_redline_l,x
        sta m_a
        lda car_redline_h,x
        sta m_a+1
        jsr num_text
        ldy tmp6
        jsr cat_ptr0
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        lda #28
        jsr pad_ptr0
        ldx #2
        ldy #18
        jsr vb_str
        ; price
        lda dl_model
        jsr car_price
        lda m_a
        ora m_a+1
        ora m_a+2
        bne :+
        MOVI16 ptr0, str_free
        jmp @pr
:       jsr money_text
@pr:    lda #12
        jsr pad_ptr0
        lda #$20
        sta text_attr
        ldx #9
        ldy #20
        jsr vb_str
        lda #0
        sta text_attr
        VBSTR str_price, 2, 20
        ; gems?
        ldx dl_model
        lda car_gems,x
        beq @nogem
        jsr fmt_8
        lda numbuf+6
        sta linebuf+2
        lda numbuf+7
        sta linebuf+3
        lda #'+'
        sta linebuf
        lda #' '
        sta linebuf+1
        ldy #4
        MOVI16 ptr0, str_gemsw
        jsr cat_ptr0
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        jmp @gm
@nogem: MOVI16 ptr0, str_blank
@gm:    lda #10
        jsr pad_ptr0
        ldx #21
        ldy #20
        jsr vb_str
        jsr wait_frame
        ; level requirement / owned
        ldx dl_model
        lda car_level,x
        cmp SV_LEVEL
        beq @lvok
        bcc @lvok
        jsr fmt_8
        ldy #0
:       lda str_needlv,y
        beq :+
        sta linebuf,y
        iny
        bne :-
:       lda numbuf+6
        sta linebuf,y
        iny
        lda numbuf+7
        sta linebuf,y
        iny
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        jmp @lv
@lvok:  MOVI16 ptr0, str_avail
@lv:    lda #28
        jsr pad_ptr0
        ldx #2
        ldy #22
        jmp vb_str

dl_buy:
        ldx dl_model
        lda car_level,x
        cmp SV_LEVEL
        beq :+
        jcs @fail
:       lda dl_model
        jsr car_price
        jsr cash_cmp
        jcc @fail
        ldx dl_model
        lda car_gems,x
        sta tmp4
        lda SV_GEMS+1
        bne :+
        lda SV_GEMS
        cmp tmp4
        bcc @fail
:       jsr free_slot
        bcs @full
        MOVI16 ptr0, str_buyq
        ldy #24
        jsr confirm
        php
        MOVI16 ptr0, str_blank
        ldy #24
        jsr vb_msg
        plp
        bcs @no
        lda dl_model
        jsr car_price
        jsr cash_sub
        ldx dl_model
        sec
        lda SV_GEMS
        sbc car_gems,x
        sta SV_GEMS
        lda SV_GEMS+1
        sbc #0
        sta SV_GEMS+1
        jsr free_slot
        sta SV_CURCAR           ; drive it right away
        jsr slot_ptr
        lda dl_model
        jsr init_record
        jsr save_write
        lda #SFX_BUY
        jsr sfx_play
        jsr header_update
        MOVI16 ptr0, str_bought
        ldy #24
        jmp vb_msg
@full:  MOVI16 ptr0, str_full
        ldy #24
        jsr vb_msg
@fail:  lda #SFX_ERROR
        jmp sfx_play
@no:    rts

str_dealer:   .byte "DEALER", 0
str_dl_help:  .byte "LEFT/RIGHT:BROWSE  A:BUY", 0
str_dl_help2: .byte "B:BACK", 0
str_gears:    .byte "GEARS ", 0
str_redl:     .byte "  REDLINE ", 0
str_price:    .byte "PRICE", 0
str_free:     .byte "FREE", 0
str_gemsw:    .byte "GEMS", 0
str_needlv:   .byte "REQUIRES LEVEL ", 0
str_avail:    .byte "AVAILABLE", 0
str_buyq:     .byte "BUY THIS CAR?", 0
str_bought:   .byte "SOLD! IT'S IN YOUR GARAGE", 0
str_full:     .byte "GARAGE FULL - SELL A CAR", 0

; ===========================================================================
; RESULTS
; ===========================================================================
.segment "BSS"
rw_cash:    .res 3
rw_xp:      .res 2
rw_lvup:    .res 1
rw_best:    .res 1
.segment "BANK1"

results_main:
        jsr apply_rewards
        lda #0
        jsr screen_begin
        jsr use_menu_palette
        MOVI16 ptr0, str_results
        jsr draw_header
        ; verdict
        lda #$20
        sta text_attr
        lda race_kind
        cmp #RK_TEST
        bne :+
        MOVI16 ptr0, str_r_test
        jmp @v
:       lda res_flags
        and #RF_FOUL
        beq :+
        MOVI16 ptr0, str_r_foul
        jmp @v
:       lda res_flags
        and #RF_WIN
        beq :+
        MOVI16 ptr0, str_r_win
        jmp @v
:       MOVI16 ptr0, str_r_lose
@v:     ldx #4
        ldy #5
        jsr print
        lda #0
        sta text_attr
        BOX 2, 7, 28, 11
        ; your ET
        PRINT str_r_et, 4, 9
        lda res_et
        sta m_a
        lda res_et+1
        sta m_a+1
        jsr ms_or_dash
        ldx #19
        ldy #9
        jsr print
        PRINT str_r_trap, 4, 10
        lda res_trap
        sta m_a
        lda res_trap+1
        sta m_a+1
        jsr num_text
        ldx #19
        ldy #10
        jsr print
        jsr speed_unit
        ldx #23
        ldy #10
        jsr print
        PRINT str_r_rt, 4, 11
        lda res_rt
        sta m_a
        lda res_rt+1
        sta m_a+1
        jsr ms_or_dash
        ldx #19
        ldy #11
        jsr print
        PRINT str_r_60, 4, 12
        lda res_t60
        sta m_a
        lda res_t60+1
        sta m_a+1
        jsr ms_or_dash
        ldx #19
        ldy #12
        jsr print
        lda race_kind
        cmp #RK_TEST
        beq @noopp
        PRINT str_r_opp, 4, 14
        MOVI16 ptr0, opp_name
        ldx #4
        ldy #15
        jsr print
        lda res_flags
        and #RF_OPPFIN
        beq @noopp
        lda res_opp_et
        sta m_a
        lda res_opp_et+1
        sta m_a+1
        jsr ms_or_dash
        ldx #19
        ldy #15
        jsr print
@noopp:
        ; rewards
        PRINT str_r_cash, 4, 19
        lda rw_cash+2
        bmi @neg
        lda rw_cash
        sta m_a
        lda rw_cash+1
        sta m_a+1
        lda rw_cash+2
        sta m_a+2
        jsr money_text
        ldx #15
        ldy #19
        jsr print
        jmp @xp
@neg:   sec
        lda #0
        sbc rw_cash
        sta m_a
        lda #0
        sbc rw_cash+1
        sta m_a+1
        lda #0
        sbc rw_cash+2
        sta m_a+2
        jsr money_text
        ldy #0
        lda #'-'
        sta (ptr0),y            ; "-300" instead of "$300"
        ldx #15
        ldy #19
        jsr print
@xp:    PRINT str_r_xp, 4, 20
        lda rw_xp
        sta m_a
        lda rw_xp+1
        sta m_a+1
        jsr num_text
        ldx #15
        ldy #20
        jsr print
        lda rw_lvup
        beq :+
        lda #$20
        sta text_attr
        PRINT str_r_lvup, 4, 22
        lda #0
        sta text_attr
:       lda rw_best
        beq :+
        PRINT str_r_best, 4, 23
:       PRINT str_r_help, 2, 26
        PRINT str_r_help2, 2, 27
        jsr attr_upload
        lda #0
        sta oam_idx
        jsr oam_clear
        jsr ppu_on
        ; jingle
        lda res_flags
        and #RF_WIN
        bne @win
        lda race_kind
        cmp #RK_TEST
        beq @win
        lda #SONG_LOSE
        bne @song
@win:   lda #SONG_WIN
@song:  jsr music_play
        lda rw_lvup
        beq :+
        lda #SFX_LEVELUP
        jsr sfx_play
:
@loop:  jsr wait_frame
        jsr read_pad
        lda pad_new
        and #BTN_START
        bne @again
        lda pad_new
        and #BTN_A|BTN_B
        beq @loop
        lda #SFX_SELECT
        jsr sfx_play
        lda #MODE_GARAGE
        sta next_mode
        rts
@again: ; race again with the same settings (new rival for quick/street)
        lda #SFX_SELECT
        jsr sfx_play
        lda race_kind
        cmp #RK_LADDER
        bne :+
        jsr setup_ladder
        jmp @go
:       cmp #RK_SECRET
        bne :+
        jsr setup_secret
        jmp @go
:       cmp #RK_QUICK
        bne :+
        jsr setup_quick
        bcs @loop               ; can't afford the bet any more
        jmp @go
:       cmp #RK_STREET
        bne @go
        jsr setup_street
@go:    lda #MODE_RACE
        sta next_mode
        rts

; track_stats: race count, best 1/4 mile overall and top trap speed
track_stats:
        inc SV_RACES
        bne :+
        inc SV_RACES+1
:       lda res_flags
        and #RF_FOUL
        bne @r
        jsr cur_car_ptr
        sta tmp4                ; model
        ; best 1/4 mile, any car
        lda race_dist+1
        cmp #>1609
        bne @spd
        lda res_et
        ora res_et+1
        beq @spd
        lda SV_PBEST
        ora SV_PBEST+1
        beq @pb
        lda res_et
        cmp SV_PBEST
        lda res_et+1
        sbc SV_PBEST+1
        bcs @spd
@pb:    lda res_et
        sta SV_PBEST
        lda res_et+1
        sta SV_PBEST+1
        lda tmp4
        sta SV_PBCAR
@spd:   ; top trap speed (mph, 10 bits) | model << 12
        lda res_mph
        ora res_mph+1
        beq @r
        lda SV_TOPSPD+1
        and #$03
        sta tmp1
        lda SV_TOPSPD
        cmp res_mph
        lda tmp1
        sbc res_mph+1
        bcs @r                  ; old record >= this one
        lda res_mph
        sta SV_TOPSPD
        lda tmp4
        asl a
        asl a
        asl a
        asl a
        ora res_mph+1
        sta SV_TOPSPD+1
@r:     rts

; ms_or_dash: m_a = ms -> ptr0 text ("--.---" if 0)
ms_or_dash:
        lda m_a
        ora m_a+1
        bne :+
        MOVI16 ptr0, str_dash
        rts
:       jsr fmt_ms
        MOVI16 ptr0, numbuf
        rts

speed_unit:
        lda SV_OPTIONS
        and #OPT_KMH
        beq :+
        MOVI16 ptr0, str_kmh
        rts
:       MOVI16 ptr0, str_mph
        rts

; apply_rewards: money, xp, best time, ladder progress, stats; then save
apply_rewards:
        lda #0
        sta rw_cash
        sta rw_cash+1
        sta rw_cash+2
        sta rw_xp+1
        sta rw_lvup
        sta rw_best
        lda #5
        sta rw_xp
        jsr track_stats
        ; best 1/4 mile time (test runs and races over 1/4 mile)
        lda race_dist+1
        cmp #>1609
        bne @nobest
        lda res_flags
        and #RF_FOUL
        bne @nobest
        lda res_et
        ora res_et+1
        beq @nobest
        jsr cur_car_ptr
        ldy #CR_BEST+1
        lda (ptr1),y
        dey
        ora (ptr1),y
        beq @newbest
        lda res_et
        cmp (ptr1),y
        iny
        lda res_et+1
        sbc (ptr1),y
        bcs @nobest
@newbest:
        ldy #CR_BEST
        lda res_et
        sta (ptr1),y
        iny
        lda res_et+1
        sta (ptr1),y
        lda #1
        sta rw_best
@nobest:
        lda race_kind
        cmp #RK_TEST
        bne :+
        jmp @xp
:       lda res_flags
        and #RF_WIN
        bne @won
        ; lost
        inc SV_LOSSES
        bne :+
        inc SV_LOSSES+1
:       lda #25
        sta rw_xp
        lda race_kind
        cmp #RK_QUICK
        jne @xp
        ; lose the bet
        sec
        lda #0
        sbc race_bet
        sta rw_cash
        lda #0
        sbc race_bet+1
        sta rw_cash+1
        lda #0
        sbc race_bet+2
        sta rw_cash+2
        lda race_bet
        sta m_a
        lda race_bet+1
        sta m_a+1
        lda race_bet+2
        sta m_a+2
        jsr cash_cmp
        jcc @xp
        jsr cash_sub
        jmp @xp
@won:   inc SV_WINS
        bne :+
        inc SV_WINS+1
:       lda #100
        sta rw_xp
        lda race_kind
        cmp #RK_SECRET
        bne :+
        jmp @secret
:       cmp #RK_LADDER
        bne @nl
        jsr boss_index
        tax
        lda boss_cash0,x
        sta rw_cash
        lda boss_cash1,x
        sta rw_cash+1
        lda boss_cash2,x
        sta rw_cash+2
        lda #150
        sta rw_xp
        lda SV_LADDER
        cmp #NBOSS
        jcs @pay
        inc SV_LADDER
        ; 3 gems for a new boss
        clc
        lda SV_GEMS
        adc #3
        sta SV_GEMS
        jcc @pay
        inc SV_GEMS+1
        jmp @pay
@nl:    cmp #RK_QUICK
        bne @street
        lda race_bet
        sta rw_cash
        lda race_bet+1
        sta rw_cash+1
        lda race_bet+2
        sta rw_cash+2
        jmp @pay
@street:
        ; street: 1200 + 600 * rival tier
        ldx opp_rec+CR_MODEL
        lda car_tier,x
        sta m_a
        lda #<600
        sta m_b
        lda #>600
        sta m_b+1
        lda #0
        sta m_a+1
        jsr mul16
        clc
        lda m_r
        adc #<1200
        sta rw_cash
        lda m_r+1
        adc #>1200
        sta rw_cash+1
        lda #0
        sta rw_cash+2
        inc SV_STREET
        lda #120
        sta rw_xp
        jmp @pay
@secret:
        ; hidden boss: $500,000, 300 xp, 25 gems the first time
        ldx #BOSS_SECRET
        lda boss_cash0,x
        sta rw_cash
        lda boss_cash1,x
        sta rw_cash+1
        lda boss_cash2,x
        sta rw_cash+2
        lda #<300
        sta rw_xp
        lda #>300
        sta rw_xp+1
        lda SV_SECRET
        bne @pay
        lda #1
        sta SV_SECRET
        clc
        lda SV_GEMS
        adc #25
        sta SV_GEMS
        bcc @pay
        inc SV_GEMS+1
@pay:   lda rw_cash
        sta m_a
        lda rw_cash+1
        sta m_a+1
        lda rw_cash+2
        sta m_a+2
        jsr cash_add
@xp:    lda rw_xp
        sta m_a
        lda rw_xp+1
        sta m_a+1
        jsr add_xp
        lda #0
        rol a
        sta rw_lvup
        jmp save_write

str_results:  .byte "RESULTS", 0
str_r_win:    .byte "YOU WIN!", 0
str_r_lose:   .byte "YOU LOSE", 0
str_r_foul:   .byte "FOUL START - YOU LOSE", 0
str_r_test:   .byte "TEST RUN COMPLETE", 0
str_r_et:     .byte "YOUR TIME", 0
str_r_trap:   .byte "TRAP SPEED", 0
str_r_rt:     .byte "REACTION", 0
str_r_60:     .byte "0-60 MPH", 0
str_r_opp:    .byte "RIVAL", 0
str_r_cash:   .byte "CASH", 0
str_r_xp:     .byte "XP", 0
str_r_lvup:   .byte "LEVEL UP! BONUS GEMS", 0
str_r_best:   .byte "NEW PERSONAL BEST!", 0
str_r_help:   .byte "A:GARAGE", 0
str_r_help2:  .byte "START:RACE AGAIN", 0
str_dash:     .byte "--.---", 0
str_mph:      .byte "MPH", 0
str_kmh:      .byte "KMH", 0

; ===========================================================================
; DEBUG MENU -- only reachable with the Game Genie debug code (cheat_debug)
; ===========================================================================
.segment "BSS"
dbg_car:    .res 1
dbg_boss:   .res 1
.segment "BANK1"

; debug_screen: carry clear = a boss race was set up, carry set = back
debug_screen:
        lda #0
        jsr screen_begin
        jsr use_menu_palette
        MOVI16 ptr0, str_dbg
        jsr draw_header
        PRINT str_dbg0, 4, 6
        PRINT str_dbg1, 4, 9
        PRINT str_dbg2, 4, 12
        PRINT str_dbg3, 4, 15
        PRINT str_dbg4, 4, 18
        PRINT str_dbg_help, 2, 26
        PRINT str_dbg_help2, 2, 27
        jsr attr_upload
        lda #0
        sta oam_idx
        jsr oam_clear
        jsr ppu_on
        lda #0
        sta ui_sel
        lda #5
        sta ui_count
        lda #2
        sta ui_x
        lda #6
        sta ui_y0
        lda #3
        sta ui_dy
        lda #1
        sta ui_cols
        jsr dbg_values
@loop:  jsr wait_frame
        jsr read_pad
        jsr list_cursor
        jsr list_select
        cmp #2
        beq @back
        cmp #6
        beq @left
        cmp #7
        beq @right
        cmp #1
        bne @loop
        lda ui_sel
        beq @addcar
        cmp #1
        jeq @boss
        cmp #2
        jeq @cash
        cmp #3
        jeq @gems
@back:  sec
        rts
@left:  ldx ui_sel
        bne :+
        ldy dbg_car             ; car: 0 .. NCARS-1
        bne @cdec
        ldy #NCARS
@cdec:  dey
        sty dbg_car
        jmp @chg
:       cpx #1
        bne @loop
        ldy dbg_boss            ; boss: 0 .. NBOSS (NBOSS = the secret boss)
        bne @bdec
        ldy #NBOSS+1
@bdec:  dey
        sty dbg_boss
        jmp @chg
@right: ldx ui_sel
        bne :+
        ldy dbg_car
        iny
        cpy #NCARS
        bcc @cset
        ldy #0
@cset:  sty dbg_car
        jmp @chg
:       cpx #1
        bne @loop
        ldy dbg_boss
        iny
        cpy #NBOSS+1
        bcc @bset
        ldy #0
@bset:  sty dbg_boss
@chg:   lda #SFX_MOVE
        jsr sfx_play
        jsr dbg_values
        jmp @loop
@addcar:
        jsr free_slot
        bcs @full
        jsr slot_ptr
        lda dbg_car
        jsr init_record
        jsr save_write
        lda #SFX_BUY
        jsr sfx_play
        MOVI16 ptr0, str_dbg_added
        jmp @msg
@full:  lda #SFX_ERROR
        jsr sfx_play
        MOVI16 ptr0, str_full
        jmp @msg
@boss:  lda dbg_boss            ; jump the ladder to this boss and race
        cmp #BOSS_SECRET
        bne :+
        jsr setup_secret
        clc
        rts
:       sta SV_LADDER
        jsr save_write
        jsr setup_ladder
        clc
        rts
@cash:  lda #<100000
        sta m_a
        lda #>100000
        sta m_a+1
        lda #^100000
        sta m_a+2
        jsr cash_add
        jmp @paid
@gems:  clc
        lda SV_GEMS
        adc #100
        sta SV_GEMS
        bcc @paid
        inc SV_GEMS+1
@paid:  jsr save_write
        lda #SFX_BUY
        jsr sfx_play
        jsr header_update
        jsr wait_frame
        MOVI16 ptr0, str_dbg_done
@msg:   ldy #22
        jsr vb_msg
        jmp @loop

; dbg_values: car name and boss name next to their items
dbg_values:
        lda dbg_car
        jsr car_name_ptr
        lda #12
        jsr pad_ptr0
        ldx #17
        ldy #6
        jsr vb_str
        lda dbg_boss
        jsr boss_line_short
        lda #14
        jsr pad_ptr0
        ldx #17
        ldy #9
        jmp vb_str

; boss_line_short: A = boss -> ptr0 = "3 MAYA"
boss_line_short:
        sta tmp6
        clc
        adc #1
        jsr fmt_8
        ldy #0
        lda numbuf+6
        cmp #' '
        beq :+
        sta linebuf,y
        iny
:       lda numbuf+7
        sta linebuf,y
        iny
        lda #' '
        sta linebuf,y
        iny
        sty tmp5
        lda tmp6
        jsr boss_name_ptr
        ldy tmp5
        jsr cat_ptr0
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        rts

str_dbg:       .byte "DEBUG MENU", 0
str_dbg0:      .byte "ADD CAR", 0
str_dbg1:      .byte "BOSS RACE", 0
str_dbg2:      .byte "ADD $100000", 0
str_dbg3:      .byte "ADD 100 GEMS", 0
str_dbg4:      .byte "BACK", 0
str_dbg_help:  .byte "LEFT/RIGHT:PICK  A:DO IT", 0
str_dbg_help2: .byte "B:BACK", 0
str_dbg_added: .byte "CAR ADDED TO YOUR GARAGE", 0
str_dbg_done:  .byte "DONE!", 0

; ===========================================================================
; STATS
; ===========================================================================
stats_screen:
        lda #0
        jsr screen_begin
        jsr use_menu_palette
        MOVI16 ptr0, str_stats
        jsr draw_header
        PRINT str_st_races, 3, 5
        lda SV_RACES
        sta m_a
        lda SV_RACES+1
        sta m_a+1
        jsr num_text
        ldx #21
        ldy #5
        jsr print
        PRINT str_st_wins, 3, 6
        lda SV_WINS
        sta m_a
        lda SV_WINS+1
        sta m_a+1
        jsr num_text
        ldx #21
        ldy #6
        jsr print
        PRINT str_st_loss, 3, 7
        lda SV_LOSSES
        sta m_a
        lda SV_LOSSES+1
        sta m_a+1
        jsr num_text
        ldx #21
        ldy #7
        jsr print
        ; personal best
        PRINT str_st_pb, 3, 9
        lda SV_PBEST
        sta m_a
        lda SV_PBEST+1
        sta m_a+1
        ora m_a
        beq @nopb
        jsr fmt_ms
        MOVI16 ptr0, numbuf
        ldx #21
        ldy #9
        jsr print
        lda SV_PBCAR
        jsr st_car_name
        ldx #5
        ldy #10
        jsr print
        jmp @spd
@nopb:  PRINT str_dash, 21, 9
@spd:   ; fastest car (top trap speed)
        PRINT str_st_top, 3, 12
        lda SV_TOPSPD+1
        and #$03
        sta m_a+1
        lda SV_TOPSPD
        sta m_a
        ora m_a+1
        beq @nospd
        lda SV_OPTIONS          ; mph -> km/h: * 413 >> 8
        and #OPT_KMH
        beq :+
        lda #<413
        sta m_b
        lda #>413
        sta m_b+1
        jsr mul16
        lda m_r+1
        sta m_a
        lda m_r+2
        sta m_a+1
:       jsr num_text
        ldx #21
        ldy #12
        jsr print
        jsr speed_unit
        ldx #25
        ldy #12
        jsr print
        lda SV_TOPSPD+1
        lsr a
        lsr a
        lsr a
        lsr a
        jsr st_car_name
        ldx #5
        ldy #13
        jsr print
        jmp @boss
@nospd: PRINT str_st_none, 21, 12
@boss:  ; boss tracker
        PRINT str_st_boss, 3, 15
        lda SV_LADDER
        cmp #NBOSS
        bcc :+
        lda #NBOSS
:       clc
        adc SV_SECRET
        jsr fmt_8
        jsr num_ptr
        ldy #0
        jsr cat_ptr0
        sty tmp5
        MOVI16 ptr0, str_st_of11  ; "/11", or "/12" once the secret is known
        lda SV_SECRET
        bne :+
        jsr has_zenith
        bne @of
:       MOVI16 ptr0, str_st_of12
@of:    ldy tmp5
        jsr cat_ptr0
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        ldx #21
        ldy #15
        jsr print
        BOX 1, 16, 30, 9
        lda #0
        sta st_i
@b:     jsr st_boss_line
        lda st_i
        cmp #6
        bcs :+
        ldx #3                  ; left column: bosses 1-6
        clc
        adc #17
        tay
        jmp :++
:       ldx #16                 ; right column: bosses 7-12
        clc
        adc #17-6               ; row 17 for boss 7
        tay
:       jsr print
        inc st_i
        lda st_i
        cmp #NBOSS+1
        bne @b
        PRINT str_st_crates, 3, 26
        lda SV_CRATES
        sta m_a
        lda SV_CRATES+1
        sta m_a+1
        jsr num_text
        ldx #21
        ldy #26
        jsr print
        PRINT str_r_help3, 2, 28
        jsr attr_upload
        lda #0
        sta oam_idx
        jsr oam_clear
        jsr ppu_on
@wait:  jsr wait_frame
        jsr read_pad
        lda pad_new
        and #BTN_A|BTN_B|BTN_START
        beq @wait
        lda #SFX_BACK
        jmp sfx_play

.segment "BSS"
st_i:       .res 1
.segment "BANK1"

; st_car_name: A = model -> ptr0 (car name, or "-" for a bad value)
st_car_name:
        cmp #NCARS
        bcc :+
        MOVI16 ptr0, str_dash
        rts
:       jmp car_name_ptr

; st_boss_line: boss st_i -> ptr0 "+ RIKU" (beaten) / "- DEX" / "- ???"
st_boss_line:
        ldx st_i
        cpx #BOSS_SECRET
        beq @sec
        lda #'-'
        cpx SV_LADDER
        bcs :+
        lda #'+'
:       sta linebuf
        lda #' '
        sta linebuf+1
        txa
        jsr boss_name_ptr
        ldy #2
        jsr cat_ptr0
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        rts
@sec:   lda SV_SECRET
        bne @won
        MOVI16 ptr0, str_st_q
        rts
@won:   lda #'+'
        sta linebuf
        lda #' '
        sta linebuf+1
        txa
        jsr boss_name_ptr
        ldy #2
        jsr cat_ptr0
        lda #0
        sta linebuf,y
        MOVI16 ptr0, linebuf
        rts

str_stats:     .byte "STATS", 0
str_st_races:  .byte "RACES COMPLETED", 0
str_st_wins:   .byte "WINS", 0
str_st_loss:   .byte "LOSSES", 0
str_st_pb:     .byte "BEST 1/4 MILE", 0
str_st_top:    .byte "FASTEST CAR", 0
str_st_none:   .byte "---", 0
str_st_boss:   .byte "BOSSES BEATEN", 0
str_st_of11:   .byte "/11", 0
str_st_of12:   .byte "/12", 0
str_st_q:      .byte "- ???", 0
str_st_crates: .byte "CRATES OPENED", 0
str_r_help3:   .byte "B:BACK", 0
