; ------------------------------------------------------------
; edit_paste.s - KnockCSV EDIT.PRG
;
; Multicell PASTE performed entirely in the overlay.
;
; Original CSV : $08000000
; Clipboard    : $08500000
; Temp rebuild : $08600000
;
; Clipboard format (written by edit_copy.s):
;   +0  $C5
;   +1  $65
;   +2  version = 1
;   +3  rows low
;   +4  rows high
;   +5  columns
;   +6  repeated: uint16 raw_length + raw CSV bytes
;
; Destination is OVL_CURROW/OVL_CURCOL. Existing cells only are
; replaced. Cells extending past the current CSV bounds are ignored.
; ------------------------------------------------------------

    .public edit_paste_multicell

OVL_SIZE0       .equ 0x1f02
OVL_SIZE1       .equ 0x1f03
OVL_SIZE2       .equ 0x1f04
OVL_SIZE3       .equ 0x1f05
OVL_DELIMITER   .equ 0x1f06
OVL_CURROW0     .equ 0x1f0a
OVL_CURROW1     .equ 0x1f0b
OVL_CURCOL      .equ 0x1f0c

SRC0            .equ 0x00
SRC1            .equ 0x00
SRC2            .equ 0x00
SRC3            .equ 0x08

CLIP0           .equ 0x00
CLIP1           .equ 0x00
CLIP2           .equ 0x50
CLIP3           .equ 0x08

TMP0            .equ 0x00
TMP1            .equ 0x00
TMP2            .equ 0x60
TMP3            .equ 0x08

    .section code,text

edit_paste_multicell:

    ; Validate clipboard header.
    lda #CLIP0
    sta edp_clip0
    lda #CLIP1
    sta edp_clip1
    lda #CLIP2
    sta edp_clip2
    lda #CLIP3
    sta edp_clip3

    jsr edp_get_clip
    cmp #0xc5
    beq +
    rts
+
    jsr edp_get_clip
    cmp #0x65
    beq +
    rts
+
    jsr edp_get_clip
    cmp #1
    beq +
    rts
+

    jsr edp_get_clip
    sta edp_rows0
    jsr edp_get_clip
    sta edp_rows1
    jsr edp_get_clip
    sta edp_cols

    ; Empty/invalid clipboard geometry -> no change.
    lda edp_rows0
    ora edp_rows1
    bne +
    rts
+
    lda edp_cols
    bne +
    rts
+

    ; Source pointer = $08000000.
    lda #SRC0
    sta edp_src0
    lda #SRC1
    sta edp_src1
    lda #SRC2
    sta edp_src2
    lda #SRC3
    sta edp_src3

    ; Source end = $08000000 + OVL_SIZE.
    clc
    lda #SRC0
    adc OVL_SIZE0
    sta edp_srcend0
    lda #SRC1
    adc OVL_SIZE1
    sta edp_srcend1
    lda #SRC2
    adc OVL_SIZE2
    sta edp_srcend2
    lda #SRC3
    adc OVL_SIZE3
    sta edp_srcend3

    ; Temp destination = $08600000.
    lda #TMP0
    sta edp_dst0
    lda #TMP1
    sta edp_dst1
    lda #TMP2
    sta edp_dst2
    lda #TMP3
    sta edp_dst3

    lda #0
    sta edp_row0
    sta edp_row1
    sta edp_col

edp_field_loop$:
    jsr edp_src_at_end
    bcc +
    jmp edp_rebuild_done$
+

    ; Decide whether current CSV field belongs to paste rectangle.
    jsr edp_is_target
    bcc edp_copy_original$

    ; Replacement field: write next clipboard record, then skip old raw field.
    jsr edp_write_clip_cell
    bcs +
    ; Malformed/truncated clipboard: abort without replacing original CSV.
    rts
+
    lda #0
    sta edp_copy_mode
    jsr edp_scan_field
    jmp edp_boundary$

edp_copy_original$:
    lda #1
    sta edp_copy_mode
    jsr edp_scan_field

edp_boundary$:
    ; edp_scan_field stops with src pointing at delimiter/CR/LF or end.
    jsr edp_src_at_end
    bcc +
    jmp edp_field_loop$
+

    ldz #0
    lda [edp_src0],z
    cmp OVL_DELIMITER
    bne edp_boundary_cr$

    ; delimiter belongs to source structure; preserve it.
    jsr edp_copy_src_byte
    inc edp_col
    jmp edp_field_loop$

edp_boundary_cr$:
    cmp #0x0d
    bne edp_boundary_lf$

    jsr edp_copy_src_byte
    ; Preserve LF of CRLF pair, but count only one row break.
    jsr edp_src_at_end
    bcs edp_new_row$
    ldz #0
    lda [edp_src0],z
    cmp #0x0a
    bne edp_new_row$
    jsr edp_copy_src_byte
    jmp edp_new_row$

edp_boundary_lf$:
    cmp #0x0a
    bne edp_copy_weird_boundary$
    jsr edp_copy_src_byte
    jmp edp_new_row$

edp_copy_weird_boundary$:
    ; Defensive fallback: preserve unexpected byte and continue field scan.
    jsr edp_copy_src_byte
    jmp edp_field_loop$

edp_new_row$:
    lda #0
    sta edp_col
    inc edp_row0
    bne +
    inc edp_row1
+
    jmp edp_field_loop$

; ------------------------------------------------------------
; Rebuild complete. Save temp end, calculate new CSV size,
; then copy temp buffer back to $08000000.
; ------------------------------------------------------------
edp_rebuild_done$:

    lda edp_dst0
    sta edp_tempend0
    lda edp_dst1
    sta edp_tempend1
    lda edp_dst2
    sta edp_tempend2
    lda edp_dst3
    sta edp_tempend3

    ; new_size = temp_end - $08600000
    sec
    lda edp_tempend0
    sbc #TMP0
    sta OVL_SIZE0
    lda edp_tempend1
    sbc #TMP1
    sta OVL_SIZE1
    lda edp_tempend2
    sbc #TMP2
    sta OVL_SIZE2
    lda edp_tempend3
    sbc #TMP3
    sta OVL_SIZE3

    ; src = temp start, dst = CSV start
    lda #TMP0
    sta edp_src0
    lda #TMP1
    sta edp_src1
    lda #TMP2
    sta edp_src2
    lda #TMP3
    sta edp_src3

    lda #SRC0
    sta edp_dst0
    lda #SRC1
    sta edp_dst1
    lda #SRC2
    sta edp_dst2
    lda #SRC3
    sta edp_dst3

edp_copyback_loop$:
    lda edp_src3
    cmp edp_tempend3
    bne edp_copyback_byte$
    lda edp_src2
    cmp edp_tempend2
    bne edp_copyback_byte$
    lda edp_src1
    cmp edp_tempend1
    bne edp_copyback_byte$
    lda edp_src0
    cmp edp_tempend0
    beq edp_paste_ok$

edp_copyback_byte$:
    ldz #0
    lda [edp_src0],z
    sta [edp_dst0],z
    jsr edp_inc_src
    jsr edp_inc_dst
    jmp edp_copyback_loop$

edp_paste_ok$:
    rts

; ------------------------------------------------------------
; C=1 if current row/col is inside destination rectangle.
; Uses difference tests to avoid 16/8-bit overflow at rectangle end.
; ------------------------------------------------------------
edp_is_target:
    ; row must be >= destination row
    sec
    lda edp_row0
    sbc OVL_CURROW0
    sta edp_diff0
    lda edp_row1
    sbc OVL_CURROW1
    sta edp_diff1
    bcs +
    clc
    rts
+
    ; difference < clipboard rows
    lda edp_diff1
    cmp edp_rows1
    bcc edp_row_inside$
    bne edp_not_target$
    lda edp_diff0
    cmp edp_rows0
    bcc edp_row_inside$
    jmp edp_not_target$

edp_row_inside$:
    lda edp_col
    cmp OVL_CURCOL
    bcs +
    clc
    rts
+
    sec
    sbc OVL_CURCOL
    cmp edp_cols
    bcc edp_target$

edp_not_target$:
    clc
    rts
edp_target$:
    sec
    rts

; ------------------------------------------------------------
; Copy next clipboard cell raw bytes to temp destination.
; C=1 success.
; ------------------------------------------------------------
edp_write_clip_cell:
    jsr edp_get_clip
    sta edp_len0
    jsr edp_get_clip
    sta edp_len1

edp_write_clip_loop$:
    lda edp_len0
    ora edp_len1
    beq edp_write_clip_done$

    ldz #0
    lda [edp_clip0],z
    jsr edp_put_dst
    jsr edp_inc_clip

    lda edp_len0
    bne +
    dec edp_len1
+
    dec edp_len0
    jmp edp_write_clip_loop$

edp_write_clip_done$:
    sec
    rts

; ------------------------------------------------------------
; Scan one raw source field. Boundary itself is not consumed.
; edp_copy_mode=1 copies source raw bytes to temp; 0 skips them.
; Handles quoted fields, escaped quotes, embedded CR/LF/delimiters.
; ------------------------------------------------------------
edp_scan_field:
    lda #0
    sta edp_in_quotes
    lda #1
    sta edp_field_start

edp_scan_loop$:
    jsr edp_src_at_end
    bcc +
    rts
+
    ldz #0
    lda [edp_src0],z
    sta edp_ch

    lda edp_in_quotes
    beq edp_scan_outside$

    lda edp_ch
    cmp #0x22
    bne edp_consume_field_byte$

    ; Consume quote itself first.
    jsr edp_consume_byte
    jsr edp_src_at_end
    bcs edp_scan_quote_closed$

    ; Doubled quote inside quoted field: consume second quote and stay quoted.
    ldz #0
    lda [edp_src0],z
    cmp #0x22
    bne edp_scan_quote_closed$
    jsr edp_consume_byte
    jmp edp_scan_loop$

edp_scan_quote_closed$:
    lda #0
    sta edp_in_quotes
    jmp edp_scan_loop$

edp_scan_outside$:
    lda edp_ch
    cmp #0x22
    bne edp_scan_check_boundary$
    lda edp_field_start
    beq edp_consume_field_byte$
    lda #1
    sta edp_in_quotes
    lda #0
    sta edp_field_start
    jsr edp_consume_byte
    jmp edp_scan_loop$

edp_scan_check_boundary$:
    lda edp_ch
    cmp OVL_DELIMITER
    beq edp_scan_done
    cmp #0x0d
    beq edp_scan_done
    cmp #0x0a
    beq edp_scan_done
    lda #0
    sta edp_field_start

edp_consume_field_byte$:
    jsr edp_consume_byte
    jmp edp_scan_loop$

; True subroutine used from quoted-field paths.
; Consumes exactly one source byte and RETURNS to the caller.
edp_consume_byte:
    lda edp_copy_mode
    beq +
    ldz #0
    lda [edp_src0],z
    jsr edp_put_dst
+
    jsr edp_inc_src
    rts

edp_scan_done:
    rts

; ------------------------------------------------------------
; Helpers
; ------------------------------------------------------------

; C=1 if source pointer >= source end, else C=0.
edp_src_at_end:
    lda edp_src3
    cmp edp_srcend3
    bcc edp_src_not_end$
    bne edp_src_end$
    lda edp_src2
    cmp edp_srcend2
    bcc edp_src_not_end$
    bne edp_src_end$
    lda edp_src1
    cmp edp_srcend1
    bcc edp_src_not_end$
    bne edp_src_end$
    lda edp_src0
    cmp edp_srcend0
    bcc edp_src_not_end$
edp_src_end$:
    sec
    rts
edp_src_not_end$:
    clc
    rts

; Copy current source byte to dst, then src++ and dst++.
edp_copy_src_byte:
    ldz #0
    lda [edp_src0],z
    jsr edp_put_dst
    jsr edp_inc_src
    rts

; Read A=[clip], clip++.
edp_get_clip:
    ldz #0
    lda [edp_clip0],z
    pha
    jsr edp_inc_clip
    pla
    rts

; A -> [dst], dst++.
edp_put_dst:
    ; Safety: temp rebuild may never cross into $08700000.
    ; If it does, abort this write path by pinning dst at the limit.
    pha
    lda edp_dst3
    cmp #0x08
    bne edp_put_abort$
    lda edp_dst2
    cmp #0x70
    bcs edp_put_abort$
    pla
    ldz #0
    sta [edp_dst0],z
    jmp edp_inc_dst
edp_put_abort$:
    pla
    ; Force source to end so the outer rebuild terminates safely.
    lda edp_srcend0
    sta edp_src0
    lda edp_srcend1
    sta edp_src1
    lda edp_srcend2
    sta edp_src2
    lda edp_srcend3
    sta edp_src3
    rts

edp_inc_src:
    inc edp_src0
    bne +
    inc edp_src1
    bne +
    inc edp_src2
    bne +
    inc edp_src3
+
    rts

edp_inc_dst:
    inc edp_dst0
    bne +
    inc edp_dst1
    bne +
    inc edp_dst2
    bne +
    inc edp_dst3
+
    rts

edp_inc_clip:
    inc edp_clip0
    bne +
    inc edp_clip1
    bne +
    inc edp_clip2
    bne +
    inc edp_clip3
+
    rts

    .section zzpage,bss
edp_src0:       .space 1
edp_src1:       .space 1
edp_src2:       .space 1
edp_src3:       .space 1
edp_dst0:       .space 1
edp_dst1:       .space 1
edp_dst2:       .space 1
edp_dst3:       .space 1
edp_clip0:      .space 1
edp_clip1:      .space 1
edp_clip2:      .space 1
edp_clip3:      .space 1

    .section bss,bss
edp_srcend0:    .space 1
edp_srcend1:    .space 1
edp_srcend2:    .space 1
edp_srcend3:    .space 1
edp_tempend0:   .space 1
edp_tempend1:   .space 1
edp_tempend2:   .space 1
edp_tempend3:   .space 1
edp_row0:       .space 1
edp_row1:       .space 1
edp_col:        .space 1
edp_rows0:      .space 1
edp_rows1:      .space 1
edp_cols:       .space 1
edp_diff0:      .space 1
edp_diff1:      .space 1
edp_len0:       .space 1
edp_len1:       .space 1
edp_copy_mode:  .space 1
edp_in_quotes:  .space 1
edp_field_start:.space 1
edp_ch:         .space 1
