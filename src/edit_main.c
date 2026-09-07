#include <stdint.h>

extern void chain_knockcsv(void);
extern void edit_copy_multicell(void);
extern void edit_paste_multicell(void);
extern void edit_cut_multicell(void);
extern void edit_delete_multicell(void);
extern void edit_fill(void);
extern void edit_structure(void);
extern void edit_sort(void);

#define OVL_COMMAND (*(volatile uint8_t *)0x1F01)
#define OVL_DIRTY   (*(volatile uint8_t *)0x1F26)
#define MODKEYS_IMM (*(volatile uint8_t *)0xD611)
#define MODKEY_MEGA 0x40

int main(void)
{
    /* Command 1 = multicell Copy. */
    if (OVL_COMMAND == 1) {
        edit_copy_multicell();
    } else if (OVL_COMMAND == 2) {
        edit_paste_multicell();
    } else if (OVL_COMMAND == 3) {
        edit_cut_multicell();
    } else if (OVL_COMMAND == 4) {
        edit_delete_multicell();
    } else if (OVL_COMMAND >= 5 && OVL_COMMAND <= 12) {
        edit_fill();
    } else if (OVL_COMMAND >= 13 && OVL_COMMAND <= 18) {
        edit_structure();
    } else if (OVL_COMMAND >= 19 && OVL_COMMAND <= 24) {
        edit_sort();
    }

    /*
     * A Fill shortcut can finish before MEGA has physically been released.
     * Returning immediately would let the viewer read the same held chord
     * again and chain-load EDIT.PRG repeatedly (drive LED flashing/freeze).
     * Wait only when the command was a Fill operation and MEGA is still down.
     * Mouse/menu Fill is unaffected because MEGA is already clear.
     */
    if (OVL_COMMAND >= 5 && OVL_COMMAND <= 12) {
        while (MODKEYS_IMM & MODKEY_MEGA) { }
    }

    /*
     * Copy (command 1) does not alter the CSV. All other EDIT overlay
     * commands are mutating operations.
     */
    if (OVL_COMMAND >= 2 && OVL_COMMAND <= 24) {
        OVL_DIRTY = 1;
    }

    /* Return to the viewer after the shortcut chord has been released. */
    chain_knockcsv();

    for (;;) { }
}
