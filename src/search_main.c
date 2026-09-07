extern void csvviewloop(void);
extern void style_seam_init(void);

int main(void)
{
    /*
     * SEARCH.PRG has its own BSS. In particular style.o's runtime
     * 80x25/80x50 VIC-IV profile variables start cleared, so initialise
     * the SEAM/style module before searchview restores OVL_SCREENMODE.
     */
    style_seam_init();

    /*
     * csvviewloop sees OVL_MAGIC, restores the shared sheet state and
     * searchview.s automatically opens Find or Replace according to
     * OVL_COMMAND.
     */
    csvviewloop();

    for (;;) { }
}
