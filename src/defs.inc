; ===========================================================================
; Pixel Racer NES -- shared constants and macros
; ===========================================================================

.macpack longbranch

; --- hardware -------------------------------------------------------------
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014
APUSTATUS = $4015
JOY1      = $4016
JOY2      = $4017

SQ1_VOL = $4000
SQ1_SWP = $4001
SQ1_LO  = $4002
SQ1_HI  = $4003
SQ2_VOL = $4004
SQ2_SWP = $4005
SQ2_LO  = $4006
SQ2_HI  = $4007
TRI_LIN = $4008
TRI_LO  = $400A
TRI_HI  = $400B
NOI_VOL = $400C
NOI_LO  = $400E
NOI_HI  = $400F

MMC1_CTRL = $8000
MMC1_CHR0 = $A000
MMC1_CHR1 = $C000
MMC1_PRG  = $E000

; --- buttons (bit order after reading the pad) -----------------------------
BTN_A      = $80
BTN_B      = $40
BTN_SELECT = $20
BTN_START  = $10
BTN_UP     = $08
BTN_DOWN   = $04
BTN_LEFT   = $02
BTN_RIGHT  = $01

; --- PPUCTRL values ----------------------------------------------------------
CTRL_NMI    = $80
CTRL_SPR1K  = $08       ; sprites from pattern table $1000
CTRL_BASE   = CTRL_NMI | CTRL_SPR1K

; --- banks ------------------------------------------------------------------
BANK_GFX   = 0
BANK_MENU  = 1
BANK_RACE  = 2
BANK_MENU2 = 3

; --- game modes (index into mode table in main.s) ----------------------------
MODE_TITLE   = 0
MODE_GARAGE  = 1
MODE_RACE    = 2
MODE_RESULTS = 3

; --- save layout (WRAM $6000) ----------------------------------------------
SAVE_MAGIC   = $6000            ; 4 bytes "PXR1"
SV_CASH      = $6004            ; 3 bytes, binary, little endian
SV_GEMS      = $6007            ; 2 bytes
SV_XP        = $6009            ; 2 bytes (xp inside current level)
SV_LEVEL     = $600B
SV_LADDER    = $600C            ; ladder bosses beaten (0-10)
SV_CURCAR    = $600D            ; garage slot in use
SV_OPTIONS   = $600E            ; bit0 km/h, bit1 music off, bit2 auto shift
SV_WINS      = $600F            ; 2 bytes
SV_LOSSES    = $6011            ; 2 bytes
SV_CRATES    = $6013            ; crates opened (2 bytes)
SV_SEED      = $6015            ; 2 bytes rng seed carried across power cycles
SV_STREET    = $6017            ; street races won
SV_CARS      = $6020            ; 8 slots x 32 bytes
SV_END       = SV_CARS + 8*32   ; $6120
SV_SUM       = SV_END           ; 2-byte checksum over $6004..SV_END-1
NSLOTS       = 8

OPT_KMH      = $01
OPT_NOMUSIC  = $02
OPT_AUTO     = $04

; --- car record (32 bytes, same layout in save slots and RAM records) --------
CR_MODEL  = 0                   ; $FF = empty slot
CR_PARTS  = 1                   ; 10 bytes
CR_PAINT  = 11
CR_RIM    = 12
CR_GLASS  = 13
CR_FINAL  = 14                  ; 2 bytes 8.8
CR_GEARS  = 16                  ; 7 x 2 bytes 8.8
CR_BEST   = 30                  ; best 1/4 mile ET in ms (2 bytes, 0 = none)
CR_SIZE   = 32

NPARTS     = 10
P_INTAKE   = 0
P_EXHAUST  = 1
P_ECU      = 2
P_TURBO    = 3
P_INTERNAL = 4
P_NITROUS  = 5
P_GEARBOX  = 6
P_TIRES    = 7
P_SUSP     = 8
P_WEIGHT   = 9

; --- WRAM work areas -------------------------------------------------------
WBUF      = $6400               ; 1 KB general buffer (big car tiles etc.)
DYNO_BMP  = $6800               ; 2 KB dyno graph bitmap (128 tiles)

; --- physics ------------------------------------------------------------------
IDLE_RPM  = 900

; --- race kinds ----------------------------------------------------------------
RK_LADDER = 0
RK_QUICK  = 1
RK_STREET = 2
RK_TEST   = 3

; --- result flags ------------------------------------------------------------
RF_WIN    = $01
RF_FOUL   = $02
RF_OPPFIN = $04         ; opponent finished (has an ET)
RF_DONE   = $80

; --- misc ---------------------------------------------------------------------
VBUF_MAX  = 104
NMI_CHR_VLEN = 40            ; CHR streaming only if the queue is this short

; Write A to an MMC1 register (5 serial writes, LSB first).  Clobbers A.
.macro MMC1_WRITE reg
        sta reg
        lsr a
        sta reg
        lsr a
        sta reg
        lsr a
        sta reg
        lsr a
        sta reg
.endmacro

; 16-bit helpers
.macro LDXY16 val
        ldx #<(val)
        ldy #>(val)
.endmacro

.macro MOV16 dst, src
        lda src
        sta dst
        lda src+1
        sta dst+1
.endmacro

.macro MOVI16 dst, val
        lda #<(val)
        sta dst
        lda #>(val)
        sta dst+1
.endmacro
