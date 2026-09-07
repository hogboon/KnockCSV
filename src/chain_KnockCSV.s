; ------------------------------------------------------------
; chain_KnockCSV.s
; EDIT.PRG -> main viewer PRG
; Stesso chain loader minimale di chain_edit.s.
; ------------------------------------------------------------

    .public chain_knockcsv

setnam  .equ 0xffbd
setlfs  .equ 0xffba
setbnk  .equ 0xff6b
load    .equ 0xffd5
STARTUP .equ 0x200e

    .section code,text

chain_knockcsv:
    lda #8
    ldx #.byte0 knockcsv_name
    ldy #.byte1 knockcsv_name
    jsr setnam

    lda #0
    ldx #0
    jsr setbnk

    lda #0
    ldx #8
    ldy #1
    jsr setlfs

    lda #.byte1 (STARTUP-1)
    pha
    lda #.byte0 (STARTUP-1)
    pha

    lda #0
    ldx #0
    ldy #0
    jmp load

knockcsv_name:
    .ascii "KNOCKCSV"
