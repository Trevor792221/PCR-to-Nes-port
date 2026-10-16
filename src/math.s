; ===========================================================================
; math.s -- multiply, divide, number formatting (fixed bank)
; ===========================================================================

; mul8: m_r(16) = m_a(8) * m_b(8), quarter squares (~50 cycles).
; Leaves m_a and m_b.  Uses X.
mul8:
        lda m_a
        clc
        adc m_b
        tax
        bcs @hi
        lda sqr_lo,x
        sta m_r
        lda sqr_hi,x
        sta m_r+1
        jmp @diff
@hi:    lda sqr2_lo,x
        sta m_r
        lda sqr2_hi,x
        sta m_r+1
@diff:  lda m_a
        sec
        sbc m_b
        bcs @pos
        eor #$FF
        adc #1                  ; carry is clear here
@pos:   tax
        sec
        lda m_r
        sbc sqr_lo,x
        sta m_r
        lda m_r+1
        sbc sqr_hi,x
        sta m_r+1
        rts

; mul16: m_r(32) = m_a(16) * m_b(16) from four 8x8 products.
; Leaves m_a and m_b.  Uses X and mul_t.
mul16:
        ; lo*lo
        lda m_a
        sta mul_x
        lda m_b
        sta mul_y
        jsr mul8q
        lda mul_r
        sta m_r
        lda mul_r+1
        sta m_r+1
        ; hi*hi
        lda m_a+1
        sta mul_x
        lda m_b+1
        sta mul_y
        jsr mul8q
        lda mul_r
        sta m_r+2
        lda mul_r+1
        sta m_r+3
        ; lo(a)*hi(b)
        lda m_a
        sta mul_x
        jsr mul8q               ; mul_y still = hi(b)
        clc
        lda mul_r
        adc m_r+1
        sta m_r+1
        lda mul_r+1
        adc m_r+2
        sta m_r+2
        bcc :+
        inc m_r+3
:       ; hi(a)*lo(b)
        lda m_a+1
        sta mul_x
        lda m_b
        sta mul_y
        jsr mul8q
        clc
        lda mul_r
        adc m_r+1
        sta m_r+1
        lda mul_r+1
        adc m_r+2
        sta m_r+2
        bcc :+
        inc m_r+3
:       rts

; mul8q: mul_r = mul_x * mul_y (internal helper for mul16)
mul8q:
        lda mul_x
        clc
        adc mul_y
        tax
        bcs @hi
        lda sqr_lo,x
        sta mul_r
        lda sqr_hi,x
        sta mul_r+1
        jmp @diff
@hi:    lda sqr2_lo,x
        sta mul_r
        lda sqr2_hi,x
        sta mul_r+1
@diff:  lda mul_x
        sec
        sbc mul_y
        bcs @pos
        eor #$FF
        adc #1
@pos:   tax
        sec
        lda mul_r
        sbc sqr_lo,x
        sta mul_r
        lda mul_r+1
        sbc sqr_hi,x
        sta mul_r+1
        rts

; div32: m_r(32) = m_r(32) / m_b(16), remainder in m_a(16).
div32:
        lda #0
        sta m_a
        sta m_a+1
        ldx #32
@l:     asl m_r
        rol m_r+1
        rol m_r+2
        rol m_r+3
        rol m_a
        rol m_a+1
        bcs @sub
        lda m_a
        cmp m_b
        lda m_a+1
        sbc m_b+1
        bcc @next
@sub:   lda m_a
        sec
        sbc m_b
        sta m_a
        lda m_a+1
        sbc m_b+1
        sta m_a+1
        inc m_r
@next:  dex
        bne @l
        rts

; div16_8: m_r(16) / A -> m_r(16), remainder A.  (simple helper)
div16_8:
        sta m_b
        lda #0
        sta m_b+1
        sta m_r+2
        sta m_r+3
        jsr div32
        lda m_a
        rts

; ---------------------------------------------------------------------------
; Decimal formatting.  fmt_u24: m_a(24) -> numbuf[0..7], right aligned,
; space padded, zero terminated at numbuf+8.  Returns X = index of the first
; digit.  fmt_u16 uses m_a(16).
; ---------------------------------------------------------------------------
fmt_u16:
        lda #0
        sta m_a+2
fmt_u24:
        ldy #7
@digit: lda #0
        sta tmp0
        ldx #24
@bit:   asl m_a
        rol m_a+1
        rol m_a+2
        rol tmp0
        lda tmp0
        cmp #10
        bcc @nb
        sbc #10
        sta tmp0
        inc m_a
@nb:    dex
        bne @bit
        lda tmp0
        ora #'0'
        sta numbuf,y
        dey
        bmi @end
        lda m_a
        ora m_a+1
        ora m_a+2
        bne @digit
@sp:    lda #' '
        sta numbuf,y
        dey
        bpl @sp
@end:   lda #0
        sta numbuf+8
        ldx #0
@first: lda numbuf,x
        cmp #' '
        bne @ret
        inx
        cpx #7
        bne @first
@ret:   rts

; fmt_8: A -> numbuf (same as fmt_u16)
fmt_8:
        sta m_a
        lda #0
        sta m_a+1
        jmp fmt_u16

; fmt_ms: m_a(16) milliseconds -> numbuf "SS.mmm" style text in numbuf+0..
; as "%2d.%03d" (6 chars + terminator).
fmt_ms:
        lda m_a
        sta m_r
        lda m_a+1
        sta m_r+1
        lda #0
        sta m_r+2
        sta m_r+3
        lda #<1000
        sta m_b
        lda #>1000
        sta m_b+1
        jsr div32               ; m_r = seconds, m_a = ms
        lda m_a
        pha
        lda m_a+1
        pha
        lda m_r
        jsr fmt_8               ; seconds -> numbuf[6..7]
        lda numbuf+6
        sta numbuf+0
        lda numbuf+7
        sta numbuf+1
        lda #'.'
        sta numbuf+2
        pla
        sta m_a+1
        pla
        sta m_a
        lda #0
        sta m_a+2
        lda #0
        sta tmp1                ; three digits of ms
        ldy #5
@d:     lda #0
        sta tmp0
        ldx #16
@b:     asl m_a
        rol m_a+1
        rol tmp0
        lda tmp0
        cmp #10
        bcc :+
        sbc #10
        sta tmp0
        inc m_a
:       dex
        bne @b
        lda tmp0
        ora #'0'
        sta numbuf,y
        dey
        cpy #2
        bne @d
        lda #0
        sta numbuf+6
        rts

; ---------------------------------------------------------------------------
; 24-bit cash helpers.  cash_cmp: carry set if SV_CASH >= m_a(24).
; cash_sub: SV_CASH -= m_a.  cash_add: SV_CASH += m_a (saturates).
; ---------------------------------------------------------------------------
cash_cmp:
        lda SV_CASH
        cmp m_a
        lda SV_CASH+1
        sbc m_a+1
        lda SV_CASH+2
        sbc m_a+2
        rts

cash_sub:
        sec
        lda SV_CASH
        sbc m_a
        sta SV_CASH
        lda SV_CASH+1
        sbc m_a+1
        sta SV_CASH+1
        lda SV_CASH+2
        sbc m_a+2
        sta SV_CASH+2
        rts

cash_add:
        clc
        lda SV_CASH
        adc m_a
        sta SV_CASH
        lda SV_CASH+1
        adc m_a+1
        sta SV_CASH+1
        lda SV_CASH+2
        adc m_a+2
        sta SV_CASH+2
        bcc @ok
        lda #$FF
        sta SV_CASH
        sta SV_CASH+1
        sta SV_CASH+2
@ok:    rts
