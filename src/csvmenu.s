;
; ------------------------------------------------------------
; csvmenu.s
; KnockCSV - menu File
; ------------------------------------------------------------

    .public csvmenu_open_file
    .public csvmenu_open_preferences
    .public csvmenu_open_decoder
    .public csvmenu_open_delimiter
    .public csvmenu_open_screen
    .public csvmenu_open_edit
    .public csvmenu_open_grid
    .public csvmenu_open_view
    .public csvmenu_open_headers
    .public csvmenu_open_sort
    .public csvmenu_open_fill
    .public csvmenu_close
    .public csvmenu_handle_key
    .public csvmenu_is_open
    .public csvmenu_type
    .public csvmenu_submenu

bsout   .equ 0xffd2
plot    .equ 0xfff0

KEY_O   .equ 0x4f
KEY_N       .equ 0x4e
KEY_S   .equ 0x53
KEY_A   .equ 0x41
KEY_X           .equ 0x58
KEY_ESC .equ 0x1b

; MEGA65 colour RAM / character attributes.
; Byte alto della colour RAM per ogni cella:
; bit 5 = underline.


    .extern seam_plot
    .extern seam_bsout
    .extern seam_apply_dropdown_style
    .extern seam_apply_cell_style
    .extern csv_decoder_mode
    .extern csv_delimiter
    .extern csv_delimiter_mode
    .extern csv_screen_mode

    .section code,text

csvmenu_open_file:
    jsr seam_apply_dropdown_style
    lda #1
    sta csvmenu_is_open
    sta csvmenu_type
    lda #0
    sta csvmenu_submenu

    ; row 1 - New
    ldx #1
    ldy #0
    clc
    jsr seam_plot
    ldx #0
file_new_loop$:
    lda new_text,x
    beq open_line$
    jsr seam_bsout
    inx
    bne file_new_loop$

open_line$:
    ; row 2 - Open
    ldx #2
    ldy #0
    clc
    jsr seam_plot
    ldx #0
open_loop$:
    lda open_text,x
    beq save_line$
    jsr seam_bsout
    inx
    bne open_loop$

save_line$:
    ; row 3 - Save
    ldx #3
    ldy #0
    clc
    jsr seam_plot
    ldx #0
save_loop$:
    lda save_text,x
    beq saveas_line$
    jsr seam_bsout
    inx
    bne save_loop$

saveas_line$:
    ; row 4 - Save As...
    ldx #4
    ldy #0
    clc
    jsr seam_plot
    ldx #0
saveas_loop$:
    lda saveas_text,x
    beq preferences_line$
    jsr seam_bsout
    inx
    bne saveas_loop$

preferences_line$:
    ; row 5 - Preferences >
    ldx #5
    ldy #0
    clc
    jsr seam_plot
    ldx #0
file_preferences_loop$:
    lda preferences_text,x
    beq exit_line$
    jsr seam_bsout
    inx
    bne file_preferences_loop$

exit_line$:
    ; row 6 - Exit
    ldx #6
    ldy #0
    clc
    jsr seam_plot
    ldx #0
file_exit_loop$:
    lda exit_text,x
    beq done$
    jsr seam_bsout
    inx
    bne file_exit_loop$

done$:
    ; dropdown FILE: rows 1..6, cols 0..13
    lda #1
    sta menu_color_row
    lda #0
    sta menu_color_col
    lda #14
    sta menu_color_width
    lda #6
    sta menu_color_height
    jsr seam_apply_cell_style
    rts


; ------------------------------------------------------------
; csvmenu_open_preferences
;
; FILE -> Preferences submenu.
; ------------------------------------------------------------
csvmenu_open_preferences:
    jsr seam_apply_dropdown_style
    lda #1
    sta csvmenu_submenu

    ; row 4 - Decoder >
    ldx #4
    ldy #14
    clc
    jsr seam_plot
    ldx #0
prefs_decoder_loop$:
    lda prefs_decoder_text,x
    beq prefs_delimiter_line$
    jsr seam_bsout
    inx
    bne prefs_decoder_loop$

prefs_delimiter_line$:
    ; row 5 - Delimiter >
    ldx #5
    ldy #14
    clc
    jsr seam_plot
    ldx #0
prefs_delimiter_loop$:
    lda prefs_delimiter_text,x
    beq prefs_screen_line$
    jsr seam_bsout
    inx
    bne prefs_delimiter_loop$

prefs_screen_line$:
    ; row 6 - Screen >
    ldx #6
    ldy #14
    clc
    jsr seam_plot
    ldx #0
prefs_screen_loop$:
    lda prefs_screen_text,x
    beq prefs_done$
    jsr seam_bsout
    inx
    bne prefs_screen_loop$

prefs_done$:
    lda #4
    sta menu_color_row
    lda #14
    sta menu_color_col
    lda #14
    sta menu_color_width
    lda #3
    sta menu_color_height
    jsr seam_apply_cell_style
    rts


; ------------------------------------------------------------
; csvmenu_open_decoder
;
; Preferences -> Decoder choices.
; ------------------------------------------------------------
csvmenu_open_decoder:
    jsr seam_apply_dropdown_style
    lda #2
    sta csvmenu_submenu

    ; PETSCII
    ldx #4
    ldy #28
    clc
    jsr seam_plot
    lda #0x20
    ldx csv_decoder_mode
    beq +
    lda #0x2a
+
    jsr seam_bsout
    ldx #0
prefs_petscii_loop$:
    lda prefs_petscii_text,x
    beq prefs_utf8$
    jsr seam_bsout
    inx
    bne prefs_petscii_loop$

prefs_utf8$:
    ldx #5
    ldy #28
    clc
    jsr seam_plot
    lda #0x20
    ldx csv_decoder_mode
    bne +
    lda #0x2a
+
    jsr seam_bsout
    ldx #0
prefs_utf8_loop$:
    lda prefs_utf8_text,x
    beq decoder_done$
    jsr seam_bsout
    inx
    bne prefs_utf8_loop$

decoder_done$:
    lda #4
    sta menu_color_row
    lda #28
    sta menu_color_col
    lda #14
    sta menu_color_width
    lda #2
    sta menu_color_height
    jsr seam_apply_cell_style
    rts



; ------------------------------------------------------------
; csvmenu_open_delimiter
;
; Preferences -> Delimiter choices.
; csv_delimiter stores the actual byte used in the document:
;   $2C comma, $3B semicolon, $09 tab.
; ------------------------------------------------------------
csvmenu_open_delimiter:
    jsr seam_apply_dropdown_style
    lda #3
    sta csvmenu_submenu

    ; Auto
    ldx #5
    ldy #28
    clc
    jsr seam_plot
    lda #' '
    ldx csv_delimiter_mode
    bne +
    lda #'*'
+
    jsr seam_bsout
    ldx #0
prefs_auto_loop$:
    lda prefs_auto_text,x
    beq prefs_comma$
    jsr seam_bsout
    inx
    bne prefs_auto_loop$

prefs_comma$:
    ldx #6
    ldy #28
    clc
    jsr seam_plot
    lda #' '
    ldx csv_delimiter_mode
    cpx #1
    bne +
    lda #'*'
+
    jsr seam_bsout
    ldx #0
prefs_comma_loop$:
    lda prefs_comma_text,x
    beq prefs_semicolon$
    jsr seam_bsout
    inx
    bne prefs_comma_loop$

prefs_semicolon$:
    ldx #7
    ldy #28
    clc
    jsr seam_plot
    lda #' '
    ldx csv_delimiter_mode
    cpx #2
    bne +
    lda #'*'
+
    jsr seam_bsout
    ldx #0
prefs_semicolon_loop$:
    lda prefs_semicolon_text,x
    beq prefs_tab$
    jsr seam_bsout
    inx
    bne prefs_semicolon_loop$

prefs_tab$:
    ldx #8
    ldy #28
    clc
    jsr seam_plot
    lda #' '
    ldx csv_delimiter_mode
    cpx #3
    bne +
    lda #'*'
+
    jsr seam_bsout
    ldx #0
prefs_tab_loop$:
    lda prefs_tab_text,x
    beq delimiter_done$
    jsr seam_bsout
    inx
    bne prefs_tab_loop$

delimiter_done$:
    lda #5
    sta menu_color_row
    lda #28
    sta menu_color_col
    lda #14
    sta menu_color_width
    lda #4
    sta menu_color_height
    jsr seam_apply_cell_style
    rts



; ------------------------------------------------------------
; csvmenu_open_screen
;
; Preferences -> Screen choices.
; ------------------------------------------------------------
csvmenu_open_screen:
    jsr seam_apply_dropdown_style
    lda #4
    sta csvmenu_submenu

    ; 80 x 25
    ldx #6
    ldy #28
    clc
    jsr seam_plot
    lda #' '
    ldx csv_screen_mode
    bne +
    lda #'*'
+
    jsr seam_bsout
    ldx #0
prefs_screen25_loop$:
    lda prefs_screen25_text,x
    beq prefs_screen50$
    jsr seam_bsout
    inx
    bne prefs_screen25_loop$

prefs_screen50$:
    ldx #7
    ldy #28
    clc
    jsr seam_plot
    lda #' '
    ldx csv_screen_mode
    beq +
    lda #'*'
+
    jsr seam_bsout
    ldx #0
prefs_screen50_loop$:
    lda prefs_screen50_text,x
    beq screen_done$
    jsr seam_bsout
    inx
    bne prefs_screen50_loop$

screen_done$:
    lda #6
    sta menu_color_row
    lda #28
    sta menu_color_col
    lda #14
    sta menu_color_width
    lda #2
    sta menu_color_height
    jsr seam_apply_cell_style
    rts


; ------------------------------------------------------------
; csvmenu_open_edit
;
; EDIT dropdown at col 7:
;   row 1  Copy
;   row 2  Paste
;   row 3  Cut
;   row 4  Delete
;
; csvmenu_type = 3
; ------------------------------------------------------------

csvmenu_open_edit:
    jsr seam_apply_dropdown_style
    lda #1
    sta csvmenu_is_open
    lda #3
    sta csvmenu_type
    lda #0
    sta csvmenu_submenu

    ; Copy
    ldx #1
    ldy #7
    clc
    jsr seam_plot
    ldx #0
edit_copy_loop$:
    lda edit_copy_text,x
    beq edit_paste$
    jsr seam_bsout
    inx
    bne edit_copy_loop$

edit_paste$:
    ; Paste
    ldx #2
    ldy #7
    clc
    jsr seam_plot
    ldx #0
edit_paste_loop$:
    lda edit_paste_text,x
    beq edit_cut$
    jsr seam_bsout
    inx
    bne edit_paste_loop$

edit_cut$:
    ; Cut
    ldx #3
    ldy #7
    clc
    jsr seam_plot
    ldx #0
edit_cut_loop$:
    lda edit_cut_text,x
    beq edit_delete$
    jsr seam_bsout
    inx
    bne edit_cut_loop$

edit_delete$:
    ; Delete
    ldx #4
    ldy #7
    clc
    jsr seam_plot
    ldx #0
edit_delete_loop$:
    lda edit_delete_text,x
    beq edit_find$
    jsr seam_bsout
    inx
    bne edit_delete_loop$

edit_find$:
    ; Find
    ldx #5
    ldy #7
    clc
    jsr seam_plot
    ldx #0
edit_find_loop$:
    lda edit_find_text,x
    beq edit_replace$
    jsr seam_bsout
    inx
    bne edit_find_loop$

edit_replace$:
    ; Replace
    ldx #6
    ldy #7
    clc
    jsr seam_plot
    ldx #0
edit_replace_loop$:
    lda edit_replace_text,x
    beq edit_fill$
    jsr seam_bsout
    inx
    bne edit_replace_loop$

edit_fill$:
    ; Fill >
    ldx #7
    ldy #7
    clc
    jsr seam_plot
    ldx #0
edit_fill_loop$:
    lda edit_fill_text,x
    beq edit_done$
    jsr seam_bsout
    inx
    bne edit_fill_loop$

edit_done$:
    ; dropdown EDIT: rows 1..7, cols 7..22
    lda #1
    sta menu_color_row
    lda #7
    sta menu_color_col
    lda #16
    sta menu_color_width
    lda #7
    sta menu_color_height
    jsr seam_apply_cell_style
    rts


; ------------------------------------------------------------
; csvmenu_open_fill
;
; EDIT -> Fill submenu, aligned with row 7.
; ------------------------------------------------------------
csvmenu_open_fill:
    jsr seam_apply_dropdown_style
    lda #1
    sta csvmenu_submenu

    ldx #7
    ldy #23
    clc
    jsr seam_plot
    ldx #0
edit_fill_up_loop$:
    lda edit_fill_up_text,x
    beq edit_fill_down$
    jsr seam_bsout
    inx
    bne edit_fill_up_loop$

edit_fill_down$:
    ldx #8
    ldy #23
    clc
    jsr seam_plot
    ldx #0
edit_fill_down_loop$:
    lda edit_fill_down_text,x
    beq edit_fill_right$
    jsr seam_bsout
    inx
    bne edit_fill_down_loop$

edit_fill_right$:
    ldx #9
    ldy #23
    clc
    jsr seam_plot
    ldx #0
edit_fill_right_loop$:
    lda edit_fill_right_text,x
    beq edit_fill_left$
    jsr seam_bsout
    inx
    bne edit_fill_right_loop$

edit_fill_left$:
    ldx #10
    ldy #23
    clc
    jsr seam_plot
    ldx #0
edit_fill_left_loop$:
    lda edit_fill_left_text,x
    beq edit_fill_all_up$
    jsr seam_bsout
    inx
    bne edit_fill_left_loop$

edit_fill_all_up$:
    ldx #11
    ldy #23
    clc
    jsr seam_plot
    ldx #0
edit_fill_all_up_loop$:
    lda edit_fill_all_up_text,x
    beq edit_fill_all_down$
    jsr seam_bsout
    inx
    bne edit_fill_all_up_loop$

edit_fill_all_down$:
    ldx #12
    ldy #23
    clc
    jsr seam_plot
    ldx #0
edit_fill_all_down_loop$:
    lda edit_fill_all_down_text,x
    beq edit_fill_all_right$
    jsr seam_bsout
    inx
    bne edit_fill_all_down_loop$

edit_fill_all_right$:
    ldx #13
    ldy #23
    clc
    jsr seam_plot
    ldx #0
edit_fill_all_right_loop$:
    lda edit_fill_all_right_text,x
    beq edit_fill_all_left$
    jsr seam_bsout
    inx
    bne edit_fill_all_right_loop$

edit_fill_all_left$:
    ldx #14
    ldy #23
    clc
    jsr seam_plot
    ldx #0
edit_fill_all_left_loop$:
    lda edit_fill_all_left_text,x
    beq edit_fill_done$
    jsr seam_bsout
    inx
    bne edit_fill_all_left_loop$

edit_fill_done$:
    lda #7
    sta menu_color_row
    lda #23
    sta menu_color_col
    lda #23
    sta menu_color_width
    lda #8
    sta menu_color_height
    jsr seam_apply_cell_style
    rts


; ------------------------------------------------------------
; csvmenu_open_grid
;
; GRID dropdown at col 14.
;
;   row 1  Headers >
;
; The header choices live in a second panel opened with
; csvmenu_open_headers.
; ------------------------------------------------------------

csvmenu_open_grid:
    jsr seam_apply_dropdown_style
    lda #1
    sta csvmenu_is_open
    lda #2
    sta csvmenu_type
    lda #0
    sta csvmenu_submenu

    ; row 1: Headers >
    ldx #1
    ldy #14
    clc
    jsr seam_plot
    ldx #0
grid_headers_loop$:
    lda grid_headers_text,x
    beq grid_row_above$
    jsr seam_bsout
    inx
    bne grid_headers_loop$

grid_row_above$:
    ; row 2
    ldx #2
    ldy #14
    clc
    jsr seam_plot
    ldx #0
grid_row_above_loop$:
    lda grid_row_above_text,x
    beq grid_row_below$
    jsr seam_bsout
    inx
    bne grid_row_above_loop$

grid_row_below$:
    ; row 3
    ldx #3
    ldy #14
    clc
    jsr seam_plot
    ldx #0
grid_row_below_loop$:
    lda grid_row_below_text,x
    beq grid_delete_row$
    jsr seam_bsout
    inx
    bne grid_row_below_loop$

grid_delete_row$:
    ; row 4
    ldx #4
    ldy #14
    clc
    jsr seam_plot
    ldx #0
grid_delete_row_loop$:
    lda grid_delete_row_text,x
    beq grid_sep$
    jsr seam_bsout
    inx
    bne grid_delete_row_loop$

grid_sep$:
    ; row 5 separator
    ldx #5
    ldy #14
    clc
    jsr seam_plot
    ldx #0
grid_sep_loop$:
    lda grid_insert_sep_text,x
    beq grid_col_left$
    jsr seam_bsout
    inx
    bne grid_sep_loop$

grid_col_left$:
    ; row 6
    ldx #6
    ldy #14
    clc
    jsr seam_plot
    ldx #0
grid_col_left_loop$:
    lda grid_col_left_text,x
    beq grid_col_right$
    jsr seam_bsout
    inx
    bne grid_col_left_loop$

grid_col_right$:
    ; row 7
    ldx #7
    ldy #14
    clc
    jsr seam_plot
    ldx #0
grid_col_right_loop$:
    lda grid_col_right_text,x
    beq grid_delete_col$
    jsr seam_bsout
    inx
    bne grid_col_right_loop$

grid_delete_col$:
    ; row 8
    ldx #8
    ldy #14
    clc
    jsr seam_plot
    ldx #0
grid_delete_col_loop$:
    lda grid_delete_col_text,x
    beq grid_sort_sep$
    jsr seam_bsout
    inx
    bne grid_delete_col_loop$

grid_sort_sep$:
    ldx #9
    ldy #14
    clc
    jsr seam_plot
    ldx #0
grid_sort_sep_loop$:
    lda grid_insert_sep_text,x
    beq grid_sort$
    jsr seam_bsout
    inx
    bne grid_sort_sep_loop$

grid_sort$:
    ldx #10
    ldy #14
    clc
    jsr seam_plot
    ldx #0
grid_sort_loop$:
    lda grid_sort_text,x
    beq grid_done$
    jsr seam_bsout
    inx
    bne grid_sort_loop$

grid_done$:
    ; dropdown GRID: rows 1..10, cols 14..39
    lda #1
    sta menu_color_row
    lda #14
    sta menu_color_col
    lda #26
    sta menu_color_width
    lda #10
    sta menu_color_height
    jsr seam_apply_cell_style
    rts


; ------------------------------------------------------------
; csvmenu_open_headers
;
; Second-level submenu at col 36:
;
;   row 1  No header rows
;   row 2  1 header row
;   row 3  2 header rows
;   row 4  --------------------
;   row 5  No header columns
;   row 6  1 header column
;   row 7  2 header columns
; ------------------------------------------------------------

csvmenu_open_headers:
    jsr seam_apply_dropdown_style
    lda #1
    sta csvmenu_submenu

    ldx #1
    ldy #36
    clc
    jsr seam_plot
    ldx #0
headers_row0_loop$:
    lda grid_rows0_text,x
    beq headers_row1$
    jsr seam_bsout
    inx
    bne headers_row0_loop$

headers_row1$:
    ldx #2
    ldy #36
    clc
    jsr seam_plot
    ldx #0
headers_row1_loop$:
    lda grid_rows1_text,x
    beq headers_row2$
    jsr seam_bsout
    inx
    bne headers_row1_loop$

headers_row2$:
    ldx #3
    ldy #36
    clc
    jsr seam_plot
    ldx #0
headers_row2_loop$:
    lda grid_rows2_text,x
    beq headers_sep$
    jsr seam_bsout
    inx
    bne headers_row2_loop$

headers_sep$:
    ldx #4
    ldy #36
    clc
    jsr seam_plot
    ldx #0
headers_sep_loop$:
    lda grid_sep_text,x
    beq headers_col0$
    jsr seam_bsout
    inx
    bne headers_sep_loop$

headers_col0$:
    ldx #5
    ldy #36
    clc
    jsr seam_plot
    ldx #0
headers_col0_loop$:
    lda grid_cols0_text,x
    beq headers_col1$
    jsr seam_bsout
    inx
    bne headers_col0_loop$

headers_col1$:
    ldx #6
    ldy #36
    clc
    jsr seam_plot
    ldx #0
headers_col1_loop$:
    lda grid_cols1_text,x
    beq headers_col2$
    jsr seam_bsout
    inx
    bne headers_col1_loop$

headers_col2$:
    ldx #7
    ldy #36
    clc
    jsr seam_plot
    ldx #0
headers_col2_loop$:
    lda grid_cols2_text,x
    beq headers_done$
    jsr seam_bsout
    inx
    bne headers_col2_loop$

headers_done$:
    ; submenu Headers: rows 1..7, cols 36..59
    lda #1
    sta menu_color_row
    lda #36
    sta menu_color_col
    lda #24
    sta menu_color_width
    lda #7
    sta menu_color_height
    jsr seam_apply_cell_style
    rts


csvmenu_open_sort:
    jsr seam_apply_dropdown_style
    lda #2
    sta csvmenu_submenu

    ; row 10: A to Z
    ldx #10
    ldy #36
    clc
    jsr seam_plot
    ldx #0
sort_asc_loop$:
    lda grid_sort_asc_text,x
    beq sort_desc$
    jsr seam_bsout
    inx
    bne sort_asc_loop$

sort_desc$:
    ; row 11: Z to A
    ldx #11
    ldy #36
    clc
    jsr seam_plot
    ldx #0
sort_desc_loop$:
    lda grid_sort_desc_text,x
    beq sort_num_asc$
    jsr seam_bsout
    inx
    bne sort_desc_loop$

sort_num_asc$:
    ; row 12: Smallest to largest
    ldx #12
    ldy #36
    clc
    jsr seam_plot
    ldx #0
sort_num_asc_loop$:
    lda grid_sort_num_asc_text,x
    beq sort_num_desc$
    jsr seam_bsout
    inx
    bne sort_num_asc_loop$

sort_num_desc$:
    ; row 13: Largest to smallest
    ldx #13
    ldy #36
    clc
    jsr seam_plot
    ldx #0
sort_num_desc_loop$:
    lda grid_sort_num_desc_text,x
    beq sort_len_asc$
    jsr seam_bsout
    inx
    bne sort_num_desc_loop$

sort_len_asc$:
    ; row 14: Shortest to longest
    ldx #14
    ldy #36
    clc
    jsr seam_plot
    ldx #0
sort_len_asc_loop$:
    lda grid_sort_len_asc_text,x
    beq sort_len_desc$
    jsr seam_bsout
    inx
    bne sort_len_asc_loop$

sort_len_desc$:
    ; row 15: Longest to shortest
    ldx #15
    ldy #36
    clc
    jsr seam_plot
    ldx #0
sort_len_desc_loop$:
    lda grid_sort_len_desc_text,x
    beq sort_done$
    jsr seam_bsout
    inx
    bne sort_len_desc_loop$

sort_done$:
    jsr seam_apply_cell_style
    rts


; ------------------------------------------------------------
; color_dropdown_rect
;
; Colours only byte 0 of each Colour RAM cell, preserving attrs.
; Coordinates are screen character cells.
; ------------------------------------------------------------
color_dropdown_rect:
    rts


; ------------------------------------------------------------
; underline_hotkey_row
;
; INPUT:
;   A = riga video (1 oppure 2)
;
; La lettera hotkey e' in colonna 1.
; Colour RAM MEGA65 = $0FF80000, 2 byte per cella.
; L'attributo underline e' nel byte alto della cella.
; offset = (row * 80 + 1) * 2 + 1
; ------------------------------------------------------------

underline_hotkey_row:
    rts



; ------------------------------------------------------------
; csvmenu_open_view
;
; VIEW menu: screen split controls.
; csvmenu_type = 4
; ------------------------------------------------------------
csvmenu_open_view:
    jsr seam_apply_dropdown_style
    lda #1
    sta csvmenu_is_open
    lda #4
    sta csvmenu_type
    lda #0
    sta csvmenu_submenu

    ; row 1 - Split Vertical
    ldx #1
    ldy #21
    clc
    jsr seam_plot
    ldx #0
view_vertical_loop$:
    lda view_split_vertical_text,x
    beq view_horizontal_line$
    jsr seam_bsout
    inx
    bne view_vertical_loop$

view_horizontal_line$:
    ; row 2 - Split Horizontal
    ldx #2
    ldy #21
    clc
    jsr seam_plot
    ldx #0
view_horizontal_loop$:
    lda view_split_horizontal_text,x
    beq view_remove_line$
    jsr seam_bsout
    inx
    bne view_horizontal_loop$

view_remove_line$:
    ; row 3 - Remove Split
    ldx #3
    ldy #21
    clc
    jsr seam_plot
    ldx #0
view_remove_loop$:
    lda view_remove_split_text,x
    beq view_menu_done$
    jsr seam_bsout
    inx
    bne view_remove_loop$

view_menu_done$:
    lda #1
    sta menu_color_row
    lda #21
    sta menu_color_col
    lda #20
    sta menu_color_width
    lda #3
    sta menu_color_height
    jsr seam_apply_cell_style
    rts

csvmenu_close:
    lda #0
    sta csvmenu_is_open
    sta csvmenu_type
    sta csvmenu_submenu
    rts

; A=input key
; A=0 none, 1 open, 2 save, 3 close, 4 saveas, 5 exit, 6 new
csvmenu_handle_key:
    cmp #KEY_N
    beq new$
    cmp #KEY_O
    beq open$
    cmp #KEY_S
    beq save$
    cmp #KEY_A
    beq saveas$
    cmp #KEY_X
    beq exit$
    cmp #KEY_ESC
    beq close$
    lda #0
    rts

new$:
    lda #6
    rts

open$:
    lda #1
    rts

save$:
    lda #2
    rts

saveas$:
    lda #4
    rts

exit$:
    lda #5
    rts

close$:
    lda #3
    rts

open_text:
    .ascii " oPEN   mEGA+o"
    .byte 0

save_text:
    .ascii " sAVE   mEGA+s"
    .byte 0

saveas_text:
    .ascii " sAVE aS...   "
    .byte 0

preferences_text:
    .ascii " pREFERENCES >"
    .byte 0
exit_text:
    .ascii " eXIT         "
    .byte 0
new_text:
    .ascii " nEW          "
    .byte 0
prefs_decoder_text:
    .ascii " dECODER >    "
    .byte 0
prefs_delimiter_text:
    .ascii " dELIMITER >  "
    .byte 0
prefs_screen_text:
    .ascii " sCREEN >     "
    .byte 0
prefs_screen25_text:
    .ascii "80 X 25      "
    .byte 0
prefs_screen50_text:
    .ascii "80 X 50      "
    .byte 0
prefs_petscii_text:
    .ascii "petscii      "
    .byte 0
prefs_utf8_text:
    .ascii "utf-8        "
    .byte 0
prefs_auto_text:
    .ascii "aUTO         "
    .byte 0
prefs_comma_text:
    .ascii "cOMMA        "
    .byte 0
prefs_semicolon_text:
    .ascii "sEMICOLON    "
    .byte 0
prefs_tab_text:
    .ascii "tAB          "
    .byte 0


edit_copy_text:
    .ascii " cOPY    mega+c "
    .byte 0
edit_paste_text:
    .ascii " pASTE   mega+v "
    .byte 0
edit_cut_text:
    .ascii " cUT     mega+x "
    .byte 0
edit_delete_text:
    .ascii " dELETE         "
    .byte 0
edit_find_text:
    .ascii " fIND    mega+f "
    .byte 0
edit_replace_text:
    .ascii " rEPLACE mega+r "
    .byte 0
edit_fill_text:
    .ascii " fILL >         "
    .byte 0
edit_fill_up_text:
    .ascii " fILL uP       mega+up "
    .byte 0
edit_fill_down_text:
    .ascii " fILL dOWN     mega+dn "
    .byte 0
edit_fill_right_text:
    .ascii " fILL rIGHT    mega+rt "
    .byte 0
edit_fill_left_text:
    .ascii " fILL lEFT     mega+lt "
    .byte 0
edit_fill_all_up_text:
    .ascii " fILL aLL uP           "
    .byte 0
edit_fill_all_down_text:
    .ascii " fILL aLL dOWN         "
    .byte 0
edit_fill_all_right_text:
    .ascii " fILL aLL rIGHT        "
    .byte 0
edit_fill_all_left_text:
    .ascii " fILL aLL lEFT         "
    .byte 0

grid_headers_text:
    .ascii " hEADERS >                  "
    .byte 0
grid_insert_sep_text:
    .ascii " -------------------------- "
    .byte 0
grid_row_above_text:
    .ascii " iNSERT ROW ABOVE           "
    .byte 0
grid_row_below_text:
    .ascii " iNSERT ROW BELOW   mega+rtn"
    .byte 0
grid_col_left_text:
    .ascii " iNSERT COLUMN LEFT         "
    .byte 0
grid_col_right_text:
    .ascii " iNSERT COLUMN RIGHT        "
    .byte 0
grid_delete_row_text:
    .ascii " dELETE ROW         mega+del"
    .byte 0
grid_delete_col_text:
    .ascii " dELETE COLUMN              "
    .byte 0
grid_sort_text:
    .ascii " sORT >                     "
    .byte 0
grid_sort_asc_text:
    .ascii " a TO z                 "
    .byte 0
grid_sort_desc_text:
    .ascii " z TO a                 "
    .byte 0
grid_sort_num_asc_text:
    .ascii " sMALLEST TO LARGEST    "
    .byte 0
grid_sort_num_desc_text:
    .ascii " lARGEST TO SMALLEST    "
    .byte 0
grid_sort_len_asc_text:
    .ascii " sHORTEST TO LONGEST    "
    .byte 0
grid_sort_len_desc_text:
    .ascii " lONGEST TO SHORTEST    "
    .byte 0

grid_rows0_text:
    .ascii " nO HEADER ROWS       "
    .byte 0
grid_rows1_text:
    .ascii " 1 HEADER ROW         "
    .byte 0
grid_rows2_text:
    .ascii " 2 HEADER ROWS        "
    .byte 0
grid_sep_text:
    .ascii " -------------------- "
    .byte 0
grid_cols0_text:
    .ascii " nO HEADER COLUMNS    "
    .byte 0
grid_cols1_text:
    .ascii " 1 HEADER COLUMN      "
    .byte 0
grid_cols2_text:
    .ascii " 2 HEADER COLUMNS     "
    .byte 0


view_split_vertical_text:
    .ascii " sPLIT vERTICAL     "
    .byte 0
view_split_horizontal_text:
    .ascii " sPLIT hORIZONTAL   "
    .byte 0
view_remove_split_text:
    .ascii " rEMOVE sPLIT       "
    .byte 0

    .section bss,bss

csvmenu_is_open:
    .space 1
csvmenu_type:
    .space 1
csvmenu_submenu:
    .space 1

menu_color_row:
    .space 1
menu_color_col:
    .space 1
menu_color_width:
    .space 1
menu_color_height:
    .space 1
menu_color_rows_left:
    .space 1
menu_color_cells_left:
    .space 1

menu_row:
    .space 1
menu_off0:
    .space 1
menu_off1:
    .space 1

    .section zzpage,bss

menu_color_ptr0:
    .space 1
menu_color_ptr1:
    .space 1
menu_color_ptr2:
    .space 1
menu_color_ptr3:
    .space 1

menu_attr0:
    .space 1
menu_attr1:
    .space 1
menu_attr2:
    .space 1
menu_attr3:
    .space 1
