; ===========================================================================
; core.s -- reset, NMI, frame sync, input, banking, random numbers, main loop
; (fixed bank)
; ===========================================================================

.segment "BSS"
fc_ptr:     .res 2
fc_ret:     .res 1
numbuf:     .res 10

.segment "FIXED"

; ---------------------------------------------------------------------------
reset:
        sei
        cld
        ldx #$40
        stx JOY2                ; disable APU frame IRQ
        ldx #$FF
        txs
        inx
        stx PPUCTRL
        stx PPUMASK
        stx $4010               ; no DMC IRQ
        bit PPUSTATUS
@vb1:   bit PPUSTATUS
        bpl @vb1

        ; clear RAM
        txa
@clr:   sta $00,x
        sta $0100,x
        sta $0300,x
        sta $0400,x
        sta $0500,x
        sta $0600,x
        sta $0700,x
        inx
        bne @clr
        lda #$F8                ; hide all sprites
@clro:  sta oam,x
        inx
        bne @clro

        ; MMC1: vertical mirroring, PRG mode 3 (fixed $C000), 8 KB CHR
        lda #$80
        sta MMC1_CTRL
        lda #$0E
        MMC1_WRITE MMC1_CTRL
        lda #$00
        MMC1_WRITE MMC1_CHR0    ; bit 4 clear: WRAM enabled (SNROM)
        lda #$00
        MMC1_WRITE MMC1_CHR1
        lda #BANK_MENU
        jsr set_bank

        ; second vblank: PPU is ready.  Time one frame for region detection.
@vb2:   bit PPUSTATUS
        bpl @vb2
        ldx #0
        ldy #0
@time:  inx                     ; 12 cycles per loop
        bne @nc
        iny
@nc:    bit PPUSTATUS
        bpl @time
        lda #0
        cpy #10
        bcc @reg
        lda #1
        cpy #11
        bcc @reg
        lda #2
@reg:   sta region

        jsr sound_init
        jsr save_load           ; validates or initialises the save
        lda SV_SEED
        sta rng
        lda SV_SEED+1
        ora #$01
        sta rng+1

        lda #CTRL_BASE
        sta ppu_ctrl
        bit PPUSTATUS
        sta PPUCTRL             ; NMI on (rendering stays off for now)
        lda #MODE_TITLE
        sta next_mode
        ; fall through
; ---------------------------------------------------------------------------
; Main loop: run the mode routine named by next_mode in its bank.
; ---------------------------------------------------------------------------
main_loop:
        ldx next_mode
        stx game_mode
        lda mode_bank,x
        jsr set_bank
        lda game_mode
        asl a
        tax
        lda mode_addr,x
        sta fc_ptr
        lda mode_addr+1,x
        sta fc_ptr+1
        jsr @go
        jmp main_loop
@go:    jmp (fc_ptr)

mode_bank:
        .byte BANK_MENU, BANK_MENU, BANK_RACE, BANK_MENU
mode_addr:
        .word title_main, garage_main, race_main, results_main

irq:
        rti

; ---------------------------------------------------------------------------
; NMI: sprites, palette, VRAM queue, CHR stream, scroll, then sound.
; ---------------------------------------------------------------------------
nmi:
        pha
        txa
        pha
        tya
        pha
        lda nmi_ready
        bne @ppu
        jmp @scroll
@ppu:
        lda vbuf_len
        sta nmi_vlen
        lda #0
        sta OAMADDR
        lda #>oam
        sta OAMDMA

        lda pal_dirty
        beq @nopal
        lda ppu_ctrl
        and #$FB
        sta PPUCTRL
        lda #$3F
        sta PPUADDR
        lda #$00
        sta PPUADDR
        ldx #0
@pal:   lda palette,x
        sta PPUDATA
        inx
        cpx #32
        bne @pal
        lda #0
        sta pal_dirty
        lda #$FF                ; no time left for the CHR stream this frame
        sta nmi_vlen
@nopal:
        ; VRAM update list: hi, lo, count (bit 7 = step 32), data...
        ldx #0
@vb:    lda vbuf,x
        beq @vbdone
        sta PPUADDR
        lda vbuf+1,x
        sta PPUADDR
        lda vbuf+2,x
        bmi @vert
        lda ppu_ctrl
        and #$FB
        sta PPUCTRL
        lda vbuf+2,x
        jmp @cnt
@vert:  lda ppu_ctrl
        ora #$04
        sta PPUCTRL
        lda vbuf+2,x
        and #$7F
@cnt:   tay
        inx
        inx
        inx
@copy:  lda vbuf,x
        sta PPUDATA
        inx
        dey
        bne @copy
        jmp @vb
@vbdone:
        lda #0
        sta vbuf
        sta vbuf_len

        ; CHR stream: 32 bytes per frame from (chr_src) to chr_dst.
        ; Only on frames with a short VRAM queue and no palette upload,
        ; so the NMI always finishes its PPU writes inside vblank.
        lda chr_cnt
        jeq @nochr
        lda nmi_vlen
        cmp #NMI_CHR_VLEN+1
        jcs @nochr
        lda ppu_ctrl
        and #$FB
        sta PPUCTRL
        lda chr_dst+1
        sta PPUADDR
        lda chr_dst
        sta PPUADDR
        ldy #0
.repeat 32
        lda (chr_src),y
        sta PPUDATA
        iny
.endrepeat
        clc
        lda chr_src
        adc #32
        sta chr_src
        bcc :+
        inc chr_src+1
:       clc
        lda chr_dst
        adc #32
        sta chr_dst
        bcc :+
        inc chr_dst+1
:       dec chr_cnt
@nochr:
        lda ppu_mask
        sta PPUMASK
        lda #0
        sta nmi_ready
@scroll:
        lda ppu_ctrl
        ora scroll_nt
        sta PPUCTRL
        bit PPUSTATUS
        lda scroll_x
        sta PPUSCROLL
        lda scroll_y
        sta PPUSCROLL
nmi_ppu_done:                   ; (tests time the NMI up to here)
        inc frame
        bne :+
        inc frame+1
:       jsr sound_update
        pla
        tay
        pla
        tax
        pla
        rti

; ---------------------------------------------------------------------------
; wait_frame: hand the prepared frame to the NMI and wait for it.
; ---------------------------------------------------------------------------
wait_frame:
        ldx vbuf_len
        lda #0
        sta vbuf,x
        lda #1
        sta nmi_ready
@w:     lda nmi_ready
        bne @w
        rts

; wait A frames (no input)
wait_frames:
        sta tmp7
@l:     jsr wait_frame
        dec tmp7
        bne @l
        rts

; ---------------------------------------------------------------------------
; read_pad: pad, pad_new (newly pressed), pad_rpt (new + d-pad auto-repeat)
; ---------------------------------------------------------------------------
read_pad:
        lda pad
        sta pad_old
        lda #1
        sta JOY1
        sta pad
        lsr a
        sta JOY1
@rd:    lda JOY1
        and #$03
        cmp #1
        rol pad
        bcc @rd
        ; Famicom expansion controllers on bit 1 are folded in above.
        lda pad_old
        eor #$FF
        and pad
        sta pad_new
        sta pad_rpt
        ; auto-repeat for the d-pad
        lda pad
        and #$0F
        beq @norep
        lda pad_new
        and #$0F
        beq @held
        lda #18
        sta pad_rep
        rts
@held:  dec pad_rep
        bne @done
        lda #5
        sta pad_rep
        lda pad
        and #$0F
        ora pad_rpt
        sta pad_rpt
@done:  rts
@norep: lda #0
        sta pad_rep
        rts

; ---------------------------------------------------------------------------
; Banking
; ---------------------------------------------------------------------------
set_bank:
        sta cur_bank
        MMC1_WRITE MMC1_PRG     ; bit 4 = 0 keeps WRAM enabled
        rts

; farcall: A = bank, X/Y = address lo/hi.  Arguments go in zero page.
; Returns the callee's A.
farcall:
        stx fc_ptr
        sty fc_ptr+1
        tax
        lda cur_bank
        pha
        txa
        jsr set_bank
        jsr @go
        sta fc_ret
        pla
        jsr set_bank
        lda fc_ret
        rts
@go:    jmp (fc_ptr)

.macro FARCALL bank, addr
        lda #bank
        ldx #<(addr)
        ldy #>(addr)
        jsr farcall
.endmacro

; ---------------------------------------------------------------------------
; Random numbers (16-bit Galois LFSR).  rand -> A
; ---------------------------------------------------------------------------
rand:
        ldx #8
        lda rng
@l:     asl a
        rol rng+1
        bcc :+
        eor #$2D
:       dex
        bne @l
        sta rng
        cmp #0
        rts

; rand_below: A = limit (1-255) -> A in 0..limit-1
rand_below:
        sta tmp6
        jsr rand
        sta m_a
        lda tmp6
        sta m_b
        jsr mul8
        lda m_r+1
        rts
