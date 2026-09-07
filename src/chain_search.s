; ------------------------------------------------------------
; chain_search.s
; KnockCSV -> SEARCH.PRG
; Same chain loader used by EDIT.PRG.
; ------------------------------------------------------------

    .public chain_search

setnam  .equ 0xffbd
setlfs  .equ 0xffba
setbnk  .equ 0xff6b
load    .equ 0xffd5
STARTUP .equ 0x200e

    .section code,text

chain_search:
    lda #6
    ldx #.byte0 search_name
    ldy #.byte1 search_name
    jsr setnam

    lda #0
    ldx #0
    jsr setbnk

    lda #0
    ldx #8
    ldy #1
    jsr setlfs

    ; Simulate JSR return address: LOAD's RTS adds one.
    lda #.byte1 (STARTUP-1)
    pha
    lda #.byte0 (STARTUP-1)
    pha

    lda #0
    ldx #0
    ldy #0
    jmp load

search_name:
    .ascii "SEARCH"
