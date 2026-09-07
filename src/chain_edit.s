; ------------------------------------------------------------
; chain_edit.s
; KnockCSV -> EDIT.PRG
;
; Loader chain minimale. Il KERNAL LOAD viene raggiunto con JMP,
; dopo aver predisposto sullo stack l'indirizzo $200D: il suo RTS
; prosegue quindi a $200E, startup del nuovo PRG appena caricato.
; ------------------------------------------------------------

    .public chain_edit

setnam  .equ 0xffbd
setlfs  .equ 0xffba
setbnk  .equ 0xff6b
load    .equ 0xffd5
STARTUP .equ 0x200e

    .section code,text

chain_edit:
    lda #4
    ldx #.byte0 edit_name
    ldy #.byte1 edit_name
    jsr setnam

    lda #0
    ldx #0
    jsr setbnk

    lda #0
    ldx #8
    ldy #1
    jsr setlfs

    ; Simula il return-address di un JSR: RTS aggiunge 1,
    ; quindi STARTUP-1 viene impostato a $200D.
    lda #.byte1 (STARTUP-1)
    pha
    lda #.byte0 (STARTUP-1)
    pha

    lda #0
    ldx #0
    ldy #0
    jmp load

edit_name:
    .ascii "EDIT"
