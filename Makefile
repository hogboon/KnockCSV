TARGET := KnockCSV
EDIT_TARGET := edit
SEARCH_TARGET := search

PRG := $(TARGET).prg
LST := $(TARGET).lst
EDIT_PRG := $(EDIT_TARGET).prg
EDIT_LST := $(EDIT_TARGET).lst
SEARCH_PRG := $(SEARCH_TARGET).prg
SEARCH_LST := $(SEARCH_TARGET).lst

SRCDIR := src
OBJDIR := obj

CC := cc6502
AS := as6502
LD := ln6502

CPU      := --target=mega65
LDSCRIPT := mega65-plain.scm

CFLAGS  := $(CPU) -O2 -g
ASFLAGS := $(CPU) -g

LDFLAGS := $(CPU) $(LDSCRIPT) \
	-g \
	--output-format=prg \
	--cross-reference

# -----------------------------------------------------------------------------
# KnockCSV residente
# -----------------------------------------------------------------------------

CSV_C_SRCS := \
	$(SRCDIR)/main.c

CSV_S_SRCS := \
	$(SRCDIR)/atticio.s \
	$(SRCDIR)/loadcsv.s \
	$(SRCDIR)/csvindex.s \
	$(SRCDIR)/csvrowaddr.s \
	$(SRCDIR)/csvprintrow.s \
	$(SRCDIR)/csvview.s \
	$(SRCDIR)/screen.s \
	$(SRCDIR)/csvmenu.s \
	$(SRCDIR)/csvfilebrowser.s \
	$(SRCDIR)/mouse.s \
	$(SRCDIR)/spritecursor.s \
	$(SRCDIR)/busycursor.s \
	$(SRCDIR)/style.s \
	$(SRCDIR)/splash.s \
	$(SRCDIR)/chain_edit.s \
	$(SRCDIR)/chain_search.s

CSV_C_OBJS := $(patsubst $(SRCDIR)/%.c,$(OBJDIR)/csv_%.o,$(CSV_C_SRCS))
CSV_S_OBJS := $(patsubst $(SRCDIR)/%.s,$(OBJDIR)/csv_%.o,$(CSV_S_SRCS))
CSV_OBJS := $(CSV_C_OBJS) $(CSV_S_OBJS)

# -----------------------------------------------------------------------------
# EDIT.PRG - primo chain overlay di prova
# Usa LO STESSO mega65-plain.scm del programma principale.
# -----------------------------------------------------------------------------

EDIT_C_OBJS := $(OBJDIR)/edit_edit_main.o
EDIT_S_OBJS := $(OBJDIR)/edit_chain_KnockCSV.o $(OBJDIR)/edit_busycursor.o $(OBJDIR)/edit_copy.o $(OBJDIR)/edit_paste.o $(OBJDIR)/edit_cut.o $(OBJDIR)/edit_fill.o $(OBJDIR)/edit_struct.o $(OBJDIR)/edit_sort.o $(OBJDIR)/edit_atticio.o $(OBJDIR)/edit_csvrowaddr.o
EDIT_OBJS := $(EDIT_C_OBJS) $(EDIT_S_OBJS)

# -----------------------------------------------------------------------------
# SEARCH.PRG - overlay dedicato a Find / Replace
# Usa LO STESSO mega65-plain.scm del programma principale.
# -----------------------------------------------------------------------------

SEARCH_C_OBJS := $(OBJDIR)/search_main.o
SEARCH_S_OBJS := \
	$(OBJDIR)/search_searchview.o \
	$(OBJDIR)/search_busycursor.o \
	$(OBJDIR)/csv_atticio.o \
	$(OBJDIR)/csv_loadcsv.o \
	$(OBJDIR)/csv_csvindex.o \
	$(OBJDIR)/csv_csvrowaddr.o \
	$(OBJDIR)/csv_csvprintrow.o \
	$(OBJDIR)/csv_screen.o \
	$(OBJDIR)/csv_csvmenu.o \
	$(OBJDIR)/csv_csvfilebrowser.o \
	$(OBJDIR)/csv_mouse.o \
	$(OBJDIR)/csv_spritecursor.o \
	$(OBJDIR)/csv_style.o \
	$(OBJDIR)/csv_chain_edit.o \
	$(OBJDIR)/edit_chain_KnockCSV.o

SEARCH_OBJS := $(SEARCH_C_OBJS) $(SEARCH_S_OBJS)

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------

all: $(PRG) $(EDIT_PRG) $(SEARCH_PRG)

$(OBJDIR):
	mkdir -p $(OBJDIR)

$(OBJDIR)/csv_%.o: $(SRCDIR)/%.c | $(OBJDIR)
	$(CC) $(CFLAGS) -o $@ $<

$(OBJDIR)/csv_%.o: $(SRCDIR)/%.s | $(OBJDIR)
	$(AS) $(ASFLAGS) -o $@ $<

$(OBJDIR)/edit_edit_main.o: $(SRCDIR)/edit_main.c | $(OBJDIR)
	$(CC) $(CFLAGS) -o $@ $<

$(OBJDIR)/edit_chain_KnockCSV.o: $(SRCDIR)/chain_KnockCSV.s | $(OBJDIR)
	$(AS) $(ASFLAGS) -o $@ $<

$(OBJDIR)/edit_busycursor.o: $(SRCDIR)/busycursor.s | $(OBJDIR)
	$(AS) $(ASFLAGS) -o $@ $<

$(OBJDIR)/search_busycursor.o: $(SRCDIR)/busycursor.s | $(OBJDIR)
	$(AS) $(ASFLAGS) -o $@ $<

$(OBJDIR)/edit_copy.o: $(SRCDIR)/edit_copy.s | $(OBJDIR)
	$(AS) $(ASFLAGS) -o $@ $<

$(OBJDIR)/edit_paste.o: $(SRCDIR)/edit_paste.s | $(OBJDIR)
	$(AS) $(ASFLAGS) -o $@ $<

$(OBJDIR)/edit_cut.o: $(SRCDIR)/edit_cut.s | $(OBJDIR)
	$(AS) $(ASFLAGS) -o $@ $<

$(OBJDIR)/edit_fill.o: $(SRCDIR)/edit_fill.s | $(OBJDIR)
	$(AS) $(ASFLAGS) -o $@ $<

$(OBJDIR)/edit_struct.o: $(SRCDIR)/edit_struct.s | $(OBJDIR)
	$(AS) $(ASFLAGS) -o $@ $<

$(OBJDIR)/edit_sort.o: $(SRCDIR)/edit_sort.s | $(OBJDIR)
	$(AS) $(ASFLAGS) -o $@ $<

$(OBJDIR)/edit_atticio.o: $(SRCDIR)/atticio.s | $(OBJDIR)
	$(AS) $(ASFLAGS) -o $@ $<

$(OBJDIR)/edit_csvrowaddr.o: $(SRCDIR)/csvrowaddr.s | $(OBJDIR)
	$(AS) $(ASFLAGS) -o $@ $<

$(OBJDIR)/search_main.o: $(SRCDIR)/search_main.c | $(OBJDIR)
	$(CC) $(CFLAGS) -o $@ $<

$(OBJDIR)/search_searchview.o: $(SRCDIR)/searchview.s | $(OBJDIR)
	$(AS) $(ASFLAGS) -o $@ $<

$(PRG): $(CSV_OBJS)
	$(LD) $(LDFLAGS) \
		--list-file=$(LST) \
		-o $@ \
		$(CSV_OBJS)

$(EDIT_PRG): $(EDIT_OBJS)
	$(LD) $(LDFLAGS) \
		--list-file=$(EDIT_LST) \
		-o $@ \
		$(EDIT_OBJS)

$(SEARCH_PRG): $(SEARCH_OBJS)
	$(LD) $(LDFLAGS) \
		--list-file=$(SEARCH_LST) \
		-o $@ \
		$(SEARCH_OBJS)

clean:
	rm -rf $(OBJDIR)
	rm -f $(PRG) $(LST)
	rm -f $(EDIT_PRG) $(EDIT_LST)
	rm -f $(SEARCH_PRG) $(SEARCH_LST)
	rm -f *.map
	rm -f KnockCSV EDIT SEARCH

.PHONY: all clean
