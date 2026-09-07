;
; ------------------------------------------------------------
; csvview.s
; KnockCSV - viewport testuale con scrolling verticale
;
; NIENTE CLS durante lo scrolling.
;
; Tasti:
;   CURSOR DOWN  PETSCII 0x11
;   CURSOR UP    PETSCII 0x91
;
; La schermata viene ridisegnata da HOME usando PETSCII 0x13.
;
; VIEW_ROWS = 24 + menu row 0
;
; Lo scroll verso il basso si ferma quando l'ultima riga
; del CSV e' gia' visibile nella viewport.
; ------------------------------------------------------------

    .public csvviewloop
    .public csvprintview

    .public csv_top_row0
    .public csv_top_row1
    .public csv_current_row0
    .public csv_current_row1
    .public csv_frozen_rows
    .public csv_frozen_cols
    .public csv_current_col
    .public csv_left_col

    .extern csvprintrow
    .extern csvprintrow_scrollable
    .extern csvmenu_open_file
    .extern csvmenu_open_preferences
    .extern csvmenu_open_decoder
    .extern csvmenu_open_delimiter
    .extern csvmenu_open_screen
    .extern csvmenu_open_edit
    .extern csvmenu_open_grid
    .extern csvmenu_open_view
    .extern csvmenu_open_headers
    .extern csvmenu_open_sort
    .extern csvmenu_open_fill
    .extern csvmenu_close
    .extern csvmenu_handle_key
    .extern csvmenu_is_open
    .extern csvmenu_type
    .extern csvmenu_submenu
    .extern chain_edit
    .extern chain_knockcsv
    .extern csvfilebrowser_open
    .extern csvfilebrowser_open_saveas
    .extern csvfilebrowser_handle_key
    .extern csvfilebrowser_handle_mouse
    .extern csvfilebrowser_is_open
    .extern csv_device
    .extern csv_loaded_device
    .extern csv_decoder_mode
    .extern csv_delimiter
    .extern csv_save_delimiter
    .extern csv_delimiter_mode
    .extern loadcsv
    .extern savecsv
    .extern csvindex

    .extern mouse_init
    .extern mouse_update
    .extern initmousecursor
    .extern updatemousecursor
    .extern hidemousecursor
    .extern sprite_apply_screen_mode
    .extern busycursor_on
    .extern busycursor_off
    .extern mouse_xpos
    .extern mouse_ypos
    .extern mouse_pressed
    .extern mouse_right_pressed
    .extern mouse_held
    .extern mouse_scale_to_25
    .extern mouse_scale_to_50

    .extern csv_rows0
    .extern csv_rows1
    .extern csv_maxcols0
    .extern csv_maxcols1

    .extern csv_row0
    .extern csv_row1
    .extern csvrowaddr
    .extern attic_addr0
    .extern attic_addr1
    .extern attic_addr2
    .extern attic_addr3
    .extern csv_size0
    .extern csv_size1
    .extern csv_size2
    .extern csv_size3
    .extern csvnamelen

getin       .equ 0xffe4
bsout       .equ 0xffd2

KEY_DOWN    .equ 0x11
KEY_UP      .equ 0x91
KEY_RIGHT   .equ 0x1d
KEY_LEFT    .equ 0x9d
KEY_F       .equ 0x46
KEY_G       .equ 0x47
KEY_ESC     .equ 0x1b
KEY_RETURN  .equ 0x0d
KEY_DEL     .equ 0x14
KEY_F3      .equ 0x86
KEY_F4      .equ 0x8a

; MEGA65 screen-editor compatible control codes.
CTRL_I_TAB_RIGHT  .equ 0x09
CTRL_J_DOWN       .equ 0x0a
CTRL_P_SCROLL_DN  .equ 0x10
CTRL_U_WORD_LEFT  .equ 0x15
CTRL_V_SCROLL_UP  .equ 0x16
CTRL_W_WORD_RIGHT .equ 0x17
CTRL_X_TAB_TOGGLE .equ 0x18
CTRL_Z_TAB_LEFT   .equ 0x1a

RASTER      .equ 0xd012
MODKEYS_IMM  .equ 0xd611
KEYMATRIX     .equ 0xd613
KEYMATRIXSEL  .equ 0xd614
CURSOR_DIRECT  .equ 0xd60f
MODKEY_MEGA   .equ 0x08
MODKEY_SHIFT  .equ 0x03
MODKEY_LSHIFT .equ 0x01
DOUBLECLICK_FRAMES .equ 25

; ------------------------------------------------------------
; Chain-overlay shared state in normal RAM outside linker areas.
; This survives main viewer PRG -> EDIT.PRG -> main viewer PRG.
; ------------------------------------------------------------
OVL_MAGIC        .equ 0x1f00
OVL_COMMAND      .equ 0x1f01
OVL_SIZE0        .equ 0x1f02
OVL_SIZE1        .equ 0x1f03
OVL_SIZE2        .equ 0x1f04
OVL_SIZE3        .equ 0x1f05
OVL_DELIMITER    .equ 0x1f06
OVL_SCREENMODE   .equ 0x1f07
OVL_TOP0         .equ 0x1f08
OVL_TOP1         .equ 0x1f09
OVL_CURROW0      .equ 0x1f0a
OVL_CURROW1      .equ 0x1f0b
OVL_CURCOL       .equ 0x1f0c
OVL_LEFTCOL      .equ 0x1f0d
OVL_MULTI_COUNT  .equ 0x1f0e
OVL_MULTI_MODE   .equ 0x1f0f
OVL_MINROW0      .equ 0x1f10
OVL_MINROW1      .equ 0x1f11
OVL_MAXROW0      .equ 0x1f12
OVL_MAXROW1      .equ 0x1f13
OVL_MINCOL       .equ 0x1f14
OVL_MAXCOL       .equ 0x1f15
OVL_DELIMMODE    .equ 0x1f16
OVL_DECODER      .equ 0x1f17
OVL_ANCHOR_ROW0  .equ 0x1f18
OVL_ANCHOR_ROW1  .equ 0x1f19
OVL_ANCHOR_COL   .equ 0x1f1a
OVL_ROWS0        .equ 0x1f1b
OVL_ROWS1        .equ 0x1f1c
OVL_MAXCOLS0     .equ 0x1f1d
OVL_MAXCOLS1     .equ 0x1f1e
OVL_FROZEN_ROWS  .equ 0x1f1f
OVL_FROZEN_COLS  .equ 0x1f20
OVL_DIRTY        .equ 0x1f26
OVL_MAGIC_VALUE  .equ 0xa5

HOME        .equ 0x13

MENU_ROW        .equ 0
COL_HEADER_ROW  .equ 1
VIEW_TOP        .equ 2
VIEW_ROWS       .equ 48
FROZEN_ROWS     .equ 1
FROZEN_COLS     .equ 0
SCROLL_TOP      .equ (VIEW_TOP + FROZEN_ROWS)
SCROLL_ROWS     .equ (VIEW_ROWS - FROZEN_ROWS)

; Larghezze reali calcolate da csvindex:
;   $08200000 + numero colonna
;
; Il valore memorizzato e' la lunghezza massima del testo.
; A video sono usati:
;   clamp(raw + 1, 4, 24)
;
; Resta 1 carattere libero a destra per evitare che
; BSOUT raggiunga il margine 80 e provochi wrap/scroll KERNAL.
ROW_HEADER_WIDTH .equ 6
DATA_START_X     .equ 6
SCREEN_DATA_COLS .equ 73   ; data area x=6..78, x=79 intentionally unused
MIN_COL_WIDTH    .equ 4
MAX_COL_WIDTH    .equ 24

; Long-cell editor buffers in Attic RAM.
; Logical buffer: 8 KB ($08400000..$08401FFF)
; Serialized temp: 16 KB ($08404000..$08407FFF)
LONGEDIT_BASE0   .equ 0x00
LONGEDIT_BASE1   .equ 0x00
LONGEDIT_BASE2   .equ 0x40
LONGEDIT_BASE3   .equ 0x08
LONGEDIT_MAX_HI  .equ 0x20      ; exclusive: 0x2000 = 8192

LONGSER_BASE0    .equ 0x00
LONGSER_BASE1    .equ 0x40
LONGSER_BASE2    .equ 0x40
LONGSER_BASE3    .equ 0x08
LONGSER_MAX_HI   .equ 0x40      ; exclusive: 0x4000 = 16384
SORTTMP_BASE0    .equ 0x00
SORTTMP_BASE1    .equ 0x00
SORTTMP_BASE2    .equ 0x30
SORTTMP_BASE3    .equ 0x08


    .extern seam_plot
    .extern seam_bsout
    .extern seam_clear_row
    .extern seam_set_attr
    .extern seam_fill_attr_span
    .extern seam_cursor_blink_at
    .extern seam_apply_menu_style
    .extern seam_apply_header_style
    .extern seam_apply_cell_style
    .extern seam_apply_cell_alt_style
    .extern seam_apply_selection_style
    .extern seam_apply_textedit_style
    .extern style_apply_screen_mode
    .extern style_seam_restore
    .extern csv_screen_mode


    .section code,text


; ------------------------------------------------------------
; void csvviewloop(void)
; ------------------------------------------------------------

csvviewloop:

    ; Mouse: driver POT/CIA + sprite hardware VIC-IV.
    jsr mouse_init
    jsr initmousecursor

    lda #0x00
    sta csv_top_row0
    sta csv_top_row1
    sta csv_current_row0
    sta csv_current_row1
    sta csv_current_col
    sta csv_file_loaded
    sta csv_edit_mode
    sta csv_edit_user_entry
    sta csv_edit_silent_load
    sta csv_double_timer
    sta csv_double_valid
    sta csv_clip_valid
    sta csv_clip_len
    sta csv_clip_key_latch
    sta csv_multiselect_count
    sta csv_find_mode
    sta csv_find_len
    sta csv_find_fn_latch
    sta csv_find_fn_physical
    sta csv_find_vertical
    sta csv_find_case_sensitive
    sta csv_replace_mode
    sta csv_replace_focus
    sta csv_replace_len
    sta csv_replace_all_active
    sta csv_find_start_pos0
    sta csv_find_start_pos1
    sta csv_exit_requested
    sta mouse_menu_consumed
    sta mouse_menu_latch

    ; Default delimiter preference: Auto.
    ; csv_delimiter itself starts at comma as an ambiguity fallback;
    ; loadcsv will replace it after auto-detection.
    lda #0
    sta csv_delimiter_mode
    lda #0x2c
    sta csv_delimiter
    sta csv_save_delimiter

    ; Returning from EDIT.PRG? Restore the resident viewer state instead
    ; of starting with an empty sheet.
    lda OVL_MAGIC
    cmp #OVL_MAGIC_VALUE
    bne csvview_fresh_start$
    jsr csv_restore_overlay_state
    lda OVL_COMMAND
    cmp #2
    beq search_overlay_open_replace$
    jsr csv_find_open
    jmp key_loop$
search_overlay_open_replace$:
    jsr csv_replace_open
    jmp key_loop$

csvview_fresh_start$:
    lda RASTER
    sta csv_double_last_raster

    lda #FROZEN_COLS
    sta csv_frozen_cols
    sta csv_left_col

    ; Una riga CSV congelata. top_row indica la prima riga
    ; della parte scrollabile.
    lda #FROZEN_ROWS
    sta csv_frozen_rows
    sta csv_top_row0
    lda #0
    sta csv_top_row1

    ; Runtime screen geometry (25 rows by default).
    jsr csv_update_screen_layout

    ; Start with a real empty sheet, identical to File -> New.
    jsr csv_new_document


key_loop$:
    ; Timer doppio click aggiornato una volta per frame video.

    ; Il mouse va aggiornato continuamente, anche quando non arrivano tasti.
    jsr mouse_update
    jsr updatemousecursor

    ; Dirty-confirmation prompt is keyboard-modal. Ignore mouse clicks until
    ; Y / N / ESC resolves it.
    lda csv_dirty_prompt_active
    beq csv_dirty_mouse_ok$
    jmp mouse_dispatch_done$
csv_dirty_mouse_ok$:

    ; F3/F4 nella Find bar devono essere letti dalla matrice fisica.
    ; GETIN espande F3 nella macro KERNAL "dir", quindi non e' adatto.
    jsr csv_find_poll_function_keys
    lda csv_find_fn_physical
    beq +
    jmp key_loop$
+

    ; Scorciatoie MEGA+C / MEGA+V lette direttamente
    ; dalla matrice hardware, indipendenti da GETIN.
    jsr csv_clip_poll_keys

    ; Se l’edit è attivo e arriva un nuovo click, conferma prima
    ; la cella corrente. Lo stesso click verra' poi inoltrato
    ; normalmente a menu/celle.
    lda csv_edit_mode
    beq mouse_edit_click_done$
    lda mouse_pressed
    bne mouse_edit_commit$
    lda mouse_right_pressed
    beq mouse_edit_click_done$
mouse_edit_commit$:
    jsr csv_edit_key_commit

mouse_edit_click_done$:
	jsr mouse_handle_menu_click

    lda csv_exit_requested
    beq +
    jmp csvview_exit$
+
	
	lda mouse_menu_consumed
	bne mouse_dispatch_done$
	
	lda csvfilebrowser_is_open
	beq searchview_skip_browser_mouse$
	jsr csvfilebrowser_handle_mouse
searchview_skip_browser_mouse$:
	jsr mouse_handle_cell_click

mouse_dispatch_done$:

    ; Latch modifiers while the physical keypress is still active.
    ; By the time GETIN has returned and edit_handle_key runs,
    ; $D611 may already no longer report MEGA.
    lda MODKEYS_IMM
    sta csv_key_mod_latch

    jsr getin
    beq key_loop$

    ; Confirmation prompt has priority over all normal shortcuts/editing.
    pha
    lda csv_dirty_prompt_active
    beq csv_dirty_key_normal$
    pla
    jsr csv_dirty_prompt_handle_key
    jmp key_loop$
csv_dirty_key_normal$:
    pla

    ; MEGA + cursor = Fill in the PHYSICAL cursor-key direction.
    ; Only active in the normal grid view.
    ;
    ; $D60F provides dedicated state bits for the physical LEFT and UP
    ; keys, which otherwise alias RIGHT/DOWN in the C65 matrix.
    ; RIGHT and DOWN are read directly from matrix segment 0.
    pha
    lda csv_edit_mode
    bne csv_shortcut_cursor_not_grid$
    lda csv_key_mod_latch
    and #MODKEY_MEGA
    beq csv_shortcut_cursor_not_grid$

    ; Physical LEFT: $D60F bit 0 = 1 while pressed.
    lda CURSOR_DIRECT
    and #0x01
    bne csv_shortcut_fill_left_from_stack$

    ; Physical UP: $D60F bit 1 = 1 while pressed.
    lda CURSOR_DIRECT
    and #0x02
    bne csv_shortcut_fill_up_from_stack$

    ; Physical RIGHT: matrix segment 0, row/bit 2, active low.
    lda #0
    sta KEYMATRIXSEL
    lda KEYMATRIX
    and #0x04
    beq csv_shortcut_fill_right_from_stack$

    ; Physical DOWN: matrix segment 0, row/bit 7, active low.
    lda #0
    sta KEYMATRIXSEL
    lda KEYMATRIX
    and #0x80
    beq csv_shortcut_fill_down_from_stack$

    ; GETIN returned something else while MEGA was held.
    pla
    pha
    jmp csv_shortcut_cursor_continue$

csv_shortcut_fill_up_from_stack$:
    pla
    pha
    jmp csv_shortcut_fill_up$

csv_shortcut_fill_down_from_stack$:
    pla
    pha
    jmp csv_shortcut_fill_down$

csv_shortcut_fill_right_from_stack$:
    pla
    pha
    jmp csv_shortcut_fill_right$

csv_shortcut_fill_left_from_stack$:
    pla
    pha
    jmp csv_shortcut_fill_left$

csv_shortcut_fill_up$:
    pla
    lda #5
    jmp csv_chain_edit_save
csv_shortcut_fill_down$:
    pla
    lda #6
    jmp csv_chain_edit_save
csv_shortcut_fill_right$:
    pla
    lda #7
    jmp csv_chain_edit_save
csv_shortcut_fill_left$:
    pla
    lda #8
    jmp csv_chain_edit_save

csv_shortcut_cursor_not_grid$:
    pla
    pha
csv_shortcut_cursor_continue$:
    pla

    ; MEGA+C/X/V in full-screen Text Mode is handled by csv_clip_poll_keys.
    ; The KERNAL also queues a PETSCII/graphic byte for the same chord:
    ; discard exactly the next non-zero GETIN byte.
    pha
    lda csv_long_clip_swallow
    beq csv_long_clip_getin_ready$
    lda #0
    sta csv_long_clip_swallow
    pla
    jmp key_loop$

csv_long_clip_getin_ready$:
    pla

    ; Find prompt aperto: intercetta la tastiera prima di edit/browser/menu.
    pha
    lda csv_find_mode
    beq csv_find_input_not_active$
    pla
    jsr csv_find_handle_key
    jmp key_loop$

csv_find_input_not_active$:
    pla

    ; Editing cella: tutti i tasti vengono gestiti qui prima
    ; di browser/menu/navigation.
    pha
    lda csv_edit_mode
    beq not_editing_key$
    pla
    jsr csv_edit_handle_key
    jmp key_loop$

not_editing_key$:
    pla

    ; --------------------------------------------------------
    ; File browser aperto: intercetta tutta la tastiera.
    ; --------------------------------------------------------
    pha
    lda csvfilebrowser_is_open
    bne +
    jmp no_browser$
+
    pla

    jsr csvfilebrowser_handle_key

    cmp #0
    bne +
    jmp key_loop$
+

    cmp #1
    beq browser_open_selected$
    cmp #3
    beq browser_saveas_confirmed$

    ; 2 = ESC: cancel any deferred New/Open after Save As.
    lda #0
    sta csv_dirty_pending_action

    ; 2 = ESC: ripristina il foglio corrente oppure
    ; la viewport vuota se nessun CSV e' ancora caricato.
    lda csv_file_loaded
    beq browser_cancel_empty$

    jsr csvprintview
    jsr highlight_current_cell
    jmp key_loop$

browser_cancel_empty$:
    jsr clear_full_viewport
    jsr draw_menu_bar
    jmp key_loop$


browser_saveas_confirmed$:
    ; Save As confirmed: the browser has prepared csvnamebuf/csvnamelen
    ; and csv_device is the destination selected in the dialog.
    ; Make that device the document's new home before calling savecsv,
    ; because Save always targets csv_loaded_device.
    lda csv_device
    sta csv_loaded_device
    jsr savecsv
    lda #0
    sta OVL_DIRTY

    lda csv_dirty_pending_action
    beq browser_saveas_normal_done$
    jsr csv_dirty_continue_pending
    jmp key_loop$
browser_saveas_normal_done$:
    jsr csvprintview
    jsr highlight_current_cell
    jmp key_loop$


browser_open_selected$:
    ; Il browser ha gia' preparato csvnamebuf/csvnamelen.
    jsr loadcsv
    jsr csvindex
    lda #0
    sta OVL_DIRTY
    
    lda #0x01
    sta csv_file_loaded

    ; Nuovo file: viewport e cella ripartono dall'origine.
    lda csv_frozen_rows
    sta csv_top_row0
    lda #0
    sta csv_top_row1
    sta csv_current_row0
    sta csv_current_row1
    sta csv_current_col
    sta csv_double_timer
    sta csv_double_valid

    lda csv_frozen_cols
    sta csv_left_col

    jsr csvprintview
    jsr highlight_current_cell
    jsr csv_multiselect_reset_current
    jmp key_loop$

no_browser$:
    pla

    ; Se il menu File e' aperto, intercetta tutti i tasti.
    pha
    lda csvmenu_is_open
    bne +
    jmp no_menu$
+
    pla
    sta last_view_key

    ; GRID: da tastiera è gestito per ora solo ESC.
    lda csvmenu_type
    cmp #2
    bne menu_keyboard_file$

    lda last_view_key
    cmp #KEY_ESC
    beq menu_keyboard_grid_close$
    jmp key_loop$

menu_keyboard_grid_close$:
    jsr csvmenu_close
    lda csv_file_loaded
    bne +
    jmp menu_close_empty$
+
    jsr csvprintview
    jsr highlight_current_cell
    jmp key_loop$

menu_keyboard_file$:
    lda last_view_key
    jsr csvmenu_handle_key
    cmp #0
    bne +
    jmp key_loop$
+

    sta menu_action
    jsr csvmenu_close

    lda menu_action
    cmp #1
    bne +
    jmp menu_open_file$
+
    cmp #2
    bne +
    jmp menu_save_file$
+
    cmp #4
    bne +
    jmp menu_saveas_file$
+
    cmp #5
    bne +
    jmp menu_exit_file$
+
    cmp #6
    bne +
    jmp menu_new_file$
+

    ; ESC (3): chiude soltanto il menu.
    lda csv_file_loaded
    bne +
    jmp menu_close_empty$
+

    jsr csvprintview
    jsr highlight_current_cell
    jmp key_loop$


menu_saveas_file$:
    lda csv_file_loaded
    bne +
    jmp menu_close_empty$
+

    ; Restore the sheet below the menu, then open the modal Save As dialog.
    jsr csvprintview
    jsr highlight_current_cell
    jsr csvfilebrowser_open_saveas
    jmp key_loop$


menu_save_file$:
    lda csv_file_loaded
    bne +
    jmp menu_close_empty$
+
    lda csvnamelen
    bne +
    jmp menu_saveas_file$
+
    jsr savecsv
    lda #0
    sta OVL_DIRTY
    jsr csvprintview
    jsr highlight_current_cell
    jmp key_loop$

; ------------------------------------------------------------
; File -> Exit
; Use the same unsaved-changes guard as New/Open.
; ------------------------------------------------------------
menu_exit_file$:
    jsr csv_request_exit
    jmp key_loop$

; ------------------------------------------------------------
; File -> New
; Creates a real empty 15 x 15 CSV document in Attic RAM.
; The document has no filename until the first Save / Save As.
; ------------------------------------------------------------
menu_new_file$:
    jsr csv_request_new
    jmp key_loop$


menu_close_empty$:
    jsr clear_full_viewport
    jsr draw_menu_bar
    jmp key_loop$

menu_open_file$:
    jsr csv_request_open
    jmp key_loop$

; ------------------------------------------------------------
; File -> Exit
; Restore the exact KERNAL text/video state captured at startup and
; return from csvviewloop. main() then returns normally to BASIC.
; ------------------------------------------------------------
csvview_exit$:
    jsr csvmenu_close
    jsr hidemousecursor
    jsr style_seam_restore

    ; Chain-loaded overlays replace the original C/BASIC return context.
    ; Do not RTS back through that synthetic stack.  Enter the KERNAL
    ; reset path instead.  This works with the stable ROM too and does
    ; not depend on the newer 920416+ reset API.
    sei
    cld
    ldx #0xff
    txs
    jmp (0xfffc)

no_menu$:
    pla
    sta last_view_key

    cmp #KEY_F
    bne check_grid_key$
    jsr csvmenu_open_file
    jmp key_loop$

check_grid_key$:
    cmp #KEY_G
    bne regular_keys$
    jsr csvmenu_open_grid
    jmp key_loop$

regular_keys$:
    ; Senza CSV caricato, ignora i comandi del foglio.
    lda csv_file_loaded
    bne csv_keys_enabled$
    jmp key_loop$

csv_keys_enabled$:
    lda last_view_key

    ; INST/DEL sulla griglia: svuota la cella corrente.
    ; Non tocca il clipboard interno.
    cmp #KEY_DEL
    bne +
    lda #4                  ; overlay: Delete selection/current cell
    jmp csv_chain_edit_save
+
    cmp #KEY_RETURN
    bne +
    lda #1
    sta csv_edit_user_entry
    jsr csv_edit_begin
    jmp key_loop$
+
    cmp #KEY_DOWN
    beq down$

    cmp #KEY_UP
    bne +
    jmp up$
+

    cmp #KEY_RIGHT
    bne +
    jmp right$
+

    cmp #KEY_LEFT
    bne +
    jmp left$
+

    jmp key_loop$


; ------------------------------------------------------------
; Clipboard shortcuts
; ------------------------------------------------------------

; ------------------------------------------------------------
; CURSOR DOWN
;
; Scorre solo se:
;
;   csv_top_row + VIEW_ROWS < csv_rows
;
; In questo modo, a fondo viewport, l'ultima riga
; resta nell'ultima posizione della viewport.
; ------------------------------------------------------------

down$:
    ; Se current_row + 1 >= csv_rows, la riga corrente è l'ultima.
    lda csv_current_row0
    clc
    adc #0x01
    sta temp_row0

    lda csv_current_row1
    adc #0x00
    sta temp_row1

    lda temp_row1
    cmp csv_rows1
    bcc down_exists$
    beq +
    jmp key_loop$
+

    lda temp_row0
    cmp csv_rows0
    bcc +
    jmp key_loop$
+

down_exists$:
    ; Indica se il flusso proviene da una selezione di riga/colonna intera.
    lda csv_multiselect_mode
    sta keyboard_old_select_mode

    ; Togli highlight dalla cella corrente.
    jsr unhighlight_current_cell

    ; current_row++
    inc csv_current_row0
    bne +
    inc csv_current_row1
+

    ; Movimento normale da tastiera = selezione singola.
    ; Aggiorna anchor/min/max PRIMA di un eventuale redraw,
    ; altrimenti csv_multiselect_highlight_all riusa i vecchi
    ; bounds (tipicamente 0,0 = cella 1:1).
    jsr csv_multiselect_reset_current

    ; Le prime due righe sono frozen.
    lda csv_current_row1
    bne down_scroll_part$
    lda csv_current_row0
    cmp csv_frozen_rows
    bcc down_highlight$

down_scroll_part$:
    ; Nella parte scrollabile sono visibili SCROLL_ROWS righe.
    jsr calc_scroll_index
    jsr calc_runtime_scroll_layout
    lda current_screen_row
    cmp runtime_scroll_rows
    bcc down_highlight$

    ; La selezione e' uscita dal bordo inferiore:
    ; top_row++ e scroll veloce di una riga.
    inc csv_top_row0
    bne +
    inc csv_top_row1
+
    jsr scroll_down_view

down_highlight$:
    ; Se provenivamo da selezione intera riga/colonna, il solo
    ; unhighlight della cella non basta: ridisegna per cancellare
    ; il vecchio highlight completo. La selezione logica è già
    ; stata collassata da csv_multiselect_reset_current.
    lda keyboard_old_select_mode
    beq +
    lda #0
    sta keyboard_old_select_mode
    jsr csvprintview
+
    jsr highlight_current_cell
    jmp key_loop$


; ------------------------------------------------------------
; CURSOR UP
; ------------------------------------------------------------

up$:
    ; Gia' sulla prima riga del CSV?
    lda csv_current_row0
    ora csv_current_row1
    bne +
    jmp key_loop$
+

    ; Indica se il flusso proviene da una selezione di riga/colonna intera.
    lda csv_multiselect_mode
    sta keyboard_old_select_mode

    ; Togli highlight corrente.
    jsr unhighlight_current_cell

    ; current_row--
    lda csv_current_row0
    bne +
    dec csv_current_row1
+
    dec csv_current_row0

    ; Movimento normale da tastiera = selezione singola.
    jsr csv_multiselect_reset_current

    ; Nelle righe frozen non deve avvenire scrolling.
    lda csv_current_row1
    bne up_check_top$
    lda csv_current_row0
    cmp csv_frozen_rows
    bcc up_highlight$

up_check_top$:
    ; Se current_row >= top_row, resta nella viewport scrollabile.
    lda csv_current_row1
    cmp csv_top_row1
    bcc up_scroll$
    bne up_highlight$

    lda csv_current_row0
    cmp csv_top_row0
    bcs up_highlight$

up_scroll$:
    ; top_row-- e scroll veloce verso il basso.
    lda csv_top_row0
    bne +
    dec csv_top_row1
+
    dec csv_top_row0

    jsr scroll_up_view

up_highlight$:
    ; Se provenivamo da selezione intera riga/colonna, il solo
    ; unhighlight della cella non basta: ridisegna per cancellare
    ; il vecchio highlight completo. La selezione logica è già
    ; stata collassata da csv_multiselect_reset_current.
    lda keyboard_old_select_mode
    beq +
    lda #0
    sta keyboard_old_select_mode
    jsr csvprintview
+
    jsr highlight_current_cell
    jmp key_loop$


; ------------------------------------------------------------
; CURSOR RIGHT / LEFT + SCROLLING ORIZZONTALE DINAMICO
;
; csv_current_col = colonna assoluta selezionata
; csv_left_col    = prima colonna visibile
;
; Le colonne NON hanno piu' larghezza fissa.
; La larghezza viene letta da $08200000.
; ------------------------------------------------------------

right$:
    ; Verifica che esista current_col + 1.
    lda csv_maxcols1
    bne right_can_move$

    lda csv_current_col
    clc
    adc #0x01
    cmp csv_maxcols0
    bcc right_can_move$
    jmp key_loop$

right_can_move$:
    lda csv_current_col
    cmp #0xff
    bne +
    jmp key_loop$
+
    lda csv_multiselect_mode
    sta keyboard_old_select_mode
    jsr unhighlight_current_cell

    inc csv_current_col

    ; Movimento normale da tastiera = selezione singola.
    ; Deve avvenire prima di csvredraw_horizontal.
    jsr csv_multiselect_reset_current

    ; Fa avanzare left_col finche' la cella corrente
    ; entra interamente nello spazio video disponibile.
    jsr ensure_current_visible

    lda hscroll_changed
    beq right_highlight$

    jsr csvredraw_horizontal

right_highlight$:
    ; Se provenivamo da selezione intera riga/colonna, il solo
    ; unhighlight della cella non basta: ridisegna per cancellare
    ; il vecchio highlight completo. La selezione logica è già
    ; stata collassata da csv_multiselect_reset_current.
    lda keyboard_old_select_mode
    beq +
    lda #0
    sta keyboard_old_select_mode
    jsr csvprintview
+
    jsr highlight_current_cell
    jmp key_loop$


left$:
    lda csv_current_col
    bne +
    jmp key_loop$
+
    lda csv_multiselect_mode
    sta keyboard_old_select_mode
    jsr unhighlight_current_cell
    dec csv_current_col

    ; Movimento normale da tastiera = selezione singola.
    ; Deve avvenire prima di csvredraw_horizontal.
    jsr csv_multiselect_reset_current

    ; Colonne 0 e 1 sono frozen: non modificano csv_left_col.
    lda csv_current_col
    cmp csv_frozen_cols
    bcc left_highlight$

    ; Parte scrollabile: se current < left, porta left a current.
    cmp csv_left_col
    bcs left_highlight$

    sta csv_left_col
    jsr csvredraw_horizontal

left_highlight$:
    ; Se provenivamo da selezione intera riga/colonna, il solo
    ; unhighlight della cella non basta: ridisegna per cancellare
    ; il vecchio highlight completo. La selezione logica è già
    ; stata collassata da csv_multiselect_reset_current.
    lda keyboard_old_select_mode
    beq +
    lda #0
    sta keyboard_old_select_mode
    jsr csvprintview
+
    jsr highlight_current_cell
    jmp key_loop$


; ------------------------------------------------------------
; mouse_handle_menu_click
;
; Gestione mouse per il menu FILE gia' esistente.
;
; Barra:
;   row 0, cols 0..5  -> FILE
;
; Tendina FILE:
;   row 1, cols 0..13 -> Open
;   row 2, cols 0..13 -> Save
;   row 3, cols 0..13 -> Save As...
;   row 4, cols 0..13 -> Preferences >
;   row 5, cols 0..13 -> Exit
;
; Un click fuori dalla tendina la chiude.
; EDIT e VIEW restano per ora soltanto voci grafiche, come prima.
;
; mouse_menu_consumed = 1 impedisce allo stesso click di
; selezionare anche una cella del foglio.
; ------------------------------------------------------------

mouse_handle_menu_click:
    ; Robust single-click handling for menus.
    ;
    ; mouse_pressed is only a one-poll edge and can be missed.  For menu
    ; interaction use the persistent mouse_held state plus a latch:
    ;   held=1, latch=0 -> accept exactly one click
    ;   held=1, latch=1 -> ignore until physical release
    ;   held=0         -> re-arm for the next click
    lda #0
    sta mouse_menu_consumed

    lda mouse_held
    bne mouse_menu_button_down$

    ; Physical release: arm the next click.
    lda #0
    sta mouse_menu_latch
    rts

mouse_menu_button_down$:
    lda mouse_menu_latch
    beq mouse_menu_new_click$
    rts

mouse_menu_new_click$:
    lda #1
    sta mouse_menu_latch
    lda csvfilebrowser_is_open
    beq +
    rts
+

    ; Mouse Y uses native text-raster coordinates in both modes:
    ;   80x25 -> Y 0..199
    ;   80x50 -> Y 0..399
    ; A text row is always 8 mouse units, so the hit-test is
    ; always row = Y / 8. In 80x50 the high Y bit contributes 32.
    lda mouse_ypos
    lsr a
    lsr a
    lsr a
    sta mouse_menu_row
    lda mouse_ypos+1
    beq mouse_menu_y_done$
    lda mouse_menu_row
    clc
    adc #32
    sta mouse_menu_row
mouse_menu_y_done$:

    ; X / 8 -> col 0..79
    lda mouse_xpos+1
    lsr a
    sta mouse_menu_xhi
    lda mouse_xpos
    ror a
    lsr mouse_menu_xhi
    ror a
    lsr mouse_menu_xhi
    ror a
    sta mouse_menu_col

    ; --------------------------------------------------------
    ; Replace All command: Replace row, F9 ALL at cols 73..78.
    ; --------------------------------------------------------
    lda csv_replace_mode
    beq mouse_replace_all_not_active$
    lda mouse_menu_row
    cmp runtime_replace_row
    bne mouse_replace_all_not_active$
    lda mouse_menu_col
    cmp #73
    bcc mouse_replace_all_not_active$
    cmp #79
    bcs mouse_replace_all_not_active$

    lda #1
    sta mouse_menu_consumed
    jsr csv_replace_all
    rts

mouse_replace_all_not_active$:
    ; --------------------------------------------------------
    ; Find-bar toggles.
    ; Shared command strip row:
    ;   cols 64..71 = F5 CASE / F5[CASE]
    ;   cols 73..79 = F7 COL  / F7[COL]
    ; --------------------------------------------------------
    lda csv_find_mode
    beq mouse_find_toggles_not_active$
    lda mouse_menu_row
    sta csv_replace_mouse_row
    lda csv_replace_mode
    beq +
    lda csv_replace_mouse_row
    cmp runtime_replace_row
    bne mouse_find_toggles_not_active$
    jmp mouse_find_toggle_row_ok$
+
    lda csv_replace_mouse_row
    cmp runtime_last_row
    bne mouse_find_toggles_not_active$
mouse_find_toggle_row_ok$:

    ; Case toggle.
    lda mouse_menu_col
    cmp #64
    bcc mouse_find_check_vertical$
    cmp #72
    bcs mouse_find_check_vertical$

    lda #1
    sta mouse_menu_consumed
    lda csv_find_case_sensitive
    eor #1
    sta csv_find_case_sensitive
    jsr csv_find_redraw_active_panel
    rts

mouse_find_check_vertical$:
    lda mouse_menu_col
    cmp #73
    bcc mouse_find_toggles_not_active$
    cmp #80
    bcs mouse_find_toggles_not_active$

    lda #1
    sta mouse_menu_consumed
    lda csv_find_vertical
    eor #1
    sta csv_find_vertical
    jsr csv_find_redraw_active_panel
    rts

mouse_find_toggles_not_active$:
    lda csvmenu_is_open
    bne +
    jmp mouse_menu_closed$
+

    ; If another title on the menu bar was clicked, switch menus now.
    ; A click on row 0 outside all titles closes the current menu.
    jsr mouse_menu_bar_switch$
    bcc +
    rts
+

    lda csvmenu_type
    cmp #1
    beq mouse_file_open$
    cmp #2
    bne +
    jmp mouse_grid_open$
+
    cmp #3
    bne +
    jmp mouse_edit_open$
+
    rts

; ------------------------------------------------------------
; FILE aperto
; ------------------------------------------------------------
mouse_file_open$:
    ; Preferences/Decoder submenu aperto?
    lda csvmenu_submenu
    beq mouse_file_root$
    cmp #1
    bne +
    jmp mouse_file_preferences_submenu$
+
    cmp #2
    bne +
    jmp mouse_file_decoder_submenu$
+
    cmp #3
    bne +
    jmp mouse_file_delimiter_submenu$
+
    cmp #4
    bne mouse_file_root$
    jmp mouse_file_screen_submenu$

mouse_file_root$:
    ; FILE sulla barra: nuovo click = chiudi.
    lda mouse_menu_row
    bne mouse_file_rows$
    lda mouse_menu_col
    cmp #6
    bcc +
    jmp mouse_menu_consume_only$
+
    jmp mouse_menu_close_restore$

mouse_file_rows$:
    ; Open: row 1, cols 0..13
    lda mouse_menu_row
    cmp #2
    bne mouse_file_save$
    lda mouse_menu_col
    cmp #14
    bcc +
    jmp mouse_menu_consume_only$
+
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    jsr csv_request_open
    rts

mouse_file_save$:
    lda mouse_menu_row
    cmp #3
    bne mouse_file_saveas$
    lda mouse_menu_col
    cmp #14
    bcc +
    jmp mouse_menu_consume_only$
+
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda csv_file_loaded
    bne +
    jmp mouse_menu_restore_empty$
+
    lda csvnamelen
    bne mouse_file_save_named$
    jsr csvprintview
    jsr highlight_current_cell
    jsr csvfilebrowser_open_saveas
    rts
mouse_file_save_named$:
    jsr savecsv
    lda #0
    sta OVL_DIRTY
    jsr csvprintview
    jsr highlight_current_cell
    rts

mouse_file_saveas$:
    lda mouse_menu_row
    cmp #4
    bne mouse_file_preferences$
    lda mouse_menu_col
    cmp #14
    bcc +
    jmp mouse_menu_consume_only$
+
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda csv_file_loaded
    bne +
    jmp mouse_menu_restore_empty$
+
    jsr csvprintview
    jsr highlight_current_cell
    jsr csvfilebrowser_open_saveas
    rts

mouse_file_preferences$:
    lda mouse_menu_row
    cmp #1
    beq mouse_file_new$
    cmp #5
    beq mouse_file_preferences_hit$
    cmp #6
    beq mouse_file_exit$
    jmp mouse_menu_consume_only$

mouse_file_preferences_hit$:
    lda mouse_menu_col
    cmp #14
    bcc +
    jmp mouse_menu_consume_only$
+
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_open_preferences
    rts

mouse_file_new$:
    lda mouse_menu_col
    cmp #14
    bcc +
    jmp mouse_menu_consume_only$
+
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    jsr csv_request_new
    rts

mouse_file_exit$:
    lda mouse_menu_col
    cmp #14
    bcc +
    jmp mouse_menu_consume_only$
+
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    jsr csv_request_exit
    rts

; FILE -> Preferences panel: col 14..27, row 4 = Decoder >
mouse_file_preferences_submenu$:
    lda mouse_menu_col
    cmp #14
    bcs +
    jmp mouse_file_root$
+
    cmp #28
    bcc +
    jmp mouse_file_root$
+
    lda mouse_menu_row
    cmp #4
    beq mouse_file_open_decoder$
    cmp #5
    beq mouse_file_open_delimiter$
    cmp #6
    beq mouse_file_open_screen$
    jmp mouse_menu_consume_only$

mouse_file_open_decoder$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_open_decoder
    rts

mouse_file_open_delimiter$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_open_delimiter
    rts

mouse_file_open_screen$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_open_screen
    rts

; FILE -> Preferences -> Decoder panel:
;   row 4 = PETSCII
;   row 5 = UTF-8
mouse_file_decoder_submenu$:
    lda mouse_menu_col
    cmp #28
    bcc mouse_file_preferences_submenu$
    cmp #42
    bcs mouse_file_preferences_submenu$

    lda mouse_menu_row
    cmp #4
    beq mouse_file_set_petscii$
    cmp #5
    beq mouse_file_set_utf8$
    jmp mouse_menu_consume_only$


mouse_file_set_petscii$:
    lda #1
    sta csv_decoder_mode
    jmp mouse_file_decoder_selected$

mouse_file_set_utf8$:
    lda #0
    sta csv_decoder_mode

mouse_file_decoder_selected$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda csv_file_loaded
    beq mouse_file_decoder_restore_empty$

    ; A file is already open: reload the same csvnamebuf/csvnamelen
    ; from the device it originally came from, regardless of any
    ; temporary drive selection made/cancelled in the file browser.
    lda csv_loaded_device
    beq +
    sta csv_device
+
    jsr loadcsv
    jsr csvindex
    lda #0
    sta OVL_DIRTY

    jsr csvprintview
    jsr csv_multiselect_highlight_all
    rts

mouse_file_decoder_restore_empty$:
    jsr clear_full_viewport
    jsr draw_menu_bar
    rts


; FILE -> Preferences -> Delimiter panel:
;   row 5 = Comma
;   row 6 = Semicolon
;   row 7 = Tab
mouse_file_delimiter_submenu$:
    lda mouse_menu_col
    cmp #28
    bcs +
    jmp mouse_file_preferences_submenu$
+
    cmp #42
    bcc +
    jmp mouse_file_preferences_submenu$
+

    lda mouse_menu_row
    cmp #5
    beq mouse_file_set_auto$
    cmp #6
    beq mouse_file_set_comma$
    cmp #7
    beq mouse_file_set_semicolon$
    cmp #8
    beq mouse_file_set_tab$
    jmp mouse_menu_consume_only$

mouse_file_set_auto$:
    lda #0
    sta csv_delimiter_mode

    ; Auto means: preserve the delimiter detected in the current document.
    ; With no file open, comma remains the harmless output fallback.
    lda csv_file_loaded
    beq mouse_file_auto_empty$
    lda csv_delimiter
    sta csv_save_delimiter
    jmp mouse_file_delimiter_selected$

mouse_file_auto_empty$:
    lda #0x2c
    sta csv_save_delimiter
    jmp mouse_file_delimiter_selected$

mouse_file_set_comma$:
    lda #1
    sta csv_delimiter_mode
    lda #0x2c
    sta csv_save_delimiter
    jmp mouse_file_delimiter_selected$

mouse_file_set_semicolon$:
    lda #2
    sta csv_delimiter_mode
    lda #0x3b
    sta csv_save_delimiter
    jmp mouse_file_delimiter_selected$

mouse_file_set_tab$:
    lda #3
    sta csv_delimiter_mode
    lda #0x09
    sta csv_save_delimiter

mouse_file_delimiter_selected$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close

    ; Delimiter preference is an output-format setting. Do not reload or
    ; reinterpret the current document: csv_delimiter remains the actual
    ; separator already detected in Attic.
    lda csv_file_loaded
    beq mouse_file_delimiter_restore_empty$

    jsr csvprintview
    jsr csv_multiselect_highlight_all
    rts


mouse_file_delimiter_restore_empty$:
    jsr clear_full_viewport
    jsr draw_menu_bar
    rts



; FILE -> Preferences -> Screen panel:
;   row 6 = 80 x 25
;   row 7 = 80 x 50
mouse_file_screen_submenu$:
    lda mouse_menu_col
    cmp #28
    bcs +
    jmp mouse_file_preferences_submenu$
+
    cmp #42
    bcc +
    jmp mouse_file_preferences_submenu$
+

    lda mouse_menu_row
    cmp #6
    beq mouse_file_set_screen25$
    cmp #7
    beq mouse_file_set_screen50$
    jmp mouse_menu_consume_only$

mouse_file_set_screen25$:
    lda csv_screen_mode
    beq mouse_file_screen_unchanged$
    lda #0
    sta csv_screen_mode
    jsr mouse_scale_to_25
    jmp mouse_file_screen_selected$

mouse_file_set_screen50$:
    lda csv_screen_mode
    bne mouse_file_screen_unchanged$
    lda #1
    sta csv_screen_mode
    jsr mouse_scale_to_50
    jmp mouse_file_screen_selected$

; Selecting the already active mode is a STRICT no-op.
; Close the logical menu state only. Do not redraw, do not touch
; VIC-IV, sprite, mouse, viewport, selection or screen RAM.
mouse_file_screen_unchanged$:
    ; La voce scelta e' gia' attiva.
    ;
    ; Questo caso deve essere completamente "modale": il click che ha
    ; scelto 80x25/80x50 non deve poter ricadere nel FILE menu / Open.
    ; La pressione resta acquisita fino al rilascio
    ; fisico del pulsante.
    lda #1
    sta mouse_menu_consumed
    sta mouse_menu_latch

    lda #0
    sta mouse_pressed

    jsr csvmenu_close

mouse_file_screen_wait_release$:
    jsr mouse_update
    jsr updatemousecursor

    lda mouse_held
    bne mouse_file_screen_wait_release$

    ; Il pulsante e' realmente rilasciato: azzera il latch prima di
    ; restituire il controllo al normale dispatcher.
    lda #0
    sta mouse_menu_latch
    sta mouse_pressed

    ; Ripristina la schermata sotto i menu appena chiusi.
    lda csv_file_loaded
    beq mouse_file_screen_unchanged_empty$

    jsr csvprintview
    jsr csv_multiselect_highlight_all
    rts

mouse_file_screen_unchanged_empty$:
    jsr clear_full_viewport
    jsr draw_menu_bar
    rts

mouse_file_screen_selected$:
    lda #1
    sta mouse_menu_consumed
    sta mouse_menu_latch

    lda #0
    sta mouse_pressed

    jsr csvmenu_close

    ; Reconfigure VIC-IV and all runtime row limits.
    jsr style_apply_screen_mode

    ; V400/V200 transitions may cause the VIC-IV to recalculate the
    ; sprite pointer location. Rebuild KnockCSV's custom sprite pointer
    ; table/data and then apply the correct vertical sprite profile.
    jsr initmousecursor
    jsr sprite_apply_screen_mode
    jsr updatemousecursor

    jsr csv_update_screen_layout

    lda csv_file_loaded
    beq mouse_file_screen_restore_empty$

    ; Keep current document/viewport; just clamp top row if needed and redraw.
    jsr csvprintview
    jsr csv_multiselect_highlight_all
    rts

mouse_file_screen_restore_empty$:
    jsr clear_full_viewport
    jsr draw_menu_bar
    rts


; ------------------------------------------------------------
; EDIT aperto
;
; Barra EDIT: cols 7..12
; Tendina: cols 7..22
;   row 1 = Copy
;   row 2 = Paste
;   row 3 = Cut
;   row 4 = Delete
; ------------------------------------------------------------

mouse_edit_open$:
    ; Fill submenu open?
    lda csvmenu_submenu
    beq mouse_edit_root$
    cmp #1
    beq mouse_edit_fill_submenu$
    lda #0
    sta csvmenu_submenu

mouse_edit_root$:
    ; Nuovo click su EDIT nella barra = chiudi.
    lda mouse_menu_row
    bne mouse_edit_rows$

    lda mouse_menu_col
    cmp #7
    bcc mouse_edit_consume$
    cmp #13
    bcs mouse_edit_consume$
    jmp mouse_menu_close_restore$

mouse_edit_consume$:
    jmp mouse_menu_consume_only$

mouse_edit_rows$:
    ; Deve essere dentro la larghezza della tendina.
    lda mouse_menu_col
    cmp #7
    bcc mouse_edit_outside$
    cmp #23
    bcs mouse_edit_outside$

    lda mouse_menu_row
    cmp #1
    bne +
    jmp mouse_edit_copy$
+
    cmp #2
    bne +
    jmp mouse_edit_paste$
+
    cmp #3
    bne +
    jmp mouse_edit_cut$
+
    cmp #4
    bne +
    jmp mouse_edit_delete$
+
    cmp #5
    bne +
    jmp mouse_edit_find$
+
    cmp #6
    bne +
    jmp mouse_edit_replace$
+
    cmp #7
    bne +
    jmp mouse_edit_fill$
+

mouse_edit_outside$:
    ; Come FILE/GRID: non chiude per un evento esterno spurio.
    jmp mouse_menu_consume_only$


mouse_edit_fill$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_open_fill
    rts


mouse_edit_fill_submenu$:
    ; submenu x=23..45, rows 7..14
    lda mouse_menu_col
    cmp #23
    bcc mouse_edit_root$
    cmp #46
    bcs mouse_edit_root$

    lda mouse_menu_row
    cmp #7
    bne +
    jmp mouse_edit_fill_up$
+
    cmp #8
    bne +
    jmp mouse_edit_fill_down$
+
    cmp #9
    bne +
    jmp mouse_edit_fill_right$
+
    cmp #10
    bne +
    jmp mouse_edit_fill_left$
+
    cmp #11
    bne +
    jmp mouse_edit_fill_all_up$
+
    cmp #12
    bne +
    jmp mouse_edit_fill_all_down$
+
    cmp #13
    bne +
    jmp mouse_edit_fill_all_right$
+
    cmp #14
    bne +
    jmp mouse_edit_fill_all_left$
+
    jmp mouse_menu_consume_only$

mouse_edit_fill_up$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #5                  ; overlay: Fill Up
    jmp csv_chain_edit_save

mouse_edit_fill_down$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #6                  ; overlay: Fill Down
    jmp csv_chain_edit_save

mouse_edit_fill_right$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #7                  ; overlay: Fill Right
    jmp csv_chain_edit_save

mouse_edit_fill_left$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #8                  ; overlay: Fill Left
    jmp csv_chain_edit_save

mouse_edit_fill_all_up$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #9                  ; overlay: Fill All Up
    jmp csv_chain_edit_save

mouse_edit_fill_all_down$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #10                 ; overlay: Fill All Down
    jmp csv_chain_edit_save

mouse_edit_fill_all_right$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #11                 ; overlay: Fill All Right
    jmp csv_chain_edit_save

mouse_edit_fill_all_left$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #12                 ; overlay: Fill All Left
    jmp csv_chain_edit_save


mouse_edit_copy$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    jsr csv_clip_copy
    rts


mouse_edit_paste$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    jsr csv_clip_paste
    rts


mouse_edit_cut$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    jsr csv_clip_cut
    rts


mouse_edit_delete$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #4                  ; overlay: Delete selection/current cell
    jmp csv_chain_edit_save


mouse_edit_find$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close

    lda csv_file_loaded
    bne +
    rts
+
    jsr csvprintview
    jsr csv_multiselect_highlight_all
    jsr csv_find_open
    rts


mouse_edit_replace$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close

    lda csv_file_loaded
    bne +
    rts
+
    jsr csvprintview
    jsr csv_multiselect_highlight_all
    jsr csv_replace_open
    rts


mouse_edit_restore_empty$:
    jsr clear_full_viewport
    jsr draw_menu_bar
    rts


; ------------------------------------------------------------
; GRID aperto
;
; Primo livello:
;   dropdown x = 14..35
;   row 1 = Headers >
;
; Sottomenu Headers:
;   x = 36..59
;   row 1 = no header rows
;   row 2 = 1 header row
;   row 3 = 2 header rows
;   row 4 = separatore
;   row 5 = no header columns
;   row 6 = 1 header column
;   row 7 = 2 header columns
; ------------------------------------------------------------
mouse_grid_open$:
    ; Click su GRID nella barra: toggle chiudi.
    lda mouse_menu_row
    bne mouse_grid_body$
    lda mouse_menu_col
    cmp #14
    bcc mouse_grid_consume$
    cmp #20
    bcs mouse_grid_consume$
    jmp mouse_menu_close_restore$

mouse_grid_consume$:
    jmp mouse_menu_consume_only$

mouse_grid_body$:
    lda csvmenu_submenu
    bne +
    jmp mouse_grid_root$
+
    cmp #1
    beq mouse_grid_headers_submenu$
    cmp #2
    beq mouse_grid_sort_submenu$
    jmp mouse_grid_root$

mouse_grid_headers_submenu$:
    lda mouse_menu_col
    cmp #36
    bcc mouse_grid_root$
    cmp #60
    bcs mouse_grid_root$
    lda mouse_menu_row
    cmp #1
    bne +
    jmp mouse_grid_rows0$
+
    cmp #2
    bne +
    jmp mouse_grid_rows1$
+
    cmp #3
    bne +
    jmp mouse_grid_rows2$
+
    cmp #5
    bne +
    jmp mouse_grid_cols0$
+
    cmp #6
    bne +
    jmp mouse_grid_cols1$
+
    cmp #7
    bne +
    jmp mouse_grid_cols2$
+
    jmp mouse_menu_consume_only$

mouse_grid_sort_submenu$:
    lda mouse_menu_col
    cmp #36
    bcc mouse_grid_root$
    cmp #60
    bcs mouse_grid_root$

    lda mouse_menu_row
    cmp #10
    bne +
    jmp mouse_grid_sort_asc$
+
    cmp #11
    bne +
    jmp mouse_grid_sort_desc$
+
    cmp #12
    bne +
    jmp mouse_grid_sort_num_asc$
+
    cmp #13
    bne +
    jmp mouse_grid_sort_num_desc$
+
    cmp #14
    bne +
    jmp mouse_grid_sort_len_asc$
+
    cmp #15
    bne +
    jmp mouse_grid_sort_len_desc$
+
    jmp mouse_menu_consume_only$

mouse_grid_root$:
    ; Primo livello GRID: x=14..39
    lda mouse_menu_col
    cmp #14
    bcs +
    jmp mouse_grid_outside$
+
    cmp #40
    bcc +
    jmp mouse_grid_outside$
+

    lda mouse_menu_row
    cmp #1
    bne +
    jmp mouse_grid_headers$
+
    cmp #2
    bne +
    jmp mouse_grid_row_above$
+
    cmp #3
    bne +
    jmp mouse_grid_row_below$
+
    cmp #4
    bne +
    jmp mouse_grid_delete_row$
+
    cmp #6
    bne +
    jmp mouse_grid_col_left$
+
    cmp #7
    bne +
    jmp mouse_grid_col_right$
+
    cmp #8
    bne +
    jmp mouse_grid_delete_col$
+
    cmp #10
    bne +
    jmp mouse_grid_sort$
+
    jmp mouse_grid_outside$

mouse_grid_headers$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_open_headers
    rts

mouse_grid_sort$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_open_sort
    rts

mouse_grid_sort_asc$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #19                ; overlay: Sort text ascending
    jmp csv_chain_edit_save

mouse_grid_sort_desc$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #20                ; overlay: Sort text descending
    jmp csv_chain_edit_save

mouse_grid_sort_num_asc$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #21                ; overlay: Sort numeric ascending
    jmp csv_chain_edit_save

mouse_grid_sort_num_desc$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #22                ; overlay: Sort numeric descending
    jmp csv_chain_edit_save

mouse_grid_sort_len_asc$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #23                ; overlay: Sort length ascending
    jmp csv_chain_edit_save

mouse_grid_sort_len_desc$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #24                ; overlay: Sort length descending
    jmp csv_chain_edit_save

mouse_grid_row_above$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #13                 ; overlay: Insert Row Above
    jmp csv_chain_edit_save

mouse_grid_row_below$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #14                 ; overlay: Insert Row Below
    jmp csv_chain_edit_save

mouse_grid_col_left$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #16                 ; overlay: Insert Column Left
    jmp csv_chain_edit_save

mouse_grid_col_right$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #17                 ; overlay: Insert Column Right
    jmp csv_chain_edit_save

mouse_grid_delete_row$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #15                 ; overlay: Delete Row(s)
    jmp csv_chain_edit_save

mouse_grid_delete_col$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close
    lda #18                 ; overlay: Delete Column(s)
    jmp csv_chain_edit_save

mouse_grid_outside$:
    ; Come FILE, il menu non viene chiuso automaticamente da click esterni:
    ; il click viene consumato e il menu resta stabile.
    jmp mouse_menu_consume_only$

mouse_grid_rows0$:
    lda #0
    sta csv_frozen_rows
    sta csv_top_row0
    sta csv_top_row1
    jmp mouse_grid_apply$

mouse_grid_rows1$:
    lda #1
    sta csv_frozen_rows
    sta csv_top_row0
    lda #0
    sta csv_top_row1
    jmp mouse_grid_apply$

mouse_grid_rows2$:
    lda #2
    sta csv_frozen_rows
    sta csv_top_row0
    lda #0
    sta csv_top_row1
    jmp mouse_grid_apply$

mouse_grid_cols0$:
    lda #0
    sta csv_frozen_cols
    sta csv_left_col
    jmp mouse_grid_apply$

mouse_grid_cols1$:
    lda #1
    sta csv_frozen_cols
    sta csv_left_col
    jmp mouse_grid_apply$

mouse_grid_cols2$:
    lda #2
    sta csv_frozen_cols
    sta csv_left_col
    jmp mouse_grid_apply$

mouse_grid_apply$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close

    lda csv_file_loaded
    beq mouse_grid_apply_empty$

    jsr csvprintview
    jsr ensure_current_visible
    jsr highlight_current_cell
    rts

mouse_grid_apply_empty$:
    jsr clear_full_viewport
    jsr draw_menu_bar
    rts



; ------------------------------------------------------------
; mouse_menu_bar_switch
;
; Called only when a menu is already open.
; Carry set   = click handled here.
; Carry clear = let the current menu handler process it.
;
; Clicking another top-level item closes/restores the old menu and
; opens the requested one immediately.  Clicking row 0 anywhere else
; closes the current menu.
; ------------------------------------------------------------
mouse_menu_bar_switch$:
    lda mouse_menu_row
    beq +
    clc
    rts
+
    lda mouse_menu_col

    ; FILE 0..5
    cmp #6
    bcc mouse_menu_switch_file$

    ; EDIT 7..12
    cmp #7
    bcc mouse_menu_switch_close$
    cmp #13
    bcc mouse_menu_switch_edit$

    ; GRID 14..19
    cmp #14
    bcc mouse_menu_switch_close$
    cmp #20
    bcc mouse_menu_switch_grid$

    ; VIEW 21..26
    cmp #21
    bcc mouse_menu_switch_close$
    cmp #27
    bcc mouse_menu_switch_view$

    ; Row 0, but not on a menu title.
    jmp mouse_menu_switch_close$

mouse_menu_switch_file$:
    lda csvmenu_type
    cmp #1
    beq mouse_menu_switch_same$
    jsr mouse_menu_close_restore$
    jsr csvmenu_open_file
    sec
    rts

mouse_menu_switch_edit$:
    lda csvmenu_type
    cmp #3
    beq mouse_menu_switch_same$
    jsr mouse_menu_close_restore$
    jsr csvmenu_open_edit
    sec
    rts

mouse_menu_switch_grid$:
    lda csvmenu_type
    cmp #2
    beq mouse_menu_switch_same$
    jsr mouse_menu_close_restore$
    jsr csvmenu_open_grid
    sec
    rts

mouse_menu_switch_view$:
    lda csvmenu_type
    cmp #4
    beq mouse_menu_switch_same$
    jsr mouse_menu_close_restore$
    jsr csvmenu_open_view
    sec
    rts

mouse_menu_switch_close$:
    jsr mouse_menu_close_restore$
    sec
    rts

mouse_menu_switch_same$:
    ; Same title: let its existing toggle-close code handle the click.
    clc
    rts


; ------------------------------------------------------------
; mouse_menu_point_inside_open
;
; Carry set if the current mouse cell belongs to any visible panel of
; the currently open menu.  Used to distinguish a harmless click in a
; menu from a click in the sheet/background, which must close it.
; ------------------------------------------------------------
mouse_menu_point_inside_open$:
    lda csvmenu_type
    cmp #1
    beq mouse_menu_inside_file$
    cmp #3
    bne +
    jmp mouse_menu_inside_edit$
+
    cmp #2
    bne +
    jmp mouse_menu_inside_grid$
+
    cmp #4
    bne +
    jmp mouse_menu_inside_view$
+
    clc
    rts

mouse_menu_inside_file$:
    ; Root FILE: x 0..13, y 1..5.
    lda mouse_menu_row
    cmp #1
    bcc mouse_menu_inside_file_sub$
    cmp #6
    bcs mouse_menu_inside_file_sub$
    lda mouse_menu_col
    cmp #14
    bcs +
    jmp mouse_menu_inside_yes$
+

mouse_menu_inside_file_sub$:
    lda csvmenu_submenu
    bne +
    jmp mouse_menu_inside_no$
+

    ; Preferences panel is visible for every FILE submenu:
    ; x 14..27, y 4..6.
    lda mouse_menu_row
    cmp #4
    bcc mouse_menu_inside_file_leaf$
    cmp #7
    bcs mouse_menu_inside_file_leaf$
    lda mouse_menu_col
    cmp #14
    bcc mouse_menu_inside_file_leaf$
    cmp #28
    bcs +
    jmp mouse_menu_inside_yes$
+

mouse_menu_inside_file_leaf$:
    lda csvmenu_submenu
    cmp #2
    beq mouse_menu_inside_decoder$
    cmp #3
    beq mouse_menu_inside_delimiter$
    cmp #4
    beq mouse_menu_inside_screen$
    jmp mouse_menu_inside_no$

mouse_menu_inside_decoder$:
    ; x 28..41, y 4..5
    lda mouse_menu_row
    cmp #4
    bcs +
    jmp mouse_menu_inside_no$
+
    cmp #6
    bcc +
    jmp mouse_menu_inside_no$
+
    bra mouse_menu_inside_file_leaf_x$

mouse_menu_inside_delimiter$:
    ; x 28..41, y 5..8
    lda mouse_menu_row
    cmp #5
    bcs +
    jmp mouse_menu_inside_no$
+
    cmp #9
    bcc +
    jmp mouse_menu_inside_no$
+
    bra mouse_menu_inside_file_leaf_x$

mouse_menu_inside_screen$:
    ; x 28..41, y 6..7
    lda mouse_menu_row
    cmp #6
    bcs +
    jmp mouse_menu_inside_no$
+
    cmp #8
    bcc +
    jmp mouse_menu_inside_no$
+

mouse_menu_inside_file_leaf_x$:
    lda mouse_menu_col
    cmp #28
    bcs +
    jmp mouse_menu_inside_no$
+
    cmp #42
    bcs +
    jmp mouse_menu_inside_yes$
+
    jmp mouse_menu_inside_no$

mouse_menu_inside_edit$:
    ; Root EDIT: x 7..20, y 1..7.
    lda mouse_menu_row
    cmp #1
    bcc mouse_menu_inside_edit_sub$
    cmp #8
    bcs mouse_menu_inside_edit_sub$
    lda mouse_menu_col
    cmp #7
    bcc mouse_menu_inside_edit_sub$
    cmp #23
    bcs +
    jmp mouse_menu_inside_yes$
+

mouse_menu_inside_edit_sub$:
    lda csvmenu_submenu
    cmp #1
    beq +
    jmp mouse_menu_inside_no$
+
    ; Fill: x 23..45, y 7..14.
    lda mouse_menu_row
    cmp #7
    bcs +
    jmp mouse_menu_inside_no$
+
    cmp #15
    bcc +
    jmp mouse_menu_inside_no$
+
    lda mouse_menu_col
    cmp #23
    bcs +
    jmp mouse_menu_inside_no$
+
    cmp #46
    bcs +
    jmp mouse_menu_inside_yes$
+
    jmp mouse_menu_inside_no$

mouse_menu_inside_grid$:
    ; Root GRID: x 14..39, y 1..10.
    lda mouse_menu_row
    cmp #1
    bcc mouse_menu_inside_grid_sub$
    cmp #11
    bcs mouse_menu_inside_grid_sub$
    lda mouse_menu_col
    cmp #14
    bcc mouse_menu_inside_grid_sub$
    cmp #40
    bcs +
    jmp mouse_menu_inside_yes$
+

mouse_menu_inside_grid_sub$:
    lda csvmenu_submenu
    cmp #1
    beq mouse_menu_inside_headers$
    cmp #2
    beq mouse_menu_inside_sort$
    jmp mouse_menu_inside_no$

mouse_menu_inside_headers$:
    ; Headers: x 36..59, y 1..7.
    lda mouse_menu_row
    cmp #1
    bcs +
    jmp mouse_menu_inside_no$
+
    cmp #8
    bcc +
    jmp mouse_menu_inside_no$
+
    bra mouse_menu_inside_grid_leaf_x$

mouse_menu_inside_sort$:
    ; Sort: x 36..59, y 10..15.
    lda mouse_menu_row
    cmp #10
    bcs +
    jmp mouse_menu_inside_no$
+
    cmp #16
    bcc +
    jmp mouse_menu_inside_no$
+

mouse_menu_inside_grid_leaf_x$:
    lda mouse_menu_col
    cmp #36
    bcs +
    jmp mouse_menu_inside_no$
+
    cmp #60
    bcs +
    jmp mouse_menu_inside_yes$
+
    jmp mouse_menu_inside_no$

mouse_menu_inside_view$:
    ; VIEW: x 21..40, y 1..3.
    lda mouse_menu_row
    cmp #1
    bcs +
    jmp mouse_menu_inside_no$
+
    cmp #4
    bcc +
    jmp mouse_menu_inside_no$
+
    lda mouse_menu_col
    cmp #21
    bcs +
    jmp mouse_menu_inside_no$
+
    cmp #41
    bcs +
    jmp mouse_menu_inside_yes$
+

mouse_menu_inside_no$:
    clc
    rts
mouse_menu_inside_yes$:
    sec
    rts

; ------------------------------------------------------------
; Nessun menu aperto
; ------------------------------------------------------------
mouse_menu_closed$:
    lda mouse_menu_row
    beq +
    rts
+
    ; FILE: cols 0..5
    lda mouse_menu_col
    cmp #6
    bcs mouse_menu_check_edit$
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_open_file
    rts

mouse_menu_check_edit$:
    ; EDIT: cols 7..12
    lda mouse_menu_col
    cmp #7
    bcc mouse_menu_check_grid$
    cmp #13
    bcs mouse_menu_check_grid$

    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_open_edit
    rts

mouse_menu_check_grid$:
    ; GRID: cols 14..19
    lda mouse_menu_col
    cmp #14
    bcc mouse_menu_check_view$
    cmp #20
    bcs mouse_menu_check_view$

    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_open_grid
    rts

mouse_menu_check_view$:
    ; VIEW: cols 21..26
    lda mouse_menu_col
    cmp #21
    bcc mouse_menu_not_bar_item$
    cmp #27
    bcs mouse_menu_not_bar_item$

    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_open_view
    rts

mouse_menu_not_bar_item$:
    rts

mouse_menu_consume_only$:
    ; Older code deliberately swallowed clicks outside a menu to avoid
    ; spurious events.  mouse_pressed is now edge-triggered, so an actual
    ; outside click should behave like a desktop menu and close it.
    jsr mouse_menu_point_inside_open$
    bcs +
    jmp mouse_menu_close_restore$
+
    lda #1
    sta mouse_menu_consumed
    rts

mouse_menu_close_restore$:
    lda #1
    sta mouse_menu_consumed
    jsr csvmenu_close

    lda csv_file_loaded
    beq mouse_menu_restore_empty$

    jsr csvprintview
    jsr highlight_current_cell
    rts

mouse_menu_restore_empty$:
    jsr clear_full_viewport
    jsr draw_menu_bar
    rts


; ------------------------------------------------------------
; mouse_handle_cell_click
;
; Un nuovo click sinistro seleziona la cella sotto il puntatore.
; Le coordinate mouse sono 640x400, quindi ogni carattere 80x50
; occupa 8x8 pixel.
;
; Ignora:
;   - menu row 0
;   - column header row 1
;   - row-number area x=0..5
;   - colonna video 79, lasciata inutilizzata dal renderer
;   - menu/file browser aperti
;   - area oltre l'ultima riga/colonna del CSV
;
; Tiene conto di:
;   - frozen rows 0..1
;   - frozen cols 0..1
;   - csv_top_row / csv_left_col
;   - larghezze dinamiche delle colonne
; ------------------------------------------------------------

mouse_handle_cell_click:
    ; LMB = selection only. RMB = select and enter Edit when available.
    ; RETURN always enters Edit on the selected cell.
    lda #0
    sta mouse_cell_right_action

    lda mouse_pressed
    bne mouse_cell_click_begin$
    lda mouse_right_pressed
    bne +
    rts
+
    lda #1
    sta mouse_cell_right_action

mouse_cell_click_begin$:
    ; Se questo click e' gia' stato usato dalla barra/tendina menu,
    ; non deve cadere anche sulla cella sottostante.
    lda mouse_menu_consumed
    beq +
    rts
+
    lda csv_file_loaded
    bne +
    rts
+
    lda csvmenu_is_open
    beq +
    rts
+
    lda csvfilebrowser_is_open
    beq +
    rts
+

    ; --------------------------------------------------------
    ; Native text-raster mouse Y:
    ;   80x25 -> 0..199
    ;   80x50 -> 0..399
    ; Text rows are always 8 mouse units high, therefore
    ; row = Y / 8 in both modes.
    ; --------------------------------------------------------
    lda mouse_ypos
    lsr a
    lsr a
    lsr a
    sta mouse_screen_row
    lda mouse_ypos+1
    beq mouse_cell_y_done$
    lda mouse_screen_row
    clc
    adc #32
    sta mouse_screen_row
mouse_cell_y_done$:

    ; IMPORTANT: always reload the calculated row.
    ; On the low half of the screen A otherwise still contains
    ; mouse_ypos+1 (=0), making every click look like MENU_ROW.
    lda mouse_screen_row

    ; row 0 = menu.
    cmp #MENU_ROW
    bne +
    rts
+

    ; row 1 = column header: use the normal X hit-test, but
    ; dispatch the result to whole-column selection.
    cmp #COL_HEADER_ROW
    bne mouse_data_row_click$
    lda #1
    sta mouse_header_col_click
    jmp mouse_x_hit_start$

mouse_data_row_click$:
    lda #0
    sta mouse_header_col_click

    ; IMPORTANT: A was clobbered by lda #0 above.
    ; Reload the physical screen row before converting it
    ; to the CSV data-row index.
    lda mouse_screen_row

    ; data row relativa 0..22.
    sec
    sbc #VIEW_TOP
    sta mouse_data_row
    cmp runtime_view_rows
    bcc +
    rts
+

    ; Prime FROZEN_ROWS righe: numero CSV = data row.
    cmp csv_frozen_rows
    bcs mouse_row_scrollable$

    sta mouse_target_row0
    lda #0
    sta mouse_target_row1
    bra mouse_row_validate$

mouse_row_scrollable$:
    ; Riga assoluta = csv_top_row + (data_row - FROZEN_ROWS).
    sec
    sbc csv_frozen_rows
    clc
    adc csv_top_row0
    sta mouse_target_row0
    lda csv_top_row1
    adc #0
    sta mouse_target_row1

mouse_row_validate$:
    ; target row < csv_rows ?
    lda mouse_target_row1
    cmp csv_rows1
    bcc mouse_row_ok$
    beq mouse_row_check_low$
    jmp mouse_click_done$

mouse_row_check_low$:
    lda mouse_target_row0
    cmp csv_rows0
    bcc mouse_row_ok$
    jmp mouse_click_done$

mouse_row_ok$:
    ; --------------------------------------------------------
    ; Click in the row-number gutter (screen columns 0..5):
    ; select the entire CSV row.
    ; DATA_START_X * 8 = 48 pixels.
    ; --------------------------------------------------------
    lda mouse_xpos+1
    bne mouse_x_hit_start$
    lda mouse_xpos
    cmp #(DATA_START_X * 8)
    bcs mouse_x_hit_start$
    jmp mouse_select_full_row$

mouse_x_hit_start$:
    ; --------------------------------------------------------
    ; Hit-test X direttamente in PIXEL H640, senza convertire
    ; prima la coordinata in colonne carattere.
    ;
    ; Questo evita qualsiasi errore di arrotondamento sui bordi:
    ; ogni cella occupa esattamente get_col_width()*8 pixel.
    ; --------------------------------------------------------

    ; Fuori dall'area dati a sinistra? DATA_START_X * 8 = 48.
    ; On the column-header row this is the top-left corner, currently
    ; intentionally unused.
    lda mouse_xpos+1
    bne mouse_x_not_left$
    lda mouse_xpos
    cmp #(DATA_START_X * 8)
    bcs mouse_x_not_left$
    rts
mouse_x_not_left$:

    ; Colonna video 79 non usata: limite destro = 79*8 = 632 ($0278).
    lda mouse_xpos+1
    cmp #0x02
    bcc mouse_x_inside_right$
    beq +
    jmp mouse_click_done$
+
    lda mouse_xpos
    cmp #0x78
    bcc mouse_x_inside_right$
    jmp mouse_click_done$
mouse_x_inside_right$:

    ; mouse_col_x = DATA_START_X*8, 16 bit.
    lda #0x30
    sta mouse_col_x
    lda #0x00
    sta mouse_col_x_hi

    lda #0
    sta mouse_test_col

mouse_hit_frozen_loop$:
    lda mouse_test_col
    cmp csv_frozen_cols
    beq mouse_hit_scroll_start$

    jsr get_col_width
    sta mouse_test_width

    ; end = start + width*8
    asl a
    asl a
    asl a
    clc
    adc mouse_col_x
    sta mouse_col_end
    lda mouse_col_x_hi
    adc #0
    sta mouse_col_end_hi

    ; mouse < start ? fuori.
    lda mouse_xpos+1
    cmp mouse_col_x_hi
    bcs +
    jmp mouse_click_done$
+
    bne mouse_frozen_check_end$
    lda mouse_xpos
    cmp mouse_col_x
    bcs +
    jmp mouse_click_done$
+

mouse_frozen_check_end$:
    ; mouse < end ? trovata.
    lda mouse_xpos+1
    cmp mouse_col_end_hi
    bcs +
    jmp mouse_col_found$
+
    bne mouse_frozen_next$
    lda mouse_xpos
    cmp mouse_col_end
    bcs +
    jmp mouse_col_found$
+

mouse_frozen_next$:
    lda mouse_col_end
    sta mouse_col_x
    lda mouse_col_end_hi
    sta mouse_col_x_hi
    inc mouse_test_col
    jmp mouse_hit_frozen_loop$

mouse_hit_scroll_start$:
    ; Dopo le frozen, la prima colonna mostrata e' csv_left_col.
    lda csv_left_col
    sta mouse_test_col

mouse_hit_scroll_loop$:
    ; current_col è a 8 bit: se maxcols ha high byte non è possibile
    ; comunque rappresentare oltre 255. Per i CSV correnti maxcols1=0.
    lda csv_maxcols1
    bne mouse_hit_have_col$
    lda mouse_test_col
    cmp csv_maxcols0
    bcc mouse_hit_have_col$
    jmp mouse_click_done$

mouse_hit_have_col$:
    lda mouse_test_col
    jsr get_col_width
    sta mouse_test_width

    ; end = start + width*8
    asl a
    asl a
    asl a
    clc
    adc mouse_col_x
    sta mouse_col_end
    lda mouse_col_x_hi
    adc #0
    sta mouse_col_end_hi

    ; mouse < start ? fuori.
    lda mouse_xpos+1
    cmp mouse_col_x_hi
    bcs +
    jmp mouse_click_done$
+
    bne mouse_scroll_check_end$
    lda mouse_xpos
    cmp mouse_col_x
    bcs +
    jmp mouse_click_done$
+

mouse_scroll_check_end$:
    ; mouse < end ? trovata.
    lda mouse_xpos+1
    cmp mouse_col_end_hi
    bcc mouse_col_found$
    bne mouse_scroll_next$
    lda mouse_xpos
    cmp mouse_col_end
    bcc mouse_col_found$

mouse_scroll_next$:
    lda mouse_col_end
    sta mouse_col_x
    lda mouse_col_end_hi
    sta mouse_col_x_hi

    ; Non oltrepassare x=632 (colonna video 79).
    lda mouse_col_x_hi
    cmp #0x02
    bcc mouse_scroll_inside$
    beq +
    jmp mouse_click_done$
+
    lda mouse_col_x
    cmp #0x78
    bcc mouse_scroll_inside$
    jmp mouse_click_done$

mouse_scroll_inside$:
    lda mouse_test_col
    cmp #0xff
    bne mouse_scroll_can_inc$
    jmp mouse_click_done$
mouse_scroll_can_inc$:
    inc mouse_test_col
    jmp mouse_hit_scroll_loop$

mouse_col_found$:
    ; mouse_test_col e' gia' la colonna corretta.
    lda mouse_header_col_click
    beq mouse_col_normal_found$

    lda mouse_test_col
    sta mouse_target_col
    jmp mouse_select_full_column$

mouse_col_normal_found$:
    ; L'indice CSV non viene più corretto con +/-1: l'allineamento
    ; viene fatto una sola volta sulla coordinata X dello schermo.
    lda mouse_test_col
    jmp mouse_col_store$

; ------------------------------------------------------------
; Header selection
; ------------------------------------------------------------

mouse_select_full_row$:
    ; mouse_target_row0/1 was resolved from the clicked physical row.
    ; Copy it explicitly to current selection.
    lda mouse_target_row0
    sta csv_current_row0
    lda mouse_target_row1
    sta csv_current_row1

    ; Keep current column if it exists, otherwise use column 0.
    lda csv_maxcols1
    bne mouse_row_keep_col$
    lda csv_current_col
    cmp csv_maxcols0
    bcc mouse_row_keep_col$
    lda #0
    sta csv_current_col

mouse_row_keep_col$:
    jsr csv_multiselect_select_full_row
    jsr csvprintview
    jsr csv_multiselect_highlight_all

    lda #0
    sta csv_double_timer
    sta csv_double_valid
    rts


mouse_select_full_column$:
    lda mouse_target_col
    sta csv_current_col

    ; Keep current row as the active cell row. The selection bounds,
    ; however, cover the complete CSV from row 0 to rows-1.
    jsr csv_multiselect_select_full_column
    jsr csvprintview
    jsr csv_multiselect_highlight_all

    lda #0
    sta csv_double_timer
    sta csv_double_valid
    rts


mouse_col_store$:
    sta mouse_target_col

    ; SHIFT immediato dal registro modifier del MEGA65.
    ; Left Shift = bit 0, Right Shift = bit 1.
    lda MODKEYS_IMM
    and #MODKEY_SHIFT
    bne mouse_rectselect_shift$

    ; --------------------------------------------------------
    ; Click normale:
    ; nuova ancora e rettangolo 1x1.
    ; --------------------------------------------------------
    lda mouse_target_row0
    sta csv_current_row0
    lda mouse_target_row1
    sta csv_current_row1
    lda mouse_target_col
    sta csv_current_col

    jsr csv_multiselect_reset_current

    ; Ridisegna pulito: elimina qualsiasi vecchio rettangolo.
    jsr csvprintview
    jsr csv_multiselect_highlight_all
    jmp mouse_selection_done$

    ; --------------------------------------------------------
    ; SHIFT + click:
    ; il primo click normale resta l'ancora.
    ; Il secondo estremo e' la cella cliccata ora.
    ; Seleziona tutto il rettangolo compreso fra i due estremi.
    ; --------------------------------------------------------
mouse_rectselect_shift$:
    lda mouse_target_row0
    sta csv_current_row0
    lda mouse_target_row1
    sta csv_current_row1
    lda mouse_target_col
    sta csv_current_col

    jsr csv_multiselect_set_rectangle

    ; Redraw pulito + evidenziazione dell'intero rettangolo.
    jsr csvprintview
    jsr csv_multiselect_highlight_all

    ; SHIFT+click non deve essere interpretato come doppio click.
    lda #0
    sta csv_double_timer
    sta csv_double_valid
    rts

mouse_selection_done$:
    ; Double-click disabled by design.
    lda #0
    sta csv_double_timer
    sta csv_double_valid

    ; Only the right button enters Edit mode.
    lda mouse_cell_right_action
    beq mouse_click_done$

    lda #1
    sta csv_edit_user_entry
    jsr csv_edit_begin
    rts

mouse_click_done$:
    ; A click on the sheet dismisses Find/Replace. SEARCH.PRG does not
    ; implement the View split engine, so return to the main KnockCSV
    ; viewer after preserving the newly selected cell and view state.
    lda csv_find_mode
    beq mouse_click_return$
    jmp csv_chain_search_return

mouse_click_return$:
    rts



; ------------------------------------------------------------
; csv_doubleclick_tick
;
; Decrementa csv_double_timer una sola volta per frame.
; Il wrap del raster low byte viene usato quando il valore corrente
; diventa minore del precedente e' iniziato un nuovo frame.
; ------------------------------------------------------------

csv_doubleclick_tick:
    lda RASTER
    cmp csv_double_last_raster
    bcs csv_double_tick_store$

    ; Raster wrap.
    lda csv_double_timer
    beq csv_double_tick_store$
    dec csv_double_timer
    bne csv_double_tick_store$

    ; Finestra scaduta.
    lda #0
    sta csv_double_valid

csv_double_tick_store$:
    lda RASTER
    sta csv_double_last_raster
    rts


; ------------------------------------------------------------
; ensure_current_visible
;
; Se current_col non entra interamente nello spazio 0..78,
; incrementa csv_left_col finche' diventa visibile.
;
; OUT:
;   hscroll_changed = 0/1
; ------------------------------------------------------------

ensure_current_visible:
    lda #0x00
    sta hscroll_changed

    ; Le colonne congelate sono sempre visibili.
    lda csv_current_col
    cmp csv_frozen_cols
    bcs ensure_scrollable$
    rts

ensure_scrollable$:
    ; --------------------------------------------------------
    ; LEFT VISIBILITY
    ;
    ; csv_left_col e' la prima colonna della parte scrollabile.
    ; Finora questa routine sapeva soltanto scorrere verso destra.
    ; Find/Find Next puo' invece saltare direttamente ad una colonna
    ; precedente (tipicamente colonna 0 della riga successiva).
    ;
    ; Se current_col è a sinistra di left_col, il riallineamento è immediato
    ; la viewport prima di calcolare la geometria video.
    ; --------------------------------------------------------
    lda csv_current_col
    cmp csv_left_col
    bcs ensure_loop$

    sta csv_left_col
    lda #0x01
    sta hscroll_changed

ensure_loop$:
    jsr calc_current_cell_geometry

    ; current_cell_x e' una X fisica.
    ; La cella deve terminare entro colonna 78.
    clc
    lda current_cell_x
    adc current_cell_width
    cmp #80
    bcc ensure_done$
    beq ensure_done$

    inc csv_left_col
    lda #0x01
    sta hscroll_changed
    jmp ensure_loop$

ensure_done$:
    rts


; ------------------------------------------------------------
; STEP 2: scrolling software a 28 bit
;
; Nessun indirizzo screen hardcoded.
; SCRNPTR viene letto dai registri VIC-IV:
;
;   $D060  byte 0
;   $D061  byte 1
;   $D062  byte 2
;   $D063  byte 3
;
; I puntatori scroll_src / scroll_dst sono quad pointer in
; zero page e vengono usati con:
;
;   lda [scroll_src],z
;   sta [scroll_dst],z
;
; VIEW_ROWS = 24 + menu row 0, 80 caratteri per riga.
; ------------------------------------------------------------

plot        .equ 0xfff0

SCRNPTR0    .equ 0xd060
SCRNPTR1    .equ 0xd061
SCRNPTR2    .equ 0xd062
SCRNPTR3    .equ 0xd063

; MEGA65 Colour RAM, 1 byte per text cell.
; Low nibble = colour, high nibble = text attributes
COLORRAM0   .equ 0x00
COLORRAM1   .equ 0x00
COLORRAM2   .equ 0xf8
COLORRAM3   .equ 0x0f

ROW_BYTES   .equ 160
COLOR_ROW_BYTES .equ 160


; ------------------------------------------------------------
; screen_getptr
;
; Legge il puntatore corrente della screen RAM.
;
; OUT:
;   screen_base0..3
; ------------------------------------------------------------

screen_getptr:
    lda SCRNPTR0
    sta screen_base0

    lda SCRNPTR1
    sta screen_base1

    lda SCRNPTR2
    sta screen_base2

    lda SCRNPTR3
    sta screen_base3

    rts


; ------------------------------------------------------------
; copy_screen_base_to_dst
; ------------------------------------------------------------

copy_screen_base_to_dst:
    lda screen_base0
    sta scroll_dst0

    lda screen_base1
    sta scroll_dst1

    lda screen_base2
    sta scroll_dst2

    lda screen_base3
    sta scroll_dst3

    rts


; ------------------------------------------------------------
; copy_screen_base_to_src
; ------------------------------------------------------------

copy_screen_base_to_src:
    lda screen_base0
    sta scroll_src0

    lda screen_base1
    sta scroll_src1

    lda screen_base2
    sta scroll_src2

    lda screen_base3
    sta scroll_src3

    rts


; ------------------------------------------------------------
; add80_src
; ------------------------------------------------------------

add80_src:
    clc

    lda scroll_src0
    adc #ROW_BYTES
    sta scroll_src0

    lda scroll_src1
    adc #0x00
    sta scroll_src1

    lda scroll_src2
    adc #0x00
    sta scroll_src2

    lda scroll_src3
    adc #0x00
    sta scroll_src3

    rts


; ------------------------------------------------------------
; add80_dst
; ------------------------------------------------------------

add80_dst:
    clc

    lda scroll_dst0
    adc #ROW_BYTES
    sta scroll_dst0

    lda scroll_dst1
    adc #0x00
    sta scroll_dst1

    lda scroll_dst2
    adc #0x00
    sta scroll_dst2

    lda scroll_dst3
    adc #0x00
    sta scroll_dst3

    rts


; ------------------------------------------------------------
; sub80_src
; ------------------------------------------------------------

sub80_src:
    sec

    lda scroll_src0
    sbc #ROW_BYTES
    sta scroll_src0

    lda scroll_src1
    sbc #0x00
    sta scroll_src1

    lda scroll_src2
    sbc #0x00
    sta scroll_src2

    lda scroll_src3
    sbc #0x00
    sta scroll_src3

    rts


; ------------------------------------------------------------
; sub80_dst
; ------------------------------------------------------------

sub80_dst:
    sec

    lda scroll_dst0
    sbc #ROW_BYTES
    sta scroll_dst0

    lda scroll_dst1
    sbc #0x00
    sta scroll_dst1

    lda scroll_dst2
    sbc #0x00
    sta scroll_dst2

    lda scroll_dst3
    sbc #0x00
    sta scroll_dst3

    rts


; ------------------------------------------------------------
; copy_row
;
; Copia 80 byte:
;   [scroll_src] -> [scroll_dst]
; ------------------------------------------------------------

copy_row:
    ldz #0x00

copy_row_loop$:
    lda [scroll_src0],z
    sta [scroll_dst0],z

    inz
    cpz #ROW_BYTES
    bne copy_row_loop$

    rts


; ------------------------------------------------------------
; clear_dst_row
;
; Riempie la riga puntata da scroll_dst con screen-code SPACE.
; ------------------------------------------------------------

clear_dst_row:
    ldz #0
clear_row_loop$:
    lda #0x20
    sta [scroll_dst0],z
    inz
    lda #0
    sta [scroll_dst0],z
    inz
    cpz #ROW_BYTES
    bne clear_row_loop$
    rts


; ------------------------------------------------------------
; scroll_down_view
;
; La viewport deve salire:
;
;   video row 1  -> video row 0
;   ...
;   ultima video row -> video penultima row
;
; Poi si pulisce ultima row e si stampa soltanto la nuova
; riga CSV entrante.
;
; csv_top_row e' gia' stato incrementato da down$.
; ------------------------------------------------------------

scroll_down_view:
    ; --------------------------------------------------------
    ; Scroll verticale veloce SOLO dell'area non frozen.
    ;
    ; Video:
    ;   row 0     menu
    ;   row 1     numeri colonne
    ;   row 2..3  due righe CSV frozen
    ;   row 4..24 area scrollabile (21 righe)
    ;
    ; DOWN:
    ;   5 -> 4
    ;   6 -> 5
    ;   ...
    ;   24 -> 23
    ; poi ridisegna soltanto row 49.
    ; --------------------------------------------------------

    jsr screen_getptr

    ; dst = screen row SCROLL_TOP (=4)
    jsr calc_runtime_scroll_layout
    jsr copy_screen_base_to_dst
    lda runtime_scroll_top
    sta scroll_seek

scroll_down_seek_dst$:
    lda scroll_seek
    beq scroll_down_dst_ready$
    jsr add80_dst
    dec scroll_seek
    jmp scroll_down_seek_dst$

scroll_down_dst_ready$:

    ; src = screen row SCROLL_TOP+1 (=5)
    jsr copy_screen_base_to_src
    lda runtime_scroll_top
    clc
    adc #1
    sta scroll_seek

scroll_down_seek_src$:
    lda scroll_seek
    beq scroll_down_src_ready$
    jsr add80_src
    dec scroll_seek
    jmp scroll_down_seek_src$

scroll_down_src_ready$:

    ; Copia 20 righe: 5..24 -> 4..23
    lda runtime_scroll_rows
    sec
    sbc #1
    sta scroll_rows

scroll_down_copy$:
    jsr copy_row
    jsr add80_src
    jsr add80_dst

    dec scroll_rows
    bne scroll_down_copy$

    ; dst ora punta alla row 49.
    jsr clear_dst_row

    ; csv_row = csv_top_row + SCROLL_ROWS - 1
    clc
    lda runtime_scroll_rows
    sec
    sbc #1
    clc
    adc csv_top_row0
    sta csv_row0

    lda csv_top_row1
    adc #0
    sta csv_row1

    ; Stampa soltanto la nuova riga entrante in basso.
    ldx runtime_last_row
    ldy #DATA_START_X
    clc
    jsr seam_plot

    jsr seam_apply_cell_style
    jsr csvprintrow
    jsr draw_scrolling_row_number
    jsr csv_multiselect_highlight_all

    rts


; ------------------------------------------------------------

scroll_up_view:
    jsr csvprintview
    rts

    ; --------------------------------------------------------
    ; Scroll verticale veloce verso il basso dell'area
    ; non frozen.
    ;
    ; UP:
    ;   23 -> 24
    ;   22 -> 23
    ;   ...
    ;   4  -> 5
    ; poi ridisegna soltanto row 4.
    ;
    ; La copia procede dal basso verso l'alto per evitare
    ; di sovrascrivere la sorgente.
    ; --------------------------------------------------------

    jsr screen_getptr
    jsr calc_runtime_scroll_layout

    ; src = last scroll row - 1
    ;     = SCROLL_TOP + SCROLL_ROWS - 2
    jsr copy_screen_base_to_src
    lda runtime_replace_row
    sta scroll_seek

scroll_up_seek_src$:
    lda scroll_seek
    beq scroll_up_src_ready$
    jsr add80_src
    dec scroll_seek
    jmp scroll_up_seek_src$

scroll_up_src_ready$:

    ; dst = screen row 49
    ;     = SCROLL_TOP + SCROLL_ROWS - 1
    jsr copy_screen_base_to_dst
    lda runtime_last_row
    sta scroll_seek

scroll_up_seek_dst$:
    lda scroll_seek
    beq scroll_up_dst_ready$
    jsr add80_dst
    dec scroll_seek
    jmp scroll_up_seek_dst$

scroll_up_dst_ready$:

    ; Copia 20 righe dal basso verso l'alto.
    lda runtime_scroll_rows
    sec
    sbc #1
    sta scroll_rows

scroll_up_copy$:
    jsr copy_row
    jsr sub80_src
    jsr sub80_dst

    dec scroll_rows
    bne scroll_up_copy$

    ; Dopo 20 iterazioni dst e' alla row 4.
    jsr clear_dst_row

    ; La nuova riga superiore e' csv_top_row.
    lda csv_top_row0
    sta csv_row0
    lda csv_top_row1
    sta csv_row1

    ldx runtime_scroll_top
    ldy #DATA_START_X
    clc
    jsr seam_plot

    jsr seam_apply_cell_style
    jsr csvprintrow
    jsr draw_scrolling_row_number
    jsr csv_multiselect_highlight_all

    rts


; ------------------------------------------------------------


; ------------------------------------------------------------
; Runtime 80x25 / 80x50 geometry.
; ------------------------------------------------------------
csv_update_screen_layout:
    lda csv_screen_mode
    bne csv_layout_50$

csv_layout_25$:
    lda #25
    sta runtime_screen_rows
    lda #23
    sta runtime_view_rows
    lda #24
    sta runtime_last_row
    lda #23
    sta runtime_replace_row
    rts

csv_layout_50$:
    lda #50
    sta runtime_screen_rows
    lda #48
    sta runtime_view_rows
    lda #49
    sta runtime_last_row
    lda #48
    sta runtime_replace_row
    rts


calc_runtime_scroll_layout:
    lda csv_frozen_rows
    clc
    adc #VIEW_TOP
    sta runtime_scroll_top

    lda runtime_view_rows
    sec
    sbc csv_frozen_rows
    sta runtime_scroll_rows
    rts


calc_scroll_index:
    sec
    lda csv_current_row0
    sbc csv_top_row0
    sta current_screen_row
    lda csv_current_row1
    sbc csv_top_row1
    sta current_screen_row_hi
    rts


calc_current_screen_row:
    ; Righe frozen -> relative data rows 0 e 1.
    lda csv_current_row1
    bne calc_screen_scroll$
    lda csv_current_row0
    cmp csv_frozen_rows
    bcs calc_screen_scroll$

    sta current_screen_row
    lda #0
    sta current_screen_row_hi
    rts

calc_screen_scroll$:
    sec
    lda csv_current_row0
    sbc csv_top_row0
    clc
    adc csv_frozen_rows
    sta current_screen_row
    lda csv_current_row1
    sbc csv_top_row1
    adc #0
    sta current_screen_row_hi
    rts


; ------------------------------------------------------------
; get_col_width
;
; INPUT:
;   A = numero colonna (0..255)
;
; OUTPUT:
;   A = larghezza visuale clamp(raw+1, 4, 24)
;
; raw e' letto direttamente da:
;   $08200000 + colonna
; ------------------------------------------------------------

get_col_width:
    sta colwidth_ptr0

    lda #0x00
    sta colwidth_ptr1

    lda #0x20
    sta colwidth_ptr2

    lda #0x08
    sta colwidth_ptr3

    ldz #0x00
    lda [colwidth_ptr0],z

    ; raw 0..2 -> minimo 4
    cmp #0x03
    bcs width_not_min$

    lda #MIN_COL_WIDTH
    rts

width_not_min$:
    ; raw >= 23 -> raw+1 sarebbe >=24: clamp 24
    cmp #(MAX_COL_WIDTH - 1)
    bcc width_add_one$

    lda #MAX_COL_WIDTH
    rts

width_add_one$:
    clc
    adc #0x01
    rts


; ------------------------------------------------------------
; calc_scroll_start_x
;
; OUT:
;   scroll_start_x = DATA_START_X + width(col0) + width(col1)
; ------------------------------------------------------------

calc_scroll_start_x:
    ; Keep the row-number gutter fixed; only real frozen CSV columns
    ; contribute to the horizontal redraw start position.
    lda #DATA_START_X
    sta scroll_start_x

    lda #0
    sta geometry_col

calc_scroll_start_frozen_loop$:
    lda geometry_col
    cmp csv_frozen_cols
    bcs calc_scroll_start_done$

    lda geometry_col
    jsr get_col_width
    clc
    adc scroll_start_x
    sta scroll_start_x

    inc geometry_col
    jmp calc_scroll_start_frozen_loop$

calc_scroll_start_done$:
    rts


; ------------------------------------------------------------
; clear_scrollable_screen_row
;
; INPUT:
;   A = physical video row
;
; Pulisce soltanto da scroll_start_x a colonna 78.
; Non tocca row numbers o colonne frozen.
; ------------------------------------------------------------

clear_scrollable_screen_row:
    ; A = physical screen row.
    sta hredraw_row

    jsr seam_apply_cell_style

    ldx hredraw_row
    ldy scroll_start_x
    clc
    jsr seam_plot

    lda #79
    sec
    sbc scroll_start_x
    sta hclear_len

clear_hrow_loop$:
    lda #' '
    jsr seam_bsout
    dec hclear_len
    bne clear_hrow_loop$
    rts


; ------------------------------------------------------------
; csvredraw_horizontal
;
; Ridisegna solo l'area scrollabile:
; - frozen CSV rows 0..1
; - visible scrolling rows
; - column-number header
;
; Non tocca:
; - menu row
; - row numbers
; - frozen columns 0..1
; ------------------------------------------------------------

csvredraw_horizontal:
    jsr calc_scroll_start_x

    ; --------------------------------------------------------
    ; Frozen rows 0..1
    ; --------------------------------------------------------
    lda #0
    sta csv_row0
    sta csv_row1
    sta hredraw_index

hredraw_frozen_loop$:
    lda hredraw_index
    cmp csv_frozen_rows
    bcs hredraw_scroll_start$

    ; Fine CSV?
    lda csv_row1
    cmp csv_rows1
    bcc hredraw_frozen_print$
    beq +
    jmp hredraw_done$
+
    lda csv_row0
    cmp csv_rows0
    bcc +
    jmp hredraw_done$
+

hredraw_frozen_print$:
    lda hredraw_index
    clc
    adc #VIEW_TOP
    sta hredraw_row

    lda hredraw_row
    jsr clear_scrollable_screen_row

    ldx hredraw_row
    ldy scroll_start_x
    clc
    jsr seam_plot
    jsr seam_apply_cell_style
    jsr csvprintrow_scrollable

    inc csv_row0
    bne +
    inc csv_row1
+
    inc hredraw_index
    jmp hredraw_frozen_loop$


    ; --------------------------------------------------------
    ; Scrollable rows
    ; --------------------------------------------------------
hredraw_scroll_start$:
    lda csv_top_row0
    sta csv_row0
    lda csv_top_row1
    sta csv_row1

    lda #0
    sta hredraw_index

hredraw_scroll_loop$:
    jsr calc_runtime_scroll_layout
    lda hredraw_index
    cmp runtime_scroll_rows
    bcc +
    jmp hredraw_done$
+

    ; Fine CSV?
    lda csv_row1
    cmp csv_rows1
    bcc hredraw_scroll_print$
    beq +
    jmp hredraw_done$
+
    lda csv_row0
    cmp csv_rows0
    bcc +
    jmp hredraw_done$
+

hredraw_scroll_print$:
    lda hredraw_index
    clc
    adc runtime_scroll_top
    sta hredraw_row

    lda hredraw_row
    jsr clear_scrollable_screen_row

    ldx hredraw_row
    ldy scroll_start_x
    clc
    jsr seam_plot
    jsr seam_apply_cell_style
    jsr csvprintrow_scrollable

    inc csv_row0
    bne +
    inc csv_row1
+
    inc hredraw_index
    jmp hredraw_scroll_loop$

hredraw_done$:
    ; Aggiorna la riga dei numeri di colonna.
    jsr draw_column_header
    jsr csv_multiselect_highlight_all
    rts


; ------------------------------------------------------------
; calc_current_cell_geometry
;
; OUT:
;   current_cell_x
;   current_cell_width
; ------------------------------------------------------------

calc_current_cell_geometry:
    lda #DATA_START_X
    sta current_cell_x

    ; --------------------------------------------------------
    ; Frozen columns 0..1.
    ; --------------------------------------------------------
    lda csv_current_col
    cmp csv_frozen_cols
    bcs geometry_scrollable$

    lda #0
    sta geometry_col

geometry_frozen_loop$:
    lda geometry_col
    cmp csv_current_col
    beq geometry_current$

    jsr get_col_width
    clc
    adc current_cell_x
    sta current_cell_x

    inc geometry_col
    jmp geometry_frozen_loop$


    ; --------------------------------------------------------
    ; Scrollable columns:
    ; X = DATA_START_X + widths(frozen 0..1)
    ;     + widths(csv_left_col .. current_col-1)
    ; --------------------------------------------------------
geometry_scrollable$:
    lda #0
    sta geometry_col

geometry_add_frozen$:
    lda geometry_col
    cmp csv_frozen_cols
    beq geometry_start_scroll$

    jsr get_col_width
    clc
    adc current_cell_x
    sta current_cell_x

    inc geometry_col
    jmp geometry_add_frozen$

geometry_start_scroll$:
    lda csv_left_col
    sta geometry_col

geometry_scroll_loop$:
    lda geometry_col
    cmp csv_current_col
    beq geometry_current$

    jsr get_col_width
    clc
    adc current_cell_x
    sta current_cell_x

    inc geometry_col
    jmp geometry_scroll_loop$

geometry_current$:
    lda csv_current_col
    jsr get_col_width
    sta current_cell_width
    rts


; ------------------------------------------------------------
; set_current_cell_ptr
;
; scroll_dst = SCRNPTR
;            + current_screen_row * 80
;            + current_cell_x
; ------------------------------------------------------------

set_current_cell_ptr:
    jsr screen_getptr
    jsr copy_screen_base_to_dst

    ; Salta menu + intestazione colonne.
    ; La prima cella CSV parte da video row 2.
    jsr add80_dst
    jsr add80_dst

    jsr calc_current_screen_row
    jsr calc_current_cell_geometry

    lda current_screen_row
    sta highlight_rows

cell_seek_row$:
    lda highlight_rows
    beq cell_seek_x$

    jsr add80_dst
    dec highlight_rows
    jmp cell_seek_row$

cell_seek_x$:
    lda current_cell_x
    asl a
    sta seam_x2_temp
    clc
    lda scroll_dst0
    adc seam_x2_temp
    sta scroll_dst0

    lda scroll_dst1
    adc #0x00
    sta scroll_dst1

    lda scroll_dst2
    adc #0x00
    sta scroll_dst2

    lda scroll_dst3
    adc #0x00
    sta scroll_dst3

    rts


; ============================================================
; MULTI CELL SELECTION
;
; Up to MULTISELECT_MAX cells are stored as absolute CSV coordinates.
; Click          -> selection becomes one cell.
; SHIFT + click  -> adds cell to selection.
;
; The list is also used to restore highlights after redraw/scroll.
; ============================================================

csv_multiselect_reset_current:
    ; Selezione attiva.
    lda #1
    sta csv_multiselect_count
    lda #0
    sta csv_multiselect_mode

    ; Ancora = cella corrente.
    lda csv_current_row0
    sta csv_multiselect_anchor_row0
    sta csv_multiselect_min_row0
    sta csv_multiselect_max_row0

    lda csv_current_row1
    sta csv_multiselect_anchor_row1
    sta csv_multiselect_min_row1
    sta csv_multiselect_max_row1

    lda csv_current_col
    sta csv_multiselect_anchor_col
    sta csv_multiselect_min_col
    sta csv_multiselect_max_col
    rts


; ------------------------------------------------------------
; csv_multiselect_select_full_row
; Current row is selected from column 0 through the last CSV column.
; mode 1 = complete row.
; ------------------------------------------------------------
csv_multiselect_select_full_row:
    lda #1
    sta csv_multiselect_count
    sta csv_multiselect_mode

    lda csv_current_row0
    sta csv_multiselect_anchor_row0
    sta csv_multiselect_min_row0
    sta csv_multiselect_max_row0
    lda csv_current_row1
    sta csv_multiselect_anchor_row1
    sta csv_multiselect_min_row1
    sta csv_multiselect_max_row1

    lda csv_current_col
    sta csv_multiselect_anchor_col

    lda #0
    sta csv_multiselect_min_col

    ; current_col is 8-bit, so clamp files with >256 columns to 255.
    lda csv_maxcols1
    beq csv_full_row_maxcol8$
    lda #0xff
    sta csv_multiselect_max_col
    rts

csv_full_row_maxcol8$:
    lda csv_maxcols0
    beq csv_full_row_no_cols$
    sec
    sbc #1
    sta csv_multiselect_max_col
    rts

csv_full_row_no_cols$:
    lda #0
    sta csv_multiselect_max_col
    rts


; ------------------------------------------------------------
; csv_multiselect_select_full_column
; Current column is selected from row 0 through rows-1.
; mode 2 = complete column.
; ------------------------------------------------------------
csv_multiselect_select_full_column:
    lda #1
    sta csv_multiselect_count
    lda #2
    sta csv_multiselect_mode

    lda csv_current_row0
    sta csv_multiselect_anchor_row0
    lda csv_current_row1
    sta csv_multiselect_anchor_row1

    lda #0
    sta csv_multiselect_min_row0
    sta csv_multiselect_min_row1

    ; max row = csv_rows - 1
    sec
    lda csv_rows0
    sbc #1
    sta csv_multiselect_max_row0
    lda csv_rows1
    sbc #0
    sta csv_multiselect_max_row1

    lda csv_current_col
    sta csv_multiselect_anchor_col
    sta csv_multiselect_min_col
    sta csv_multiselect_max_col
    rts


; ------------------------------------------------------------
; csv_multiselect_set_rectangle
;
; Anchor gia' salvata dal click normale.
; Current = secondo estremo.
; Calcola min/max inclusivi.
; ------------------------------------------------------------
csv_multiselect_set_rectangle:
    lda #1
    sta csv_multiselect_count
    lda #0
    sta csv_multiselect_mode

    ; ----- rows: compare current with anchor, 16 bit -----
    lda csv_current_row1
    cmp csv_multiselect_anchor_row1
    bcc rect_current_row_lower$
    bne rect_anchor_row_lower$

    lda csv_current_row0
    cmp csv_multiselect_anchor_row0
    bcc rect_current_row_lower$

rect_anchor_row_lower$:
    lda csv_multiselect_anchor_row0
    sta csv_multiselect_min_row0
    lda csv_multiselect_anchor_row1
    sta csv_multiselect_min_row1

    lda csv_current_row0
    sta csv_multiselect_max_row0
    lda csv_current_row1
    sta csv_multiselect_max_row1
    jmp rect_rows_done$

rect_current_row_lower$:
    lda csv_current_row0
    sta csv_multiselect_min_row0
    lda csv_current_row1
    sta csv_multiselect_min_row1

    lda csv_multiselect_anchor_row0
    sta csv_multiselect_max_row0
    lda csv_multiselect_anchor_row1
    sta csv_multiselect_max_row1

rect_rows_done$:
    ; ----- columns: 8 bit -----
    lda csv_current_col
    cmp csv_multiselect_anchor_col
    bcc rect_current_col_lower$

    lda csv_multiselect_anchor_col
    sta csv_multiselect_min_col
    lda csv_current_col
    sta csv_multiselect_max_col
    rts

rect_current_col_lower$:
    lda csv_current_col
    sta csv_multiselect_min_col
    lda csv_multiselect_anchor_col
    sta csv_multiselect_max_col
    rts


; A=1 if current cell is visible, A=0 otherwise.
csv_multiselect_current_visible:
    ; ----- row -----
    lda csv_current_row1
    bne csv_multiselect_row_scroll$
    lda csv_current_row0
    cmp csv_frozen_rows
    bcc csv_multiselect_row_ok$

csv_multiselect_row_scroll$:
    ; current >= top ?
    lda csv_current_row1
    cmp csv_top_row1
    bcc csv_multiselect_not_visible$
    bne csv_multiselect_row_delta$
    lda csv_current_row0
    cmp csv_top_row0
    bcc csv_multiselect_not_visible$

csv_multiselect_row_delta$:
    sec
    lda csv_current_row0
    sbc csv_top_row0
    sta csv_multiselect_delta0
    lda csv_current_row1
    sbc csv_top_row1
    bne csv_multiselect_not_visible$

    jsr calc_runtime_scroll_layout
    lda csv_multiselect_delta0
    cmp runtime_scroll_rows
    bcs csv_multiselect_not_visible$

csv_multiselect_row_ok$:
    ; ----- column -----
    lda csv_current_col
    cmp csv_frozen_cols
    bcc csv_multiselect_col_ok$

    cmp csv_left_col
    bcc csv_multiselect_not_visible$

csv_multiselect_col_ok$:
    jsr calc_current_cell_geometry

    ; end X must remain inside the usable 80-column line.
    clc
    lda current_cell_x
    adc current_cell_width
    cmp #80
    bcc csv_multiselect_visible$
    beq csv_multiselect_visible$

csv_multiselect_not_visible$:
    lda #0
    rts

csv_multiselect_visible$:
    lda #1
    rts


csv_multiselect_save_current:
    lda csv_current_row0
    sta csv_multiselect_save_row0
    lda csv_current_row1
    sta csv_multiselect_save_row1
    lda csv_current_col
    sta csv_multiselect_save_col
    rts

csv_multiselect_restore_current:
    lda csv_multiselect_save_row0
    sta csv_current_row0
    lda csv_multiselect_save_row1
    sta csv_current_row1
    lda csv_multiselect_save_col
    sta csv_current_col
    rts


; ------------------------------------------------------------
; Evidenzia tutte le celle del rettangolo attualmente visibili.
; I bounds sono assoluti CSV e inclusivi.
; ------------------------------------------------------------
csv_multiselect_highlight_all:
    lda csv_multiselect_count
    bne +
    rts
+
    lda csv_multiselect_mode
    beq csv_multiselect_highlight_mode0$
    cmp #1
    beq csv_multiselect_highlight_full_row$
    jmp csv_multiselect_highlight_full_col$

csv_multiselect_highlight_mode0$:
    jmp csv_multiselect_highlight_mode0


; ------------------------------------------------------------
; Whole-row selection.
; Only the selected row is highlighted, but across all 80
; physical screen columns. No per-column loop required.
; ------------------------------------------------------------
csv_multiselect_highlight_full_row$:
    jsr csv_multiselect_save_current

    ; selected row = min row = max row
    lda csv_multiselect_min_row0
    sta csv_current_row0
    lda csv_multiselect_min_row1
    sta csv_current_row1

    ; Is row visible? Use column 0 temporarily because it is frozen.
    lda #0
    sta csv_current_col
    jsr csv_multiselect_current_visible
    beq csv_multi_full_row_done$

    jsr calc_current_screen_row
    jsr seam_apply_selection_style

    lda current_screen_row
    clc
    adc #VIEW_TOP
    ldx #0
    ldy #80
    jsr seam_fill_attr_span

    jsr seam_apply_cell_style

csv_multi_full_row_done$:
    jsr csv_multiselect_restore_current
    rts


; ------------------------------------------------------------
; Whole-column selection.
; Iterate only rows currently visible, not all rows in CSV.
; ------------------------------------------------------------
csv_multiselect_highlight_full_col$:
    jsr csv_multiselect_save_current

    ; frozen rows 0..frozen_rows-1
    lda #0
    sta csv_multiselect_vis_row0
    sta csv_multiselect_vis_row1

csv_multi_col_frozen_loop$:
    lda csv_multiselect_vis_row1
    bne csv_multi_col_scroll_start$
    lda csv_multiselect_vis_row0
    cmp csv_frozen_rows
    bcs csv_multi_col_scroll_start$

    lda csv_multiselect_vis_row1
    cmp csv_rows1
    bcc csv_multi_col_frozen_draw$
    bne csv_multi_col_scroll_start$
    lda csv_multiselect_vis_row0
    cmp csv_rows0
    bcs csv_multi_col_scroll_start$

csv_multi_col_frozen_draw$:
    lda csv_multiselect_vis_row0
    sta csv_current_row0
    lda csv_multiselect_vis_row1
    sta csv_current_row1
    lda csv_multiselect_min_col
    sta csv_current_col

    jsr csv_multiselect_current_visible
    beq csv_multi_col_frozen_next$
    jsr highlight_current_cell

csv_multi_col_frozen_next$:
    inc csv_multiselect_vis_row0
    bne csv_multi_col_frozen_loop$
    inc csv_multiselect_vis_row1
    jmp csv_multi_col_frozen_loop$


csv_multi_col_scroll_start$:
    lda csv_top_row0
    sta csv_multiselect_vis_row0
    lda csv_top_row1
    sta csv_multiselect_vis_row1

    jsr calc_runtime_scroll_layout
    lda runtime_scroll_rows
    sta csv_multiselect_vis_count

csv_multi_col_scroll_loop$:
    lda csv_multiselect_vis_count
    beq csv_multi_col_done$

    ; end of CSV?
    lda csv_multiselect_vis_row1
    cmp csv_rows1
    bcc csv_multi_col_scroll_draw$
    bne csv_multi_col_done$
    lda csv_multiselect_vis_row0
    cmp csv_rows0
    bcs csv_multi_col_done$

csv_multi_col_scroll_draw$:
    lda csv_multiselect_vis_row0
    sta csv_current_row0
    lda csv_multiselect_vis_row1
    sta csv_current_row1
    lda csv_multiselect_min_col
    sta csv_current_col

    jsr csv_multiselect_current_visible
    beq csv_multi_col_scroll_next$
    jsr highlight_current_cell

csv_multi_col_scroll_next$:
    inc csv_multiselect_vis_row0
    bne +
    inc csv_multiselect_vis_row1
+
    dec csv_multiselect_vis_count
    jmp csv_multi_col_scroll_loop$

csv_multi_col_done$:
    jsr csv_multiselect_restore_current
    rts


csv_multiselect_highlight_mode0:
    lda csv_multiselect_count
    bne +
    rts
+
    jsr csv_multiselect_save_current

    lda csv_multiselect_min_row0
    sta csv_multiselect_iter_row0
    lda csv_multiselect_min_row1
    sta csv_multiselect_iter_row1

rect_highlight_row_loop$:
    ; current row = iter row
    lda csv_multiselect_iter_row0
    sta csv_current_row0
    lda csv_multiselect_iter_row1
    sta csv_current_row1

    lda csv_multiselect_min_col
    sta csv_multiselect_iter_col

rect_highlight_col_loop$:
    lda csv_multiselect_iter_col
    sta csv_current_col

    jsr csv_multiselect_current_visible
    beq rect_highlight_col_next$

    jsr highlight_current_cell

rect_highlight_col_next$:
    lda csv_multiselect_iter_col
    cmp csv_multiselect_max_col
    beq rect_highlight_row_next$
    inc csv_multiselect_iter_col
    jmp rect_highlight_col_loop$

rect_highlight_row_next$:
    ; iter_row == max_row ?
    lda csv_multiselect_iter_row1
    cmp csv_multiselect_max_row1
    bne rect_highlight_inc_row$
    lda csv_multiselect_iter_row0
    cmp csv_multiselect_max_row0
    beq rect_highlight_done$

rect_highlight_inc_row$:
    inc csv_multiselect_iter_row0
    bne +
    inc csv_multiselect_iter_row1
+
    jmp rect_highlight_row_loop$

rect_highlight_done$:
    jsr csv_multiselect_restore_current
    rts


; Vecchia API mantenuta per compatibilita' con eventuali chiamate:
; un redraw completo elimina gli highlight senza dover iterare.
csv_multiselect_unhighlight_all:
    lda #0
    sta csv_multiselect_count
    rts


; Apply the normal background style for csv_current_col.
; Keeps unhighlight correct with alternating column colours.
apply_current_column_style:
    lda csv_current_col
    and #0x01
    beq apply_current_column_even$
    jsr seam_apply_cell_alt_style
    rts
apply_current_column_even$:
    jsr seam_apply_cell_style
    rts


highlight_current_cell:
    jsr calc_current_screen_row
    jsr calc_current_cell_geometry

    jsr seam_apply_selection_style

    lda current_screen_row
    clc
    adc #VIEW_TOP
    ldx current_cell_x
    ldy current_cell_width
    jsr seam_fill_attr_span

    jsr apply_current_column_style
    rts


unhighlight_current_cell:
    jsr calc_current_screen_row
    jsr calc_current_cell_geometry

    jsr apply_current_column_style

    lda current_screen_row
    clc
    adc #VIEW_TOP
    ldx current_cell_x
    ldy current_cell_width
    jsr seam_fill_attr_span
    rts



; ------------------------------------------------------------
; csv_cell_delete
;
; INST/DEL fuori dalla modalita' edit:
; svuota la cella corrente senza copiare nulla nel clipboard.
; ------------------------------------------------------------

; Structural row/column insert/delete moved to EDIT.PRG.

csv_cell_delete:
    lda csv_file_loaded
    bne +
    rts
+
    ; Prepara start/end/old_len della cella corrente.
    jsr csv_edit_begin

    ; Nuovo contenuto = stringa vuota.
    lda #0
    sta csv_edit_len

    jsr csv_edit_commit
    lda #0
    sta csv_edit_mode

    ; La larghezza massima della colonna puo' cambiare.
    jsr csvindex
    jsr ensure_current_visible
    jsr csvprintview
    jsr highlight_current_cell

    ; Evita un falso doppio click dopo il redraw.
    lda #0
    sta csv_double_timer
    sta csv_double_valid
    rts


; ============================================================
; INTERNAL CLIPBOARD
;
; MEGA+C copies only the value of the current cell.
; MEGA+V replaces the current cell using the same variable-length
; Attic RAM commit routine used by the cell editor.
; ============================================================

; ------------------------------------------------------------
; csv_clip_poll_keys
;
; MEGA/C= : $D611 bit 3 = 1 while held
; C       : matrix column 2, row 4 -> bit 4 clear
; V       : matrix column 3, row 7 -> bit 7 clear
;
; One action per physical chord thanks to csv_clip_key_latch.
; ------------------------------------------------------------

csv_clip_poll_keys:
    lda MODKEYS_IMM
    and #MODKEY_MEGA
    bne csv_clip_mega_down$

    ; MEGA released -> re-arm shortcut.
    lda #0
    sta csv_clip_key_latch
    rts

csv_clip_mega_down$:
    lda csv_clip_key_latch
    beq +
    rts
+
    ; C: matrix segment 2, bit 4
    lda #2
    sta KEYMATRIXSEL
    lda KEYMATRIX
    and #0x10
    bne csv_clip_check_x$

    lda #1
    sta csv_clip_key_latch
    lda csv_edit_mode
    beq csv_clip_copy_cells$
    lda csv_edit_long_mode
    beq csv_clip_copy_cells$
    jsr csv_long_clip_copy
    lda #1
    sta csv_long_clip_swallow
    rts
csv_clip_copy_cells$:
    jsr csv_clip_copy
    rts

csv_clip_check_x$:
    ; X: matrix segment 2, bit 7
    lda #2
    sta KEYMATRIXSEL
    lda KEYMATRIX
    and #0x80
    bne csv_clip_check_v$

    lda #1
    sta csv_clip_key_latch
    lda csv_edit_mode
    beq csv_clip_cut_cells$
    lda csv_edit_long_mode
    beq csv_clip_cut_cells$
    jsr csv_long_clip_cut
    lda #1
    sta csv_long_clip_swallow
    rts
csv_clip_cut_cells$:
    jsr csv_clip_cut
    rts

csv_clip_check_v$:
    ; V: column 3, row 7
    lda #3
    sta KEYMATRIXSEL
    lda KEYMATRIX
    and #0x80
    bne csv_clip_check_f$

    lda #1
    sta csv_clip_key_latch
    lda csv_edit_mode
    beq csv_clip_paste_cells$
    lda csv_edit_long_mode
    beq csv_clip_paste_cells$
    jsr csv_long_clip_paste
    lda #1
    sta csv_long_clip_swallow
    rts
csv_clip_paste_cells$:
    jsr csv_clip_paste
    rts


csv_clip_check_f$:
    ; F: keyboard matrix segment 2, bit 5 clear.
    lda #2
    sta KEYMATRIXSEL
    lda KEYMATRIX
    and #0x20
    bne csv_clip_check_r$

    ; Find/Replace/Fill shortcuts are grid-view commands only.
    lda csv_edit_mode
    bne csv_clip_poll_done
    lda #1
    sta csv_clip_key_latch
    lda csv_file_loaded
    beq csv_clip_poll_done
    ; Drain the KERNAL character generated by MEGA+F.
    jsr csv_shortcut_wait_f_release
    jsr csv_find_open
    rts

csv_clip_check_r$:
    ; R: keyboard matrix segment 2, bit 1 clear.
    lda #2
    sta KEYMATRIXSEL
    lda KEYMATRIX
    and #0x02
    bne csv_clip_poll_done

    lda csv_edit_mode
    bne csv_clip_poll_done
    lda #1
    sta csv_clip_key_latch
    lda csv_file_loaded
    beq csv_clip_poll_done
    ; Drain the KERNAL character generated by MEGA+R.
    jsr csv_shortcut_wait_r_release
    jsr csv_replace_open
    rts


; ------------------------------------------------------------
; MEGA+F / MEGA+R are detected from the physical key matrix,
; but the KERNAL can still enqueue the printable F/R into GETIN.
; Wait until the physical key is released while continuously
; draining GETIN, then drain once more after release.
; ------------------------------------------------------------
csv_shortcut_wait_f_release:
csv_shortcut_wait_f_loop$:
    jsr getin
    lda #2
    sta KEYMATRIXSEL
    lda KEYMATRIX
    and #0x20
    beq csv_shortcut_wait_f_loop$
csv_shortcut_wait_f_drain$:
    jsr getin
    bne csv_shortcut_wait_f_drain$
    rts

csv_shortcut_wait_r_release:
csv_shortcut_wait_r_loop$:
    jsr getin
    lda #2
    sta KEYMATRIXSEL
    lda KEYMATRIX
    and #0x02
    beq csv_shortcut_wait_r_loop$
csv_shortcut_wait_r_drain$:
    jsr getin
    bne csv_shortcut_wait_r_drain$
    rts

csv_clip_poll_done:
    rts


; ============================================================
; EDIT -> FILL
;
; A direction:
;   0 Up, 1 Down, 2 Right, 3 Left
;
; The selected cell is the source and remains selected afterwards.
; The existing Copy/Paste engine performs the actual transfer.
; ============================================================
; ------------------------------------------------------------
; Full-length Fill staging.
;
; SORTTMP_BASE ($08300000) is reused as an 8 KB temporary source
; buffer while Fill is running. Sort and Fill never run concurrently.
;
; csv_fill_stage_source:
;   selected source -> logical LONGEDIT buffer -> SORTTMP
;
; csv_fill_paste_staged:
;   destination metadata is loaded silently, then SORTTMP -> LONGEDIT
;   and the existing 16-bit long commit serializes/writes the cell.
; ------------------------------------------------------------
csv_fill_stage_source:
    lda #1
    sta csv_edit_silent_load
    jsr csv_edit_begin
    lda #0
    sta csv_edit_silent_load
    sta csv_edit_mode

    ; csv_edit_begin always decoded the logical value into LONGEDIT,
    ; even when the cell was short.
    lda csv_edit_long_len0
    sta csv_fill_source_len0
    lda csv_edit_long_len1
    sta csv_fill_source_len1

    ; src = LONGEDIT_BASE
    lda #LONGEDIT_BASE0
    sta csv_sort_src0
    lda #LONGEDIT_BASE1
    sta csv_sort_src1
    lda #LONGEDIT_BASE2
    sta csv_sort_src2
    lda #LONGEDIT_BASE3
    sta csv_sort_src3

    ; dst = SORTTMP_BASE
    lda #SORTTMP_BASE0
    sta csv_sort_dst0
    lda #SORTTMP_BASE1
    sta csv_sort_dst1
    lda #SORTTMP_BASE2
    sta csv_sort_dst2
    lda #SORTTMP_BASE3
    sta csv_sort_dst3

    lda csv_fill_source_len0
    sta csv_long_rem0
    lda csv_fill_source_len1
    sta csv_long_rem1

csv_fill_stage_loop$:
    lda csv_long_rem0
    ora csv_long_rem1
    beq csv_fill_stage_done$

    ldz #0
    lda [csv_sort_src0],z
    sta [csv_sort_dst0],z
    jsr csv_sort_inc_src
    jsr csv_sort_inc_dst

    lda csv_long_rem0
    bne +
    dec csv_long_rem1
+
    dec csv_long_rem0
    jmp csv_fill_stage_loop$

csv_fill_stage_done$:
    rts


csv_fill_paste_staged:
    ; Load destination boundaries/raw length, but never draw editor UI.
    lda #1
    sta csv_edit_silent_load
    jsr csv_edit_begin
    lda #0
    sta csv_edit_silent_load
    sta csv_edit_mode

    ; src = staged source
    lda #SORTTMP_BASE0
    sta csv_sort_src0
    lda #SORTTMP_BASE1
    sta csv_sort_src1
    lda #SORTTMP_BASE2
    sta csv_sort_src2
    lda #SORTTMP_BASE3
    sta csv_sort_src3

    ; dst = LONGEDIT logical buffer
    lda #LONGEDIT_BASE0
    sta csv_sort_dst0
    lda #LONGEDIT_BASE1
    sta csv_sort_dst1
    lda #LONGEDIT_BASE2
    sta csv_sort_dst2
    lda #LONGEDIT_BASE3
    sta csv_sort_dst3

    lda csv_fill_source_len0
    sta csv_long_rem0
    sta csv_edit_long_len0
    lda csv_fill_source_len1
    sta csv_long_rem1
    sta csv_edit_long_len1

csv_fill_restore_loop$:
    lda csv_long_rem0
    ora csv_long_rem1
    beq csv_fill_restore_done$

    ldz #0
    lda [csv_sort_src0],z
    sta [csv_sort_dst0],z
    jsr csv_sort_inc_src
    jsr csv_sort_inc_dst

    lda csv_long_rem0
    bne +
    dec csv_long_rem1
+
    dec csv_long_rem0
    jmp csv_fill_restore_loop$

csv_fill_restore_done$:
    ; Force 16-bit commit path for every Fill destination.
    ; This works for both short and long source/destination cells.
    lda #1
    sta csv_edit_long_mode
    jsr csv_edit_commit
    lda #0
    sta csv_edit_mode

    ; Cell length may have changed, so addresses/widths must be rebuilt.
    jsr csvindex

    ; Bulk mode redraws only after the whole operation.
    lda csv_fill_bulk
    bne csv_fill_paste_staged_done$

    jsr ensure_current_visible
    jsr csvprintview
    jsr highlight_current_cell

csv_fill_paste_staged_done$:
    rts


csv_fill_all:
    sta csv_fill_direction

    lda csv_file_loaded
    bne +
    rts
+
    ; Preserve the original source selection.
    lda csv_current_row0
    sta csv_fill_src_row0
    lda csv_current_row1
    sta csv_fill_src_row1
    lda csv_current_col
    sta csv_fill_src_col

    ; Stage the complete logical source in Attic RAM.
    ; Unlike csv_clip_copy, this supports up to 8191 bytes.
    jsr csv_fill_stage_source

    lda #1
    sta csv_fill_bulk

    ; Start from source; each loop first advances one cell.
    lda csv_fill_src_row0
    sta csv_current_row0
    lda csv_fill_src_row1
    sta csv_current_row1
    lda csv_fill_src_col
    sta csv_current_col

csv_fill_all_loop$:
    lda csv_fill_direction
    beq csv_fill_all_up$
    cmp #1
    beq csv_fill_all_down$
    cmp #2
    beq csv_fill_all_right$
    jmp csv_fill_all_left$

csv_fill_all_up$:
    lda csv_current_row0
    ora csv_current_row1
    beq csv_fill_all_done$
    lda csv_current_row0
    bne +
    dec csv_current_row1
+
    dec csv_current_row0
    jmp csv_fill_all_paste$

csv_fill_all_down$:
    clc
    lda csv_current_row0
    adc #1
    sta csv_fill_dst_row0
    lda csv_current_row1
    adc #0
    sta csv_fill_dst_row1
    cmp csv_rows1
    bcc csv_fill_all_down_ok$
    bne csv_fill_all_done$
    lda csv_fill_dst_row0
    cmp csv_rows0
    bcs csv_fill_all_done$
csv_fill_all_down_ok$:
    lda csv_fill_dst_row0
    sta csv_current_row0
    lda csv_fill_dst_row1
    sta csv_current_row1
    jmp csv_fill_all_paste$

csv_fill_all_right$:
    lda csv_maxcols1
    bne csv_fill_all_right_inc$
    clc
    lda csv_current_col
    adc #1
    cmp csv_maxcols0
    bcs csv_fill_all_done$
csv_fill_all_right_inc$:
    inc csv_current_col
    jmp csv_fill_all_paste$

csv_fill_all_left$:
    lda csv_current_col
    beq csv_fill_all_done$
    dec csv_current_col

csv_fill_all_paste$:
    ; Paste complete staged source (short or long) into destination.
    jsr csv_fill_paste_staged
    jmp csv_fill_all_loop$

csv_fill_all_done$:
    lda #0
    sta csv_fill_bulk
    sta csv_edit_silent_load

    ; Return selection to original source and redraw only once.
    lda csv_fill_src_row0
    sta csv_current_row0
    lda csv_fill_src_row1
    sta csv_current_row1
    lda csv_fill_src_col
    sta csv_current_col

    jsr csv_multiselect_reset_current
    jsr ensure_current_visible
    jsr csvprintview
    jsr highlight_current_cell
    lda #0
    sta csv_double_timer
    sta csv_double_valid
    rts


csv_fill_adjacent:
    sta csv_fill_direction

    lda csv_file_loaded
    bne +
    rts
+
    ; Save source coordinates.
    lda csv_current_row0
    sta csv_fill_src_row0
    lda csv_current_row1
    sta csv_fill_src_row1
    lda csv_current_col
    sta csv_fill_src_col

    ; Validate destination before touching clipboard.
    lda csv_fill_direction
    beq csv_fill_check_up$
    cmp #1
    beq csv_fill_check_down$
    cmp #2
    beq csv_fill_check_right$
    jmp csv_fill_check_left$

csv_fill_check_up$:
    lda csv_current_row0
    ora csv_current_row1
    bne csv_fill_copy_source$
    rts

csv_fill_check_down$:
    clc
    lda csv_current_row0
    adc #1
    sta csv_fill_dst_row0
    lda csv_current_row1
    adc #0
    sta csv_fill_dst_row1

    lda csv_fill_dst_row1
    cmp csv_rows1
    bcc csv_fill_copy_source$
    bne csv_fill_invalid$
    lda csv_fill_dst_row0
    cmp csv_rows0
    bcc csv_fill_copy_source$
csv_fill_invalid$:
    rts

csv_fill_check_right$:
    lda csv_current_col
    cmp #0xff
    beq csv_fill_invalid$

    lda csv_maxcols1
    bne csv_fill_copy_source$
    clc
    lda csv_current_col
    adc #1
    cmp csv_maxcols0
    bcc csv_fill_copy_source$
    rts

csv_fill_check_left$:
    lda csv_current_col
    bne csv_fill_copy_source$
    rts


csv_fill_copy_source$:
    ; Capture complete logical source in Attic RAM.
    jsr csv_fill_stage_source

    ; Build destination coordinates from saved source.
    lda csv_fill_src_row0
    sta csv_current_row0
    lda csv_fill_src_row1
    sta csv_current_row1
    lda csv_fill_src_col
    sta csv_current_col

    lda csv_fill_direction
    beq csv_fill_target_up$
    cmp #1
    beq csv_fill_target_down$
    cmp #2
    beq csv_fill_target_right$
    jmp csv_fill_target_left$

csv_fill_target_up$:
    lda csv_current_row0
    bne +
    dec csv_current_row1
+
    dec csv_current_row0
    jmp csv_fill_paste$

csv_fill_target_down$:
    inc csv_current_row0
    bne csv_fill_paste$
    inc csv_current_row1
    jmp csv_fill_paste$

csv_fill_target_right$:
    inc csv_current_col
    jmp csv_fill_paste$

csv_fill_target_left$:
    dec csv_current_col

csv_fill_paste$:
    ; Paste complete staged source without opening Text Mode.
    jsr csv_fill_paste_staged

    ; Restore original source selection.
    lda csv_fill_src_row0
    sta csv_current_row0
    lda csv_fill_src_row1
    sta csv_current_row1
    lda csv_fill_src_col
    sta csv_current_col

    jsr csv_multiselect_reset_current
    jsr ensure_current_visible
    jsr csvprintview
    jsr highlight_current_cell

    lda #0
    sta csv_double_timer
    sta csv_double_valid
    rts



csv_clip_copy:
    lda csv_file_loaded
    bne +
    rts
+
    ; For a normal rectangular Shift selection, rebuild min/max bounds
    ; from the persistent anchor + current cell immediately before the
    ; overlay hand-off.  After a chain-load these BSS bounds may have
    ; been restored from an older state, while anchor/current are the
    ; authoritative rectangle endpoints.
    lda csv_multiselect_mode
    bne copy_bounds_ready$
    jsr csv_multiselect_set_rectangle
copy_bounds_ready$:
    lda #1                  ; overlay command: COPY
    jmp csv_chain_edit_save


; ------------------------------------------------------------
; csv_chain_edit_save
;
; A = overlay command. Saves the minimum viewer/CSV state in $1F00
; and chain-loads EDIT.PRG. No BSS is required for the shared record.
; ------------------------------------------------------------
csv_chain_edit_save:
    sta OVL_COMMAND

    ; Show Busy immediately, before loading EDIT.PRG.
    ; This covers Copy/Paste/Cut and also the chain-load time itself.
    jsr busycursor_on

    lda #OVL_MAGIC_VALUE
    sta OVL_MAGIC

    lda csv_size0
    sta OVL_SIZE0
    lda csv_size1
    sta OVL_SIZE1
    lda csv_size2
    sta OVL_SIZE2
    lda csv_size3
    sta OVL_SIZE3
    lda csv_delimiter
    sta OVL_DELIMITER
    lda csv_screen_mode
    sta OVL_SCREENMODE
    lda csv_delimiter_mode
    sta OVL_DELIMMODE
    lda csv_decoder_mode
    sta OVL_DECODER

    lda csv_top_row0
    sta OVL_TOP0
    lda csv_top_row1
    sta OVL_TOP1
    lda csv_current_row0
    sta OVL_CURROW0
    lda csv_current_row1
    sta OVL_CURROW1
    lda csv_current_col
    sta OVL_CURCOL
    lda csv_left_col
    sta OVL_LEFTCOL

    lda csv_multiselect_count
    sta OVL_MULTI_COUNT
    lda csv_multiselect_mode
    sta OVL_MULTI_MODE
    lda csv_multiselect_min_row0
    sta OVL_MINROW0
    lda csv_multiselect_min_row1
    sta OVL_MINROW1
    lda csv_multiselect_max_row0
    sta OVL_MAXROW0
    lda csv_multiselect_max_row1
    sta OVL_MAXROW1
    lda csv_multiselect_min_col
    sta OVL_MINCOL
    lda csv_multiselect_max_col
    sta OVL_MAXCOL

    ; Preserve the Shift-selection anchor across the chain-load.
    ; Without this the BSS anchor restarts at 0,0 and the next
    ; Shift+click may create an enormous rectangle from the origin.
    lda csv_multiselect_anchor_row0
    sta OVL_ANCHOR_ROW0
    lda csv_multiselect_anchor_row1
    sta OVL_ANCHOR_ROW1
    lda csv_multiselect_anchor_col
    sta OVL_ANCHOR_COL

    ; Dimensions needed by Fill / Fill All inside EDIT.PRG.
    lda csv_rows0
    sta OVL_ROWS0
    lda csv_rows1
    sta OVL_ROWS1
    lda csv_maxcols0
    sta OVL_MAXCOLS0
    lda csv_maxcols1
    sta OVL_MAXCOLS1

    lda csv_frozen_rows
    sta OVL_FROZEN_ROWS
    lda csv_frozen_cols
    sta OVL_FROZEN_COLS

    jmp chain_edit



; ------------------------------------------------------------
; csv_chain_search_return
; Save current viewer/CSV position and return from SEARCH.PRG to main viewer PRG.
; ------------------------------------------------------------
csv_chain_search_return:
    lda #OVL_MAGIC_VALUE
    sta OVL_MAGIC

    lda csv_size0
    sta OVL_SIZE0
    lda csv_size1
    sta OVL_SIZE1
    lda csv_size2
    sta OVL_SIZE2
    lda csv_size3
    sta OVL_SIZE3
    lda csv_delimiter
    sta OVL_DELIMITER
    lda csv_screen_mode
    sta OVL_SCREENMODE
    lda csv_delimiter_mode
    sta OVL_DELIMMODE
    lda csv_decoder_mode
    sta OVL_DECODER

    lda csv_top_row0
    sta OVL_TOP0
    lda csv_top_row1
    sta OVL_TOP1
    lda csv_current_row0
    sta OVL_CURROW0
    lda csv_current_row1
    sta OVL_CURROW1
    lda csv_current_col
    sta OVL_CURCOL
    lda csv_left_col
    sta OVL_LEFTCOL

    lda csv_multiselect_count
    sta OVL_MULTI_COUNT
    lda csv_multiselect_mode
    sta OVL_MULTI_MODE
    lda csv_multiselect_min_row0
    sta OVL_MINROW0
    lda csv_multiselect_min_row1
    sta OVL_MINROW1
    lda csv_multiselect_max_row0
    sta OVL_MAXROW0
    lda csv_multiselect_max_row1
    sta OVL_MAXROW1
    lda csv_multiselect_min_col
    sta OVL_MINCOL
    lda csv_multiselect_max_col
    sta OVL_MAXCOL

    ; Preserve the Shift-selection anchor across the chain-load.
    ; Without this the BSS anchor restarts at 0,0 and the next
    ; Shift+click may create an enormous rectangle from the origin.
    lda csv_multiselect_anchor_row0
    sta OVL_ANCHOR_ROW0
    lda csv_multiselect_anchor_row1
    sta OVL_ANCHOR_ROW1
    lda csv_multiselect_anchor_col
    sta OVL_ANCHOR_COL

    ; Dimensions needed by Fill / Fill All inside EDIT.PRG.
    lda csv_rows0
    sta OVL_ROWS0
    lda csv_rows1
    sta OVL_ROWS1
    lda csv_maxcols0
    sta OVL_MAXCOLS0
    lda csv_maxcols1
    sta OVL_MAXCOLS1

    lda csv_frozen_rows
    sta OVL_FROZEN_ROWS
    lda csv_frozen_cols
    sta OVL_FROZEN_COLS

    jmp chain_knockcsv


; ------------------------------------------------------------
; csv_restore_overlay_state
; Restores CSV/view state after EDIT.PRG chain-loads main viewer PRG again.
; ------------------------------------------------------------
csv_restore_overlay_state:
    lda #0
    sta OVL_MAGIC

    lda OVL_SIZE0
    sta csv_size0
    lda OVL_SIZE1
    sta csv_size1
    lda OVL_SIZE2
    sta csv_size2
    lda OVL_SIZE3
    sta csv_size3
    lda OVL_DELIMITER
    sta csv_delimiter
    sta csv_save_delimiter
    lda OVL_DELIMMODE
    sta csv_delimiter_mode
    lda OVL_DECODER
    sta csv_decoder_mode
    lda OVL_SCREENMODE
    sta csv_screen_mode

    ; Rebuild row index / column widths from the CSV that remained in Attic.
    jsr csvindex
    lda #1
    sta csv_file_loaded

    lda OVL_TOP0
    sta csv_top_row0
    lda OVL_TOP1
    sta csv_top_row1
    lda OVL_CURROW0
    sta csv_current_row0
    lda OVL_CURROW1
    sta csv_current_row1
    lda OVL_CURCOL
    sta csv_current_col
    lda OVL_LEFTCOL
    sta csv_left_col

    lda OVL_MULTI_COUNT
    sta csv_multiselect_count
    lda OVL_MULTI_MODE
    sta csv_multiselect_mode
    lda OVL_MINROW0
    sta csv_multiselect_min_row0
    lda OVL_MINROW1
    sta csv_multiselect_min_row1
    lda OVL_MAXROW0
    sta csv_multiselect_max_row0
    lda OVL_MAXROW1
    sta csv_multiselect_max_row1
    lda OVL_MINCOL
    sta csv_multiselect_min_col
    lda OVL_MAXCOL
    sta csv_multiselect_max_col

    lda OVL_ANCHOR_ROW0
    sta csv_multiselect_anchor_row0
    lda OVL_ANCHOR_ROW1
    sta csv_multiselect_anchor_row1
    lda OVL_ANCHOR_COL
    sta csv_multiselect_anchor_col

    ; These BSS geometry values are cleared when main viewer PRG is reloaded.
    lda OVL_FROZEN_ROWS
    sta csv_frozen_rows
    lda OVL_FROZEN_COLS
    sta csv_frozen_cols

    jsr style_apply_screen_mode
    jsr sprite_apply_screen_mode
    jsr csv_update_screen_layout

    ; Rebuild the custom mouse sprite after the final video mode restore.
    jsr initmousecursor
    jsr sprite_apply_screen_mode

    jsr clear_full_viewport
    jsr draw_menu_bar
    jsr csvprintview
    jsr csv_multiselect_highlight_all
    lda RASTER
    sta csv_double_last_raster
    rts


; ------------------------------------------------------------
; csv_clip_cut
;
; MEGA+X:
;   1. copia il valore corrente nel clipboard
;   2. sostituisce la cella con stringa vuota
;   3. ricostruisce indice/larghezze e ridisegna
; ------------------------------------------------------------

csv_clip_cut:
    lda csv_file_loaded
    bne +
    rts
+
    ; Come Copy: prima del chain-load ricalcola sempre i bounds
    ; del rettangolo Shift da anchor + cella corrente.
    lda csv_multiselect_mode
    bne cut_bounds_ready$
    jsr csv_multiselect_set_rectangle
cut_bounds_ready$:
    lda #3                  ; overlay command: CUT multicell
    jmp csv_chain_edit_save

csv_clip_paste:
    lda csv_file_loaded
    bne +
    rts
+
    lda #2                  ; overlay command: PASTE multicell
    jmp csv_chain_edit_save


; ============================================================
; CELL EDITING - first step
;
; RETURN sulla cella corrente:
;   copia il contenuto in csv_edit_buf e entra in edit mode.
;
; Durante edit:
;   caratteri stampabili -> append
;   DEL ($14)            -> cancella ultimo carattere
;   RETURN               -> commit
;   ESC                  -> cancel
;
; Il commit supporta variazioni di lunghezza: sposta la coda
; del CSV in Attic RAM, aggiorna csv_size e ricostruisce csvindex.
; ============================================================

csv_edit_begin:
    lda csv_file_loaded
    bne +
    rts
+
    jsr csv_edit_find_cell

    ; Reset long-engine lengths/state.
    lda #0
    sta csv_edit_long_mode
    sta csv_edit_long_len0
    sta csv_edit_long_len1
    sta csv_edit_long_raw0
    sta csv_edit_long_raw1
    sta csv_edit_window_width

    jsr csv_long_ptr_reset
    jsr csv_scan_reset

csv_edit_load_loop:
    jsr csv_edit_at_end
    beq +
    jmp csv_edit_load_done
+
    ldz #0
    lda [attic_addr0],z
    sta csv_edit_raw_char

    jsr csv_scan_classify
    sta csv_edit_scan_kind

    cmp #1
    beq csv_edit_load_done
    cmp #2
    beq csv_edit_load_done

    ; RAW serialized length is 16 bit.
    inc csv_edit_long_raw0
    bne +
    inc csv_edit_long_raw1
+

    ; Syntax quote is not part of the logical value.
    lda csv_edit_scan_kind
    cmp #3
    beq csv_edit_load_advance

    ; Append logical byte to Attic long buffer, up to 8191 bytes.
    lda csv_edit_long_len1
    cmp #LONGEDIT_MAX_HI
    bcs csv_edit_load_advance

    lda csv_edit_raw_char
    ldz #0
    sta [csv_long_ptr0],z
    jsr csv_long_ptr_inc

    inc csv_edit_long_len0
    bne csv_edit_load_advance
    inc csv_edit_long_len1

csv_edit_load_advance:
    jsr csv_edit_inc_attic
    jmp csv_edit_load_loop


csv_edit_load_done:
    ; attic_addr points to cell delimiter / logical row end.
    lda attic_addr0
    sta csv_edit_end0
    lda attic_addr1
    sta csv_edit_end1
    lda attic_addr2
    sta csv_edit_end2
    lda attic_addr3
    sta csv_edit_end3


    ; --------------------------------------------------------
    ; Decide editor mode from the exact physical cell length.
    ;
    ; raw_len = csv_edit_end - csv_edit_start (16 bit)
    ; This is authoritative and independent of quote/newline decoding.
    ; --------------------------------------------------------
    sec
    lda csv_edit_end0
    sbc csv_edit_start0
    sta csv_edit_long_raw0
    lda csv_edit_end1
    sbc csv_edit_start1
    sta csv_edit_long_raw1

    ; Full-screen Text Mode ONLY for long cells:
    ;   raw length > 254  OR logical decoded length > 254.
    lda csv_edit_long_raw1
    bne csv_edit_begin_long$

    lda csv_edit_long_raw0
    cmp #255
    bcs csv_edit_begin_long$

    lda csv_edit_long_len1
    bne csv_edit_begin_long$

    lda csv_edit_long_len0
    cmp #255
    bcs csv_edit_begin_long$

    lda #0
    sta csv_edit_long_mode

    ; Mirror short logical value back to conventional RAM buffer.
    ; IMPORTANT: csv_edit_len must be the decoded logical length,
    ; not the zero currently in A.
    lda csv_edit_long_len0
    sta csv_edit_len

    lda csv_edit_long_raw0
    sta csv_edit_raw_len
    sta csv_edit_old_len

    ; Short editor cursor starts at logical end.
    lda csv_edit_len
    sta csv_edit_cursor_pos

    jsr csv_long_ptr_reset
    ldx #0
csv_edit_copy_short$:
    cpx csv_edit_len
    beq csv_edit_begin_ready$
    ldz #0
    lda [csv_long_ptr0],z
    sta csv_edit_buf,x
    jsr csv_long_ptr_inc
    inx
    jmp csv_edit_copy_short$

csv_edit_begin_long$:
    ; Long cells use the Attic-backed full-screen editor.
    lda #1
    sta csv_edit_long_mode
    sta csv_long_follow_end

    ; Long editor cursor starts at logical end (16 bit).
    lda csv_edit_long_len0
    sta csv_long_cursor_pos0
    lda csv_edit_long_len1
    sta csv_long_cursor_pos1

    lda #0
    sta csv_long_top0
    sta csv_long_top1
    sta csv_long_sel_active

csv_edit_begin_ready$:
    lda #1
    sta csv_edit_mode

    ; Replace uses the editor loader as a data engine only.
    ; For long cells, drawing here would enter full-screen Text Mode
    ; and cause visible open/close flashes during Replace/Replace All.
    lda csv_edit_silent_load
    bne csv_edit_begin_ready_silent$

    jsr csv_edit_draw

csv_edit_begin_ready_silent$:
    rts


; ------------------------------------------------------------
; csv_scan_reset / csv_scan_classify
; Generic quote-aware raw CSV scanner for cell-boundary operations.
; OUTPUT A from classify:
;   0 = content
;   1 = comma delimiter outside quotes
;   2 = row end outside quotes
;   3 = quote syntax / skipped
; ------------------------------------------------------------
csv_scan_reset:
    lda #0
    sta csv_scan_in_quotes
    sta csv_scan_quote_pending
    sta csv_scan_field_has_data
    rts

csv_scan_classify:
    lda csv_scan_in_quotes
    beq csv_scan_outside$

    lda csv_scan_quote_pending
    beq csv_scan_inside$
    ldz #0
    lda [attic_addr0],z
    cmp #0x22
    bne csv_scan_close_then_out$
    lda #0
    sta csv_scan_quote_pending
    lda #0
    rts
csv_scan_close_then_out$:
    lda #0
    sta csv_scan_quote_pending
    sta csv_scan_in_quotes
    jmp csv_scan_outside_process$

csv_scan_inside$:
    ldz #0
    lda [attic_addr0],z
    cmp #0x22
    bne csv_scan_inside_content$
    lda #1
    sta csv_scan_quote_pending
    lda #3
    rts
csv_scan_inside_content$:
    lda #1
    sta csv_scan_field_has_data
    lda #0
    rts

csv_scan_outside$:
    ldz #0
    lda [attic_addr0],z
    cmp #0x22
    bne csv_scan_outside_process$
    lda csv_scan_field_has_data
    bne csv_scan_plain_quote$
    lda #1
    sta csv_scan_in_quotes
    lda #3
    rts
csv_scan_plain_quote$:
    lda #1
    sta csv_scan_field_has_data
    lda #0
    rts

csv_scan_outside_process$:
    ldz #0
    lda [attic_addr0],z
    cmp csv_delimiter
    bne csv_scan_chk_cr$
    lda #0
    sta csv_scan_field_has_data
    lda #1
    rts
csv_scan_chk_cr$:
    cmp #0x0d
    beq csv_scan_row_end$

    ; Canonical Attic convention:
    ; $0D = real CSV row end
    ; $0A = embedded newline content.
    ; If $0A is encountered outside quote state, treat it as content
    ; rather than prematurely terminating the cell.
    lda #1
    sta csv_scan_field_has_data
    lda #0
    rts
csv_scan_row_end$:
    lda #2
    rts


; Trova start della cella corrente.
; ============================================================
; FIND
; ============================================================

; ------------------------------------------------------------
; csv_find_poll_function_keys
;
; Physical F3/F4 interception for the Find bar.
;
; F3/F4 share the physical F3 key:
;   keyboard matrix segment 0, bit 5 (active low)
;   no SHIFT -> F3 / Find next
;   SHIFT    -> F4 / Find previous
;
; This bypasses GETIN because the MEGA65 KERNAL expands F3 to
; its programmed command string ("dir" by default).
;
; csv_find_fn_physical = 1 while the key is physically held.
; The main loop skips GETIN in that case, preventing macro bytes
; from entering the Find field.
; ------------------------------------------------------------
csv_find_poll_function_keys:
    lda #0
    sta csv_find_fn_physical

    lda csv_find_mode
    bne csv_find_fn_check$
    lda #0
    sta csv_find_fn_latch
    rts

csv_find_fn_check$:
    ; C64/MEGA65 keyboard matrix row 0:
    ;   bit 5 = physical F3/F4
    ;   bit 6 = physical F5/F6
    ;   bit 3 = physical F7/F8
    ; Function keys are active-low.  Read them directly because
    ; GETIN expands programmable F-key macros.
    lda #0
    sta KEYMATRIXSEL
    lda KEYMATRIX
    sta csv_find_fn_matrix

    ; F3/F4 = Find next / previous.
    lda csv_find_fn_matrix
    and #0x20
    bne csv_find_fn_check_f5$

    lda #0x20
    sta csv_find_fn_mask
    lda #1
    sta csv_find_fn_physical

    lda MODKEYS_IMM
    and #MODKEY_SHIFT
    beq csv_find_fn_do_next$
    jsr csv_find_execute_previous
    jmp csv_find_fn_wait_release$

csv_find_fn_do_next$:
    jsr csv_find_execute_next
    jmp csv_find_fn_wait_release$

csv_find_fn_check_f5$:
    ; F5 toggles case-sensitive search. Shift+F5 (F6) is ignored.
    lda csv_find_fn_matrix
    and #0x40
    bne csv_find_fn_check_f7$

    lda #0x40
    sta csv_find_fn_mask
    lda #1
    sta csv_find_fn_physical

    lda MODKEYS_IMM
    and #MODKEY_SHIFT
    bne csv_find_fn_wait_release$
    lda csv_find_case_sensitive
    eor #1
    sta csv_find_case_sensitive
    jsr csv_find_redraw_active_panel
    jmp csv_find_fn_wait_release$

csv_find_fn_check_f7$:
    ; F7 toggles search restricted to the current column.
    ; Shift+F7 (F8) is ignored.
    lda csv_find_fn_matrix
    and #0x08
    bne csv_find_fn_none$

    lda #0x08
    sta csv_find_fn_mask
    lda #1
    sta csv_find_fn_physical

    lda MODKEYS_IMM
    and #MODKEY_SHIFT
    bne csv_find_fn_wait_release$
    lda csv_find_vertical
    eor #1
    sta csv_find_vertical
    jsr csv_find_redraw_active_panel
    jmp csv_find_fn_wait_release$

csv_find_fn_none$:
    lda #0
    sta csv_find_fn_latch
    rts

csv_find_fn_wait_release$:
    ; Stay here until the same physical function key is released,
    ; continuously draining any KERNAL macro bytes.
csv_find_fn_wait_loop$:
    jsr csv_find_flush_getin
    lda #0
    sta KEYMATRIXSEL
    lda KEYMATRIX
    and csv_find_fn_mask
    beq csv_find_fn_wait_loop$

    ; One final drain catches bytes queued on key release.
    jsr csv_find_flush_getin

    lda #0
    sta csv_find_fn_latch
    sta csv_find_fn_physical
    rts


; Drain KERNAL keyboard buffer until GETIN reports empty.
csv_find_flush_getin:
csv_find_flush_loop$:
    jsr getin
    bne csv_find_flush_loop$
    rts



; Open one-line Find prompt on the bottom screen row.
csv_find_redraw_active_panel:
    lda csv_replace_mode
    beq csv_find_redraw_single$
    jsr csv_replace_draw
    rts

csv_find_redraw_single$:
    jsr csv_find_draw_prompt
    rts


csv_find_open:
    ; Se il flusso proviene dal pannello Replace, ripristina prima
    ; la griglia: Replace occupava due righe, mentre Find
    ; deve occuparne soltanto una.
    lda csv_replace_mode
    beq csv_find_open_no_replace$

    jsr csvprintview
    jsr highlight_current_cell

csv_find_open_no_replace$:
    lda #1
    sta csv_find_mode

    lda #0
    sta csv_replace_mode
    sta csv_find_len

    jsr csv_find_draw_prompt
    rts


; A = input key while Find prompt is active.
csv_find_handle_key:
    sta csv_find_key

    ; Native F9 is returned as $F9.  It means Replace All only when
    ; the Replace panel is active; in plain Find it is intentionally inert.
    lda csv_find_key
    cmp #0xf9
    bne csv_find_key_not_f9$
    lda csv_replace_mode
    beq csv_find_key_done$
    jsr csv_replace_all
    rts
csv_find_key_not_f9$:

    lda csv_replace_mode
    beq +
    lda csv_find_key
    jmp csv_replace_handle_key
+
    lda csv_find_key
    and #0x7f
    cmp #KEY_RETURN
    bne csv_find_key_not_return$
    jsr csv_find_execute
    rts

csv_find_key_not_return$:
    lda csv_find_key
    cmp #KEY_ESC
    bne csv_find_key_not_esc$
    jmp csv_chain_search_return

csv_find_key_not_esc$:
    cmp #KEY_DEL
    bne csv_find_key_not_del$
    lda csv_find_len
    beq csv_find_redraw_prompt$
    dec csv_find_len
    jmp csv_find_redraw_prompt$

csv_find_key_not_del$:
    cmp #0x08
    bne csv_find_key_printable$
    lda csv_find_len
    beq csv_find_redraw_prompt$
    dec csv_find_len
    jmp csv_find_redraw_prompt$

csv_find_key_printable$:
    lda csv_find_key
    cmp #0x20
    bcc csv_find_key_done$
    ldx csv_find_len
    cpx #63
    bcs csv_find_key_done$
    sta csv_find_buf,x
    inc csv_find_len

csv_find_redraw_prompt$:
    jsr csv_find_draw_prompt
csv_find_key_done$:
    rts


csv_find_draw_prompt:
    jsr seam_apply_selection_style

    ; Clear the entire Find row first, including old table characters.
    ldx runtime_last_row
    jsr seam_clear_row

    ; Uniforma gli attributi di tutta la barra Find.
    lda runtime_last_row
    ldx #0
    ldy #80
    jsr seam_fill_attr_span

    ldx runtime_last_row
    ldy #0
    clc
    jsr seam_plot

    ldx #0
csv_find_draw_label$:
    lda csv_find_prompt_text,x
    beq csv_find_draw_text$
    jsr seam_bsout
    inx
    jmp csv_find_draw_label$

csv_find_draw_text$:
    ldx #0
csv_find_draw_chars$:
    cpx csv_find_len
    beq csv_find_draw_clear$
    cpx #33
    bcs csv_find_draw_clear_full$
    lda csv_find_buf,x
    jsr seam_bsout
    inx
    jmp csv_find_draw_chars$

csv_find_draw_clear$:
    ; Clear the unused visible part of the Find field. The logical
    ; search buffer may be longer than the 33 columns shown here.
    lda #33
    sec
    sbc csv_find_len
    sta csv_find_clear_count
    jmp csv_find_draw_clear_loop$
csv_find_draw_clear_full$:
    lda #0
    sta csv_find_clear_count
csv_find_draw_clear_loop$:
    lda csv_find_clear_count
    beq csv_find_draw_cursor$
    lda #' '
    jsr seam_bsout
    dec csv_find_clear_count
    jmp csv_find_draw_clear_loop$

csv_find_draw_cursor$:
    ; Find command strip, right-aligned:
    ; F3 NEXT F4 PREV F5 CASE F7 COL
    ldx runtime_last_row
    ldy #48
    clc
    jsr seam_plot
    jsr csv_find_draw_command_strip

    lda csv_find_len
    clc
    adc #6
    cmp #48
    bcc +
    lda #47
+
    tax
    lda runtime_last_row
    jsr seam_cursor_blink_at
    jsr seam_apply_cell_style
    rts


; ============================================================
; REPLACE
; ============================================================

csv_replace_open:
    lda #1
    sta csv_find_mode
    sta csv_replace_mode
    lda #0
    sta csv_replace_focus
    sta csv_find_len
    sta csv_replace_len
    jsr csv_replace_draw
    rts


; A = key while Replace panel is active.
; focus 0 = Find field, focus 1 = Replace field.
csv_replace_handle_key:
    sta csv_find_key

    cmp #KEY_ESC
    bne csv_replace_not_esc$
    jmp csv_chain_search_return

csv_replace_not_esc$:
    and #0x7f
    cmp #KEY_RETURN
    bne csv_replace_not_return$

    lda csv_replace_focus
    bne csv_replace_do_return$

    ; First Return: move from Find to Replace field.
    lda #1
    sta csv_replace_focus
    jsr csv_replace_draw
    rts

csv_replace_do_return$:
    ; Find first/current match, replace it, then leave panel active.
    lda csv_find_len
    beq csv_replace_done$
    jsr csv_find_execute
    lda csv_find_match
    beq csv_replace_done$
    jsr csv_replace_current_match
    jsr csv_replace_draw
csv_replace_done$:
    rts

csv_replace_not_return$:
    lda csv_find_key
    cmp #KEY_DEL
    beq csv_replace_delete$
    cmp #0x08
    beq csv_replace_delete$

    cmp #0x20
    bcc csv_replace_key_done$

    ; Keep the actual printable PETSCII byte.  The focus test below
    ; loads csv_replace_focus into A, so without this reload the code was
    ; storing 0/1 instead of the typed character. seam_bsout then
    ; rendered those control bytes as '?'.
    lda csv_replace_focus
    bne csv_replace_char_replace$

    ldx csv_find_len
    cpx #63
    bcs csv_replace_key_done$
    lda csv_find_key
    sta csv_find_buf,x
    inc csv_find_len
    jsr csv_replace_draw
    rts

csv_replace_char_replace$:
    ldx csv_replace_len
    cpx #63
    bcs csv_replace_key_done$
    lda csv_find_key
    sta csv_replace_buf,x
    inc csv_replace_len
    jsr csv_replace_draw
    rts

csv_replace_delete$:
    lda csv_replace_focus
    bne csv_replace_delete_replace$
    lda csv_find_len
    beq csv_replace_key_done$
    dec csv_find_len
    jsr csv_replace_draw
    rts

csv_replace_delete_replace$:
    lda csv_replace_len
    beq csv_replace_key_done$
    dec csv_replace_len
    jsr csv_replace_draw

csv_replace_key_done$:
    rts


; Draw Find on row 48 and Replace on row 49.
csv_replace_draw:
    jsr seam_apply_selection_style

    ; Clear both panel rows first, including old table characters.
    ldx runtime_replace_row
    jsr seam_clear_row
    ldx runtime_last_row
    jsr seam_clear_row

    ; Uniforma gli attributi di tutta la barra Find.
    lda runtime_replace_row
    ldx #0
    ldy #80
    jsr seam_fill_attr_span

    ; Uniforma gli attributi di tutta la barra Replace.
    lda runtime_last_row
    ldx #0
    ldy #80
    jsr seam_fill_attr_span

    ; Find row
    ldx runtime_replace_row
    ldy #0
    clc
    jsr seam_plot

    ; Find row
    ldx runtime_replace_row
    ldy #0
    clc
    jsr seam_plot
    ldx #0
csv_replace_draw_find_label$:
    lda csv_find_prompt_text,x
    beq csv_replace_draw_find_text$
    jsr seam_bsout
    inx
    jmp csv_replace_draw_find_label$

csv_replace_draw_find_text$:
    ldx #0
csv_replace_draw_find_chars$:
    cpx csv_find_len
    beq csv_replace_draw_find_clear$
    cpx #33
    bcs csv_replace_draw_find_clear_full$
    lda csv_find_buf,x
    jsr seam_bsout
    inx
    jmp csv_replace_draw_find_chars$

csv_replace_draw_find_clear$:
    lda #33
    sec
    sbc csv_find_len
    sta csv_find_clear_count
    jmp csv_replace_draw_find_clear_loop$
csv_replace_draw_find_clear_full$:
    lda #0
    sta csv_find_clear_count
csv_replace_draw_find_clear_loop$:
    lda csv_find_clear_count
    beq csv_replace_draw_find_hints$
    lda #' '
    jsr seam_bsout
    dec csv_find_clear_count
    jmp csv_replace_draw_find_clear_loop$

csv_replace_draw_find_hints$:
    ; Same right-aligned Find controls as the one-line Find panel.
    ldx runtime_replace_row
    ldy #48
    clc
    jsr seam_plot
    jsr csv_find_draw_command_strip

csv_replace_draw_replace$:
    ldx runtime_last_row
    ldy #0
    clc
    jsr seam_plot
    ldx #0
csv_replace_label_loop$:
    lda csv_replace_prompt_text,x
    beq csv_replace_text_loop_start$
    jsr seam_bsout
    inx
    jmp csv_replace_label_loop$

csv_replace_text_loop_start$:
    ldx #0
csv_replace_text_loop$:
    cpx csv_replace_len
    beq csv_replace_clear_rest$
    lda csv_replace_buf,x
    jsr seam_bsout
    inx
    jmp csv_replace_text_loop$

csv_replace_clear_rest$:
    ; Keep cols 73..78 free for the Replace-only F9 ALL command.
    lda #64
    sec
    sbc csv_replace_len
    sta csv_find_clear_count
csv_replace_clear_rest_loop$:
    lda csv_find_clear_count
    beq csv_replace_cursor$
    lda #' '
    jsr seam_bsout
    dec csv_find_clear_count
    jmp csv_replace_clear_rest_loop$

csv_replace_cursor$:
    ; F9 ALL exists only on the Replace row.
    ldx runtime_last_row
    ldy #73
    clc
    jsr seam_plot
    ldx #0
csv_replace_draw_all_loop$:
    lda csv_find_all_hint_text,x
    beq csv_replace_cursor_select$
    jsr seam_bsout
    inx
    jmp csv_replace_draw_all_loop$

csv_replace_cursor_select$:
    lda csv_replace_focus
    bne csv_replace_cursor_replace$
    lda csv_find_len
    clc
    adc #6
    tax
    lda runtime_replace_row
    jsr seam_cursor_blink_at
    jmp csv_replace_draw_done$

csv_replace_cursor_replace$:
    lda csv_replace_len
    clc
    adc #9
    tax
    lda runtime_last_row
    jsr seam_cursor_blink_at

csv_replace_draw_done$:
    jsr seam_apply_cell_style
    rts


; Replace the logical match in current cell using existing editor engine.
csv_replace_current_match:
    ; Single Replace can also take noticeable time on long cells.
    ; Replace All already owns the Busy cursor for the whole batch.
    lda csv_replace_all_active
    bne +
    jsr busycursor_on
+
    ; Load selected cell through normal edit loader, but silently.
    ; Long cells still use the Attic-backed editor buffers; only the
    ; full-screen Text Mode renderer is suppressed.
    lda #1
    sta csv_edit_silent_load
    jsr csv_edit_begin
    lda #0
    sta csv_edit_silent_load

    ; Interactive edit UI is not required after loading.
    sta csv_edit_mode

    lda csv_edit_long_mode
    beq +
    jmp csv_replace_long$
+

    ; Short buffer: remove find_len bytes at match_pos, then insert replacement.
    lda csv_find_match_pos1
    beq +
    rts
+
    lda csv_find_match_pos0
    sta csv_replace_pos

    ; Shift left: src = pos + find_len, dst = pos.
    clc
    adc csv_find_len
    sta csv_replace_src
    lda csv_replace_pos
    sta csv_replace_dst

csv_replace_short_remove_loop$:
    lda csv_replace_src
    cmp csv_edit_len
    bcs csv_replace_short_removed$
    ldx csv_replace_src
    lda csv_edit_buf,x
    ldx csv_replace_dst
    sta csv_edit_buf,x
    inc csv_replace_src
    inc csv_replace_dst
    jmp csv_replace_short_remove_loop$

csv_replace_short_removed$:
    sec
    lda csv_edit_len
    sbc csv_find_len
    sta csv_edit_len

    ; Capacity check for replacement.
    clc
    adc csv_replace_len
    cmp #255
    bcc +
    rts
+
    ; Make room from end backwards.
    lda csv_edit_len
    sta csv_replace_src
csv_replace_short_shift_right$:
    lda csv_replace_src
    cmp csv_replace_pos
    beq csv_replace_short_insert$
    dec csv_replace_src
    ldx csv_replace_src
    stx csv_replace_tmp
    txa
    clc
    adc csv_replace_len
    tay
    ldx csv_replace_tmp
    lda csv_edit_buf,x
    sta csv_edit_buf,y
    jmp csv_replace_short_shift_right$

csv_replace_short_insert$:
    ldx #0
csv_replace_short_insert_loop$:
    cpx csv_replace_len
    beq csv_replace_short_commit$
    lda csv_replace_buf,x
    stx csv_replace_tmp
    txa
    clc
    adc csv_replace_pos
    tay
    ldx csv_replace_tmp
    lda csv_replace_buf,x
    sta csv_edit_buf,y
    inx
    jmp csv_replace_short_insert_loop$

csv_replace_short_commit$:
    clc
    lda csv_edit_len
    adc csv_replace_len
    sta csv_edit_len
    jsr csv_edit_commit
    jmp csv_replace_after_commit$


csv_replace_long$:
    ; cursor = match_pos + find_len, then backspace find_len chars.
    clc
    lda csv_find_match_pos0
    adc csv_find_len
    sta csv_long_cursor_pos0
    lda csv_find_match_pos1
    adc #0
    sta csv_long_cursor_pos1

    ldx csv_find_len
csv_replace_long_delete_loop$:
    cpx #0
    beq csv_replace_long_insert$
    jsr csv_long_backspace
    dex
    jmp csv_replace_long_delete_loop$

csv_replace_long_insert$:
    ldx #0
csv_replace_long_insert_loop$:
    cpx csv_replace_len
    beq csv_replace_long_commit$
    lda csv_replace_buf,x
    jsr csv_long_insert_char
    inx
    jmp csv_replace_long_insert_loop$

csv_replace_long_commit$:
    jsr csv_edit_commit

csv_replace_after_commit$:
    jsr csvindex

    lda csv_replace_all_active
    beq csv_replace_after_commit_redraw$
    lda #1
    sta csv_find_mode
    sta csv_replace_mode
    rts

csv_replace_after_commit_redraw$:
    jsr ensure_current_visible
    jsr csvprintview
    jsr highlight_current_cell
    lda #1
    sta csv_find_mode
    sta csv_replace_mode
    jsr busycursor_off
    rts


; ------------------------------------------------------------
; Replace All
;
; Scans every target cell exactly once in row-major order. Inside a cell,
; repeatedly finds/replaces from an explicit logical offset. After each
; replacement the offset advances by replacement length, preventing a
; replacement that contains the search text from matching itself forever.
; ------------------------------------------------------------
csv_replace_all:
    lda csv_find_len
    bne +
    rts
+
    jsr busycursor_on

    lda #1
    sta csv_replace_all_active

    ; Start at row 0. In normal mode start col 0; in vertical mode use
    ; the currently selected column only.
    lda #0
    sta csv_replace_all_row0
    sta csv_replace_all_row1
    sta csv_replace_all_col

    lda csv_find_vertical
    beq csv_replace_all_cell_begin$
    lda csv_current_col
    sta csv_replace_all_col

csv_replace_all_cell_begin$:
    lda csv_replace_all_row0
    sta csv_find_row0
    lda csv_replace_all_row1
    sta csv_find_row1
    lda csv_replace_all_col
    sta csv_find_col

    lda #0
    sta csv_find_start_pos0
    sta csv_find_start_pos1

csv_replace_all_same_cell$:
    jsr csv_find_test_cell
    lda csv_find_match
    beq csv_replace_all_next_cell$

    ; Move visible/current selection to the matched cell because the existing
    ; replacement engine edits csv_current_row/col.
    lda csv_find_row0
    sta csv_current_row0
    lda csv_find_row1
    sta csv_current_row1
    lda csv_find_col
    sta csv_current_col

    jsr csv_replace_current_match

    ; Continue after newly inserted replacement.
    clc
    lda csv_find_match_pos0
    adc csv_replace_len
    sta csv_find_start_pos0
    lda csv_find_match_pos1
    adc #0
    sta csv_find_start_pos1

    ; csvindex rebuilt by current_match; row/col identity remains valid.
    lda csv_replace_all_row0
    sta csv_find_row0
    lda csv_replace_all_row1
    sta csv_find_row1
    lda csv_replace_all_col
    sta csv_find_col
    jmp csv_replace_all_same_cell$

csv_replace_all_next_cell$:
    lda csv_find_vertical
    bne csv_replace_all_next_row$

    inc csv_replace_all_col
    lda csv_maxcols1
    bne csv_replace_all_cell_begin$
    lda csv_replace_all_col
    cmp csv_maxcols0
    bcc csv_replace_all_cell_begin$

    lda #0
    sta csv_replace_all_col

csv_replace_all_next_row$:
    inc csv_replace_all_row0
    bne +
    inc csv_replace_all_row1
+
    lda csv_replace_all_row1
    cmp csv_rows1
    bcs +
    jmp csv_replace_all_cell_begin$
+
    bne csv_replace_all_done$
    lda csv_replace_all_row0
    cmp csv_rows0
    bcs +
    jmp csv_replace_all_cell_begin$
+

csv_replace_all_done$:
    lda #0
    sta csv_replace_all_active
    sta csv_find_start_pos0
    sta csv_find_start_pos1

    jsr ensure_current_visible
    jsr csvprintview
    jsr highlight_current_cell
    jsr csv_replace_draw
    jsr busycursor_off
    rts


csv_replace_prompt_text:
    .ascii "rEPLACE: "
    .byte 0
csv_replace_all_text:
    .ascii "f7aLL"
    .byte 0


; Execute case-insensitive substring search.
; Scan row-major from current cell, then wrap once to 0,0.
; Find next:
; reuse the previous pattern, but do NOT test the current cell first.
; Start at the following cell and wrap at most once.
; ------------------------------------------------------------
; Vertical Find mode.
; Same selected column only.
; ------------------------------------------------------------

; RETURN in vertical mode: test current cell first, then continue down.
csv_find_execute_vertical:
    lda #0
    sta csv_find_start_pos0
    sta csv_find_start_pos1

    lda csv_find_len
    bne +
    rts
+
    lda csv_current_row0
    sta csv_find_start_row0
    lda csv_current_row1
    sta csv_find_start_row1
    lda csv_current_col
    sta csv_find_start_col
    sta csv_find_col

    lda #0
    sta csv_find_wrapped

    lda csv_current_row0
    sta csv_find_row0
    lda csv_current_row1
    sta csv_find_row1

    jsr csv_find_test_cell
    lda csv_find_match
    beq csv_find_vertical_next_advance
    jmp csv_find_found


; F3: next match downward in same column.
csv_find_execute_next_vertical:
    lda #0
    sta csv_find_start_pos0
    sta csv_find_start_pos1

    lda csv_find_len
    bne +
    jsr csv_find_open
    rts
+
    lda csv_current_row0
    sta csv_find_start_row0
    lda csv_current_row1
    sta csv_find_start_row1
    lda csv_current_col
    sta csv_find_start_col
    sta csv_find_col

    lda #0
    sta csv_find_wrapped

    lda csv_current_row0
    sta csv_find_row0
    lda csv_current_row1
    sta csv_find_row1

csv_find_vertical_next_advance:
    inc csv_find_row0
    bne csv_find_vertical_next_check_end
    inc csv_find_row1

csv_find_vertical_next_check_end:
    lda csv_find_row1
    cmp csv_rows1
    bcc csv_find_vertical_next_check_stop
    bne csv_find_vertical_next_wrap
    lda csv_find_row0
    cmp csv_rows0
    bcc csv_find_vertical_next_check_stop

csv_find_vertical_next_wrap:
    lda csv_find_wrapped
    beq +
    jmp csv_find_not_found
+
    lda #1
    sta csv_find_wrapped
    lda #0
    sta csv_find_row0
    sta csv_find_row1

csv_find_vertical_next_check_stop:
    lda csv_find_wrapped
    beq csv_find_vertical_next_test
    lda csv_find_row1
    cmp csv_find_start_row1
    bne csv_find_vertical_next_test
    lda csv_find_row0
    cmp csv_find_start_row0
    bne csv_find_vertical_next_test
    jmp csv_find_not_found

csv_find_vertical_next_test:
    jsr csv_find_test_cell
    lda csv_find_match
    beq csv_find_vertical_next_advance
    jmp csv_find_found


; F4: previous match upward in same column.
csv_find_execute_previous_vertical:
    lda #0
    sta csv_find_start_pos0
    sta csv_find_start_pos1

    lda csv_find_len
    bne +
    jsr csv_find_open
    rts
+
    lda csv_current_row0
    sta csv_find_start_row0
    lda csv_current_row1
    sta csv_find_start_row1
    lda csv_current_col
    sta csv_find_start_col
    sta csv_find_col

    lda #0
    sta csv_find_wrapped

    lda csv_current_row0
    sta csv_find_row0
    lda csv_current_row1
    sta csv_find_row1

csv_find_vertical_prev_advance:
    lda csv_find_row0
    ora csv_find_row1
    beq csv_find_vertical_prev_wrap

    lda csv_find_row0
    bne +
    dec csv_find_row1
+
    dec csv_find_row0
    jmp csv_find_vertical_prev_check_stop

csv_find_vertical_prev_wrap:
    lda csv_find_wrapped
    beq +
    jmp csv_find_not_found
+
    lda #1
    sta csv_find_wrapped

    ; row = csv_rows - 1
    lda csv_rows0
    sta csv_find_row0
    lda csv_rows1
    sta csv_find_row1
    lda csv_find_row0
    bne +
    dec csv_find_row1
+
    dec csv_find_row0

csv_find_vertical_prev_check_stop:
    lda csv_find_wrapped
    beq csv_find_vertical_prev_test
    lda csv_find_row1
    cmp csv_find_start_row1
    bne csv_find_vertical_prev_test
    lda csv_find_row0
    cmp csv_find_start_row0
    bne csv_find_vertical_prev_test
    jmp csv_find_not_found

csv_find_vertical_prev_test:
    jsr csv_find_test_cell
    lda csv_find_match
    beq csv_find_vertical_prev_advance
    jmp csv_find_found


csv_find_execute_next:
    ; No search text: preserve the old behaviour without showing Busy.
    lda csv_find_len
    beq csv_find_execute_next_dispatch$
    jsr busycursor_on
csv_find_execute_next_dispatch$:
    lda csv_find_vertical
    beq csv_find_execute_next_normal
    jmp csv_find_execute_next_vertical

csv_find_execute_next_normal:
    lda #0
    sta csv_find_start_pos0
    sta csv_find_start_pos1

    lda csv_find_len
    bne +
    jsr csv_find_open
    rts
+
    ; The current match is the stop point for a full wrapped pass.
    lda csv_current_row0
    sta csv_find_start_row0
    lda csv_current_row1
    sta csv_find_start_row1
    lda csv_current_col
    sta csv_find_start_col

    lda #0
    sta csv_find_wrapped

    lda csv_current_row0
    sta csv_find_row0
    lda csv_current_row1
    sta csv_find_row1
    lda csv_current_col
    sta csv_find_col

    ; Reuse the normal scanner starting with its increment step.
    ; This guarantees Find next never returns the same current cell
    ; unless a later implementation supports multiple matches inside
    ; one cell.
    jmp csv_find_advance_cell


csv_find_execute_previous:
    ; No search text: preserve the old behaviour without showing Busy.
    lda csv_find_len
    beq csv_find_execute_previous_dispatch$
    jsr busycursor_on
csv_find_execute_previous_dispatch$:
    lda csv_find_vertical
    beq csv_find_execute_previous_normal
    jmp csv_find_execute_previous_vertical

csv_find_execute_previous_normal:
    lda #0
    sta csv_find_start_pos0
    sta csv_find_start_pos1

    lda csv_find_len
    bne +
    jsr csv_find_open
    rts
+
    lda csv_current_row0
    sta csv_find_start_row0
    lda csv_current_row1
    sta csv_find_start_row1
    lda csv_current_col
    sta csv_find_start_col
    lda #0
    sta csv_find_wrapped
    lda csv_current_row0
    sta csv_find_row0
    lda csv_current_row1
    sta csv_find_row1
    lda csv_current_col
    sta csv_find_col
    jmp csv_find_prev_advance

csv_find_prev_cell_loop:
    jsr csv_find_test_cell
    lda csv_find_match
    beq csv_find_prev_advance
    jmp csv_find_found

csv_find_prev_advance:
    lda csv_find_col
    beq csv_find_prev_row
    dec csv_find_col
    jmp csv_find_prev_check_stop

csv_find_prev_row:
    lda csv_find_row0
    ora csv_find_row1
    beq csv_find_prev_wrap
    lda csv_find_row0
    bne +
    dec csv_find_row1
+
    dec csv_find_row0
    lda csv_maxcols0
    beq csv_find_prev_wrap
    sec
    sbc #1
    sta csv_find_col
    jmp csv_find_prev_check_stop

csv_find_prev_wrap:
    lda csv_find_wrapped
    beq +
    jmp csv_find_not_found
+
    lda #1
    sta csv_find_wrapped
    lda csv_rows0
    sta csv_find_row0
    lda csv_rows1
    sta csv_find_row1
    lda csv_find_row0
    bne +
    dec csv_find_row1
+
    dec csv_find_row0
    lda csv_maxcols0
    bne +
    jmp csv_find_not_found
+
    sec
    sbc #1
    sta csv_find_col

csv_find_prev_check_stop:
    lda csv_find_wrapped
    beq csv_find_prev_cell_loop
    lda csv_find_row1
    cmp csv_find_start_row1
    bne csv_find_prev_cell_loop
    lda csv_find_row0
    cmp csv_find_start_row0
    bne csv_find_prev_cell_loop
    lda csv_find_col
    cmp csv_find_start_col
    beq +
    jmp csv_find_prev_cell_loop
+
    jmp csv_find_not_found


csv_find_execute:
    ; Show Busy only when an actual search is going to run.
    lda csv_find_len
    beq csv_find_execute_dispatch$
    jsr busycursor_on
csv_find_execute_dispatch$:
    lda csv_find_vertical
    beq csv_find_execute_normal
    jmp csv_find_execute_vertical

csv_find_execute_normal:
    lda #0
    sta csv_find_start_pos0
    sta csv_find_start_pos1

    lda csv_find_len
    bne +
    rts
+
    ; Save starting selection.
    lda csv_current_row0
    sta csv_find_start_row0
    lda csv_current_row1
    sta csv_find_start_row1
    lda csv_current_col
    sta csv_find_start_col

    lda #0
    sta csv_find_wrapped

    lda csv_current_row0
    sta csv_find_row0
    lda csv_current_row1
    sta csv_find_row1
    lda csv_current_col
    sta csv_find_col

csv_find_cell_loop:
    jsr csv_find_test_cell
    lda csv_find_match
    beq csv_find_advance_cell
    jmp csv_find_found

csv_find_advance_cell:
    inc csv_find_col

    ; col >= maxcols -> next row, col=0.
    lda csv_maxcols1
    bne csv_find_col_valid
    lda csv_find_col
    cmp csv_maxcols0
    bcc csv_find_col_valid

    lda #0
    sta csv_find_col
    inc csv_find_row0
    bne csv_find_row_check
    inc csv_find_row1

csv_find_row_check:
    lda csv_find_row1
    cmp csv_rows1
    bcc csv_find_col_valid
    bne csv_find_wrap_or_stop
    lda csv_find_row0
    cmp csv_rows0
    bcc csv_find_col_valid

csv_find_wrap_or_stop:
    lda csv_find_wrapped
    bne csv_find_not_found
    lda #1
    sta csv_find_wrapped
    lda #0
    sta csv_find_row0
    sta csv_find_row1
    sta csv_find_col

csv_find_col_valid:
    ; After wrapping, stop when the original start cell is reached again.
    lda csv_find_wrapped
    beq csv_find_cell_loop
    lda csv_find_row1
    cmp csv_find_start_row1
    bne csv_find_cell_loop
    lda csv_find_row0
    cmp csv_find_start_row0
    bne csv_find_cell_loop
    lda csv_find_col
    cmp csv_find_start_col
    bne csv_find_cell_loop
    jmp csv_find_not_found


csv_find_found:
    lda csv_find_row0
    sta csv_current_row0
    lda csv_find_row1
    sta csv_current_row1
    lda csv_find_col
    sta csv_current_col

    lda #1
    sta csv_find_mode

    jsr csv_multiselect_reset_current

    ; Make vertical position visible.
    jsr csv_find_ensure_row_visible
    jsr ensure_current_visible
    jsr csvprintview
    jsr highlight_current_cell
    ; F3/F4 are Find navigation even while Replace is active.
    ; Redraw the active search panel instead of always collapsing
    ; the UI to the one-line Find bar.
    jsr csv_find_redraw_active_panel
    jsr busycursor_off
    rts


csv_find_not_found:
    ; Restore original current selection.
    lda csv_find_start_row0
    sta csv_current_row0
    lda csv_find_start_row1
    sta csv_current_row1
    lda csv_find_start_col
    sta csv_current_col

    lda #0
    sta csv_find_mode
    jsr csvprintview
    jsr csv_multiselect_highlight_all
    jsr busycursor_off
    rts


; Keep a Find/Replace result clearly visible in the grid.
;
; Unlike normal cursor movement, Find deliberately recentres the
; scrollable viewport around every match.  The bottom Find panel
; consumes one screen row; Replace consumes two.  Those rows must
; never be counted as usable CSV rows, otherwise the highlighted
; match can end up hidden underneath the prompt.
csv_find_ensure_row_visible:
    ; Frozen rows are always visible and must not move the viewport.
    lda csv_current_row1
    bne csv_find_row_scrollable$
    lda csv_current_row0
    cmp csv_frozen_rows
    bcs csv_find_row_scrollable$
    rts

csv_find_row_scrollable$:
    ; Number of actually usable SCROLLABLE grid rows:
    ;   runtime_view_rows - frozen_rows - Find/Replace panel rows
    sec
    lda runtime_view_rows
    sbc csv_frozen_rows
    sta csv_find_visible_scroll_rows

    lda csv_replace_mode
    beq csv_find_reserve_find_row$

    ; Replace panel occupies two bottom rows.
    lda csv_find_visible_scroll_rows
    sec
    sbc #2
    bcs csv_find_rows_ready$
    lda #1
    bne csv_find_rows_ready$

csv_find_reserve_find_row$:
    ; Find panel occupies one bottom row.
    lda csv_find_visible_scroll_rows
    sec
    sbc #1
    bcs csv_find_rows_ready$
    lda #1

csv_find_rows_ready$:
    bne +
    lda #1
+
    sta csv_find_visible_scroll_rows

    ; Centre the match: top = current - floor(visible_rows / 2).
    ; csv_find_bottom0 is reused here as the 8-bit half-height.
    lsr a
    sta csv_find_bottom0

    sec
    lda csv_current_row0
    sbc csv_find_bottom0
    sta csv_find_bottom0
    lda csv_current_row1
    sbc #0
    sta csv_find_bottom1
    bcc csv_find_center_clamp_top$

    ; Clamp at the first scrollable CSV row (after frozen rows).
    lda csv_find_bottom1
    bne csv_find_center_nonnegative$
    lda csv_find_bottom0
    cmp csv_frozen_rows
    bcs csv_find_center_nonnegative$

csv_find_center_clamp_top$:
    lda csv_frozen_rows
    sta csv_top_row0
    lda #0
    sta csv_top_row1
    rts

csv_find_center_nonnegative$:

csv_find_store_center$:
    lda csv_find_bottom0
    sta csv_top_row0
    lda csv_find_bottom1
    sta csv_top_row1
    rts



; ============================================================
; Shared CSV field helpers retained in resident KnockCSV.
;
; Sort itself lives in EDIT.PRG, but Find and legacy Fill staging
; also use these small quote-aware/pointer helpers.
; ============================================================

; A = PETSCII byte, returns canonical case-insensitive byte.
csv_sort_casefold:
    cmp #0x41
    bcc csv_sort_casefold_shifted$
    cmp #0x5b
    bcs csv_sort_casefold_shifted$
    clc
    adc #0x20
    rts
csv_sort_casefold_shifted$:
    cmp #0xc1
    bcc csv_sort_casefold_done$
    cmp #0xdb
    bcs csv_sort_casefold_done$
    sec
    sbc #0x60
csv_sort_casefold_done$:
    rts

; Locate csv_current_col in row csv_sort_rowa*.
csv_sort_field_ptr_a:
    lda csv_sort_rowa0
    sta csv_row0
    lda csv_sort_rowa1
    sta csv_row1
    jsr csvrowaddr
    lda attic_addr0
    sta csv_sort_pa0
    lda attic_addr1
    sta csv_sort_pa1
    lda attic_addr2
    sta csv_sort_pa2
    lda attic_addr3
    sta csv_sort_pa3
    lda #0
    sta csv_sort_ca
    sta csv_sort_a_inq
    sta csv_sort_a_qp
    sta csv_sort_a_data
    sta csv_sort_a_end
csv_shared_seek_a$:
    lda csv_sort_ca
    cmp csv_current_col
    beq csv_shared_seek_a_done$
    jsr csv_sort_class_a
    cmp #2
    beq csv_shared_seek_a_missing$
    cmp #1
    bne +
    inc csv_sort_ca
+
    jsr csv_sort_inc_pa
    jmp csv_shared_seek_a$
csv_shared_seek_a_missing$:
    lda #1
    sta csv_sort_a_end
csv_shared_seek_a_done$:
    rts

; Return next logical character from A field in csv_sort_a_char.
csv_sort_next_a:
    lda csv_sort_a_end
    beq +
    rts
+
csv_shared_next_a_loop$:
    jsr csv_sort_class_a
    cmp #1
    beq csv_shared_next_a_end$
    cmp #2
    beq csv_shared_next_a_end$
    cmp #3
    beq csv_shared_next_a_skip$
    ldz #0
    lda [csv_sort_pa0],z
    sta csv_sort_a_char
    jsr csv_sort_inc_pa
    lda #0
    sta csv_sort_a_end
    rts
csv_shared_next_a_skip$:
    jsr csv_sort_inc_pa
    jmp csv_shared_next_a_loop$
csv_shared_next_a_end$:
    lda #1
    sta csv_sort_a_end
    rts

; Quote-aware classifier for A field.
; 0=content, 1=delimiter, 2=end row, 3=quote byte to skip.
csv_sort_class_a:
    lda csv_sort_a_inq
    beq csv_shared_a_out$
    lda csv_sort_a_qp
    beq csv_shared_a_inside$
    ldz #0
    lda [csv_sort_pa0],z
    cmp #0x22
    bne csv_shared_a_close$
    lda #0
    sta csv_sort_a_qp
    lda #0
    rts
csv_shared_a_close$:
    lda #0
    sta csv_sort_a_qp
    sta csv_sort_a_inq
    jmp csv_shared_a_process$
csv_shared_a_inside$:
    ldz #0
    lda [csv_sort_pa0],z
    cmp #0x22
    bne csv_shared_a_content$
    lda #1
    sta csv_sort_a_qp
    lda #3
    rts
csv_shared_a_content$:
    lda #1
    sta csv_sort_a_data
    lda #0
    rts
csv_shared_a_out$:
    ldz #0
    lda [csv_sort_pa0],z
    cmp #0x22
    bne csv_shared_a_process$
    lda csv_sort_a_data
    bne csv_shared_a_content$
    lda #1
    sta csv_sort_a_inq
    lda #3
    rts
csv_shared_a_process$:
    ldz #0
    lda [csv_sort_pa0],z
    cmp csv_delimiter
    beq csv_shared_a_comma$
    cmp #0x0d
    beq csv_shared_a_endrow$
    lda #1
    sta csv_sort_a_data
    lda #0
    rts
csv_shared_a_comma$:
    lda #0
    sta csv_sort_a_data
    lda #1
    rts
csv_shared_a_endrow$:
    lda #2
    rts

csv_sort_inc_pa:
    inc csv_sort_pa0
    bne csv_shared_inc_pa_done$
    inc csv_sort_pa1
    bne csv_shared_inc_pa_done$
    inc csv_sort_pa2
    bne csv_shared_inc_pa_done$
    inc csv_sort_pa3
csv_shared_inc_pa_done$:
    rts

csv_sort_inc_src:
    inc csv_sort_src0
    bne csv_shared_inc_src_done$
    inc csv_sort_src1
    bne csv_shared_inc_src_done$
    inc csv_sort_src2
    bne csv_shared_inc_src_done$
    inc csv_sort_src3
csv_shared_inc_src_done$:
    rts

csv_sort_inc_dst:
    inc csv_sort_dst0
    bne csv_shared_inc_dst_done$
    inc csv_sort_dst1
    bne csv_shared_inc_dst_done$
    inc csv_sort_dst2
    bne csv_shared_inc_dst_done$
    inc csv_sort_dst3
csv_shared_inc_dst_done$:
    rts

; Test current csv_find_row/csv_find_col.
; Reuses the existing quote-aware sort field reader.
csv_find_test_cell:
    lda #0
    sta csv_find_match

    lda csv_find_row0
    sta csv_sort_rowa0
    lda csv_find_row1
    sta csv_sort_rowa1

    lda csv_current_col
    sta csv_find_saved_current_col
    lda csv_find_col
    sta csv_current_col
    jsr csv_sort_field_ptr_a
    lda csv_find_saved_current_col
    sta csv_current_col

    lda csv_sort_a_end
    beq +
    rts
+
    ; For every possible field character position, try pattern.
    ; Replace All can ask us to resume inside the same cell.
    lda csv_find_start_pos0
    sta csv_find_candidate_pos0
    sta csv_find_skip0
    lda csv_find_start_pos1
    sta csv_find_candidate_pos1
    sta csv_find_skip1

    ; Consume logical characters up to requested start position.
csv_find_skip_to_start$:
    lda csv_find_skip0
    ora csv_find_skip1
    beq csv_find_candidate_loop

    jsr csv_sort_next_a
    lda csv_sort_a_end
    beq +
    rts
+
    lda csv_find_skip0
    bne +
    dec csv_find_skip1
+
    dec csv_find_skip0
    jmp csv_find_skip_to_start$

csv_find_candidate_loop:
    jsr csv_find_save_field_state

    ldx #0
csv_find_pattern_loop:
    cpx csv_find_len
    beq csv_find_candidate_success

    jsr csv_sort_next_a
    lda csv_sort_a_end
    bne csv_find_candidate_fail

    ; Case-sensitive mode compares raw PETSCII bytes.
    lda csv_find_case_sensitive
    beq csv_find_compare_folded$

    lda csv_sort_a_char
    sta csv_find_fold_char
    lda csv_find_buf,x
    cmp csv_find_fold_char
    bne csv_find_candidate_fail
    jmp csv_find_compare_ok$

csv_find_compare_folded$:
    lda csv_sort_a_char
    jsr csv_sort_casefold
    sta csv_find_fold_char

    lda csv_find_buf,x
    jsr csv_sort_casefold
    cmp csv_find_fold_char
    bne csv_find_candidate_fail

csv_find_compare_ok$:

    inx
    jmp csv_find_pattern_loop

csv_find_candidate_success:
    lda csv_find_candidate_pos0
    sta csv_find_match_pos0
    lda csv_find_candidate_pos1
    sta csv_find_match_pos1
    lda #1
    sta csv_find_match
    rts

csv_find_candidate_fail:
    jsr csv_find_restore_field_state

    ; Consume exactly one logical char and try again.
    jsr csv_sort_next_a
    lda csv_sort_a_end
    bne +
    inc csv_find_candidate_pos0
    bne csv_find_candidate_loop
    inc csv_find_candidate_pos1
    jmp csv_find_candidate_loop
+
    rts


; Save enough of A-field reader state for candidate restart.
csv_find_save_field_state:
    lda csv_sort_pa0
    sta csv_find_save_pa0
    lda csv_sort_pa1
    sta csv_find_save_pa1
    lda csv_sort_pa2
    sta csv_find_save_pa2
    lda csv_sort_pa3
    sta csv_find_save_pa3
    lda csv_sort_a_inq
    sta csv_find_save_inq
    lda csv_sort_a_qp
    sta csv_find_save_qp
    lda csv_sort_a_data
    sta csv_find_save_data
    lda csv_sort_a_end
    sta csv_find_save_end
    rts

csv_find_restore_field_state:
    lda csv_find_save_pa0
    sta csv_sort_pa0
    lda csv_find_save_pa1
    sta csv_sort_pa1
    lda csv_find_save_pa2
    sta csv_sort_pa2
    lda csv_find_save_pa3
    sta csv_sort_pa3
    lda csv_find_save_inq
    sta csv_sort_a_inq
    lda csv_find_save_qp
    sta csv_sort_a_qp
    lda csv_find_save_data
    sta csv_sort_a_data
    lda csv_find_save_end
    sta csv_sort_a_end
    rts


; Draw the shared Find/Replace navigation/toggle strip at the current
; cursor position. Called at col 48:
;   48..54 F3 NEXT, 56..62 F4 PREV, 64..71 F5 CASE/[CASE],
;   73..79 F7 COL/[COL].
; F9 ALL is intentionally NOT part of this strip: it is drawn only
; on the Replace row.
csv_find_draw_command_strip:
    ldx #0
csv_find_cmd_next_loop$:
    lda csv_find_hint_text,x
    beq csv_find_cmd_prev$
    jsr seam_bsout
    inx
    jmp csv_find_cmd_next_loop$
csv_find_cmd_prev$:
    lda #' '
    jsr seam_bsout
    ldx #0
csv_find_cmd_prev_loop$:
    lda csv_find_prev_hint_text,x
    beq csv_find_cmd_case$
    jsr seam_bsout
    inx
    jmp csv_find_cmd_prev_loop$
csv_find_cmd_case$:
    lda #' '
    jsr seam_bsout
    ldx #0
    lda csv_find_case_sensitive
    beq csv_find_cmd_case_off$
csv_find_cmd_case_on_loop$:
    lda csv_find_case_on_text,x
    beq csv_find_cmd_col$
    jsr seam_bsout
    inx
    jmp csv_find_cmd_case_on_loop$
csv_find_cmd_case_off$:
    lda csv_find_case_off_text,x
    beq csv_find_cmd_col$
    jsr seam_bsout
    inx
    jmp csv_find_cmd_case_off$
csv_find_cmd_col$:
    lda #' '
    jsr seam_bsout
    ldx #0
    lda csv_find_vertical
    beq csv_find_cmd_col_off$
csv_find_cmd_col_on_loop$:
    lda csv_find_vertical_on_text,x
    beq csv_find_cmd_done$
    jsr seam_bsout
    inx
    jmp csv_find_cmd_col_on_loop$
csv_find_cmd_col_off$:
    lda csv_find_vertical_off_text,x
    beq csv_find_cmd_done$
    jsr seam_bsout
    inx
    jmp csv_find_cmd_col_off$
csv_find_cmd_done$:
    rts

csv_find_prompt_text:
    .ascii "fIND: "
    .byte 0
csv_find_hint_text:
    .ascii "f3 next"
    .byte 0
csv_find_prev_hint_text:
    .ascii "f4 prev"
    .byte 0
csv_find_case_off_text:
    .ascii "f5 case "
    .byte 0
csv_find_case_on_text:
    .ascii "f5[case]"
    .byte 0
csv_find_vertical_off_text:
    .ascii "f7 col "
    .byte 0
csv_find_vertical_on_text:
    .ascii "f7[col]"
    .byte 0
csv_find_all_hint_text:
    .ascii "f9 all"
    .byte 0


csv_edit_find_cell:
    lda csv_current_row0
    sta csv_row0
    lda csv_current_row1
    sta csv_row1
    jsr csvrowaddr

    lda #0
    sta csv_edit_scan_col
    jsr csv_scan_reset

csv_edit_find_col_loop:
    lda csv_edit_scan_col
    cmp csv_current_col
    beq csv_edit_found_start

    jsr csv_edit_at_end
    beq +
    jmp csv_edit_found_start
+
    jsr csv_scan_classify
    cmp #2
    beq csv_edit_found_start
    cmp #1
    bne csv_edit_find_next
    inc csv_edit_scan_col

csv_edit_find_next:
    jsr csv_edit_inc_attic
    jmp csv_edit_find_col_loop

csv_edit_found_start:
    lda attic_addr0
    sta csv_edit_start0
    lda attic_addr1
    sta csv_edit_start1
    lda attic_addr2
    sta csv_edit_start2
    lda attic_addr3
    sta csv_edit_start3
    rts


; A = key
csv_edit_handle_key:
    sta csv_edit_key

    ; --------------------------------------------------------
    ; Full-screen Text Mode selection uses Left Shift as a real
    ; selection modifier. The KERNAL, however, encodes:
    ;
    ;   Shift + RIGHT -> KEY_LEFT
    ;   Shift + DOWN  -> KEY_UP
    ;
    ; Remap those two shifted cursor codes back to the PHYSICAL
    ; direction before the normal editor dispatch.
    ; Only long-text mode is affected.
    ; --------------------------------------------------------
    lda csv_edit_long_mode
    beq csv_edit_shift_cursor_remap_done$
    lda csv_key_mod_latch
    and #MODKEY_LSHIFT
    beq csv_edit_shift_cursor_remap_done$

    lda csv_edit_key
    cmp #KEY_LEFT
    bne csv_edit_shift_cursor_check_up$
    lda #KEY_RIGHT
    sta csv_edit_key
    jmp csv_edit_shift_cursor_remap_done$

csv_edit_shift_cursor_check_up$:
    cmp #KEY_UP
    bne csv_edit_shift_cursor_remap_done$
    lda #KEY_DOWN
    sta csv_edit_key

csv_edit_shift_cursor_remap_done$:
    lda csv_edit_key

    ; RETURN may arrive with bit 7 set. Normalize only for this test.
    and #0x7f
    cmp #KEY_RETURN
    bne csv_edit_not_return$

    ; RETURN alone = commit/exit.
    ; MEGA+RETURN = embedded newline.
    ; Use the modifier state latched BEFORE GETIN.
    lda csv_key_mod_latch
    and #MODKEY_MEGA
    beq +
    jmp csv_edit_key_newline
+
    jmp csv_edit_key_commit

csv_edit_not_return$:
    ; --------------------------------------------------------
    ; MEGA65 screen-editor compatible CTRL keys whose PETSCII codes
    ; do not already coincide with normal cursor/DEL/RETURN keys.
    ; --------------------------------------------------------
    lda csv_edit_key

    cmp #CTRL_J_DOWN
    bne +
    jmp csv_edit_key_down$
+
    cmp #CTRL_U_WORD_LEFT
    bne +
    jsr csv_edit_word_left
    rts
+
    cmp #CTRL_W_WORD_RIGHT
    bne +
    jsr csv_edit_word_right
    rts
+
    cmp #CTRL_Z_TAB_LEFT
    bne +
    jsr csv_edit_tab_left
    rts
+
    cmp #CTRL_I_TAB_RIGHT
    bne +
    jsr csv_edit_tab_right
    rts
+
    ; CTRL+P / CTRL+V scroll the long text viewport without moving
    ; the logical cursor. In the short cell editor they do nothing.
    cmp #CTRL_P_SCROLL_DN
    bne +
    lda csv_edit_long_mode
    beq csv_edit_ctrl_handled$
    jsr csv_long_scroll_down
csv_edit_ctrl_handled$:
    rts
+
    cmp #CTRL_V_SCROLL_UP
    bne +
    lda csv_edit_long_mode
    beq csv_edit_ctrl_handled2$
    jsr csv_long_scroll_up
csv_edit_ctrl_handled2$:
    rts
+

    ; HOME ($13): start of current visual/logical line.
    cmp #HOME
    bne +
    jsr csv_edit_home_line
    rts
+

    ; Cursor keys are control codes, never cell text.
    lda csv_edit_key
    cmp #KEY_LEFT
    beq csv_edit_key_left$
    cmp #KEY_RIGHT
    beq csv_edit_key_right$
    cmp #KEY_UP
    bne +
    jmp csv_edit_key_up$
+
    cmp #KEY_DOWN
    bne +
    jmp csv_edit_key_down$
+

    ; Reject / recognize variants with bit 7 normalized.
    and #0x7f
    cmp #(KEY_LEFT & 0x7f)
    beq csv_edit_key_left$
    cmp #(KEY_RIGHT & 0x7f)
    beq csv_edit_key_right$
    cmp #(KEY_UP & 0x7f)
    bne +
    jmp csv_edit_key_up$
+
    cmp #(KEY_DOWN & 0x7f)
    bne +
    jmp csv_edit_key_down$
+

    lda csv_edit_key
    jmp csv_edit_after_cursor_keys$


csv_edit_key_left$:
    lda csv_edit_long_mode
    beq csv_edit_short_left$

    lda csv_key_mod_latch
    and #MODKEY_LSHIFT
    beq csv_edit_long_left_noshift$
    jsr csv_long_selection_prepare_shift
    jmp csv_edit_long_left_ready$
csv_edit_long_left_noshift$:
    jsr csv_long_selection_clear
csv_edit_long_left_ready$:

    lda csv_long_cursor_pos0
    ora csv_long_cursor_pos1
    bne +
    jmp csv_edit_key_done
+

    lda csv_long_cursor_pos0
    bne +
    dec csv_long_cursor_pos1
+
    dec csv_long_cursor_pos0
    lda csv_key_mod_latch
    and #MODKEY_LSHIFT
    beq +
    jsr csv_long_selection_update
+
    lda #0
    sta csv_long_follow_end
    jsr csv_edit_draw
    rts

csv_edit_short_left$:
    lda csv_edit_cursor_pos
    bne +
    jmp csv_edit_key_done
+
    dec csv_edit_cursor_pos
    jsr csv_edit_draw
    rts


csv_edit_key_right$:
    lda csv_edit_long_mode
    beq csv_edit_short_right$

    lda csv_key_mod_latch
    and #MODKEY_LSHIFT
    beq csv_edit_long_right_noshift$
    jsr csv_long_selection_prepare_shift
    jmp csv_edit_long_right_ready$
csv_edit_long_right_noshift$:
    jsr csv_long_selection_clear
csv_edit_long_right_ready$:

    ; cursor < long_len ?
    lda csv_long_cursor_pos1
    cmp csv_edit_long_len1
    bcc csv_edit_long_right_ok$
    beq +
    jmp csv_edit_key_done
+
    lda csv_long_cursor_pos0
    cmp csv_edit_long_len0
    bcc csv_edit_long_right_ok$
    jmp csv_edit_key_done

csv_edit_long_right_ok$:
    inc csv_long_cursor_pos0
    bne +
    inc csv_long_cursor_pos1
+
    lda csv_key_mod_latch
    and #MODKEY_LSHIFT
    beq +
    jsr csv_long_selection_update
+
    lda #0
    sta csv_long_follow_end
    jsr csv_edit_draw
    rts

csv_edit_short_right$:
    lda csv_edit_cursor_pos
    cmp csv_edit_len
    bcc +
    jmp csv_edit_key_done
+
    inc csv_edit_cursor_pos
    jsr csv_edit_draw
    rts


csv_edit_key_up$:
    lda csv_edit_long_mode
    bne +
    jmp csv_edit_key_done
+
    lda csv_key_mod_latch
    and #MODKEY_LSHIFT
    beq csv_edit_long_up_noshift$
    jsr csv_long_selection_prepare_shift
    jmp csv_edit_long_up_move$
csv_edit_long_up_noshift$:
    jsr csv_long_selection_clear
csv_edit_long_up_move$:
    jsr csv_long_cursor_up
    lda csv_key_mod_latch
    and #MODKEY_LSHIFT
    beq +
    jsr csv_long_selection_update
    jsr csv_edit_draw
+
    rts


csv_edit_key_down$:
    lda csv_edit_long_mode
    bne +
    jmp csv_edit_key_done
+
    lda csv_key_mod_latch
    and #MODKEY_LSHIFT
    beq csv_edit_long_down_noshift$
    jsr csv_long_selection_prepare_shift
    jmp csv_edit_long_down_move$
csv_edit_long_down_noshift$:
    jsr csv_long_selection_clear
csv_edit_long_down_move$:
    jsr csv_long_cursor_down
    lda csv_key_mod_latch
    and #MODKEY_LSHIFT
    beq +
    jsr csv_long_selection_update
    jsr csv_edit_draw
+
    rts


csv_edit_after_cursor_keys$:
    lda csv_edit_key
    cmp #KEY_ESC
    bne +
    jmp csv_edit_key_cancel
+
    cmp #KEY_DEL
    bne +
    lda csv_key_mod_latch
    and #MODKEY_SHIFT
    beq csv_edit_del_normal$
    jsr csv_edit_insert_space
    rts
csv_edit_del_normal$:
    jmp csv_edit_key_del
+
    cmp #0x08
    bne +
    jmp csv_edit_key_del
+

    ; Printable PETSCII logical value.
    lda csv_edit_key
    cmp #0x20
    bcs +
    jmp csv_edit_key_done
+

    lda csv_edit_long_mode
    beq csv_edit_key_short_char$

    lda csv_long_sel_active
    beq +
    jsr csv_long_delete_selection
+
    lda csv_edit_key
    jsr csv_long_insert_char
    lda #0
    sta csv_long_follow_end
    jsr csv_edit_draw
    rts

csv_edit_key_short_char$:
    lda csv_edit_len
    cmp #254
    bcc +
    jmp csv_edit_key_done
+

    ; Shift [cursor..len-1] one byte right.
    ldx csv_edit_len
csv_edit_short_insert_shift$:
    cpx csv_edit_cursor_pos
    beq csv_edit_short_insert_store$
    dex
    lda csv_edit_buf,x
    inx
    sta csv_edit_buf,x
    dex
    jmp csv_edit_short_insert_shift$

csv_edit_short_insert_store$:
    ldx csv_edit_cursor_pos
    lda csv_edit_key
    sta csv_edit_buf,x
    inc csv_edit_len
    inc csv_edit_cursor_pos
    jsr csv_edit_draw
csv_edit_key_done:
    rts

; ============================================================
; MEGA65 EDITOR-STYLE NAVIGATION HELPERS
; ============================================================

; Read logical byte at current cursor position into A.
; Caller guarantees cursor < len.
csv_edit_read_cursor_byte:
    lda csv_edit_long_mode
    beq csv_edit_read_cursor_short$

    jsr csv_long_ptr_to_cursor
    ldz #0
    lda [csv_long_ptr0],z
    rts

csv_edit_read_cursor_short$:
    ldx csv_edit_cursor_pos
    lda csv_edit_buf,x
    rts


; Is A whitespace for word navigation? Z=1 yes, Z=0 no.
csv_edit_is_space:
    cmp #' '
    beq csv_edit_space_yes$
    cmp #0x09
    beq csv_edit_space_yes$
    cmp #0x0a
    beq csv_edit_space_yes$
    cmp #0x0d
    beq csv_edit_space_yes$
    lda #1
    rts
csv_edit_space_yes$:
    lda #0
    rts


; ------------------------------------------------------------
; CTRL+U: previous word.
; ------------------------------------------------------------
csv_edit_word_left:
    lda csv_edit_long_mode
    beq csv_edit_word_left_short$

    lda csv_long_cursor_pos0
    ora csv_long_cursor_pos1
    bne +
    rts
+
    ; Move left once, then skip whitespace.
    jsr csv_long_cursor_dec_one
csv_edit_word_left_long_ws$:
    jsr csv_edit_read_cursor_byte
    jsr csv_edit_is_space
    bne csv_edit_word_left_long_word$

    lda csv_long_cursor_pos0
    ora csv_long_cursor_pos1
    beq csv_edit_word_left_redraw$
    jsr csv_long_cursor_dec_one
    jmp csv_edit_word_left_long_ws$

csv_edit_word_left_long_word$:
    ; Move to first character of this word by inspecting previous byte.
    lda csv_long_cursor_pos0
    ora csv_long_cursor_pos1
    beq csv_edit_word_left_redraw$

    jsr csv_long_cursor_dec_one
    jsr csv_edit_read_cursor_byte
    jsr csv_edit_is_space
    beq csv_edit_word_left_long_restore$
    jmp csv_edit_word_left_long_word$

csv_edit_word_left_long_restore$:
    jsr csv_long_cursor_inc_one

csv_edit_word_left_redraw$:
    lda #0
    sta csv_long_follow_end
    jsr csv_edit_draw
    rts


csv_edit_word_left_short$:
    lda csv_edit_cursor_pos
    bne +
    rts
+
    dec csv_edit_cursor_pos

csv_edit_word_left_short_ws$:
    jsr csv_edit_read_cursor_byte
    jsr csv_edit_is_space
    bne csv_edit_word_left_short_word$
    lda csv_edit_cursor_pos
    beq csv_edit_word_left_short_redraw$
    dec csv_edit_cursor_pos
    jmp csv_edit_word_left_short_ws$

csv_edit_word_left_short_word$:
    lda csv_edit_cursor_pos
    beq csv_edit_word_left_short_redraw$
    dec csv_edit_cursor_pos
    jsr csv_edit_read_cursor_byte
    jsr csv_edit_is_space
    beq csv_edit_word_left_short_restore$
    jmp csv_edit_word_left_short_word$

csv_edit_word_left_short_restore$:
    inc csv_edit_cursor_pos
csv_edit_word_left_short_redraw$:
    jsr csv_edit_draw
    rts


; ------------------------------------------------------------
; CTRL+W: next word.
; ------------------------------------------------------------
csv_edit_word_right:
    lda csv_edit_long_mode
    beq csv_edit_word_right_short$

    ; cursor >= len?
    jsr csv_long_cursor_at_end
    bne +
    rts
+
    ; Skip current word/non-space first.
csv_edit_word_right_long_word$:
    jsr csv_edit_read_cursor_byte
    jsr csv_edit_is_space
    beq csv_edit_word_right_long_ws$

    jsr csv_long_cursor_inc_one
    jsr csv_long_cursor_at_end
    beq csv_edit_word_right_long_redraw$
    jmp csv_edit_word_right_long_word$

csv_edit_word_right_long_ws$:
    jsr csv_long_cursor_inc_one
    jsr csv_long_cursor_at_end
    beq csv_edit_word_right_long_redraw$
    jsr csv_edit_read_cursor_byte
    jsr csv_edit_is_space
    beq csv_edit_word_right_long_ws$

csv_edit_word_right_long_redraw$:
    lda #0
    sta csv_long_follow_end
    jsr csv_edit_draw
    rts


csv_edit_word_right_short$:
    lda csv_edit_cursor_pos
    cmp csv_edit_len
    bcc +
    rts
+
csv_edit_word_right_short_word$:
    jsr csv_edit_read_cursor_byte
    jsr csv_edit_is_space
    beq csv_edit_word_right_short_ws$
    inc csv_edit_cursor_pos
    lda csv_edit_cursor_pos
    cmp csv_edit_len
    bcs csv_edit_word_right_short_redraw$
    jmp csv_edit_word_right_short_word$

csv_edit_word_right_short_ws$:
    inc csv_edit_cursor_pos
    lda csv_edit_cursor_pos
    cmp csv_edit_len
    bcs csv_edit_word_right_short_redraw$
    jsr csv_edit_read_cursor_byte
    jsr csv_edit_is_space
    beq csv_edit_word_right_short_ws$

csv_edit_word_right_short_redraw$:
    jsr csv_edit_draw
    rts


; ------------------------------------------------------------
; HOME: beginning of current line.
; For long mode use current wrapped visual-line mapping.
; For short mode scan backward to embedded newline.
; ------------------------------------------------------------
csv_edit_home_line:
    lda csv_edit_long_mode
    beq csv_edit_home_short$

    ; Cursor visual line should already be mapped by last redraw.
    sec
    lda csv_long_cursor_line0
    sbc csv_long_top0
    tax
    lda csv_long_cursor_line1
    sbc csv_long_top1
    bne csv_edit_home_long_done$
    cpx #23
    bcs csv_edit_home_long_done$

    lda csv_long_vis_start_lo,x
    sta csv_long_cursor_pos0
    lda csv_long_vis_start_hi,x
    sta csv_long_cursor_pos1

    lda #0
    sta csv_long_follow_end
    jsr csv_edit_draw
csv_edit_home_long_done$:
    rts

csv_edit_home_short$:
    lda csv_edit_cursor_pos
    beq csv_edit_home_short_done$
csv_edit_home_short_loop$:
    dec csv_edit_cursor_pos
    jsr csv_edit_read_cursor_byte
    cmp #0x0a
    beq csv_edit_home_short_after_nl$
    cmp #0x0d
    beq csv_edit_home_short_after_nl$
    lda csv_edit_cursor_pos
    bne csv_edit_home_short_loop$
    jmp csv_edit_home_short_redraw$

csv_edit_home_short_after_nl$:
    inc csv_edit_cursor_pos
csv_edit_home_short_redraw$:
    jsr csv_edit_draw
csv_edit_home_short_done$:
    rts


; ------------------------------------------------------------
; CTRL+I / CTRL+Z: default tab stops every 8 columns.
; Uses the current visual cursor column. Movement is constrained
; to the current visual/logical line.
; ------------------------------------------------------------
csv_edit_tab_right:
    lda csv_edit_long_mode
    beq csv_edit_tab_right_short$

    lda csv_long_cursor_col
    lsr a
    lsr a
    lsr a
    clc
    adc #1
    asl a
    asl a
    asl a
    sta csv_edit_tab_target
    cmp #80
    bcc +
    lda #79
    sta csv_edit_tab_target
+
    ; current visible line start/len
    sec
    lda csv_long_cursor_line0
    sbc csv_long_top0
    tax
    lda csv_long_cursor_line1
    sbc csv_long_top1
    bne csv_edit_tab_done$
    cpx #23
    bcs csv_edit_tab_done$

    lda csv_edit_tab_target
    cmp csv_long_vis_len,x
    bcc +
    lda csv_long_vis_len,x
+
    clc
    adc csv_long_vis_start_lo,x
    sta csv_long_cursor_pos0
    lda csv_long_vis_start_hi,x
    adc #0
    sta csv_long_cursor_pos1
    lda #0
    sta csv_long_follow_end
    jsr csv_edit_draw
csv_edit_tab_done$:
    rts


csv_edit_tab_right_short$:
    ; Derive current column within explicit logical line.
    jsr csv_edit_short_line_bounds
    sec
    lda csv_edit_cursor_pos
    sbc csv_edit_short_line_start
    sta csv_edit_tab_col

    lsr a
    lsr a
    lsr a
    clc
    adc #1
    asl a
    asl a
    asl a
    sta csv_edit_tab_target

    clc
    adc csv_edit_short_line_start
    cmp csv_edit_short_line_end
    bcc +
    lda csv_edit_short_line_end
+
    sta csv_edit_cursor_pos
    jsr csv_edit_draw
    rts


csv_edit_tab_left:
    lda csv_edit_long_mode
    beq csv_edit_tab_left_short$

    lda csv_long_cursor_col
    beq csv_edit_tab_left_done$
    sec
    sbc #1
    lsr a
    lsr a
    lsr a
    asl a
    asl a
    asl a
    sta csv_edit_tab_target

    sec
    lda csv_long_cursor_line0
    sbc csv_long_top0
    tax
    lda csv_long_cursor_line1
    sbc csv_long_top1
    bne csv_edit_tab_left_done$
    cpx #23
    bcs csv_edit_tab_left_done$

    clc
    lda csv_long_vis_start_lo,x
    adc csv_edit_tab_target
    sta csv_long_cursor_pos0
    lda csv_long_vis_start_hi,x
    adc #0
    sta csv_long_cursor_pos1
    lda #0
    sta csv_long_follow_end
    jsr csv_edit_draw
    rts


csv_edit_tab_left_short$:
    jsr csv_edit_short_line_bounds
    sec
    lda csv_edit_cursor_pos
    sbc csv_edit_short_line_start
    beq csv_edit_tab_left_done$

    sec
    sbc #1
    lsr a
    lsr a
    lsr a
    asl a
    asl a
    asl a
    clc
    adc csv_edit_short_line_start
    sta csv_edit_cursor_pos
    jsr csv_edit_draw

csv_edit_tab_left_done$:
    rts


; Compute short logical line [start,end] around cursor.
csv_edit_short_line_bounds:
    lda csv_edit_cursor_pos
    sta csv_edit_short_line_start
csv_edit_short_find_start$:
    lda csv_edit_short_line_start
    beq csv_edit_short_start_done$
    dec csv_edit_short_line_start
    ldx csv_edit_short_line_start
    lda csv_edit_buf,x
    cmp #0x0a
    beq csv_edit_short_start_after$
    cmp #0x0d
    beq csv_edit_short_start_after$
    jmp csv_edit_short_find_start$
csv_edit_short_start_after$:
    inc csv_edit_short_line_start
csv_edit_short_start_done$:

    lda csv_edit_cursor_pos
    sta csv_edit_short_line_end
csv_edit_short_find_end$:
    lda csv_edit_short_line_end
    cmp csv_edit_len
    bcs csv_edit_short_end_done$
    tax
    lda csv_edit_buf,x
    cmp #0x0a
    beq csv_edit_short_end_done$
    cmp #0x0d
    beq csv_edit_short_end_done$
    inc csv_edit_short_line_end
    jmp csv_edit_short_find_end$
csv_edit_short_end_done$:
    rts


; SHIFT+INST/DEL inserts a blank at current cursor.
csv_edit_insert_space:
    lda csv_edit_long_mode
    beq csv_edit_insert_space_short$
    lda #' '
    jsr csv_long_insert_char
    lda #0
    sta csv_long_follow_end
    jsr csv_edit_draw
    rts

csv_edit_insert_space_short$:
    lda csv_edit_len
    cmp #254
    bcc +
    rts
+
    ldx csv_edit_len
csv_edit_insert_space_shift$:
    cpx csv_edit_cursor_pos
    beq csv_edit_insert_space_store$
    dex
    lda csv_edit_buf,x
    inx
    sta csv_edit_buf,x
    dex
    jmp csv_edit_insert_space_shift$
csv_edit_insert_space_store$:
    ldx csv_edit_cursor_pos
    lda #' '
    sta csv_edit_buf,x
    inc csv_edit_len
    inc csv_edit_cursor_pos
    jsr csv_edit_draw
    rts


; ------------------------------------------------------------
; Small 16-bit long-cursor helpers.
; ------------------------------------------------------------
csv_long_cursor_inc_one:
    inc csv_long_cursor_pos0
    bne +
    inc csv_long_cursor_pos1
+
    rts

csv_long_cursor_dec_one:
    lda csv_long_cursor_pos0
    bne +
    dec csv_long_cursor_pos1
+
    dec csv_long_cursor_pos0
    rts

; A=0 when cursor == end, A=1 otherwise.
csv_long_cursor_at_end:
    lda csv_long_cursor_pos1
    cmp csv_edit_long_len1
    bne csv_long_cursor_not_end$
    lda csv_long_cursor_pos0
    cmp csv_edit_long_len0
    bne csv_long_cursor_not_end$
    lda #0
    rts
csv_long_cursor_not_end$:
    lda #1
    rts


csv_edit_key_newline:
    lda csv_edit_long_mode
    beq csv_edit_key_newline_short$

    lda csv_long_sel_active
    beq +
    jsr csv_long_delete_selection
+
    lda #0x0a
    jsr csv_long_insert_char
    lda #0
    sta csv_long_follow_end
    jsr csv_edit_draw
    rts

csv_edit_key_newline_short$:
    lda csv_edit_len
    cmp #254
    bcc +
    jmp csv_edit_key_done
+

    ldx csv_edit_len
csv_edit_short_nl_shift$:
    cpx csv_edit_cursor_pos
    beq csv_edit_short_nl_store$
    dex
    lda csv_edit_buf,x
    inx
    sta csv_edit_buf,x
    dex
    jmp csv_edit_short_nl_shift$

csv_edit_short_nl_store$:
    ldx csv_edit_cursor_pos
    lda #0x0a
    sta csv_edit_buf,x
    inc csv_edit_len
    inc csv_edit_cursor_pos
    jsr csv_edit_draw
    rts


csv_edit_key_del:
    lda csv_edit_long_mode
    beq csv_edit_key_del_short$

    lda csv_long_sel_active
    beq csv_edit_long_del_one$
    jsr csv_long_delete_selection
    lda #0
    sta csv_long_follow_end
    jsr csv_edit_draw
    rts

csv_edit_long_del_one$:
    lda csv_long_cursor_pos0
    ora csv_long_cursor_pos1
    bne +
    jmp csv_edit_key_done
+

    jsr csv_long_backspace
    lda #0
    sta csv_long_follow_end
    jsr csv_edit_draw
    rts

csv_edit_key_del_short$:
    lda csv_edit_cursor_pos
    bne +
    jmp csv_edit_key_done
+

    dec csv_edit_cursor_pos
    ldx csv_edit_cursor_pos

csv_edit_short_del_shift$:
    inx
    cpx csv_edit_len
    bcs csv_edit_short_del_done$
    lda csv_edit_buf,x
    dex
    sta csv_edit_buf,x
    inx
    jmp csv_edit_short_del_shift$

csv_edit_short_del_done$:
    dec csv_edit_len
    jsr csv_edit_draw
    rts

csv_edit_key_cancel:
    lda #0
    sta csv_edit_mode
    jsr csvprintview
    jsr highlight_current_cell
    rts

csv_edit_key_commit:
    jsr csv_edit_commit
    lda #0
    sta csv_edit_mode

    ; Ricostruisce offsets righe e larghezze colonne.
    jsr csvindex
    jsr ensure_current_visible
    jsr csvprintview
    jsr highlight_current_cell
    rts


; Disegna il buffer direttamente nella cella corrente.
; La cella resta highlighted; "_" indica il punto di inserimento.
csv_edit_draw:
    lda csv_edit_long_mode
    beq csv_edit_draw_short$
    jmp csv_long_draw_preview

csv_edit_draw_short$:
    jsr calc_current_screen_row
    jsr calc_current_cell_geometry

    ; Physical first screen row of the selected CSV cell.
    lda current_screen_row
    clc
    adc #VIEW_TOP
    sta csv_edit_draw_row

    ; --------------------------------------------------------
    ; Calculate longest logical line in the edit buffer.
    ; Newline $0A/$0D resets the current line length.
    ; --------------------------------------------------------
    lda #0
    sta csv_edit_line_len
    sta csv_edit_longest_line

    ldx #0
csv_edit_width_scan$:
    cpx csv_edit_len
    beq csv_edit_width_scan_done$

    lda csv_edit_buf,x
    cmp #0x0a
    beq csv_edit_width_newline$
    cmp #0x0d
    beq csv_edit_width_newline$

    inc csv_edit_line_len
    lda csv_edit_line_len
    cmp csv_edit_longest_line
    bcc csv_edit_width_scan_next$
    sta csv_edit_longest_line

csv_edit_width_scan_next$:
    inx
    jmp csv_edit_width_scan$

csv_edit_width_newline$:
    lda #0
    sta csv_edit_line_len
    inx
    jmp csv_edit_width_scan$

csv_edit_width_scan_done$:
    ; desired width = longest line + one cursor position.
    lda csv_edit_longest_line
    cmp #72
    bcc csv_edit_width_add_cursor$
    lda #73
    jmp csv_edit_width_have_desired$

csv_edit_width_add_cursor$:
    clc
    adc #1

csv_edit_width_have_desired$:
    sta csv_edit_desired_width

    ; Never smaller than the normal grid cell.
    lda current_cell_width
    cmp csv_edit_desired_width
    bcc csv_edit_width_use_desired$
    sta csv_edit_desired_width

csv_edit_width_use_desired$:
    ; Maximum usable data-area width is 73 chars (screen x=6..78).
    lda csv_edit_desired_width
    cmp #74
    bcc csv_edit_width_clamped$
    lda #73
    sta csv_edit_desired_width

csv_edit_width_clamped$:
    ; Sticky during this edit session: grow, never shrink.
    lda csv_edit_window_width
    cmp csv_edit_desired_width
    bcs csv_edit_width_sticky_ok$
    lda csv_edit_desired_width
    sta csv_edit_window_width

csv_edit_width_sticky_ok$:
    ; --------------------------------------------------------
    ; Choose overlay X.
    ;
    ; Prefer the real cell X. If window would extend beyond x=78,
    ; shift the temporary editor left. Never move left of DATA_START_X.
    ; --------------------------------------------------------
    lda current_cell_x
    sta csv_edit_draw_x

    clc
    adc csv_edit_window_width
    cmp #80
    bcc csv_edit_x_ready$
    beq csv_edit_x_ready$

    ; x = 79 - width  (rightmost used column = 78)
    lda #79
    sec
    sbc csv_edit_window_width
    cmp #DATA_START_X
    bcs csv_edit_store_shifted_x$
    lda #DATA_START_X

csv_edit_store_shifted_x$:
    sta csv_edit_draw_x

csv_edit_x_ready$:
    ; Count logical lines = 1 + number of embedded LF bytes.
    lda #1
    sta csv_edit_draw_lines
    ldx #0

csv_edit_count_lines$:
    cpx csv_edit_len
    beq csv_edit_count_lines_done$
    lda csv_edit_buf,x
    cmp #0x0a
    bne +
    inc csv_edit_draw_lines
+
    inx
    jmp csv_edit_count_lines$

csv_edit_count_lines_done$:
    ; Clamp the temporary editor to remaining screen rows.
    lda runtime_screen_rows
    sec
    sbc csv_edit_draw_row
    sta csv_edit_draw_max_lines

    lda csv_edit_draw_lines
    cmp csv_edit_draw_max_lines
    bcc +
    lda csv_edit_draw_max_lines
    sta csv_edit_draw_lines
+

    jsr seam_apply_selection_style

    ; --------------------------------------------------------
    ; Clear temporary edit rectangle.
    ; width = csv_edit_window_width
    ; height = logical line count
    ; --------------------------------------------------------
    lda #0
    sta csv_edit_draw_line

csv_edit_clear_lines$:
    lda csv_edit_draw_line
    cmp csv_edit_draw_lines
    bcs csv_edit_clear_done$

    clc
    adc csv_edit_draw_row
    tax
    ldy csv_edit_draw_x
    clc
    jsr seam_plot

    lda csv_edit_window_width
    sta csv_edit_draw_remaining

csv_edit_clear_line_chars$:
    lda #' '
    jsr seam_bsout
    dec csv_edit_draw_remaining
    bne csv_edit_clear_line_chars$

    inc csv_edit_draw_line
    jmp csv_edit_clear_lines$

csv_edit_clear_done$:
    ; --------------------------------------------------------
    ; Draw logical buffer. LF starts a new physical line.
    ; One character is reserved for the insertion cursor.
    ; --------------------------------------------------------
    lda #0
    sta csv_edit_draw_line
    sta csv_edit_draw_col

    lda csv_edit_draw_row
    tax
    ldy csv_edit_draw_x
    clc
    jsr seam_plot

    lda #0
    sta csv_edit_cursor_draw_valid

    ldx #0

csv_edit_draw_text$:
    ; Cursor is a position BETWEEN characters.
    cpx csv_edit_cursor_pos
    bne +
    lda csv_edit_draw_line
    sta csv_edit_cursor_draw_line
    lda csv_edit_draw_col
    sta csv_edit_cursor_draw_col
    lda #1
    sta csv_edit_cursor_draw_valid
+
    cpx csv_edit_len
    beq csv_edit_draw_cursor$

    lda csv_edit_buf,x
    cmp #0x0a
    beq csv_edit_draw_newline$
    cmp #0x0d
    beq csv_edit_draw_newline$

    lda csv_edit_draw_col
    clc
    adc #1
    cmp csv_edit_window_width
    bcs csv_edit_draw_skip_char$

    lda csv_edit_buf,x
    jsr seam_bsout
    inc csv_edit_draw_col

csv_edit_draw_skip_char$:
    inx
    jmp csv_edit_draw_text$


csv_edit_draw_newline$:
    inc csv_edit_draw_line

    ; X is logical-buffer index: preserve it while TAX is used for PLOT.
    stx csv_edit_draw_saved_x

    lda csv_edit_draw_line
    cmp csv_edit_draw_lines
    bcs csv_edit_draw_newline_restore$

    lda #0
    sta csv_edit_draw_col

    lda csv_edit_draw_row
    clc
    adc csv_edit_draw_line
    tax
    ldy csv_edit_draw_x
    clc
    jsr seam_plot

csv_edit_draw_newline_restore$:
    ldx csv_edit_draw_saved_x
    inx
    jmp csv_edit_draw_text$


csv_edit_draw_cursor$:
    ; Cursor at EOF may not have been seen inside the loop yet.
    lda csv_edit_cursor_draw_valid
    bne +
    lda csv_edit_draw_line
    sta csv_edit_cursor_draw_line
    lda csv_edit_draw_col
    sta csv_edit_cursor_draw_col
+
    lda csv_edit_cursor_draw_line
    cmp csv_edit_draw_lines
    bcs csv_edit_draw_done$

    lda csv_edit_cursor_draw_col
    cmp csv_edit_window_width
    bcc +
    lda csv_edit_window_width
    sec
    sbc #1
    sta csv_edit_cursor_draw_col
+
    lda csv_edit_draw_row
    clc
    adc csv_edit_cursor_draw_line
    sta csv_edit_cursor_hw_row

    lda csv_edit_draw_x
    clc
    adc csv_edit_cursor_draw_col
    tax

    lda csv_edit_cursor_hw_row
    jsr seam_cursor_blink_at

csv_edit_draw_done$:
    jsr seam_apply_cell_style
    rts


; ============================================================
; LONG CELL ENGINE
; ============================================================

; Reset long logical pointer to $08400000.

; ============================================================
; LONG TEXT MODE: character selection + private clipboard
;
; Shift + cursor extends a 16-bit linear selection.
; MEGA+C / X / V operate on the selected logical bytes directly.
; Clipboard storage reuses SORTTMP_BASE ($08300000), which is safe
; while the full-screen editor is active (Sort/Fill cannot run).
; ============================================================

csv_long_selection_clear:
    lda #0
    sta csv_long_sel_active
    rts

; Called BEFORE a Shift+cursor movement.
csv_long_selection_prepare_shift:
    lda csv_long_sel_active
    bne csv_long_selection_prepare_done$
    lda csv_long_cursor_pos0
    sta csv_long_sel_anchor0
    lda csv_long_cursor_pos1
    sta csv_long_sel_anchor1
csv_long_selection_prepare_done$:
    rts

; Rebuild normalized [start,end) from anchor and current cursor.
csv_long_selection_update:
    lda csv_long_cursor_pos1
    cmp csv_long_sel_anchor1
    bcc csv_long_selection_cursor_first$
    bne csv_long_selection_anchor_first$
    lda csv_long_cursor_pos0
    cmp csv_long_sel_anchor0
    bcc csv_long_selection_cursor_first$

csv_long_selection_anchor_first$:
    lda csv_long_sel_anchor0
    sta csv_long_sel_start0
    lda csv_long_sel_anchor1
    sta csv_long_sel_start1
    lda csv_long_cursor_pos0
    sta csv_long_sel_end0
    lda csv_long_cursor_pos1
    sta csv_long_sel_end1
    jmp csv_long_selection_check_empty$

csv_long_selection_cursor_first$:
    lda csv_long_cursor_pos0
    sta csv_long_sel_start0
    lda csv_long_cursor_pos1
    sta csv_long_sel_start1
    lda csv_long_sel_anchor0
    sta csv_long_sel_end0
    lda csv_long_sel_anchor1
    sta csv_long_sel_end1

csv_long_selection_check_empty$:
    lda csv_long_sel_start0
    cmp csv_long_sel_end0
    bne csv_long_selection_nonempty$
    lda csv_long_sel_start1
    cmp csv_long_sel_end1
    bne csv_long_selection_nonempty$
    lda #0
    sta csv_long_sel_active
    rts
csv_long_selection_nonempty$:
    lda #1
    sta csv_long_sel_active
    rts


; Normalize range and compute length = end-start.
csv_long_selection_get_len:
    jsr csv_long_selection_update
    lda csv_long_sel_active
    bne +
    lda #0
    sta csv_long_sel_len0
    sta csv_long_sel_len1
    rts
+
    sec
    lda csv_long_sel_end0
    sbc csv_long_sel_start0
    sta csv_long_sel_len0
    lda csv_long_sel_end1
    sbc csv_long_sel_start1
    sta csv_long_sel_len1
    rts


; Build csv_edit_src = LONGEDIT_BASE + selection start.
csv_long_src_to_sel_start:
    lda #LONGEDIT_BASE0
    clc
    adc csv_long_sel_start0
    sta csv_edit_src0
    lda #LONGEDIT_BASE1
    adc csv_long_sel_start1
    sta csv_edit_src1
    lda #LONGEDIT_BASE2
    adc #0
    sta csv_edit_src2
    lda #LONGEDIT_BASE3
    adc #0
    sta csv_edit_src3
    rts

; Build csv_edit_dst = LONGEDIT_BASE + selection start.
csv_long_dst_to_sel_start:
    lda #LONGEDIT_BASE0
    clc
    adc csv_long_sel_start0
    sta csv_edit_dst0
    lda #LONGEDIT_BASE1
    adc csv_long_sel_start1
    sta csv_edit_dst1
    lda #LONGEDIT_BASE2
    adc #0
    sta csv_edit_dst2
    lda #LONGEDIT_BASE3
    adc #0
    sta csv_edit_dst3
    rts

; Build csv_edit_src = LONGEDIT_BASE + selection end.
csv_long_src_to_sel_end:
    lda #LONGEDIT_BASE0
    clc
    adc csv_long_sel_end0
    sta csv_edit_src0
    lda #LONGEDIT_BASE1
    adc csv_long_sel_end1
    sta csv_edit_src1
    lda #LONGEDIT_BASE2
    adc #0
    sta csv_edit_src2
    lda #LONGEDIT_BASE3
    adc #0
    sta csv_edit_src3
    rts

; Build csv_edit_dst = LONGEDIT_BASE + cursor.
csv_long_dst_to_cursor:
    lda #LONGEDIT_BASE0
    clc
    adc csv_long_cursor_pos0
    sta csv_edit_dst0
    lda #LONGEDIT_BASE1
    adc csv_long_cursor_pos1
    sta csv_edit_dst1
    lda #LONGEDIT_BASE2
    adc #0
    sta csv_edit_dst2
    lda #LONGEDIT_BASE3
    adc #0
    sta csv_edit_dst3
    rts


csv_long_clip_copy:
    jsr csv_long_selection_get_len
    lda csv_long_sel_active
    bne +
    rts
+
    lda csv_long_sel_len0
    sta csv_long_clip_len0
    lda csv_long_sel_len1
    sta csv_long_clip_len1

    jsr csv_long_src_to_sel_start

    lda #SORTTMP_BASE0
    sta csv_edit_dst0
    lda #SORTTMP_BASE1
    sta csv_edit_dst1
    lda #SORTTMP_BASE2
    sta csv_edit_dst2
    lda #SORTTMP_BASE3
    sta csv_edit_dst3

    lda csv_long_clip_len0
    sta csv_long_rem0
    lda csv_long_clip_len1
    sta csv_long_rem1

csv_long_clip_copy_loop$:
    lda csv_long_rem0
    ora csv_long_rem1
    beq csv_long_clip_copy_done$

    ldz #0
    lda [csv_edit_src0],z
    sta [csv_edit_dst0],z
    jsr csv_edit_inc_src
    jsr csv_edit_inc_dst

    lda csv_long_rem0
    bne +
    dec csv_long_rem1
+
    dec csv_long_rem0
    jmp csv_long_clip_copy_loop$

csv_long_clip_copy_done$:
    lda #1
    sta csv_long_clip_valid
    rts


; Delete current selection and place cursor at selection start.
csv_long_delete_selection:
    jsr csv_long_selection_get_len
    lda csv_long_sel_active
    bne +
    rts
+
    ; dst = start, src = end
    jsr csv_long_dst_to_sel_start
    jsr csv_long_src_to_sel_end

    ; end pointer = LONGEDIT_BASE + logical length
    jsr csv_long_ptr_to_end

csv_long_delete_selection_loop$:
    lda csv_edit_src0
    cmp csv_long_ptr0
    bne csv_long_delete_selection_copy$
    lda csv_edit_src1
    cmp csv_long_ptr1
    bne csv_long_delete_selection_copy$
    lda csv_edit_src2
    cmp csv_long_ptr2
    bne csv_long_delete_selection_copy$
    lda csv_edit_src3
    cmp csv_long_ptr3
    beq csv_long_delete_selection_shift_done$

csv_long_delete_selection_copy$:
    ldz #0
    lda [csv_edit_src0],z
    sta [csv_edit_dst0],z
    jsr csv_edit_inc_src
    jsr csv_edit_inc_dst
    jmp csv_long_delete_selection_loop$

csv_long_delete_selection_shift_done$:
    sec
    lda csv_edit_long_len0
    sbc csv_long_sel_len0
    sta csv_edit_long_len0
    lda csv_edit_long_len1
    sbc csv_long_sel_len1
    sta csv_edit_long_len1

    lda csv_long_sel_start0
    sta csv_long_cursor_pos0
    lda csv_long_sel_start1
    sta csv_long_cursor_pos1
    lda #0
    sta csv_long_sel_active
    rts


csv_long_clip_cut:
    jsr csv_long_selection_get_len
    lda csv_long_sel_active
    bne +
    rts
+
    jsr csv_long_clip_copy
    jsr csv_long_delete_selection
    lda #0
    sta csv_long_follow_end
    jsr csv_edit_draw
    rts


csv_long_clip_paste:
    lda csv_long_clip_valid
    bne +
    rts
+
    ; Calculate final length BEFORE changing the document, so a paste
    ; that would exceed 8191 bytes never destroys the current selection.
    lda csv_edit_long_len0
    sta csv_long_newlen0
    lda csv_edit_long_len1
    sta csv_long_newlen1

    lda csv_long_sel_active
    beq csv_long_clip_paste_add_len$
    jsr csv_long_selection_get_len
    sec
    lda csv_long_newlen0
    sbc csv_long_sel_len0
    sta csv_long_newlen0
    lda csv_long_newlen1
    sbc csv_long_sel_len1
    sta csv_long_newlen1

csv_long_clip_paste_add_len$:
    clc
    lda csv_long_newlen0
    adc csv_long_clip_len0
    sta csv_long_newlen0
    lda csv_long_newlen1
    adc csv_long_clip_len1
    sta csv_long_newlen1

    lda csv_long_newlen1
    cmp #0x20
    bcc csv_long_clip_paste_capacity_ok$
    ; 0x2000 or above would exceed the 8191-byte logical buffer.
    rts

csv_long_clip_paste_capacity_ok$:
    ; Replacement is now guaranteed to fit.
    lda csv_long_sel_active
    beq +
    jsr csv_long_delete_selection
+
    ; src = old end.
    jsr csv_long_ptr_to_end
    lda csv_long_ptr0
    sta csv_edit_src0
    lda csv_long_ptr1
    sta csv_edit_src1
    lda csv_long_ptr2
    sta csv_edit_src2
    lda csv_long_ptr3
    sta csv_edit_src3

    ; dst = new end.
    lda #LONGEDIT_BASE0
    clc
    adc csv_long_newlen0
    sta csv_edit_dst0
    lda #LONGEDIT_BASE1
    adc csv_long_newlen1
    sta csv_edit_dst1
    lda #LONGEDIT_BASE2
    adc #0
    sta csv_edit_dst2
    lda #LONGEDIT_BASE3
    adc #0
    sta csv_edit_dst3

    ; cursor pointer in csv_long_ptr.
    jsr csv_long_ptr_to_cursor

csv_long_clip_shift_right$:
    lda csv_edit_src0
    cmp csv_long_ptr0
    bne csv_long_clip_shift_copy$
    lda csv_edit_src1
    cmp csv_long_ptr1
    bne csv_long_clip_shift_copy$
    lda csv_edit_src2
    cmp csv_long_ptr2
    bne csv_long_clip_shift_copy$
    lda csv_edit_src3
    cmp csv_long_ptr3
    beq csv_long_clip_shift_done$

csv_long_clip_shift_copy$:
    jsr csv_edit_dec_src
    jsr csv_edit_dec_dst
    ldz #0
    lda [csv_edit_src0],z
    sta [csv_edit_dst0],z
    jmp csv_long_clip_shift_right$

csv_long_clip_shift_done$:
    ; Copy clipboard at cursor.
    lda #SORTTMP_BASE0
    sta csv_edit_src0
    lda #SORTTMP_BASE1
    sta csv_edit_src1
    lda #SORTTMP_BASE2
    sta csv_edit_src2
    lda #SORTTMP_BASE3
    sta csv_edit_src3

    jsr csv_long_dst_to_cursor

    lda csv_long_clip_len0
    sta csv_long_rem0
    lda csv_long_clip_len1
    sta csv_long_rem1

csv_long_clip_paste_loop$:
    lda csv_long_rem0
    ora csv_long_rem1
    beq csv_long_clip_paste_store_len$

    ldz #0
    lda [csv_edit_src0],z
    sta [csv_edit_dst0],z
    jsr csv_edit_inc_src
    jsr csv_edit_inc_dst

    lda csv_long_rem0
    bne +
    dec csv_long_rem1
+
    dec csv_long_rem0
    jmp csv_long_clip_paste_loop$

csv_long_clip_paste_store_len$:
    lda csv_long_newlen0
    sta csv_edit_long_len0
    lda csv_long_newlen1
    sta csv_edit_long_len1

    clc
    lda csv_long_cursor_pos0
    adc csv_long_clip_len0
    sta csv_long_cursor_pos0
    lda csv_long_cursor_pos1
    adc csv_long_clip_len1
    sta csv_long_cursor_pos1

    lda #0
    sta csv_long_sel_active
    sta csv_long_follow_end
    jsr csv_edit_draw
csv_long_clip_paste_done$:
    rts


; Paint the visible selected character range after the text itself has
; been rendered. Screen attributes only are changed; text bytes stay put.
csv_long_draw_selection:
    lda csv_long_sel_active
    bne +
    rts
+
    jsr csv_long_selection_get_len
    lda csv_long_sel_active
    bne +
    rts
+
    lda #0
    sta csv_long_sel_line

csv_long_draw_selection_line$:
    lda csv_long_sel_line
    cmp #23
    bcc +
    rts
+
    ; Stop once top + visible index reaches total visual lines.
    clc
    adc csv_long_top0
    sta csv_long_sel_visual0
    lda csv_long_top1
    adc #0
    sta csv_long_sel_visual1

    lda csv_long_sel_visual1
    cmp csv_long_total1
    bcc csv_long_sel_line_exists$
    bne csv_long_draw_selection_done$
    lda csv_long_sel_visual0
    cmp csv_long_total0
    bcc csv_long_sel_line_exists$
csv_long_draw_selection_done$:
    rts

csv_long_sel_line_exists$:
    ldx csv_long_sel_line

    ; line_start
    lda csv_long_vis_start_lo,x
    sta csv_long_sel_line_start0
    lda csv_long_vis_start_hi,x
    sta csv_long_sel_line_start1

    ; line_end = start + visible logical length.
    clc
    lda csv_long_sel_line_start0
    adc csv_long_vis_len,x
    sta csv_long_sel_line_end0
    lda csv_long_sel_line_start1
    adc #0
    sta csv_long_sel_line_end1

    ; intersection start = max(selection start, line start)
    lda csv_long_sel_start1
    cmp csv_long_sel_line_start1
    bcc csv_long_sel_use_line_start$
    bne csv_long_sel_use_sel_start$
    lda csv_long_sel_start0
    cmp csv_long_sel_line_start0
    bcc csv_long_sel_use_line_start$

csv_long_sel_use_sel_start$:
    lda csv_long_sel_start0
    sta csv_long_sel_isect_start0
    lda csv_long_sel_start1
    sta csv_long_sel_isect_start1
    jmp csv_long_sel_have_isect_start$

csv_long_sel_use_line_start$:
    lda csv_long_sel_line_start0
    sta csv_long_sel_isect_start0
    lda csv_long_sel_line_start1
    sta csv_long_sel_isect_start1

csv_long_sel_have_isect_start$:
    ; intersection end = min(selection end, line end)
    lda csv_long_sel_end1
    cmp csv_long_sel_line_end1
    bcc csv_long_sel_use_sel_end$
    bne csv_long_sel_use_line_end$
    lda csv_long_sel_end0
    cmp csv_long_sel_line_end0
    bcc csv_long_sel_use_sel_end$
    beq csv_long_sel_use_sel_end$

csv_long_sel_use_line_end$:
    lda csv_long_sel_line_end0
    sta csv_long_sel_isect_end0
    lda csv_long_sel_line_end1
    sta csv_long_sel_isect_end1
    jmp csv_long_sel_have_isect_end$

csv_long_sel_use_sel_end$:
    lda csv_long_sel_end0
    sta csv_long_sel_isect_end0
    lda csv_long_sel_end1
    sta csv_long_sel_isect_end1

csv_long_sel_have_isect_end$:
    ; Empty intersection when end <= start.
    lda csv_long_sel_isect_end1
    cmp csv_long_sel_isect_start1
    bcc csv_long_sel_next_line$
    bne csv_long_sel_nonempty_line$
    lda csv_long_sel_isect_end0
    cmp csv_long_sel_isect_start0
    bcc csv_long_sel_next_line$
    beq csv_long_sel_next_line$

csv_long_sel_nonempty_line$:
    ; Select highlight style first: this routine uses X internally.
    jsr seam_apply_selection_style

    ; X = intersection_start - line_start (0..79)
    sec
    lda csv_long_sel_isect_start0
    sbc csv_long_sel_line_start0
    tax

    ; Y = intersection_end - intersection_start (1..80)
    sec
    lda csv_long_sel_isect_end0
    sbc csv_long_sel_isect_start0
    tay

    ; A = physical screen row.
    lda csv_long_sel_line
    clc
    adc #VIEW_TOP
    jsr seam_fill_attr_span

csv_long_sel_next_line$:
    inc csv_long_sel_line
    jmp csv_long_draw_selection_line$


csv_long_ptr_reset:
    lda #LONGEDIT_BASE0
    sta csv_long_ptr0
    lda #LONGEDIT_BASE1
    sta csv_long_ptr1
    lda #LONGEDIT_BASE2
    sta csv_long_ptr2
    lda #LONGEDIT_BASE3
    sta csv_long_ptr3
    rts

csv_long_ptr_inc:
    inc csv_long_ptr0
    bne csv_long_ptr_inc_done$
    inc csv_long_ptr1
    bne csv_long_ptr_inc_done$
    inc csv_long_ptr2
    bne csv_long_ptr_inc_done$
    inc csv_long_ptr3
csv_long_ptr_inc_done$:
    rts


; A = byte. Insert at 16-bit logical cursor position.
csv_long_insert_char:
    sta csv_long_append_byte

    ; capacity 8191
    lda csv_edit_long_len1
    cmp #0x1f
    bcc csv_long_insert_capacity_ok$
    beq +
    jmp csv_long_insert_done$
+
    lda csv_edit_long_len0
    cmp #0xff
    bne +
    jmp csv_long_insert_done$
+

csv_long_insert_capacity_ok$:
    ; cursor absolute pointer in csv_long_ptr
    jsr csv_long_ptr_to_cursor

    ; src = base + len
    jsr csv_long_ptr_to_end
    lda csv_long_ptr0
    sta csv_edit_src0
    lda csv_long_ptr1
    sta csv_edit_src1
    lda csv_long_ptr2
    sta csv_edit_src2
    lda csv_long_ptr3
    sta csv_edit_src3

    ; dst = src + 1
    lda csv_edit_src0
    sta csv_edit_dst0
    lda csv_edit_src1
    sta csv_edit_dst1
    lda csv_edit_src2
    sta csv_edit_dst2
    lda csv_edit_src3
    sta csv_edit_dst3
    jsr csv_edit_inc_dst

    ; cursor pointer again for compare
    jsr csv_long_ptr_to_cursor

csv_long_insert_shift$:
    ; if src == cursor, stop: slot at cursor is now free.
    lda csv_edit_src0
    cmp csv_long_ptr0
    bne csv_long_insert_copy$
    lda csv_edit_src1
    cmp csv_long_ptr1
    bne csv_long_insert_copy$
    lda csv_edit_src2
    cmp csv_long_ptr2
    bne csv_long_insert_copy$
    lda csv_edit_src3
    cmp csv_long_ptr3
    beq csv_long_insert_store$

csv_long_insert_copy$:
    jsr csv_edit_dec_src
    jsr csv_edit_dec_dst
    ldz #0
    lda [csv_edit_src0],z
    sta [csv_edit_dst0],z
    jmp csv_long_insert_shift$

csv_long_insert_store$:
    ldz #0
    lda csv_long_append_byte
    sta [csv_long_ptr0],z

    inc csv_edit_long_len0
    bne +
    inc csv_edit_long_len1
+
    inc csv_long_cursor_pos0
    beq +
    jmp csv_long_insert_done$
+
    inc csv_long_cursor_pos1
csv_long_insert_done$:
    rts


; Backspace one byte before the long cursor.
csv_long_backspace:
    ; cursor > 0 guaranteed by caller.
    lda csv_long_cursor_pos0
    bne +
    dec csv_long_cursor_pos1
+
    dec csv_long_cursor_pos0

    ; dst = base + new cursor
    jsr csv_long_ptr_to_cursor
    lda csv_long_ptr0
    sta csv_edit_dst0
    lda csv_long_ptr1
    sta csv_edit_dst1
    lda csv_long_ptr2
    sta csv_edit_dst2
    lda csv_long_ptr3
    sta csv_edit_dst3

    ; src = dst + 1
    lda csv_edit_dst0
    sta csv_edit_src0
    lda csv_edit_dst1
    sta csv_edit_src1
    lda csv_edit_dst2
    sta csv_edit_src2
    lda csv_edit_dst3
    sta csv_edit_src3
    jsr csv_edit_inc_src

    ; end pointer = base + len
    jsr csv_long_ptr_to_end

csv_long_backspace_shift$:
    ; stop when src == old end
    lda csv_edit_src0
    cmp csv_long_ptr0
    bne csv_long_backspace_copy$
    lda csv_edit_src1
    cmp csv_long_ptr1
    bne csv_long_backspace_copy$
    lda csv_edit_src2
    cmp csv_long_ptr2
    bne csv_long_backspace_copy$
    lda csv_edit_src3
    cmp csv_long_ptr3
    beq csv_long_backspace_done_shift$

csv_long_backspace_copy$:
    ldz #0
    lda [csv_edit_src0],z
    sta [csv_edit_dst0],z
    jsr csv_edit_inc_src
    jsr csv_edit_inc_dst
    jmp csv_long_backspace_shift$

csv_long_backspace_done_shift$:
    lda csv_edit_long_len0
    bne +
    dec csv_edit_long_len1
+
    dec csv_edit_long_len0
    rts


; csv_long_ptr = LONGEDIT_BASE + logical cursor.
csv_long_ptr_to_cursor:
    jsr csv_long_ptr_reset
    clc
    lda csv_long_ptr0
    adc csv_long_cursor_pos0
    sta csv_long_ptr0
    lda csv_long_ptr1
    adc csv_long_cursor_pos1
    sta csv_long_ptr1
    lda csv_long_ptr2
    adc #0
    sta csv_long_ptr2
    lda csv_long_ptr3
    adc #0
    sta csv_long_ptr3
    rts


; A = byte. Append at logical long-buffer end.
csv_long_append_char:
    sta csv_long_append_byte

    ; capacity 8191 bytes
    lda csv_edit_long_len1
    cmp #0x1f
    bcc csv_long_append_ok$
    bne csv_long_append_done$
    lda csv_edit_long_len0
    cmp #0xff
    beq csv_long_append_done$

csv_long_append_ok$:
    jsr csv_long_ptr_to_end
    ldz #0
    lda csv_long_append_byte
    sta [csv_long_ptr0],z

    inc csv_edit_long_len0
    bne csv_long_append_done$
    inc csv_edit_long_len1
csv_long_append_done$:
    rts


; csv_long_ptr = LONGEDIT_BASE + logical len.
csv_long_ptr_to_end:
    jsr csv_long_ptr_reset
    clc
    lda csv_long_ptr0
    adc csv_edit_long_len0
    sta csv_long_ptr0
    lda csv_long_ptr1
    adc csv_edit_long_len1
    sta csv_long_ptr1
    lda csv_long_ptr2
    adc #0
    sta csv_long_ptr2
    lda csv_long_ptr3
    adc #0
    sta csv_long_ptr3
    rts


; ------------------------------------------------------------
; Minimal long-cell preview used until the full-screen editor lands.
; It proves the 16-bit engine is active without truncating the buffer.
; ------------------------------------------------------------
csv_long_draw_preview:
    ; Compatibility entry used by csv_edit_draw.
    jmp csv_long_draw_fullscreen


; ------------------------------------------------------------
; Long text editor viewport: screen rows 2..49, columns 0..79.
; Word-wrap is performed at 80 characters, preferring the last
; space already present in the line buffer.
; ------------------------------------------------------------
csv_long_draw_fullscreen:
    ; Clear the 80x48 text-editor area.
    jsr seam_apply_textedit_style

    lda #VIEW_TOP
    sta csv_long_clear_row

csv_long_clear_rows$:
    lda csv_long_clear_row
    cmp runtime_screen_rows
    bcs csv_long_clear_done$

    tax
    ldy #0
    clc
    jsr seam_plot

    lda #80
    sta csv_long_clear_count
csv_long_clear_chars$:
    lda #' '
    jsr seam_bsout
    dec csv_long_clear_count
    bne csv_long_clear_chars$

    inc csv_long_clear_row
    jmp csv_long_clear_rows$

csv_long_clear_done$:
    ; Scanner state.
    jsr csv_long_ptr_reset

    lda csv_edit_long_len0
    sta csv_long_rem0
    lda csv_edit_long_len1
    sta csv_long_rem1

    lda #0
    sta csv_long_line_len
    sta csv_long_visual0
    sta csv_long_visual1
    sta csv_long_last_newline
    sta csv_long_cursor_col
    sta csv_long_line_start0
    sta csv_long_line_start1
    sta csv_long_cursor_found

    lda #0xff
    sta csv_long_last_space


; Fetch/process the current Attic byte.
csv_long_render_scan$:
    lda csv_long_rem0
    ora csv_long_rem1
    bne +
    jmp csv_long_render_eof$
+

    ldz #0
    lda [csv_long_ptr0],z
    sta csv_long_current_char

    cmp #0x0a
    bne +
    jmp csv_long_explicit_newline$
+
    cmp #0x0d
    bne +
    jmp csv_long_explicit_newline$
+

    lda #0
    sta csv_long_last_newline

    ; If line buffer is already full, wrap BEFORE consuming current char.
    lda csv_long_line_len
    cmp #80
    bcc csv_long_add_current$

    lda csv_long_last_space
    cmp #0xff
    beq csv_long_wrap_hard$
    beq csv_long_wrap_hard$

    ; A space at position 0 is not a useful wrap point.
    lda csv_long_last_space
    beq csv_long_wrap_hard$

    ; Emit text before last space.
    sta csv_long_emit_len
    jsr csv_long_emit_line

    ; Next visual line starts after the wrapping space.
    lda csv_long_last_space
    clc
    adc #1
    jsr csv_long_add_a_to_line_start

    ; Shift bytes after the wrapping space to linebuf[0].
    lda csv_long_last_space
    clc
    adc #1
    tay
    ldx #0

csv_long_shift_remainder$:
    cpy #80
    bcs csv_long_shift_done$
    lda csv_long_linebuf,y
    sta csv_long_linebuf,x
    iny
    inx
    jmp csv_long_shift_remainder$

csv_long_shift_done$:
    stx csv_long_line_len
    jsr csv_long_recompute_space
    jmp csv_long_render_scan$


csv_long_wrap_hard$:
    lda #80
    sta csv_long_emit_len
    jsr csv_long_emit_line

    lda #80
    jsr csv_long_add_a_to_line_start

    lda #0
    sta csv_long_line_len
    lda #0xff
    sta csv_long_last_space
    jmp csv_long_render_scan$


csv_long_add_current$:
    ldx csv_long_line_len
    lda csv_long_current_char
    sta csv_long_linebuf,x

    cmp #' '
    bne +
    stx csv_long_last_space
+
    inc csv_long_line_len

    jsr csv_long_ptr_inc
    jsr csv_long_dec_rem
    jmp csv_long_render_scan$


csv_long_explicit_newline$:
    ; Emit current line, including an empty one.
    lda csv_long_line_len
    sta csv_long_emit_len
    jsr csv_long_emit_line

    lda csv_long_line_len
    clc
    adc #1
    jsr csv_long_add_a_to_line_start

    lda #0
    sta csv_long_line_len
    lda #0xff
    sta csv_long_last_space
    lda #1
    sta csv_long_last_newline

    jsr csv_long_ptr_inc
    jsr csv_long_dec_rem
    jmp csv_long_render_scan$


csv_long_render_eof$:
    ; Place append cursor at the logical end.
    lda csv_long_line_len
    cmp #80
    bne csv_long_eof_not_full$

    ; Full final line: cursor belongs to a fresh visual line.
    lda #80
    sta csv_long_emit_len
    jsr csv_long_emit_line

    lda #0
    sta csv_long_emit_len
    jsr csv_long_emit_line
    jmp csv_long_render_finish$


csv_long_eof_not_full$:
    lda csv_long_line_len
    bne csv_long_eof_have_text$

    ; Empty document or document ending with explicit newline:
    ; create the empty cursor line.
    lda csv_long_visual0
    ora csv_long_visual1
    beq csv_long_eof_empty_line$

    lda csv_long_last_newline
    beq csv_long_render_finish$

csv_long_eof_empty_line$:
    lda #0
    sta csv_long_emit_len
    jsr csv_long_emit_line
    jmp csv_long_render_finish$


csv_long_eof_have_text$:
    lda csv_long_line_len
    sta csv_long_emit_len
    jsr csv_long_emit_line


csv_long_render_finish$:
    ; total visual lines = current visual counter.
    lda csv_long_visual0
    sta csv_long_total0
    lda csv_long_visual1
    sta csv_long_total1

    ; Follow append cursor after entering/editing.
    lda csv_long_follow_end
    beq csv_long_render_no_follow$

    lda #0
    sta csv_long_follow_end

    ; desired_top = max(total - 23, 0)
    lda csv_long_total1
    bne csv_long_follow_sub$
    lda csv_long_total0
    cmp #23
    bcs csv_long_follow_sub$

    lda #0
    sta csv_long_desired_top0
    sta csv_long_desired_top1
    jmp csv_long_follow_compare$

csv_long_follow_sub$:
    sec
    lda csv_long_total0
    sbc #23
    sta csv_long_desired_top0
    lda csv_long_total1
    sbc #0
    sta csv_long_desired_top1

csv_long_follow_compare$:
    lda csv_long_top0
    cmp csv_long_desired_top0
    bne csv_long_follow_apply$
    lda csv_long_top1
    cmp csv_long_desired_top1
    beq csv_long_render_no_follow$

csv_long_follow_apply$:
    lda csv_long_desired_top0
    sta csv_long_top0
    lda csv_long_desired_top1
    sta csv_long_top1
    jmp csv_long_draw_fullscreen


csv_long_render_no_follow$:
    ; has_more = total > top + 23
    clc
    lda csv_long_top0
    adc #23
    sta csv_long_limit0
    lda csv_long_top1
    adc #0
    sta csv_long_limit1

    lda #0
    sta csv_long_has_more

    lda csv_long_total1
    cmp csv_long_limit1
    bcc csv_long_draw_cursor$
    bne csv_long_set_more$
    lda csv_long_total0
    cmp csv_long_limit0
    bcc csv_long_draw_cursor$
    beq csv_long_draw_cursor$

csv_long_set_more$:
    lda #1
    sta csv_long_has_more


csv_long_draw_cursor$:
    ; Paint character selection after text rendering, before cursor blink.
    jsr csv_long_draw_selection
    jsr seam_apply_textedit_style

    ; cursor_line must be inside [top, top+23).
    sec
    lda csv_long_cursor_line0
    sbc csv_long_top0
    sta csv_long_offset
    lda csv_long_cursor_line1
    sbc csv_long_top1
    bne csv_long_draw_done$

    lda csv_long_offset
    cmp #23
    bcs csv_long_draw_done$

    clc
    adc #VIEW_TOP
    tax

    lda csv_long_cursor_col
    cmp #80
    bcc +
    lda #79
+
    tay
    ; Hardware blink cursor at VIEW_TOP+offset, cursor_col.
    ; No character is inserted into screen RAM.
    stx csv_edit_cursor_hw_row
    sty csv_edit_cursor_hw_col

    lda csv_edit_cursor_hw_row
    ldx csv_edit_cursor_hw_col
    jsr seam_cursor_blink_at

csv_long_draw_done$:
    jsr seam_apply_cell_style
    rts


; ------------------------------------------------------------
; Emit one wrapped visual line.
; csv_long_emit_len = number of bytes from linebuf to draw.
; Always increments the 16-bit visual-line counter.
; ------------------------------------------------------------
csv_long_emit_line:
    ; If logical cursor lies inside this visual line, record its
    ; visual line/column before drawing.
    jsr csv_long_maybe_place_cursor

    ; Store visible-line mapping for UP/DOWN navigation.
    jsr csv_long_store_visible_line

    ; offset = visual - top, if visible.
    sec
    lda csv_long_visual0
    sbc csv_long_top0
    sta csv_long_offset
    lda csv_long_visual1
    sbc csv_long_top1
    bne csv_long_emit_advance$

    lda csv_long_offset
    cmp #23
    bcs csv_long_emit_advance$

    clc
    adc #VIEW_TOP
    tax
    ldy #0
    clc
    jsr seam_plot

    ldx #0
csv_long_emit_chars$:
    cpx csv_long_emit_len
    beq csv_long_emit_advance$
    lda csv_long_linebuf,x
    jsr seam_bsout
    inx
    jmp csv_long_emit_chars$

csv_long_emit_advance$:
    inc csv_long_visual0
    bne +
    inc csv_long_visual1
+
    rts


; Recompute last-space index for the shifted remainder.
csv_long_recompute_space:
    lda #0xff
    sta csv_long_last_space

    ldx #0
csv_long_recompute_loop$:
    cpx csv_long_line_len
    beq csv_long_recompute_done$
    lda csv_long_linebuf,x
    cmp #' '
    bne +
    stx csv_long_last_space
+
    inx
    jmp csv_long_recompute_loop$
csv_long_recompute_done$:
    rts


; ------------------------------------------------------------
; Cursor / visual-line mapping helpers.
; ------------------------------------------------------------
csv_long_maybe_place_cursor:
    lda csv_long_cursor_found
    beq +
    rts
+
    ; cursor >= line_start ?
    lda csv_long_cursor_pos1
    cmp csv_long_line_start1
    bcc csv_long_place_no$
    bne csv_long_place_check_end$
    lda csv_long_cursor_pos0
    cmp csv_long_line_start0
    bcc csv_long_place_no$

csv_long_place_check_end$:
    ; end = line_start + emit_len
    clc
    lda csv_long_line_start0
    adc csv_long_emit_len
    sta csv_long_tmp_end0
    lda csv_long_line_start1
    adc #0
    sta csv_long_tmp_end1

    ; cursor <= end ?
    lda csv_long_cursor_pos1
    cmp csv_long_tmp_end1
    bcc csv_long_place_yes$
    bne csv_long_place_no$
    lda csv_long_cursor_pos0
    cmp csv_long_tmp_end0
    bcc csv_long_place_yes$
    bne csv_long_place_no$

csv_long_place_yes$:
    lda csv_long_visual0
    sta csv_long_cursor_line0
    lda csv_long_visual1
    sta csv_long_cursor_line1

    sec
    lda csv_long_cursor_pos0
    sbc csv_long_line_start0
    sta csv_long_cursor_col

    lda #1
    sta csv_long_cursor_found
csv_long_place_no$:
    rts


; A = 8-bit delta to add to 16-bit logical line start.
csv_long_add_a_to_line_start:
    clc
    adc csv_long_line_start0
    sta csv_long_line_start0
    lda csv_long_line_start1
    adc #0
    sta csv_long_line_start1
    rts


; Save mapping for currently visible visual lines.
csv_long_store_visible_line:
    sec
    lda csv_long_visual0
    sbc csv_long_top0
    sta csv_long_offset
    lda csv_long_visual1
    sbc csv_long_top1
    bne csv_long_store_line_done$

    lda csv_long_offset
    cmp #23
    bcs csv_long_store_line_done$

    tax
    lda csv_long_line_start0
    sta csv_long_vis_start_lo,x
    lda csv_long_line_start1
    sta csv_long_vis_start_hi,x
    lda csv_long_emit_len
    sta csv_long_vis_len,x

csv_long_store_line_done$:
    rts


; Move cursor one visual line up, preserving preferred column.
csv_long_cursor_up:
    lda csv_long_cursor_line0
    ora csv_long_cursor_line1
    bne +
    rts
+
    lda csv_long_cursor_col
    sta csv_long_goal_col

    ; target line = cursor_line - 1
    lda csv_long_cursor_line0
    sta csv_long_target_line0
    lda csv_long_cursor_line1
    sta csv_long_target_line1
    lda csv_long_target_line0
    bne +
    dec csv_long_target_line1
+
    dec csv_long_target_line0

    jsr csv_long_move_to_target_line
    rts


; Move cursor one visual line down if target exists.
csv_long_cursor_down:
    lda csv_long_cursor_col
    sta csv_long_goal_col

    lda csv_long_cursor_line0
    sta csv_long_target_line0
    lda csv_long_cursor_line1
    sta csv_long_target_line1
    inc csv_long_target_line0
    bne +
    inc csv_long_target_line1
+
    ; target < total ?
    lda csv_long_target_line1
    cmp csv_long_total1
    bcc csv_long_down_ok$
    bne csv_long_down_done$
    lda csv_long_target_line0
    cmp csv_long_total0
    bcs csv_long_down_done$

csv_long_down_ok$:
    jsr csv_long_move_to_target_line
csv_long_down_done$:
    rts


csv_long_move_to_target_line:
    ; Ensure target is visible. If above, set top=target.
    lda csv_long_target_line1
    cmp csv_long_top1
    bcc csv_long_target_above$
    bne csv_long_target_check_below$
    lda csv_long_target_line0
    cmp csv_long_top0
    bcc csv_long_target_above$

csv_long_target_check_below$:
    ; limit = top + 23; target must be < limit.
    clc
    lda csv_long_top0
    adc #23
    sta csv_long_limit0
    lda csv_long_top1
    adc #0
    sta csv_long_limit1

    lda csv_long_target_line1
    cmp csv_long_limit1
    bcc csv_long_target_visible$
    bne csv_long_target_below$
    lda csv_long_target_line0
    cmp csv_long_limit0
    bcc csv_long_target_visible$

csv_long_target_below$:
    ; top = target - 22
    sec
    lda csv_long_target_line0
    sbc #22
    sta csv_long_top0
    lda csv_long_target_line1
    sbc #0
    sta csv_long_top1
    jsr csv_long_draw_fullscreen
    jmp csv_long_target_visible$

csv_long_target_above$:
    lda csv_long_target_line0
    sta csv_long_top0
    lda csv_long_target_line1
    sta csv_long_top1
    jsr csv_long_draw_fullscreen

csv_long_target_visible$:
    ; index = target - top (0..22)
    sec
    lda csv_long_target_line0
    sbc csv_long_top0
    tax

    lda csv_long_goal_col
    cmp csv_long_vis_len,x
    bcc +
    lda csv_long_vis_len,x
+
    sta csv_long_target_col

    ; cursor = line_start[index] + target_col
    clc
    lda csv_long_vis_start_lo,x
    adc csv_long_target_col
    sta csv_long_cursor_pos0
    lda csv_long_vis_start_hi,x
    adc #0
    sta csv_long_cursor_pos1

    lda #0
    sta csv_long_follow_end
    jsr csv_long_draw_fullscreen
    rts


; ------------------------------------------------------------
; Vertical scrolling of long full-screen editor.
; ------------------------------------------------------------
csv_long_scroll_up:
    lda #0
    sta csv_long_follow_end

    lda csv_long_top0
    ora csv_long_top1
    beq csv_long_scroll_up_done$

    lda csv_long_top0
    bne +
    dec csv_long_top1
+
    dec csv_long_top0
    jsr csv_long_draw_fullscreen
csv_long_scroll_up_done$:
    rts


csv_long_scroll_down:
    lda #0
    sta csv_long_follow_end

    lda csv_long_has_more
    bne +
    rts
+
    inc csv_long_top0
    bne +
    inc csv_long_top1
+
    jsr csv_long_draw_fullscreen
    rts


; ------------------------------------------------------------
; Serialize long logical buffer to $08404000.
; lengths are 16 bit.
; ------------------------------------------------------------
csv_long_serialize:
    lda #0
    sta csv_long_need_quotes
    sta csv_long_serial_len0
    sta csv_long_serial_len1

    jsr csv_long_ptr_reset
    lda csv_edit_long_len0
    sta csv_long_rem0
    lda csv_edit_long_len1
    sta csv_long_rem1

csv_long_ser_scan$:
    lda csv_long_rem0
    ora csv_long_rem1
    beq csv_long_ser_scan_done$

    ldz #0
    lda [csv_long_ptr0],z
    cmp csv_delimiter
    beq csv_long_ser_need$
    cmp #0x22
    beq csv_long_ser_need$
    cmp #0x0a
    beq csv_long_ser_need$
    cmp #0x0d
    beq csv_long_ser_need$

    jsr csv_long_ptr_inc
    jsr csv_long_dec_rem
    jmp csv_long_ser_scan$

csv_long_ser_need$:
    lda #1
    sta csv_long_need_quotes

csv_long_ser_scan_done$:
    jsr csv_long_ser_ptr_reset

    lda csv_long_need_quotes
    beq csv_long_ser_body_init$
    lda #0x22
    jsr csv_long_ser_append

csv_long_ser_body_init$:
    jsr csv_long_ptr_reset
    lda csv_edit_long_len0
    sta csv_long_rem0
    lda csv_edit_long_len1
    sta csv_long_rem1

csv_long_ser_body$:
    lda csv_long_rem0
    ora csv_long_rem1
    beq csv_long_ser_body_done$

    ldz #0
    lda [csv_long_ptr0],z
    sta csv_long_append_byte

    cmp #0x22
    bne csv_long_ser_one$

    lda #0x22
    jsr csv_long_ser_append
    lda #0x22
    jsr csv_long_ser_append
    jmp csv_long_ser_advance$

csv_long_ser_one$:
    lda csv_long_append_byte
    jsr csv_long_ser_append

csv_long_ser_advance$:
    jsr csv_long_ptr_inc
    jsr csv_long_dec_rem
    jmp csv_long_ser_body$

csv_long_ser_body_done$:
    lda csv_long_need_quotes
    beq csv_long_ser_done$
    lda #0x22
    jsr csv_long_ser_append
csv_long_ser_done$:
    rts


csv_long_ser_ptr_reset:
    lda #LONGSER_BASE0
    sta csv_long_ser_ptr0
    lda #LONGSER_BASE1
    sta csv_long_ser_ptr1
    lda #LONGSER_BASE2
    sta csv_long_ser_ptr2
    lda #LONGSER_BASE3
    sta csv_long_ser_ptr3
    rts

csv_long_ser_ptr_inc:
    inc csv_long_ser_ptr0
    bne csv_long_ser_ptr_inc_done$
    inc csv_long_ser_ptr1
    bne csv_long_ser_ptr_inc_done$
    inc csv_long_ser_ptr2
    bne csv_long_ser_ptr_inc_done$
    inc csv_long_ser_ptr3
csv_long_ser_ptr_inc_done$:
    rts

; A byte to append, saturating below 16 KB.
csv_long_ser_append:
    sta csv_long_append_byte

    lda csv_long_serial_len1
    cmp #0x3f
    bcc csv_long_ser_append_ok$
    bne csv_long_ser_append_done$
    lda csv_long_serial_len0
    cmp #0xff
    beq csv_long_ser_append_done$

csv_long_ser_append_ok$:
    ldz #0
    lda csv_long_append_byte
    sta [csv_long_ser_ptr0],z
    jsr csv_long_ser_ptr_inc

    inc csv_long_serial_len0
    bne csv_long_ser_append_done$
    inc csv_long_serial_len1
csv_long_ser_append_done$:
    rts


csv_long_dec_rem:
    lda csv_long_rem0
    bne +
    dec csv_long_rem1
+
    dec csv_long_rem0
    rts


; ------------------------------------------------------------
; Commit long serialized value back into raw CSV.
; ------------------------------------------------------------
csv_long_commit:
    jsr csv_long_serialize

    ; Compare new serialized len with old raw len.
    lda csv_long_serial_len1
    cmp csv_edit_long_raw1
    bcc csv_long_commit_shrink$
    bne csv_long_commit_grow$

    lda csv_long_serial_len0
    cmp csv_edit_long_raw0
    bcc csv_long_commit_shrink$
    beq csv_long_commit_write$

csv_long_commit_grow$:
    ; delta = new - old
    sec
    lda csv_long_serial_len0
    sbc csv_edit_long_raw0
    sta csv_long_delta0
    lda csv_long_serial_len1
    sbc csv_edit_long_raw1
    sta csv_long_delta1

    jsr csv_long_shift_right
    jsr csv_long_size_add_delta
    jmp csv_long_commit_write$

csv_long_commit_shrink$:
    ; delta = old - new
    sec
    lda csv_edit_long_raw0
    sbc csv_long_serial_len0
    sta csv_long_delta0
    lda csv_edit_long_raw1
    sbc csv_long_serial_len1
    sta csv_long_delta1

    jsr csv_long_shift_left
    jsr csv_long_size_sub_delta

csv_long_commit_write$:
    ; dst = original cell start
    lda csv_edit_start0
    sta csv_edit_ptr0
    lda csv_edit_start1
    sta csv_edit_ptr1
    lda csv_edit_start2
    sta csv_edit_ptr2
    lda csv_edit_start3
    sta csv_edit_ptr3

    jsr csv_long_ser_ptr_reset
    lda csv_long_serial_len0
    sta csv_long_rem0
    lda csv_long_serial_len1
    sta csv_long_rem1

csv_long_commit_write_loop$:
    lda csv_long_rem0
    ora csv_long_rem1
    beq csv_long_commit_done$

    ldz #0
    lda [csv_long_ser_ptr0],z
    sta [csv_edit_ptr0],z

    jsr csv_long_ser_ptr_inc
    jsr csv_edit_inc_ptr
    jsr csv_long_dec_rem
    jmp csv_long_commit_write_loop$

csv_long_commit_done$:
    rts


; Shift raw file right by 16-bit delta.
csv_long_shift_right:
    jsr csv_edit_make_file_end_to_src
    jsr csv_edit_dec_src

    lda csv_edit_src0
    sta csv_edit_dst0
    lda csv_edit_src1
    sta csv_edit_dst1
    lda csv_edit_src2
    sta csv_edit_dst2
    lda csv_edit_src3
    sta csv_edit_dst3

    jsr csv_long_add_delta_to_dst

csv_long_shift_right_loop$:
    jsr csv_edit_src_before_cell_end
    beq +
    rts
+
    ldz #0
    lda [csv_edit_src0],z
    sta [csv_edit_dst0],z

    jsr csv_edit_src_equals_cell_end
    bne +
    rts
+
    jsr csv_edit_dec_src
    jsr csv_edit_dec_dst
    jmp csv_long_shift_right_loop$


; Shift raw file left by 16-bit delta.
; src = old delimiter; dst = start + new serialized length.
csv_long_shift_left:
    lda csv_edit_end0
    sta csv_edit_src0
    lda csv_edit_end1
    sta csv_edit_src1
    lda csv_edit_end2
    sta csv_edit_src2
    lda csv_edit_end3
    sta csv_edit_src3

    lda csv_edit_start0
    sta csv_edit_dst0
    lda csv_edit_start1
    sta csv_edit_dst1
    lda csv_edit_start2
    sta csv_edit_dst2
    lda csv_edit_start3
    sta csv_edit_dst3

    ; dst += new serialized len
    clc
    lda csv_edit_dst0
    adc csv_long_serial_len0
    sta csv_edit_dst0
    lda csv_edit_dst1
    adc csv_long_serial_len1
    sta csv_edit_dst1
    lda csv_edit_dst2
    adc #0
    sta csv_edit_dst2
    lda csv_edit_dst3
    adc #0
    sta csv_edit_dst3

csv_long_shift_left_loop$:
    jsr csv_edit_src_at_file_end
    beq +
    rts
+
    ldz #0
    lda [csv_edit_src0],z
    sta [csv_edit_dst0],z
    jsr csv_edit_inc_src
    jsr csv_edit_inc_dst
    jmp csv_long_shift_left_loop$


csv_long_add_delta_to_dst:
    clc
    lda csv_edit_dst0
    adc csv_long_delta0
    sta csv_edit_dst0
    lda csv_edit_dst1
    adc csv_long_delta1
    sta csv_edit_dst1
    lda csv_edit_dst2
    adc #0
    sta csv_edit_dst2
    lda csv_edit_dst3
    adc #0
    sta csv_edit_dst3
    rts


csv_long_size_add_delta:
    clc
    lda csv_size0
    adc csv_long_delta0
    sta csv_size0
    lda csv_size1
    adc csv_long_delta1
    sta csv_size1
    lda csv_size2
    adc #0
    sta csv_size2
    lda csv_size3
    adc #0
    sta csv_size3
    rts

csv_long_size_sub_delta:
    sec
    lda csv_size0
    sbc csv_long_delta0
    sta csv_size0
    lda csv_size1
    sbc csv_long_delta1
    sta csv_size1
    lda csv_size2
    sbc #0
    sta csv_size2
    lda csv_size3
    sbc #0
    sta csv_size3
    rts


; ------------------------------------------------------------
; Commit buffer in Attic
; ------------------------------------------------------------
csv_edit_commit:
    ; Any committed cell edit makes the document dirty.
    lda #1
    sta OVL_DIRTY
    lda csv_edit_long_mode
    beq csv_edit_commit_short$
    jmp csv_long_commit

csv_edit_commit_short$:
    ; Convert logical edit buffer to valid CSV serialization.
    jsr csv_edit_serialize

    lda csv_edit_serial_len
    cmp csv_edit_old_len
    beq csv_edit_write_serial
    bcc csv_edit_serial_shrink

    ; GROW: delta = serialized_new - raw_old
    sec
    sbc csv_edit_old_len
    sta csv_edit_delta
    jsr csv_edit_shift_right
    jsr csv_edit_size_add_delta
    jmp csv_edit_write_serial

csv_edit_serial_shrink:
    lda csv_edit_old_len
    sec
    sbc csv_edit_serial_len
    sta csv_edit_delta

    ; shift-left uses csv_edit_len as destination offset in the old code.
    ; Temporarily feed it serialized length.
    lda csv_edit_len
    sta csv_edit_logical_len_save
    lda csv_edit_serial_len
    sta csv_edit_len
    jsr csv_edit_shift_left
    lda csv_edit_logical_len_save
    sta csv_edit_len

    jsr csv_edit_size_sub_delta

csv_edit_write_serial:
    lda csv_edit_start0
    sta csv_edit_ptr0
    lda csv_edit_start1
    sta csv_edit_ptr1
    lda csv_edit_start2
    sta csv_edit_ptr2
    lda csv_edit_start3
    sta csv_edit_ptr3

    ldx #0
csv_edit_write_serial_loop:
    cpx csv_edit_serial_len
    beq csv_edit_write_serial_done
    ldz #0
    lda csv_edit_serial_buf,x
    sta [csv_edit_ptr0],z
    jsr csv_edit_inc_ptr
    inx
    jmp csv_edit_write_serial_loop

csv_edit_write_serial_done:
    rts


; ------------------------------------------------------------
; Serialize logical buffer to valid CSV.
;
; Quote field iff it contains:
;   comma, quote, CR or LF.
; Internal quote becomes "".
; Canonical internal newline remains $0A.
; ------------------------------------------------------------
csv_edit_serialize:
    lda #0
    sta csv_edit_need_quotes
    sta csv_edit_serial_len

    ldx #0
csv_edit_serialize_scan$:
    cpx csv_edit_len
    beq csv_edit_serialize_scan_done$
    lda csv_edit_buf,x
    cmp csv_delimiter
    beq csv_edit_serialize_need$
    cmp #0x22
    beq csv_edit_serialize_need$
    cmp #0x0a
    beq csv_edit_serialize_need$
    cmp #0x0d
    beq csv_edit_serialize_need$
    inx
    jmp csv_edit_serialize_scan$

csv_edit_serialize_need$:
    lda #1
    sta csv_edit_need_quotes

csv_edit_serialize_scan_done$:
    lda csv_edit_need_quotes
    beq csv_edit_serialize_body_start$

    lda #0x22
    jsr csv_edit_serial_append

csv_edit_serialize_body_start$:
    ldx #0
csv_edit_serialize_body$:
    cpx csv_edit_len
    beq csv_edit_serialize_body_done$

    lda csv_edit_buf,x
    cmp #0x22
    bne csv_edit_serialize_one$

    ; Quote logical -> doubled quote in CSV.
    lda #0x22
    jsr csv_edit_serial_append
    lda #0x22
    jsr csv_edit_serial_append
    inx
    jmp csv_edit_serialize_body$

csv_edit_serialize_one$:
    jsr csv_edit_serial_append
    inx
    jmp csv_edit_serialize_body$

csv_edit_serialize_body_done$:
    lda csv_edit_need_quotes
    beq csv_edit_serialize_done$

    lda #0x22
    jsr csv_edit_serial_append

csv_edit_serialize_done$:
    rts


; A = byte to append. Saturates at 254 bytes.
csv_edit_serial_append:
    ; Preserve caller's X: csv_edit_serialize_body uses it as the
    ; logical-buffer index.
    stx csv_edit_serial_saved_x
    pha

    ldx csv_edit_serial_len
    cpx #254
    bcs csv_edit_serial_append_full$

    pla
    sta csv_edit_serial_buf,x
    inc csv_edit_serial_len

    ldx csv_edit_serial_saved_x
    rts

csv_edit_serial_append_full$:
    pla
    ldx csv_edit_serial_saved_x
    rts


; Shift right by delta.
; Copies bytes backwards from file_end-1 down through old cell delimiter.
csv_edit_shift_right:
    ; src = absolute end = $08000000 + csv_size
    jsr csv_edit_make_file_end_to_src
    jsr csv_edit_dec_src

    ; dst = src + delta
    lda csv_edit_src0
    sta csv_edit_dst0
    lda csv_edit_src1
    sta csv_edit_dst1
    lda csv_edit_src2
    sta csv_edit_dst2
    lda csv_edit_src3
    sta csv_edit_dst3
    ldx csv_edit_delta
csv_edit_shift_right_add:
    cpx #0
    beq csv_edit_shift_right_loop
    jsr csv_edit_inc_dst
    dex
    jmp csv_edit_shift_right_add

csv_edit_shift_right_loop:
    ; Stop when src < old cell end.
    jsr csv_edit_src_before_cell_end
    beq +
    rts
+
    ldz #0
    lda [csv_edit_src0],z
    sta [csv_edit_dst0],z

    ; Verifica se è stato copiato anche il delimitatore della cella.
    ; csv_edit_src_equals_cell_end restituisce A=0 se uguale.
    ; In tal caso il lavoro è terminato; altrimenti prosegue
    ; a copiare all'indietro.
    jsr csv_edit_src_equals_cell_end
    bne +
    rts
+
    jsr csv_edit_dec_src
    jsr csv_edit_dec_dst
    jmp csv_edit_shift_right_loop


; Shift left by delta.
; src = old cell end (delimiter), dst = start + new_len.
csv_edit_shift_left:
    lda csv_edit_end0
    sta csv_edit_src0
    lda csv_edit_end1
    sta csv_edit_src1
    lda csv_edit_end2
    sta csv_edit_src2
    lda csv_edit_end3
    sta csv_edit_src3

    lda csv_edit_start0
    sta csv_edit_dst0
    lda csv_edit_start1
    sta csv_edit_dst1
    lda csv_edit_start2
    sta csv_edit_dst2
    lda csv_edit_start3
    sta csv_edit_dst3

    ldx csv_edit_len
csv_edit_shift_left_seek:
    cpx #0
    beq csv_edit_shift_left_loop
    jsr csv_edit_inc_dst
    dex
    jmp csv_edit_shift_left_seek

csv_edit_shift_left_loop:
    jsr csv_edit_src_at_file_end
    beq +
    rts
+
    ldz #0
    lda [csv_edit_src0],z
    sta [csv_edit_dst0],z
    jsr csv_edit_inc_src
    jsr csv_edit_inc_dst
    jmp csv_edit_shift_left_loop


; ------------------------------------------------------------
; 32-bit helpers
; ------------------------------------------------------------
csv_edit_make_file_end_to_src:
    lda csv_size0
    sta csv_edit_src0
    lda csv_size1
    sta csv_edit_src1
    lda csv_size2
    sta csv_edit_src2
    lda csv_size3
    clc
    adc #0x08
    sta csv_edit_src3
    rts

; A=0 while src < end-cell?  A=1 otherwise.
csv_edit_src_before_cell_end:
    lda csv_edit_src3
    cmp csv_edit_end3
    bcc csv_edit_cmp_yes
    bne csv_edit_cmp_no
    lda csv_edit_src2
    cmp csv_edit_end2
    bcc csv_edit_cmp_yes
    bne csv_edit_cmp_no
    lda csv_edit_src1
    cmp csv_edit_end1
    bcc csv_edit_cmp_yes
    bne csv_edit_cmp_no
    lda csv_edit_src0
    cmp csv_edit_end0
    bcc csv_edit_cmp_yes
csv_edit_cmp_no:
    lda #0
    rts
csv_edit_cmp_yes:
    lda #1
    rts

; A=0 if equal, A=1 otherwise
csv_edit_src_equals_cell_end:
    lda csv_edit_src0
    cmp csv_edit_end0
    bne csv_edit_ne
    lda csv_edit_src1
    cmp csv_edit_end1
    bne csv_edit_ne
    lda csv_edit_src2
    cmp csv_edit_end2
    bne csv_edit_ne
    lda csv_edit_src3
    cmp csv_edit_end3
    bne csv_edit_ne
    lda #0
    rts
csv_edit_ne:
    lda #1
    rts

; A=1 if src == absolute file end, else 0
csv_edit_src_at_file_end:
    lda csv_edit_src0
    cmp csv_size0
    bne csv_edit_src_not_end
    lda csv_edit_src1
    cmp csv_size1
    bne csv_edit_src_not_end
    lda csv_edit_src2
    cmp csv_size2
    bne csv_edit_src_not_end
    lda csv_edit_src3
    sec
    sbc #0x08
    cmp csv_size3
    bne csv_edit_src_not_end
    lda #1
    rts
csv_edit_src_not_end:
    lda #0
    rts

csv_edit_at_end:
    lda attic_addr0
    cmp csv_size0
    bne csv_edit_not_end
    lda attic_addr1
    cmp csv_size1
    bne csv_edit_not_end
    lda attic_addr2
    cmp csv_size2
    bne csv_edit_not_end
    lda attic_addr3
    sec
    sbc #0x08
    cmp csv_size3
    bne csv_edit_not_end
    lda #1
    rts
csv_edit_not_end:
    lda #0
    rts

csv_edit_size_add_delta:
    clc
    lda csv_size0
    adc csv_edit_delta
    sta csv_size0
    lda csv_size1
    adc #0
    sta csv_size1
    lda csv_size2
    adc #0
    sta csv_size2
    lda csv_size3
    adc #0
    sta csv_size3
    rts

csv_edit_size_sub_delta:
    sec
    lda csv_size0
    sbc csv_edit_delta
    sta csv_size0
    lda csv_size1
    sbc #0
    sta csv_size1
    lda csv_size2
    sbc #0
    sta csv_size2
    lda csv_size3
    sbc #0
    sta csv_size3
    rts

csv_edit_inc_attic:
    inc attic_addr0
    bne csv_edit_inc_attic_done
    inc attic_addr1
    bne csv_edit_inc_attic_done
    inc attic_addr2
    bne csv_edit_inc_attic_done
    inc attic_addr3
csv_edit_inc_attic_done:
    rts

csv_edit_inc_ptr:
    inc csv_edit_ptr0
    bne csv_edit_inc_ptr_done
    inc csv_edit_ptr1
    bne csv_edit_inc_ptr_done
    inc csv_edit_ptr2
    bne csv_edit_inc_ptr_done
    inc csv_edit_ptr3
csv_edit_inc_ptr_done:
    rts

csv_edit_inc_src:
    inc csv_edit_src0
    bne csv_edit_inc_src_done
    inc csv_edit_src1
    bne csv_edit_inc_src_done
    inc csv_edit_src2
    bne csv_edit_inc_src_done
    inc csv_edit_src3
csv_edit_inc_src_done:
    rts

csv_edit_inc_dst:
    inc csv_edit_dst0
    bne csv_edit_inc_dst_done
    inc csv_edit_dst1
    bne csv_edit_inc_dst_done
    inc csv_edit_dst2
    bne csv_edit_inc_dst_done
    inc csv_edit_dst3
csv_edit_inc_dst_done:
    rts

csv_edit_dec_src:
    lda csv_edit_src0
    bne csv_edit_dec_src0
    lda csv_edit_src1
    bne csv_edit_dec_src1
    lda csv_edit_src2
    bne csv_edit_dec_src2
    dec csv_edit_src3
csv_edit_dec_src2:
    dec csv_edit_src2
csv_edit_dec_src1:
    dec csv_edit_src1
csv_edit_dec_src0:
    dec csv_edit_src0
    rts

csv_edit_dec_dst:
    lda csv_edit_dst0
    bne csv_edit_dec_dst0
    lda csv_edit_dst1
    bne csv_edit_dec_dst1
    lda csv_edit_dst2
    bne csv_edit_dec_dst2
    dec csv_edit_dst3
csv_edit_dec_dst2:
    dec csv_edit_dst2
csv_edit_dec_dst1:
    dec csv_edit_dst1
csv_edit_dec_dst0:
    dec csv_edit_dst0
    rts


; Sort engine moved to EDIT.PRG (edit_sort.s)

    rts


; ============================================================
; COLOUR RAM STYLE HELPERS
; ============================================================

; style_color_ptr = $0FF80000 + (row*80 + col)*2
; INPUT:
;   A = screen row 0..24
;   X = screen column 0..79
style_make_color_ptr:
    sta style_color_row
    stx style_color_col

    lda #COLORRAM0
    sta style_color_ptr0
    lda #COLORRAM1
    sta style_color_ptr1
    lda #COLORRAM2
    sta style_color_ptr2
    lda #COLORRAM3
    sta style_color_ptr3

    ; add row * 160
    ldy style_color_row
style_color_add_rows$:
    cpy #0
    beq style_color_add_cols$
    clc
    lda style_color_ptr0
    adc #80
    sta style_color_ptr0
    lda style_color_ptr1
    adc #0
    sta style_color_ptr1
    lda style_color_ptr2
    adc #0
    sta style_color_ptr2
    lda style_color_ptr3
    adc #0
    sta style_color_ptr3
    dey
    jmp style_color_add_rows$

style_color_add_cols$:
    txa
    clc
    adc style_color_ptr0
    sta style_color_ptr0
    lda style_color_ptr1
    adc #0
    sta style_color_ptr1
    lda style_color_ptr2
    adc #0
    sta style_color_ptr2
    lda style_color_ptr3
    adc #0
    sta style_color_ptr3
    rts


; INPUT:
;   A = screen row
;   X = start column
;   Y = number of cells
;   style_color_value = colour
style_fill_color_span:
    sty style_color_len
    jsr style_make_color_ptr
    ldz #0
style_fill_color_span_loop$:
    lda [style_color_ptr0],z
    and #0xf0
    ora style_color_value
    sta [style_color_ptr0],z

    ; next cell = +1 Colour RAM byte
    clc
    lda style_color_ptr0
    adc #1
    sta style_color_ptr0
    lda style_color_ptr1
    adc #0
    sta style_color_ptr1
    lda style_color_ptr2
    adc #0
    sta style_color_ptr2
    lda style_color_ptr3
    adc #0
    sta style_color_ptr3

    dec style_color_len
    bne style_fill_color_span_loop$
    rts


; Colour complete 80-cell screen row.
; INPUT: A=row, style_color_value already set.
style_fill_color_row:
    ldx #0
    ldy #80
    jmp style_fill_color_span


; Apply normal cell colour to all CSV data rows 2..24.
style_color_data_area:
    jsr seam_apply_cell_style
    lda #0
    sta style_color_value
    lda #VIEW_TOP
    sta style_color_row_iter
style_color_data_rows$:
    lda style_color_row_iter
    jsr style_fill_color_row
    inc style_color_row_iter
    lda style_color_row_iter
    cmp runtime_screen_rows
    bcc style_color_data_rows$
    rts


; Apply header colour to row 1.
style_color_header_row:
    jsr seam_apply_header_style
    lda #0
    sta style_color_value
    lda #COL_HEADER_ROW
    jsr style_fill_color_row
    rts


; Apply menu-bar colour to row 0.
style_color_menu_row:
    jsr seam_apply_menu_style
    lda #0
    sta style_color_value
    lda #MENU_ROW
    jsr style_fill_color_row
    rts


; Colour current cell using current geometry.
; INPUT: A = colour
style_color_current_cell:
    sta style_color_value
    jsr calc_current_screen_row
    jsr calc_current_cell_geometry

    lda current_screen_row
    clc
    adc #VIEW_TOP
    ldx current_cell_x
    ldy current_cell_width
    jsr style_fill_color_span
    rts


; ------------------------------------------------------------
; draw_menu_bar
;
; Riga video 0 fissa:
;
;   FILE   EDIT   VIEW                                   KnockCSV
;
; Per ora e' soltanto visiva. La riga viene prima pulita,
; poi scritta con BSOUT e infine resa tutta reverse-video.
; Le routine di scrolling lavorano esclusivamente su rows 1..24.
; ------------------------------------------------------------

draw_menu_bar:
    jsr seam_apply_menu_style

    ldx #MENU_ROW
    ldy #0
    clc
    jsr seam_plot

    ; Fill full row so the bar background spans all 80 columns.
    lda #80
    sta menu_style_count
draw_menu_fill$:
    lda #' '
    jsr seam_bsout
    dec menu_style_count
    bne draw_menu_fill$

    ; Print menu text over the filled bar.
    ldx #MENU_ROW
    ldy #0
    clc
    jsr seam_plot
    ldx #0
menu_text_loop$:
    lda menu_text,x
    beq menu_text_done$
    jsr seam_bsout
    inx
    bne menu_text_loop$

menu_text_done$:
    jsr seam_apply_cell_style
    rts


menu_text:
    .ascii " fILE   eDIT   gRID   vIEW   hELP                            kNOCKcsv 1.0"
    .byte 0


; ------------------------------------------------------------
; NUMERI DI COLONNA / RIGA
;
; Row 0 : menu
; Row 1 : intestazioni colonne
; Rows 2..24 : CSV
;
; Cols 0..4 : numero riga (right aligned)
; Col 5      : spazio
; Cols 6..78 : dati CSV
; ------------------------------------------------------------


; ------------------------------------------------------------
; draw_column_header
;
; Disegna 1,2,3... usando le stesse larghezze dinamiche
; delle colonne CSV e csv_left_col.
; ------------------------------------------------------------

draw_column_header:
    ; Applica lo stile header a TUTTA la riga dei numeri colonna.
    ; In SEAM il background viene simulato tramite reverse, quindi
    ; l'attributo deve essere aggiornato per tutte le 80 celle, non solo
    ; per quelle in cui vengono stampati i numeri.
    jsr seam_apply_header_style

    lda #COL_HEADER_ROW
    ldx #0
    ldy #80
    jsr seam_fill_attr_span

    ; Pulisce tutta la row 1.
    jsr screen_getptr
    jsr copy_screen_base_to_dst
    jsr add80_dst
    jsr clear_dst_row

    lda #DATA_START_X
    sta header_x

    ; --------------------------------------------------------
    ; Frozen column headers: 1, 2
    ; --------------------------------------------------------
    lda #0
    sta header_col

header_frozen_loop$:
    lda header_col
    cmp csv_frozen_cols
    beq header_scroll_start$

    ; Non oltre il numero reale di colonne.
    lda csv_maxcols1
    bne header_frozen_exists$
    lda header_col
    cmp csv_maxcols0
    bcc +
    jmp column_header_done$
+

header_frozen_exists$:
    lda header_col
    jsr get_col_width
    sta header_width

    clc
    lda header_x
    adc header_width
    cmp #80
    bcc +
    jmp column_header_done$
+

    ldx #COL_HEADER_ROW
    ldy header_x
    clc
    jsr seam_plot

    lda header_col
    clc
    adc #1
    sta print_num0
    lda #0
    adc #0
    sta print_num1
    jsr print_u16

    clc
    lda header_x
    adc header_width
    sta header_x

    inc header_col
    jmp header_frozen_loop$

    ; --------------------------------------------------------
    ; Scrollable headers: csv_left_col, csv_left_col+1...
    ; --------------------------------------------------------
header_scroll_start$:
    lda csv_left_col
    cmp csv_frozen_cols
    bcs +
    lda csv_frozen_cols
+
    sta header_col

header_scroll_loop$:
    lda csv_maxcols1
    bne header_scroll_exists$

    lda header_col
    cmp csv_maxcols0
    bcs column_header_done$

header_scroll_exists$:
    lda header_col
    jsr get_col_width
    sta header_width

    clc
    lda header_x
    adc header_width
    cmp #80
    bcs column_header_done$

    ldx #COL_HEADER_ROW
    ldy header_x
    clc
    jsr seam_plot

    lda header_col
    clc
    adc #1
    sta print_num0
    lda #0
    adc #0
    sta print_num1
    jsr print_u16

    clc
    lda header_x
    adc header_width
    sta header_x

    inc header_col
    bne header_scroll_loop$

column_header_done$:
    jsr seam_apply_cell_style
    rts


; ------------------------------------------------------------
; draw_current_row_number
;
; INPUT implicito:
;   csv_row0/1 = riga CSV appena stampata (0-based)
;   cursore puo' essere ovunque.
;
; Stampa csv_row+1 right-aligned in 5 caratteri.
; ------------------------------------------------------------

draw_frozen_row_number:
    jsr seam_apply_header_style
    ; Salva row CSV + 1.
    clc
    lda csv_row0
    adc #1
    sta print_num0
    lda csv_row1
    adc #0
    sta print_num1

    ; Frozen row: relative screen row equals csv_row.
    lda csv_row0
    sta rownum_screen

    clc
    lda rownum_screen
    adc #VIEW_TOP
    tax

    ; pulisci area numero riga 0..5
    ldy #0
    clc
    jsr seam_plot

    lda #6
    sta rownum_clear_count
rownum_clear_loop$:
    lda #' '
    jsr seam_bsout
    dec rownum_clear_count
    bne rownum_clear_loop$

    ; calcola numero di cifre e posizione right-aligned
    jsr count_u16_digits
    lda #5
    sec
    sbc num_digits
    tay

    ldx rownum_screen
    txa
    clc
    adc #VIEW_TOP
    tax
    clc
    jsr seam_plot

    jsr print_u16
    jsr seam_apply_cell_style
    rts


draw_scrolling_row_number:
    jsr seam_apply_header_style
    jsr calc_runtime_scroll_layout
    clc
    lda csv_row0
    adc #1
    sta print_num0
    lda csv_row1
    adc #0
    sta print_num1

    sec
    lda csv_row0
    sbc csv_top_row0
    sta rownum_screen

    clc
    lda rownum_screen
    adc runtime_scroll_top
    tax
    ldy #0
    clc
    jsr seam_plot

    lda #6
    sta rownum_clear_count
rownum_clear_loop$:
    lda #' '
    jsr seam_bsout
    dec rownum_clear_count
    bne rownum_clear_loop$

    jsr count_u16_digits
    lda #5
    sec
    sbc num_digits
    tay

    ldx rownum_screen
    txa
    clc
    adc runtime_scroll_top
    tax
    clc
    jsr seam_plot
    jsr print_u16
    jsr seam_apply_cell_style
    rts


; ------------------------------------------------------------
; ------------------------------------------------------------
; count_u16_digits
; print_num0/1 -> num_digits (1..5)
; ------------------------------------------------------------

count_u16_digits:
    lda print_num1
    bne digits_large$

    lda print_num0
    cmp #10
    bcc digits_1$
    cmp #100
    bcc digits_2$

    lda #3
    sta num_digits
    rts

digits_large$:
    ; >=256. Decide 3/4/5 with 16-bit comparisons.
    ; >=10000 ?
    lda print_num1
    cmp #0x27
    bcc check_1000$
    bne digits_5$
    lda print_num0
    cmp #0x10
    bcs digits_5$

check_1000$:
    ; >=1000 ($03E8) ?
    lda print_num1
    cmp #0x03
    bcc digits_3$
    bne digits_4$
    lda print_num0
    cmp #0xe8
    bcs digits_4$

digits_3$:
    lda #3
    sta num_digits
    rts

digits_4$:
    lda #4
    sta num_digits
    rts

digits_5$:
    lda #5
    sta num_digits
    rts

digits_1$:
    lda #1
    sta num_digits
    rts

digits_2$:
    lda #2
    sta num_digits
    rts


; ------------------------------------------------------------
; print_u16
;
; print_num0/1 (0..65535) -> decimal via repeated subtraction.
; Uses place values 10000,1000,100,10,1.
; ------------------------------------------------------------

print_u16:
    lda print_num0
    sta dec_work0
    lda print_num1
    sta dec_work1

    lda #0
    sta dec_started

    ; 10000 = $2710
    lda #0x10
    sta dec_div0
    lda #0x27
    sta dec_div1
    jsr print_decimal_place

    ; 1000 = $03E8
    lda #0xe8
    sta dec_div0
    lda #0x03
    sta dec_div1
    jsr print_decimal_place

    ; 100 = $0064
    lda #0x64
    sta dec_div0
    lda #0x00
    sta dec_div1
    jsr print_decimal_place

    ; 10 = $000A
    lda #0x0a
    sta dec_div0
    lda #0x00
    sta dec_div1
    jsr print_decimal_place

    ; ones: remainder is 0..9, always print.
    lda dec_work0
    clc
    adc #'0'
    jsr seam_bsout
    rts


print_decimal_place:
    lda #0
    sta dec_digit

decimal_sub_loop$:
    ; if work < divisor -> done
    lda dec_work1
    cmp dec_div1
    bcc decimal_place_done$
    bne decimal_do_sub$

    lda dec_work0
    cmp dec_div0
    bcc decimal_place_done$

decimal_do_sub$:
    sec
    lda dec_work0
    sbc dec_div0
    sta dec_work0
    lda dec_work1
    sbc dec_div1
    sta dec_work1

    inc dec_digit
    jmp decimal_sub_loop$

decimal_place_done$:
    lda dec_digit
    bne decimal_emit$

    lda dec_started
    beq decimal_skip$
    lda #'0'
    jsr seam_bsout
    rts

decimal_emit$:
    lda #1
    sta dec_started

    lda dec_digit
    clc
    adc #'0'
    jsr seam_bsout

decimal_skip$:
    rts


; ------------------------------------------------------------
; clear_full_viewport
;
; Pulisce soltanto le VIEW_ROWS righe CSV (video rows 1..49).
; ------------------------------------------------------------

clear_full_viewport:
    jsr seam_apply_cell_style

    ldx #1
clear_full_viewport_loop$:
    jsr seam_clear_row
    inx
    cpx runtime_screen_rows
    bne clear_full_viewport_loop$
    rts


; ------------------------------------------------------------
; csvprintview
;
; Pulisce la viewport e ridisegna VIEW_ROWS righe.
; Ogni riga viene posizionata esplicitamente con PLOT,
; quindi csvprintrow non deve emettere CR.
; ------------------------------------------------------------

csvprintview:
    jsr clear_full_viewport

    ; 1) Frozen CSV rows 0..1
    lda #0
    sta csv_row0
    sta csv_row1
    sta view_count

frozen_view_loop$:
    lda view_count
    cmp csv_frozen_rows
    bcs scroll_view_start$

    lda csv_row1
    cmp csv_rows1
    bcc frozen_print$
    beq +
    jmp view_done$
+
    lda csv_row0
    cmp csv_rows0
    bcs view_done$

frozen_print$:
    ldx view_count
    txa
    clc
    adc #VIEW_TOP
    tax
    ldy #DATA_START_X
    clc
    jsr seam_plot
    jsr seam_apply_cell_style
    jsr csvprintrow
    jsr draw_frozen_row_number

    inc csv_row0
    bne frozen_inc_done$
    inc csv_row1
frozen_inc_done$:
    inc view_count
    jmp frozen_view_loop$

    ; 2) Scrollable CSV rows from csv_top_row
scroll_view_start$:
    lda csv_top_row0
    sta csv_row0
    lda csv_top_row1
    sta csv_row1
    lda #0
    sta view_count

scroll_view_loop$:
    jsr calc_runtime_scroll_layout
    lda view_count
    cmp runtime_scroll_rows
    bcs view_done$

    lda csv_row1
    cmp csv_rows1
    bcc scroll_print$
    bne view_done$
    lda csv_row0
    cmp csv_rows0
    bcs view_done$

scroll_print$:
    ldx view_count
    txa
    clc
    adc runtime_scroll_top
    tax
    ldy #DATA_START_X
    clc
    jsr seam_plot
    jsr seam_apply_cell_style
    jsr csvprintrow
    jsr draw_scrolling_row_number

    inc csv_row0
    bne scroll_inc_done$
    inc csv_row1
scroll_inc_done$:
    inc view_count
    jmp scroll_view_loop$

view_done$:
    jsr draw_column_header
    jsr draw_menu_bar
    jsr csv_multiselect_highlight_all
    rts


; ------------------------------------------------------------
; BSS
; ------------------------------------------------------------



csv_new_document:
    ; A new empty sheet starts clean.
    lda #0
    sta OVL_DIRTY

    ; Reset document/view state.
    lda #0
    sta csv_size0
    sta csv_size1
    sta csv_size2
    sta csv_size3
    sta csvnamelen
    sta csv_top_row0
    sta csv_top_row1
    sta csv_current_row0
    sta csv_current_row1
    sta csv_current_col
    sta csv_multiselect_count
    sta csv_multiselect_mode
    sta csv_find_mode
    sta csv_replace_mode
    sta csv_replace_focus
    sta csv_find_len
    sta csv_replace_len

    lda #FROZEN_ROWS
    sta csv_frozen_rows
    sta csv_top_row0
    lda #FROZEN_COLS
    sta csv_frozen_cols
    sta csv_left_col

    ; Attic destination = $08000000.
    lda #0
    sta attic_addr0
    sta attic_addr1
    sta attic_addr2
    lda #0x08
    sta attic_addr3

    ; 100 rows, 26 empty fields per row:
    ; 25 delimiters followed by canonical CR.
    lda #15
    sta csv_new_rows_left

csv_new_row_loop$:
    ldx #14
csv_new_col_loop$:
    lda csv_delimiter
    jsr csv_new_store_byte$
    dex
    bne csv_new_col_loop$

    lda #0x0d
    jsr csv_new_store_byte$

    dec csv_new_rows_left
    bne csv_new_row_loop$

    ; 15 * 15 = 225 = $00E1 bytes.
    lda #0xe1
    sta csv_size0
    lda #0
    sta csv_size1
    lda #0
    sta csv_size2
    sta csv_size3

    jsr csvindex
    lda #1
    sta csv_file_loaded

    jsr csvprintview
    jsr highlight_current_cell
    rts

csv_new_store_byte$:
    ldz #0
    sta [attic_addr0],z
    inc attic_addr0
    bne csv_new_store_done$
    inc attic_addr1
    bne csv_new_store_done$
    inc attic_addr2
    bne csv_new_store_done$
    inc attic_addr3
csv_new_store_done$:
    rts



; ============================================================
; UNSAVED-CHANGES GUARD
; OVL_DIRTY survives overlay chain loads in shared RAM.
; pending_action: 1=New, 2=Open.
; ============================================================

csv_request_new:
    lda OVL_DIRTY
    beq csv_request_new_now$
    lda #1
    sta csv_dirty_pending_action
    jsr csv_dirty_prompt_open
    rts
csv_request_new_now$:
    jsr csv_new_document
    rts

csv_request_open:
    lda OVL_DIRTY
    beq csv_request_open_now$
    lda #2
    sta csv_dirty_pending_action
    jsr csv_dirty_prompt_open
    rts
csv_request_open_now$:
    jsr csv_open_browser_now
    rts

csv_request_exit:
    lda OVL_DIRTY
    beq csv_request_exit_now$
    lda #3
    sta csv_dirty_pending_action
    jsr csv_dirty_prompt_open
    rts
csv_request_exit_now$:
    lda #1
    sta csv_exit_requested
    rts

csv_dirty_prompt_open:
    lda #1
    sta csv_dirty_prompt_active

    ; Draw a compact confirmation strip on the last screen row.
    jsr seam_apply_selection_style
    ldx runtime_last_row
    jsr seam_clear_row
    ldx runtime_last_row
    ldy #2
    clc
    jsr seam_plot
    ldx #0
csv_dirty_prompt_text_loop$:
    lda csv_dirty_prompt_text,x
    beq csv_dirty_prompt_draw_done$
    jsr seam_bsout
    inx
    bne csv_dirty_prompt_text_loop$
csv_dirty_prompt_draw_done$:
    jsr seam_apply_cell_style
    rts

; A = key. Y saves, N discards, ESC cancels.
csv_dirty_prompt_handle_key:
    cmp #KEY_ESC
    beq csv_dirty_prompt_cancel$
    cmp #'y'
    beq csv_dirty_prompt_save$
    cmp #'Y'
    beq csv_dirty_prompt_save$
    cmp #'n'
    beq csv_dirty_prompt_discard$
    cmp #'N'
    beq csv_dirty_prompt_discard$
    rts

csv_dirty_prompt_cancel$:
    lda #0
    sta csv_dirty_prompt_active
    sta csv_dirty_pending_action
    jsr csvprintview
    jsr highlight_current_cell
    rts

csv_dirty_prompt_discard$:
    lda #0
    sta csv_dirty_prompt_active
    sta OVL_DIRTY
    jsr csv_dirty_continue_pending
    rts

csv_dirty_prompt_save$:
    lda #0
    sta csv_dirty_prompt_active

    ; Named document: save synchronously, then continue.
    lda csvnamelen
    beq csv_dirty_prompt_saveas$

    jsr busycursor_on
    jsr savecsv
    jsr busycursor_off
    lda #0
    sta OVL_DIRTY
    jsr csv_dirty_continue_pending
    rts

csv_dirty_prompt_saveas$:
    ; Keep pending_action until Save As confirms. ESC in the browser
    ; leaves OVL_DIRTY set and cancels the deferred New/Open.
    jsr csvprintview
    jsr highlight_current_cell
    jsr csvfilebrowser_open_saveas
    rts

csv_dirty_continue_pending:
    lda csv_dirty_pending_action
    pha
    lda #0
    sta csv_dirty_pending_action
    pla
    cmp #1
    beq csv_dirty_continue_new$
    cmp #2
    beq csv_dirty_continue_open$
    cmp #3
    beq csv_dirty_continue_exit$
    rts
csv_dirty_continue_new$:
    jsr csv_new_document
    rts
csv_dirty_continue_open$:
    jsr csv_open_browser_now
    rts
csv_dirty_continue_exit$:
    lda #1
    sta csv_exit_requested
    rts

csv_dirty_prompt_text:
    .ascii "sAVE CHANGES BEFORE CONTINUING?  y=sAVE  n=dON'T SAVE  esc=cANCEL"
    .byte 0



; ------------------------------------------------------------
; Open browser helper used by the unsaved-changes guard.
; Kept outside csvviewloop so it cannot break local-label scope.
; ------------------------------------------------------------
csv_open_browser_now:
    ; Restore what was below the menu before opening the browser.
    lda csv_file_loaded
    beq open_browser_from_empty$

    jsr csvprintview
    jsr highlight_current_cell
    jmp open_browser$

open_browser_from_empty$:
    jsr clear_full_viewport
    jsr draw_menu_bar

open_browser$:
    jsr csvfilebrowser_open
    rts


    .section bss,bss

csv_dirty_prompt_active:
    .space 1
csv_dirty_pending_action:
    .space 1

; Colour-RAM style temporaries
style_color_row:
    .space 1
style_color_col:
    .space 1
style_color_len:
    .space 1
style_color_value:
    .space 1
style_color_row_iter:
    .space 1

seam_x2_temp:
    .space 1
menu_style_count:
    .space 1

menu_action:
    .space 1
csv_exit_requested:
    .space 1

csv_fill_direction:
    .space 1
csv_fill_bulk:
    .space 1
csv_fill_source_len0:
    .space 1
csv_fill_source_len1:
    .space 1
csv_fill_src_row0:
    .space 1
csv_fill_src_row1:
    .space 1
csv_fill_src_col:
    .space 1
csv_fill_dst_row0:
    .space 1
csv_fill_dst_row1:
    .space 1

csv_file_loaded:
    .space 1
csv_new_rows_left:
    .space 1

csv_frozen_rows:
    .space 1

csv_frozen_cols:
    .space 1

runtime_scroll_top:
    .space 1
runtime_scroll_rows:
    .space 1

; Temporanei per hit-test mouse/cella.
mouse_screen_row:
    .space 1
; 1 while hit-testing the column-number header row.
mouse_header_col_click:
    .space 1
mouse_cell_right_action:
    .space 1
mouse_data_row:
    .space 1
mouse_screen_col:
    .space 1
mouse_target_row0:
    .space 1
mouse_target_row1:
    .space 1
mouse_target_col:
    .space 1
mouse_div_x0:
    .space 1
mouse_div_x1:
    .space 1
mouse_col_x:
    .space 1
mouse_col_x_hi:
    .space 1
mouse_col_end:
    .space 1
mouse_col_end_hi:
    .space 1
mouse_test_col:
    .space 1
mouse_test_width:
    .space 1

mouse_menu_consumed:
    .space 1
mouse_menu_latch:
    .space 1
mouse_menu_row:
    .space 1
mouse_menu_col:
    .space 1
mouse_menu_xhi:
    .space 1

last_view_key:
    .space 1

csv_top_row0:
    .space 1

csv_top_row1:
    .space 1

view_count:
    .space 1

temp_row0:
    .space 1

temp_row1:
    .space 1

scroll_rows:
    .space 1

scroll_seek:
    .space 1

screen_base0:
    .space 1
screen_base1:
    .space 1
screen_base2:
    .space 1
screen_base3:
    .space 1

; Riga assoluta selezionata nel CSV.
csv_current_row0:
    .space 1
csv_current_row1:
    .space 1

; Colonna selezionata, per ora 0..4.
csv_current_col:
    .space 1

; Prima colonna visibile nella viewport.
csv_left_col:
    .space 1

; Riga relativa nella viewport CSV (0..23).
current_screen_row:
    .space 1
current_screen_row_hi:
    .space 1

highlight_rows:
    .space 1

highlight_len:
    .space 1

current_cell_x:
    .space 1

current_cell_width:
    .space 1

geometry_col:
    .space 1

hscroll_changed:
    .space 1

keyboard_old_select_mode:
    .space 1

scroll_start_x:
    .space 1

hredraw_row:
    .space 1

hredraw_index:
    .space 1

hclear_len:
    .space 1

clear_rows:
    .space 1

header_x:
    .space 1
header_col:
    .space 1
header_width:
    .space 1

rownum_screen:
    .space 1
rownum_clear_count:
    .space 1
num_digits:
    .space 1

print_num0:
    .space 1
print_num1:
    .space 1

dec_work0:
    .space 1
dec_work1:
    .space 1
dec_div0:
    .space 1
dec_div1:
    .space 1
dec_digit:
    .space 1
dec_started:
    .space 1



; ------------------------------------------------------------
; Multi-cell rectangular selection
; ------------------------------------------------------------
; csv_multiselect_count is now simply 0=inactive / 1=active.
csv_multiselect_count:
    .space 1
; 0 = normal rectangle/single cell, 1 = whole row, 2 = whole column
csv_multiselect_mode:
    .space 1
csv_multiselect_delta0:
    .space 1

; Anchor (first normal click).
csv_multiselect_anchor_row0:
    .space 1
csv_multiselect_anchor_row1:
    .space 1
csv_multiselect_anchor_col:
    .space 1

; Inclusive rectangle bounds.
csv_multiselect_min_row0:
    .space 1
csv_multiselect_min_row1:
    .space 1
csv_multiselect_max_row0:
    .space 1
csv_multiselect_max_row1:
    .space 1
csv_multiselect_min_col:
    .space 1
csv_multiselect_max_col:
    .space 1

; Iterators / saved current cell.
csv_multiselect_iter_row0:
    .space 1
csv_multiselect_iter_row1:
    .space 1
csv_multiselect_iter_col:
    .space 1
csv_multiselect_vis_row0:
    .space 1
csv_multiselect_vis_row1:
    .space 1
csv_multiselect_vis_count:
    .space 1
csv_multiselect_save_row0:
    .space 1
csv_multiselect_save_row1:
    .space 1
csv_multiselect_save_col:
    .space 1

; Structural insert/delete state moved to EDIT.PRG.

; ------------------------------------------------------------
; Keyboard / internal clipboard
; ------------------------------------------------------------
csv_clip_key_latch:
    .space 1
csv_clip_valid:
    .space 1
csv_clip_len:
    .space 1
csv_clip_buf:
    .space 255

; ------------------------------------------------------------
; Double click state
; ------------------------------------------------------------
csv_double_timer:
    .space 1
csv_double_valid:
    .space 1
csv_double_last_raster:
    .space 1
csv_double_row0:
    .space 1
csv_double_row1:
    .space 1
csv_double_col:
    .space 1

; ------------------------------------------------------------
; Cell editor state
; ------------------------------------------------------------
csv_edit_mode:
    .space 1

; Non-zero only while Replace loads a cell through csv_edit_begin.
; Keeps all editor parsing/buffer logic but suppresses visual drawing.
csv_edit_silent_load:
    .space 1

; Diagnostic/manual-entry discriminator.
csv_edit_user_entry:
    .space 1

csv_edit_len:
    .space 1

; Short editor logical cursor (0..len).
csv_edit_cursor_pos:
    .space 1

; Long-cell engine state (16-bit lengths).
csv_edit_long_mode:
    .space 1
csv_edit_long_len0:
    .space 1
csv_edit_long_len1:
    .space 1
csv_edit_long_raw0:
    .space 1
csv_edit_long_raw1:
    .space 1
csv_long_serial_len0:
    .space 1
csv_long_serial_len1:
    .space 1
csv_long_delta0:
    .space 1
csv_long_delta1:
    .space 1
csv_long_rem0:
    .space 1
csv_long_rem1:
    .space 1
csv_long_need_quotes:
    .space 1
csv_long_append_byte:
    .space 1
csv_long_preview_row:
    .space 1
csv_long_preview_left:
    .space 1

; Full-screen long editor viewport / word-wrap state.
csv_long_top0:
    .space 1
csv_long_top1:
    .space 1
csv_long_total0:
    .space 1
csv_long_total1:
    .space 1
csv_long_visual0:
    .space 1
csv_long_visual1:
    .space 1
csv_long_cursor_line0:
    .space 1
csv_long_cursor_line1:
    .space 1
csv_long_cursor_col:
    .space 1

; Long editor logical cursor position in Attic buffer.
csv_long_cursor_pos0:
    .space 1
csv_long_cursor_pos1:
    .space 1
csv_long_cursor_found:
    .space 1
csv_long_line_start0:
    .space 1
csv_long_line_start1:
    .space 1
csv_long_tmp_end0:
    .space 1
csv_long_tmp_end1:
    .space 1
csv_long_goal_col:
    .space 1
csv_long_target_line0:
    .space 1
csv_long_target_line1:
    .space 1
csv_long_target_col:
    .space 1

; Mapping of the 23 visible wrapped lines.
csv_long_vis_start_lo:
    .space 23
csv_long_vis_start_hi:
    .space 23
csv_long_vis_len:
    .space 23
csv_long_follow_end:
    .space 1
csv_long_has_more:
    .space 1
csv_long_limit0:
    .space 1
csv_long_limit1:
    .space 1
csv_long_desired_top0:
    .space 1
csv_long_desired_top1:
    .space 1
csv_long_offset:
    .space 1
csv_long_line_len:
    .space 1
csv_long_last_space:
    .space 1
csv_long_last_newline:
    .space 1
csv_long_current_char:
    .space 1
csv_long_emit_len:
    .space 1
csv_long_clear_row:
    .space 1
csv_long_clear_count:
    .space 1

; 80-byte temporary word-wrap line.
csv_long_linebuf:
    .space 80


; Long Text Mode character selection / clipboard.
csv_long_sel_active:       .space 1
csv_long_sel_anchor0:      .space 1
csv_long_sel_anchor1:      .space 1
csv_long_sel_start0:       .space 1
csv_long_sel_start1:       .space 1
csv_long_sel_end0:         .space 1
csv_long_sel_end1:         .space 1
csv_long_sel_len0:         .space 1
csv_long_sel_len1:         .space 1
csv_long_clip_valid:       .space 1
csv_long_clip_swallow:     .space 1
csv_long_clip_len0:        .space 1
csv_long_clip_len1:        .space 1
csv_long_newlen0:          .space 1
csv_long_newlen1:          .space 1
csv_long_sel_line:         .space 1
csv_long_sel_visual0:      .space 1
csv_long_sel_visual1:      .space 1
csv_long_sel_line_start0:  .space 1
csv_long_sel_line_start1:  .space 1
csv_long_sel_line_end0:    .space 1
csv_long_sel_line_end1:    .space 1
csv_long_sel_isect_start0: .space 1
csv_long_sel_isect_start1: .space 1
csv_long_sel_isect_end0:   .space 1
csv_long_sel_isect_end1:   .space 1

; RAW serialized length of the original cell.
csv_edit_raw_len:
    .space 1

csv_edit_old_len:
    .space 1

csv_edit_serial_len:
    .space 1
csv_edit_serial_saved_x:
    .space 1
csv_edit_need_quotes:
    .space 1
csv_edit_logical_len_save:
    .space 1
csv_edit_raw_char:
    .space 1
csv_edit_scan_kind:
    .space 1

; Temporary multiline edit renderer state.
csv_edit_draw_row:
    .space 1
csv_edit_draw_x:
    .space 1
csv_edit_draw_lines:
    .space 1
csv_edit_draw_max_lines:
    .space 1
csv_edit_draw_line:
    .space 1
csv_edit_draw_col:
    .space 1
csv_edit_draw_remaining:
    .space 1
csv_edit_draw_saved_x:
    .space 1

; Physical hardware cursor position.
csv_edit_cursor_hw_row:
    .space 1
csv_edit_cursor_hw_col:
    .space 1
csv_edit_cursor_draw_valid:
    .space 1
csv_edit_cursor_draw_line:
    .space 1
csv_edit_cursor_draw_col:
    .space 1

; MEGA65 editor-style navigation scratch.
csv_edit_tab_target:
    .space 1
csv_edit_tab_col:
    .space 1
csv_edit_short_line_start:
    .space 1
csv_edit_short_line_end:
    .space 1

; Dynamic horizontal edit overlay.
csv_edit_window_width:
    .space 1
csv_edit_desired_width:
    .space 1
csv_edit_line_len:
    .space 1
csv_edit_longest_line:
    .space 1
csv_edit_scan_col:
    .space 1
csv_scan_in_quotes:
    .space 1
csv_scan_quote_pending:
    .space 1
csv_scan_field_has_data:
    .space 1
csv_edit_key:
    .space 1

; MODKEYS_IMM snapshot taken immediately before GETIN.
csv_key_mod_latch:
    .space 1
csv_edit_delta:
    .space 1

csv_edit_start0:
    .space 1
csv_edit_start1:
    .space 1
csv_edit_start2:
    .space 1
csv_edit_start3:
    .space 1

csv_edit_end0:
    .space 1
csv_edit_end1:
    .space 1
csv_edit_end2:
    .space 1
csv_edit_end3:
    .space 1

csv_edit_buf:
    .space 255

; Serialized CSV form generated on commit.
csv_edit_serial_buf:
    .space 255

; ------------------------------------------------------------
; Quad pointers 28/32 bit per accesso VIC-IV screen RAM
; ------------------------------------------------------------


csv_find_mode: .space 1
csv_find_len: .space 1
csv_find_fn_latch: .space 1
csv_find_fn_physical: .space 1
csv_find_fn_matrix: .space 1
csv_find_fn_mask: .space 1
csv_find_vertical: .space 1
csv_find_case_sensitive: .space 1
csv_replace_mode: .space 1
csv_replace_focus: .space 1
csv_replace_len: .space 1
csv_replace_pos: .space 1
csv_replace_src: .space 1
csv_replace_dst: .space 1
csv_replace_tmp: .space 1
csv_replace_mouse_row: .space 1
csv_replace_all_active: .space 1
csv_replace_all_row0: .space 1
csv_replace_all_row1: .space 1
csv_replace_all_col: .space 1
csv_find_start_pos0: .space 1
csv_find_start_pos1: .space 1
csv_find_skip0: .space 1
csv_find_skip1: .space 1
csv_find_candidate_pos0: .space 1
csv_find_candidate_pos1: .space 1
csv_find_match_pos0: .space 1
csv_find_match_pos1: .space 1
csv_find_key: .space 1
csv_find_clear_count: .space 1
csv_find_match: .space 1
csv_find_wrapped: .space 1
csv_find_row0: .space 1
csv_find_row1: .space 1
csv_find_col: .space 1
csv_find_start_row0: .space 1
csv_find_start_row1: .space 1
csv_find_start_col: .space 1
csv_find_saved_current_col: .space 1
csv_find_fold_char: .space 1
csv_find_visible_scroll_rows: .space 1
csv_find_bottom0: .space 1
csv_find_bottom1: .space 1
csv_find_save_inq: .space 1
csv_find_save_qp: .space 1
csv_find_save_data: .space 1
csv_find_save_end: .space 1
csv_find_save_pa0: .space 1
csv_find_save_pa1: .space 1
csv_find_save_pa2: .space 1
csv_find_save_pa3: .space 1
csv_find_buf: .space 64
csv_replace_buf: .space 64

; Sort engine moved to EDIT.PRG.  These small shared reader variables
; remain resident because Find uses the quote-aware A-field reader.
csv_sort_rowa0: .space 1
csv_sort_rowa1: .space 1
csv_sort_ca: .space 1
csv_sort_a_inq: .space 1
csv_sort_a_qp: .space 1
csv_sort_a_data: .space 1
csv_sort_a_end: .space 1
csv_sort_a_char: .space 1


    .section zdata,bss

runtime_screen_rows:
    .space 1
runtime_view_rows:
    .space 1
runtime_last_row:
    .space 1
runtime_replace_row:
    .space 1

    .section zzpage,bss
; Two shared 32-bit ZP pointers retained for Find/Fill helpers.
csv_sort_ptra0: .space 1
csv_sort_ptra1: .space 1
csv_sort_ptra2: .space 1
csv_sort_ptra3: .space 1
csv_sort_ptrb0: .space 1
csv_sort_ptrb1: .space 1
csv_sort_ptrb2: .space 1
csv_sort_ptrb3: .space 1

csv_sort_pa0  .equ csv_sort_ptra0
csv_sort_pa1  .equ csv_sort_ptra1
csv_sort_pa2  .equ csv_sort_ptra2
csv_sort_pa3  .equ csv_sort_ptra3
csv_sort_src0 .equ csv_sort_ptra0
csv_sort_src1 .equ csv_sort_ptra1
csv_sort_src2 .equ csv_sort_ptra2
csv_sort_src3 .equ csv_sort_ptra3
csv_sort_dst0 .equ csv_sort_ptrb0
csv_sort_dst1 .equ csv_sort_ptrb1
csv_sort_dst2 .equ csv_sort_ptrb2
csv_sort_dst3 .equ csv_sort_ptrb3


; Long logical and serialized Attic pointers.
csv_long_ptr0:
    .space 1
csv_long_ptr1:
    .space 1
csv_long_ptr2:
    .space 1
csv_long_ptr3:
    .space 1

csv_long_ser_ptr0:
    .space 1
csv_long_ser_ptr1:
    .space 1
csv_long_ser_ptr2:
    .space 1
csv_long_ser_ptr3:
    .space 1

csv_edit_ptr0:
    .space 1
csv_edit_ptr1:
    .space 1
csv_edit_ptr2:
    .space 1
csv_edit_ptr3:
    .space 1
csv_edit_src0:
    .space 1
csv_edit_src1:
    .space 1
csv_edit_src2:
    .space 1
csv_edit_src3:
    .space 1
csv_edit_dst0:
    .space 1
csv_edit_dst1:
    .space 1
csv_edit_dst2:
    .space 1
csv_edit_dst3:
    .space 1

style_color_ptr0:
    .space 1
style_color_ptr1:
    .space 1
style_color_ptr2:
    .space 1
style_color_ptr3:
    .space 1

scroll_src0:
    .space 1
scroll_src1:
    .space 1
scroll_src2:
    .space 1
scroll_src3:
    .space 1

scroll_dst0:
    .space 1
scroll_dst1:
    .space 1
scroll_dst2:
    .space 1
scroll_dst3:
    .space 1

; Puntatore temporaneo alla tabella larghezze $08200000.
colwidth_ptr0:
    .space 1
colwidth_ptr1:
    .space 1
colwidth_ptr2:
    .space 1
colwidth_ptr3:
    .space 1
