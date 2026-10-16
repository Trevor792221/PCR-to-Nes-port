; ===========================================================================
; physics.s -- car setup and per-frame drag physics (fixed bank)
;
; Mirrors the Car class in tools/gamedata.py operation for operation.
; Two cars (X = 0 player, X = 1 opponent).
;   v, wv : 24-bit, 1/65536 px per frame (top 16 bits = 1/256 px/frame)
;   pos   : 24-bit, 1/256 px
;   rpm   : 16-bit
; ===========================================================================

.segment "BSS"
ph_v0:      .res 2
ph_v1:      .res 2
ph_v2:      .res 2
ph_w0:      .res 2
ph_w1:      .res 2
ph_w2:      .res 2
ph_p0:      .res 2
ph_p1:      .res 2
ph_p2:      .res 2
ph_rpm_l:   .res 2
ph_rpm_h:   .res 2
ph_gear:    .res 2
ph_ngears:  .res 2
ph_shift_t: .res 2
ph_spool:   .res 2
ph_nos_t:   .res 2
ph_nos_on:  .res 2
ph_spin:    .res 2
ph_slip:    .res 2
ph_thr:     .res 2
ph_model:   .res 2
ph_redl_l:  .res 2
ph_redl_h:  .res 2
ph_lim_l:   .res 2
ph_lim_h:   .res 2
ph_trac_l:  .res 2
ph_trac_h:  .res 2
ph_tk_l:    .res 2
ph_tk_h:    .res 2
ph_dk_l:    .res 2
ph_dk_h:    .res 2
ph_k0h_l:   .res 2
ph_k0h_h:   .res 2
ph_mass_l:  .res 2
ph_mass_h:  .res 2
ph_hpm_l:   .res 2
ph_hpm_h:   .res 2
ph_teff_l:  .res 2
ph_teff_h:  .res 2
ph_srate:   .res 2
ph_nos_add: .res 2
ph_nos_fr:  .res 2
ph_shf_fr:  .res 2
ph_tl:      .res 2          ; turbo level
ph_rs_l:    .res 16         ; [car*8 + gear]
ph_rs_h:    .res 16
ph_kg_l:    .res 16
ph_kg_h:    .res 16
ph_curve:   .res 96         ; [car*48 + bucket]
ph_bcurve:  .res 96
; per-frame scratch
ph_tq:      .res 2
ph_drive:   .res 2
ph_acc:     .res 2
ph_res:     .res 2
ph_tgt:     .res 2
ph_cb:      .res 1          ; car*48
ph_shape:   .res 1
ph_boost:   .res 1
ph_tstart:  .res 1

.segment "FIXED"

; ---------------------------------------------------------------------------
; phys_setup: X = car, ptr0 = car record
; ---------------------------------------------------------------------------
phys_setup:
        stx cx
        ldy #CR_MODEL
        lda (ptr0),y
        sta ph_model,x
        tay
        lda car_ngears,y
        sta ph_ngears,x
        lda car_curve,y
        sta ph_shape            ; curve index for now

        ; hpm = 256 + sum(hp_bonus[p] * level[p])
        lda #0
        sta tmp2
        lda #1
        sta tmp3
        ldy #0
@hp:    sty tmp4
        lda hp_bonus,y
        beq @hpn
        sta m_b
        tya
        clc
        adc #CR_PARTS
        tay
        lda (ptr0),y
        sta m_a
        jsr mul8
        clc
        lda tmp2
        adc m_r
        sta tmp2
        lda tmp3
        adc m_r+1
        sta tmp3
@hpn:   ldy tmp4
        iny
        cpy #NPARTS
        bne @hp
        ldx cx
        lda tmp2
        sta ph_hpm_l,x
        lda tmp3
        sta ph_hpm_h,x

        ; teff = torque * hpm >> 8
        ldy ph_model,x
        lda car_torque_l,y
        sta m_a
        lda car_torque_h,y
        sta m_a+1
        lda tmp2
        sta m_b
        lda tmp3
        sta m_b+1
        jsr mul16
        ldx cx
        lda m_r+1
        sta ph_teff_l,x
        lda m_r+2
        sta ph_teff_h,x

        ; redline = base + 200*ecu, limiter = redline + 200
        ldy #CR_PARTS+P_ECU
        lda (ptr0),y
        sta m_a
        lda #200
        sta m_b
        jsr mul8
        ldx cx
        ldy ph_model,x
        clc
        lda car_redline_l,y
        adc m_r
        sta ph_redl_l,x
        lda car_redline_h,y
        adc m_r+1
        sta ph_redl_h,x
        clc
        lda ph_redl_l,x
        adc #200
        sta ph_lim_l,x
        lda ph_redl_h,x
        adc #0
        sta ph_lim_h,x

        ; mass = mass * (256 - 10*weight) >> 8
        ldy #CR_PARTS+P_WEIGHT
        lda (ptr0),y
        sta m_a
        lda #10
        sta m_b
        jsr mul8
        sec
        lda #0
        sbc m_r
        sta m_b
        lda #1
        sbc m_r+1
        sta m_b+1
        ldx cx
        ldy ph_model,x
        lda car_mass_l,y
        sta m_a
        lda car_mass_h,y
        sta m_a+1
        jsr mul16
        ldx cx
        lda m_r+1
        sta ph_mass_l,x
        lda m_r+2
        sta ph_mass_h,x

        ; k0h = teff * 24849 / mass
        lda ph_teff_l,x
        sta m_a
        lda ph_teff_h,x
        sta m_a+1
        lda #<24849
        sta m_b
        lda #>24849
        sta m_b+1
        jsr mul16
        ldx cx
        lda ph_mass_l,x
        sta m_b
        lda ph_mass_h,x
        sta m_b+1
        jsr div32
        ldx cx
        lda m_r
        sta ph_k0h_l,x
        lda m_r+1
        sta ph_k0h_h,x

        ; turbo / nitrous / gearbox tables
        ldy #CR_PARTS+P_TURBO
        lda (ptr0),y
        sta ph_tl,x
        tay
        lda turbo_boost,y
        sta ph_boost
        lda turbo_start,y
        sta ph_tstart
        lda turbo_rate,y
        sta ph_srate,x
        ldy #CR_PARTS+P_NITROUS
        lda (ptr0),y
        tay
        lda nos_add_tab,y
        sta ph_nos_add,x
        lda nos_frames_tab,y
        sta ph_nos_fr,x
        ldy #CR_PARTS+P_GEARBOX
        lda (ptr0),y
        tay
        lda shift_frames_tab,y
        sta ph_shf_fr,x

        ; torque curve stretched over this redline
        txa
        beq :+
        lda #48
:       sta ph_cb
        lda ph_shape
        sta m_a
        lda #41
        sta m_b
        jsr mul8
        clc
        lda m_r
        adc #<curve_shapes
        sta ptr2
        lda m_r+1
        adc #>curve_shapes
        sta ptr2+1
        lda #0
        sta tmp5                ; bucket b
@cv:    ; idx = min(40, (b*8192 + 4096) / redline)
        lda #0
        sta m_r
        lda tmp5
        asl a
        asl a
        asl a
        asl a
        asl a
        ora #$10
        sta m_r+1
        lda tmp5
        lsr a
        lsr a
        lsr a
        sta m_r+2
        lda #0
        sta m_r+3
        ldx cx
        lda ph_redl_l,x
        sta m_b
        lda ph_redl_h,x
        sta m_b+1
        jsr div32
        lda m_r+1
        bne @cap
        lda m_r
        cmp #41
        bcc @idx
@cap:   lda #40
@idx:   sta tmp6                ; idx
        tay
        lda (ptr2),y
        sta tmp7                ; v
        lda tmp5
        clc
        adc ph_cb
        tax
        lda tmp7
        sta ph_curve,x
        ; boost
        lda #0
        sta ph_bcurve,x
        lda ph_boost
        beq @nb
        lda tmp6
        sec
        sbc ph_tstart
        bcc @nb
        cmp #6
        bcc :+
        lda #6
:       sta tmp4                ; ramp
        lda tmp7
        sta m_a
        lda ph_boost
        sta m_b
        jsr mul8                ; v*boost -> m_r+1 = (v*boost)>>8
        lda m_r+1
        sta m_a
        lda tmp4
        sta m_b
        jsr mul8                ; * ramp
        lda #6
        jsr div16_8
        lda tmp5
        clc
        adc ph_cb
        tax
        lda m_r
        sta ph_bcurve,x
@nb:    inc tmp5
        lda tmp5
        cmp #48
        jne @cv

        ; gearing: r = gear*final >> 8 ; rs = r*447 >> 8 ; kg = k0h*r >> 15
        lda #1
        sta tmp5
@gear:  lda tmp5
        sec
        sbc #1
        asl a
        clc
        adc #CR_GEARS
        tay
        lda (ptr0),y
        sta m_a
        iny
        lda (ptr0),y
        sta m_a+1
        ldy #CR_FINAL
        lda (ptr0),y
        sta m_b
        iny
        lda (ptr0),y
        sta m_b+1
        jsr mul16
        lda m_r+1
        sta tmp2                ; r lo
        sta m_a
        lda m_r+2
        sta tmp3                ; r hi
        sta m_a+1
        lda #<447
        sta m_b
        lda #>447
        sta m_b+1
        jsr mul16
        lda cx
        asl a
        asl a
        asl a
        ora tmp5
        tax
        lda m_r+1
        sta ph_rs_l,x
        lda m_r+2
        sta ph_rs_h,x
        lda tmp2
        sta m_a
        lda tmp3
        sta m_a+1
        ldx cx
        lda ph_k0h_l,x
        sta m_b
        lda ph_k0h_h,x
        sta m_b+1
        jsr mul16
        asl m_r+1               ; >> 15 = << 1 then take bytes 2..3
        rol m_r+2
        rol m_r+3
        lda cx
        asl a
        asl a
        asl a
        ora tmp5
        tax
        lda m_r+2
        sta ph_kg_l,x
        lda m_r+3
        sta ph_kg_h,x
        ldx cx
        lda tmp5
        cmp ph_ngears,x
        inc tmp5
        jcc @gear

        ; traction = (grip * df) * 457 >> 14
        ldy #CR_PARTS+P_SUSP
        lda (ptr0),y
        asl a
        asl a
        sta tmp2
        ldy #CR_PARTS+P_TIRES
        lda (ptr0),y
        tay
        lda tire_grip,y
        clc
        adc tmp2
        sta m_a
        lda #0
        sta m_a+1
        ldx cx
        ldy ph_model,x
        lda car_drive,y
        tay
        lda drive_factor_l,y
        sta m_b
        lda drive_factor_h,y
        sta m_b+1
        jsr mul16
        lda m_r
        sta m_a
        lda m_r+1
        sta m_a+1
        lda #<457
        sta m_b
        lda #>457
        sta m_b+1
        jsr mul16
        asl m_r+1               ; >> 14 = << 2, bytes 2..3
        rol m_r+2
        rol m_r+3
        asl m_r+1
        rol m_r+2
        rol m_r+3
        ldx cx
        lda m_r+2
        sta ph_trac_l,x
        lda m_r+3
        sta ph_trac_h,x
        ; trac_k = trac - trac>>2 - trac>>4
        lda m_r+3
        sta tmp3
        lda m_r+2
        sta tmp2
        lsr tmp3
        ror tmp2
        lsr tmp3
        ror tmp2                ; trac>>2
        sec
        lda ph_trac_l,x
        sbc tmp2
        sta ph_tk_l,x
        lda ph_trac_h,x
        sbc tmp3
        sta ph_tk_h,x
        lsr tmp3
        ror tmp2
        lsr tmp3
        ror tmp2                ; trac>>4
        sec
        lda ph_tk_l,x
        sbc tmp2
        sta ph_tk_l,x
        lda ph_tk_h,x
        sbc tmp3
        sta ph_tk_h,x

        ; dk = 9828 * cda / mass
        ldy ph_model,x
        lda car_cda,y
        sta m_a
        lda #0
        sta m_a+1
        lda #<9828
        sta m_b
        lda #>9828
        sta m_b+1
        jsr mul16
        ldx cx
        lda ph_mass_l,x
        sta m_b
        lda ph_mass_h,x
        sta m_b+1
        jsr div32
        ldx cx
        lda m_r
        sta ph_dk_l,x
        lda m_r+1
        sta ph_dk_h,x
        ; fall through
; ---------------------------------------------------------------------------
; phys_reset: X = car.  Back to the start line, idle, neutral.
; ---------------------------------------------------------------------------
phys_reset:
        lda #0
        sta ph_v0,x
        sta ph_v1,x
        sta ph_v2,x
        sta ph_w0,x
        sta ph_w1,x
        sta ph_w2,x
        sta ph_p0,x
        sta ph_p1,x
        sta ph_p2,x
        sta ph_gear,x
        sta ph_shift_t,x
        sta ph_spool,x
        sta ph_nos_t,x
        sta ph_nos_on,x
        sta ph_spin,x
        sta ph_slip,x
        sta ph_thr,x
        lda #<IDLE_RPM
        sta ph_rpm_l,x
        lda #>IDLE_RPM
        sta ph_rpm_h,x
        rts

; ---------------------------------------------------------------------------
; wheel_rpm: X = car -> ph_tgt = min(65535, (wv>>8) * rs[gear] >> 8)
; ---------------------------------------------------------------------------
wheel_rpm:
        lda ph_w1,x
        sta m_a
        lda ph_w2,x
        sta m_a+1
        txa
        asl a
        asl a
        asl a
        ora ph_gear,x
        tay
        lda ph_rs_l,y
        sta m_b
        lda ph_rs_h,y
        sta m_b+1
        jsr mul16
        ldx cx
        lda m_r+3
        bne @max
        lda m_r+1
        sta ph_tgt
        lda m_r+2
        sta ph_tgt+1
        rts
@max:   lda #$FF
        sta ph_tgt
        sta ph_tgt+1
        rts

; ---------------------------------------------------------------------------
; phys_step: advance car X by one frame
; ---------------------------------------------------------------------------
phys_step:
        stx cx
        txa
        beq :+
        lda #48
:       sta ph_cb
        ; --- torque fraction ------------------------------------------------
        lda #0
        sta ph_tq
        sta ph_tq+1
        sta ph_drive
        sta ph_drive+1
        lda ph_thr,x
        beq @tqdone
        jsr bucket              ; Y = car*48 + min(47, rpm>>8)
        lda ph_bcurve,y
        sta m_a
        lda ph_spool,x
        sta m_b
        sty tmp0
        jsr mul8
        ldy tmp0
        ldx cx
        clc
        lda ph_curve,y
        adc m_r+1
        sta ph_tq
        lda #0
        adc #0
        sta ph_tq+1
        lda ph_nos_on,x
        beq @tqdone
        ; tq += tq * nos_add >> 8
        lda ph_tq
        sta m_a
        lda ph_tq+1
        sta m_a+1
        lda ph_nos_add,x
        sta m_b
        lda #0
        sta m_b+1
        jsr mul16
        ldx cx
        clc
        lda ph_tq
        adc m_r+1
        sta ph_tq
        lda ph_tq+1
        adc m_r+2
        sta ph_tq+1
@tqdone:
        ; nitrous timer
        lda ph_nos_on,x
        beq @nonos
        dec ph_nos_t,x
        bne @nonos
        lda #0
        sta ph_nos_on,x
        lda #1
        sta ph_nos_t,x
@nonos:
        ; limiter: rpm >= limiter -> no torque
        jsr at_limiter
        bcc :+
        lda #0
        sta ph_tq
        sta ph_tq+1
:
        ; --- drivetrain -----------------------------------------------------
        lda ph_gear,x
        bne @ingear
        ; neutral: free revving
        lda ph_thr,x
        beq @nthr
        jsr at_limiter
        bcs @bounce
        lda ph_tq+1
        lsr a
        sta tmp1
        lda ph_tq
        ror a
        clc
        adc ph_rpm_l,x
        sta ph_rpm_l,x
        lda tmp1
        adc ph_rpm_h,x
        sta ph_rpm_h,x
        jmp @resist
@nthr:  jsr at_limiter
        bcc @fall
@bounce:
        sec
        lda ph_rpm_l,x
        sbc #<400
        sta ph_rpm_l,x
        lda ph_rpm_h,x
        sbc #>400
        sta ph_rpm_h,x
        jmp @resist
@fall:  sec
        lda ph_rpm_l,x
        sbc #120
        sta tmp0
        lda ph_rpm_h,x
        sbc #0
        sta tmp1
        jsr clamp_idle
        jmp @resist

@ingear:
        lda ph_shift_t,x
        beq @engaged
        ; shifting: rpm moves a quarter of the way to the wheel rpm
        dec ph_shift_t,x
        jsr wheel_rpm
        sec
        lda ph_tgt
        sbc ph_rpm_l,x
        sta tmp0
        lda ph_tgt+1
        sbc ph_rpm_h,x
        sta tmp1
        jsr sdiff_asr2
        clc
        lda ph_rpm_l,x
        adc tmp0
        sta ph_rpm_l,x
        lda ph_rpm_h,x
        adc tmp1
        sta ph_rpm_h,x
        lda ph_shift_t,x
        bne @resist
        jsr slip_check
        jmp @resist

@engaged:
        lda ph_slip,x
        beq @locked
        jsr wheel_rpm
        ; diff = rpm - wheel_rpm  (rpm >= wheel_rpm expected while slipping)
        sec
        lda ph_rpm_l,x
        sbc ph_tgt
        sta tmp0
        lda ph_rpm_h,x
        sbc ph_tgt+1
        sta tmp1
        bcc @unslip             ; negative
        bne @slipping           ; >= 256
        lda tmp0
        cmp #200
        bcs @slipping
@unslip:
        lda #0
        sta ph_slip,x
        jmp @locked
@slipping:
        lda ph_thr,x
        beq @slipoff
        ; drive = (tq + diff>>5) * kg >> 8
        ldy #5
:       lsr tmp1
        ror tmp0
        dey
        bne :-
        clc
        lda ph_tq
        adc tmp0
        sta m_a
        lda ph_tq+1
        adc tmp1
        sta m_a+1
        jsr drive_mul
        lda #24
        bne @slipdrop
@slipoff:
        lda #80
@slipdrop:
        sta tmp0
        sec
        lda ph_rpm_l,x
        sbc tmp0
        sta ph_rpm_l,x
        lda ph_rpm_h,x
        sbc #0
        sta ph_rpm_h,x
        jmp @resist
@locked:
        lda ph_tq
        sta m_a
        lda ph_tq+1
        sta m_a+1
        jsr drive_mul

        ; --- resistance -------------------------------------------------------
@resist:
        ; s = (v >> 12) & $FF
        lda ph_v2,x
        asl a
        asl a
        asl a
        asl a
        sta tmp0
        lda ph_v1,x
        lsr a
        lsr a
        lsr a
        lsr a
        ora tmp0
        sta m_a
        sta m_b
        jsr mul8
        lda m_r
        sta m_a
        lda m_r+1
        sta m_a+1
        ldx cx
        lda ph_dk_l,x
        sta m_b
        lda ph_dk_h,x
        sta m_b+1
        jsr mul16
        ldx cx
        clc
        lda m_r+2
        adc #9                  ; rolling resistance
        sta ph_res
        lda m_r+3
        adc #0
        sta ph_res+1
        lda ph_thr,x
        bne :+
        lda ph_gear,x
        beq :+
        clc
        lda ph_res
        adc #20
        sta ph_res
        bcc :+
        inc ph_res+1
:
        ; --- traction ---------------------------------------------------------
        lda ph_spin,x
        bne @spinning
        ; drive > trac ?
        lda ph_trac_l,x
        cmp ph_drive
        lda ph_trac_h,x
        sbc ph_drive+1
        bcs @grip
        lda #1
        sta ph_spin,x
@spinning:
        lda ph_tk_l,x
        sta ph_acc
        lda ph_tk_h,x
        sta ph_acc+1
        ; wv += (drive - trac_k) * 2   (signed)
        sec
        lda ph_drive
        sbc ph_tk_l,x
        sta tmp0
        lda ph_drive+1
        sbc ph_tk_h,x
        sta tmp1
        lda #0
        sbc #0                  ; $FF if negative
        sta tmp2
        asl tmp0
        rol tmp1
        rol tmp2
        clc
        lda ph_w0,x
        adc tmp0
        sta ph_w0,x
        lda ph_w1,x
        adc tmp1
        sta ph_w1,x
        lda ph_w2,x
        adc tmp2
        sta ph_w2,x
        ; result negative?  (adding a negative that underflows)
        lda tmp2
        bpl @wpos
        bcs @wpos               ; no borrow: still positive
        lda #0
        sta ph_w0,x
        sta ph_w1,x
        sta ph_w2,x
@wpos:  ; wv <= v -> stop spinning
        lda ph_v0,x
        cmp ph_w0,x
        lda ph_v1,x
        sbc ph_w1,x
        lda ph_v2,x
        sbc ph_w2,x
        bcc @move               ; v < wv: keep spinning
        lda #0
        sta ph_spin,x
        jmp @move
@grip:  lda ph_drive
        sta ph_acc
        lda ph_drive+1
        sta ph_acc+1

        ; --- move ---------------------------------------------------------------
@move:  ; v = max(0, v + acc - resist)
        clc
        lda ph_v0,x
        adc ph_acc
        sta ph_v0,x
        lda ph_v1,x
        adc ph_acc+1
        sta ph_v1,x
        lda ph_v2,x
        adc #0
        sta ph_v2,x
        sec
        lda ph_v0,x
        sbc ph_res
        sta ph_v0,x
        lda ph_v1,x
        sbc ph_res+1
        sta ph_v1,x
        lda ph_v2,x
        sbc #0
        sta ph_v2,x
        bcs :+
        lda #0
        sta ph_v0,x
        sta ph_v1,x
        sta ph_v2,x
:       lda ph_spin,x
        bne :+
        lda ph_v0,x
        sta ph_w0,x
        lda ph_v1,x
        sta ph_w1,x
        lda ph_v2,x
        sta ph_w2,x
:       ; pos += v >> 8
        clc
        lda ph_p0,x
        adc ph_v1,x
        sta ph_p0,x
        lda ph_p1,x
        adc ph_v2,x
        sta ph_p1,x
        lda ph_p2,x
        adc #0
        sta ph_p2,x
        ; engine follows the wheels when engaged
        lda ph_gear,x
        beq @spool
        lda ph_shift_t,x
        bne @spool
        lda ph_slip,x
        bne @spool
        jsr wheel_rpm
        lda ph_tgt
        sta tmp0
        lda ph_tgt+1
        sta tmp1
        jsr clamp_idle

        ; --- turbo spool --------------------------------------------------------
@spool: lda ph_srate,x
        beq @sdec
        lda ph_thr,x
        beq @sdec
        jsr bucket
        lda ph_bcurve,y
        beq @sdec
        clc
        lda ph_spool,x
        adc ph_srate,x
        bcc :+
        lda #255
:       sta ph_spool,x
        rts
@sdec:  lda ph_spool,x
        sec
        sbc #8
        bcs :+
        lda #0
:       sta ph_spool,x
        rts

; drive = m_a(16) * kg[gear] >> 8 (saturating)
drive_mul:
        txa
        asl a
        asl a
        asl a
        ora ph_gear,x
        tay
        lda ph_kg_l,y
        sta m_b
        lda ph_kg_h,y
        sta m_b+1
        jsr mul16
        ldx cx
        lda m_r+3
        bne @sat
        lda m_r+1
        sta ph_drive
        lda m_r+2
        sta ph_drive+1
        rts
@sat:   lda #$FF
        sta ph_drive
        sta ph_drive+1
        rts

; bucket: Y = car*48 + min(47, rpm>>8)
bucket:
        lda ph_rpm_h,x
        cmp #47
        bcc :+
        lda #47
:       clc
        adc ph_cb
        tay
        rts

; at_limiter: carry set if rpm >= limiter
at_limiter:
        lda ph_rpm_l,x
        cmp ph_lim_l,x
        lda ph_rpm_h,x
        sbc ph_lim_h,x
        rts

; clamp_idle: rpm = max(IDLE, tmp1:tmp0)
clamp_idle:
        lda tmp0
        cmp #<IDLE_RPM
        lda tmp1
        sbc #>IDLE_RPM
        bcc @idle
        lda tmp0
        sta ph_rpm_l,x
        lda tmp1
        sta ph_rpm_h,x
        rts
@idle:  lda #<IDLE_RPM
        sta ph_rpm_l,x
        lda #>IDLE_RPM
        sta ph_rpm_h,x
        rts

; sdiff_asr2: arithmetic shift right by 2 of the signed 16-bit tmp1:tmp0
; (rpm differences always fit in 16 signed bits)
sdiff_asr2:
        lda tmp1
        cmp #$80
        ror tmp1
        ror tmp0
        lda tmp1
        cmp #$80
        ror tmp1
        ror tmp0
        rts

; slip_check: after a shift, slip = rpm > wheel_rpm + 200
slip_check:
        jsr wheel_rpm
        clc
        lda ph_tgt
        adc #200
        sta tmp0
        lda ph_tgt+1
        adc #0
        sta tmp1
        bcs @no                 ; overflow: can't be above
        lda tmp0
        cmp ph_rpm_l,x
        lda tmp1
        sbc ph_rpm_h,x
        bcs @no                 ; tgt+200 >= rpm
        lda #1
        sta ph_slip,x
        rts
@no:    lda #0
        sta ph_slip,x
        rts

; ---------------------------------------------------------------------------
; Controls.  X = car.
; ---------------------------------------------------------------------------
; phys_shift_up: carry set if a shift happened
phys_shift_up:
        stx cx
        lda ph_shift_t,x
        bne @no
        lda ph_gear,x
        cmp ph_ngears,x
        bcs @no
        lda ph_gear,x
        bne @up
        lda #1
        sta ph_gear,x
        jsr slip_check
        sec
        rts
@up:    inc ph_gear,x
        lda ph_shf_fr,x
        sta ph_shift_t,x
        lda ph_spool,x
        cmp #129
        bcc @ok
        sta m_a                 ; spool = spool*3 >> 2
        lda #3
        sta m_b
        jsr mul8
        ldx cx
        lsr m_r+1
        ror m_r
        lsr m_r+1
        ror m_r
        lda m_r
        sta ph_spool,x
@ok:    sec
        rts
@no:    clc
        rts

; phys_shift_down: carry set if shifted
phys_shift_down:
        stx cx
        lda ph_shift_t,x
        bne @no
        lda ph_gear,x
        cmp #2
        bcc @no
        dec ph_gear,x
        lda ph_shf_fr,x
        sta ph_shift_t,x
        sec
        rts
@no:    clc
        rts

; phys_nitrous: fire the bottle if there is one.  Carry set if fired.
phys_nitrous:
        lda ph_nos_fr,x
        beq @no
        lda ph_nos_on,x
        bne @no
        lda ph_nos_t,x
        bne @no
        lda #1
        sta ph_nos_on,x
        lda ph_nos_fr,x
        sta ph_nos_t,x
        sec
        rts
@no:    clc
        rts

; ---------------------------------------------------------------------------
; Readouts
; ---------------------------------------------------------------------------
; phys_speed: X = car -> A = mph (or km/h if the option is set)
phys_speed:
        stx cx
        lda ph_v1,x
        sta m_a
        lda ph_v2,x
        sta m_a+1
        lda SV_OPTIONS
        and #OPT_KMH
        beq :+
        lda #55-34
:       clc
        adc #34
        sta m_b
        lda #0
        sta m_b+1
        jsr mul16
        ldx cx
        lda m_r+2
        bne @max
        lda m_r+1
        rts
@max:   lda #255
        rts

; phys_best_launch: X = car -> tmp2/tmp3 = launch rpm for the AI
; target = trac*256/kg[1]; best rpm in 1500..redline step 128 with
; curve[b] + rpm>>5 <= target + target>>4
phys_best_launch:
        stx cx
        txa
        beq :+
        lda #48
:       sta ph_cb
        lda #0
        sta m_r
        lda ph_trac_l,x
        sta m_r+1
        lda ph_trac_h,x
        sta m_r+2
        lda #0
        sta m_r+3
        txa
        asl a
        asl a
        asl a
        ora #1
        tay
        lda ph_kg_l,y
        sta m_b
        lda ph_kg_h,y
        sta m_b+1
        jsr div32
        ldx cx
        lda m_r+2
        ora m_r+3
        beq :+
        lda #$FF
        sta m_r
        sta m_r+1
:       ; limit = target + target>>4
        lda m_r+1
        sta tmp1
        lda m_r
        sta tmp0
        ldy #4
:       lsr tmp1
        ror tmp0
        dey
        bne :-
        clc
        lda m_r
        adc tmp0
        sta ptr2
        lda m_r+1
        adc tmp1
        sta ptr2+1
        bcc :+
        lda #$FF
        sta ptr2
        sta ptr2+1
:       lda #<2000
        sta tmp2
        lda #>2000
        sta tmp3
        lda #<1500
        sta tmp4
        lda #>1500
        sta tmp5
@l:     ; while rpm < redline
        lda tmp4
        cmp ph_redl_l,x
        lda tmp5
        sbc ph_redl_h,x
        bcs @done
        ; value = curve[min(47,rpm>>8)] + rpm>>5
        lda tmp5
        cmp #47
        bcc :+
        lda #47
:       clc
        adc ph_cb
        tay
        lda tmp5
        sta tmp1
        lda tmp4
        sta tmp0
        lsr tmp1
        ror tmp0
        lsr tmp1
        ror tmp0
        lsr tmp1
        ror tmp0
        lsr tmp1
        ror tmp0
        lsr tmp1
        ror tmp0
        clc
        lda ph_curve,y
        adc tmp0
        sta tmp0
        lda tmp1
        adc #0
        sta tmp1
        ; <= limit ?
        lda ptr2
        cmp tmp0
        lda ptr2+1
        sbc tmp1
        bcc @next
        lda tmp4
        sta tmp2
        lda tmp5
        sta tmp3
@next:  clc
        lda tmp4
        adc #128
        sta tmp4
        bcc @l
        inc tmp5
        jmp @l
@done:  rts

; phys_peak_hp: X = car -> m_a(16) = displayed peak horsepower
;   hp * (hpm + boost_peak) >> 8 where boost adds turbo_boost[level]
phys_peak_hp:
        stx cx
        ldy ph_tl,x
        clc
        lda ph_hpm_l,x
        adc turbo_boost,y
        sta m_b
        lda ph_hpm_h,x
        adc #0
        sta m_b+1
        ldy ph_model,x
        lda car_hp_l,y
        sta m_a
        lda car_hp_h,y
        sta m_a+1
        jsr mul16
        ldx cx
        lda m_r+1
        sta m_a
        lda m_r+2
        sta m_a+1
        rts
