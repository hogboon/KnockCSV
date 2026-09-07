;
; ------------------------------------------------------------
; csvindex.s
; KnockCSV - scansione e indice righe
;
; CSV grezzo:
;   0x08000000
;
; Indice righe:
;   0x08100000
;
; Ogni voce dell'indice e' un offset a 32 bit little-endian
; relativo all'inizio del CSV.
;
; Esempio:
;   0x08100000 = offset riga 0
;   0x08100004 = offset riga 1
;   0x08100008 = offset riga 2
;
; Questa versione:
;   - conta le righe non vuote
;   - conta il massimo numero di colonne
;   - salva l'offset iniziale di ogni riga
;   - gestisce CR, LF e CRLF
;   - gestisce campi CSV quotati RFC-style
;   - virgole e CR/LF dentro "..." sono contenuto della cella
;   - "" dentro un campo quotato conta come un singolo carattere
; ------------------------------------------------------------

    .public csvindex
    ;.public csv_colwidth_get

    .public csv_rows0
    .public csv_rows1
    .public csv_maxcols0
    .public csv_maxcols1

    .extern csv_size0
    .extern csv_size1
    .extern csv_size2
    .extern csv_size3

    .extern attic_addr0
    .extern attic_addr1
    .extern attic_addr2
    .extern attic_addr3

    .extern attic_val0
    .extern attic_read8
    .extern attic_write8

    .extern csv_delimiter

    .section code,text
    
; ------------------------------------------------------------
; Tabella larghezze massime colonne in Attic RAM
; $08200000
; ------------------------------------------------------------

COLWIDTH_BASE0  .equ 0x00
COLWIDTH_BASE1  .equ 0x00
COLWIDTH_BASE2  .equ 0x20
COLWIDTH_BASE3  .equ 0x08

; ------------------------------------------------------------
; void csvindex(void)
; ------------------------------------------------------------

csvindex:
    jsr init_index

loop$:
    jsr remaining_is_zero
    bne +
    jmp eof$
+

    jsr attic_read8

    ; Preserve the current raw byte: helpers such as store_row_offset
    ; and update_current_col_width use attic_val0 as scratch.
    lda attic_val0
    sta csvidx_current_byte

    ; Open/index the physical CSV row on its first real byte.
    lda row_open
    bne csvidx_row_is_open$

    lda csvidx_current_byte
    cmp #0x0d
    beq csvidx_row_is_open$
    ; Canonical $0A can only be embedded content, but a valid row
    ; cannot begin with it outside a quoted field.
    cmp #0x0a
    beq csvidx_row_is_open$

    jsr store_row_offset
    lda #1
    sta row_open

csvidx_row_is_open$:
    lda csvidx_current_byte
    sta attic_val0

    ; --------------------------------------------------------
    ; Explicit CSV state machine.
    ;
    ; field_start   = 1 only before the first byte of a field.
    ; in_quotes     = currently inside a quoted field.
    ; quote_pending = previous byte was a quote while in_quotes.
    ; --------------------------------------------------------

    lda csvidx_in_quotes
    beq csvidx_outside$

    ; ----- inside quoted field -----
    lda csvidx_quote_pending
    beq csvidx_inside_normal$

    ; Previous byte was quote.
    lda csvidx_current_byte
    cmp #0x22
    beq csvidx_escaped_quote$

    ; It was a closing quote. Process THIS SAME byte outside.
    lda #0
    sta csvidx_quote_pending
    sta csvidx_in_quotes
    jmp csvidx_after_closing_quote$


csvidx_escaped_quote$:
    ; "" = one literal quote in the logical cell.
    lda #0
    sta csvidx_quote_pending
    inc current_col_len
    jmp next$


csvidx_inside_normal$:
    lda csvidx_current_byte
    cmp #0x22
    bne csvidx_inside_content$

    ; Could be closing quote or first half of "".
    lda #1
    sta csvidx_quote_pending
    jmp next$


csvidx_inside_content$:
    ; Canonical internal LF is an embedded newline and counts as one
    ; displayed character. CR should never occur inside quotes after
    ; loadcsv canonicalisation, but treat it as content defensively.
    inc current_col_len
    jmp next$


    ; ----- outside quoted field -----
csvidx_outside$:
    lda csvidx_current_byte

    ; A quote only opens quoted mode at true field start.
    cmp #0x22
    bne csvidx_outside_nonquote$

    lda csvidx_field_start
    beq csvidx_plain_quote$

    lda #1
    sta csvidx_in_quotes
    lda #0
    sta csvidx_quote_pending
    sta csvidx_field_start
    jmp next$


csvidx_plain_quote$:
    ; Quote occurring later in an unquoted field = ordinary content.
    inc current_col_len
    jmp next$


csvidx_outside_nonquote$:
    ; Delimiter.
    cmp csv_delimiter
    beq csvidx_delimiter$

    ; Real canonical row terminator.
    cmp #0x0d
    beq csvidx_row_end$

    ; Canonical LF = embedded cell newline, never row end.
    cmp #0x0a
    beq csvidx_plain_content$

    ; Any ordinary byte.
csvidx_plain_content$:
    lda #0
    sta csvidx_field_start
    inc current_col_len
    jmp next$


; A quoted field has just closed; classify the current byte.
csvidx_after_closing_quote$:
    lda csvidx_current_byte
    cmp csv_delimiter
    beq csvidx_delimiter$
    cmp #0x0d
    beq csvidx_row_end$

    ; Spaces or other non-standard bytes after closing quote are
    ; accepted as ordinary cell content rather than corrupting columns.
    cmp #0x0a
    beq csvidx_plain_content$
    jmp csvidx_plain_content$


csvidx_delimiter$:
    jsr update_current_col_width

    inc current_col
    lda #0
    sta current_col_len

    lda #1
    sta csvidx_field_start

    jsr inc_current_cols
    jmp next$


csvidx_row_end$:
    jsr finish_row
    jmp next$


next$:
    jsr inc_attic_ptr
    jsr inc_file_offset
    jsr dec_remaining
    jmp loop$


eof$:
    ; A pending quote at EOF is simply the closing quote.
    lda #0
    sta csvidx_quote_pending
    sta csvidx_in_quotes
    jsr finish_row
    rts


; ------------------------------------------------------------
; Inizializzazione
; ------------------------------------------------------------

init_index:
    lda #0x00

    sta csv_rows0
    sta csv_rows1

    sta csv_maxcols0
    sta csv_maxcols1

    sta current_cols0
    sta current_cols1

    sta row_open
    sta last_was_cr
    sta csvidx_in_quotes
    sta csvidx_quote_pending
    sta csvidx_inside_cr

    lda #1
    sta csvidx_field_start

    lda #0

    sta file_offset0
    sta file_offset1
    sta file_offset2
    sta file_offset3

    ; Puntatore scansione CSV = 0x08000000
    sta attic_addr0
    sta attic_addr1
    sta attic_addr2
    
	sta current_col
    sta current_col_len

    lda #0x08
    sta attic_addr3

    ; Puntatore indice righe = 0x08100000
    lda #0x00
    sta index_addr0
    sta index_addr1

    lda #0x10
    sta index_addr2

    lda #0x08
    sta index_addr3

    ; remaining = csv_size
    lda csv_size0
    sta remaining0

    lda csv_size1
    sta remaining1

    lda csv_size2
    sta remaining2

    lda csv_size3
    sta remaining3

    ; Una riga contenente dati parte da una colonna.
    lda #0x01
    sta current_cols0

    lda #0x00
    sta current_cols1
    
	jsr clear_colwidth_table

    rts
    
clear_colwidth_table:

    ; Salva puntatore.
    lda attic_addr0
    sta scan_save0
    lda attic_addr1
    sta scan_save1
    lda attic_addr2
    sta scan_save2
    lda attic_addr3
    sta scan_save3

    lda #COLWIDTH_BASE0
    sta attic_addr0
    lda #COLWIDTH_BASE1
    sta attic_addr1
    lda #COLWIDTH_BASE2
    sta attic_addr2
    lda #COLWIDTH_BASE3
    sta attic_addr3

    lda #0x00
    sta attic_val0

    ldx #0x00

clear_colwidth_loop$:
    jsr attic_write8
    jsr inc_attic_ptr

    inx
    bne clear_colwidth_loop$

    ; Ripristina.
    lda scan_save0
    sta attic_addr0
    lda scan_save1
    sta attic_addr1
    lda scan_save2
    sta attic_addr2
    lda scan_save3
    sta attic_addr3

    rts


; ------------------------------------------------------------
; Salva file_offset nell'indice righe.
;
; Usa attic_write8, quindi salva temporaneamente il puntatore
; corrente di scansione e lo ripristina alla fine.
; ------------------------------------------------------------

store_row_offset:

    ; Salva puntatore di scansione
    lda attic_addr0
    sta scan_save0

    lda attic_addr1
    sta scan_save1

    lda attic_addr2
    sta scan_save2

    lda attic_addr3
    sta scan_save3

    ; Carica puntatore indice
    lda index_addr0
    sta attic_addr0

    lda index_addr1
    sta attic_addr1

    lda index_addr2
    sta attic_addr2

    lda index_addr3
    sta attic_addr3

    ; Byte 0
    lda file_offset0
    sta attic_val0
    jsr attic_write8
    jsr inc_attic_ptr

    ; Byte 1
    lda file_offset1
    sta attic_val0
    jsr attic_write8
    jsr inc_attic_ptr

    ; Byte 2
    lda file_offset2
    sta attic_val0
    jsr attic_write8
    jsr inc_attic_ptr

    ; Byte 3
    lda file_offset3
    sta attic_val0
    jsr attic_write8
    jsr inc_attic_ptr

    ; Salva il nuovo puntatore dell'indice
    lda attic_addr0
    sta index_addr0

    lda attic_addr1
    sta index_addr1

    lda attic_addr2
    sta index_addr2

    lda attic_addr3
    sta index_addr3

    ; Ripristina puntatore di scansione
    lda scan_save0
    sta attic_addr0

    lda scan_save1
    sta attic_addr1

    lda scan_save2
    sta attic_addr2

    lda scan_save3
    sta attic_addr3

    rts


; ------------------------------------------------------------
; A = 0 se remaining == 0
; A != 0 altrimenti
; ------------------------------------------------------------

remaining_is_zero:
    lda remaining0
    ora remaining1
    ora remaining2
    ora remaining3
    rts


; ------------------------------------------------------------
; remaining--
; ------------------------------------------------------------

dec_remaining:
    sec

    lda remaining0
    sbc #0x01
    sta remaining0

    lda remaining1
    sbc #0x00
    sta remaining1

    lda remaining2
    sbc #0x00
    sta remaining2

    lda remaining3
    sbc #0x00
    sta remaining3

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
; file_offset++
; ------------------------------------------------------------

inc_file_offset:
    inc file_offset0
    bne done$

    inc file_offset1
    bne done$

    inc file_offset2
    bne done$

    inc file_offset3

done$:
    rts


; ------------------------------------------------------------
; current_cols++
; ------------------------------------------------------------

inc_current_cols:
    inc current_cols0
    bne done$

    inc current_cols1

done$:
    rts


; ------------------------------------------------------------
; Chiude la riga corrente.
;
; Le righe completamente vuote vengono ignorate.
; ------------------------------------------------------------

finish_row:
    lda row_open
    beq reset$
    
	jsr update_current_col_width

    ; rows++
    inc csv_rows0
    bne compare$

    inc csv_rows1

compare$:
    ; Se current_cols > csv_maxcols, aggiorna il massimo.

    lda current_cols1
    cmp csv_maxcols1
    bcc reset$
    bne update$

    lda current_cols0
    cmp csv_maxcols0
    bcc reset$
    beq reset$

update$:
    lda current_cols0
    sta csv_maxcols0

    lda current_cols1
    sta csv_maxcols1

reset$:
    lda #0x00
    sta row_open

    lda #0x01
    sta current_cols0

    lda #0x00
    sta current_cols1
    
	lda #0x00
    sta current_col
    sta current_col_len
    sta csvidx_in_quotes
    sta csvidx_quote_pending
    sta csvidx_inside_cr

    lda #1
    sta csvidx_field_start
    rts
    
; ------------------------------------------------------------
; update_current_col_width
;
; colwidth[current_col] =
;     max(colwidth[current_col], current_col_len)
;
; Tabella:
;   $08200000 + numero colonna
; ------------------------------------------------------------

update_current_col_width:

    ; Salva puntatore CSV corrente.
    lda attic_addr0
    sta scan_save0
    lda attic_addr1
    sta scan_save1
    lda attic_addr2
    sta scan_save2
    lda attic_addr3
    sta scan_save3

    ; $08200000 + current_col
    lda current_col
    sta attic_addr0

    lda #COLWIDTH_BASE1
    sta attic_addr1
    lda #COLWIDTH_BASE2
    sta attic_addr2
    lda #COLWIDTH_BASE3
    sta attic_addr3

    ; Leggi larghezza precedente.
    jsr attic_read8

    lda current_col_len
    cmp attic_val0
    bcc colwidth_done$
    beq colwidth_done$

    ; Nuovo massimo.
    sta attic_val0
    jsr attic_write8

colwidth_done$:

    ; Ripristina puntatore CSV.
    lda scan_save0
    sta attic_addr0
    lda scan_save1
    sta attic_addr1
    lda scan_save2
    sta attic_addr2
    lda scan_save3
    sta attic_addr3

    rts


; ------------------------------------------------------------
; BSS
; ------------------------------------------------------------

    .section bss,bss

csv_rows0:       .space 1
csv_rows1:       .space 1

csv_maxcols0:    .space 1
csv_maxcols1:    .space 1

current_cols0:   .space 1
current_cols1:   .space 1


csvidx_current_byte:    .space 1
csvidx_field_start:     .space 1
csvidx_in_quotes:      .space 1
csvidx_quote_pending:  .space 1
csvidx_inside_cr:      .space 1
remaining0:      .space 1
remaining1:      .space 1
remaining2:      .space 1
remaining3:      .space 1

file_offset0:    .space 1
file_offset1:    .space 1
file_offset2:    .space 1
file_offset3:    .space 1

index_addr0:     .space 1
index_addr1:     .space 1
index_addr2:     .space 1
index_addr3:     .space 1

scan_save0:      .space 1
scan_save1:      .space 1
scan_save2:      .space 1
scan_save3:      .space 1

row_open:        .space 1
last_was_cr:     .space 1

current_col:     .space 1
current_col_len: .space 1
