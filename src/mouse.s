	.public mouse_init
	.public mouse_update

	.public mouse_xpos
	.public mouse_ypos
	.public mouse_prevxpos
	.public mouse_prevypos

	.public mouse_pressed
	.public mouse_right_pressed
	.public mouse_held
	.public mouse_released
	.public mouse_doubleclicked
	.public mouse_scale_to_25
	.public mouse_scale_to_50
	
MOUSE_MAX_X .equ 639
MOUSE_MAX_Y_25 .equ 199
MOUSE_MAX_Y_50 .equ 399

    .extern csv_screen_mode

    .section code,text

mouse_init:
    lda #0x10
    sta mouse_doubleclickthreshold

    ; seleziona paddle/mouse port 1 e inizializza valori precedenti
    lda #0xe0
    sta 0xdc02
    lda #0x40
    sta 0xdc00

    lda 0xd419
    sta mouse_paddlex
    lda 0xd41a
    sta mouse_paddley

    lda #0
    sta mouse_pressed
    sta mouse_held
    sta mouse_released
    sta mouse_doubleclicked
    sta mouse_released_timer
    sta mouse_pressedtimer
	sta mouse_longpressed
    sta mouse_longpressedtimer
    sta mouse_right_pressed
    sta mouse_right_held

    ; posizione iniziale circa centro schermo 640x200
    lda #.byte0 320
    sta mouse_xpos
    lda #.byte1 320
    sta mouse_xpos+1

    lda #.byte0 100
    sta mouse_ypos
    lda #.byte1 100
    sta mouse_ypos+1

    ; più border offset usato dalla routine originale
    lda #.byte0 (320 + 0x50)
    sta mouse_xpos_plusborder
    lda #.byte1 (320 + 0x50)
    sta mouse_xpos_plusborder+1

    lda #.byte0 (100 + 0x67)
    sta mouse_ypos_plusborder
    lda #.byte1 (100 + 0x67)
    sta mouse_ypos_plusborder+1
	
    lda #0xff
    sta 0xdc02
    sta 0xdc00

    rts

mouse_update:

		; 0xdc00 = data port A
		;	read/write:	bit 0...7 keyboard matrix columns
		;	read:		joystick port 2:	bit 0..3 direction, but 4 fire button, 0 = activated
		;	read:		lightpen:			bit 4 (as fire button), connected also with '/LP' (pin 9) of the vic
		;	read:		paddles:			bit 2..3 fire buttons, bit 6..7 switch control port 1 (%01=Paddles A) or 2 (%10=Paddles B)
		; 0xdc01 = data port B
		;	read/write:	bit 0...7 keyboard matrix columns
		;	read:		joystick port 1:	bit 0..3 direction, but 4 fire button, 0 = activated
		;	read:		bit 6:				Timer A: Toggle/Impulse output (see register 14 bit 2)
		;	read:		bit 7:				Timer B: Toggle/Impulse output (see register 15 bit 2)
		; 0xdc02 = Data Direction Port A
		; 	Bit X: 0=Input (read only), 1=Output (read and write)
		; 0xdc03 = Data Direction Port B
		; 	Bit X: 0=Input (read only), 1=Output (read and write)

		; additional bits for UP DN scroll wheel
		; Bit       7   6   5   4   3   2   1   0
		; function  --  --  --  LMB DN  UP  MMB RMB

		lda #0b11100000									; set data direction to  0=input (read only) for all 8 data lines
		sta 0xdc02

		lda #0x40
		sta 0xdc00

		lda 0xd419										; read paddle port and store mouse pos
		sta mouse_d419
		ldy mouse_paddlex
		jsr mouse_count_delta
		sty mouse_paddlex

		clc
		adc mouse_xpos_plusborder+0
		sta mouse_xpos_plusborder+0
		txa												; x = 0/ff after mouse_count_delta
		adc mouse_xpos_plusborder+1
		sta mouse_xpos_plusborder+1

		lda 0xd41a
		sta mouse_d41a
		ldy mouse_paddley
		jsr mouse_count_delta
		sty mouse_paddley

		sec
		eor #0xff
		adc mouse_ypos_plusborder+0
		sta mouse_ypos_plusborder+0
		txa												; x = 0/ff after mouse_count_delta
		eor #0xff
		adc mouse_ypos_plusborder+1
		sta mouse_ypos_plusborder+1

		lda mouse_xpos+0								; store previous positions
		sta mouse_prevxpos+0
		lda mouse_xpos+1
		sta mouse_prevxpos+1
		lda mouse_ypos+0
		sta mouse_prevypos+0
		lda mouse_ypos+1
		sta mouse_prevypos+1

		sec												; subtract upper left corner position
		lda mouse_xpos_plusborder+0
		sbc #0x50
		sta mouse_xpos+0
		lda mouse_xpos_plusborder+1
		sbc #0x00
		sta mouse_xpos+1

		sec
		lda mouse_ypos_plusborder+0
		sbc #0x67 ; 0xd048
		sta mouse_ypos+0
		lda mouse_ypos_plusborder+1
		sbc #0x00
		sta mouse_ypos+1

		jsr mouse_constrain_x
		jsr mouse_constrain_y

		clc												; mouse is constraint. calculate new plusborder values
		lda mouse_xpos+0
		adc #0x50
		sta mouse_xpos_plusborder+0
		lda mouse_xpos+1
		adc #0x00
		sta mouse_xpos_plusborder+1
		clc												; mouse is constraint. calculate new plusborder values
		lda mouse_ypos+0
		adc #0x67 ; 0xd048
		sta mouse_ypos_plusborder+0
		lda mouse_ypos+1
		adc #0x00
		sta mouse_ypos_plusborder+1

		inc mouse_released_timer
		lda mouse_released_timer
        cmp mouse_doubleclickthreshold
        bmi mouse_released_timer_ok$
        lda mouse_doubleclickthreshold
        sta mouse_released_timer

mouse_released_timer_ok$:
        lda #0x00                                        ; edge flags for this poll
        sta mouse_pressed
        sta mouse_released
        sta mouse_doubleclicked
        sta mouse_right_pressed

        ; Snapshot mouse buttons WITHOUT allowing the keyboard matrix
        ; to pull bits of $DC01 low.
        ;
        ; During paddle reading $DC00 is $40. With that value several
        ; keyboard columns are selected, so a keyboard key (SPACE in
        ; particular) can look exactly like LMB on $DC01 bit 4.
        ; That made SPACE generate mouse_pressed and the main viewer
        ; committed/exited the full-screen editor.
        ;
        ; Drive all keyboard-matrix columns high while sampling port 1,
        ; then restore $40 for the paddle/mouse routing used above.
        lda #0xff
        sta 0xdc00
        lda 0xdc01
        sta mouse_buttons_raw
        lda #0x40
        sta 0xdc00

        ; bit 4 = LMB (standard)
        ; bit 0 = RMB when the mouse/adapter exposes the extended line
        ;         (for example a suitably configured mouSTer).

        ; Standard left button.
        lda mouse_buttons_raw
        and #0b00010000
        beq mouse_event_pressed
		
mouse_event_released:
        lda mouse_held
        bne mouse_was_held$
        bra mouse_check_end

mouse_was_held$:
        lda #0x01										; it was pressed before, so must be released now
		sta mouse_released
		lda #0x00
		sta mouse_held
		sta mouse_longpressed
		sta mouse_pressedtimer
		sta mouse_longpressedtimer
		lda mouse_released_timer						; read released timer
		cmp mouse_doubleclickthreshold
		beq mouse_event_startreleasedtimer				; it's the same as the theshold, so restart it
		bra mouse_event_doubleclicked					; it's not, so this must be a double click

mouse_event_startreleasedtimer:
		lda #0x00
		sta mouse_released_timer
		bra mouse_check_end

mouse_event_doubleclicked:
		lda #0x01
		sta mouse_doubleclicked
		bra mouse_check_end

mouse_event_pressed:
        lda mouse_held
        beq mouse_event_newpress$       ; non era premuto prima

        ; era già premuto: gestisci long press
        inc mouse_pressedtimer
        lda mouse_pressedtimer
        cmp #0x12
        bne mouse_event_stillheld$

        lda #0x10
        sta mouse_pressedtimer
        inc mouse_longpressedtimer
        lda #0x01
        sta mouse_longpressed

        bra mouse_event_newpress_done$

mouse_event_stillheld$:
        bra mouse_check_end             ; già premuto: mouse_pressed resta 0

mouse_event_newpress$:
        lda #0x01
        sta mouse_pressed
        sta mouse_held

        lda mouse_xpos
        sta mouse_xpos_pressed
        lda mouse_xpos+1
        sta mouse_xpos_pressed+1

        lda mouse_ypos
        sta mouse_ypos_pressed
        lda mouse_ypos+1
        sta mouse_ypos_pressed+1

mouse_event_newpress_done$:

mouse_check_end:
        ; Minimal RMB edge detector. No debounce, no IRQ manipulation.
        ; $DC01 bit 0 is active low on the mouse/adapter protocol used here.
        lda mouse_buttons_raw
        and #0b00000001
        bne mouse_right_release

        lda mouse_right_held
        bne mouse_right_done
        lda #1
        sta mouse_right_held
        sta mouse_right_pressed
        bra mouse_right_done

mouse_right_release:
        lda #0
        sta mouse_right_held

mouse_right_done:
        lda #0xff                        ; enable keyboard again
        sta 0xdc02
        sta 0xdc00

        rts

mouse_constrain_x:
    ; clamp signed 16-bit X to 0..639 ($027F)
    lda mouse_xpos+1
    bmi mcx_negative$

    cmp #.byte1 MOUSE_MAX_X
    bcc mcx_ok$
    bne mcx_high$

    lda mouse_xpos+0
    cmp #(.byte0 MOUSE_MAX_X + 1)
    bcc mcx_ok$

mcx_high$:
    lda #.byte0 MOUSE_MAX_X
    sta mouse_xpos+0
    lda #.byte1 MOUSE_MAX_X
    sta mouse_xpos+1
    rts

mcx_negative$:
    lda #0x00
    sta mouse_xpos+0
    sta mouse_xpos+1

mcx_ok$:
    rts

mouse_constrain_y:
    ; Runtime clamp: 0..199 in 80x25, 0..399 in 80x50.
    lda mouse_ypos+1
    bmi mcy_negative$

    lda csv_screen_mode
    bne mcy_50$

mcy_25$:
    lda mouse_ypos+1
    beq mcy_25_low$
    jmp mcy_high25$
mcy_25_low$:
    lda mouse_ypos
    cmp #200
    bcc mcy_ok$
mcy_high25$:
    lda #199
    sta mouse_ypos
    lda #0
    sta mouse_ypos+1
    rts

mcy_50$:
    lda mouse_ypos+1
    cmp #1
    bcc mcy_ok$
    bne mcy_high50$
    lda mouse_ypos
    cmp #144                    ; 400 = $0190
    bcc mcy_ok$
mcy_high50$:
    lda #143                    ; 399 = $018F
    sta mouse_ypos
    lda #1
    sta mouse_ypos+1
    rts

mcy_negative$:
    lda #0
    sta mouse_ypos
    sta mouse_ypos+1
mcy_ok$:
    rts


; Scale current Y so the pointer remains at the same visual location
; when changing between 25 and 50 rows.
mouse_scale_to_50:
    asl mouse_ypos
    rol mouse_ypos+1
    asl mouse_prevypos
    rol mouse_prevypos+1
    jsr mouse_rebuild_y_border
    rts

mouse_scale_to_25:
    lsr mouse_ypos+1
    ror mouse_ypos
    lsr mouse_prevypos+1
    ror mouse_prevypos
    jsr mouse_rebuild_y_border
    rts

mouse_rebuild_y_border:
    clc
    lda mouse_ypos
    adc #0x67
    sta mouse_ypos_plusborder
    lda mouse_ypos+1
    adc #0
    sta mouse_ypos_plusborder+1
    rts


mouse_count_delta:
        ; input:
        ;   A = valore paddle corrente
        ;   Y = valore paddle precedente
        ;
        ; output:
        ;   A = delta signed 8 bit
        ;   X = estensione segno: 0x00 o 0xff
        ;   Y = valore corrente, da salvare come nuovo precedente

        sty mouse_temp1          ; old
        sta mouse_temp2          ; current

        sec
        sbc mouse_temp1          ; current - old
        and #0x7f                ; delta modulo 128

        beq mcd_zero

        cmp #0x40
        bcs mcd_negative

mcd_positive:
        ldx #0x00
        ldy mouse_temp2
        rts

mcd_negative:
        ; valore signed negativo:
        ; $7f -> $ff = -1
        ; $7e -> $fe = -2
        ; $40 -> $c0 = -64
        ora #0x80
        ldx #0xff
        ldy mouse_temp2
        rts

mcd_zero:
        lda #0x00
        ldx #0x00
        ldy mouse_temp2
        rts
		
	.section data,data

mouse_delta_adjust:
		;.byte 0x01, 0x01, 0x02, 0x02, 0x03, 0x04, 0x06, 0x08
		;.byte 0x09, 0x0b, 0x0d, 0x0f, 0x11, 0x13, 0x15, 0x19
		;.byte 0x1d, 0x20, 0x23, 0x26, 0x29, 0x2c, 0x2f, 0x32
		;.byte 0x35, 0x38, 0x3c, 0x41, 0x4b, 0x50, 0x5a, 0x64

		;.byte 0x01, 0x02, 0x03, 0x05, 0x08, 0x0a, 0x0d, 0x11
		;.byte 0x14, 0x18, 0x1c, 0x21, 0x25, 0x29, 0x2c, 0x2f
		;.byte 0x35, 0x38, 0x3c, 0x41, 0x4b, 0x50, 0x5a, 0x64
		;.byte 0x64, 0x64, 0x64, 0x64, 0x64, 0x64, 0x64, 0x64

		.byte 0x02, 0x08, 0x10, 0x25, 0x35, 0x4b, 0x64, 0x7f
		.byte 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f
		.byte 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f
		.byte 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f
		
    .section zdata,bss

mouse_temp1:                 .space 1
mouse_temp2:                 .space 1

mouse_d419:                  .space 1
mouse_d41a:                  .space 1

mouse_buttons_raw:           .space 1
mouse_paddlex:               .space 1
mouse_paddley:               .space 1

mouse_xpos_plusborder:       .space 2
mouse_xpos:                  .space 2
mouse_prevxpos:              .space 2
mouse_xpos_pressed:          .space 2

mouse_ypos_plusborder:       .space 2
mouse_ypos:                  .space 2
mouse_prevypos:              .space 2
mouse_ypos_pressed:          .space 2

mouse_pressed:               .space 1
mouse_held:                  .space 1
mouse_longpressed:           .space 1
mouse_released:              .space 1
mouse_doubleclicked:         .space 1
mouse_right_pressed:         .space 1
mouse_right_held:            .space 1

mouse_released_timer:        .space 1
mouse_doubleclickthreshold:  .space 1
mouse_pressedtimer:          .space 1
mouse_longpressedtimer:      .space 1
