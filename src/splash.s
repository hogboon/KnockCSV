; ------------------------------------------------------------
; splash.s
; KnockCSV startup splash - 320x200 FCM image
;
; Asset file on disk:
;   "SPLASH" PRG
;     2 byte PRG header (discarded)
;     256 red palette bytes
;     256 green palette bytes
;     256 blue palette bytes
;     64000 FCM pixel bytes, character-major
;
; FCM layout:
;   screen map : $0000C000
;   pixels     : $00040000
;   chars      : $1000..$13E7
;   Color RAM  : $00,$FF per cell
; ------------------------------------------------------------

    .public splash_show
    .public splash_draw_image

    .extern attic_addr0
    .extern attic_addr1
    .extern attic_addr2
    .extern attic_addr3

MODKEY   .equ 0xd60a
ASCIIKEY .equ 0xd610

setnam   .equ 0xffbd
setlfs   .equ 0xffba
setbnk   .equ 0xff6b
open     .equ 0xffc0
close    .equ 0xffc3
chkin    .equ 0xffc6
clrchn   .equ 0xffcc
basin    .equ 0xffcf

    .section code,text

; ------------------------------------------------------------
; splash_show
; ------------------------------------------------------------
splash_show:
    sei

    ; Preserve shared long pointer.
    lda attic_addr0
    sta splash_saved_attic0
    lda attic_addr1
    sta splash_saved_attic1
    lda attic_addr2
    sta splash_saved_attic2
    lda attic_addr3
    sta splash_saved_attic3

    ; Preserve VIC-IV state changed by the splash.
    lda 0xd011
    sta splash_saved_d011
    lda 0xd020
    sta splash_saved_d020
    lda 0xd021
    sta splash_saved_d021
    lda 0xd031
    sta splash_saved_d031
    lda 0xd054
    sta splash_saved_d054
    lda 0xd058
    sta splash_saved_d058
    lda 0xd059
    sta splash_saved_d059
    lda 0xd05e
    sta splash_saved_d05e
    lda 0xd060
    sta splash_saved_d060
    lda 0xd061
    sta splash_saved_d061
    lda 0xd062
    sta splash_saved_d062
    lda 0xd063
    sta splash_saved_d063

    ; Blank video while loading the asset.  This also prevents the
    ; temporary writes to KnockCSV screen RAM $40000 from being visible.
    lda 0xd011
    and #0xef
    sta 0xd011

    cli

    ; Load palette + 64000 FCM bytes from disk.
    jsr splash_load_asset
    bcc splash_asset_ok$

    ; Missing/corrupt SPLASH file: restore cleanly and skip splash.
    jmp splash_restore$

splash_asset_ok$:
    ; Build FCM screen map and Color RAM after the asset is present.
    jsr splash_build_screen
    jsr splash_build_colorram

    sei

    ; Display on, ECM off.
    lda splash_saved_d011
    and #0xbf
    ora #0x10
    sta 0xd011

    ; Same 320x200 FCM profile as the working 3D project:
    ; H640 off, ATTR off, V400 off.
    lda splash_saved_d031
    and #0b01010111
    sta 0xd031

    ; CHR16 ON, FCLRHI ON, NCM OFF.
    lda splash_saved_d054
    and #0xfd
    ora #0x05
    sta 0xd054

    ; 40 CHR16 cells x 2 bytes = 80 bytes per line.
    lda #80
    sta 0xd058
    lda #0
    sta 0xd059

    ; 40 visible cells.
    lda #39
    sta 0xd05e

    ; FCM screen map = $0000C000.
    lda #0x00
    sta 0xd060
    lda #0xc0
    sta 0xd061
    lda #0x00
    sta 0xd062
    sta 0xd063

    ; Black border/background around the 320x200 picture.
    lda #0xff
    sta 0xd020
    sta 0xd021

    cli

    jsr splash_draw_image

    ; Discard the RUN/RETURN event if still queued.
splash_flush_keys$:
    lda MODKEY
    and #0x80
    beq splash_wait_key$
    lda ASCIIKEY
    lda #0
    sta ASCIIKEY
    bra splash_flush_keys$

splash_wait_key$:
    lda MODKEY
    and #0x80
    beq splash_wait_key$

    lda ASCIIKEY
    lda #0
    sta ASCIIKEY

splash_restore$:
    sei

    ; Restore exact SEAM VIC-IV state.
    lda splash_saved_d060
    sta 0xd060
    lda splash_saved_d061
    sta 0xd061
    lda splash_saved_d062
    sta 0xd062
    lda splash_saved_d063
    sta 0xd063

    lda splash_saved_d058
    sta 0xd058
    lda splash_saved_d059
    sta 0xd059
    lda splash_saved_d05e
    sta 0xd05e

    lda splash_saved_d054
    sta 0xd054
    lda splash_saved_d031
    sta 0xd031
    lda splash_saved_d011
    sta 0xd011

    lda splash_saved_d020
    sta 0xd020
    lda splash_saved_d021
    sta 0xd021

    ; Restore shared long pointer.
    lda splash_saved_attic0
    sta attic_addr0
    lda splash_saved_attic1
    sta attic_addr1
    lda splash_saved_attic2
    sta attic_addr2
    lda splash_saved_attic3
    sta attic_addr3

    cli
    rts


; ------------------------------------------------------------
; Read SPLASH PRG using KERNAL sequential I/O.
;
; Device 8 is intentional for this first splash test: it is the same
; virtual drive from which KnockCSV is normally started.
;
; Carry clear = OK
; Carry set   = OPEN/CHKIN error
; ------------------------------------------------------------
splash_load_asset:
    lda #6
    ldx #.byte0 splash_filename
    ldy #.byte1 splash_filename
    jsr setnam

    lda #0
    ldx #0
    jsr setbnk

    lda #3
    ldx #8
    ldy #2
    jsr setlfs

    jsr open
    bcc +
    jmp splash_load_error$
+

    ldx #3
    jsr chkin
    bcs splash_load_close_error$

    ; Skip the two-byte PRG load address.
    jsr basin
    jsr basin

    ; Palette R[256].
    lda #0
    sta splash_index
splash_load_red$:
    jsr basin
    jsr splash_swapnib
    ldx splash_index
    sta 0xd100,x
    inc splash_index
    bne splash_load_red$

    ; Palette G[256].
    lda #0
    sta splash_index
splash_load_green$:
    jsr basin
    jsr splash_swapnib
    ldx splash_index
    sta 0xd200,x
    inc splash_index
    bne splash_load_green$

    ; Palette B[256].
    lda #0
    sta splash_index
splash_load_blue$:
    jsr basin
    jsr splash_swapnib
    ldx splash_index
    sta 0xd300,x
    inc splash_index
    bne splash_load_blue$

    ; Destination = $00040000.
    lda #0
    sta attic_addr0
    sta attic_addr1
    lda #0x04
    sta attic_addr2
    lda #0
    sta attic_addr3

    ; Exactly 64000 bytes = $FA00.
    lda #0x00
    sta splash_count0
    lda #0xfa
    sta splash_count1

splash_load_pixels$:
    jsr basin
    ldz #0
    sta [attic_addr0],z
    jsr splash_inc_ptr1

    jsr splash_dec_count
    bne splash_load_pixels$

    jsr clrchn
    lda #3
    jsr close
    clc
    rts

splash_load_close_error$:
    jsr clrchn
    lda #3
    jsr close
splash_load_error$:
    sec
    rts


; MEGA65 VIC-IV palette register byte order uses swapped nibbles.
splash_swapnib:
    sta splash_pal_tmp
    and #0x0f
    asl a
    asl a
    asl a
    asl a
    sta splash_pal_tmp2
    lda splash_pal_tmp
    lsr a
    lsr a
    lsr a
    lsr a
    ora splash_pal_tmp2
    rts


; ------------------------------------------------------------
; FCM screen map $C000:
; 1000 sequential CHR16 character numbers $1000..$13E7.
; ------------------------------------------------------------
splash_build_screen:
    lda #0x00
    sta attic_addr0
    lda #0xc0
    sta attic_addr1
    lda #0x00
    sta attic_addr2
    sta attic_addr3

    lda #0x00
    sta splash_char_lo
    lda #0x10
    sta splash_char_hi

    lda #.byte0 1000
    sta splash_count0
    lda #.byte1 1000
    sta splash_count1

splash_screen_loop$:
    ldz #0
    lda splash_char_lo
    sta [attic_addr0],z
    inz
    lda splash_char_hi
    sta [attic_addr0],z

    jsr splash_inc_ptr2

    inc splash_char_lo
    bne splash_char_ok$
    inc splash_char_hi
splash_char_ok$:

    jsr splash_dec_count
    bne splash_screen_loop$
    rts


; ------------------------------------------------------------
; Color RAM exactly like the working 3D FCM init:
; byte 0 = $00, byte 1 = $FF, for 1000 cells.
; ------------------------------------------------------------
splash_build_colorram:
    lda #0
    sta attic_addr0
    sta attic_addr1
    lda #0xf8
    sta attic_addr2
    lda #0x0f
    sta attic_addr3

    lda #.byte0 1000
    sta splash_count0
    lda #.byte1 1000
    sta splash_count1

splash_colourram_loop$:
    ldz #0
    lda #0x00
    sta [attic_addr0],z
    inz
    lda #0xff
    sta [attic_addr0],z

    jsr splash_inc_ptr2
    jsr splash_dec_count
    bne splash_colourram_loop$
    rts


splash_inc_ptr1:
    inc attic_addr0
    bne splash_inc_ptr1_done$
    inc attic_addr1
    bne splash_inc_ptr1_done$
    inc attic_addr2
    bne splash_inc_ptr1_done$
    inc attic_addr3
splash_inc_ptr1_done$:
    rts


splash_inc_ptr2:
    clc
    lda attic_addr0
    adc #2
    sta attic_addr0
    bcc splash_inc_ptr2_done$
    inc attic_addr1
    bne splash_inc_ptr2_done$
    inc attic_addr2
    bne splash_inc_ptr2_done$
    inc attic_addr3
splash_inc_ptr2_done$:
    rts


splash_dec_count:
    lda splash_count0
    bne splash_dec_count_low$
    dec splash_count1
splash_dec_count_low$:
    dec splash_count0
    lda splash_count0
    ora splash_count1
    rts


splash_draw_image:
    rts


splash_filename:
    .ascii "SPLASH"


    .section bss,bss

splash_count0:
    .space 1
splash_count1:
    .space 1
splash_index:
    .space 1
splash_char_lo:
    .space 1
splash_char_hi:
    .space 1
splash_pal_tmp:
    .space 1
splash_pal_tmp2:
    .space 1

splash_saved_d011:
    .space 1
splash_saved_d020:
    .space 1
splash_saved_d021:
    .space 1
splash_saved_d031:
    .space 1
splash_saved_d054:
    .space 1
splash_saved_d058:
    .space 1
splash_saved_d059:
    .space 1
splash_saved_d05e:
    .space 1
splash_saved_d060:
    .space 1
splash_saved_d061:
    .space 1
splash_saved_d062:
    .space 1
splash_saved_d063:
    .space 1

splash_saved_attic0:
    .space 1
splash_saved_attic1:
    .space 1
splash_saved_attic2:
    .space 1
splash_saved_attic3:
    .space 1
