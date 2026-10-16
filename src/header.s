; ---------------------------------------------------------------------------
; NES 2.0 header: mapper 1 (MMC1, SNROM), 128 KB PRG-ROM, 8 KB CHR-RAM,
; 8 KB battery-backed PRG-RAM.
; ---------------------------------------------------------------------------
.segment "HEADER"
        .byte "NES", $1A
        .byte 8                 ; 8 x 16 KB PRG-ROM
        .byte 0                 ; CHR-ROM: none (CHR-RAM)
        .byte $12               ; mapper 1 low nibble, battery
        .byte $08               ; NES 2.0 identifier
        .byte $00               ; mapper high / submapper
        .byte $00               ; ROM size MSBs
        .byte $70               ; PRG-NVRAM 64<<7 = 8 KB
        .byte $07               ; CHR-RAM 64<<7 = 8 KB
        .byte $00               ; NTSC timing
        .byte $00, $00, $00
