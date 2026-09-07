;
; screen.s
; KnockCSV - routine testuali KERNAL minime
;

    .public cls

bsout   .equ 0xffd2

    .section code,text

; ------------------------------------------------------------
; void cls(void)
;
; Invia il carattere PETSCII CLR/HOME al KERNAL.
; Non modifica la modalità video.
; ------------------------------------------------------------

cls:
    lda #0x93
    jsr bsout
    rts