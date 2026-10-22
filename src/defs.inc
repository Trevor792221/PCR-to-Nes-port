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
BANK_SCENE = 4                  ; race background themes
BANK_PW    = 5                  ; passwords
BANK_MAP   = 6                  ; world map, engine tune maths
NREGIONS   = 7                  ; map regions (FUKUOKA .. TOKYO)

; --- game modes (index into mode table in main.s) ----------------------------
MODE_TITLE   = 0
MODE_GARAGE  = 1
MODE_RACE    = 2
MODE_RESULTS = 3
MODE_SPLASH  = 4

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
SV_SECRET    = $6018            ; secret boss beaten (0/1)
SV_RACES     = $6019            ; races completed (2 bytes)
SV_PBEST     = $601B            ; best 1/4 mile time in ms, any car (2 bytes)
SV_PBCAR     = $601D            ; model that set it
SV_TOPSPD    = $601E            ; top trap speed: mph (bits 0-9) | model << 12
SV_CARS      = $6020            ; 8 slots x 48 bytes
SV_BESTS     = SV_CARS + 8*CR_SIZE  ; $61A0: best 1/4 mile ET per slot in ms (8 x 2)
SV_OWNED     = SV_BESTS + 16    ; $61B0: swaps each slot has paid for (8 x 3):
                                ;   bit e = engine e (0-16), bit 20 + d = drivetrain d;
                                ;   only ones not fitted now (see swap.s)
SV_END       = SV_OWNED + 24    ; $61C8
SV_SUM       = SV_END           ; 2-byte checksum over $6004..SV_END-1
NSLOTS       = 8

OPT_KMH      = $01
OPT_NOMUSIC  = $02
OPT_AUTO     = $04

CASH_MAX     = 9999999          ; cash never goes past this (fits every display)

; --- car record (48 bytes, same layout in save slots and RAM records) --------
CR_MODEL  = 0                   ; $FF = empty slot
CR_PARTS  = 1                   ; 14 bytes
CR_PAINT  = 15
CR_RIM    = 16
CR_GLASS  = 17
CR_FINAL  = 18                  ; 2 bytes 8.8
CR_GEARS  = 20                  ; 7 x 2 bytes 8.8
CR_FUEL   = 34                  ; engine tune, signed, 0 = stock: fuel map
                                ;   (8 cells, -5 rich .. +5 lean),
CR_TIMING = 42                  ;   ignition advance (-5 .. +5),
CR_TIREP  = 43                  ;   tire psi from 32 (-14 .. +8),
CR_BOOST  = 44                  ;   boost psi from the turbo's own,
CR_LAUNCH = 45                  ;   2-step launch rpm/100 (0 off)
MAX_LEVEL = 99
EASY_CAP  = 32                  ; easy quick-race rivals: -32/256 power (12.5%)
CR_NOS    = 46                  ;   nitrous: -4 more power .. +4 longer
CR_SWAP   = 47                  ; swaps: engine id + 1 in bits 0-4, drivetrain
SWAP_ENG  = $1F                 ;   + 1 in bits 5-6 (0 = the car's own)
SWAP_DRV  = $60
CR_SIZE   = 48
NCELLS    = 8                   ; fuel map cells

NPARTS     = 14
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
P_ICOOL    = 10                 ; intercooler
P_AERO     = 11
P_WHEELIE  = 12                 ; wheelie bars
P_INJECT   = 13                 ; injectors

; --- WRAM work areas -------------------------------------------------------
WBUF      = $6400               ; 1 KB general buffer (big car tiles etc.)
DYNO_BMP  = $6800               ; 2 KB dyno graph bitmap (128 tiles)

; --- physics ------------------------------------------------------------------
IDLE_RPM  = 900

; --- race kinds ----------------------------------------------------------------
GL_DAY    = 0                   ; garage_look: the garage by day,
GL_NIGHT  = 1                   ;   at night (door open on the city),
GL_SUNSET = 2                   ;   at sunset (door open on the sun going down)

RK_LADDER = 0
RK_QUICK  = 1
RK_STREET = 2
RK_TEST   = 3
RK_SECRET = 4                   ; hidden 12th boss (needs the Zenith X400)
RK_CRUISE = 5                   ; endless driving with traffic, quit from pause
RK_2P     = 6                   ; two players: controller 2 drives the other car

; --- result flags ------------------------------------------------------------
RF_WIN    = $01
RF_FOUL   = $02
RF_OPPFIN = $04         ; opponent finished (has an ET)
RF_P2FOUL = $08         ; two players: player 2 jumped the start
RF_LAUNCH = $10         ; player launched (has a reaction time)
RF_DONE   = $80

; --- misc ---------------------------------------------------------------------
VBUF_MAX  = 104
NMI_CHR_VLEN = 40            ; CHR streaming only if the queue is this short
NMI_PAL_VLEN = 48            ; palette upload only if the queue is this short

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
