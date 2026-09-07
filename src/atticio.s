    .public attic_addr0
    .public attic_addr1
    .public attic_addr2
    .public attic_addr3

    .public attic_val0
    .public attic_val1

    .public attic_read16
    .public attic_write8
	.public attic_read8

    .section code,text

attic_read16:
    ldz #0
    lda [attic_addr0],z
    sta attic_val0
    inz
    lda [attic_addr0],z
    sta attic_val1
    rts

attic_write8:
    ldz #0
    lda attic_val0
    sta [attic_addr0],z
    rts
	
attic_read8:
    ldz #0
    lda [attic_addr0],z
    sta attic_val0
    rts


    .section zzpage,bss

attic_addr0: .space 1
attic_addr1: .space 1
attic_addr2: .space 1
attic_addr3: .space 1

    .section zdata,bss

attic_val0: .space 1
attic_val1: .space 1