; ------------------------------------------------------------
; busycursor.s - KnockCSV shared busy mouse cursor
;
; Changes sprite 0 bitmap data at $00C840.
; Busy mode uses VIC multicolour:
;   00 = transparent
;   01 = white cloud
;   10 = black Z
;
; Uses only existing KnockCSV palette entries:
;   0  = very dark (used as black)
;   15 = white
; No palette registers are modified by the busy cursor.
; ------------------------------------------------------------

    .public busycursor_on
    .public busycursor_off

SPRITE_DATA .equ 0x00c840

SPR_MC       .equ 0xd01c
SPR_MC0      .equ 0xd025
SPR_COLOR0   .equ 0xd027

BUSY_BLACK   .equ 0
BUSY_WHITE   .equ 15

    .section code,text

busycursor_on:
    ; Save current sprite mode/colours.
    lda SPR_MC
    sta busy_saved_mc
    lda SPR_MC0
    sta busy_saved_mc0
    lda SPR_COLOR0
    sta busy_saved_color0


    ; Sprite 0 multicolour.
    lda SPR_MC
    ora #0x01
    sta SPR_MC

    ; 01 pixels = shared multicolour 0 = white (palette 15).
    lda #BUSY_WHITE
    sta SPR_MC0

    ; 10 pixels = sprite individual colour = dark/black (palette 0).
    lda #BUSY_BLACK
    sta SPR_COLOR0

    ; Copy Busy bitmap.
    ldx #0
busy_on_copy$:
    lda busy_sprite_data,x
    sta SPRITE_DATA,x
    inx
    cpx #64
    bne busy_on_copy$
    rts


busycursor_off:
    ; Restore normal cursor bitmap first.
    ldx #0
busy_off_copy$:
    lda normal_sprite_data,x
    sta SPRITE_DATA,x
    inx
    cpx #64
    bne busy_off_copy$

    ; Restore original sprite mode/colours.
    lda busy_saved_mc
    sta SPR_MC
    lda busy_saved_mc0
    sta SPR_MC0
    lda busy_saved_color0
    sta SPR_COLOR0

    rts


    .section data,data

; ------------------------------------------------------------------
; 24x21 VIC multicolour Busy sprite.
; Each logical pixel is 2 hardware pixels wide:
;   00 transparent
;   01 white cloud
;   10 black "ZZ"
; ------------------------------------------------------------------
busy_sprite_data:
    .byte 0x01,0x50,0x00
    .byte 0x05,0x54,0x00
    .byte 0x15,0x55,0x00
    .byte 0x15,0x55,0x00
    .byte 0x5A,0x55,0x40
    .byte 0x56,0x55,0x40
    .byte 0x59,0x55,0x40
    .byte 0x5A,0x55,0x40
    .byte 0x55,0x69,0x40
    .byte 0x55,0x59,0x40
    .byte 0x55,0x65,0x40
    .byte 0x55,0x69,0x40
    .byte 0x15,0x55,0x00
    .byte 0x15,0x55,0x00
    .byte 0x05,0x54,0x00
    .byte 0x01,0x51,0x00
    .byte 0x00,0x01,0x40
    .byte 0x00,0x01,0x40
    .byte 0x00,0x01,0x10
    .byte 0x00,0x00,0x10
    .byte 0x00,0x00,0x00

    ; padding byte
    .byte 0x00


; Current KnockCSV normal cursor: tiny 3x3 cross.
normal_sprite_data:
    .byte 0x40,0x00,0x00
    .byte 0xe0,0x00,0x00
    .byte 0x40,0x00,0x00

    .byte 0x00,0x00,0x00
    .byte 0x00,0x00,0x00
    .byte 0x00,0x00,0x00
    .byte 0x00,0x00,0x00
    .byte 0x00,0x00,0x00
    .byte 0x00,0x00,0x00
    .byte 0x00,0x00,0x00
    .byte 0x00,0x00,0x00
    .byte 0x00,0x00,0x00
    .byte 0x00,0x00,0x00
    .byte 0x00,0x00,0x00
    .byte 0x00,0x00,0x00
    .byte 0x00,0x00,0x00
    .byte 0x00,0x00,0x00
    .byte 0x00,0x00,0x00
    .byte 0x00,0x00,0x00
    .byte 0x00,0x00,0x00
    .byte 0x00,0x00,0x00
    .byte 0x00,0x00,0x00
    .byte 0x00


; Saved sprite state.
busy_saved_mc:
    .byte 0
busy_saved_mc0:
    .byte 0
busy_saved_color0:
    .byte 0

