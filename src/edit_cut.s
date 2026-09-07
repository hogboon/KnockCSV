; ------------------------------------------------------------
; edit_cut.s - KnockCSV EDIT.PRG
;
; Multicell CUT:
;   1. copies the complete selected rectangle to the same clipboard
;      used by Copy/Paste ($08500000)
;   2. rebuilds the CSV in $08600000 with the selected cells empty
;   3. copies the rebuilt CSV back to $08000000
;
; Selection bounds come from shared state $1F10..$1F15.
; CSV raw syntax, delimiters and row endings are preserved.
; ------------------------------------------------------------

    .public edit_cut_multicell
    .public edit_delete_multicell
    .extern edit_copy_multicell

OVL_SIZE0       .equ 0x1f02
OVL_SIZE1       .equ 0x1f03
OVL_SIZE2       .equ 0x1f04
OVL_SIZE3       .equ 0x1f05
OVL_DELIMITER   .equ 0x1f06
OVL_MINROW0     .equ 0x1f10
OVL_MINROW1     .equ 0x1f11
OVL_MAXROW0     .equ 0x1f12
OVL_MAXROW1     .equ 0x1f13
OVL_MINCOL      .equ 0x1f14
OVL_MAXCOL      .equ 0x1f15

SRC0            .equ 0x00
SRC1            .equ 0x00
SRC2            .equ 0x00
SRC3            .equ 0x08

TMP0            .equ 0x00
TMP1            .equ 0x00
TMP2            .equ 0x60
TMP3            .equ 0x08

    .section code,text

edit_cut_multicell:
    ; Preserve the selection in the normal multicell clipboard first.
    jsr edit_copy_multicell

edit_delete_multicell:
    ; DELETE enters here directly, so the clipboard is left untouched.

    ; Source pointer = $08000000.
    lda #SRC0
    sta edc_src0
    lda #SRC1
    sta edc_src1
    lda #SRC2
    sta edc_src2
    lda #SRC3
    sta edc_src3

    ; Source end = $08000000 + OVL_SIZE.
    clc
    lda #SRC0
    adc OVL_SIZE0
    sta edc_srcend0
    lda #SRC1
    adc OVL_SIZE1
    sta edc_srcend1
    lda #SRC2
    adc OVL_SIZE2
    sta edc_srcend2
    lda #SRC3
    adc OVL_SIZE3
    sta edc_srcend3

    ; Temp destination = $08600000.
    lda #TMP0
    sta edc_dst0
    lda #TMP1
    sta edc_dst1
    lda #TMP2
    sta edc_dst2
    lda #TMP3
    sta edc_dst3

    lda #0
    sta edc_row0
    sta edc_row1
    sta edc_col

edc_field_loop$:
    jsr edc_src_at_end
    bcc +
    jmp edc_rebuild_done$
+

    ; Selected field? Scan it but do not emit its raw contents.
    jsr edc_is_target
    bcc edc_copy_original$

    lda #0
    sta edc_copy_mode
    jsr edc_scan_field
    jmp edc_boundary$

edc_copy_original$:
    lda #1
    sta edc_copy_mode
    jsr edc_scan_field

edc_boundary$:
    ; Field scanner leaves src at delimiter/CR/LF or end.
    jsr edc_src_at_end
    bcc +
    jmp edc_field_loop$
+

    ldz #0
    lda [edc_src0],z
    cmp OVL_DELIMITER
    bne edc_boundary_cr$

    ; Preserve delimiter, even for an emptied cell.
    jsr edc_copy_src_byte
    inc edc_col
    jmp edc_field_loop$

edc_boundary_cr$:
    cmp #0x0d
    bne edc_boundary_lf$

    jsr edc_copy_src_byte
    jsr edc_src_at_end
    bcs edc_new_row$
    ldz #0
    lda [edc_src0],z
    cmp #0x0a
    bne edc_new_row$
    jsr edc_copy_src_byte
    jmp edc_new_row$

edc_boundary_lf$:
    cmp #0x0a
    bne edc_copy_weird_boundary$
    jsr edc_copy_src_byte
    jmp edc_new_row$

edc_copy_weird_boundary$:
    ; Defensive fallback.
    jsr edc_copy_src_byte
    jmp edc_field_loop$

edc_new_row$:
    lda #0
    sta edc_col
    inc edc_row0
    bne +
    inc edc_row1
+
    jmp edc_field_loop$

edc_rebuild_done$:
    ; Save temp end.
    lda edc_dst0
    sta edc_tempend0
    lda edc_dst1
    sta edc_tempend1
    lda edc_dst2
    sta edc_tempend2
    lda edc_dst3
    sta edc_tempend3

    ; New size = temp_end - $08600000.
    sec
    lda edc_tempend0
    sbc #TMP0
    sta OVL_SIZE0
    lda edc_tempend1
    sbc #TMP1
    sta OVL_SIZE1
    lda edc_tempend2
    sbc #TMP2
    sta OVL_SIZE2
    lda edc_tempend3
    sbc #TMP3
    sta OVL_SIZE3

    ; Copy rebuilt CSV back.
    lda #TMP0
    sta edc_src0
    lda #TMP1
    sta edc_src1
    lda #TMP2
    sta edc_src2
    lda #TMP3
    sta edc_src3

    lda #SRC0
    sta edc_dst0
    lda #SRC1
    sta edc_dst1
    lda #SRC2
    sta edc_dst2
    lda #SRC3
    sta edc_dst3

edc_copyback_loop$:
    lda edc_src3
    cmp edc_tempend3
    bne edc_copyback_byte$
    lda edc_src2
    cmp edc_tempend2
    bne edc_copyback_byte$
    lda edc_src1
    cmp edc_tempend1
    bne edc_copyback_byte$
    lda edc_src0
    cmp edc_tempend0
    beq edc_cut_ok$

edc_copyback_byte$:
    ldz #0
    lda [edc_src0],z
    sta [edc_dst0],z
    jsr edc_inc_src
    jsr edc_inc_dst
    jmp edc_copyback_loop$

edc_cut_ok$:
    rts

; ------------------------------------------------------------
; C=1 if current row/col lies inside selected rectangle.
; ------------------------------------------------------------
edc_is_target:
    ; row >= min row ?
    lda edc_row1
    cmp OVL_MINROW1
    bcc edc_not_target$
    bne edc_check_max_row$
    lda edc_row0
    cmp OVL_MINROW0
    bcc edc_not_target$

edc_check_max_row$:
    ; row <= max row ?
    lda edc_row1
    cmp OVL_MAXROW1
    bcc edc_check_col$
    bne edc_not_target$
    lda edc_row0
    cmp OVL_MAXROW0
    bcc edc_check_col$
    bne edc_not_target$

edc_check_col$:
    lda edc_col
    cmp OVL_MINCOL
    bcc edc_not_target$
    cmp OVL_MAXCOL
    bcc edc_target$
    beq edc_target$

edc_not_target$:
    clc
    rts
edc_target$:
    sec
    rts

; ------------------------------------------------------------
; Scan one raw field. Boundary itself is not consumed.
; edc_copy_mode=1 copies field bytes; 0 discards them.
; ------------------------------------------------------------
edc_scan_field:
    lda #0
    sta edc_in_quotes
    lda #1
    sta edc_field_start

edc_scan_loop$:
    jsr edc_src_at_end
    bcc +
    rts
+
    ldz #0
    lda [edc_src0],z
    sta edc_ch

    lda edc_in_quotes
    beq edc_scan_outside$

    lda edc_ch
    cmp #0x22
    bne edc_consume_field_byte$

    ; Consume quote.
    jsr edc_consume_byte
    jsr edc_src_at_end
    bcs edc_scan_quote_closed$

    ; Escaped doubled quote.
    ldz #0
    lda [edc_src0],z
    cmp #0x22
    bne edc_scan_quote_closed$
    jsr edc_consume_byte
    jmp edc_scan_loop$

edc_scan_quote_closed$:
    lda #0
    sta edc_in_quotes
    jmp edc_scan_loop$

edc_scan_outside$:
    lda edc_ch
    cmp #0x22
    bne edc_scan_check_boundary$
    lda edc_field_start
    beq edc_consume_field_byte$
    lda #1
    sta edc_in_quotes
    lda #0
    sta edc_field_start
    jsr edc_consume_byte
    jmp edc_scan_loop$

edc_scan_check_boundary$:
    lda edc_ch
    cmp OVL_DELIMITER
    beq edc_scan_done
    cmp #0x0d
    beq edc_scan_done
    cmp #0x0a
    beq edc_scan_done
    lda #0
    sta edc_field_start

edc_consume_field_byte$:
    jsr edc_consume_byte
    jmp edc_scan_loop$

edc_consume_byte:
    lda edc_copy_mode
    beq +
    ldz #0
    lda [edc_src0],z
    jsr edc_put_dst
+
    jsr edc_inc_src
    rts

edc_scan_done:
    rts

; ------------------------------------------------------------
; Helpers
; ------------------------------------------------------------

edc_src_at_end:
    lda edc_src3
    cmp edc_srcend3
    bcc edc_src_not_end$
    bne edc_src_end$
    lda edc_src2
    cmp edc_srcend2
    bcc edc_src_not_end$
    bne edc_src_end$
    lda edc_src1
    cmp edc_srcend1
    bcc edc_src_not_end$
    bne edc_src_end$
    lda edc_src0
    cmp edc_srcend0
    bcc edc_src_not_end$
edc_src_end$:
    sec
    rts
edc_src_not_end$:
    clc
    rts

edc_copy_src_byte:
    ldz #0
    lda [edc_src0],z
    jsr edc_put_dst
    jsr edc_inc_src
    rts

edc_put_dst:
    ; Temp rebuild must remain below $08700000.
    pha
    lda edc_dst3
    cmp #0x08
    bne edc_put_abort$
    lda edc_dst2
    cmp #0x70
    bcs edc_put_abort$
    pla
    ldz #0
    sta [edc_dst0],z
    jmp edc_inc_dst
edc_put_abort$:
    pla
    ; Force outer scan to finish instead of hanging.
    lda edc_srcend0
    sta edc_src0
    lda edc_srcend1
    sta edc_src1
    lda edc_srcend2
    sta edc_src2
    lda edc_srcend3
    sta edc_src3
    rts

edc_inc_src:
    inc edc_src0
    bne +
    inc edc_src1
    bne +
    inc edc_src2
    bne +
    inc edc_src3
+
    rts

edc_inc_dst:
    inc edc_dst0
    bne +
    inc edc_dst1
    bne +
    inc edc_dst2
    bne +
    inc edc_dst3
+
    rts

    .section zzpage,bss
edc_src0:       .space 1
edc_src1:       .space 1
edc_src2:       .space 1
edc_src3:       .space 1
edc_dst0:       .space 1
edc_dst1:       .space 1
edc_dst2:       .space 1
edc_dst3:       .space 1

    .section bss,bss
edc_srcend0:    .space 1
edc_srcend1:    .space 1
edc_srcend2:    .space 1
edc_srcend3:    .space 1
edc_tempend0:   .space 1
edc_tempend1:   .space 1
edc_tempend2:   .space 1
edc_tempend3:   .space 1
edc_row0:       .space 1
edc_row1:       .space 1
edc_col:        .space 1
edc_copy_mode:  .space 1
edc_in_quotes:  .space 1
edc_field_start:.space 1
edc_ch:         .space 1
