;
; ------------------------------------------------------------
; edit_fill.s - KnockCSV EDIT.PRG
;
; Fill / Fill All implemented on top of the proven multicell
; Copy/Paste overlay primitives.
;
; Commands:
;   5  Fill Up
;   6  Fill Down
;   7  Fill Right
;   8  Fill Left
;   9  Fill All Up
;  10  Fill All Down
;  11  Fill All Right
;  12  Fill All Left
;
; The current cell is copied once to the normal overlay clipboard.
; For Fill All the single clipboard record is duplicated in-place to
; form a 1xN or Nx1 block, then one multicell Paste performs the fill.
; ------------------------------------------------------------

    .public edit_fill
    .extern edit_copy_multicell
    .extern edit_paste_multicell
    .extern busycursor_on
    .extern busycursor_off

OVL_COMMAND      .equ 0x1f01
OVL_CURROW0      .equ 0x1f0a
OVL_CURROW1      .equ 0x1f0b
OVL_CURCOL       .equ 0x1f0c
OVL_MINROW0      .equ 0x1f10
OVL_MINROW1      .equ 0x1f11
OVL_MAXROW0      .equ 0x1f12
OVL_MAXROW1      .equ 0x1f13
OVL_MINCOL       .equ 0x1f14
OVL_MAXCOL       .equ 0x1f15
OVL_ROWS0        .equ 0x1f1b
OVL_ROWS1        .equ 0x1f1c
OVL_MAXCOLS0     .equ 0x1f1d
OVL_MAXCOLS1     .equ 0x1f1e

CLIP0            .equ 0x00
CLIP1            .equ 0x00
CLIP2            .equ 0x50
CLIP3            .equ 0x08

    .section code,text

edit_fill:
    ; Only Fill All (commands 9..12) is potentially expensive.
    lda OVL_COMMAND
    cmp #9
    bcc edit_fill_impl
    jsr busycursor_on
    jsr edit_fill_impl
    jsr busycursor_off
    rts

edit_fill_impl:
    ; Preserve viewer selection bounds and source position.
    lda OVL_MINROW0
    sta ef_save_minr0
    lda OVL_MINROW1
    sta ef_save_minr1
    lda OVL_MAXROW0
    sta ef_save_maxr0
    lda OVL_MAXROW1
    sta ef_save_maxr1
    lda OVL_MINCOL
    sta ef_save_minc
    lda OVL_MAXCOL
    sta ef_save_maxc

    lda OVL_CURROW0
    sta ef_srcrow0
    lda OVL_CURROW1
    sta ef_srcrow1
    lda OVL_CURCOL
    sta ef_srccol

    ; Make Copy see exactly the current cell as a 1x1 selection.
    lda ef_srcrow0
    sta OVL_MINROW0
    sta OVL_MAXROW0
    lda ef_srcrow1
    sta OVL_MINROW1
    sta OVL_MAXROW1
    lda ef_srccol
    sta OVL_MINCOL
    sta OVL_MAXCOL
    jsr edit_copy_multicell

    ; Restore the visible selection bounds immediately.
    lda ef_save_minr0
    sta OVL_MINROW0
    lda ef_save_minr1
    sta OVL_MINROW1
    lda ef_save_maxr0
    sta OVL_MAXROW0
    lda ef_save_maxr1
    sta OVL_MAXROW1
    lda ef_save_minc
    sta OVL_MINCOL
    lda ef_save_maxc
    sta OVL_MAXCOL

    ; Default block is 1x1.
    lda #1
    sta ef_rows0
    lda #0
    sta ef_rows1
    lda #1
    sta ef_cols

    lda OVL_COMMAND
    cmp #9
    bcc ef_adjacent

    ; Fill All: direction = command - 9.
    sec
    sbc #9
    sta ef_dir
    jmp ef_compute_all

ef_adjacent:
    ; Adjacent: direction = command - 5.
    sec
    sbc #5
    sta ef_dir
    jsr ef_compute_adjacent
    bcs +
    jmp ef_done
+
    jmp ef_prepare_clip

; ------------------------------------------------------------
; Compute one-cell destination.
; C=1 valid, C=0 nothing to do.
; ------------------------------------------------------------
ef_compute_adjacent:
    lda ef_dir
    beq ef_adj_up
    cmp #1
    beq ef_adj_down
    cmp #2
    beq ef_adj_right
    jmp ef_adj_left

ef_adj_up:
    lda ef_srcrow0
    ora ef_srcrow1
    bne +
    jmp ef_invalid
+
    sec
    lda ef_srcrow0
    sbc #1
    sta OVL_CURROW0
    lda ef_srcrow1
    sbc #0
    sta OVL_CURROW1
    lda ef_srccol
    sta OVL_CURCOL
    sec
    rts

ef_adj_down:
    ; target = source row + 1, must be < row count
    clc
    lda ef_srcrow0
    adc #1
    sta ef_tmp0
    lda ef_srcrow1
    adc #0
    sta ef_tmp1

    lda ef_tmp1
    cmp OVL_ROWS1
    bcc ef_adj_down_ok
    bne ef_invalid
    lda ef_tmp0
    cmp OVL_ROWS0
    bcs ef_invalid
ef_adj_down_ok:
    lda ef_tmp0
    sta OVL_CURROW0
    lda ef_tmp1
    sta OVL_CURROW1
    lda ef_srccol
    sta OVL_CURCOL
    sec
    rts

ef_adj_right:
    lda OVL_MAXCOLS1
    bne ef_adj_right_ok_hi
    clc
    lda ef_srccol
    adc #1
    cmp OVL_MAXCOLS0
    bcs ef_invalid
    sta OVL_CURCOL
    lda ef_srcrow0
    sta OVL_CURROW0
    lda ef_srcrow1
    sta OVL_CURROW1
    sec
    rts
ef_adj_right_ok_hi:
    clc
    lda ef_srccol
    adc #1
    sta OVL_CURCOL
    lda ef_srcrow0
    sta OVL_CURROW0
    lda ef_srcrow1
    sta OVL_CURROW1
    sec
    rts

ef_adj_left:
    lda ef_srccol
    beq ef_invalid
    sec
    sbc #1
    sta OVL_CURCOL
    lda ef_srcrow0
    sta OVL_CURROW0
    lda ef_srcrow1
    sta OVL_CURROW1
    sec
    rts

ef_invalid:
    clc
    rts

; ------------------------------------------------------------
; Compute Fill All destination and dimensions.
; ------------------------------------------------------------
ef_compute_all:
    lda ef_dir
    beq ef_all_up
    cmp #1
    beq ef_all_down
    cmp #2
    beq ef_all_right
    jmp ef_all_left

ef_all_up:
    ; rows = source row, destination row = 0
    lda ef_srcrow0
    ora ef_srcrow1
    bne +
    jmp ef_done
+
    lda ef_srcrow0
    sta ef_rows0
    lda ef_srcrow1
    sta ef_rows1
    lda #1
    sta ef_cols
    lda #0
    sta OVL_CURROW0
    sta OVL_CURROW1
    lda ef_srccol
    sta OVL_CURCOL
    jmp ef_prepare_clip

ef_all_down:
    ; rows = total_rows - source_row - 1
    sec
    lda OVL_ROWS0
    sbc ef_srcrow0
    sta ef_rows0
    lda OVL_ROWS1
    sbc ef_srcrow1
    sta ef_rows1
    sec
    lda ef_rows0
    sbc #1
    sta ef_rows0
    lda ef_rows1
    sbc #0
    sta ef_rows1
    lda ef_rows0
    ora ef_rows1
    bne +
    jmp ef_done
+

    clc
    lda ef_srcrow0
    adc #1
    sta OVL_CURROW0
    lda ef_srcrow1
    adc #0
    sta OVL_CURROW1
    lda ef_srccol
    sta OVL_CURCOL
    lda #1
    sta ef_cols
    jmp ef_prepare_clip

ef_all_right:
    ; Clipboard format stores columns in one byte. KnockCSV current column
    ; is also one byte, so support the normal <=255-column case.
    lda OVL_MAXCOLS1
    bne ef_all_right_cap
    sec
    lda OVL_MAXCOLS0
    sbc ef_srccol
    sec
    sbc #1
    bne +
    jmp ef_done
+
    sta ef_cols
    lda #1
    sta ef_rows0
    lda #0
    sta ef_rows1
    clc
    lda ef_srccol
    adc #1
    sta OVL_CURCOL
    lda ef_srcrow0
    sta OVL_CURROW0
    lda ef_srcrow1
    sta OVL_CURROW1
    jmp ef_prepare_clip

ef_all_right_cap:
    ; With >255 columns, fill as far as the 8-bit clipboard can express.
    lda ef_srccol
    eor #0xff
    bne +
    jmp ef_done
+
    sta ef_cols
    lda #1
    sta ef_rows0
    lda #0
    sta ef_rows1
    clc
    lda ef_srccol
    adc #1
    sta OVL_CURCOL
    lda ef_srcrow0
    sta OVL_CURROW0
    lda ef_srcrow1
    sta OVL_CURROW1
    jmp ef_prepare_clip

ef_all_left:
    lda ef_srccol
    bne +
    jmp ef_done
+
    sta ef_cols
    lda #1
    sta ef_rows0
    lda #0
    sta ef_rows1
    lda #0
    sta OVL_CURCOL
    lda ef_srcrow0
    sta OVL_CURROW0
    lda ef_srcrow1
    sta OVL_CURROW1

; ------------------------------------------------------------
; Rewrite clipboard dimensions and duplicate the first 1x1 record
; until the requested block has all cells.
; ------------------------------------------------------------
ef_prepare_clip:
    ; Header rows/cols.
    ; Directly write header in Attic.
    lda #CLIP0
    sta ef_ptr0
    lda #CLIP1
    sta ef_ptr1
    lda #CLIP2
    sta ef_ptr2
    lda #CLIP3
    sta ef_ptr3

    ; +3 rows low, +4 rows high, +5 cols
    jsr ef_ptr_plus3
    ldz #0
    lda ef_rows0
    sta [ef_ptr0],z
    jsr ef_inc_ptr
    lda ef_rows1
    sta [ef_ptr0],z
    jsr ef_inc_ptr
    lda ef_cols
    sta [ef_ptr0],z

    ; total cell count = rows * cols.
    ; Fill blocks are either Nx1 or 1xN, so choose the non-one dimension.
    lda ef_cols
    cmp #1
    bne ef_count_cols
    lda ef_rows0
    sta ef_count0
    lda ef_rows1
    sta ef_count1
    jmp ef_have_count
ef_count_cols:
    lda ef_cols
    sta ef_count0
    lda #0
    sta ef_count1

ef_have_count:
    ; One record already exists.
    lda ef_count0
    ora ef_count1
    bne +
    jmp ef_done_restore
+
    sec
    lda ef_count0
    sbc #1
    sta ef_count0
    lda ef_count1
    sbc #0
    sta ef_count1
    lda ef_count0
    ora ef_count1
    bne +
    jmp ef_do_paste
+

    ; Fixed source record starts at $08500006.
    lda #0x06
    sta ef_rec0
    lda #0x00
    sta ef_rec1
    lda #0x50
    sta ef_rec2
    lda #0x08
    sta ef_rec3

    ; record length = uint16 length + 2.
    ldz #0
    lda [ef_rec0],z
    sta ef_reclen0
    jsr ef_inc_rec
    lda [ef_rec0],z
    sta ef_reclen1
    ; restore record pointer to +6
    lda #0x06
    sta ef_rec0

    clc
    lda ef_reclen0
    adc #2
    sta ef_reclen0
    lda ef_reclen1
    adc #0
    sta ef_reclen1

    ; Destination = record start + record length.
    clc
    lda #0x06
    adc ef_reclen0
    sta ef_dst0
    lda #0x00
    adc ef_reclen1
    sta ef_dst1
    lda #0x50
    adc #0
    sta ef_dst2
    lda #0x08
    adc #0
    sta ef_dst3

ef_dup_record:
    lda #0x06
    sta ef_src0
    lda #0x00
    sta ef_src1
    lda #0x50
    sta ef_src2
    lda #0x08
    sta ef_src3
    lda ef_reclen0
    sta ef_left0
    lda ef_reclen1
    sta ef_left1

ef_dup_byte:
    lda ef_left0
    ora ef_left1
    beq ef_dup_one_done
    ldz #0
    lda [ef_src0],z
    sta [ef_dst0],z
    jsr ef_inc_src
    jsr ef_inc_dst
    sec
    lda ef_left0
    sbc #1
    sta ef_left0
    lda ef_left1
    sbc #0
    sta ef_left1
    jmp ef_dup_byte

ef_dup_one_done:
    sec
    lda ef_count0
    sbc #1
    sta ef_count0
    lda ef_count1
    sbc #0
    sta ef_count1
    lda ef_count0
    ora ef_count1
    bne ef_dup_record

ef_do_paste:
    jsr edit_paste_multicell

ef_done_restore:
    ; Restore source cell as viewer current position.
    lda ef_srcrow0
    sta OVL_CURROW0
    lda ef_srcrow1
    sta OVL_CURROW1
    lda ef_srccol
    sta OVL_CURCOL
ef_done:
    rts

ef_ptr_plus3:
    jsr ef_inc_ptr
    jsr ef_inc_ptr
    jsr ef_inc_ptr
    rts

ef_inc_ptr:
    inc ef_ptr0
    bne +
    inc ef_ptr1
    bne +
    inc ef_ptr2
    bne +
    inc ef_ptr3
+
    rts

ef_inc_rec:
    inc ef_rec0
    bne +
    inc ef_rec1
    bne +
    inc ef_rec2
    bne +
    inc ef_rec3
+
    rts

ef_inc_src:
    inc ef_src0
    bne +
    inc ef_src1
    bne +
    inc ef_src2
    bne +
    inc ef_src3
+
    rts

ef_inc_dst:
    inc ef_dst0
    bne +
    inc ef_dst1
    bne +
    inc ef_dst2
    bne +
    inc ef_dst3
+
    rts

    .section zzpage,bss
ef_ptr0: .space 1
ef_ptr1: .space 1
ef_ptr2: .space 1
ef_ptr3: .space 1
ef_rec0: .space 1
ef_rec1: .space 1
ef_rec2: .space 1
ef_rec3: .space 1
ef_src0: .space 1
ef_src1: .space 1
ef_src2: .space 1
ef_src3: .space 1
ef_dst0: .space 1
ef_dst1: .space 1
ef_dst2: .space 1
ef_dst3: .space 1

    .section bss,bss
ef_save_minr0: .space 1
ef_save_minr1: .space 1
ef_save_maxr0: .space 1
ef_save_maxr1: .space 1
ef_save_minc: .space 1
ef_save_maxc: .space 1
ef_srcrow0: .space 1
ef_srcrow1: .space 1
ef_srccol: .space 1
ef_dir: .space 1
ef_rows0: .space 1
ef_rows1: .space 1
ef_cols: .space 1
ef_tmp0: .space 1
ef_tmp1: .space 1
ef_count0: .space 1
ef_count1: .space 1
ef_reclen0: .space 1
ef_reclen1: .space 1
ef_left0: .space 1
ef_left1: .space 1
