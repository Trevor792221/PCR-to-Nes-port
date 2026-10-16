; ===========================================================================
; Pixel Racer NES
; An unofficial NES demake of the drag-racing / car-building game genre made
; popular by Pixel Car Racer.  All code, art, music and names are original.
;
; Build: ca65 + ld65 (see Makefile).  Mapper: MMC1 (SNROM), 128 KB PRG,
; 8 KB CHR-RAM, 8 KB battery-backed WRAM.
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
race_half:  .res 1          ; 0 = 1/4 mile, 1 = 1/2 mile (menu setting)
opp_rec:    .res 32         ; opponent car record
opp_name:   .res 13
opp_skill:  .res 1
res_flags:  .res 1          ; RF_* bits
res_et:     .res 2          ; ms
res_trap:   .res 1
res_rt:     .res 2          ; reaction time ms
res_opp_et: .res 2
res_t60:    .res 2          ; 0-60 time ms
tmp_rec:    .res 32         ; scratch car record (dealer, crates)

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

.segment "BANK0"
.include "gfx.s"

.segment "BANK1"
.include "menus.s"

.segment "BANK3"
.include "menus2.s"

.segment "BANK2"
.include "race.s"

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
