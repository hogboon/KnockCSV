;
; ------------------------------------------------------------
; loadcsv.s
; KnockCSV - single DMA loader
;
; Strategia:
;   OPEN
;   BASIN -> buffer RAM da 2048 byte
;   CLOSE
;   un solo DMA -> Attic 0x08000000
;
; Serve a eliminare completamente i confini tra DMA multipli.
; ------------------------------------------------------------

    .public loadcsv
    .public savecsv

    .public csv_size0
    .public csv_size1
    .public csv_size2
    .public csv_size3
    .public csvnamebuf
    .public csvnamelen
    .public csv_delimiter
    .public csv_save_delimiter
    .public csv_delimiter_mode
    .public csv_device
    .public csv_loaded_device
    .public csv_decoder_mode

open     .equ 0xffc0
close    .equ 0xffc3
setbnk   .equ 0xff6b
setlfs   .equ 0xffba
setnam   .equ 0xffbd
chkin    .equ 0xffc6
chkout   .equ 0xffc9
readss   .equ 0xffb7
basin    .equ 0xffcf
bsout    .equ 0xffd2
clrchn   .equ 0xffcc

    .section code,text


; ------------------------------------------------------------
; void loadcsv(void)
;
; Caricamento diretto in Attic:
;   BASIN -> char -> [csv_attic_ptr],z
;
; Nessun buffer RAM e nessun DMA.
; csv_attic_ptr parte da $08000000.
; ------------------------------------------------------------

loadcsv:
    lda csv_device
    bne device_ready$
    lda #8
    sta csv_device
device_ready$:

    lda #0x00
    sta fs
    sta char

    sta csv_size0
    sta csv_size1
    sta csv_size2
    sta csv_size3

    ; Stato normalizzazione CSV quote-aware.
    ;
    ; Formato canonico interno in Attic:
    ;   $0D = fine riga CSV reale
    ;   $0A = newline contenuta in un campo quotato
    ;
    ; In questo modo l'indice righe non puo' confondere i due casi.
    sta load_last_was_cr
    sta load_in_quotes
    sta load_quote_pending

    ; destination Attic = $08000000
    sta csv_attic_ptr0
    sta csv_attic_ptr1
    sta csv_attic_ptr2
    lda #0x08
    sta csv_attic_ptr3

    ; Se il browser ha gia' scelto un file, usa quel nome.
    ; Al primo avvio, csvnamelen=0 e viene usato il default.
    lda csvnamelen
    bne have_csv_name$
    jsr setdefaultcsvname

have_csv_name$:
    jsr opencsv

    lda fs
    beq +
    jmp loadcsv_done
+
    ; Remember the actual device of the successfully opened document.
    ; The file browser is free to change csv_device later without
    ; affecting Save of the current document.
    lda csv_device
    sta csv_loaded_device

read_loop$:
    ; Decoder selezionabile dalle Preferences.
    ;   0 = UTF-8 (default)
    ;   1 = PETSCII/raw SEQ (byte-for-byte)
    lda csv_decoder_mode
    bne read_petscii_char$
    jsr read_utf8_char
    jmp read_decoded_char$

read_petscii_char$:
    ; PETSCII mode: keep the original bytes produced by petcat.
    ; seam_bsout already knows the mixed-case PETSCII convention:
    ;   $41..$5A = lowercase
    ;   $61..$7A = uppercase alternate range
    ;   $C1..$DA = uppercase shifted range
    ; Therefore no case conversion must be done here.
    jsr readchar

read_decoded_char$:

    ; Errori veri: bit 7,1,0.
    lda fs
    and #0b10000011
    beq +
    jmp loadcsv_finish
+

    ; --------------------------------------------------------
    ; Normalizzazione CSV quote-aware.
    ;
    ; Fuori da quote:
    ;   CR / LF / CRLF -> $0D (fine riga logica)
    ;
    ; Dentro quote:
    ;   CR / LF / CRLF -> $0A (newline interna alla cella)
    ;
    ; Quote:
    ;   "" dentro quote = quote letterale, resta in quote
    ;   " + altro      = chiusura del campo quotato
    ;
    ; I byte quote originali vengono comunque conservati in Attic.
    ; --------------------------------------------------------

    lda char

    ; Se il quote precedente era potenzialmente di chiusura,
    ; il byte corrente decide se era "" oppure chiusura.
    lda load_in_quotes
    beq load_outside_quotes$

    lda load_quote_pending
    beq load_inside_quotes$

    lda char
    cmp #0x22
    beq load_doubled_quote$

    ; Il quote precedente chiudeva il campo.
    lda #0
    sta load_quote_pending
    sta load_in_quotes
    jmp load_outside_process_same$


load_doubled_quote$:
    ; Secondo quote di "". Conserva normalmente il byte e resta quoted.
    lda #0
    sta load_quote_pending
    lda char
    jsr store_attic_byte
    lda #0
    sta load_last_was_cr
    jmp check_eoi$


load_inside_quotes$:
    lda char
    cmp #0x22
    bne load_inside_not_quote$

    ; Conserva il quote; sapremo al byte seguente se chiude o e' "".
    jsr store_attic_byte
    lda #1
    sta load_quote_pending
    lda #0
    sta load_last_was_cr
    jmp check_eoi$


load_inside_not_quote$:
    lda char
    cmp #0x0d
    beq load_inside_cr$
    cmp #0x0a
    beq load_inside_lf$

    lda #0
    sta load_last_was_cr
    lda char
    jsr store_attic_byte
    jmp check_eoi$


load_inside_cr$:
    lda #1
    sta load_last_was_cr
    lda #0x0a
    jsr store_attic_byte
    jmp check_eoi$


load_inside_lf$:
    ; CRLF interno: CR e' gia' stato convertito in un singolo $0A.
    lda load_last_was_cr
    bne load_skip_lf_common$
    lda #0x0a
    jsr store_attic_byte
load_skip_lf_common$:
    lda #0
    sta load_last_was_cr
    jmp check_eoi$


load_outside_quotes$:
    ; Un quote apre un campo quoted. Per il loader non serve sapere
    ; se la posizione è esattamente a inizio campo: per distinguere newline
    ; interna/esterna e' sufficiente seguire la sintassi CSV valida.
    lda char
    cmp #0x22
    bne load_outside_process_same$

    lda #1
    sta load_in_quotes
    lda #0
    sta load_quote_pending
    sta load_last_was_cr
    lda char
    jsr store_attic_byte
    jmp check_eoi$


load_outside_process_same$:
    lda char
    cmp #0x0d
    beq load_outside_cr$
    cmp #0x0a
    beq load_outside_lf$

    lda #0
    sta load_last_was_cr
    lda char
    jsr store_attic_byte
    jmp check_eoi$


load_outside_cr$:
    lda #1
    sta load_last_was_cr
    lda #0x0d
    jsr store_attic_byte
    jmp check_eoi$


load_outside_lf$:
    lda load_last_was_cr
    bne load_outside_skip_lf$

    lda #0x0d
    jsr store_attic_byte

load_outside_skip_lf$:
    lda #0
    sta load_last_was_cr
    jmp check_eoi$


check_eoi$:
    ; bit 6 = ultimo byte valido
    lda fs
    and #0b01000000
    bne loadcsv_finish

    jmp read_loop$


; ------------------------------------------------------------
; store_attic_byte
;
; INPUT:
;   A = byte da salvare
;
; Aggiorna sia il puntatore Attic sia csv_size.
; ------------------------------------------------------------

store_attic_byte:
    ldz #0x00
    sta [csv_attic_ptr0],z

    jsr inc_attic_dest
    jsr inc_csv_size
    rts


loadcsv_finish:
    jsr closecsv

    ; Always detect the delimiter actually present in the document.
    ; Preferences controls the delimiter used on Save/Save As, not parsing.
    jsr detect_csv_delimiter

    ; Auto preserves the detected delimiter on output.
    lda csv_delimiter_mode
    bne loadcsv_done
    lda csv_delimiter
    sta csv_save_delimiter

loadcsv_done:
    rts


; ------------------------------------------------------------
; csv_attic_ptr++
; ------------------------------------------------------------

inc_attic_dest:
    inc csv_attic_ptr0
    bne done$

    inc csv_attic_ptr1
    bne done$

    inc csv_attic_ptr2
    bne done$

    inc csv_attic_ptr3

done$:
    rts


; ------------------------------------------------------------
; OPEN
; ------------------------------------------------------------

opencsv:
    lda csvnamelen
    ldx #.byte0 csvnamebuf
    ldy #.byte1 csvnamebuf
    jsr setnam

    lda #0x00
    ldx #0x00
    jsr setbnk

    lda #0x01
    ldx csv_device
    ldy #0x02
    jsr setlfs

    jsr open
    bcs openerr$

    ldx #0x01
    jsr chkin
    bcs openerr$

    rts

openerr$:
    lda #0xff
    sta fs
    rts


; ------------------------------------------------------------
; Nome file
; ------------------------------------------------------------

setdefaultcsvname:
    ldx #0x00

name_loop$:
    lda defaultcsvname,x
    beq name_done$

    sta csvnamebuf,x
    inx
    jmp name_loop$

name_done$:
    stx csvnamelen
    rts


defaultcsvname:
    .ascii "MONO,S"
    .byte 0


; ------------------------------------------------------------
; readchar
; ------------------------------------------------------------

readchar:
    jsr basin
    sta char
    
    jsr readss
    and #0b11000011
    sta fs

    rts


; ------------------------------------------------------------
; read_utf8_char
; UTF-8 -> KnockCSV internal one-byte encoding.
; ------------------------------------------------------------
read_utf8_char:
    jsr readchar
    lda fs
    and #0b10000011
    beq +
    rts
+
    lda char
    cmp #0x80
    bcc read_utf8_ascii$

    cmp #0xc3
    beq read_utf8_supported2$
    cmp #0xc4
    beq read_utf8_supported2$
    cmp #0xc5
    beq read_utf8_supported2$

    cmp #0xc2
    bcs +
    jmp read_utf8_bad_single$
+
    cmp #0xe0
    bcc read_utf8_skip1$
    cmp #0xf0
    bcs +
    jmp read_utf8_skip2$
+
    cmp #0xf5
    bcs +
    jmp read_utf8_skip3$
+
    jmp read_utf8_bad_single$

read_utf8_ascii$:
    ; Match the PETSCII convention previously produced by petcat.
    lda char
    cmp #0x41
    bcs +
    rts
+
    cmp #0x5b
    bcs read_utf8_ascii_lower_check$
    clc
    adc #0x80
    sta char
    rts
read_utf8_ascii_lower_check$:
    cmp #0x61
    bcs +
    rts
+
    cmp #0x7b
    bcc +
    rts
+
    sec
    sbc #0x20
    sta char
    rts

read_utf8_supported2$:
    sta utf8_lead
    lda fs
    and #0x40
    bne read_utf8_bad_single$
    jsr readchar
    lda fs
    and #0b10000011
    beq +
    jmp read_utf8_bad_after_read$
+
    lda char
    cmp #0x80
    bcs +
    jmp read_utf8_bad_after_read$
+
    cmp #0xc0
    bcc +
    jmp read_utf8_bad_after_read$
+
    and #0x3f
    tax
    lda utf8_lead
    cmp #0xc3
    beq read_utf8_table_c3$
    cmp #0xc4
    beq read_utf8_table_c4$
    lda utf8_table_c5,x
    jmp read_utf8_table_result$
read_utf8_table_c3$:
    lda utf8_table_c3,x
    jmp read_utf8_table_result$
read_utf8_table_c4$:
    lda utf8_table_c4,x
read_utf8_table_result$:
    sta char
    rts

read_utf8_skip1$:
    lda fs
    and #0x40
    bne read_utf8_bad_single$
    jsr readchar
    jmp read_utf8_question$
read_utf8_skip2$:
    lda #2
    sta utf8_skip_count
    jmp read_utf8_skip_loop$
read_utf8_skip3$:
    lda #3
    sta utf8_skip_count
read_utf8_skip_loop$:
    lda fs
    and #0x40
    bne read_utf8_question$
    jsr readchar
    lda fs
    and #0b10000011
    bne read_utf8_bad_after_read$
    dec utf8_skip_count
    bne read_utf8_skip_loop$
read_utf8_question$:
    lda #0x3f
    sta char
    rts
read_utf8_bad_after_read$:
    lda #0x3f
    sta char
    rts
read_utf8_bad_single$:
    lda #0x3f
    sta char
read_utf8_done$:
    rts

utf8_table_c3:
    .byte 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f
    .byte 0x3f, 0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x3f, 0x96, 0x97, 0x98, 0x99, 0x9a, 0x9b, 0x3f, 0xb9
    .byte 0x9c, 0x9d, 0x9e, 0x9f, 0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xab
    .byte 0x3f, 0xac, 0xad, 0xae, 0xaf, 0xb0, 0xb1, 0x3f, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0x3f, 0xb8

utf8_table_c4:
    .byte 0x3f, 0x3f, 0x3f, 0x3f, 0xba, 0xdc, 0xbb, 0xdd, 0x3f, 0x3f, 0x3f, 0x3f, 0xe4, 0xed, 0xe5, 0xee
    .byte 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0xbc, 0xde, 0xe6, 0xef, 0x3f, 0x3f, 0x3f, 0x3f
    .byte 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f
    .byte 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0xfa, 0xfb, 0x3f

utf8_table_c5:
    .byte 0x3f, 0xbd, 0xdf, 0xbe, 0xe0, 0x3f, 0x3f, 0xe7, 0xf0, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f
    .byte 0xf6, 0xf8, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0xe8, 0xf1, 0xbf, 0xe1, 0x3f, 0x3f, 0x3f, 0x3f
    .byte 0xe9, 0xf2, 0x3f, 0x3f, 0xea, 0xf3, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0xeb, 0xf4
    .byte 0xf7, 0xf9, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0xc0, 0xe2, 0xdb, 0xe3, 0xec, 0xf5, 0x3f




; ------------------------------------------------------------
; detect_csv_delimiter
;
; Auto-detect comma / semicolon / TAB from at most the first
; 2048 decoded bytes or 8 physical CSV rows.
;
; Delimiters inside quoted fields are ignored.  The first row is
; used as a reference: subsequent rows score when they contain the
; same non-zero delimiter count.  This avoids choosing decimal
; commas in European semicolon-separated files.
;
; No additional scratch BSS is required.  During this routine only,
; existing loader/save temporaries are reused:
;   save_rem0/1       sample bytes remaining
;   save_char         in-quotes flag
;   save_error        rows evaluated
;   save_namelen      current comma count
;   save_base_len     current semicolon count
;   fs                current TAB count
;   char              reference comma count
;   load_last_was_cr  reference semicolon count
;   load_in_quotes    reference TAB count
;   load_quote_pending comma match score
;   utf8_lead          semicolon match score
;   utf8_skip_count    TAB match score
; ------------------------------------------------------------
detect_csv_delimiter:
    ; Fallback for empty / ambiguous files.
    lda #0x2c
    sta csv_delimiter

    lda csv_size0
    ora csv_size1
    ora csv_size2
    ora csv_size3
    bne +
    rts
+

    ; sample remaining = min(csv_size, $0800)
    lda csv_size2
    ora csv_size3
    bne auto_sample_2k$
    lda csv_size1
    cmp #0x08
    bcs auto_sample_2k$

    lda csv_size0
    sta save_rem0
    lda csv_size1
    sta save_rem1
    jmp auto_sample_ready$

auto_sample_2k$:
    lda #0x00
    sta save_rem0
    lda #0x08
    sta save_rem1

auto_sample_ready$:
    ; Attic source = $08000000.
    lda #0
    sta csv_attic_ptr0
    sta csv_attic_ptr1
    sta csv_attic_ptr2
    lda #0x08
    sta csv_attic_ptr3

    lda #0
    sta save_char
    sta save_error
    sta save_namelen
    sta save_base_len
    sta fs
    sta char
    sta load_last_was_cr
    sta load_in_quotes
    sta load_quote_pending
    sta utf8_lead
    sta utf8_skip_count

auto_scan_loop$:
    ; stop if sample exhausted
    lda save_rem0
    ora save_rem1
    beq auto_finish_partial$

    ldz #0
    lda [csv_attic_ptr0],z

    ; Quotes simply toggle state.  With valid CSV, doubled quotes
    ; toggle twice consecutively and therefore preserve the state.
    cmp #0x22
    bne auto_not_quote$
    lda save_char
    eor #1
    sta save_char
    jmp auto_next_byte$

auto_not_quote$:
    lda save_char
    bne auto_next_byte$

    ldz #0
    lda [csv_attic_ptr0],z
    cmp #0x0d
    beq auto_end_row$
    cmp #0x2c
    bne +
    inc save_namelen
    jmp auto_next_byte$
+
    cmp #0x3b
    bne +
    inc save_base_len
    jmp auto_next_byte$
+
    cmp #0x09
    bne auto_next_byte$
    inc fs
    jmp auto_next_byte$

auto_end_row$:
    jsr auto_evaluate_row
    lda save_error
    cmp #8
    bcs auto_choose$

auto_next_byte$:
    jsr inc_attic_dest

    lda save_rem0
    bne +
    dec save_rem1
+
    dec save_rem0
    jmp auto_scan_loop$

auto_finish_partial$:
    ; Evaluate a final unterminated row only when it has data.
    lda save_namelen
    ora save_base_len
    ora fs
    beq auto_choose$
    jsr auto_evaluate_row

auto_choose$:
    ; Prefer the candidate with the highest consistency score.
    ; On a tie, prefer the larger reference field count.
    ;
    ; Start with comma.
    lda #0x2c
    sta csv_delimiter
    lda load_quote_pending
    sta save_namelen          ; best score
    lda char
    sta save_base_len         ; best reference count

    ; Semicolon candidate.
    lda utf8_lead
    cmp save_namelen
    bcc auto_try_tab$
    bne auto_pick_semicolon$
    lda load_last_was_cr
    cmp save_base_len
    bcc auto_try_tab$
    beq auto_try_tab$

auto_pick_semicolon$:
    lda #0x3b
    sta csv_delimiter
    lda utf8_lead
    sta save_namelen
    lda load_last_was_cr
    sta save_base_len

auto_try_tab$:
    lda utf8_skip_count
    cmp save_namelen
    bcc auto_choice_validity$
    bne auto_pick_tab$
    lda load_in_quotes
    cmp save_base_len
    bcc auto_choice_validity$
    beq auto_choice_validity$

auto_pick_tab$:
    lda #0x09
    sta csv_delimiter
    lda utf8_skip_count
    sta save_namelen
    lda load_in_quotes
    sta save_base_len

auto_choice_validity$:
    ; A candidate must actually occur in the reference row.
    lda save_base_len
    bne auto_detect_done$
    lda #0x2c
    sta csv_delimiter
auto_detect_done$:
    rts


; Evaluate current physical row.
auto_evaluate_row:
    ; Ignore blank / one-field rows with no candidate separator.
    ; This also prevents leading empty lines from becoming the reference.
    lda save_namelen
    ora save_base_len
    ora fs
    bne +
    rts
+
    lda save_error
    bne auto_compare_row$

    ; First row = references.
    lda save_namelen
    sta char
    lda save_base_len
    sta load_last_was_cr
    lda fs
    sta load_in_quotes

    ; A non-zero reference gets one initial score.
    lda char
    beq +
    inc load_quote_pending
+
    lda load_last_was_cr
    beq +
    inc utf8_lead
+
    lda load_in_quotes
    beq auto_row_done$
    inc utf8_skip_count
    jmp auto_row_done$

auto_compare_row$:
    lda char
    beq +
    cmp save_namelen
    bne +
    inc load_quote_pending
+
    lda load_last_was_cr
    beq +
    cmp save_base_len
    bne +
    inc utf8_lead
+
    lda load_in_quotes
    beq auto_row_done$
    cmp fs
    bne auto_row_done$
    inc utf8_skip_count

auto_row_done$:
    inc save_error
    lda #0
    sta save_namelen
    sta save_base_len
    sta fs
    rts


; ------------------------------------------------------------
; void savecsv(void)
;
; Sovrascrive il file correntemente aperto sul csv_device corrente.
; PETSCII: byte interni scritti invariati.
; UTF-8:   formato interno KnockCSV riconvertito in ASCII/UTF-8.
;
; Il nome DOS usato per l'OPEN e':
;   @0:<nome>,s,w
; cosi' il file SEQ esistente viene sostituito.
; ------------------------------------------------------------

savecsv:
    lda csvnamelen
    bne savecsv_have_name$
    rts

savecsv_have_name$:
    ; Reset Save error state first.
    lda #0
    sta save_error

    ; --------------------------------------------------------
    ; Replace strategy:
    ;   1) SCRATCH old file through command channel 15
    ;      using "S0:<name>"
    ;   2) create a new sequential file using "<name>,S,W"
    ;
    ; csvnamebuf already contains "<name>,S" from the browser.
    ; --------------------------------------------------------
    jsr save_scratch_current
    lda save_error
    beq +
    rts
+

    ; source Attic = $08000000
    lda #0
    sta csv_attic_ptr0
    sta csv_attic_ptr1
    sta csv_attic_ptr2
    lda #0x08
    sta csv_attic_ptr3

    ; remaining = csv_size
    lda csv_size0
    sta save_rem0
    lda csv_size1
    sta save_rem1
    lda csv_size2
    sta save_rem2
    lda csv_size3
    sta save_rem3

    jsr save_prepare_write_name
    jsr opensavecsv

    lda save_error
    beq +
    rts
+
    ; Delimiter-conversion state, reusing Save scratch bytes after OPEN.
    lda #0
    sta save_error
    sta save_base_len
    lda #1
    sta save_namelen

savecsv_loop_test$:
    lda save_rem0
    ora save_rem1
    ora save_rem2
    ora save_rem3
    beq savecsv_finish$

    ldz #0
    lda [csv_attic_ptr0],z
    sta save_char

    ; Same delimiter: preserve the existing CSV structure exactly.
    lda csv_save_delimiter
    cmp csv_delimiter
    bne savecsv_convert_delimiter$

    lda save_char
    jsr save_emit_document_char
    jmp savecsv_advance$

savecsv_convert_delimiter$:
    jsr save_emit_converted_char

savecsv_advance$:
    jsr inc_attic_dest
    jsr dec_save_remaining
    jmp savecsv_loop_test$

savecsv_finish$:
    ; Trailing delimiter means a final empty field. During conversion
    ; serialize it explicitly as "".
    lda csv_save_delimiter
    cmp csv_delimiter
    beq savecsv_close$
    lda save_char
    cmp csv_delimiter
    bne savecsv_close$
    lda #0x22
    jsr bsout
    jsr bsout

savecsv_close$:
    jsr clrchn
    lda #0x02
    jsr close
    rts


; ------------------------------------------------------------
; Emit one ordinary document byte using the selected file encoding.
; INPUT: A = internal KnockCSV byte.
; ------------------------------------------------------------
save_emit_document_char:
    sta save_char
    lda csv_decoder_mode
    bne save_emit_document_petscii$
    jsr save_emit_utf8
    rts

save_emit_document_petscii$:
    lda save_char
    jsr bsout
    rts


; ------------------------------------------------------------
; Delimiter conversion for Save / Save As.
;
; Attic keeps the delimiter used to parse/edit the current document.
; If output delimiter differs, every originally-unquoted field is written
; quoted. Existing quoted fields are preserved. This keeps target
; delimiters already present in field data from creating extra columns.
;
; save_error    = source quoted state
; save_namelen  = field-start flag
; save_base_len = wrapper quote active
; ------------------------------------------------------------
save_emit_converted_char:
    lda save_error
    beq save_conv_outside$

    ; Inside a source-quoted field. Doubled quotes toggle twice.
    lda save_char
    cmp #0x22
    bne save_conv_quoted_emit$
    lda save_error
    eor #1
    sta save_error
save_conv_quoted_emit$:
    lda save_char
    jsr save_emit_document_char
    rts

save_conv_outside$:
    lda save_char
    cmp csv_delimiter
    beq save_conv_delimiter$
    cmp #0x0d
    beq save_conv_row_end$

    lda save_namelen
    beq save_conv_unquoted_content$

    lda save_char
    cmp #0x22
    bne save_conv_begin_wrapped$

    ; Existing quoted field.
    lda #0
    sta save_namelen
    lda #1
    sta save_error
    lda save_char
    jsr save_emit_document_char
    rts

save_conv_begin_wrapped$:
    ; Quote every originally-unquoted field during conversion.
    lda #0x22
    jsr bsout
    lda #1
    sta save_base_len
    lda #0
    sta save_namelen

save_conv_unquoted_content$:
    lda save_char
    cmp #0x22
    bne save_conv_content_emit$

    ; Wrapped originally-unquoted field: escape a literal quote.
    lda save_base_len
    bne save_conv_escape_wrapped_quote$

    ; The second half of "" in an existing quoted field was just read.
    ; Re-enter quoted state; the first quote temporarily toggled it off.
    lda #1
    sta save_error
    lda save_char
    jsr save_emit_document_char
    rts

save_conv_escape_wrapped_quote$:
    lda #0x22
    jsr bsout

save_conv_content_emit$:
    lda save_char
    jsr save_emit_document_char
    rts

save_conv_delimiter$:
    jsr save_conv_close_wrapper
    lda csv_save_delimiter
    jsr bsout
    lda #1
    sta save_namelen
    rts

save_conv_row_end$:
    jsr save_conv_close_wrapper
    lda #0x0d
    jsr bsout
    lda #1
    sta save_namelen
    rts

save_conv_close_wrapper:
    lda save_base_len
    beq save_conv_close_done$
    lda #0x22
    jsr bsout
    lda #0
    sta save_base_len
save_conv_close_done$:
    rts


; ------------------------------------------------------------
; SCRATCH current file.
;
; csvnamebuf contains:
;     <name>,S
;
; Temporarily transform it into:
;     S0:<name>
;
; The original "<name>,S" is reconstructed immediately after OPEN.
; ------------------------------------------------------------
save_scratch_current:
    lda csvnamelen
    cmp #3
    bcs +
    lda #0xff
    sta save_error
    rts
+
    ; basename length = csvnamelen - 2 (strip trailing ",S")
    sec
    sbc #2
    sta save_base_len

    ; Shift basename right by three bytes, backwards.
    tax
    dex
save_scratch_shift$:
    lda csvnamebuf,x
    sta csvnamebuf+3,x
    dex
    bpl save_scratch_shift$

    lda #'S'
    sta csvnamebuf
    lda #'0'
    sta csvnamebuf+1
    lda #':'
    sta csvnamebuf+2

    ; command length = 3 + basename length = csvnamelen + 1
    lda csvnamelen
    clc
    adc #1
    sta save_namelen

    lda save_namelen
    ldx #.byte0 csvnamebuf
    ldy #.byte1 csvnamebuf
    jsr setnam

    lda #0
    ldx #0
    jsr setbnk

    ; Command channel 15.
    lda #0x0f
    ldx csv_loaded_device
    bne save_scratch_device_ready$
    ldx csv_device
save_scratch_device_ready$:
    ldy #0x0f
    jsr setlfs
    jsr open
    bcs save_scratch_open_error$

    lda #0x0f
    jsr close
    jsr save_restore_original_name
    rts

save_scratch_open_error$:
    lda #0xff
    sta save_error
    lda #0x0f
    jsr close
    jsr clrchn
    jsr save_restore_original_name
    rts


; Restore "<name>,S" after the temporary scratch command.
save_restore_original_name:
    ldx #0
save_restore_original_loop$:
    cpx save_base_len
    beq save_restore_original_tail$
    lda csvnamebuf+3,x
    sta csvnamebuf,x
    inx
    jmp save_restore_original_loop$

save_restore_original_tail$:
    lda #','
    sta csvnamebuf,x
    inx
    lda #'S'
    sta csvnamebuf,x
    rts


; csvnamebuf already contains "<name>,S".
; Append only ",W" -> "<name>,S,W".
; No restore is needed afterwards because csvnamelen keeps the original
; length and the extra bytes are ignored by subsequent LOADs.
save_prepare_write_name:
    lda #0
    sta save_error

    ldx csvnamelen
    lda #','
    sta csvnamebuf,x
    inx
    lda #'W'
    sta csvnamebuf,x
    inx
    stx save_namelen
    rts


opensavecsv:
    lda save_namelen
    ldx #.byte0 csvnamebuf
    ldy #.byte1 csvnamebuf
    jsr setnam

    lda #0
    ldx #0
    jsr setbnk

    lda #0x02
    ldx csv_loaded_device
    bne save_device_ready$
    ldx csv_device
save_device_ready$:
    ldy #0x02
    jsr setlfs

    jsr open
    bcs opensave_error$

    ldx #0x02
    jsr chkout
    bcs opensave_error_close$
    rts

opensave_error_close$:
    lda #0x02
    jsr close
opensave_error$:
    lda #0xff
    sta save_error
    jsr clrchn
    rts


; UTF-8 export from KnockCSV's internal one-byte representation.
save_emit_utf8:
    lda save_char

    ; Private European range $80..$C0.
    cmp #0x80
    bcc save_utf8_ascii$
    cmp #0xc1
    bcc save_utf8_private_low$

    ; $C1..$DA = canonical uppercase ASCII A..Z.
    cmp #0xdb
    bcc save_utf8_upper_canonical$

    ; Private European range $DB..$FB.
    cmp #0xfc
    bcc save_utf8_private_high$

    lda #'?'
    jsr bsout
    rts

save_utf8_ascii$:
    lda save_char

    ; Internal $41..$5A = lowercase a..z.
    cmp #0x41
    bcc save_utf8_ascii_direct$
    cmp #0x5b
    bcs save_utf8_ascii_upper_alt_check$
    clc
    adc #0x20
    jsr bsout
    rts

save_utf8_ascii_upper_alt_check$:
    ; Defensive support for alternate internal uppercase $61..$7A.
    cmp #0x61
    bcc save_utf8_ascii_direct$
    cmp #0x7b
    bcs save_utf8_ascii_direct$
    sec
    sbc #0x20
    jsr bsout
    rts

save_utf8_ascii_direct$:
    lda save_char
    jsr bsout
    rts

save_utf8_upper_canonical$:
    lda save_char
    sec
    sbc #0x80
    jsr bsout
    rts

save_utf8_private_low$:
    sec
    sbc #0x80
    tax
    lda save_utf8_low_lead,x
    jsr bsout
    lda save_utf8_low_trail,x
    jsr bsout
    rts

save_utf8_private_high$:
    sec
    sbc #0xdb
    tax
    lda save_utf8_high_lead,x
    jsr bsout
    lda save_utf8_high_trail,x
    jsr bsout
    rts


dec_save_remaining:
    lda save_rem0
    bne save_dec0$
    lda save_rem1
    bne save_dec1$
    lda save_rem2
    bne save_dec2$
    dec save_rem3
save_dec2$:
    dec save_rem2
save_dec1$:
    dec save_rem1
save_dec0$:
    dec save_rem0
    rts


; Reverse mapping for the 98 supported European UTF-8 characters.
save_utf8_low_lead:
    .byte 0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3
    .byte 0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3
    .byte 0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3
    .byte 0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc4,0xc4,0xc4,0xc5,0xc5,0xc5
    .byte 0xc5
save_utf8_low_trail:
    .byte 0x80,0x81,0x82,0x83,0x84,0x85,0x86,0x87,0x88,0x89,0x8a,0x8b,0x8c,0x8d,0x8e,0x8f
    .byte 0x91,0x92,0x93,0x94,0x95,0x96,0x98,0x99,0x9a,0x9b,0x9c,0x9d,0xa0,0xa1,0xa2,0xa3
    .byte 0xa4,0xa5,0xa6,0xa7,0xa8,0xa9,0xaa,0xab,0xac,0xad,0xae,0xaf,0xb1,0xb2,0xb3,0xb4
    .byte 0xb5,0xb6,0xb8,0xb9,0xba,0xbb,0xbc,0xbd,0xbf,0x9f,0x84,0x86,0x98,0x81,0x83,0x9a
    .byte 0xb9

save_utf8_high_lead:
    .byte 0xc5,0xc4,0xc4,0xc4,0xc5,0xc5,0xc5,0xc5,0xc5,0xc4,0xc4,0xc4,0xc5,0xc5,0xc5,0xc5
    .byte 0xc5,0xc5,0xc4,0xc4,0xc4,0xc5,0xc5,0xc5,0xc5,0xc5,0xc5,0xc5,0xc5,0xc5,0xc5,0xc4
    .byte 0xc4
save_utf8_high_trail:
    .byte 0xbb,0x85,0x87,0x99,0x82,0x84,0x9b,0xba,0xbc,0x8c,0x8e,0x9a,0x87,0x98,0xa0,0xa4
    .byte 0xae,0xbd,0x8d,0x8f,0x9b,0x88,0x99,0xa1,0xa5,0xaf,0xbe,0x90,0xb0,0x91,0xb1,0xbd
    .byte 0xbe


; ------------------------------------------------------------
; CLOSE
; ------------------------------------------------------------

closecsv:
    jsr clrchn

    lda #0x01
    jsr close

    rts


; ------------------------------------------------------------
; csv_size++
; ------------------------------------------------------------

inc_csv_size:
    inc csv_size0
    bne done$

    inc csv_size1
    bne done$

    inc csv_size2
    bne done$

    inc csv_size3

done$:
    rts


; ------------------------------------------------------------
; BSS
; ------------------------------------------------------------

    .section bss,bss

fs:
    .space 1

char:
    .space 1

csv_size0:
    .space 1

csv_size1:
    .space 1

csv_size2:
    .space 1

csv_size3:
    .space 1

; 1 se l'ultimo newline letto dal file era CR.
load_last_was_cr:
    .space 1

load_in_quotes:
    .space 1

load_quote_pending:
    .space 1
utf8_lead:
    .space 1
utf8_skip_count:
    .space 1
    
	.section zdata,bss

save_rem0:
    .space 1
save_rem1:
    .space 1
save_rem2:
    .space 1
save_rem3:
    .space 1
save_char:
    .space 1
save_error:
    .space 1
save_namelen:
    .space 1
save_base_len:
    .space 1
    
    .section bss,bss

csvnamelen:
    .space 1

; Device IEC corrente per browser e caricamento CSV.
; Inizializzato a 8 al primo ingresso in loadcsv se ancora zero.
csv_device:
    .space 1

; Device from which the currently loaded document was actually opened.
; Save uses this instead of the browser's temporary device selection.
csv_loaded_device:
    .space 1

; Decoder file:
;   0 = UTF-8 (default, BSS inizializzata a zero)
;   1 = PETSCII prodotto da petcat, normalizzato nel formato interno KnockCSV
csv_decoder_mode:
    .space 1

; Active CSV field delimiter. Initialized to comma by csvviewloop.
csv_delimiter:
    .space 1

csvnamebuf:
    .space 64

; Delimiter used when writing Save / Save As.
; Reuses the old csv_debug_fs byte so BSS does not grow.
csv_save_delimiter:
    .space 1

; Delimiter preference:
;   0 = Auto
;   1 = Comma
;   2 = Semicolon
;   3 = Tab
; Reuses the old csv_debug_open byte to avoid growing BSS.
csv_delimiter_mode:
	.space 1


; ------------------------------------------------------------
; Zero page
; ------------------------------------------------------------

    .section zzpage,bss

; Puntatore quad per accesso diretto alla Attic RAM.
; Deve essere in zero page per l'indirizzamento [ptr],z.
csv_attic_ptr0:
    .space 1
csv_attic_ptr1:
    .space 1
csv_attic_ptr2:
    .space 1
csv_attic_ptr3:
    .space 1
