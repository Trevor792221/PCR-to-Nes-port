; ---------------------------------------------------------------------------
; NES 2.0 header: mapper 1 (MMC1, SNROM), 128 KB PRG-ROM, 8 KB CHR-RAM,
; 8 KB PRG-RAM (work RAM, no battery: the game saves with passwords).
; ---------------------------------------------------------------------------
.segment "HEADER"
        .byte "NES", $1A
        .byte 8                 ; 8 x 16 KB PRG-ROM
        .byte 0                 ; CHR-ROM: none (CHR-RAM)
        .byte $10               ; mapper 1 low nibble, no battery
        .byte $08               ; NES 2.0 identifier
        .byte $00               ; mapper high / submapper
        .byte $00               ; ROM size MSBs
        .byte $07               ; PRG-RAM 64<<7 = 8 KB (volatile)
        .byte $07               ; CHR-RAM 64<<7 = 8 KB
        .byte $00               ; NTSC timing
        .byte $00, $00, $00
