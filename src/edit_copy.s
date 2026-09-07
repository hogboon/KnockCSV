; ------------------------------------------------------------
; edit_copy.s - KnockCSV EDIT.PRG
;
; Multicell COPY performed entirely in the overlay.
; Source CSV remains at $08000000 and row index at $08100000.
; Shared selection/state is at $1F00..$1F17.
;
; Clipboard format at $08500000:
;   +0  $C5
;   +1  $65
;   +2  version = 1
;   +3  rows low
;   +4  rows high
;   +5  columns
;   +6... for every cell, row-major:
;        uint16 raw_length
;        raw CSV field bytes (quotes preserved)
; ------------------------------------------------------------

    .public edit_copy_multicell

OVL_MINROW0     .equ 0x1f10
OVL_MINROW1     .equ 0x1f11
OVL_MAXROW0     .equ 0x1f12
OVL_MAXROW1     .equ 0x1f13
OVL_MINCOL      .equ 0x1f14
OVL_MAXCOL      .equ 0x1f15
OVL_DELIMITER   .equ 0x1f06

CLIP0           .equ 0x00
CLIP1           .equ 0x00
CLIP2           .equ 0x50
CLIP3           .equ 0x08

    .section code,text

edit_copy_multicell:
    ; clipboard write pointer = $08500000
    lda #CLIP0
    sta ed_dst0
    lda #CLIP1
    sta ed_dst1
    lda #CLIP2
    sta ed_dst2
    lda #CLIP3
    sta ed_dst3

    lda #0xc5
    jsr ed_put_dst
    lda #0x65
    jsr ed_put_dst
    lda #1
    jsr ed_put_dst

    ; rows = maxrow - minrow + 1
    sec
    lda OVL_MAXROW0
    sbc OVL_MINROW0
    sta ed_rows0
    lda OVL_MAXROW1
    sbc OVL_MINROW1
    sta ed_rows1
    inc ed_rows0
    bne +
    inc ed_rows1
+
    lda ed_rows0
    jsr ed_put_dst
    lda ed_rows1
    jsr ed_put_dst

    ; cols = maxcol - mincol + 1
    sec
    lda OVL_MAXCOL
    sbc OVL_MINCOL
    clc
    adc #1
    sta ed_cols
    jsr ed_put_dst

    lda OVL_MINROW0
    sta ed_row0
    lda OVL_MINROW1
    sta ed_row1

ed_row_loop$:
    lda OVL_MINCOL
    sta ed_col

ed_col_loop$:
    jsr ed_find_cell_start
    bcs +
    jmp ed_copy_fail$
+

    ; Preserve start pointer.
    lda ed_ptr0
    sta ed_start0
    lda ed_ptr1
    sta ed_start1
    lda ed_ptr2
    sta ed_start2
    lda ed_ptr3
    sta ed_start3

    jsr ed_find_cell_end

    ; length = end - start (low 16 bits; cells are bounded by editor limits)
    sec
    lda ed_ptr0
    sbc ed_start0
    sta ed_len0
    lda ed_ptr1
    sbc ed_start1
    sta ed_len1

    lda ed_len0
    jsr ed_put_dst
    lda ed_len1
    jsr ed_put_dst

    ; copy raw field bytes start..end-1
    lda ed_start0
    sta ed_ptr0
    lda ed_start1
    sta ed_ptr1
    lda ed_start2
    sta ed_ptr2
    lda ed_start3
    sta ed_ptr3

ed_copy_bytes$:
    lda ed_ptr3
    cmp ed_end3
    bne ed_copy_byte$
    lda ed_ptr2
    cmp ed_end2
    bne ed_copy_byte$
    lda ed_ptr1
    cmp ed_end1
    bne ed_copy_byte$
    lda ed_ptr0
    cmp ed_end0
    beq ed_cell_done$

ed_copy_byte$:
    ldz #0
    lda [ed_ptr0],z
    jsr ed_put_dst
    jsr ed_inc_ptr
    jmp ed_copy_bytes$

ed_cell_done$:
    lda ed_col
    cmp OVL_MAXCOL
    beq ed_next_row$
    inc ed_col
    jmp ed_col_loop$

ed_next_row$:
    lda ed_row1
    cmp OVL_MAXROW1
    bne ed_inc_row$
    lda ed_row0
    cmp OVL_MAXROW0
    beq ed_copy_ok$

ed_inc_row$:
    inc ed_row0
    bne +
    inc ed_row1
+
    jmp ed_row_loop$

ed_copy_ok$:
    lda #1
    sta ed_result
    rts

ed_copy_fail$:
    lda #0
    sta ed_result
    ; invalidate clipboard magic
    lda #CLIP0
    sta ed_dst0
    lda #CLIP1
    sta ed_dst1
    lda #CLIP2
    sta ed_dst2
    lda #CLIP3
    sta ed_dst3
    lda #0
    ldz #0
    sta [ed_dst0],z
    rts

; ------------------------------------------------------------
; Find start of (ed_row, ed_col) using row index $08100000.
; C=1 success, ed_ptr = field start.
; ------------------------------------------------------------
ed_find_cell_start:
    ; index pointer = $08100000 + row*4
    lda ed_row0
    sta ed_tmp0
    lda ed_row1
    sta ed_tmp1
    lda #0
    sta ed_tmp2
    asl ed_tmp0
    rol ed_tmp1
    rol ed_tmp2
    asl ed_tmp0
    rol ed_tmp1
    rol ed_tmp2

    lda ed_tmp0
    sta ed_idx0
    lda ed_tmp1
    sta ed_idx1
    lda ed_tmp2
    clc
    adc #0x10
    sta ed_idx2
    lda #0x08
    adc #0
    sta ed_idx3

    ; read row relative offset
    ldz #0
    lda [ed_idx0],z
    sta ed_ptr0
    inz
    lda [ed_idx0],z
    sta ed_ptr1
    inz
    lda [ed_idx0],z
    sta ed_ptr2
    inz
    lda [ed_idx0],z
    clc
    adc #0x08
    sta ed_ptr3

    lda #0
    sta ed_scan_col
    sta ed_in_quotes
    lda #1
    sta ed_field_start

    lda ed_col
    bne ed_find_scan$
    sec
    rts

ed_find_scan$:
    ldz #0
    lda [ed_ptr0],z
    sta ed_ch

    lda ed_in_quotes
    beq ed_find_outside$

    lda ed_ch
    cmp #0x22
    bne ed_find_advance$

    ; quote inside quoted field: escaped if followed by another quote
    jsr ed_inc_ptr
    ldz #0
    lda [ed_ptr0],z
    cmp #0x22
    beq ed_find_advance$      ; escaped pair: consume second quote below
    lda #0
    sta ed_in_quotes
    jmp ed_find_scan$         ; process byte after closing quote

ed_find_outside$:
    lda ed_ch
    cmp #0x22
    bne ed_find_check_sep$
    lda ed_field_start
    beq ed_find_advance$
    lda #1
    sta ed_in_quotes
    lda #0
    sta ed_field_start
    jmp ed_find_advance$

ed_find_check_sep$:
    lda ed_ch
    cmp OVL_DELIMITER
    bne ed_find_check_eol$

    inc ed_scan_col
    jsr ed_inc_ptr
    lda ed_scan_col
    cmp ed_col
    beq ed_find_success$
    lda #1
    sta ed_field_start
    jmp ed_find_scan$

ed_find_check_eol$:
    cmp #0x0d
    beq ed_find_notfound$
    cmp #0x0a
    beq ed_find_notfound$
    lda #0
    sta ed_field_start

ed_find_advance$:
    jsr ed_inc_ptr
    jmp ed_find_scan$

ed_find_success$:
    sec
    rts
ed_find_notfound$:
    clc
    rts

; ------------------------------------------------------------
; Find end of current raw field. Input ed_ptr=start.
; Output ed_ptr=end, and ed_end mirrors it.
; ------------------------------------------------------------
ed_find_cell_end:
    lda #0
    sta ed_in_quotes
    lda #1
    sta ed_field_start

ed_end_scan$:
    ldz #0
    lda [ed_ptr0],z
    sta ed_ch

    lda ed_in_quotes
    beq ed_end_outside$
    lda ed_ch
    cmp #0x22
    bne ed_end_advance$

    jsr ed_inc_ptr
    ldz #0
    lda [ed_ptr0],z
    cmp #0x22
    beq ed_end_advance$       ; escaped quote pair
    lda #0
    sta ed_in_quotes
    jmp ed_end_scan$          ; process byte after closing quote

ed_end_outside$:
    lda ed_ch
    cmp #0x22
    bne ed_end_check_sep$
    lda ed_field_start
    beq ed_end_advance$
    lda #1
    sta ed_in_quotes
    lda #0
    sta ed_field_start
    jmp ed_end_advance$

ed_end_check_sep$:
    lda ed_ch
    cmp OVL_DELIMITER
    beq ed_end_found$
    cmp #0x0d
    beq ed_end_found$
    cmp #0x0a
    beq ed_end_found$
    lda #0
    sta ed_field_start

ed_end_advance$:
    jsr ed_inc_ptr
    jmp ed_end_scan$

ed_end_found$:
    lda ed_ptr0
    sta ed_end0
    lda ed_ptr1
    sta ed_end1
    lda ed_ptr2
    sta ed_end2
    lda ed_ptr3
    sta ed_end3
    rts

; A -> [ed_dst], dst++
ed_put_dst:
    ldz #0
    sta [ed_dst0],z
    inc ed_dst0
    bne +
    inc ed_dst1
    bne +
    inc ed_dst2
    bne +
    inc ed_dst3
+
    rts

ed_inc_ptr:
    inc ed_ptr0
    bne +
    inc ed_ptr1
    bne +
    inc ed_ptr2
    bne +
    inc ed_ptr3
+
    rts

    .section zzpage,bss
ed_ptr0: .space 1
ed_ptr1: .space 1
ed_ptr2: .space 1
ed_ptr3: .space 1
ed_dst0: .space 1
ed_dst1: .space 1
ed_dst2: .space 1
ed_dst3: .space 1
ed_idx0: .space 1
ed_idx1: .space 1
ed_idx2: .space 1
ed_idx3: .space 1

    .section bss,bss
ed_row0: .space 1
ed_row1: .space 1
ed_col: .space 1
ed_rows0: .space 1
ed_rows1: .space 1
ed_cols: .space 1
ed_scan_col: .space 1
ed_in_quotes: .space 1
ed_field_start: .space 1
ed_ch: .space 1
ed_tmp0: .space 1
ed_tmp1: .space 1
ed_tmp2: .space 1
ed_start0: .space 1
ed_start1: .space 1
ed_start2: .space 1
ed_start3: .space 1
ed_end0: .space 1
ed_end1: .space 1
ed_end2: .space 1
ed_end3: .space 1
ed_len0: .space 1
ed_len1: .space 1
ed_result: .space 1
