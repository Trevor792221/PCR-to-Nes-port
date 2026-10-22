; ===========================================================================
; Pixel Racer NES
; An unofficial NES demake of the drag-racing / car-building game genre made
; popular by Pixel Car Racer.  All code, art, music and names are original.
;
; Build: ca65 + ld65 (see Makefile).  Mapper: MMC1 (SNROM), 128 KB PRG,
; 8 KB CHR-RAM, 8 KB battery-backed WRAM (the save; passwords work too).
; ===========================================================================

.include "defs.inc"
.include "build/tiles.inc"

; ---------------------------------------------------------------------------
; Zero page
; ---------------------------------------------------------------------------
.segment "ZEROPAGE"
tmp0:       .res 1
tmp1:       .res 1
tmp2:       .res 1
tmp3:       .res 1
tmp4:       .res 1
tmp5:       .res 1
tmp6:       .res 1
tmp7:       .res 1
ptr0:       .res 2
ptr1:       .res 2
ptr2:       .res 2
ptr3:       .res 2
m_a:        .res 4          ; math operand A
m_b:        .res 4          ; math operand B
m_r:        .res 8          ; math result
nmi_ready:  .res 1
frame:      .res 2
ppu_ctrl:   .res 1
ppu_mask:   .res 1
scroll_x:   .res 1
scroll_y:   .res 1
scroll_nt:  .res 1
pad:        .res 1
pad_old:    .res 1
pad_new:    .res 1
pad2:       .res 1          ; controller 2 (two-player races)
pad2_old:   .res 1
pad2_new:   .res 1
cur_bank:   .res 1
vbuf_len:   .res 1
pal_dirty:  .res 1
rng:        .res 2
chr_cnt:    .res 1          ; 32-byte CHR chunks left to stream
chr_src:    .res 2
chr_dst:    .res 2
region:     .res 1          ; 0 NTSC, 1 PAL, 2 Dendy
game_mode:  .res 1
next_mode:  .res 1
oam_idx:    .res 1
text_attr:  .res 1          ; $00 normal font, $20 colour-3 font
pad_rep:    .res 1          ; auto-repeat timer
kb_off:     .res 1          ; 1: the keyboard isn't a controller (it types)
kb_idle:    .res 1          ; frames until we look for a keyboard again
kb_k:       .res 5          ; keyboard rows read this frame (1 = key down)
pad_rpt:    .res 1          ; pad_new plus auto-repeat for d-pad
sp_x:       .res 1          ; sprite helpers
sp_y:       .res 1
sp_attr:    .res 1
sp_tile:    .res 1
cx:         .res 1          ; physics: current car (0 player, 1 opponent)
sfx_req:    .res 1          ; sound effect request (0 = none)
mul_x:      .res 1
mul_y:      .res 1
mul_r:      .res 2
nmi_vlen:   .res 1          ; VRAM queue length this NMI ($FF = busy)
zp_end:     .res 1

; ---------------------------------------------------------------------------
; RAM
; ---------------------------------------------------------------------------
.segment "OAM"
oam:        .res 256

.segment "BSS"
vbuf:       .res VBUF_MAX + 8
palette:    .res 32

; race set-up (written by the menus, read by the race) and results
race_kind:  .res 1          ; RK_*
race_dist:  .res 2          ; pixels (1609 = 1/4 mile)
race_diff:  .res 1          ; quick race difficulty 0-2
race_bet:   .res 3
race_half:  .res 1          ; 0 = 1/4 mile, 1 = 1/2 mile, 2 = 1 mile (menu setting)
cruise_empty: .res 1        ; cruise mode: 1 = no traffic
opp_rec:    .res CR_SIZE    ; opponent car record
opp_name:   .res 13
opp_skill:  .res 1
res_flags:  .res 1          ; RF_* bits
res_et:     .res 2          ; ms
res_trap:   .res 2          ; trap speed (mph or km/h)
res_rt:     .res 2          ; reaction time ms
res_opp_et: .res 2
res_t60:    .res 2          ; 0-60 time ms
res_mph:    .res 2          ; trap speed in mph (for the stats page)
tmp_rec:    .res CR_SIZE    ; scratch car record (dealer, crates)
race_theme: .res 1          ; 0 day, 1 sunset, 2 night (picked per race)
race_scene: .res 1          ; background: race_theme, + 3 when overcast
opp_cap:    .res 1          ; easy rivals: power handicap /256 (0 outside quick races)
race_weather: .res 1        ; W_CLEAR, W_CLOUDY, W_RAIN, W_SNOW (0 outside races)
weather_force: .res 1       ; tests: weather + 1 for the next races (0 = random)
theme_force: .res 1         ; tests: time of day + 1 likewise
copy_bank:  .res 1          ; source bank for chr_copy / bank0_copy (0 = graphics)
garage_song: .res 1         ; garage theme in use (SONG_GARAGE, SONG_NEON or SONG_NIGHT)
new_song:   .res 1          ; set by a race: the garage picks a theme again
garage_look: .res 1         ; the garage: 0 day, 1 night, 2 sunset (GL_*)
map_region: .res 1          ; map region the races are in (0 FUKUOKA .. 6 TOKYO)

; ---------------------------------------------------------------------------
.include "header.s"

.segment "FIXED"
.include "core.s"
.include "math.s"
.include "ppu.s"
.include "ui.s"
.include "sound.s"
.include "physics.s"
.include "save.s"
.include "cardata.s"

; ---------------------------------------------------------------------------
; Cheat switches at fixed addresses for Game Genie codes (see CHEATS.md).
; The game always reads these bytes from ROM, so a Game Genie code that
; changes one turns the cheat on.  Addresses must never move.
; ---------------------------------------------------------------------------
.segment "CHEATS"
cheat_start_car: .byte 0        ; $FFC0  model of the new-game car
cheat_money:     .byte 0        ; $FFC1  non-zero: cash refilled to $9,999,999
cheat_debug:     .byte 0        ; $FFC2  non-zero: SELECT in the garage = debug menu
.assert cheat_start_car = $FFC0, error, "cheat table moved"
.assert cheat_debug = $FFC2, error, "cheat table moved"

.segment "BANK0"
.include "gfx.s"

.segment "BANK1"
.include "menus.s"

.segment "BANK3"
.include "menus2.s"
.include "tune_ui.s"

.segment "BANK4"
.include "scenes.s"
.include "splash.s"

.segment "BANK2"
.include "race.s"

.segment "BANK5"
.include "password.s"
.include "scenes2.s"

.segment "BANK6"
.include "map.s"
.include "tune.s"
.include "swap.s"
.include "tape.s"

; ---------------------------------------------------------------------------
; Reset stubs: identical in every bank so the console boots no matter which
; bank MMC1 maps at $C000 on power-up.
; ---------------------------------------------------------------------------
.macro RESET_STUB
.scope
stub:   sei
        ldx #$FF
        txs
        stx MMC1_CTRL           ; bit 7 set: reset MMC1 (fixes last bank at $C000)
        jmp reset
stub_end:
        .res 26 - (stub_end - stub), $FF
        .word nmi, stub, irq
.endscope
.endmacro

.segment "STUB0"
        RESET_STUB
.segment "STUB1"
        RESET_STUB
.segment "STUB2"
        RESET_STUB
.segment "STUB3"
        RESET_STUB
.segment "STUB4"
        RESET_STUB
.segment "STUB5"
        RESET_STUB
.segment "STUB6"
        RESET_STUB
.segment "STUB7"
        RESET_STUB
