; ===========================================================================
; tune.s -- what the engine tune does to a car (bank 6, called from
; phys_setup).  tools/gamedata.py tune_calc is the reference: keep them the
; same.  A record whose tune bytes are all 0 behaves exactly like stock.
;
;   boost   psi = turbo's own psi + setting (3 .. the turbo's max).  Over its
;           own psi: +6/256 power per psi.  Under: the boost curve shrinks.
;   fuel    per cell k (an eighth of the redline): f = -5 rich .. +5 lean.
;           lean = max(0, f + overboost - 3 * injector level)  (overboost
;           only counts where the turbo has spooled)
;   timing  t = -5 .. +5.  Knock limit L = 3 + intercooler + rich/2
;           - overboost/2 - lean.  Up to L: +3 per step; past it -12 per
;           step over (knock).
;   cell power d = timing + 2f - 12 lean.  The best cell's d goes into the
;           power multiplier; the others scale their part of the torque
;           curve down from there.
;   tires   psi from 32: -2 grip and -1 rolling drag per psi
;   wheelie bars: launch grip per level (RWD 5, FWD and AWD 3)
;   2-step  launch rpm (needs an ECU upgrade)
; ===========================================================================

.segment "BSS"
tn_hpm:     .res 2          ; added to the power multiplier (signed)
tn_band:    .res NCELLS     ; power factor per fuel cell /256 (0 = 256)
tn_bmul:    .res 1          ; boost scale /256 when turned down (0 = none)
tn_grip:    .res 1          ; launch grip (signed)
tn_psi:     .res 1          ; boost in psi (0 = no turbo)
tn_knock:   .res 1          ; cells that knock (bit k = cell k)
tn_lean:    .res 1          ; cells that run lean
tn_ob:      .res 1          ; psi over the turbo's own
tn_tl:      .res 1
tn_k:       .res 1
tn_f:       .res 1
tn_obk:     .res 1
tn_ln:      .res 1
tn_lim:     .res 1
tn_top:     .res 1
tn_bit:     .res 1          ; this cell's bit
tn_tmp:     .res 1
tn_acc:     .res 2
tn_d:       .res NCELLS
.segment "BANK6"

.include "build/tunedata.inc"

; tn_adds: tn_acc += A (signed)
tn_adds:
        pha
        clc
        adc tn_acc
        sta tn_acc
        pla
        bpl :+
        lda #$FF
        bne :++
:       lda #0
:       adc tn_acc+1
        sta tn_acc+1
        rts

; tn_le_lim: carry set if signed A <= signed tn_lim
tn_le_lim:
        eor #$80
        sta tn_tmp
        lda tn_lim
        eor #$80
        cmp tn_tmp
        rts

; tune_calc: ptr0 = car record, cx = car.  Sets tn_*, ph_roll and ph_ls.
tune_calc:
        ; --- boost ----------------------------------------------------------
        lda #0
        sta tn_psi
        sta tn_ob
        sta tn_bmul
        ldy #CR_PARTS+P_TURBO
        lda (ptr0),y
        sta tn_tl
        beq @nb
        tax
        ldy #CR_BOOST
        clc
        lda (ptr0),y
        adc tn_turbo_psi,x      ; own psi + setting (signed)
        bmi @min
        cmp #TURBO_PSI_MIN
        bcs :+
@min:   lda #TURBO_PSI_MIN
:       cmp tn_turbo_max,x
        bcc :+
        lda tn_turbo_max,x
:       sta tn_psi
        sec
        sbc tn_turbo_psi,x
        bcc @under
        sta tn_ob
        jmp @nb
@under: lda #0                  ; psi * 256 / own psi
        sta m_r
        lda tn_psi
        sta m_r+1
        lda tn_turbo_psi,x
        jsr div16_8
        lda m_r
        sta tn_bmul
@nb:
        ; --- fuel map and timing, cell by cell ----------------------------------
        lda #0
        sta tn_knock
        sta tn_lean
        sta tn_k
        lda #1
        sta tn_bit
@cell:  lda #0
        sta tn_acc
        sta tn_acc+1
        ; overboost only where the turbo makes boost: 4k+3 >= turbo start
        sta tn_obk
        lda tn_tl
        beq :+
        tax
        lda tn_k
        asl a
        asl a
        clc
        adc #3
        cmp turbo_start,x
        bcc :+
        lda tn_ob
        sta tn_obk
:       ; f
        lda tn_k
        clc
        adc #CR_FUEL
        tay
        lda (ptr0),y
        sta tn_f
        ; lean = max(0, f + obk - 3*inj)
        ldy #CR_PARTS+P_INJECT
        lda (ptr0),y
        sta tn_tmp
        asl a
        adc tn_tmp              ; *3 (LEAN_STEP)
        sta tn_tmp
        clc
        lda tn_f
        adc tn_obk
        sec
        sbc tn_tmp
        bpl :+
        lda #0
:       sta tn_ln
        ; L = 3 + ic + rich/2 - obk/2 - lean
        ldy #CR_PARTS+P_ICOOL
        lda (ptr0),y
        clc
        adc #3
        sta tn_lim
        lda tn_f
        bpl :+
        eor #$FF                ; -f
        clc
        adc #1
        lsr a
        clc
        adc tn_lim
        sta tn_lim
:       lda tn_obk
        lsr a
        sta tn_tmp
        sec
        lda tn_lim
        sbc tn_tmp
        sec
        sbc tn_ln
        sta tn_lim
        ; timing: t <= L: 3t, else 3L - 12(t-L) and the cell knocks
        ldy #CR_TIMING
        lda (ptr0),y
        jsr tn_le_lim
        bcc @knock
        lda (ptr0),y
        jsr tn_adds
        lda (ptr0),y
        jsr tn_adds
        lda (ptr0),y
        jsr tn_adds
        jmp @fuel
@knock: lda tn_bit
        ora tn_knock
        sta tn_knock
        lda tn_lim
        jsr tn_adds
        lda tn_lim
        jsr tn_adds
        lda tn_lim
        jsr tn_adds
        sec                     ; -12 per step past the limit
        lda (ptr0),y
        sbc tn_lim
        tax
:       lda #<-12
        jsr tn_adds
        dex
        bne :-
@fuel:  lda tn_f                ; + 2f
        jsr tn_adds
        lda tn_f
        jsr tn_adds
        ldx tn_ln               ; - 12 per lean step
        beq @sum
        lda tn_bit
        ora tn_lean
        sta tn_lean
:       lda #<-12
        jsr tn_adds
        dex
        bne :-
@sum:   ; d = max(-120, acc)  (acc is never above 127)
        lda tn_acc
        ldx tn_acc+1
        bpl @st
        inx
        bne @floor              ; below -256
        cmp #<-120
        bcs @st
@floor: lda #<-120
@st:    ldx tn_k
        sta tn_d,x
        asl tn_bit
        inc tn_k
        lda tn_k
        cmp #NCELLS
        jcc @cell
        ; --- best cell -> power multiplier, the rest scale down from it ----------
        lda tn_d
        sta tn_top
        ldx #1
@mx:    lda tn_d,x
        sec
        sbc tn_top
        bvc :+
        eor #$80
:       bmi :+
        lda tn_d,x
        sta tn_top
:       inx
        cpx #NCELLS
        bne @mx
        ldx #0
@bd:    sec                     ; 256 + d - top  (d - top is -247..0)
        lda tn_d,x
        sbc tn_top
        sta tn_band,x           ; 0 when d = top: stands for 256
        inx
        cpx #NCELLS
        bne @bd
        ; hpm = top + 6 * overboost  (6 * ob <= 54)
        lda tn_ob
        asl a
        adc tn_ob
        asl a
        sta tn_acc
        lda #0
        sta tn_acc+1
        lda tn_top
        jsr tn_adds
        lda tn_acc
        sta tn_hpm
        lda tn_acc+1
        sta tn_hpm+1
        ; --- grip: wheelie bars, and -2 per tire psi --------------------------
        ldx cx
        ldy ph_model,x
        lda car_drive,y
        tax
        ldy #CR_PARTS+P_WHEELIE
        lda (ptr0),y
        sta m_a
        lda tn_wheelie,x
        sta m_b
        jsr mul8
        ldy #CR_TIREP
        sec
        lda m_r
        sbc (ptr0),y
        sec
        sbc (ptr0),y
        sta tn_grip
        ; rolling drag = max(3, 9 - tire psi)
        ldx cx
        sec
        lda #9
        sbc (ptr0),y
        bmi :+
        cmp #3
        bcs :++
:       lda #3
:       sta ph_roll,x
        ; --- 2-step: launch rpm / 100, only with an ECU upgrade ----------------
        lda #0
        sta ph_ls_l,x
        sta ph_ls_h,x
        ldy #CR_PARTS+P_ECU
        lda (ptr0),y
        beq @done
        ldy #CR_LAUNCH
        lda (ptr0),y
        beq @done
        sta m_a
        lda #100
        sta m_b
        jsr mul8
        ldx cx
        lda m_r
        sta ph_ls_l,x
        lda m_r+1
        sta ph_ls_h,x
@done:  rts
