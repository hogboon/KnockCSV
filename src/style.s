; ------------------------------------------------------------
; style.s
; KnockCSV - SEAM / CHR16 text layer + central style values
; ------------------------------------------------------------

    .public style_seam_init
    .public style_seam_restore
    .public style_apply_screen_mode
    .public csv_screen_mode
    .public style_palette_init
    .public style_utf8_font_init
    .public seam_plot
    .public seam_bsout
    .public seam_clear_row
    .public seam_set_attr
    .public seam_fill_attr_span
    .public seam_cursor_blink_at

    .public style_mouse_color

    .public style_screen_bg

    .public style_border
    .public style_fg_menu
    .public style_bg_menu
    .public style_fg_dropdown
    .public style_bg_dropdown
    .public style_fg_header
    .public style_bg_header
    .public style_fg_cell
    .public style_bg_cell
    .public style_fg_cell_alt
    .public style_bg_cell_alt
    .public style_fg_selection
    .public style_bg_selection
    .public style_fg_textedit
    .public style_bg_textedit

    .public seam_apply_menu_style
    .public seam_apply_dropdown_style
    .public seam_apply_header_style
    .public seam_apply_cell_style
    .public seam_apply_cell_alt_style
    .public seam_apply_selection_style
    .public seam_apply_textedit_style

; Persistent original video profile survives KnockCSV <-> EDIT chain-loads.
STYLE_ORIG_PAL_R .equ 0x1f80
STYLE_ORIG_PAL_G .equ 0x1f90
STYLE_ORIG_PAL_B .equ 0x1fa0
STYLE_ORIG_MAGIC .equ 0x1fe0
STYLE_ORIG_D011  .equ 0x1fe1
STYLE_ORIG_D015  .equ 0x1fe2
STYLE_ORIG_D017  .equ 0x1fe3
STYLE_ORIG_D01C  .equ 0x1fe4
STYLE_ORIG_D01D  .equ 0x1fe5
STYLE_ORIG_D021  .equ 0x1fe6
STYLE_ORIG_D027  .equ 0x1fe7
STYLE_ORIG_D031  .equ 0x1fe8
STYLE_ORIG_D051  .equ 0x1fe9
STYLE_ORIG_D054  .equ 0x1fea
STYLE_ORIG_D058  .equ 0x1feb
STYLE_ORIG_D059  .equ 0x1fec
STYLE_ORIG_D05B  .equ 0x1fed
STYLE_ORIG_D05E  .equ 0x1fee
STYLE_ORIG_D05F  .equ 0x1fef
STYLE_ORIG_D060  .equ 0x1ff0
STYLE_ORIG_D061  .equ 0x1ff1
STYLE_ORIG_D062  .equ 0x1ff2
STYLE_ORIG_D063  .equ 0x1ff3
STYLE_ORIG_D068  .equ 0x1ff4
STYLE_ORIG_D069  .equ 0x1ff5
STYLE_ORIG_D06A  .equ 0x1ff6
STYLE_ORIG_D06C  .equ 0x1ff7
STYLE_ORIG_D06D  .equ 0x1ff8
STYLE_ORIG_D06E  .equ 0x1ff9
STYLE_ORIG_D076  .equ 0x1ffa
STYLE_ORIG_D077  .equ 0x1ffb
STYLE_ORIG_D07B  .equ 0x1ffc
STYLE_ORIG_D020  .equ 0x1ffd
STYLE_ORIG_MAGIC_VALUE .equ 0xc5

    .section code,text

; ------------------------------------------------------------
; CUSTOM RGB PALETTE
;
; VIC-IV palette registers:
;   $D100 + index = RED
;   $D200 + index = GREEN
;   $D300 + index = BLUE
;
; The VIC-IV palette bytes use swapped nibbles, so RGB values below
; are written through style_swapnib exactly as in the 3D project.
;
; Edit ONLY style_palette_r/g/b to experiment with colours.
; Values are normal 0..255 RGB.
;
; Palette indices currently used by KnockCSV:
;   0 = common text colour / screen background helper / default border
;   1 = normal cell background, even columns
;   2 = selection background
;   3 = header background
;   4 = alternate cell background, odd columns
;   5 = dropdown background
;   7 = menu-bar background
;
; Remaining entries 6,8..15 are free for future UI styles.
; ------------------------------------------------------------

style_palette_init:
    ldx #0

style_palette_loop$:
    lda style_palette_r,x
    jsr style_swapnib
    sta 0xd100,x

    lda style_palette_g,x
    jsr style_swapnib
    sta 0xd200,x

    lda style_palette_b,x
    jsr style_swapnib
    sta 0xd300,x

    inx
    cpx #16
    bne style_palette_loop$
    rts


style_swapnib:
    sta style_pal_tmp0
    and #0x0f
    asl a
    asl a
    asl a
    asl a
    sta style_pal_tmp1

    lda style_pal_tmp0
    lsr a
    lsr a
    lsr a
    lsr a
    ora style_pal_tmp1
    rts


; ------------------------------------------------------------
; Permanent SEAM setup
; CHR16 ON, ECM OFF, 80 columns, 160 bytes/line,
; screen RAM at $00040000.
; ------------------------------------------------------------
style_seam_init:
    ; Capture BASIC/KERNAL video state only on the first KnockCSV load.
    ; $1FE0-$1FFC survives chain-loading EDIT.PRG and main viewer PRG.
    lda STYLE_ORIG_MAGIC
    cmp #STYLE_ORIG_MAGIC_VALUE
    bne +
    jmp style_orig_already_saved$
+

    ; KnockCSV replaces palette entries 0..15, so preserve them too.
    ldx #0
style_save_palette_loop$:
    lda 0xd100,x
    sta STYLE_ORIG_PAL_R,x
    lda 0xd200,x
    sta STYLE_ORIG_PAL_G,x
    lda 0xd300,x
    sta STYLE_ORIG_PAL_B,x
    inx
    cpx #16
    bne style_save_palette_loop$

    lda 0xd011
    sta STYLE_ORIG_D011
    lda 0xd015
    sta STYLE_ORIG_D015
    lda 0xd017
    sta STYLE_ORIG_D017
    lda 0xd01c
    sta STYLE_ORIG_D01C
    lda 0xd01d
    sta STYLE_ORIG_D01D
    lda 0xd020
    sta STYLE_ORIG_D020
    lda 0xd021
    sta STYLE_ORIG_D021
    lda 0xd027
    sta STYLE_ORIG_D027
    lda 0xd031
    sta STYLE_ORIG_D031
    lda 0xd051
    sta STYLE_ORIG_D051
    lda 0xd054
    sta STYLE_ORIG_D054
    lda 0xd058
    sta STYLE_ORIG_D058
    lda 0xd059
    sta STYLE_ORIG_D059
    lda 0xd05b
    sta STYLE_ORIG_D05B
    lda 0xd05e
    sta STYLE_ORIG_D05E
    lda 0xd05f
    sta STYLE_ORIG_D05F
    lda 0xd060
    sta STYLE_ORIG_D060
    lda 0xd061
    sta STYLE_ORIG_D061
    lda 0xd062
    sta STYLE_ORIG_D062
    lda 0xd063
    sta STYLE_ORIG_D063
    lda 0xd068
    sta STYLE_ORIG_D068
    lda 0xd069
    sta STYLE_ORIG_D069
    lda 0xd06a
    sta STYLE_ORIG_D06A
    lda 0xd06c
    sta STYLE_ORIG_D06C
    lda 0xd06d
    sta STYLE_ORIG_D06D
    lda 0xd06e
    sta STYLE_ORIG_D06E
    lda 0xd076
    sta STYLE_ORIG_D076
    lda 0xd077
    sta STYLE_ORIG_D077
    lda 0xd07b
    sta STYLE_ORIG_D07B

    lda #STYLE_ORIG_MAGIC_VALUE
    sta STYLE_ORIG_MAGIC

style_orig_already_saved$:
    jsr style_palette_init
    jsr style_utf8_font_init

    ; Capture the exact VIC-IV vertical profile present in the known-good
    ; 80x25 startup state. The KERNAL is never asked to change text mode,
    ; so these bytes remain our authoritative 25-row profile.
    lda STYLE_ORIG_D031

    sta style_v25_d031

    lda STYLE_ORIG_D05B

    sta style_v25_d05b

    lda STYLE_ORIG_D07B

    sta style_v25_d07b

    lda STYLE_ORIG_D051

    sta style_v25_d051

    ; Disable MEGA+SHIFT charset switching.
    ; On C65/MEGA65 PETSCII $0B disables case switching;
    ; $0C enables it.
    lda #0x0b
    jsr 0xffd2

    lda 0xd011
    and #0xbf
    sta 0xd011

    lda 0xd054
    ora #0x01
    sta 0xd054

    lda #160
    sta 0xd058
    lda #0
    sta 0xd059

    ; --------------------------------------------------------
    ; KnockCSV custom 512-character font at $00050000.
    ; style_utf8_font_init copies Font A ($29000) there and
    ; replaces screen codes $0180-$01DF with European glyphs.
    ; --------------------------------------------------------
    lda #0x00
    sta 0xd068
    sta 0xd069
    lda #0x05
    sta 0xd06a

    lda #0x00
    sta 0xd060
    sta 0xd061
    lda #0x04
    sta 0xd062
    lda #0x00
    sta 0xd063

    ; Common screen/text colour used by reversed cells.
    lda style_border
    sta 0xd020
    lda style_screen_bg
    sta 0xd021

    jsr seam_apply_cell_style

    ; Clear all 25 rows in both screen and color memory.
    ldx #0
seam_init_clear_loop$:
    jsr seam_clear_row
    inx
    cpx #25
    bne seam_init_clear_loop$
    rts


; ------------------------------------------------------------
; style_seam_restore
; Restore the text/video environment captured before KnockCSV startup.
; ------------------------------------------------------------
style_seam_restore:
    sei

    ; Restore sprite-related state first; in the normal KERNAL environment
    ; sprite 0 is normally disabled, but the exact previous byte is restored.
    lda STYLE_ORIG_D015
    sta 0xd015
    lda STYLE_ORIG_D017
    sta 0xd017
    lda STYLE_ORIG_D01C
    sta 0xd01c
    lda STYLE_ORIG_D01D
    sta 0xd01d
    lda STYLE_ORIG_D027
    sta 0xd027
    lda STYLE_ORIG_D05F
    sta 0xd05f
    lda STYLE_ORIG_D06C
    sta 0xd06c
    lda STYLE_ORIG_D06D
    sta 0xd06d
    lda STYLE_ORIG_D06E
    sta 0xd06e
    lda STYLE_ORIG_D076
    sta 0xd076
    lda STYLE_ORIG_D077
    sta 0xd077

    ; Restore screen geometry, address, character generator and VIC-IV mode.
    lda STYLE_ORIG_D060
    sta 0xd060
    lda STYLE_ORIG_D061
    sta 0xd061
    lda STYLE_ORIG_D062
    sta 0xd062
    lda STYLE_ORIG_D063
    sta 0xd063
    lda STYLE_ORIG_D058
    sta 0xd058
    lda STYLE_ORIG_D059
    sta 0xd059
    lda STYLE_ORIG_D05E
    sta 0xd05e
    lda STYLE_ORIG_D068
    sta 0xd068
    lda STYLE_ORIG_D069
    sta 0xd069
    lda STYLE_ORIG_D06A
    sta 0xd06a
    lda STYLE_ORIG_D051
    sta 0xd051
    lda STYLE_ORIG_D054
    sta 0xd054
    lda STYLE_ORIG_D05B
    sta 0xd05b
    lda STYLE_ORIG_D07B
    sta 0xd07b
    lda STYLE_ORIG_D031
    sta 0xd031
    lda STYLE_ORIG_D011
    sta 0xd011
    lda STYLE_ORIG_D020
    sta 0xd020
    lda STYLE_ORIG_D021
    sta 0xd021

    ; Restore the 16 palette entries changed by KnockCSV.
    ldx #0
style_restore_palette_loop$:
    lda STYLE_ORIG_PAL_R,x
    sta 0xd100,x
    lda STYLE_ORIG_PAL_G,x
    sta 0xd200,x
    lda STYLE_ORIG_PAL_B,x
    sta 0xd300,x
    inx
    cpx #16
    bne style_restore_palette_loop$

    cli

    ; Re-enable MEGA+SHIFT charset switching for the KERNAL environment.
    lda #0x0c
    jsr 0xffd2

    ; Clear/home using the restored KERNAL text screen.
    lda #0x93
    jsr 0xffd2

    ; Next launch must capture the then-current KERNAL environment again.
    lda #0
    sta STYLE_ORIG_MAGIC
    rts


; ------------------------------------------------------------
; SEAM foreground/background style helpers
;
; VIC-IV SEAM still has one foreground color plus reverse/blink/
; underline in the active colour/attribute byte. There is no separate
; per-cell background field.
;
; Strategy:
;   - $D021 = style_screen_bg, the common visible text colour for
;     reversed cells.
;   - if requested BG == style_screen_bg:
;         normal character, requested FG is used.
;   - otherwise:
;         reverse character, requested BG becomes the cell fill colour.
;         visible text colour is style_screen_bg.
;
; INPUT to seam_apply_fg_bg:
;   A = requested foreground
;   X = requested background
; ------------------------------------------------------------

seam_apply_fg_bg:
    sta seam_style_fg
    stx seam_style_bg

    cpx style_screen_bg
    bne seam_style_reverse$

    lda seam_style_fg
    sta seam_attr
    rts

seam_style_reverse$:
    txa
    ora #0x20
    sta seam_attr
    rts


seam_apply_menu_style:
    lda style_fg_menu
    ldx style_bg_menu
    jmp seam_apply_fg_bg

seam_apply_dropdown_style:
    lda style_fg_dropdown
    ldx style_bg_dropdown
    jmp seam_apply_fg_bg

seam_apply_header_style:
    lda style_fg_header
    ldx style_bg_header
    jmp seam_apply_fg_bg

seam_apply_cell_style:
    lda style_fg_cell
    ldx style_bg_cell
    jmp seam_apply_fg_bg

; Alternate normal CSV column style (odd absolute columns).
seam_apply_cell_alt_style:
    lda style_fg_cell_alt
    ldx style_bg_cell_alt
    jmp seam_apply_fg_bg

seam_apply_selection_style:
    lda style_fg_selection
    ldx style_bg_selection
    jmp seam_apply_fg_bg


seam_apply_textedit_style:
    lda style_fg_textedit
    ldx style_bg_textedit
    jmp seam_apply_fg_bg


; ------------------------------------------------------------
; style_utf8_font_init
; Build private 4KB / 512-character font at $00050000.
; ------------------------------------------------------------

; ------------------------------------------------------------
; Runtime 80x25 / 80x50 video profile.
; 80x25 is restored exactly from the values captured at startup.
; 80x50 is the known-good profile from the working 80x50 build.
; ------------------------------------------------------------
style_apply_screen_mode:
    ; Do NOT invoke the KERNAL 80x50 mode here.
    ; KnockCSV owns its screen rendering, and the KERNAL 80x50 path reserves
    ; bank 4 region 0 -- exactly where KnockCSV screen RAM lives ($040000).
    ;
    ; Instead switch only the VIC-IV vertical profile:
    ;   25 rows = exact startup register values captured above
    ;   50 rows = exact additions from the known-good standalone 80x50 build.
    lda csv_screen_mode
    bne style_direct_50$

style_direct_25$:
    lda style_v25_d031
    sta 0xd031
    lda style_v25_d05b
    sta 0xd05b
    lda style_v25_d07b
    sta 0xd07b
    lda style_v25_d051
    sta 0xd051
    jmp style_reapply_common_video$

style_direct_50$:
    ; Exact vertical block from the working standalone 80x50 archive.
    lda 0xd031
    ora #0x08
    sta 0xd031

    lda #0x00
    sta 0xd05b
    lda #49
    sta 0xd07b

    lda 0xd051
    and #0xbf
    sta 0xd051

style_reapply_common_video$:
    ; Re-assert the complete KnockCSV text profile after the geometry change.
    lda 0xd011
    and #0xbf
    sta 0xd011

    lda 0xd054
    ora #0x01
    sta 0xd054

    lda #160
    sta 0xd058
    lda #0
    sta 0xd059

    ; Custom 512-character font at $00050000.
    lda #0x00
    sta 0xd068
    sta 0xd069
    lda #0x05
    sta 0xd06a

    ; KnockCSV screen RAM at $00040000.
    lda #0x00
    sta 0xd060
    sta 0xd061
    lda #0x04
    sta 0xd062
    lda #0x00
    sta 0xd063

    lda style_screen_bg
    sta 0xd021

    jsr seam_apply_cell_style
    rts


style_utf8_font_init:
    lda #0x00
    sta seam_screen0
    lda #0x90
    sta seam_screen1
    lda #0x02
    sta seam_screen2
    lda #0x00
    sta seam_screen3

    lda #0x00
    sta seam_color0
    sta seam_color1
    lda #0x05
    sta seam_color2
    lda #0x00
    sta seam_color3

    lda #0x00
    sta font_count0
    lda #0x10
    sta font_count1
style_utf8_copy_font$:
    ldz #0
    lda [seam_screen0],z
    sta [seam_color0],z
    jsr style_inc_font_src
    jsr style_inc_font_dst
    dec font_count0
    bne style_utf8_copy_font$
    dec font_count1
    bne style_utf8_copy_font$

    lda #0x00
    sta seam_color0
    lda #0x0c
    sta seam_color1
    lda #0x05
    sta seam_color2
    lda #0x00
    sta seam_color3

    lda #.byte0 utf8_glyph_data
    sta seam_screen0
    lda #.byte1 utf8_glyph_data
    sta seam_screen1
    lda #0x00
    sta seam_screen2
    lda #0x00
    sta seam_screen3

    lda #0x00
    sta font_count0
    lda #0x03
    sta font_count1
style_utf8_patch_font$:
    ldz #0
    lda [seam_screen0],z
    sta [seam_color0],z
    jsr style_inc_font_src
    jsr style_inc_font_dst
    dec font_count0
    bne style_utf8_patch_font$
    dec font_count1
    bne style_utf8_patch_font$

    ; Two extra glyphs after the original 96: U+013D / U+013E (Ľ / ľ).
    lda #16
    sta font_count0
style_utf8_patch_extra$:
    ldz #0
    lda [seam_screen0],z
    sta [seam_color0],z
    jsr style_inc_font_src
    jsr style_inc_font_dst
    dec font_count0
    bne style_utf8_patch_extra$
    rts

style_inc_font_src:
    inc seam_screen0
    bne style_font_src_done$
    inc seam_screen1
    bne style_font_src_done$
    inc seam_screen2
    bne style_font_src_done$
    inc seam_screen3
style_font_src_done$:
    rts

style_inc_font_dst:
    inc seam_color0
    bne style_font_dst_done$
    inc seam_color1
    bne style_font_dst_done$
    inc seam_color2
    bne style_font_dst_done$
    inc seam_color3
style_font_dst_done$:
    rts


; ------------------------------------------------------------
; seam_plot
; Same call pattern used by KERNAL PLOT in this project:
;   X = row, Y = column, C clear (ignored)
; ------------------------------------------------------------
seam_plot:
    ; PLOT replacement must preserve X/Y for the existing callers.
    stx seam_plot_saved_x
    sty seam_plot_saved_y

    stx seam_cursor_row
    sty seam_cursor_col
    jsr seam_make_ptrs

    ldx seam_plot_saved_x
    ldy seam_plot_saved_y
    rts


; ------------------------------------------------------------
; seam_set_attr
; A = CHR16 color/attribute byte:
; bits 0-3,6 = foreground palette index
; bit 4 = blink
; bit 5 = reverse
; bit 7 = underline
; ------------------------------------------------------------
seam_set_attr:
    sta seam_attr
    rts


; ------------------------------------------------------------
; seam_bsout
; A = ASCII/PETSCII character.
; Writes one CHR16 screen cell + one CHR16 color cell.
; Preserves X/Y because existing UI loops use them as counters.
; ------------------------------------------------------------
seam_bsout:
    sta seam_input_char
    stx seam_saved_x
    sty seam_saved_y

    ; CLR/HOME ignored: SEAM screen clearing is explicit.
    lda seam_input_char
    cmp #0x93
    bne +
    ldx seam_saved_x
    ldy seam_saved_y
    rts
+

    ; --------------------------------------------------------
    ; PETSCII -> screen code for FIXED lowercase+uppercase set.
    ;
    ; CHR16 bank $01xx (second built-in charset) is always used.
    ;
    ; Important petcat / PETSCII letter ranges:
    ;
    ;   $41..$5A  -> lowercase a..z
    ;                screen $01..$1A
    ;
    ;   $61..$7A  -> uppercase A..Z (duplicate/alternate range)
    ;                screen $41..$5A
    ;
    ;   $C1..$DA  -> uppercase A..Z used by shifted PETSCII
    ;                screen $41..$5A
    ;
    ; This preserves mixed case in petcat-generated SEQ files.
    ; --------------------------------------------------------

    lda #1
    sta seam_char_hi

    lda seam_input_char

    ; --------------------------------------------------------
    ; KnockCSV private display convention:
    ; canonical embedded newline $0A -> small return marker.
    ;
    ; In the built-in lowercase+uppercase charset, screen code
    ; $1F is the PETSCII left-arrow glyph. It is written directly
    ; instead of feeding $0A through the normal PETSCII mapping.
    ;
    ; The logical CSV byte remains $0A in Attic RAM.
    ; --------------------------------------------------------
    cmp #0x0a
    bne seam_not_csv_return$
    lda #0x1f
    sta seam_char_lo
    lda #1
    sta seam_char_hi
    jmp seam_write_char$

seam_not_csv_return$:
    lda seam_input_char

    ; KnockCSV private European one-byte encoding.
    ; $80..$C0 = indices 0..64, $DB..$FB = indices 65..97.
    ; $C1..$DA stays reserved for legacy PETSCII uppercase.
    cmp #0x80
    bcc seam_not_utf8_private$
    cmp #0xc1
    bcc seam_utf8_private_low$
    cmp #0xdb
    bcc seam_not_utf8_private$
    cmp #0xfc
    bcs seam_not_utf8_private$
    sec
    sbc #0xdb
    clc
    adc #0xc1
    sta seam_char_lo
    lda #1
    sta seam_char_hi
    jmp seam_write_char$

seam_utf8_private_low$:
    sta seam_char_lo
    lda #1
    sta seam_char_hi
    jmp seam_write_char$

seam_not_utf8_private$:
    lda seam_input_char

    ; PETSCII $C1..$DA = uppercase letters.
    cmp #0xc1
    bcc seam_check_lower_letters$
    cmp #0xdb
    bcc +
    jmp seam_check_high_other$
+
    sec
    sbc #0x80              ; $C1..$DA -> $41..$5A
    sta seam_char_lo
    jmp seam_write_char$

seam_check_lower_letters$:
    lda seam_input_char

    ; PETSCII $41..$5A = lowercase letters in shifted/mixed mode.
    cmp #0x41
    bcc seam_check_upper_alt$
    cmp #0x5b
    bcs seam_check_upper_alt$
    sec
    sbc #0x40              ; $41..$5A -> $01..$1A
    sta seam_char_lo
    jmp seam_write_char$

seam_check_upper_alt$:
    lda seam_input_char

    ; --------------------------------------------------------
    ; PETSCII graphics used by the KnockCSV UI in mixed-case mode.
    ;
    ; $5B -> screen $1B  [
    ; $5D -> screen $1D  ]
    ; $5E -> screen $1E  up-arrow glyph
    ;
    ; Previously these fell through to '?' because the fixed
    ; mixed-case mapper only handled letters and low punctuation.
    ; --------------------------------------------------------
    cmp #0x5b
    bne +
    lda #0x1b
    sta seam_char_lo
    jmp seam_write_char$
+
    cmp #0x5d
    bne +
    lda #0x1d
    sta seam_char_lo
    jmp seam_write_char$
+
    cmp #0x5e
    bne +
    lda #0x1e
    sta seam_char_lo
    jmp seam_write_char$
+
    ; ASCII/UTF-8 underscore $5F -> screen code $64
    ; in the MEGA65 lowercase+uppercase charset.
    cmp #0x5f
    bne +
    lda #0x64
    sta seam_char_lo
    jmp seam_write_char$
+

    lda seam_input_char

    ; PETSCII $61..$7A = alternate uppercase range.
    cmp #0x61
    bcc seam_check_ascii_punct$
    cmp #0x7b
    bcs seam_check_high_other$
    sec
    sbc #0x20              ; $61..$7A -> $41..$5A
    sta seam_char_lo
    jmp seam_write_char$

seam_check_ascii_punct$:
    lda seam_input_char

    ; SPACE .. @, punctuation and digits.
    cmp #0x20
    bcc seam_map_unknown$
    cmp #0x41
    bcs seam_check_high_other$

    ; '@' is screen code $00.
    cmp #0x40
    bne seam_direct_low$
    lda #0
    sta seam_char_lo
    jmp seam_write_char$

seam_direct_low$:
    sta seam_char_lo
    jmp seam_write_char$

seam_check_high_other$:
    ; Common high-bit punctuation / graphics are not important
    ; for CSV text yet. Normalise a small safe subset.
    lda seam_input_char
    cmp #0xa0
    bcc seam_map_unknown$
    cmp #0xc0
    bcs seam_map_unknown$
    sec
    sbc #0x40
    sta seam_char_lo
    jmp seam_write_char$

seam_map_unknown$:
    lda #0x3f
    sta seam_char_lo
    lda #1
    sta seam_char_hi

seam_write_char$:
    ldz #0
    lda seam_char_lo
    sta [seam_screen0],z
    inz
    lda seam_char_hi
    sta [seam_screen0],z

    ldz #0
    lda #0
    sta [seam_color0],z
    inz
    lda seam_attr
    sta [seam_color0],z

    jsr seam_inc_screen2
    jsr seam_inc_color2

    inc seam_cursor_col

    ldx seam_saved_x
    ldy seam_saved_y
    rts


; ------------------------------------------------------------
; seam_clear_row
; X = screen row 0..24.
; Fills 80 cells with spaces and current seam_attr.
; Preserves X/Y.
; ------------------------------------------------------------
seam_clear_row:
    stx seam_saved_x
    sty seam_saved_y
    ldy #0
    jsr seam_plot

    lda #80
    sta seam_count
seam_clear_row_loop$:
    lda #' '
    jsr seam_bsout
    dec seam_count
    bne seam_clear_row_loop$

    ldx seam_saved_x
    ldy seam_saved_y
    rts


; ------------------------------------------------------------
; seam_fill_attr_span
; Change only color/attribute bytes, not characters.
; INPUT:
;   A = row
;   X = start column
;   Y = number of cells
; Uses current seam_attr.
; ------------------------------------------------------------
seam_fill_attr_span:
    sta seam_span_row
    stx seam_span_col
    sty seam_span_len

    ldx seam_span_row
    ldy seam_span_col
    jsr seam_plot

seam_fill_attr_loop$:
    ldz #1
    lda seam_attr
    sta [seam_color0],z
    jsr seam_inc_color2
    dec seam_span_len
    bne seam_fill_attr_loop$
    rts


; ------------------------------------------------------------
; seam_cursor_blink_at
;
; Hardware text cursor using the VIC-III/VIC-IV BLINK attribute.
;
; INPUT:
;   A = screen row
;   X = screen column
;
; The existing per-cell attribute is preserved and BLINK ($10)
; is ORed into it.  The editor redraw naturally removes BLINK
; from the old cursor position.
; ------------------------------------------------------------
seam_cursor_blink_at:
    sta seam_cursor_blink_row
    stx seam_cursor_blink_col

    ldx seam_cursor_blink_row
    ldy seam_cursor_blink_col
    jsr seam_plot

    ldz #1
    lda [seam_color0],z
    ora #0x10
    sta [seam_color0],z
    rts


; ------------------------------------------------------------
; Compute screen/color pointers from seam_cursor_row/col.
; screen = $40000 + row*160 + col*2
; color  = $FF80000 + row*160 + col*2
; ------------------------------------------------------------
seam_make_ptrs:
    lda #0
    sta seam_screen0
    sta seam_screen1
    lda #0x04
    sta seam_screen2
    lda #0
    sta seam_screen3

    lda #0
    sta seam_color0
    sta seam_color1
    lda #0xf8
    sta seam_color2
    lda #0x0f
    sta seam_color3

    ldx seam_cursor_row
seam_ptr_add_rows$:
    cpx #0
    beq seam_ptr_add_col$
    jsr seam_add160_screen
    jsr seam_add160_color
    dex
    jmp seam_ptr_add_rows$

seam_ptr_add_col$:
    lda seam_cursor_col
    asl a
    sta seam_offset
    clc
    lda seam_screen0
    adc seam_offset
    sta seam_screen0
    lda seam_screen1
    adc #0
    sta seam_screen1
    lda seam_screen2
    adc #0
    sta seam_screen2
    lda seam_screen3
    adc #0
    sta seam_screen3

    clc
    lda seam_color0
    adc seam_offset
    sta seam_color0
    lda seam_color1
    adc #0
    sta seam_color1
    lda seam_color2
    adc #0
    sta seam_color2
    lda seam_color3
    adc #0
    sta seam_color3
    rts


seam_add160_screen:
    clc
    lda seam_screen0
    adc #160
    sta seam_screen0
    lda seam_screen1
    adc #0
    sta seam_screen1
    lda seam_screen2
    adc #0
    sta seam_screen2
    lda seam_screen3
    adc #0
    sta seam_screen3
    rts

seam_add160_color:
    clc
    lda seam_color0
    adc #160
    sta seam_color0
    lda seam_color1
    adc #0
    sta seam_color1
    lda seam_color2
    adc #0
    sta seam_color2
    lda seam_color3
    adc #0
    sta seam_color3
    rts

seam_inc_screen2:
    clc
    lda seam_screen0
    adc #2
    sta seam_screen0
    lda seam_screen1
    adc #0
    sta seam_screen1
    lda seam_screen2
    adc #0
    sta seam_screen2
    lda seam_screen3
    adc #0
    sta seam_screen3
    rts

seam_inc_color2:
    clc
    lda seam_color0
    adc #2
    sta seam_color0
    lda seam_color1
    adc #0
    sta seam_color1
    lda seam_color2
    adc #0
    sta seam_color2
    lda seam_color3
    adc #0
    sta seam_color3
    rts


    .section bss,bss
seam_cursor_row:
    .space 1
seam_cursor_col:
    .space 1
seam_attr:
    .space 1
seam_input_char:
    .space 1
seam_char_lo:
    .space 1
seam_char_hi:
    .space 1
seam_saved_x:
    .space 1
seam_saved_y:
    .space 1
seam_plot_saved_x:
    .space 1
seam_plot_saved_y:
    .space 1
seam_count:
    .space 1
seam_offset:
    .space 1
seam_span_row:
    .space 1
seam_span_col:
    .space 1
seam_span_len:
    .space 1
seam_cursor_blink_row:
    .space 1
seam_cursor_blink_col:
    .space 1
seam_style_fg:
    .space 1
seam_style_bg:
    .space 1

style_pal_tmp0:
    .space 1
style_pal_tmp1:
    .space 1
font_count0:
    .space 1
font_count1:
    .space 1

    .section zzpage,bss
seam_screen0:
    .space 1
seam_screen1:
    .space 1
seam_screen2:
    .space 1
seam_screen3:
    .space 1
seam_color0:
    .space 1
seam_color1:
    .space 1
seam_color2:
    .space 1
seam_color3:
    .space 1

    .section data,data

; Saved exact startup 80x25 vertical VIC-IV profile.
style_v25_d031:
    .byte 0
style_v25_d05b:
    .byte 0
style_v25_d07b:
    .byte 0
style_v25_d051:
    .byte 0


csv_screen_mode:
    .byte 0


; European glyphs for CHR16 screen codes $0180..$01DF.
; Order is shared with the UTF-8 mapping in loadcsv.s.
utf8_glyph_data:
    .byte 0x30, 0x1c, 0x1c, 0x1c, 0x1c, 0x3e, 0x36, 0x00, 0x18, 0x1c, 0x1c, 0x1c, 0x1c, 0x3e, 0x36, 0x00
    .byte 0x1c, 0x1c, 0x1c, 0x1c, 0x1c, 0x3e, 0x36, 0x00, 0x1c, 0x1c, 0x1c, 0x1c, 0x1c, 0x3e, 0x36, 0x00
    .byte 0x1c, 0x1c, 0x1c, 0x1c, 0x1c, 0x3e, 0x36, 0x00, 0x1c, 0x18, 0x18, 0x1c, 0x1c, 0x1c, 0x36, 0x00
    .byte 0x00, 0x3c, 0x38, 0x38, 0x3c, 0x78, 0x7c, 0x00, 0x1e, 0x30, 0x30, 0x30, 0x30, 0x1e, 0x18, 0x38
    .byte 0x30, 0x3e, 0x30, 0x30, 0x3e, 0x30, 0x3e, 0x00, 0x18, 0x3e, 0x30, 0x30, 0x3e, 0x30, 0x3e, 0x00
    .byte 0x38, 0x3e, 0x30, 0x30, 0x3e, 0x30, 0x3e, 0x00, 0x3c, 0x3e, 0x30, 0x30, 0x3e, 0x30, 0x3e, 0x00
    .byte 0x30, 0x3c, 0x18, 0x18, 0x18, 0x18, 0x3c, 0x00, 0x18, 0x3c, 0x18, 0x18, 0x18, 0x18, 0x3c, 0x00
    .byte 0x38, 0x3c, 0x18, 0x18, 0x18, 0x18, 0x3c, 0x00, 0x3c, 0x3c, 0x18, 0x18, 0x18, 0x18, 0x3c, 0x00
    .byte 0x1c, 0x36, 0x3e, 0x3e, 0x3e, 0x3e, 0x36, 0x00, 0x30, 0x1c, 0x36, 0x36, 0x36, 0x36, 0x1c, 0x00
    .byte 0x18, 0x1c, 0x36, 0x36, 0x36, 0x36, 0x1c, 0x00, 0x1c, 0x1c, 0x36, 0x36, 0x36, 0x36, 0x1c, 0x00
    .byte 0x1c, 0x1c, 0x36, 0x36, 0x36, 0x36, 0x1c, 0x00, 0x1c, 0x1c, 0x36, 0x36, 0x36, 0x36, 0x1c, 0x00
    .byte 0x1e, 0x36, 0x3e, 0x3e, 0x36, 0x7c, 0x00, 0x00, 0x30, 0x36, 0x36, 0x36, 0x36, 0x36, 0x1c, 0x00
    .byte 0x18, 0x36, 0x36, 0x36, 0x36, 0x36, 0x1c, 0x00, 0x1c, 0x36, 0x36, 0x36, 0x36, 0x36, 0x1c, 0x00
    .byte 0x1c, 0x36, 0x36, 0x36, 0x36, 0x36, 0x1c, 0x00, 0x18, 0x66, 0x3c, 0x18, 0x18, 0x18, 0x18, 0x00
    .byte 0x00, 0x30, 0x00, 0x3e, 0x3e, 0x36, 0x3e, 0x00, 0x00, 0x18, 0x00, 0x3e, 0x3e, 0x36, 0x3e, 0x00
    .byte 0x00, 0x38, 0x00, 0x3e, 0x3e, 0x36, 0x3e, 0x00, 0x00, 0x3c, 0x3c, 0x3e, 0x3e, 0x36, 0x3e, 0x00
    .byte 0x00, 0x3c, 0x00, 0x3e, 0x3e, 0x36, 0x3e, 0x00, 0x38, 0x38, 0x00, 0x3e, 0x3e, 0x36, 0x3e, 0x00
    .byte 0x00, 0x00, 0x3e, 0x3e, 0x38, 0x3e, 0x00, 0x00, 0x00, 0x1c, 0x30, 0x30, 0x1c, 0x18, 0x38, 0x00
    .byte 0x00, 0x30, 0x00, 0x1e, 0x3e, 0x30, 0x1e, 0x00, 0x00, 0x18, 0x00, 0x1e, 0x3e, 0x30, 0x1e, 0x00
    .byte 0x00, 0x38, 0x00, 0x1e, 0x3e, 0x30, 0x1e, 0x00, 0x00, 0x3c, 0x00, 0x1e, 0x3e, 0x30, 0x1e, 0x00
    .byte 0x00, 0x30, 0x00, 0x38, 0x18, 0x18, 0x3c, 0x00, 0x00, 0x18, 0x00, 0x38, 0x18, 0x18, 0x3c, 0x00
    .byte 0x00, 0x38, 0x00, 0x38, 0x18, 0x18, 0x3c, 0x00, 0x00, 0x3c, 0x00, 0x38, 0x18, 0x18, 0x3c, 0x00
    .byte 0x00, 0x3c, 0x3c, 0x3e, 0x36, 0x36, 0x36, 0x00, 0x00, 0x30, 0x00, 0x1c, 0x36, 0x36, 0x1c, 0x00
    .byte 0x00, 0x18, 0x00, 0x1c, 0x36, 0x36, 0x1c, 0x00, 0x00, 0x1c, 0x00, 0x1c, 0x36, 0x36, 0x1c, 0x00
    .byte 0x00, 0x1c, 0x1c, 0x1c, 0x36, 0x36, 0x1c, 0x00, 0x00, 0x36, 0x00, 0x1c, 0x36, 0x36, 0x1c, 0x00
    .byte 0x00, 0x3e, 0x3e, 0x3e, 0x3e, 0x00, 0x00, 0x00, 0x00, 0x30, 0x00, 0x36, 0x36, 0x36, 0x3e, 0x00
    .byte 0x00, 0x18, 0x00, 0x36, 0x36, 0x36, 0x3e, 0x00, 0x00, 0x1c, 0x00, 0x36, 0x36, 0x36, 0x3e, 0x00
    .byte 0x00, 0x36, 0x00, 0x36, 0x36, 0x36, 0x3e, 0x00, 0x18, 0x00, 0x36, 0x1c, 0x1c, 0x18, 0x18, 0x38
    .byte 0x3c, 0x00, 0x36, 0x1c, 0x1c, 0x18, 0x18, 0x38, 0x1c, 0x36, 0x3c, 0x3c, 0x36, 0x36, 0x3e, 0x00
    .byte 0x1c, 0x1c, 0x1c, 0x1c, 0x3e, 0x36, 0x06, 0x06, 0x18, 0x1e, 0x30, 0x30, 0x30, 0x30, 0x1e, 0x00
    .byte 0x3e, 0x30, 0x30, 0x3e, 0x30, 0x3e, 0x0c, 0x0c, 0x00, 0x30, 0x30, 0x38, 0x70, 0x30, 0x3e, 0x00
    .byte 0x18, 0x36, 0x3e, 0x3e, 0x3e, 0x3e, 0x36, 0x00, 0x18, 0x1e, 0x30, 0x3c, 0x0e, 0x06, 0x3e, 0x00
    .byte 0x18, 0x3e, 0x0c, 0x0c, 0x18, 0x18, 0x3e, 0x00, 0x18, 0x00, 0x3e, 0x0c, 0x0c, 0x18, 0x18, 0x3e
    .byte 0x00, 0x3e, 0x3e, 0x36, 0x3e, 0x0c, 0x0c, 0x00, 0x00, 0x18, 0x00, 0x1c, 0x30, 0x30, 0x1c, 0x00
    .byte 0x00, 0x1e, 0x3e, 0x30, 0x1e, 0x0c, 0x0c, 0x00, 0x38, 0x18, 0x1e, 0x18, 0x38, 0x18, 0x1e, 0x00
    .byte 0x00, 0x18, 0x00, 0x3e, 0x36, 0x36, 0x36, 0x00, 0x00, 0x18, 0x00, 0x3e, 0x3c, 0x06, 0x3e, 0x00
    .byte 0x00, 0x18, 0x00, 0x3e, 0x1c, 0x18, 0x3e, 0x00, 0x00, 0x18, 0x00, 0x3e, 0x1c, 0x18, 0x3e, 0x00
    .byte 0x38, 0x1e, 0x30, 0x30, 0x30, 0x30, 0x1e, 0x00, 0x38, 0x3c, 0x36, 0x36, 0x36, 0x36, 0x3c, 0x00
    .byte 0x38, 0x3e, 0x30, 0x30, 0x3e, 0x30, 0x3e, 0x00, 0x38, 0x36, 0x3e, 0x3e, 0x3e, 0x3e, 0x36, 0x00
    .byte 0x38, 0x3e, 0x36, 0x3c, 0x3e, 0x36, 0x33, 0x00, 0x38, 0x1e, 0x30, 0x3c, 0x0e, 0x06, 0x3e, 0x00
    .byte 0x00, 0x7e, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00, 0x38, 0x3e, 0x36, 0x36, 0x36, 0x36, 0x1c, 0x00
    .byte 0x38, 0x3e, 0x0c, 0x0c, 0x18, 0x18, 0x3e, 0x00, 0x00, 0x38, 0x00, 0x1c, 0x30, 0x30, 0x1c, 0x00
    .byte 0x06, 0x07, 0x06, 0x1e, 0x36, 0x36, 0x1e, 0x00, 0x00, 0x38, 0x00, 0x1e, 0x3e, 0x30, 0x1e, 0x00
    .byte 0x00, 0x38, 0x00, 0x3e, 0x36, 0x36, 0x36, 0x00, 0x00, 0x38, 0x00, 0x3c, 0x30, 0x30, 0x30, 0x00
    .byte 0x00, 0x38, 0x00, 0x3e, 0x3c, 0x06, 0x3e, 0x00, 0x00, 0x0c, 0x18, 0x3e, 0x18, 0x18, 0x1e, 0x00
    .byte 0x38, 0x38, 0x00, 0x36, 0x36, 0x36, 0x3e, 0x00, 0x00, 0x38, 0x00, 0x3e, 0x1c, 0x18, 0x3e, 0x00
    .byte 0x38, 0x1c, 0x36, 0x36, 0x36, 0x36, 0x1c, 0x00, 0x38, 0x36, 0x36, 0x36, 0x36, 0x36, 0x1c, 0x00
    .byte 0x00, 0x38, 0x00, 0x1c, 0x36, 0x36, 0x1c, 0x00, 0x00, 0x38, 0x00, 0x36, 0x36, 0x36, 0x3e, 0x00
    .byte 0x0c, 0x0e, 0x30, 0x30, 0x30, 0x30, 0x3e, 0x00, 0x0c, 0x0e, 0x18, 0x18, 0x18, 0x18, 0x1c, 0x00
style_mouse_color:
    .byte 0xfe

; Main program border colour (palette index).
; Change this value to theme the VIC-IV border.
style_border:
    .byte 0

; Common visible text colour when cells are reversed.
; 0 = black.
style_screen_bg:
    .byte 0 ;Deep space blue

; MENU BAR
style_fg_menu:
    .byte 0 ;Deep space blue
style_bg_menu:
    .byte 2          ; Tiger orange

; DROPDOWN / SUBMENU
style_fg_dropdown:
    .byte 0
style_bg_dropdown:
    .byte 2          ; Tiger orange

; COLUMN / ROW HEADERS
style_fg_header:
    .byte 0
style_bg_header:
    .byte 3          ; Blue Green

; NORMAL CSV CELLS - EVEN COLUMNS (0,2,4,...)
style_fg_cell:
    .byte 0
style_bg_cell:
    .byte 1          ; sky blue

; NORMAL CSV CELLS - ODD COLUMNS (1,3,5,...)
; Change these two values to choose the alternating column colour.
style_fg_cell_alt:
    .byte 0
style_bg_cell_alt:
    .byte 4          ; Blue Green

; CURRENT / MULTI SELECTION
style_fg_selection:
    .byte 0
style_bg_selection:
    .byte 7          ; Tiger orange

; LONG TEXT FULL-SCREEN EDITOR
; Independent from the normal cell-selection style.
style_fg_textedit:
    .byte 0
style_bg_textedit:
    .byte 1

; ------------------------------------------------------------
; RGB PALETTE TABLES
; ------------------------------------------------------------
; Normal RGB values, 0x00..0xFF.
;
; Current test theme:
;   0  dark text
;   1  warm white cells
;   2  coral-red selection
;   3  pale cyan headers
;   4  spare
;   5  pale green dropdown
;   6  spare
;   7  warm yellow menu
;
; Feel free to edit these directly.
; ------------------------------------------------------------

style_palette_r:
    .byte 0x02, 0x8e, 0xfb, 0x21
    .byte 0x21, 0xB8, 0x7D, 0xff
    .byte 0x70, 0xA0, 0xD0, 0x70
    .byte 0xD0, 0x90, 0xE0, 0xFF

style_palette_g:
    .byte 0x30, 0xca, 0x85, 0x9e
    .byte 0x9e, 0xE0, 0x7D, 0xb7
    .byte 0x90, 0x70, 0x90, 0xC0
    .byte 0xD0, 0x90, 0xC0, 0xFF

style_palette_b:
    .byte 0x47, 0xe6, 0x00, 0xbc
    .byte 0xbc, 0xB0, 0x7D, 0x03
    .byte 0xC0, 0xB0, 0x70, 0x90
    .byte 0xA0, 0xD0, 0xE0, 0xFF

