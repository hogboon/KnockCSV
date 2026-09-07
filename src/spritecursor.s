    .public initmousecursor
    .public updatemousecursor
    .public sprite_apply_screen_mode
    .public hidemousecursor

    .extern mouse_xpos
    .extern mouse_ypos

    .extern style_mouse_color
    .extern csv_screen_mode

    .section code,text

SPRPTR_TABLE .equ 0x00c800
SPRITE_DATA  .equ 0x00c840
SPRITE_PTR0  .equ  SPRITE_DATA / 64

SPRITE_OFFSET_X .equ 24
SPRITE_OFFSET_Y .equ 50

initmousecursor:
    ; VIC-IV extended sprite pointer table:
    ; SPRPTRADR = $00C800
    lda #.byte0 SPRPTR_TABLE
    sta 0xd06c
    lda #.byte1 SPRPTR_TABLE
    sta 0xd06d

    ; $D06E:
    ; bit 7 = SPRPTR16 enabled
    ; bits 0..6 = bank for sprite pointer table
    lda #0x80
    sta 0xd06e

    ; sprite 0 pointer = SPRITE_DATA / 64 = $0321
    lda #.byte0 SPRITE_PTR0
    sta SPRPTR_TABLE + 0
    lda #.byte1 SPRITE_PTR0
    sta SPRPTR_TABLE + 1

    ; copia 64 byte sprite data in $00C840
    ldx #0x00

copy_sprite_loop$:
    lda mouse_sprite_data,x
    sta SPRITE_DATA,x
    inx
    cpx #64
    bne copy_sprite_loop$

    ; Gli sprite restano nel sistema H320/VIC-II anche con testo H640.
    ; Il mouse logico resta 0..639 e viene diviso per 2 in updatemousecursor.
    lda 0xd054
    and #0xef
    sta 0xd054

    ; sprite 0 parte senza super-MSB X
    lda 0xd05f
    and #0xfe
    sta 0xd05f

    ; sprite 0 monocolore
    lda 0xd01c
    and #0xfe
    sta 0xd01c

    ; no expand X/Y
    lda 0xd01d
    and #0xfe
    sta 0xd01d

    lda 0xd017
    and #0xfe
    sta 0xd017

    ; colore sprite 0
    lda style_mouse_color
    sta 0xd027

    ; abilita sprite 0
    lda 0xd015
    ora #0x01
    sta 0xd015

    jsr updatemousecursor
    rts



sprite_apply_screen_mode:
    lda csv_screen_mode
    bne sprite_mode_50$

sprite_mode_25$:
    ; Exact behaviour of the original working 80x25 build:
    ; standard V200 sprite Y, no V400 extension.
    lda 0xd076
    and #0xfe
    sta 0xd076
    lda 0xd077
    and #0xfe
    sta 0xd077
    rts

sprite_mode_50$:
    lda 0xd076
    ora #0x01
    sta 0xd076
    lda 0xd077
    and #0xfe
    sta 0xd077
    rts


updatemousecursor:
    ; Il mouse logico resta 0..639 (coordinate testo H640), ma lo
    ; sprite viene mantenuto nel sistema VIC-II/H320. Questo evita
    ; completamente il passaggio attraverso SPRXSMSBS ($D05F).
    ;
    ; sprite_x = (mouse_xpos >> 1) + 24
    lda mouse_xpos+1
    lsr a
    sta sprite_x_hi
    lda mouse_xpos
    ror a

    clc
    adc #SPRITE_OFFSET_X
    sta 0xd000
    lda sprite_x_hi
    adc #0x00
    sta sprite_x_hi

    ; bit 8 standard VIC-II in $D010.
    lda sprite_x_hi
    and #0x01
    beq sprite_x_bit8_clear$
    lda 0xd010
    ora #0x01
    sta 0xd010
    bra sprite_x_done$

sprite_x_bit8_clear$:
    lda 0xd010
    and #0xfe
    sta 0xd010

sprite_x_done$:
    ; Il super-MSB H640 non viene usato per questo sprite.
    lda 0xd05f
    and #0xfe
    sta 0xd05f

    lda csv_screen_mode
    bne sprite_y_50$

sprite_y_25$:
    ; Original working 80x25 path.
    clc
    lda mouse_ypos
    adc #50
    sta 0xd001
    rts

sprite_y_50$:
    ; Working 80x50 path: native V400 coordinate + doubled border offset.
    clc
    lda mouse_ypos
    adc #103
    sta 0xd001
    lda mouse_ypos+1
    adc #0
    and #0x01
    beq sprite_y50_clear$
    lda 0xd077
    ora #0x01
    sta 0xd077
    rts
sprite_y50_clear$:
    lda 0xd077
    and #0xfe
    sta 0xd077
    rts


hidemousecursor:
    lda 0xd015
    and #0xfe
    sta 0xd015
    rts


    .section data,data

sprite_x_hi:
    .byte 0x00

mouse_sprite_data:
    ; 3x3 cross:
    ; .#.
    ; ###
    ; .#.

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

    ; byte 64 padding, standard VIC-II sprite slot = 64 byte
    .byte 0x00