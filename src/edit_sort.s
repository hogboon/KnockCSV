; ------------------------------------------------------------
; edit_sort.s - KnockCSV EDIT.PRG
; Sort current column using the same engine previously resident in csvview.s.
;
; Commands:
;   19 Text ascending
;   20 Text descending
;   21 Numeric ascending
;   22 Numeric descending
;   23 Length ascending
;   24 Length descending
;
; Row index remains in Attic at $08100000 across the chain-load.
; Sorted CSV is materialised through $08300000 and copied back to $08000000.
; KnockCSV rebuilds its row index after EDIT.PRG returns.
; ------------------------------------------------------------

    .public edit_sort

    .extern csvrowaddr
    .extern csv_row0
    .extern csv_row1
    .extern attic_addr0
    .extern attic_addr1
    .extern attic_addr2
    .extern attic_addr3
    .extern busycursor_on
    .extern busycursor_off

OVL_COMMAND      .equ 0x1f01
OVL_SIZE0        .equ 0x1f02
OVL_SIZE1        .equ 0x1f03
OVL_SIZE2        .equ 0x1f04
OVL_SIZE3        .equ 0x1f05
OVL_DELIMITER    .equ 0x1f06
OVL_CURCOL       .equ 0x1f0c
OVL_MINROW0      .equ 0x1f10
OVL_MINROW1      .equ 0x1f11
OVL_MAXROW0      .equ 0x1f12
OVL_MAXROW1      .equ 0x1f13
OVL_ROWS0        .equ 0x1f1b
OVL_ROWS1        .equ 0x1f1c
OVL_FROZEN_ROWS  .equ 0x1f1f

SORTTMP_BASE0    .equ 0x00
SORTTMP_BASE1    .equ 0x00
SORTTMP_BASE2    .equ 0x30
SORTTMP_BASE3    .equ 0x08

    .section code,text

edit_sort:

    lda #0
    sta csv_sort_descending
    sta csv_sort_numeric
    sta csv_sort_length

    lda OVL_COMMAND
    cmp #19
    beq esort_go
    cmp #20
    bne +
    lda #1
    sta csv_sort_descending
    jmp esort_go
+
    cmp #21
    bne +
    lda #1
    sta csv_sort_numeric
    jmp esort_go
+
    cmp #22
    bne +
    lda #1
    sta csv_sort_numeric
    sta csv_sort_descending
    jmp esort_go
+
    cmp #23
    bne +
    lda #1
    sta csv_sort_length
    jmp esort_go
+
    cmp #24
    bne esort_done
    lda #1
    sta csv_sort_length
    sta csv_sort_descending

esort_go:
    jsr busycursor_on
    jsr csv_sort_current_column
    jsr busycursor_off
esort_done:
    rts

; ============================================================
; SORT ENGINE: current column, text ascending/descending.
; Frozen header rows are excluded.
; ============================================================
csv_sort_current_column:
    ; Default: sort all non-frozen data rows.
    lda OVL_FROZEN_ROWS
    sta csv_sort_start0
    lda #0
    sta csv_sort_start1
    lda OVL_ROWS0
    sta csv_sort_end0
    lda OVL_ROWS1
    sta csv_sort_end1

    ; If the selection spans more than one row, limit sorting to
    ; MINROW..MAXROW inclusive.  The current column remains the key.
    lda OVL_MINROW1
    cmp OVL_MAXROW1
    bne csv_sort_use_selection
    lda OVL_MINROW0
    cmp OVL_MAXROW0
    beq csv_sort_range_ready

csv_sort_use_selection:
    ; start = max(MINROW, frozen_rows)
    lda OVL_MINROW1
    bne csv_sort_sel_start_ok
    lda OVL_MINROW0
    cmp OVL_FROZEN_ROWS
    bcs csv_sort_sel_start_ok
    lda OVL_FROZEN_ROWS
    sta csv_sort_start0
    lda #0
    sta csv_sort_start1
    jmp csv_sort_sel_end

csv_sort_sel_start_ok:
    lda OVL_MINROW0
    sta csv_sort_start0
    lda OVL_MINROW1
    sta csv_sort_start1

csv_sort_sel_end:
    ; end = MAXROW + 1 (exclusive), clamped to total rows.
    clc
    lda OVL_MAXROW0
    adc #1
    sta csv_sort_end0
    lda OVL_MAXROW1
    adc #0
    sta csv_sort_end1

    lda csv_sort_end1
    cmp OVL_ROWS1
    bcc csv_sort_range_ready
    bne csv_sort_clamp_end
    lda csv_sort_end0
    cmp OVL_ROWS0
    bcc csv_sort_range_ready
    beq csv_sort_range_ready
csv_sort_clamp_end:
    lda OVL_ROWS0
    sta csv_sort_end0
    lda OVL_ROWS1
    sta csv_sort_end1

csv_sort_range_ready:
    ; n = end - start
    sec
    lda csv_sort_end0
    sbc csv_sort_start0
    sta csv_sort_n0
    lda csv_sort_end1
    sbc csv_sort_start1
    sta csv_sort_n1
    lda csv_sort_n1
    bne sort_have$
    lda csv_sort_n0
    cmp #2
    bcs sort_have$
    jmp sort_redraw$
sort_have$:
    lda csv_sort_n1
    lsr a
    sta csv_sort_gap1
    lda csv_sort_n0
    ror a
    sta csv_sort_gap0

sort_gap$:
    lda csv_sort_gap0
    ora csv_sort_gap1
    bne +
    jmp sort_materialise$
+
    clc
    lda csv_sort_gap0
    adc csv_sort_start0
    sta csv_sort_i0
    lda csv_sort_gap1
    adc csv_sort_start1
    sta csv_sort_i1

sort_i$:
    lda csv_sort_i1
    cmp csv_sort_end1
    bcc sort_i_ok$
    beq +
    jmp sort_next_gap$
+
    lda csv_sort_i0
    cmp csv_sort_end0
    bcc sort_i_ok$
    jmp sort_next_gap$
sort_i_ok$:
    lda csv_sort_i0
    sta csv_sort_j0
    lda csv_sort_i1
    sta csv_sort_j1

sort_j$:
    sec
    lda csv_sort_j0
    sbc csv_sort_gap0
    sta csv_sort_prev0
    lda csv_sort_j1
    sbc csv_sort_gap1
    sta csv_sort_prev1
    bcc sort_j_done$
    lda csv_sort_prev1
    cmp csv_sort_start1
    bcc sort_j_done$
    bne sort_compare$
    lda csv_sort_prev0
    cmp csv_sort_start0
    bcc sort_j_done$
sort_compare$:
    lda csv_sort_prev0
    sta csv_sort_rowa0
    lda csv_sort_prev1
    sta csv_sort_rowa1
    lda csv_sort_j0
    sta csv_sort_rowb0
    lda csv_sort_j1
    sta csv_sort_rowb1
    jsr csv_sort_compare_rows
    sta csv_sort_cmp

    lda csv_sort_descending
    bne sort_desc$
    lda csv_sort_cmp
    cmp #1
    bne sort_j_done$
    jmp sort_swap$
sort_desc$:
    lda csv_sort_cmp
    cmp #0xff
    bne sort_j_done$
sort_swap$:
    jsr csv_sort_swap_index_rows
    lda csv_sort_prev0
    sta csv_sort_j0
    lda csv_sort_prev1
    sta csv_sort_j1
    jmp sort_j$
sort_j_done$:
    inc csv_sort_i0
    beq +
    jmp sort_i$
+
    inc csv_sort_i1
    jmp sort_i$

sort_next_gap$:
    lda csv_sort_gap1
    lsr a
    sta csv_sort_gap1
    lda csv_sort_gap0
    ror a
    sta csv_sort_gap0
    jmp sort_gap$

sort_materialise$:

    lda #SORTTMP_BASE0
    sta csv_sort_dst0
    lda #SORTTMP_BASE1
    sta csv_sort_dst1
    lda #SORTTMP_BASE2
    sta csv_sort_dst2
    lda #SORTTMP_BASE3
    sta csv_sort_dst3
    lda #0
    sta csv_sort_i0
    sta csv_sort_i1

sort_mat_row$:
    lda csv_sort_i1
    cmp OVL_ROWS1
    bcc sort_mat_ok$
    bne sort_copyback$
    lda csv_sort_i0
    cmp OVL_ROWS0
    bcc sort_mat_ok$
    jmp sort_copyback$
sort_mat_ok$:
    lda csv_sort_i0
    sta csv_sort_rowa0
    lda csv_sort_i1
    sta csv_sort_rowa1
    jsr csv_sort_get_index_offset_a
    lda csv_sort_offa0
    sta csv_sort_src0
    lda csv_sort_offa1
    sta csv_sort_src1
    lda csv_sort_offa2
    sta csv_sort_src2
    lda csv_sort_offa3
    clc
    adc #0x08
    sta csv_sort_src3
sort_mat_byte$:
    jsr csv_sort_src_at_end
    bne sort_mat_done$
    ldz #0
    lda [csv_sort_src0],z
    sta csv_sort_byte
    sta [csv_sort_dst0],z
    jsr csv_sort_inc_src
    jsr csv_sort_inc_dst
    lda csv_sort_byte
    cmp #0x0d
    bne sort_mat_byte$
sort_mat_done$:
    inc csv_sort_i0
    bne sort_mat_row$
    inc csv_sort_i1
    jmp sort_mat_row$

sort_copyback$:

    lda #SORTTMP_BASE0
    sta csv_sort_src0
    lda #SORTTMP_BASE1
    sta csv_sort_src1
    lda #SORTTMP_BASE2
    sta csv_sort_src2
    lda #SORTTMP_BASE3
    sta csv_sort_src3
    lda #0
    sta csv_sort_dst0
    sta csv_sort_dst1
    sta csv_sort_dst2
    lda #0x08
    sta csv_sort_dst3
    lda OVL_SIZE0
    sta csv_sort_rem0
    lda OVL_SIZE1
    sta csv_sort_rem1
    lda OVL_SIZE2
    sta csv_sort_rem2
    lda OVL_SIZE3
    sta csv_sort_rem3
sort_copy_loop$:
    lda csv_sort_rem0
    ora csv_sort_rem1
    ora csv_sort_rem2
    ora csv_sort_rem3
    beq sort_copy_done$
    ldz #0
    lda [csv_sort_src0],z
    sta [csv_sort_dst0],z
    jsr csv_sort_inc_src
    jsr csv_sort_inc_dst
    jsr csv_sort_dec_rem
    jmp sort_copy_loop$
sort_copy_done$:
sort_redraw$:
    rts

; Compare rows A/B, logical selected fields.
; A=$ff A<B, 0 equal, 1 A>B.
csv_sort_compare_rows:
    lda csv_sort_length
    beq csv_sort_compare_rows_not_length
    jsr csv_sort_compare_length_rows
    lda csv_sort_len_result
    rts

csv_sort_compare_rows_not_length:
    lda csv_sort_numeric
    beq csv_sort_compare_text_rows

    jsr csv_sort_compare_numeric_rows
    lda csv_sort_num_fallback
    bne csv_sort_compare_text_rows
    lda csv_sort_num_result
    rts

csv_sort_compare_text_rows:
    jsr csv_sort_field_ptr_a
    jsr csv_sort_field_ptr_b
sort_cmp_loop$:
    jsr csv_sort_next_a
    lda csv_sort_a_end
    sta csv_sort_a_end_saved
    lda csv_sort_a_char
    sta csv_sort_a_char_saved
    jsr csv_sort_next_b
    lda csv_sort_a_end_saved
    beq sort_cmp_a_has$
    lda csv_sort_b_end
    beq sort_cmp_less$
    lda #0
    rts
sort_cmp_a_has$:
    lda csv_sort_b_end
    beq sort_cmp_chars$
    lda #1
    rts
sort_cmp_chars$:
    ; Natural text comparison, case-insensitive.
    ;
    ; KnockCSV mixed-case PETSCII can contain letters in these ranges:
    ;   $41..$5A  -> a..z
    ;   $61..$7A  -> A..Z alternate range
    ;   $C1..$DA  -> A..Z shifted PETSCII
    ;
    ; Normalize every alphabetic representation to $61..$7A only
    ; for comparison. The original CSV bytes are never modified.
    lda csv_sort_a_char_saved
    jsr csv_sort_casefold
    sta csv_sort_fold_a

    lda csv_sort_b_char
    jsr csv_sort_casefold
    sta csv_sort_fold_b

    lda csv_sort_fold_a
    cmp csv_sort_fold_b
    bcc sort_cmp_less$
    bne sort_cmp_greater$
    jmp sort_cmp_loop$


sort_cmp_less$:
    lda #0xff
    rts
sort_cmp_greater$:
    lda #1
    rts

; A = PETSCII byte
; returns A = canonical case-insensitive comparison byte.
csv_sort_casefold:
    ; $41..$5A -> $61..$7A
    cmp #0x41
    bcc csv_sort_casefold_shifted$
    cmp #0x5b
    bcs csv_sort_casefold_shifted$
    clc
    adc #0x20
    rts

csv_sort_casefold_shifted$:
    ; $C1..$DA -> $61..$7A
    cmp #0xc1
    bcc csv_sort_casefold_done$
    cmp #0xdb
    bcs csv_sort_casefold_done$
    sec
    sbc #0x60

csv_sort_casefold_done$:
    rts

; ------------------------------------------------------------
; Length comparator.
;
; Counts the LOGICAL characters of the selected field using the same
; quote-aware csv_sort_next_a / csv_sort_next_b readers used by text sort.
; Length is 16-bit, so long text cells are handled correctly.
;
; Result:
;   $ff = A shorter than B
;     0 = same logical length
;     1 = A longer than B
; ------------------------------------------------------------
csv_sort_compare_length_rows:
    lda #0
    sta csv_sort_len_a0
    sta csv_sort_len_a1
    sta csv_sort_len_b0
    sta csv_sort_len_b1

    jsr csv_sort_field_ptr_a

csv_sort_len_count_a:
    jsr csv_sort_next_a
    lda csv_sort_a_end
    bne csv_sort_len_a_done
    inc csv_sort_len_a0
    bne csv_sort_len_count_a
    inc csv_sort_len_a1
    jmp csv_sort_len_count_a

csv_sort_len_a_done:
    jsr csv_sort_field_ptr_b

csv_sort_len_count_b:
    jsr csv_sort_next_b
    lda csv_sort_b_end
    bne csv_sort_len_b_done
    inc csv_sort_len_b0
    bne csv_sort_len_count_b
    inc csv_sort_len_b1
    jmp csv_sort_len_count_b

csv_sort_len_b_done:
    lda csv_sort_len_a1
    cmp csv_sort_len_b1
    bcc csv_sort_len_less
    bne csv_sort_len_greater

    lda csv_sort_len_a0
    cmp csv_sort_len_b0
    bcc csv_sort_len_less
    bne csv_sort_len_greater

    lda #0
    sta csv_sort_len_result
    rts

csv_sort_len_less:
    lda #0xff
    sta csv_sort_len_result
    rts

csv_sort_len_greater:
    lda #1
    sta csv_sort_len_result
    rts


; ------------------------------------------------------------
; Numeric comparator.
;
; Supports:
;   leading/trailing spaces
;   optional + / -
;   integer and decimal values using '.'
;   up to 63 numeric digits per cell
;
; Numeric cells sort before non-numeric cells in ascending order.
; If both cells are non-numeric, comparison falls back to text.
; ------------------------------------------------------------
csv_sort_compare_numeric_rows:
    lda #0
    sta csv_sort_num_fallback

    jsr csv_sort_parse_num_a
    jsr csv_sort_parse_num_b

    ; Both invalid -> use normal text comparator.
    lda csv_sort_num_valid_a
    bne csv_sort_num_a_valid
    lda csv_sort_num_valid_b
    bne csv_sort_num_a_invalid_only
    lda #1
    sta csv_sort_num_fallback
    rts

csv_sort_num_a_invalid_only:
    ; invalid A > numeric B
    lda #1
    sta csv_sort_num_result
    rts

csv_sort_num_a_valid:
    lda csv_sort_num_valid_b
    bne csv_sort_num_both_valid
    ; numeric A < invalid B
    lda #0xff
    sta csv_sort_num_result
    rts

csv_sort_num_both_valid:
    ; Normalize -0 to +0.
    lda csv_sort_num_nonzero_a
    bne csv_sort_num_sign_a_ok
    lda #0
    sta csv_sort_num_sign_a
csv_sort_num_sign_a_ok:
    lda csv_sort_num_nonzero_b
    bne csv_sort_num_sign_b_ok
    lda #0
    sta csv_sort_num_sign_b
csv_sort_num_sign_b_ok:

    ; Different signs: negative is smaller.
    lda csv_sort_num_sign_a
    cmp csv_sort_num_sign_b
    beq csv_sort_num_same_sign
    lda csv_sort_num_sign_a
    beq csv_sort_num_positive_a
    lda #0xff
    sta csv_sort_num_result
    rts
csv_sort_num_positive_a:
    lda #1
    sta csv_sort_num_result
    rts

csv_sort_num_same_sign:
    jsr csv_sort_compare_num_magnitude
    ; result is comparator of absolute magnitudes.
    lda csv_sort_num_mag_result
    sta csv_sort_num_result

    ; Both negative -> reverse magnitude order.
    lda csv_sort_num_sign_a
    beq csv_sort_num_numeric_done
    lda csv_sort_num_result
    beq csv_sort_num_numeric_done
    cmp #1
    beq csv_sort_num_neg_make_less
    lda #1
    sta csv_sort_num_result
    rts
csv_sort_num_neg_make_less:
    lda #0xff
    sta csv_sort_num_result
csv_sort_num_numeric_done:
    rts


; ------------------------------------------------------------
; Parse numeric field A into csv_sort_num_buf_a.
; ------------------------------------------------------------
csv_sort_parse_num_a:
    lda csv_sort_rowa0
    sta csv_row0
    lda csv_sort_rowa1
    sta csv_row1
    jsr csvrowaddr

    lda attic_addr0
    sta csv_sort_pa0
    lda attic_addr1
    sta csv_sort_pa1
    lda attic_addr2
    sta csv_sort_pa2
    lda attic_addr3
    sta csv_sort_pa3

    lda #0
    sta csv_sort_ca
    sta csv_sort_a_inq
    sta csv_sort_a_qp
    sta csv_sort_a_data
    sta csv_sort_a_end
    jsr csv_sort_seek_selected_a

    lda #0
    sta csv_sort_num_valid_a
    sta csv_sort_num_sign_a
    sta csv_sort_num_nonzero_a
    sta csv_sort_num_intlen_a
    sta csv_sort_num_fraclen_a
    sta csv_sort_num_buflen_a
    sta csv_sort_num_phase
    sta csv_sort_num_sign_seen
    sta csv_sort_num_digits_seen

csv_sort_num_parse_a_loop:
    jsr csv_sort_next_a
    lda csv_sort_a_end
    bne csv_sort_num_parse_a_finish

    lda csv_sort_a_char
    jsr csv_sort_num_parse_char_a
    lda csv_sort_num_parse_error
    beq csv_sort_num_parse_a_loop
    rts

csv_sort_num_parse_a_finish:
    lda csv_sort_num_digits_seen
    beq csv_sort_num_parse_a_invalid
    lda #1
    sta csv_sort_num_valid_a
    jsr csv_sort_num_normalize_a
    rts

csv_sort_num_parse_a_invalid:
    lda #0
    sta csv_sort_num_valid_a
    rts


; ------------------------------------------------------------
; Parse numeric field B into csv_sort_num_buf_b.
; ------------------------------------------------------------
csv_sort_parse_num_b:
    lda csv_sort_rowb0
    sta csv_row0
    lda csv_sort_rowb1
    sta csv_row1
    jsr csvrowaddr

    lda attic_addr0
    sta csv_sort_pb0
    lda attic_addr1
    sta csv_sort_pb1
    lda attic_addr2
    sta csv_sort_pb2
    lda attic_addr3
    sta csv_sort_pb3

    lda #0
    sta csv_sort_cb
    sta csv_sort_b_inq
    sta csv_sort_b_qp
    sta csv_sort_b_data
    sta csv_sort_b_end
    jsr csv_sort_seek_selected_b

    lda #0
    sta csv_sort_num_valid_b
    sta csv_sort_num_sign_b
    sta csv_sort_num_nonzero_b
    sta csv_sort_num_intlen_b
    sta csv_sort_num_fraclen_b
    sta csv_sort_num_buflen_b
    sta csv_sort_num_phase
    sta csv_sort_num_sign_seen
    sta csv_sort_num_digits_seen

csv_sort_num_parse_b_loop:
    jsr csv_sort_next_b
    lda csv_sort_b_end
    bne csv_sort_num_parse_b_finish

    lda csv_sort_b_char
    jsr csv_sort_num_parse_char_b
    lda csv_sort_num_parse_error
    beq csv_sort_num_parse_b_loop
    rts

csv_sort_num_parse_b_finish:
    lda csv_sort_num_digits_seen
    beq csv_sort_num_parse_b_invalid
    lda #1
    sta csv_sort_num_valid_b
    jsr csv_sort_num_normalize_b
    rts

csv_sort_num_parse_b_invalid:
    lda #0
    sta csv_sort_num_valid_b
    rts


; Seek selected column using already-initialised A/B state.
csv_sort_seek_selected_a:
    lda csv_sort_ca
    cmp OVL_CURCOL
    beq csv_sort_seek_selected_a_done
csv_sort_seek_selected_a_loop:
    jsr csv_sort_class_a
    cmp #2
    beq csv_sort_seek_selected_a_missing
    cmp #1
    bne csv_sort_seek_selected_a_advance
    inc csv_sort_ca
    lda csv_sort_ca
    cmp OVL_CURCOL
    beq csv_sort_seek_selected_a_advance_done
csv_sort_seek_selected_a_advance:
    jsr csv_sort_inc_pa
    jmp csv_sort_seek_selected_a_loop
csv_sort_seek_selected_a_advance_done:
    jsr csv_sort_inc_pa
csv_sort_seek_selected_a_done:
    rts
csv_sort_seek_selected_a_missing:
    lda #1
    sta csv_sort_a_end
    rts

csv_sort_seek_selected_b:
    lda csv_sort_cb
    cmp OVL_CURCOL
    beq csv_sort_seek_selected_b_done
csv_sort_seek_selected_b_loop:
    jsr csv_sort_class_b
    cmp #2
    beq csv_sort_seek_selected_b_missing
    cmp #1
    bne csv_sort_seek_selected_b_advance
    inc csv_sort_cb
    lda csv_sort_cb
    cmp OVL_CURCOL
    beq csv_sort_seek_selected_b_advance_done
csv_sort_seek_selected_b_advance:
    jsr csv_sort_inc_pb
    jmp csv_sort_seek_selected_b_loop
csv_sort_seek_selected_b_advance_done:
    jsr csv_sort_inc_pb
csv_sort_seek_selected_b_done:
    rts
csv_sort_seek_selected_b_missing:
    lda #1
    sta csv_sort_b_end
    rts


; ------------------------------------------------------------
; Parse one logical numeric character A.
; phases: 0 leading/sign, 1 integer, 2 fraction, 3 trailing spaces.
; ------------------------------------------------------------
csv_sort_num_parse_char_a:
    sta csv_sort_num_char
    lda #0
    sta csv_sort_num_parse_error

    lda csv_sort_num_phase
    beq csv_sort_num_a_phase0
    cmp #1
    beq csv_sort_num_a_phase1
    cmp #2
    beq csv_sort_num_a_phase2
    jmp csv_sort_num_a_phase3

csv_sort_num_a_phase0:
    lda csv_sort_num_char
    cmp #' '
    bne +
    jmp csv_sort_num_a_ok
+
    cmp #'+'
    beq csv_sort_num_a_plus
    cmp #'-'
    beq csv_sort_num_a_minus
    cmp #'.'
    beq csv_sort_num_a_dot
    jsr csv_sort_num_is_digit
    bcc csv_sort_num_a_invalid
    lda #1
    sta csv_sort_num_phase
    jmp csv_sort_num_a_store_int

csv_sort_num_a_plus:
    lda csv_sort_num_sign_seen
    bne csv_sort_num_a_invalid
    lda #1
    sta csv_sort_num_sign_seen
    rts

csv_sort_num_a_minus:
    lda csv_sort_num_sign_seen
    bne csv_sort_num_a_invalid
    lda #1
    sta csv_sort_num_sign_seen
    sta csv_sort_num_sign_a
    rts

csv_sort_num_a_dot:
    lda #2
    sta csv_sort_num_phase
    rts

csv_sort_num_a_phase1:
    lda csv_sort_num_char
    cmp #'.'
    beq csv_sort_num_a_dot
    cmp #' '
    beq csv_sort_num_a_trailing
    jsr csv_sort_num_is_digit
    bcc csv_sort_num_a_invalid
csv_sort_num_a_store_int:
    jsr csv_sort_num_store_a
    lda csv_sort_num_parse_error
    bne csv_sort_num_a_ok
    inc csv_sort_num_intlen_a
    rts

csv_sort_num_a_phase2:
    lda csv_sort_num_char
    cmp #' '
    beq csv_sort_num_a_trailing
    jsr csv_sort_num_is_digit
    bcc csv_sort_num_a_invalid
    jsr csv_sort_num_store_a
    lda csv_sort_num_parse_error
    bne csv_sort_num_a_ok
    inc csv_sort_num_fraclen_a
    rts

csv_sort_num_a_trailing:
    lda #3
    sta csv_sort_num_phase
    rts

csv_sort_num_a_phase3:
    lda csv_sort_num_char
    cmp #' '
    beq csv_sort_num_a_ok
csv_sort_num_a_invalid:
    lda #1
    sta csv_sort_num_parse_error
    lda #0
    sta csv_sort_num_valid_a
csv_sort_num_a_ok:
    rts


; B parser, same rules.
csv_sort_num_parse_char_b:
    sta csv_sort_num_char
    lda #0
    sta csv_sort_num_parse_error

    lda csv_sort_num_phase
    beq csv_sort_num_b_phase0
    cmp #1
    beq csv_sort_num_b_phase1
    cmp #2
    beq csv_sort_num_b_phase2
    jmp csv_sort_num_b_phase3

csv_sort_num_b_phase0:
    lda csv_sort_num_char
    cmp #' '
    bne +
    jmp csv_sort_num_b_ok
+
    cmp #'+'
    beq csv_sort_num_b_plus
    cmp #'-'
    beq csv_sort_num_b_minus
    cmp #'.'
    beq csv_sort_num_b_dot
    jsr csv_sort_num_is_digit
    bcc csv_sort_num_b_invalid
    lda #1
    sta csv_sort_num_phase
    jmp csv_sort_num_b_store_int

csv_sort_num_b_plus:
    lda csv_sort_num_sign_seen
    bne csv_sort_num_b_invalid
    lda #1
    sta csv_sort_num_sign_seen
    rts

csv_sort_num_b_minus:
    lda csv_sort_num_sign_seen
    bne csv_sort_num_b_invalid
    lda #1
    sta csv_sort_num_sign_seen
    sta csv_sort_num_sign_b
    rts

csv_sort_num_b_dot:
    lda #2
    sta csv_sort_num_phase
    rts

csv_sort_num_b_phase1:
    lda csv_sort_num_char
    cmp #'.'
    beq csv_sort_num_b_dot
    cmp #' '
    beq csv_sort_num_b_trailing
    jsr csv_sort_num_is_digit
    bcc csv_sort_num_b_invalid
csv_sort_num_b_store_int:
    jsr csv_sort_num_store_b
    lda csv_sort_num_parse_error
    bne csv_sort_num_b_ok
    inc csv_sort_num_intlen_b
    rts

csv_sort_num_b_phase2:
    lda csv_sort_num_char
    cmp #' '
    beq csv_sort_num_b_trailing
    jsr csv_sort_num_is_digit
    bcc csv_sort_num_b_invalid
    jsr csv_sort_num_store_b
    lda csv_sort_num_parse_error
    bne csv_sort_num_b_ok
    inc csv_sort_num_fraclen_b
    rts

csv_sort_num_b_trailing:
    lda #3
    sta csv_sort_num_phase
    rts

csv_sort_num_b_phase3:
    lda csv_sort_num_char
    cmp #' '
    beq csv_sort_num_b_ok
csv_sort_num_b_invalid:
    lda #1
    sta csv_sort_num_parse_error
    lda #0
    sta csv_sort_num_valid_b
csv_sort_num_b_ok:
    rts


; A is digit? C=1 yes, C=0 no.
csv_sort_num_is_digit:
    cmp #'0'
    bcc csv_sort_num_not_digit
    cmp #('9'+1)
    bcs csv_sort_num_not_digit
    sec
    rts
csv_sort_num_not_digit:
    clc
    rts


; Store current numeric digit A/B. Max 63 digits.
csv_sort_num_store_a:
    lda csv_sort_num_buflen_a
    cmp #63
    bcc csv_sort_num_store_a_ok
    lda #1
    sta csv_sort_num_parse_error
    rts
csv_sort_num_store_a_ok:
    tax
    lda csv_sort_num_char
    sta csv_sort_num_buf_a,x
    cmp #'0'
    beq csv_sort_num_store_a_zero
    lda #1
    sta csv_sort_num_nonzero_a
csv_sort_num_store_a_zero:
    inc csv_sort_num_buflen_a
    lda #1
    sta csv_sort_num_digits_seen
    rts

csv_sort_num_store_b:
    lda csv_sort_num_buflen_b
    cmp #63
    bcc csv_sort_num_store_b_ok
    lda #1
    sta csv_sort_num_parse_error
    rts
csv_sort_num_store_b_ok:
    tax
    lda csv_sort_num_char
    sta csv_sort_num_buf_b,x
    cmp #'0'
    beq csv_sort_num_store_b_zero
    lda #1
    sta csv_sort_num_nonzero_b
csv_sort_num_store_b_zero:
    inc csv_sort_num_buflen_b
    lda #1
    sta csv_sort_num_digits_seen
    rts


; Count leading zeroes in integer portions.
csv_sort_num_normalize_a:
    lda #0
    sta csv_sort_num_leadzero_a
    tax
csv_sort_num_norm_a_loop:
    cpx csv_sort_num_intlen_a
    bcs csv_sort_num_norm_a_done
    lda csv_sort_num_buf_a,x
    cmp #'0'
    bne csv_sort_num_norm_a_done
    inc csv_sort_num_leadzero_a
    inx
    jmp csv_sort_num_norm_a_loop
csv_sort_num_norm_a_done:
    sec
    lda csv_sort_num_intlen_a
    sbc csv_sort_num_leadzero_a
    sta csv_sort_num_sigint_a
    rts

csv_sort_num_normalize_b:
    lda #0
    sta csv_sort_num_leadzero_b
    tax
csv_sort_num_norm_b_loop:
    cpx csv_sort_num_intlen_b
    bcs csv_sort_num_norm_b_done
    lda csv_sort_num_buf_b,x
    cmp #'0'
    bne csv_sort_num_norm_b_done
    inc csv_sort_num_leadzero_b
    inx
    jmp csv_sort_num_norm_b_loop
csv_sort_num_norm_b_done:
    sec
    lda csv_sort_num_intlen_b
    sbc csv_sort_num_leadzero_b
    sta csv_sort_num_sigint_b
    rts


; Compare absolute magnitudes.
csv_sort_compare_num_magnitude:
    lda csv_sort_num_sigint_a
    cmp csv_sort_num_sigint_b
    bcs +
    jmp csv_sort_num_mag_less
+
    beq +
    jmp csv_sort_num_mag_greater
+

    ; Same count of significant integer digits.
    ldx csv_sort_num_leadzero_a
    ldy csv_sort_num_leadzero_b
    lda csv_sort_num_sigint_a
    sta csv_sort_num_count
csv_sort_num_mag_int_loop:
    lda csv_sort_num_count
    beq csv_sort_num_mag_fraction
    lda csv_sort_num_buf_a,x
    cmp csv_sort_num_buf_b,y
    bcc csv_sort_num_mag_less
    bne csv_sort_num_mag_greater
    inx
    iny
    dec csv_sort_num_count
    jmp csv_sort_num_mag_int_loop

csv_sort_num_mag_fraction:
    lda #0
    sta csv_sort_num_frac_index
csv_sort_num_mag_frac_loop:
    ; stop when index >= both fractional lengths.
    lda csv_sort_num_frac_index
    cmp csv_sort_num_fraclen_a
    bcc csv_sort_num_mag_frac_have
    cmp csv_sort_num_fraclen_b
    bcc csv_sort_num_mag_frac_have
    lda #0
    sta csv_sort_num_mag_result
    rts

csv_sort_num_mag_frac_have:
    ; A fractional digit or implicit zero.
    lda csv_sort_num_frac_index
    cmp csv_sort_num_fraclen_a
    bcc csv_sort_num_mag_get_a
    lda #'0'
    sta csv_sort_num_digit_a
    jmp csv_sort_num_mag_get_b
csv_sort_num_mag_get_a:
    clc
    adc csv_sort_num_intlen_a
    tax
    lda csv_sort_num_buf_a,x
    sta csv_sort_num_digit_a

csv_sort_num_mag_get_b:
    lda csv_sort_num_frac_index
    cmp csv_sort_num_fraclen_b
    bcc csv_sort_num_mag_real_b
    lda #'0'
    sta csv_sort_num_digit_b
    jmp csv_sort_num_mag_compare_frac
csv_sort_num_mag_real_b:
    clc
    adc csv_sort_num_intlen_b
    tax
    lda csv_sort_num_buf_b,x
    sta csv_sort_num_digit_b

csv_sort_num_mag_compare_frac:
    lda csv_sort_num_digit_a
    cmp csv_sort_num_digit_b
    bcc csv_sort_num_mag_less
    bne csv_sort_num_mag_greater
    inc csv_sort_num_frac_index
    jmp csv_sort_num_mag_frac_loop

csv_sort_num_mag_less:
    lda #0xff
    sta csv_sort_num_mag_result
    rts
csv_sort_num_mag_greater:
    lda #1
    sta csv_sort_num_mag_result
    rts


; Locate selected column for A.
csv_sort_field_ptr_a:
    lda csv_sort_rowa0
    sta csv_row0
    lda csv_sort_rowa1
    sta csv_row1
    jsr csvrowaddr
    lda attic_addr0
    sta csv_sort_pa0
    lda attic_addr1
    sta csv_sort_pa1
    lda attic_addr2
    sta csv_sort_pa2
    lda attic_addr3
    sta csv_sort_pa3
    lda #0
    sta csv_sort_ca
    sta csv_sort_a_inq
    sta csv_sort_a_qp
    sta csv_sort_a_data
    sta csv_sort_a_end
sort_seek_a$:
    lda csv_sort_ca
    cmp OVL_CURCOL
    beq sort_seek_a_done$
    jsr csv_sort_class_a
    cmp #2
    beq sort_seek_a_missing$
    cmp #1
    bne +
    inc csv_sort_ca
+
    jsr csv_sort_inc_pa
    jmp sort_seek_a$
sort_seek_a_missing$:
    lda #1
    sta csv_sort_a_end
sort_seek_a_done$:
    rts

csv_sort_field_ptr_b:
    lda csv_sort_rowb0
    sta csv_row0
    lda csv_sort_rowb1
    sta csv_row1
    jsr csvrowaddr
    lda attic_addr0
    sta csv_sort_pb0
    lda attic_addr1
    sta csv_sort_pb1
    lda attic_addr2
    sta csv_sort_pb2
    lda attic_addr3
    sta csv_sort_pb3
    lda #0
    sta csv_sort_cb
    sta csv_sort_b_inq
    sta csv_sort_b_qp
    sta csv_sort_b_data
    sta csv_sort_b_end
sort_seek_b$:
    lda csv_sort_cb
    cmp OVL_CURCOL
    beq sort_seek_b_done$
    jsr csv_sort_class_b
    cmp #2
    beq sort_seek_b_missing$
    cmp #1
    bne +
    inc csv_sort_cb
+
    jsr csv_sort_inc_pb
    jmp sort_seek_b$
sort_seek_b_missing$:
    lda #1
    sta csv_sort_b_end
sort_seek_b_done$:
    rts

csv_sort_next_a:
    lda csv_sort_a_end
    beq +
    rts
+
sort_next_a_loop$:
    jsr csv_sort_class_a
    cmp #1
    beq sort_next_a_end$
    cmp #2
    beq sort_next_a_end$
    cmp #3
    beq sort_next_a_skip$
    ldz #0
    lda [csv_sort_pa0],z
    sta csv_sort_a_char
    jsr csv_sort_inc_pa
    lda #0
    sta csv_sort_a_end
    rts
sort_next_a_skip$:
    jsr csv_sort_inc_pa
    jmp sort_next_a_loop$
sort_next_a_end$:
    lda #1
    sta csv_sort_a_end
    rts

csv_sort_next_b:
    lda csv_sort_b_end
    beq +
    rts
+
sort_next_b_loop$:
    jsr csv_sort_class_b
    cmp #1
    beq sort_next_b_end$
    cmp #2
    beq sort_next_b_end$
    cmp #3
    beq sort_next_b_skip$
    ldz #0
    lda [csv_sort_pb0],z
    sta csv_sort_b_char
    jsr csv_sort_inc_pb
    lda #0
    sta csv_sort_b_end
    rts
sort_next_b_skip$:
    jsr csv_sort_inc_pb
    jmp sort_next_b_loop$
sort_next_b_end$:
    lda #1
    sta csv_sort_b_end
    rts

; Quote-aware classifiers.
csv_sort_class_a:
    lda csv_sort_a_inq
    beq sort_a_out$
    lda csv_sort_a_qp
    beq sort_a_inside$
    ldz #0
    lda [csv_sort_pa0],z
    cmp #0x22
    bne sort_a_close$
    lda #0
    sta csv_sort_a_qp
    lda #0
    rts
sort_a_close$:
    lda #0
    sta csv_sort_a_qp
    sta csv_sort_a_inq
    jmp sort_a_process$
sort_a_inside$:
    ldz #0
    lda [csv_sort_pa0],z
    cmp #0x22
    bne sort_a_content$
    lda #1
    sta csv_sort_a_qp
    lda #3
    rts
sort_a_content$:
    lda #1
    sta csv_sort_a_data
    lda #0
    rts
sort_a_out$:
    ldz #0
    lda [csv_sort_pa0],z
    cmp #0x22
    bne sort_a_process$
    lda csv_sort_a_data
    bne sort_a_content$
    lda #1
    sta csv_sort_a_inq
    lda #3
    rts
sort_a_process$:
    ldz #0
    lda [csv_sort_pa0],z
    cmp OVL_DELIMITER
    beq sort_a_comma$
    cmp #0x0d
    beq sort_a_endrow$
    lda #1
    sta csv_sort_a_data
    lda #0
    rts
sort_a_comma$:
    lda #0
    sta csv_sort_a_data
    lda #1
    rts
sort_a_endrow$:
    lda #2
    rts

csv_sort_class_b:
    lda csv_sort_b_inq
    beq sort_b_out$
    lda csv_sort_b_qp
    beq sort_b_inside$
    ldz #0
    lda [csv_sort_pb0],z
    cmp #0x22
    bne sort_b_close$
    lda #0
    sta csv_sort_b_qp
    lda #0
    rts
sort_b_close$:
    lda #0
    sta csv_sort_b_qp
    sta csv_sort_b_inq
    jmp sort_b_process$
sort_b_inside$:
    ldz #0
    lda [csv_sort_pb0],z
    cmp #0x22
    bne sort_b_content$
    lda #1
    sta csv_sort_b_qp
    lda #3
    rts
sort_b_content$:
    lda #1
    sta csv_sort_b_data
    lda #0
    rts
sort_b_out$:
    ldz #0
    lda [csv_sort_pb0],z
    cmp #0x22
    bne sort_b_process$
    lda csv_sort_b_data
    bne sort_b_content$
    lda #1
    sta csv_sort_b_inq
    lda #3
    rts
sort_b_process$:
    ldz #0
    lda [csv_sort_pb0],z
    cmp OVL_DELIMITER
    beq sort_b_comma$
    cmp #0x0d
    beq sort_b_endrow$
    lda #1
    sta csv_sort_b_data
    lda #0
    rts
sort_b_comma$:
    lda #0
    sta csv_sort_b_data
    lda #1
    rts
sort_b_endrow$:
    lda #2
    rts

; Index helpers.
csv_sort_swap_index_rows:
    jsr csv_sort_make_ia
    jsr csv_sort_make_ib
    ldz #0
    lda [csv_sort_ia0],z
    sta csv_sort_swap0
    inz
    lda [csv_sort_ia0],z
    sta csv_sort_swap1
    inz
    lda [csv_sort_ia0],z
    sta csv_sort_swap2
    inz
    lda [csv_sort_ia0],z
    sta csv_sort_swap3
    ldz #0
    lda [csv_sort_ib0],z
    sta [csv_sort_ia0],z
    inz
    lda [csv_sort_ib0],z
    sta [csv_sort_ia0],z
    inz
    lda [csv_sort_ib0],z
    sta [csv_sort_ia0],z
    inz
    lda [csv_sort_ib0],z
    sta [csv_sort_ia0],z
    ldz #0
    lda csv_sort_swap0
    sta [csv_sort_ib0],z
    inz
    lda csv_sort_swap1
    sta [csv_sort_ib0],z
    inz
    lda csv_sort_swap2
    sta [csv_sort_ib0],z
    inz
    lda csv_sort_swap3
    sta [csv_sort_ib0],z
    rts

csv_sort_get_index_offset_a:
    jsr csv_sort_make_ia
    ldz #0
    lda [csv_sort_ia0],z
    sta csv_sort_offa0
    inz
    lda [csv_sort_ia0],z
    sta csv_sort_offa1
    inz
    lda [csv_sort_ia0],z
    sta csv_sort_offa2
    inz
    lda [csv_sort_ia0],z
    sta csv_sort_offa3
    rts

csv_sort_make_ia:
    lda csv_sort_rowa0
    sta csv_sort_tmp0
    lda csv_sort_rowa1
    sta csv_sort_tmp1
    jmp csv_sort_make_idx_common_a
csv_sort_make_idx_common_a:
    lda #0
    sta csv_sort_tmp2
    asl csv_sort_tmp0
    rol csv_sort_tmp1
    rol csv_sort_tmp2
    asl csv_sort_tmp0
    rol csv_sort_tmp1
    rol csv_sort_tmp2
    lda csv_sort_tmp0
    sta csv_sort_ia0
    lda csv_sort_tmp1
    sta csv_sort_ia1
    lda csv_sort_tmp2
    clc
    adc #0x10
    sta csv_sort_ia2
    lda #0x08
    adc #0
    sta csv_sort_ia3
    rts

csv_sort_make_ib:
    lda csv_sort_rowb0
    sta csv_sort_tmp0
    lda csv_sort_rowb1
    sta csv_sort_tmp1
    lda #0
    sta csv_sort_tmp2
    asl csv_sort_tmp0
    rol csv_sort_tmp1
    rol csv_sort_tmp2
    asl csv_sort_tmp0
    rol csv_sort_tmp1
    rol csv_sort_tmp2
    lda csv_sort_tmp0
    sta csv_sort_ib0
    lda csv_sort_tmp1
    sta csv_sort_ib1
    lda csv_sort_tmp2
    clc
    adc #0x10
    sta csv_sort_ib2
    lda #0x08
    adc #0
    sta csv_sort_ib3
    rts

; Pointer helpers.
csv_sort_src_at_end:
    lda csv_sort_src0
    cmp OVL_SIZE0
    bne sort_ptr_no$
    lda csv_sort_src1
    cmp OVL_SIZE1
    bne sort_ptr_no$
    lda csv_sort_src2
    cmp OVL_SIZE2
    bne sort_ptr_no$
    lda csv_sort_src3
    sec
    sbc #0x08
    cmp OVL_SIZE3
    bne sort_ptr_no$
    lda #1
    rts
sort_ptr_no$:
    lda #0
    rts

csv_sort_inc_pa:
    inc csv_sort_pa0
    bne sort_inc_pa_done$
    inc csv_sort_pa1
    bne sort_inc_pa_done$
    inc csv_sort_pa2
    bne sort_inc_pa_done$
    inc csv_sort_pa3
sort_inc_pa_done$:
    rts
csv_sort_inc_pb:
    inc csv_sort_pb0
    bne sort_inc_pb_done$
    inc csv_sort_pb1
    bne sort_inc_pb_done$
    inc csv_sort_pb2
    bne sort_inc_pb_done$
    inc csv_sort_pb3
sort_inc_pb_done$:
    rts
csv_sort_inc_src:
    inc csv_sort_src0
    bne sort_inc_src_done$
    inc csv_sort_src1
    bne sort_inc_src_done$
    inc csv_sort_src2
    bne sort_inc_src_done$
    inc csv_sort_src3
sort_inc_src_done$:
    rts
csv_sort_inc_dst:
    inc csv_sort_dst0
    bne sort_inc_dst_done$
    inc csv_sort_dst1
    bne sort_inc_dst_done$
    inc csv_sort_dst2
    bne sort_inc_dst_done$
    inc csv_sort_dst3
sort_inc_dst_done$:
    rts
csv_sort_dec_rem:
    lda csv_sort_rem0
    bne sort_dec0$
    lda csv_sort_rem1
    bne sort_dec1$
    lda csv_sort_rem2
    bne sort_dec2$
    dec csv_sort_rem3
sort_dec2$:
    dec csv_sort_rem2
sort_dec1$:
    dec csv_sort_rem1
sort_dec0$:
    dec csv_sort_rem0
    rts

    .section bss,bss
csv_sort_descending: .space 1
csv_sort_numeric: .space 1
csv_sort_length: .space 1
csv_sort_len_result: .space 1
csv_sort_len_a0: .space 1
csv_sort_len_a1: .space 1
csv_sort_len_b0: .space 1
csv_sort_len_b1: .space 1
csv_sort_num_fallback: .space 1
csv_sort_num_result: .space 1
csv_sort_num_mag_result: .space 1
csv_sort_num_valid_a: .space 1
csv_sort_num_valid_b: .space 1
csv_sort_num_sign_a: .space 1
csv_sort_num_sign_b: .space 1
csv_sort_num_nonzero_a: .space 1
csv_sort_num_nonzero_b: .space 1
csv_sort_num_intlen_a: .space 1
csv_sort_num_intlen_b: .space 1
csv_sort_num_fraclen_a: .space 1
csv_sort_num_fraclen_b: .space 1
csv_sort_num_buflen_a: .space 1
csv_sort_num_buflen_b: .space 1
csv_sort_num_leadzero_a: .space 1
csv_sort_num_leadzero_b: .space 1
csv_sort_num_sigint_a: .space 1
csv_sort_num_sigint_b: .space 1
csv_sort_num_phase: .space 1
csv_sort_num_sign_seen: .space 1
csv_sort_num_digits_seen: .space 1
csv_sort_num_parse_error: .space 1
csv_sort_num_char: .space 1
csv_sort_num_count: .space 1
csv_sort_num_frac_index: .space 1
csv_sort_num_digit_a: .space 1
csv_sort_num_digit_b: .space 1

; Numeric digit buffers (normal BSS, no Zero Page cost).
csv_sort_num_buf_a: .space 64
csv_sort_num_buf_b: .space 64
csv_sort_n0: .space 1
csv_sort_n1: .space 1
csv_sort_start0: .space 1
csv_sort_start1: .space 1
csv_sort_end0: .space 1
csv_sort_end1: .space 1
csv_sort_gap0: .space 1
csv_sort_gap1: .space 1
csv_sort_i0: .space 1
csv_sort_i1: .space 1
csv_sort_j0: .space 1
csv_sort_j1: .space 1
csv_sort_prev0: .space 1
csv_sort_prev1: .space 1
csv_sort_rowa0: .space 1
csv_sort_rowa1: .space 1
csv_sort_rowb0: .space 1
csv_sort_rowb1: .space 1
csv_sort_cmp: .space 1
csv_sort_ca: .space 1
csv_sort_cb: .space 1
csv_sort_a_inq: .space 1
csv_sort_a_qp: .space 1
csv_sort_a_data: .space 1
csv_sort_a_end: .space 1
csv_sort_b_inq: .space 1
csv_sort_b_qp: .space 1
csv_sort_b_data: .space 1
csv_sort_b_end: .space 1
csv_sort_a_char: .space 1
csv_sort_b_char: .space 1
csv_sort_a_char_saved: .space 1
csv_sort_a_end_saved: .space 1
csv_sort_fold_a: .space 1
csv_sort_fold_b: .space 1
csv_sort_swap0: .space 1
csv_sort_swap1: .space 1
csv_sort_swap2: .space 1
csv_sort_swap3: .space 1
csv_sort_offa0: .space 1
csv_sort_offa1: .space 1
csv_sort_offa2: .space 1
csv_sort_offa3: .space 1
csv_sort_tmp0: .space 1
csv_sort_tmp1: .space 1
csv_sort_tmp2: .space 1
csv_sort_byte: .space 1
csv_sort_rem0: .space 1
csv_sort_rem1: .space 1
csv_sort_rem2: .space 1
csv_sort_rem3: .space 1

    .section zzpage,bss

; ------------------------------------------------------------
; Sort engine pointers -- ZP optimized.
;
; The sort phases never need PA/IA/SRC at the same time, nor
; PB/IB/DST at the same time.  Reuse two physical 32-bit ZP
; pointers and expose aliases for the existing code.
;
; Before: 6 x 4-byte pointers = 24 bytes ZP
; Now:    2 x 4-byte pointers =  8 bytes ZP
; Saving:                    = 16 bytes ZP
; ------------------------------------------------------------
csv_sort_ptra0: .space 1
csv_sort_ptra1: .space 1
csv_sort_ptra2: .space 1
csv_sort_ptra3: .space 1

csv_sort_ptrb0: .space 1
csv_sort_ptrb1: .space 1
csv_sort_ptrb2: .space 1
csv_sort_ptrb3: .space 1

; A-side aliases: compare-row A / index A / materialise source.
csv_sort_pa0  .equ csv_sort_ptra0
csv_sort_pa1  .equ csv_sort_ptra1
csv_sort_pa2  .equ csv_sort_ptra2
csv_sort_pa3  .equ csv_sort_ptra3

csv_sort_ia0  .equ csv_sort_ptra0
csv_sort_ia1  .equ csv_sort_ptra1
csv_sort_ia2  .equ csv_sort_ptra2
csv_sort_ia3  .equ csv_sort_ptra3

csv_sort_src0 .equ csv_sort_ptra0
csv_sort_src1 .equ csv_sort_ptra1
csv_sort_src2 .equ csv_sort_ptra2
csv_sort_src3 .equ csv_sort_ptra3

; B-side aliases: compare-row B / index B / materialise destination.
csv_sort_pb0  .equ csv_sort_ptrb0
csv_sort_pb1  .equ csv_sort_ptrb1
csv_sort_pb2  .equ csv_sort_ptrb2
csv_sort_pb3  .equ csv_sort_ptrb3

csv_sort_ib0  .equ csv_sort_ptrb0
csv_sort_ib1  .equ csv_sort_ptrb1
csv_sort_ib2  .equ csv_sort_ptrb2
csv_sort_ib3  .equ csv_sort_ptrb3

csv_sort_dst0 .equ csv_sort_ptrb0
csv_sort_dst1 .equ csv_sort_ptrb1
csv_sort_dst2 .equ csv_sort_ptrb2
csv_sort_dst3 .equ csv_sort_ptrb3
