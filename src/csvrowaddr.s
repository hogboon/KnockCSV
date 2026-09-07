;
; ------------------------------------------------------------
; csvrowaddr.s
; KnockCSV
;
; Imposta attic_addr sull'inizio di una riga CSV.
;
; INPUT:
;   csv_row0
;   csv_row1
;       numero riga a 16 bit, little-endian
;
; OUTPUT:
;   attic_addr0..3
;       indirizzo assoluto della riga nel CSV grezzo
;
; Layout:
;   CSV grezzo   : 0x08000000
;   indice righe : 0x08100000
;
; Ogni voce indice:
;   4 byte little-endian = offset relativo nel CSV
;
; Esempio:
;   row = 2
;   entry address = 0x08100000 + (2 * 4)
;   entry = 2B 00 00 00
;   risultato attic_addr = 0x0800002B
;
; ------------------------------------------------------------

    .public csvrowaddr
    .public csv_row0
    .public csv_row1

    .extern attic_addr0
    .extern attic_addr1
    .extern attic_addr2
    .extern attic_addr3

    .extern attic_val0
    .extern attic_read8

    .section code,text


; ------------------------------------------------------------
; void csvrowaddr(void)
; ------------------------------------------------------------

csvrowaddr:

    ; --------------------------------------------------------
    ; Calcola row * 4 in offset0..offset2.
    ;
    ; row e' 16 bit.
    ; Moltiplicare per 4 produce fino a 18 bit.
    ; --------------------------------------------------------

    lda csv_row0
    sta offset0

    lda csv_row1
    sta offset1

    lda #0x00
    sta offset2

    ; << 1
    asl offset0
    rol offset1
    rol offset2

    ; << 1  => *4
    asl offset0
    rol offset1
    rol offset2


    ; --------------------------------------------------------
    ; attic_addr = 0x08100000 + offset
    ; --------------------------------------------------------

    lda offset0
    sta attic_addr0

    lda offset1
    sta attic_addr1

    lda offset2
    clc
    adc #0x10
    sta attic_addr2

    lda #0x08
    adc #0x00
    sta attic_addr3


    ; --------------------------------------------------------
    ; Legge i 4 byte dell'offset riga.
    ; --------------------------------------------------------

    jsr attic_read8
    lda attic_val0
    sta row_offset0
    jsr inc_attic_ptr

    jsr attic_read8
    lda attic_val0
    sta row_offset1
    jsr inc_attic_ptr

    jsr attic_read8
    lda attic_val0
    sta row_offset2
    jsr inc_attic_ptr

    jsr attic_read8
    lda attic_val0
    sta row_offset3


    ; --------------------------------------------------------
    ; Converte offset relativo in indirizzo assoluto:
    ;
    ;   0x08000000 + row_offset
    ;
    ; --------------------------------------------------------

    lda row_offset0
    sta attic_addr0

    lda row_offset1
    sta attic_addr1

    lda row_offset2
    sta attic_addr2

    lda row_offset3
    clc
    adc #0x08
    sta attic_addr3

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

csv_row0:
    .space 1

csv_row1:
    .space 1

offset0:
    .space 1

offset1:
    .space 1

offset2:
    .space 1

row_offset0:
    .space 1

row_offset1:
    .space 1

row_offset2:
    .space 1

row_offset3:
    .space 1
