;
; ------------------------------------------------------------
; csvprintrow.s
; KnockCSV
;
; Stampa una riga CSV in colonne fisse.
;
; INPUT:
;   csv_row0
;   csv_row1
;
; Colonne:
;   larghezza fissa = 16 caratteri
;
; Termina su:
;   - CR
;   - LF
;   - fine fisica del file CSV
;
; IMPORTANTE:
;   BSOUT/KERNAL puo' usare locazioni di zero page.
;   attic_addr0..3 vengono quindi salvati e ripristinati
;   attorno ad ogni chiamata a BSOUT.
;
; Questa versione gestisce campi CSV quotati:
;   - virgole e newline dentro quote sono contenuto
;   - "" viene mostrato come un singolo quote
;   - newline interno viene mostrato come spazio
; ------------------------------------------------------------

    .public csvprintrow
    .public csvprintrow_scrollable
    .public csv_print_limit_cols

    .extern csvrowaddr

    .extern attic_addr0
    .extern attic_addr1
    .extern attic_addr2
    .extern attic_addr3

    .extern attic_val0
    .extern attic_read8

    .extern csv_size0
    .extern csv_size1
    .extern csv_size2
    .extern csv_size3

    .extern csv_left_col
    .extern csv_frozen_cols

bsout       .equ 0xffd2

ROW_HEADER_WIDTH .equ 6
DATA_START_X     .equ 6
SCREEN_DATA_COLS .equ 73   ; max total width from x=6: physical x=6..78
MIN_COL_WIDTH    .equ 4
MAX_COL_WIDTH    .equ 24

    .extern seam_bsout
    .extern seam_apply_cell_style
    .extern seam_apply_cell_alt_style

    .extern csv_delimiter

    .section code,text


; ------------------------------------------------------------
; void csvprintrow(void)
; ------------------------------------------------------------

csvprintrow:

    lda csv_print_limit_cols
    bne +
    lda #SCREEN_DATA_COLS
    sta csv_print_limit_cols
+
    jsr calc_end_addr

    lda #0
    sta screen_pos

    ; --------------------------------------------------------
    ; PASS 1: frozen columns 0..1.
    ; --------------------------------------------------------
    jsr csvrowaddr
    jsr csvpr_reset

    lda #0
    sta print_col
    sta col_pos
    sta print_col_width

    ; With zero frozen columns, skip PASS 1 completely.
    ; Previously frozen_loop$ was entered once unconditionally,
    ; so column 0 was drawn here and then again by PASS 2.
    lda csv_frozen_cols
    bne +
    jmp frozen_done$
+

frozen_loop$:
    jsr at_end
    beq +
    jmp frozen_done$
+

    jsr attic_read8
    jsr csvpr_classify
    cmp #2
    bne +
    jmp frozen_done$
+
    cmp #1
    beq frozen_end_cell$
    cmp #3
    beq frozen_next_byte$

    ; Testo entro width-1.
    lda print_col_width
    bne frozen_have_width$

    jsr load_print_col_width

frozen_have_width$:
    lda print_col_width
    sec
    sbc #1
    cmp col_pos
    beq frozen_next_byte$
    bcc frozen_next_byte$

    lda screen_pos
    cmp csv_print_limit_cols
    bcc +
    jmp end_row$
+

    ; Never let frozen columns cross the current pane boundary.
    ; This is especially important for the right vertical pane:
    ; starting at X=44, an overflow past X=79 would wrap to X=0
    ; of the next screen row and overwrite the row-number gutter.
    lda screen_pos
    cmp csv_print_limit_cols
    bcc +
    jmp end_row$
+
    lda csvpr_out_char
    jsr safe_bsout
    inc col_pos
    inc screen_pos

frozen_next_byte$:
    jsr inc_attic_ptr
    jmp frozen_loop$


frozen_end_cell$:
    ; Assicura width caricata.
    lda print_col_width
    bne frozen_pad$
    jsr load_print_col_width

frozen_pad$:
    lda col_pos
    cmp print_col_width
    bcs frozen_next_cell$

    lda screen_pos
    cmp csv_print_limit_cols
    bcc +
    jmp end_row$
+
    lda #' '
    jsr safe_bsout
    inc col_pos
    inc screen_pos
    jmp frozen_pad$

frozen_next_cell$:
    inc print_col
    lda print_col
    cmp csv_frozen_cols
    bcs frozen_done$

    lda #0
    sta col_pos
    sta print_col_width

    jsr inc_attic_ptr
    jmp frozen_loop$


frozen_done$:
    ; Se la riga aveva meno di csv_frozen_cols celle, completa
    ; comunque lo spazio frozen usando le widths note.
frozen_fill_missing$:
    lda print_col
    cmp csv_frozen_cols
    bcs scroll_pass_start$

    lda #0
    sta col_pos
    sta print_col_width
    jsr load_print_col_width

frozen_fill_pad$:
    lda col_pos
    cmp print_col_width
    bcs frozen_fill_next$

    lda screen_pos
    cmp csv_print_limit_cols
    bcc +
    jmp end_row$
+
    lda #' '
    jsr safe_bsout
    inc col_pos
    inc screen_pos
    jmp frozen_fill_pad$

frozen_fill_next$:
    inc print_col
    jmp frozen_fill_missing$


    ; --------------------------------------------------------
    ; PASS 2: scrollable columns starting at csv_left_col.
    ; Rescan the same row from its beginning.
    ; --------------------------------------------------------
scroll_pass_start$:
    jsr csvrowaddr
    jsr csvpr_reset

    lda #0
    sta skip_col

scroll_skip$:
    lda skip_col
    cmp csv_left_col
    beq scroll_visible_start$

    jsr at_end
    beq +
    jmp end_row$
+

    jsr attic_read8
    jsr csvpr_classify
    cmp #2
    bne +
    jmp end_row$
+
    cmp #1
    bne scroll_skip_next$
    inc skip_col

scroll_skip_next$:
    jsr inc_attic_ptr
    jmp scroll_skip$


scroll_visible_start$:
    lda csv_left_col
    sta print_col
    lda #0
    sta col_pos
    sta print_col_width
    jsr load_print_col_width

    ; The first scrollable column is allowed to be clipped at the
    ; viewport edge. This is required in vertical split mode.


scroll_loop$:
    jsr at_end
    beq +
    jmp end_row$
+

    jsr attic_read8
    jsr csvpr_classify
    cmp #2
    beq scroll_row_end$
    cmp #1
    beq scroll_end_cell$
    cmp #3
    beq scroll_next_byte$

    lda print_col_width
    sec
    sbc #1
    cmp col_pos
    beq scroll_next_byte$
    bcc scroll_next_byte$

    ; Clip actual cell text at the pane boundary too.
    ; The first visible scrollable cell is intentionally allowed to be
    ; wider than the pane, so checking only its padding is not enough.
    lda screen_pos
    cmp csv_print_limit_cols
    bcc scroll_text_fits$
    jmp end_row$

scroll_text_fits$:
    lda csvpr_out_char
    jsr safe_bsout
    inc col_pos
    inc screen_pos

scroll_next_byte$:
    jsr inc_attic_ptr
    jmp scroll_loop$


scroll_end_cell$:
scroll_pad$:
    lda col_pos
    cmp print_col_width
    bcs scroll_next_cell$

    lda screen_pos
    cmp csv_print_limit_cols
    bcc +
    jmp end_row$
+
    lda #' '
    jsr safe_bsout
    inc col_pos
    inc screen_pos
    jmp scroll_pad$

scroll_next_cell$:
    lda #0
    sta col_pos

    inc print_col
    lda #0
    sta print_col_width
    jsr load_print_col_width

    ; Following columns are shown only when they fit completely.
    ; Ending exactly at the viewport edge is valid.
    clc
    lda screen_pos
    adc print_col_width
    cmp csv_print_limit_cols
    bcc scroll_next_fits$
    beq scroll_next_fits$
    jmp end_row$

scroll_next_fits$:
    jsr inc_attic_ptr
    jmp scroll_loop$
    
; ------------------------------------------------------------
; End of physical CSV row.
;
; The last cell has no delimiter after it, therefore it must
; still be padded to its full visual column width.
; ------------------------------------------------------------

scroll_row_end$:
    lda col_pos
    cmp print_col_width
    bcs end_row$

scroll_row_end_pad$:
    lda screen_pos
    cmp csv_print_limit_cols
    bcs end_row$

    lda #' '
    jsr safe_bsout

    inc col_pos
    inc screen_pos

    lda col_pos
    cmp print_col_width
    bcc scroll_row_end_pad$

end_row$:
    rts

    
; ------------------------------------------------------------
; csvpr_reset
; Reset parser quoted-field for a new scan of a row.
; ------------------------------------------------------------
csvpr_reset:
    lda #0
    sta csvpr_in_quotes
    sta csvpr_quote_pending
    sta csvpr_field_has_data
    sta csvpr_inside_cr
    rts


; ------------------------------------------------------------
; csvpr_classify
; INPUT:  attic_val0 = raw CSV byte
; OUTPUT: A = type
;          0 content, csvpr_out_char valid
;          1 comma delimiter
;          2 physical row end
;          3 syntax byte / skipped byte
; Preserves X/Y.
; ------------------------------------------------------------
csvpr_classify:
    lda csvpr_in_quotes
    bne +
    jmp csvpr_outside$
+

    lda csvpr_quote_pending
    beq csvpr_inside$

    lda attic_val0
    cmp #0x22
    bne csvpr_close_then_outside$
    ; doubled quote -> one visible quote
    lda #0
    sta csvpr_quote_pending
    lda #0x22
    sta csvpr_out_char
    lda #1
    sta csvpr_field_has_data
    lda #0
    rts

csvpr_close_then_outside$:
    lda #0
    sta csvpr_quote_pending
    sta csvpr_in_quotes
    ; classify same raw byte outside quotes
    jmp csvpr_outside_process$

csvpr_inside$:
    lda attic_val0
    cmp #0x22
    bne csvpr_inside_not_quote$
    lda #1
    sta csvpr_quote_pending
    lda #3
    rts

csvpr_inside_not_quote$:
    cmp #0x0d
    bne csvpr_inside_lf$
    ; Defensive: CR inside quotes is shown with the same return marker.
    lda #0x0a
    sta csvpr_out_char
    lda #1
    sta csvpr_inside_cr
    sta csvpr_field_has_data
    lda #0
    rts

csvpr_inside_lf$:
    cmp #0x0a
    bne csvpr_inside_char$
    lda csvpr_inside_cr
    beq csvpr_inside_lf_single$
    lda #0
    sta csvpr_inside_cr
    lda #3
    rts
csvpr_inside_lf_single$:
    ; Keep canonical embedded newline as $0A. seam_bsout renders it
    ; as the PETSCII return-marker glyph.
    lda #0x0a
    sta csvpr_out_char
    lda #1
    sta csvpr_field_has_data
    lda #0
    rts

csvpr_inside_char$:
    lda #0
    sta csvpr_inside_cr
    lda attic_val0
    sta csvpr_out_char
    lda #1
    sta csvpr_field_has_data
    lda #0
    rts

csvpr_outside$:
    lda attic_val0
    cmp #0x22
    bne csvpr_outside_process$
    lda csvpr_field_has_data
    bne csvpr_quote_plain$
    lda #1
    sta csvpr_in_quotes
    lda #0
    sta csvpr_quote_pending
    lda #3
    rts
csvpr_quote_plain$:
    lda #0x22
    sta csvpr_out_char
    lda #1
    sta csvpr_field_has_data
    lda #0
    rts

csvpr_outside_process$:
    lda attic_val0
    cmp csv_delimiter
    bne csvpr_check_cr$
    lda #0
    sta csvpr_field_has_data
    lda #1
    rts
csvpr_check_cr$:
    cmp #0x0d
    beq csvpr_row_end$
    cmp #0x0a
    bne csvpr_outside_char$
    ; Canonical embedded newline: render the return marker.
    lda #0x0a
    sta csvpr_out_char
    lda #1
    sta csvpr_field_has_data
    lda #0
    rts
csvpr_outside_char$:
    sta csvpr_out_char
    lda #1
    sta csvpr_field_has_data
    lda #0
    rts
csvpr_row_end$:
    lda #2
    rts


; ------------------------------------------------------------
; load_print_col_width
;
; print_col -> print_col_width
; tabella raw: $08200000 + print_col
; visuale: clamp(raw+1,4,24)
; ------------------------------------------------------------

load_print_col_width:
    ; Select alternating cell style from ABSOLUTE column number.
    ; Even columns use style_fg/bg_cell, odd columns use *_cell_alt.
    lda print_col
    and #0x01
    beq csvpr_style_even$

    jsr seam_apply_cell_alt_style
    jmp csvpr_style_done$

csvpr_style_even$:
    jsr seam_apply_cell_style

csvpr_style_done$:
    lda print_col
    sta colwidth_ptr0

    lda #0x00
    sta colwidth_ptr1

    lda #0x20
    sta colwidth_ptr2

    lda #0x08
    sta colwidth_ptr3

    ldz #0x00
    lda [colwidth_ptr0],z

    cmp #0x03
    bcs print_width_not_min$

    lda #MIN_COL_WIDTH
    sta print_col_width
    rts

print_width_not_min$:
    cmp #(MAX_COL_WIDTH - 1)
    bcc print_width_add$

    lda #MAX_COL_WIDTH
    sta print_col_width
    rts

print_width_add$:
    clc
    adc #0x01
    sta print_col_width
    rts


; ------------------------------------------------------------
; csvprintrow_scrollable
;
; Stampa SOLO la parte non frozen della riga corrente.
;
; INPUT impliciti:
;   csv_row0/1    = riga CSV da stampare
;   csv_left_col  = prima colonna scrollabile visibile
;
; Il cursore video deve essere gia' posizionato all'inizio
; dell'area scrollabile, cioe' dopo le due colonne frozen.
;
; screen_pos viene inizializzato alla larghezza complessiva
; delle due colonne frozen, cosi' i test di fine schermo
; restano identici a csvprintrow.
; ------------------------------------------------------------

csvprintrow_scrollable:
    lda csv_print_limit_cols
    bne +
    lda #SCREEN_DATA_COLS
    sta csv_print_limit_cols
+
    jsr calc_end_addr
    jsr csvrowaddr

    ; screen_pos counts only CSV data columns, never the fixed row-number gutter.
    ; Add only the columns that are really frozen.
    lda #0
    sta screen_pos
    sta print_col

scroll_only_frozen_width_loop$:
    lda print_col
    cmp csv_frozen_cols
    bcs scroll_only_frozen_width_done$

    lda #0
    sta print_col_width
    jsr load_print_col_width
    clc
    lda screen_pos
    adc print_col_width
    sta screen_pos

    inc print_col
    jmp scroll_only_frozen_width_loop$

scroll_only_frozen_width_done$:

    ; Rescan row from start and skip to csv_left_col.
    jsr csvrowaddr
    jsr csvpr_reset

    lda #0
    sta skip_col

scroll_only_skip$:
    lda skip_col
    cmp csv_left_col
    beq scroll_only_start$

    jsr at_end
    beq +
    jmp scroll_only_done$
+
    jsr attic_read8
    jsr csvpr_classify
    cmp #2
    bne +
    jmp scroll_only_row_end$
+
    cmp #1
    bne scroll_only_skip_next$

    inc skip_col

scroll_only_skip_next$:
    jsr inc_attic_ptr
    jmp scroll_only_skip$


scroll_only_start$:
    lda csv_left_col
    sta print_col

    lda #0
    sta col_pos
    sta print_col_width
    jsr load_print_col_width

    ; Prima colonna scrollabile deve entrare.
    clc
    lda screen_pos
    adc print_col_width
    cmp csv_print_limit_cols
    bcc scroll_only_loop$
    beq scroll_only_loop$
    jmp scroll_only_done$


scroll_only_loop$:
    jsr at_end
    beq +
    jmp scroll_only_row_end$
+
    jsr attic_read8
    jsr csvpr_classify
    cmp #2
    bne +
    jmp scroll_only_row_end$
+
    cmp #1
    beq scroll_only_end_cell$
    cmp #3
    beq scroll_only_next_byte$

    lda print_col_width
    sec
    sbc #1
    cmp col_pos
    beq scroll_only_next_byte$
    bcc scroll_only_next_byte$

    lda screen_pos
    cmp csv_print_limit_cols
    bcc scroll_only_text_fits$
    jmp scroll_only_done$

scroll_only_text_fits$:
    lda csvpr_out_char
    jsr safe_bsout
    inc col_pos
    inc screen_pos

scroll_only_next_byte$:
    jsr inc_attic_ptr
    jmp scroll_only_loop$


scroll_only_end_cell$:
scroll_only_pad$:
    lda col_pos
    cmp print_col_width
    bcs scroll_only_next_cell$

    lda #' '
    jsr safe_bsout
    inc col_pos
    inc screen_pos
    jmp scroll_only_pad$

scroll_only_next_cell$:
    lda #0
    sta col_pos

    inc print_col
    lda #0
    sta print_col_width
    jsr load_print_col_width

    clc
    lda screen_pos
    adc print_col_width
    cmp csv_print_limit_cols
    bcc scroll_only_continue$
    beq scroll_only_continue$
    jmp scroll_only_done$

scroll_only_continue$:
    jsr inc_attic_ptr
    jmp scroll_only_loop$
    
; ------------------------------------------------------------
; End of physical row: pad final visible cell.
; ------------------------------------------------------------

scroll_only_row_end$:
    lda col_pos
    cmp print_col_width
    bcs scroll_only_done$

scroll_only_row_end_pad$:
    lda screen_pos
    cmp csv_print_limit_cols
    bcs scroll_only_done$

    lda #' '
    jsr safe_bsout

    inc col_pos
    inc screen_pos

    lda col_pos
    cmp print_col_width
    bcc scroll_only_row_end_pad$

scroll_only_done$:
    rts


; ------------------------------------------------------------
; safe_bsout
;
; INPUT:
;   A = carattere PETSCII da stampare
;
; Protegge attic_addr0..3 da eventuali modifiche del KERNAL.
; ------------------------------------------------------------

safe_bsout:
    sta bsout_char

    lda attic_addr0
    sta save_addr0
    lda attic_addr1
    sta save_addr1
    lda attic_addr2
    sta save_addr2
    lda attic_addr3
    sta save_addr3

    lda bsout_char
    jsr seam_bsout

    lda save_addr0
    sta attic_addr0
    lda save_addr1
    sta attic_addr1
    lda save_addr2
    sta attic_addr2
    lda save_addr3
    sta attic_addr3
    rts


; ------------------------------------------------------------
; Calcola:
;   end_addr = 0x08000000 + csv_size
; ------------------------------------------------------------

calc_end_addr:

    lda csv_size0
    sta end_addr0

    lda csv_size1
    sta end_addr1

    lda csv_size2
    sta end_addr2

    lda csv_size3
    clc
    adc #0x08
    sta end_addr3

    rts


; ------------------------------------------------------------
; at_end
;
; ritorna:
;   A = 1 se attic_addr == end_addr
;   A = 0 altrimenti
; ------------------------------------------------------------

at_end:

    lda attic_addr0
    cmp end_addr0
    bne no$

    lda attic_addr1
    cmp end_addr1
    bne no$

    lda attic_addr2
    cmp end_addr2
    bne no$

    lda attic_addr3
    cmp end_addr3
    bne no$

    lda #0x01
    rts

no$:
    lda #0x00
    rts


; ------------------------------------------------------------
; attic_addr++
; ------------------------------------------------------------

inc_attic_ptr:

    inc attic_addr0
    bne done$

    inc attic_addr1
    bne done$

    inc attic_addr2
    bne done$

    inc attic_addr3

done$:
    rts


; ------------------------------------------------------------
; BSS
; ------------------------------------------------------------

    .section bss,bss

csvpr_in_quotes:      .space 1
csvpr_quote_pending:  .space 1
csvpr_field_has_data: .space 1
csvpr_inside_cr:      .space 1
csvpr_out_char:       .space 1

col_pos:
    .space 1

; Campi saltati prima della prima colonna visibile.
skip_col:
    .space 1

csv_print_limit_cols:
    .space 1

screen_pos:
    .space 1

print_col:
    .space 1

print_col_width:
    .space 1

end_addr0:
    .space 1
end_addr1:
    .space 1
end_addr2:
    .space 1
end_addr3:
    .space 1

save_addr0:
    .space 1
save_addr1:
    .space 1
save_addr2:
    .space 1
save_addr3:
    .space 1

bsout_char:
    .space 1


; ------------------------------------------------------------
; Zero page: puntatore temporaneo tabella larghezze
; ------------------------------------------------------------

    .section zzpage,bss

colwidth_ptr0:
    .space 1
colwidth_ptr1:
    .space 1
colwidth_ptr2:
    .space 1
colwidth_ptr3:
    .space 1
