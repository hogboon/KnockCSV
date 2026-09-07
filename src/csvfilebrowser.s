;
; ------------------------------------------------------------
; csvfilebrowser.s
; KnockCSV - file browser SEQ centrato
;
; Finestra:
;   col 20..59 (40 char)
;   row 5..18
;
; Mostra fino a 10 file SEQ.
;
; Tasti gestiti da csvview:
;   UP / DOWN
;   RETURN
;   ESC
; ------------------------------------------------------------

    .public csvfilebrowser_open
    .public csvfilebrowser_open_saveas
    .public csvfilebrowser_close
    .public csvfilebrowser_handle_key
    .public csvfilebrowser_handle_mouse
    .public csvfilebrowser_is_open

    .extern csvnamebuf
    .extern csvnamelen

open     .equ 0xffc0
close    .equ 0xffc3
setbnk   .equ 0xff6b
setlfs   .equ 0xffba
setnam   .equ 0xffbd
chkin    .equ 0xffc6
readss   .equ 0xffb7
basin    .equ 0xffcf
clrchn   .equ 0xffcc
bsout    .equ 0xffd2
plot     .equ 0xfff0

KEY_UP      .equ 0x91
KEY_DOWN    .equ 0x11
KEY_RETURN  .equ 0x0d
KEY_ESC     .equ 0x1b
KEY_DEL     .equ 0x14

WIN_COL     .equ 20
WIN_ROW     .equ 5
WIN_WIDTH   .equ 40
LIST_ROW    .equ 7
LIST_COUNT  .equ 10

    .extern seam_plot
    .extern seam_bsout

    .extern csv_device
    .extern csv_screen_mode
    .extern csv_loaded_device
    .extern mouse_xpos
    .extern mouse_ypos
    .extern mouse_pressed

    .section code,text


; ------------------------------------------------------------
; Open browser: scan directory, reset selection, draw.
; ------------------------------------------------------------

csvfilebrowser_open:
    lda #0
    sta csvfilebrowser_mode

    ; Il file manager si apre sempre inizialmente su Drive 0
    ; (IEC device 8). La scelta Drive 0 / Drive 1 avviene poi
    ; all'interno della finestra.
    lda #8
    sta csv_device

    jsr scandir
    cmp #0
    bne browser_open_failed$

    lda #0
    sta selected_index
    sta page_top

    lda #1
    sta csvfilebrowser_is_open

    jsr draw_browser
    lda #0
    rts

browser_open_failed$:
    lda #0
    sta csvfilebrowser_is_open
    lda #0xff
    rts



; ------------------------------------------------------------
; Save As dialog.
;
; Reuses dirnames[] as temporary backup storage:
;   dirnames+0  = old csvnamelen
;   dirnames+1  = old csv_loaded_device is not needed here;
;                 csvview changes it only after confirmation.
;   dirnames+2..65 = old csvnamebuf[0..63]
;
; csvnamebuf itself becomes the editable basename while the
; dialog is open.  No extra 64-byte buffer is required.
; ------------------------------------------------------------
csvfilebrowser_open_saveas:
    lda #1
    sta csvfilebrowser_mode
    sta csvfilebrowser_is_open

    ; Keep the current document device selected.
    lda csv_loaded_device
    beq saveas_default_device$
    sta csv_device
    jmp saveas_backup$
saveas_default_device$:
    lda #8
    sta csv_device

saveas_backup$:
    lda csvnamelen
    sta dirnames

    ldx #0
saveas_backup_loop$:
    lda csvnamebuf,x
    sta dirnames+2,x
    inx
    cpx #64
    bcc saveas_backup_loop$

    ; Prefill with current basename, stripping trailing ",S".
    lda csvnamelen
    cmp #2
    bcc saveas_empty$
    sec
    sbc #2
    cmp #17
    bcc +
    lda #16
+
    sta tmp_pos
    jmp saveas_prefill_done$

saveas_empty$:
    lda #0
    sta tmp_pos

saveas_prefill_done$:
    jsr draw_browser
    lda #0
    rts


csvfilebrowser_close:
    lda #0
    sta csvfilebrowser_is_open
    sta csvfilebrowser_mode
    rts


; ------------------------------------------------------------
; INPUT: A = key
; OUTPUT:
;   A=0 -> browser remains open
;   A=1 -> file selected, csvnamebuf ready
;   A=2 -> ESC / close
; ------------------------------------------------------------

csvfilebrowser_handle_key:
    ldx csvfilebrowser_mode
    beq browser_key_open_mode$
    jmp saveas_handle_key$

browser_key_open_mode$:
    cmp #KEY_UP
    bne +
    jmp key_up$
+

    cmp #KEY_DOWN
    bne +
    jmp key_down$
+

    cmp #KEY_RETURN
    bne +
    jmp key_return$
+

    cmp #KEY_ESC
    bne +
    jmp key_esc$
+

    lda #0
    rts



; Save As keyboard:
; printable filename characters, DEL, RETURN, ESC.
; Return value:
;   A=0 dialog remains open
;   A=2 cancelled
;   A=3 confirmed, csvnamebuf contains "<name>,S"
saveas_handle_key$:
    cmp #KEY_ESC
    beq saveas_cancel$
    cmp #KEY_RETURN
    beq saveas_confirm$
    cmp #KEY_DEL
    beq saveas_delete$

    ; Keep the first implementation conservative: printable
    ; characters only, excluding comma (reserved for ",S").
    cmp #0x20
    bcc saveas_key_done$
    cmp #0x7f
    bcs saveas_key_done$
    cmp #','
    beq saveas_key_done$

    ldx tmp_pos
    cpx #16
    bcs saveas_key_done$
    sta csvnamebuf,x
    inc tmp_pos
    jsr draw_browser
saveas_key_done$:
    lda #0
    rts

saveas_delete$:
    lda tmp_pos
    beq saveas_key_done$
    dec tmp_pos
    ldx tmp_pos
    lda #0
    sta csvnamebuf,x
    jsr draw_browser
    lda #0
    rts

saveas_confirm$:
    lda tmp_pos
    beq saveas_key_done$

    ldx tmp_pos
    lda #','
    sta csvnamebuf,x
    inx
    lda #'S'
    sta csvnamebuf,x
    inx
    stx csvnamelen

    lda #0
    sta csvfilebrowser_is_open
    sta csvfilebrowser_mode
    lda #3
    rts

saveas_cancel$:
    ; Restore old filename exactly.
    lda dirnames
    sta csvnamelen
    ldx #0
saveas_restore_loop$:
    lda dirnames+2,x
    sta csvnamebuf,x
    inx
    cpx #64
    bcc saveas_restore_loop$

    lda #0
    sta csvfilebrowser_is_open
    sta csvfilebrowser_mode
    lda #2
    rts


key_up$:
    lda selected_index
    beq redraw$

    dec selected_index
    jsr adjust_page

redraw$:
    jsr draw_browser
    lda #0
    rts


key_down$:
    lda dircount
    beq down_done$

    lda selected_index
    clc
    adc #1
    cmp dircount
    bcs down_done$

    sta selected_index
    jsr adjust_page
    jsr draw_browser

down_done$:
    lda #0
    rts


key_return$:
    lda dircount
    beq return_none$

    jsr select_current_file
    jsr csvfilebrowser_close

    lda #1
    rts

return_none$:
    lda #0
    rts


key_esc$:
    jsr csvfilebrowser_close
    lda #2
    rts


; ------------------------------------------------------------
; Mouse: selezione drive/device IEC nella riga superiore.
;
;   Drive 0: device 8 <-> 10
;   Drive 1: device 9 <-> 11
;
; Cliccando un drive diverso si seleziona prima il suo device base
; (8 oppure 9). Cliccando nuovamente lo stesso drive si alterna
; tra il device interno e quello IEC esterno.
;
; Per device 8/9 drive_media_present controlla $D68B prima di IEC.
; Device 10/11 sono periferiche IEC esterne e non compaiono in $D68B,
; quindi vengono interrogate direttamente tramite KERNAL.
; ------------------------------------------------------------

csvfilebrowser_handle_mouse:
    ; HARD GUARD: a grid click must never reach browser logic
    ; when the Open/Save As window is closed.
    lda csvfilebrowser_is_open
    bne csvfilebrowser_mouse_active
    lda #0
    rts

csvfilebrowser_mouse_active:
    lda mouse_pressed
    bne +
    rts
+
    ; Native text-raster mouse Y:
    ; 80x25 = 0..199, 80x50 = 0..399.
    ; A text row is always 8 mouse units high.
    lda mouse_ypos
    lsr a
    lsr a
    lsr a
    sta browser_mouse_col
    lda mouse_ypos+1
    beq browser_mouse_y_done$
    lda browser_mouse_col
    clc
    adc #32
    sta browser_mouse_col
browser_mouse_y_done$:
    lda browser_mouse_col
    cmp #(WIN_ROW + 1)
    beq +
    rts
+
    ; X / 8 -> col 0..79.
    lda mouse_xpos+1
    lsr a
    sta browser_mouse_xhi
    lda mouse_xpos
    ror a
    lsr browser_mouse_xhi
    ror a
    lsr browser_mouse_xhi
    ror a
    sta browser_mouse_col

    ; Drive 0: cols 22..33  -- 8 <-> 10
    cmp #(WIN_COL + 2)
    bcc check_drive1_click$
    cmp #(WIN_COL + 14)
    bcs check_drive1_click$

    lda csv_device
    cmp #8
    beq drive0_to_10$
    cmp #10
    beq drive0_to_8$
    lda #8
    jmp switch_drive$

drive0_to_10$:
    lda #10
    jmp switch_drive$

drive0_to_8$:
    lda #8
    jmp switch_drive$

check_drive1_click$:
    lda browser_mouse_col
    cmp #(WIN_COL + 15)
    bcc mouse_drive_done$
    cmp #(WIN_COL + 27)
    bcs mouse_drive_done$

    lda csv_device
    cmp #9
    beq drive1_to_11$
    cmp #11
    beq drive1_to_9$
    lda #9
    jmp switch_drive$

drive1_to_11$:
    lda #11
    jmp switch_drive$

drive1_to_9$:
    lda #9

switch_drive$:
    cmp csv_device
    beq mouse_drive_done$

    sta browser_new_device
    sta csv_device

    lda csvfilebrowser_mode
    beq switch_drive_open_mode$
    jsr draw_browser
    rts

switch_drive_open_mode$:
    ; Il device selezionato resta attivo anche se non disponibile.
    ; Questo e' importante per poter passare, per esempio,
    ; Drive 1: 9 -> 11 quando il device 9 non e' montato.
    ;
    ; Per 8/9 viene controllato prima il flag hardware del MEGA65.
    ; Per 10/11 drive_media_present permette il tentativo IEC reale.
    jsr drive_media_present
    bne try_scan_selected$

drive_unavailable$:
    lda #0
    sta dircount
    sta selected_index
    sta page_top
    jsr draw_browser
    rts

try_scan_selected$:
    jsr scandir
    cmp #0
    bne drive_unavailable$

    lda #0
    sta selected_index
    sta page_top
    jsr draw_browser
    rts

mouse_drive_done$:
    rts


; ------------------------------------------------------------
; Directory scan, adapted from 3D loader.
; Stores only SEQ names, up to 32.
; ------------------------------------------------------------

scandir:
    lda #0
    sta dircount
    sta selected_index
    jsr reset_dir_line

    ; Prima di chiamare il KERNAL controlla direttamente se il
    ; media e' presente nel drive gestito dal MEGA65.
    ; $D68B bit 1 = drive 0 media present (device 8)
    ; $D68B bit 4 = drive 1 media present (device 9)
    ; In questo modo un drive 9 non montato non viene mai toccato
    ; dalle routine IEC/KERNAL, evitando il blocco del LED.
    jsr drive_media_present
    bne +
    jmp scan_error_no_close$
+

    lda #1
    ldx #.byte0 dirname
    ldy #.byte1 dirname
    jsr setnam

    lda #0
    ldx #0
    jsr setbnk

    lda #2
    ldx csv_device
    ldy #0
    jsr setlfs

    jsr open
    bcc +
    jmp scan_error$
+

    ldx #2
    jsr chkin
    bcc +
    jmp scan_error$
+
    ; CHKIN can complete with C clear even when the IEC device did not
    ; answer.  Check KERNAL I/O status before attempting BASIN; otherwise
    ; an unmounted drive (e.g. device 9) can leave us waiting in BASIN.
    jsr readss
    beq +
    jmp scan_error$
+

scan_loop$:
    jsr basin
    sta dirchar

    jsr readss
    and #0b11000011
    bne scan_done$

    lda dirchar
    and #0x7f
    sta dirchar

    beq endline$

    cmp #0x0d
    beq endline$

    cmp #0x0a
    beq endline$

    cmp #0x22
    beq quote$

    lda in_quote
    beq outside_quote$

    lda tmp_pos
    cmp #16
    bcs scan_loop$

    ldx tmp_pos
    lda dirchar
    sta tmp_name,x
    inc tmp_pos
    jmp scan_loop$

outside_quote$:
    jsr update_seq_detector
    jmp scan_loop$

quote$:
    lda in_quote
    beq open_quote$

    ldx tmp_pos
    lda #0
    sta tmp_name,x

    lda #0
    sta in_quote
    jmp scan_loop$

open_quote$:
    lda #1
    sta in_quote
    lda #0
    sta tmp_pos
    jmp scan_loop$

endline$:
    lda saw_seq
    beq nextline$

    jsr commit_tmp_name

    lda dircount
    cmp #32
    bcs scan_done$

nextline$:
    jsr reset_dir_line
    jmp scan_loop$


scan_done$:
    jsr clrchn
    lda #2
    jsr close
    lda #0
    rts

scan_error$:
    jsr clrchn
    lda #2
    jsr close

scan_error_no_close$:
    lda #0xff
    rts


; ------------------------------------------------------------
; Check disponibilita' del device.
;
; 8/9 sono i due drive gestiti dal MEGA65: $D68B viene controllato per
; evitare di entrare nelle routine IEC quando il media non e' montato.
;
; 10/11 possono essere periferiche IEC fisiche esterne. Non hanno un
; flag "media present" in $D68B, quindi qui vengono abilitati e lasciati a
; OPEN/CHKIN/READST il controllo della periferica.
;
; OUTPUT:
;   A != 0  si puo' tentare lo scan
;   A == 0  drive interno non montato / device non supportato
; ------------------------------------------------------------

drive_media_present:
    lda csv_device
    cmp #8
    beq check_drive0$
    cmp #9
    beq check_drive1$
    cmp #10
    beq external_iec$
    cmp #11
    beq external_iec$
    lda #0
    rts

external_iec$:
    lda #1
    rts

check_drive0$:
    lda 0xd68b
    and #0x02
    rts

check_drive1$:
    lda 0xd68b
    and #0x10
    rts


dirname:
    .ascii "$"


reset_dir_line:
    lda #0
    sta in_quote
    sta tmp_pos
    sta saw_seq
    sta seq_state
    sta tmp_name
    rts


update_seq_detector:
    lda dirchar

    ldx seq_state
    cpx #0
    bne seq_state1$

    cmp #'S'
    beq got_s$
    cmp #'s'
    beq got_s$
    rts

got_s$:
    lda #1
    sta seq_state
    rts

seq_state1$:
    cpx #1
    bne seq_state2$

    cmp #'E'
    beq got_e$
    cmp #'e'
    beq got_e$

    cmp #'S'
    beq got_s$
    cmp #'s'
    beq got_s$

    lda #0
    sta seq_state
    rts

got_e$:
    lda #2
    sta seq_state
    rts

seq_state2$:
    cmp #'Q'
    beq got_q$
    cmp #'q'
    beq got_q$

    cmp #'S'
    beq got_s$
    cmp #'s'
    beq got_s$

    lda #0
    sta seq_state
    rts

got_q$:
    lda #1
    sta saw_seq
    lda #0
    sta seq_state
    rts


commit_tmp_name:
    lda dircount
    jsr name_ptr_for_index

    ldx #0

commit_loop$:
    lda tmp_name,x
    ldy #0
    sta (name_ptr),y

    cmp #0
    beq commit_done$

    inc name_ptr
    bne +
    inc name_ptr+1
+
    inx
    cpx #16
    bcc commit_loop$

    ldy #0
    lda #0
    sta (name_ptr),y

commit_done$:
    inc dircount
    rts


; ------------------------------------------------------------
; selected filename -> csvnamebuf + ",S"
; ------------------------------------------------------------

select_current_file:
    lda selected_index
    jsr name_ptr_for_index

    ldx #0

select_copy$:
    ldy #0
    lda (name_ptr),y
    beq select_type$

    sta csvnamebuf,x
    inx

    inc name_ptr
    bne +
    inc name_ptr+1
+
    cpx #60
    bcc select_copy$

select_type$:
    lda #','
    sta csvnamebuf,x
    inx
    lda #'S'
    sta csvnamebuf,x
    inx

    stx csvnamelen
    rts


; ------------------------------------------------------------
; Page management
; ------------------------------------------------------------

adjust_page:
    lda selected_index
    cmp page_top
    bcs check_bottom$

    lda selected_index
    sta page_top
    rts

check_bottom$:
    lda page_top
    clc
    adc #LIST_COUNT
    sta page_limit

    lda selected_index
    cmp page_limit
    bcc page_done$

    sec
    sbc #(LIST_COUNT - 1)
    sta page_top

page_done$:
    rts


; ------------------------------------------------------------
; Draw centered window.
; ------------------------------------------------------------

draw_browser:
    ; 14 blank rows, 40 columns.
    lda #WIN_ROW
    sta draw_row

clear_rows$:
    lda draw_row
    cmp #(WIN_ROW + 14)
    bcs draw_title$

    ldx draw_row
    ldy #WIN_COL
    clc
    jsr seam_plot

    ldx #WIN_WIDTH
clear_cols$:
    lda #' '
    jsr seam_bsout
    dex
    bne clear_cols$

    inc draw_row
    jmp clear_rows$


draw_title$:
    ldx #WIN_ROW
    ldy #WIN_COL
    clc
    jsr seam_plot

    lda csvfilebrowser_mode
    beq draw_open_title$

    ldx #0
saveas_title_loop$:
    lda saveas_title_text,x
    beq draw_drives$
    jsr seam_bsout
    inx
    bne saveas_title_loop$

draw_open_title$:
    ldx #0
title_loop$:
    lda title_text,x
    beq draw_drives$
    jsr seam_bsout
    inx
    bne title_loop$


draw_drives$:
    ; Riga selezione device:
    ;   Drive 0 [8/10]     Drive 1 [9/11]
    ; Il gruppo del device attivo e' marcato con '>'.

    ldx #(WIN_ROW + 1)
    ldy #(WIN_COL + 2)
    clc
    jsr seam_plot

    lda csv_device
    cmp #8
    beq drive0_active$
    cmp #10
    beq drive0_active$
    lda #' '
    jsr seam_bsout
    jmp drive0_marker_done$
drive0_active$:
    lda #'>'
    jsr seam_bsout
drive0_marker_done$:

    ldx #0
draw_drive0_loop$:
    lda drive0_text,x
    beq draw_drive0_dev$
    jsr seam_bsout
    inx
    bne draw_drive0_loop$

draw_drive0_dev$:
    ; Mostra il device correntemente selezionato per Drive 0.
    ; Se e' attivo 10 mostra 10, altrimenti mostra 8.
    lda csv_device
    cmp #10
    beq draw_dev10$
    lda #'8'
    jsr seam_bsout
    jmp draw_drive0_close$
draw_dev10$:
    lda #'1'
    jsr seam_bsout
    lda #'0'
    jsr seam_bsout
draw_drive0_close$:
    lda #']'
    jsr seam_bsout

    ldx #(WIN_ROW + 1)
    ldy #(WIN_COL + 15)
    clc
    jsr seam_plot

    lda csv_device
    cmp #9
    beq drive1_active$
    cmp #11
    beq drive1_active$
    lda #' '
    jsr seam_bsout
    jmp drive1_marker_done$
drive1_active$:
    lda #'>'
    jsr seam_bsout
drive1_marker_done$:

    ldx #0
draw_drive1_loop$:
    lda drive1_text,x
    beq draw_drive1_dev$
    jsr seam_bsout
    inx
    bne draw_drive1_loop$

draw_drive1_dev$:
    ; Mostra il device correntemente selezionato per Drive 1.
    ; Se e' attivo 11 mostra 11, altrimenti mostra 9.
    lda csv_device
    cmp #11
    beq draw_dev11$
    lda #'9'
    jsr seam_bsout
    jmp draw_drive1_close$
draw_dev11$:
    lda #'1'
    jsr seam_bsout
    lda #'1'
    jsr seam_bsout
draw_drive1_close$:
    lda #']'
    jsr seam_bsout

    lda csvfilebrowser_mode
    beq draw_files$
    jmp draw_saveas_body$

draw_files$:
    lda #0
    sta slot

file_slot_loop$:
    lda slot
    cmp #LIST_COUNT
    bcc +
    jmp draw_footer$
+

    clc
    adc page_top
    sta entry_index

    lda entry_index
    cmp dircount
    bcs next_slot$

    ; row = LIST_ROW + slot
    lda slot
    clc
    adc #LIST_ROW
    tax
    ldy #(WIN_COL + 2)
    clc
    jsr seam_plot

    ; selection marker
    lda entry_index
    cmp selected_index
    bne not_selected$

    lda #'>'
    jsr seam_bsout
    jmp after_marker$

not_selected$:
    lda #' '
    jsr seam_bsout

after_marker$:
    lda #' '
    jsr seam_bsout

    lda entry_index
    jsr name_ptr_for_index

    ldx #0
draw_name_loop$:
    ldy #0
    lda (name_ptr),y
    beq next_slot$

    jsr seam_bsout

    inc name_ptr
    bne +
    inc name_ptr+1
+
    inx
    cpx #16
    bcc draw_name_loop$

next_slot$:
    inc slot
    jmp file_slot_loop$



draw_saveas_body$:
    ; Label
    ldx #(WIN_ROW + 4)
    ldy #(WIN_COL + 2)
    clc
    jsr seam_plot
    ldx #0
saveas_name_label_loop$:
    lda saveas_name_text,x
    beq saveas_draw_name$
    jsr seam_bsout
    inx
    bne saveas_name_label_loop$

saveas_draw_name$:
    ldx #(WIN_ROW + 5)
    ldy #(WIN_COL + 2)
    clc
    jsr seam_plot

    ; Simple input marker + basename.
    lda #'>'
    jsr seam_bsout
    lda #' '
    jsr seam_bsout

    ldx #0
saveas_name_loop$:
    cpx tmp_pos
    bcs saveas_name_pad$
    lda csvnamebuf,x
    jsr seam_bsout
    inx
    jmp saveas_name_loop$

saveas_name_pad$:
    cpx #16
    bcs saveas_footer$
    lda #' '
    jsr seam_bsout
    inx
    jmp saveas_name_pad$

saveas_footer$:
    ldx #(WIN_ROW + 13)
    ldy #(WIN_COL + 2)
    clc
    jsr seam_plot
    ldx #0
saveas_footer_loop$:
    lda saveas_footer_text,x
    beq draw_done$
    jsr seam_bsout
    inx
    bne saveas_footer_loop$


draw_footer$:
    ldx #(WIN_ROW + 13)
    ldy #(WIN_COL + 2)
    clc
    jsr seam_plot

    ldx #0
footer_loop$:
    lda footer_text,x
    beq draw_done$
    jsr seam_bsout
    inx
    bne footer_loop$

draw_done$:
    rts


title_text:
    .ascii "          oPEN csv fILE          "
    .byte 0

saveas_title_text:
    .ascii "             sAVE AS             "
    .byte 0

saveas_name_text:
    .ascii "fILE NAME:"
    .byte 0

saveas_footer_text:
    .ascii "rETURN=sAVE AS   esc=cANCEL"
    .byte 0

drive0_text:
    .ascii "dRIVE 0 ["
    .byte 0

drive1_text:
    .ascii "dRIVE 1 ["
    .byte 0

footer_text:
    .ascii "uP/dOWN  rETURN=oPEN  esc=cANCEL"
    .byte 0


; ------------------------------------------------------------
; name_ptr = dirnames + A*17
; ------------------------------------------------------------

name_ptr_for_index:
    sta tmp_index

    asl a
    asl a
    asl a
    asl a
    sta tmp_mul

    clc
    lda tmp_mul
    adc tmp_index
    sta tmp_mul

    lda #.byte0 dirnames
    sta name_ptr
    lda #.byte1 dirnames
    sta name_ptr+1

    clc
    lda name_ptr
    adc tmp_mul
    sta name_ptr
    bcc +
    inc name_ptr+1
+
    rts


; ------------------------------------------------------------
; BSS
; ------------------------------------------------------------

    .section bss,bss

csvfilebrowser_is_open:
    .space 1
csvfilebrowser_mode:
    .space 1

dircount:
    .space 1

dirnames:
    .space 544              ; 32 * 17

selected_index:
    .space 1
page_top:
    .space 1
page_limit:
    .space 1

dirchar:
    .space 1
in_quote:
    .space 1
tmp_pos:
    .space 1
saw_seq:
    .space 1
seq_state:
    .space 1

tmp_name:
    .space 17

slot:
    .space 1
entry_index:
    .space 1
draw_row:
    .space 1
tmp_index:
    .space 1
tmp_mul:
    .space 1

browser_mouse_col:
    .space 1
browser_mouse_xhi:
    .space 1
browser_old_device:
    .space 1
browser_new_device:
    .space 1


    .section zzpage,bss

name_ptr:
    .space 2
