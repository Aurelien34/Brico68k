    include "inc/define.inc"

    global EXT_TEST_MARCH_VRAM_LOWER
    global EXT_TEST_MARCH_VRAM_UPPER

    section text

    ; d7.w = VRAM start address in words
    ; d6.w = VRAM size - 1 in words

EXT_TEST_MARCH_VRAM_LOWER:
    move.w #0, d7
    move.w #$7fff, d6
    jmp EXT_TEST_MARCH_VRAM

EXT_TEST_MARCH_VRAM_UPPER:
    move.w #$8000, d7
    move.w #$5ff, d6
    jmp EXT_TEST_MARCH_VRAM

EXT_TEST_MARCH_VRAM:
    PrintLn "March-C VRAM test"

    ; --- Pass 1 : up(w0) ---
    Print "> Pass 1 up(w0)    "
    move.w d7, REG_VRAMADD
    move.w #1, REG_VRAMMOD
    move.w d6, d2
.pass1Loop:
    WatchDog
    Nop4
    move.w #$0000, REG_VRAMRW
    dbra d2, .pass1Loop
    Nop8
    PrintLn "OK"

    ; --- Pass 2 : up(r0,w1) ---
    ; REG_VRAMMOD=0 : address is not auto-incremented, allowing read then write to the same cell
    Print "> Pass 2 up(r0,w1) "
    move.w #0, REG_VRAMMOD
    move.w d7, d4
    move.w d6, d2
.pass2Loop:
    WatchDog
    move.w d4, REG_VRAMADD
    move.w REG_VRAMRW, d1
    cmp.w #$0000, d1
    bne .error2
    Nop4
    move.w #$FFFF, REG_VRAMRW
    add.w #1, d4
    dbra d2, .pass2Loop
    Nop8
    PrintLn "OK"

    ; --- Pass 3 : up(r1,w0) ---
    Print "> Pass 3 up(r1,w0) "
    move.w #0, REG_VRAMMOD
    move.w d7, d4
    move.w d6, d2
.pass3Loop:
    WatchDog
    move.w d4, REG_VRAMADD
    move.w REG_VRAMRW, d1
    cmp.w #$FFFF, d1
    bne .error3
    Nop4
    move.w #$0000, REG_VRAMRW
    add.w #1, d4
    dbra d2, .pass3Loop
    Nop8
    PrintLn "OK"

    ; --- Pass 4 : dn(r0,w1) ---
    ; No VRAMMOD for descending: decrement d4 manually after each cell
    Print "> Pass 4 dn(r0,w1) "
    move.w #0, REG_VRAMMOD
    move.w d7, d4
    add.w d6, d4            ; d4 = last valid address
    move.w d6, d2
.pass4Loop:
    WatchDog
    move.w d4, REG_VRAMADD
    move.w REG_VRAMRW, d1
    cmp.w #$0000, d1
    bne .error4
    Nop4
    move.w #$FFFF, REG_VRAMRW
    sub.w #1, d4
    dbra d2, .pass4Loop
    Nop8
    PrintLn "OK"

    ; --- Pass 5 : dn(r1,w0) ---
    Print "> Pass 5 dn(r1,w0) "
    move.w #0, REG_VRAMMOD
    move.w d7, d4
    add.w d6, d4
    move.w d6, d2
.pass5Loop:
    WatchDog
    move.w d4, REG_VRAMADD
    move.w REG_VRAMRW, d1
    cmp.w #$FFFF, d1
    bne .error5
    Nop4
    move.w #$0000, REG_VRAMRW
    sub.w #1, d4
    dbra d2, .pass5Loop
    Nop8
    PrintLn "OK"

    ; --- Pass 6 : up(r0) ---
    Print "> Pass 6 up(r0)    "
    move.w #0, REG_VRAMMOD
    move.w d7, d4
    move.w d6, d2
.pass6Loop:
    WatchDog
    move.w d4, REG_VRAMADD
    move.w REG_VRAMRW, d1
    cmp.w #$0000, d1
    bne .error6
    add.w #1, d4
    dbra d2, .pass6Loop
    PrintLn "OK"

    PrintLn "=> Test success"
    jmp .done

.error2:
    move.w #2, d5
    move.w #$0000, d3
    jmp .error
.error3:
    move.w #3, d5
    move.w #$FFFF, d3
    jmp .error
.error4:
    move.w #4, d5
    move.w #$0000, d3
    jmp .error
.error5:
    move.w #5, d5
    move.w #$FFFF, d3
    jmp .error
.error6:
    move.w #6, d5
    move.w #$0000, d3
    jmp .error

.error:
    ; d4 = error address, d1 = read, d3 = expected, d5 = pass
    ; printWord clobbers d4 -- save error address to d6 (size-1 no longer needed)
    move.w d4, d6
    move.w d5, $100000
    move.w d6, $100002
    move.w d1, $100004
    move.w d3, $100006

    PrintLn "=> March-C failure"

    Print "- Pass    : 0x"
    move.l d5, d0
    JsrA6 printWord
    move.l #.lblNl, a1
    PrintA1

    Print "- Address : 0x"
    move.l d6, d0
    JsrA6 printWord
    move.l #.lblNl, a1
    PrintA1

    Print "- Read    : 0x"
    move.l d1, d0
    JsrA6 printWord
    move.l #.lblNl, a1
    PrintA1

    Print "- Expected: 0x"
    move.l d3, d0
    JsrA6 printWord
    move.l #.lblNl, a1
    PrintA1

.lblNl:
    dc.b "",10,0
    even

.done:
    WriteEOT
    jmp WAIT_FOR_COMMAND
