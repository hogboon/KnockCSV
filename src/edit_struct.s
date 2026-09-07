; ------------------------------------------------------------
; edit_struct.s - KnockCSV EDIT.PRG
;
; Structural operations handled entirely inside the overlay.
;
; Commands:
;   13 Insert Row Above
;   14 Insert Row Below
;   15 Delete Row(s)
;   16 Insert Column Left
;   17 Insert Column Right
;   18 Delete Column(s)
;
; CSV source: $08000000
; Temp rebuild: $08600000
; Shared state: $1F00..
; ------------------------------------------------------------

    .public edit_structure
    .extern busycursor_on
    .extern busycursor_off

OVL_COMMAND      .equ 0x1f01
OVL_SIZE0        .equ 0x1f02
OVL_SIZE1        .equ 0x1f03
OVL_SIZE2        .equ 0x1f04
OVL_SIZE3        .equ 0x1f05
OVL_DELIMITER    .equ 0x1f06
OVL_CURROW0      .equ 0x1f0a
OVL_CURROW1      .equ 0x1f0b
OVL_CURCOL       .equ 0x1f0c
OVL_MULTI_COUNT  .equ 0x1f0e
OVL_MULTI_MODE   .equ 0x1f0f
OVL_MINROW0      .equ 0x1f10
OVL_MINROW1      .equ 0x1f11
OVL_MAXROW0      .equ 0x1f12
OVL_MAXROW1      .equ 0x1f13
OVL_MINCOL       .equ 0x1f14
OVL_MAXCOL       .equ 0x1f15
OVL_ANCHOR_ROW0  .equ 0x1f18
OVL_ANCHOR_ROW1  .equ 0x1f19
OVL_ANCHOR_COL   .equ 0x1f1a
OVL_ROWS0        .equ 0x1f1b
OVL_ROWS1        .equ 0x1f1c
OVL_MAXCOLS0     .equ 0x1f1d
OVL_MAXCOLS1     .equ 0x1f1e

SRC0             .equ 0x00
SRC1             .equ 0x00
SRC2             .equ 0x00
SRC3             .equ 0x08
TMP0             .equ 0x00
TMP1             .equ 0x00
TMP2             .equ 0x60
TMP3             .equ 0x08

    .section code,text

edit_structure:
    jsr busycursor_on
    jsr edit_structure_impl
    jsr busycursor_off
    rts

edit_structure_impl:
    jsr es_init

    lda OVL_COMMAND
    cmp #13
    bne +
    jmp es_insert_row_above
+
    cmp #14
    bne +
    jmp es_insert_row_below
+
    cmp #15
    bne +
    jmp es_delete_rows
+
    cmp #16
    bne +
    jmp es_insert_col_left
+
    cmp #17
    bne +
    jmp es_insert_col_right
+
    cmp #18
    bne +
    jmp es_delete_cols
+
    rts

; ============================================================
; ROW INSERT
; ============================================================

es_insert_row_above:
    lda OVL_CURROW0
    sta es_target_row0
    lda OVL_CURROW1
    sta es_target_row1
    lda #0
    sta es_insert_after
    jmp es_rebuild_rows_insert

es_insert_row_below:
    lda OVL_CURROW0
    sta es_target_row0
    lda OVL_CURROW1
    sta es_target_row1
    lda #1
    sta es_insert_after

es_rebuild_rows_insert:
    lda #0
    sta es_row0
    sta es_row1

es_row_insert_loop:
    jsr es_src_at_end
    bcc +
    ; Empty/malformed file fallback: still create one row.
    lda es_row0
    ora es_row1
    bne es_row_insert_done
    jsr es_emit_empty_row
    jmp es_row_insert_done
+
    lda es_insert_after
    bne es_copy_insert_row
    jsr es_row_equals_target
    bcc es_copy_insert_row
    jsr es_emit_empty_row

es_copy_insert_row:
    jsr es_copy_one_row

    lda es_insert_after
    beq es_row_insert_advance
    jsr es_row_equals_target
    bcc es_row_insert_advance
    jsr es_emit_empty_row

es_row_insert_advance:
    inc es_row0
    bne +
    inc es_row1
+
    jsr es_src_at_end
    bcc es_row_insert_loop

    ; Insert below the final row is already handled after its copy.
    ; If the requested row was out of range, append one empty row.
    lda es_inserted
    bne es_row_insert_done
    jsr es_emit_empty_row

es_row_insert_done:
    ; Insert Above keeps current index on the new blank row.
    ; Insert Below selects the newly inserted row, matching old behavior.
    lda OVL_COMMAND
    cmp #14
    bne +
    clc
    lda OVL_CURROW0
    adc #1
    sta OVL_CURROW0
    lda OVL_CURROW1
    adc #0
    sta OVL_CURROW1
+
    jsr es_collapse_selection
    jmp es_finish

; C=1 if es_row == target row.
es_row_equals_target:
    lda es_row1
    cmp es_target_row1
    bne es_row_not_target
    lda es_row0
    cmp es_target_row0
    bne es_row_not_target
    sec
    rts
es_row_not_target:
    clc
    rts

es_emit_empty_row:
    lda #1
    sta es_inserted

    ; Existing code clamps rows wider than 255 columns to 255 fields.
    lda OVL_MAXCOLS1
    beq +
    lda #255
    jmp es_empty_count_ready
+
    lda OVL_MAXCOLS0
    bne es_empty_count_ready
    lda #1
es_empty_count_ready:
    sta es_tmp_count
    dec es_tmp_count
es_empty_delims:
    lda es_tmp_count
    beq es_empty_cr
    lda OVL_DELIMITER
    jsr es_put_dst
    dec es_tmp_count
    jmp es_empty_delims
es_empty_cr:
    lda #0x0d
    jmp es_put_dst

; Copy one complete logical CSV row, respecting quoted CR/LF.
es_copy_one_row:
    lda #0
    sta es_in_quotes
    sta es_field_start

es_copy_row_loop:
    jsr es_src_at_end
    bcc +
    rts
+
    ldz #0
    lda [es_src0],z
    sta es_ch

    lda es_in_quotes
    beq es_copy_row_outside

    lda es_ch
    jsr es_copy_src_byte
    cmp #0x22
    bne es_copy_row_loop

    ; quote inside quoted field: doubled quote stays inside quotes
    jsr es_src_at_end
    bcs es_quote_close
    ldz #0
    lda [es_src0],z
    cmp #0x22
    bne es_quote_close
    jsr es_copy_src_byte
    jmp es_copy_row_loop
es_quote_close:
    lda #0
    sta es_in_quotes
    jmp es_copy_row_loop

es_copy_row_outside:
    lda es_ch
    cmp #0x22
    bne es_copy_row_boundary
    lda #1
    sta es_in_quotes
    jsr es_copy_src_byte
    jmp es_copy_row_loop

es_copy_row_boundary:
    lda es_ch
    cmp #0x0d
    beq es_copy_row_cr
    cmp #0x0a
    beq es_copy_row_lf
    jsr es_copy_src_byte
    jmp es_copy_row_loop

es_copy_row_cr:
    jsr es_copy_src_byte
    jsr es_src_at_end
    bcs +
    ldz #0
    lda [es_src0],z
    cmp #0x0a
    bne +
    jsr es_copy_src_byte
+
    rts

es_copy_row_lf:
    jsr es_copy_src_byte
    rts

; ============================================================
; ROW DELETE
; ============================================================

es_delete_rows:
    ; Do not delete the only remaining row.
    lda OVL_ROWS1
    bne es_delete_rows_go
    lda OVL_ROWS0
    cmp #2
    bcs es_delete_rows_go
    rts

es_delete_rows_go:
    ; selected_count = max-min+1, clamped to rows-1.
    sec
    lda OVL_MAXROW0
    sbc OVL_MINROW0
    sta es_count0
    lda OVL_MAXROW1
    sbc OVL_MINROW1
    sta es_count1
    inc es_count0
    bne +
    inc es_count1
+
    ; max deletable = rows-1
    sec
    lda OVL_ROWS0
    sbc #1
    sta es_limit0
    lda OVL_ROWS1
    sbc #0
    sta es_limit1
    jsr es_count_min_limit

    lda #0
    sta es_row0
    sta es_row1

es_delete_rows_loop:
    jsr es_src_at_end
    bcs es_delete_rows_done

    jsr es_row_in_delete_window
    bcc es_delete_rows_copy
    ; skip row
    jsr es_skip_one_row
    jmp es_delete_rows_next

es_delete_rows_copy:
    jsr es_copy_one_row

es_delete_rows_next:
    inc es_row0
    bne +
    inc es_row1
+
    jmp es_delete_rows_loop

es_delete_rows_done:
    ; New current row = min selected, clamped to new last row.
    sec
    lda OVL_ROWS0
    sbc es_count0
    sta es_newrows0
    lda OVL_ROWS1
    sbc es_count1
    sta es_newrows1

    lda OVL_MINROW1
    cmp es_newrows1
    bcc es_delrow_use_min
    bne es_delrow_use_last
    lda OVL_MINROW0
    cmp es_newrows0
    bcc es_delrow_use_min
es_delrow_use_last:
    sec
    lda es_newrows0
    sbc #1
    sta OVL_CURROW0
    lda es_newrows1
    sbc #0
    sta OVL_CURROW1
    jmp es_delrow_state
es_delrow_use_min:
    lda OVL_MINROW0
    sta OVL_CURROW0
    lda OVL_MINROW1
    sta OVL_CURROW1
es_delrow_state:
    jsr es_collapse_selection
    jmp es_finish

; C=1 if current row lies in first es_count rows beginning at OVL_MINROW.
es_row_in_delete_window:
    ; row < min => no
    lda es_row1
    cmp OVL_MINROW1
    bcc es_row_keep
    bne es_row_check_offset
    lda es_row0
    cmp OVL_MINROW0
    bcc es_row_keep
es_row_check_offset:
    ; offset = row-min
    sec
    lda es_row0
    sbc OVL_MINROW0
    sta es_tmp0
    lda es_row1
    sbc OVL_MINROW1
    sta es_tmp1
    ; offset < count ?
    lda es_tmp1
    cmp es_count1
    bcc es_row_delete_yes
    bne es_row_keep
    lda es_tmp0
    cmp es_count0
    bcc es_row_delete_yes
es_row_keep:
    clc
    rts
es_row_delete_yes:
    sec
    rts

es_skip_one_row:
    lda es_dst0
    pha
    lda es_dst1
    pha
    lda es_dst2
    pha
    lda es_dst3
    pha
    ; copy_one_row advances source; restore destination to discard bytes.
    jsr es_copy_one_row
    pla
    sta es_dst3
    pla
    sta es_dst2
    pla
    sta es_dst1
    pla
    sta es_dst0
    rts

; ============================================================
; COLUMN INSERT / DELETE
; ============================================================

es_insert_col_left:
    lda OVL_CURCOL
    sta es_target_col
    lda #0
    sta es_col_delete_mode
    jmp es_rebuild_columns

es_insert_col_right:
    lda OVL_CURCOL
    clc
    adc #1
    sta es_target_col
    sta OVL_CURCOL
    lda #0
    sta es_col_delete_mode
    jmp es_rebuild_columns

es_delete_cols:
    ; Do not delete final remaining column.
    lda OVL_MAXCOLS1
    bne es_delete_cols_go
    lda OVL_MAXCOLS0
    cmp #2
    bcs es_delete_cols_go
    rts

es_delete_cols_go:
    lda #1
    sta es_col_delete_mode

    ; Clamp deletion width to maxcols-1.
    sec
    lda OVL_MAXCOL
    sbc OVL_MINCOL
    sta es_count0
    lda #0
    sta es_count1
    inc es_count0

    sec
    lda OVL_MAXCOLS0
    sbc #1
    sta es_limit0
    lda OVL_MAXCOLS1
    sbc #0
    sta es_limit1
    jsr es_count_min_limit

    ; Effective max delete col = min + count - 1 (8-bit col domain).
    lda OVL_MINCOL
    clc
    adc es_count0
    sec
    sbc #1
    sta es_delete_maxcol

    ; New max column count = old maxcols - deleted count.
    sec
    lda OVL_MAXCOLS0
    sbc es_count0
    sta es_newcols0
    lda OVL_MAXCOLS1
    sbc es_count1
    sta es_newcols1

    ; Current = min selected column, clamped to new last column.
    lda OVL_MINCOL
    sta OVL_CURCOL
    lda es_newcols1
    bne es_delcol_current_ok
    lda OVL_CURCOL
    cmp es_newcols0
    bcc es_delcol_current_ok
    lda es_newcols0
    beq es_delcol_current_ok
    sec
    sbc #1
    sta OVL_CURCOL
es_delcol_current_ok:

es_rebuild_columns:
    lda #0
    sta es_row0
    sta es_row1

es_columns_row_loop:
    jsr es_src_at_end
    bcc +
    jmp es_columns_done
+

    lda #0
    sta es_col
    sta es_emitted
    sta es_inserted

es_columns_field_loop:
    ; INSERT: emit blank before target source field.
    lda es_col_delete_mode
    bne es_columns_no_preinsert
    lda es_inserted
    bne es_columns_no_preinsert
    lda es_col
    cmp es_target_col
    bne es_columns_no_preinsert
    jsr es_emit_empty_field
    lda #1
    sta es_inserted
es_columns_no_preinsert:

    ; Decide whether source field is kept.
    lda es_col_delete_mode
    beq es_columns_keep_field
    lda es_col
    cmp OVL_MINCOL
    bcc es_columns_keep_field
    cmp es_delete_maxcol
    bcc es_columns_drop_field
    beq es_columns_drop_field

es_columns_keep_field:
    jsr es_emit_prefix
    lda #1
    sta es_copy_mode
    jsr es_scan_field
    jmp es_columns_after_field

es_columns_drop_field:
    lda #0
    sta es_copy_mode
    jsr es_scan_field

es_columns_after_field:
    jsr es_src_at_end
    bcs es_columns_row_end_eof
    ldz #0
    lda [es_src0],z
    cmp OVL_DELIMITER
    bne es_columns_row_boundary

    ; Consume original delimiter; output delimiter is reconstructed by prefix.
    jsr es_inc_src
    inc es_col
    jmp es_columns_field_loop

es_columns_row_boundary:
    ; INSERT target beyond this short row: append one empty field.
    lda es_col_delete_mode
    bne es_columns_ensure_field
    lda es_inserted
    bne es_columns_ensure_field
    jsr es_emit_empty_field
    lda #1
    sta es_inserted

es_columns_ensure_field:
    ; DELETE on a short row may remove every field: preserve one empty field.
    lda es_emitted
    bne es_columns_emit_eol
    jsr es_emit_empty_field

es_columns_emit_eol:
    ldz #0
    lda [es_src0],z
    cmp #0x0d
    bne es_columns_eol_lf
    jsr es_copy_src_byte
    jsr es_src_at_end
    bcs es_columns_row_advance
    ldz #0
    lda [es_src0],z
    cmp #0x0a
    bne es_columns_row_advance
    jsr es_copy_src_byte
    jmp es_columns_row_advance
es_columns_eol_lf:
    cmp #0x0a
    bne es_columns_weird
    jsr es_copy_src_byte
    jmp es_columns_row_advance
es_columns_weird:
    ; Defensive malformed boundary: preserve and continue same row.
    jsr es_copy_src_byte
    jmp es_columns_field_loop

es_columns_row_end_eof:
    ; EOF terminates final logical row without CR.
    lda es_col_delete_mode
    bne +
    lda es_inserted
    bne +
    jsr es_emit_empty_field
+
    lda es_emitted
    bne es_columns_done
    jsr es_emit_empty_field
    jmp es_columns_done

es_columns_row_advance:
    inc es_row0
    bne +
    inc es_row1
+
    jmp es_columns_row_loop

es_columns_done:
    lda es_col_delete_mode
    beq es_columns_finish
    jsr es_collapse_selection
es_columns_finish:
    jmp es_finish

; emit delimiter before every field after the first.
es_emit_prefix:
    lda es_emitted
    beq +
    lda OVL_DELIMITER
    jsr es_put_dst
+
    inc es_emitted
    rts

es_emit_empty_field:
    jmp es_emit_prefix

; Scan raw source field. Boundary delimiter/CR/LF is not consumed.
; es_copy_mode=1 copies raw field bytes after emitting prefix; 0 discards.
es_scan_field:
    lda #0
    sta es_in_quotes
    lda #1
    sta es_field_start

es_scan_field_loop:
    jsr es_src_at_end
    bcc +
    rts
+
    ldz #0
    lda [es_src0],z
    sta es_ch

    lda es_in_quotes
    beq es_scan_outside

    lda es_ch
    cmp #0x22
    bne es_scan_consume
    jsr es_consume_field_byte
    jsr es_src_at_end
    bcs es_scan_quote_closed
    ldz #0
    lda [es_src0],z
    cmp #0x22
    bne es_scan_quote_closed
    jsr es_consume_field_byte
    jmp es_scan_field_loop
es_scan_quote_closed:
    lda #0
    sta es_in_quotes
    jmp es_scan_field_loop

es_scan_outside:
    lda es_ch
    cmp #0x22
    bne es_scan_boundary
    lda es_field_start
    beq es_scan_consume
    lda #1
    sta es_in_quotes
    lda #0
    sta es_field_start
    jsr es_consume_field_byte
    jmp es_scan_field_loop

es_scan_boundary:
    lda es_ch
    cmp OVL_DELIMITER
    beq es_scan_done
    cmp #0x0d
    beq es_scan_done
    cmp #0x0a
    beq es_scan_done
    lda #0
    sta es_field_start
es_scan_consume:
    jsr es_consume_field_byte
    jmp es_scan_field_loop
es_scan_done:
    rts

es_consume_field_byte:
    lda es_copy_mode
    beq +
    ldz #0
    lda [es_src0],z
    jsr es_put_dst
+
    jsr es_inc_src
    rts

; ============================================================
; COMMON INIT / FINISH / HELPERS
; ============================================================

es_init:
    lda #SRC0
    sta es_src0
    lda #SRC1
    sta es_src1
    lda #SRC2
    sta es_src2
    lda #SRC3
    sta es_src3

    clc
    lda #SRC0
    adc OVL_SIZE0
    sta es_srcend0
    lda #SRC1
    adc OVL_SIZE1
    sta es_srcend1
    lda #SRC2
    adc OVL_SIZE2
    sta es_srcend2
    lda #SRC3
    adc OVL_SIZE3
    sta es_srcend3

    lda #TMP0
    sta es_dst0
    lda #TMP1
    sta es_dst1
    lda #TMP2
    sta es_dst2
    lda #TMP3
    sta es_dst3

    lda #0
    sta es_inserted
    rts

es_finish:
    ; temp end
    lda es_dst0
    sta es_tempend0
    lda es_dst1
    sta es_tempend1
    lda es_dst2
    sta es_tempend2
    lda es_dst3
    sta es_tempend3

    ; OVL_SIZE = temp_end - $08600000
    sec
    lda es_tempend0
    sbc #TMP0
    sta OVL_SIZE0
    lda es_tempend1
    sbc #TMP1
    sta OVL_SIZE1
    lda es_tempend2
    sbc #TMP2
    sta OVL_SIZE2
    lda es_tempend3
    sbc #TMP3
    sta OVL_SIZE3

    ; copy temp back to source
    lda #TMP0
    sta es_src0
    lda #TMP1
    sta es_src1
    lda #TMP2
    sta es_src2
    lda #TMP3
    sta es_src3

    lda #SRC0
    sta es_dst0
    lda #SRC1
    sta es_dst1
    lda #SRC2
    sta es_dst2
    lda #SRC3
    sta es_dst3

es_copyback_loop:
    lda es_src3
    cmp es_tempend3
    bne es_copyback_byte
    lda es_src2
    cmp es_tempend2
    bne es_copyback_byte
    lda es_src1
    cmp es_tempend1
    bne es_copyback_byte
    lda es_src0
    cmp es_tempend0
    beq es_finish_done
es_copyback_byte:
    ldz #0
    lda [es_src0],z
    sta [es_dst0],z
    jsr es_inc_src
    jsr es_inc_dst
    jmp es_copyback_loop
es_finish_done:
    rts

es_collapse_selection:
    lda #1
    sta OVL_MULTI_COUNT
    lda #0
    sta OVL_MULTI_MODE

    lda OVL_CURROW0
    sta OVL_MINROW0
    sta OVL_MAXROW0
    sta OVL_ANCHOR_ROW0
    lda OVL_CURROW1
    sta OVL_MINROW1
    sta OVL_MAXROW1
    sta OVL_ANCHOR_ROW1
    lda OVL_CURCOL
    sta OVL_MINCOL
    sta OVL_MAXCOL
    sta OVL_ANCHOR_COL
    rts

; Clamp es_count to es_limit if count > limit.
es_count_min_limit:
    lda es_count1
    cmp es_limit1
    bcc es_count_ok
    bne es_count_use_limit
    lda es_count0
    cmp es_limit0
    bcc es_count_ok
    beq es_count_ok
es_count_use_limit:
    lda es_limit0
    sta es_count0
    lda es_limit1
    sta es_count1
es_count_ok:
    rts

es_src_at_end:
    lda es_src3
    cmp es_srcend3
    bcc es_src_not_end
    bne es_src_end
    lda es_src2
    cmp es_srcend2
    bcc es_src_not_end
    bne es_src_end
    lda es_src1
    cmp es_srcend1
    bcc es_src_not_end
    bne es_src_end
    lda es_src0
    cmp es_srcend0
    bcc es_src_not_end
es_src_end:
    sec
    rts
es_src_not_end:
    clc
    rts

es_copy_src_byte:
    ldz #0
    lda [es_src0],z
    pha
    jsr es_put_dst
    pla
    jsr es_inc_src
    rts

es_put_dst:
    ; Keep rebuild below $08700000.
    pha
    lda es_dst3
    cmp #0x08
    bne es_put_abort
    lda es_dst2
    cmp #0x70
    bcs es_put_abort
    pla
    ldz #0
    sta [es_dst0],z
    jmp es_inc_dst
es_put_abort:
    pla
    ; abort transform safely by forcing input EOF
    lda es_srcend0
    sta es_src0
    lda es_srcend1
    sta es_src1
    lda es_srcend2
    sta es_src2
    lda es_srcend3
    sta es_src3
    rts

es_inc_src:
    inc es_src0
    bne +
    inc es_src1
    bne +
    inc es_src2
    bne +
    inc es_src3
+
    rts

es_inc_dst:
    inc es_dst0
    bne +
    inc es_dst1
    bne +
    inc es_dst2
    bne +
    inc es_dst3
+
    rts

    .section zzpage,bss
es_src0:        .space 1
es_src1:        .space 1
es_src2:        .space 1
es_src3:        .space 1
es_dst0:        .space 1
es_dst1:        .space 1
es_dst2:        .space 1
es_dst3:        .space 1

    .section bss,bss
es_srcend0:     .space 1
es_srcend1:     .space 1
es_srcend2:     .space 1
es_srcend3:     .space 1
es_tempend0:    .space 1
es_tempend1:    .space 1
es_tempend2:    .space 1
es_tempend3:    .space 1
es_row0:        .space 1
es_row1:        .space 1
es_target_row0: .space 1
es_target_row1: .space 1
es_count0:      .space 1
es_count1:      .space 1
es_limit0:      .space 1
es_limit1:      .space 1
es_newrows0:    .space 1
es_newrows1:    .space 1
es_newcols0:    .space 1
es_newcols1:    .space 1
es_tmp0:        .space 1
es_tmp1:        .space 1
es_tmp_count:   .space 1
es_insert_after:.space 1
es_inserted:    .space 1
es_target_col:  .space 1
es_delete_maxcol:.space 1
es_col:         .space 1
es_emitted:     .space 1
es_col_delete_mode:.space 1
es_copy_mode:   .space 1
es_in_quotes:   .space 1
es_field_start: .space 1
es_ch:          .space 1
