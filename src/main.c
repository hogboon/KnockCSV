#include <stdint.h>
#include "screen.h"

extern void loadcsv(void);
extern void csvindex(void);
extern void csvviewloop(void);
extern void style_seam_init(void);
extern void splash_show(void);

#define KEY_L           0x4c

#define ASCIIKEY (*(volatile uint8_t *)0xD610)
#define MODKEY   (*(volatile uint8_t *)0xD60A)

/* Overlay return marker used by EDIT/SEARCH -> KnockCSV chain loading. */
#define OVL_MAGIC       (*(volatile uint8_t *)0x1F00)
#define OVL_MAGIC_VALUE 0xA5

static uint8_t keyboard_get_event(void)
{
    uint8_t ch;

    /*
     * MODKEY bit 7:
     * 1 = almeno un evento presente nella coda.
     */
    if ((MODKEY & 0x80) == 0) {
        return 0;
    }

    ch = ASCIIKEY;

    /*
     * Scrivere un valore in ASCIIKEY elimina l'evento corrente
     * e rende disponibile il successivo.
     */
    ASCIIKEY = 0;

    /*
     * $FF significa che l'evento non ha una rappresentazione ASCII
     * utilizzabile.
     */
    if (ch == 0xFF) {
        return 0;
    }

    /*
     * Il tuo switch usa lettere maiuscole:
     * KEY_P = $50, KEY_G = $47, ecc.
     *
     * ASCIIKEY restituisce normalmente lettere minuscole quando
     * non viene premuto Shift, quindi vengono normalizzate.
     */
    if (ch >= 'a' && ch <= 'z') {
        ch -= ('a' - 'A');
    }

    return ch;
}

int main(void)
{
    cls();

    /* KnockCSV now runs permanently in VIC-IV SEAM / CHR16 mode. */
    style_seam_init();

    /* Show the splash only on a real program start.  When EDIT/SEARCH
     * chain-load KnockCSV again, OVL_MAGIC is still $A5 until csvviewloop()
     * restores the viewer state, so the splash is correctly skipped. */
    if (OVL_MAGIC != OVL_MAGIC_VALUE) {
        splash_show();

        /*
         * The true FCM splash uses $40000-$4F9FF for its 320x200
         * character pixels.  $40000 is also KnockCSV's normal screen RAM,
         * so rebuild the known-good SEAM screen/color state after the
         * splash has restored the VIC-IV registers.
         */
        style_seam_init();
    }

    csvviewloop();

    return 0;
}