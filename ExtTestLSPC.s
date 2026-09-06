    include "inc/define.inc"

    global EXT_TEST_LSPC

    section text

    ; d5.w = pattern under test  (safe across printWord / Print)
    ; d1.w = value read back     (safe across printWord / Print)
    ; d7.w = global error flag   (0 = all OK, 1 = at least one failure)
    ;
    ; REG_LSPCMODE: not tested - upper bits reflect live scanline counter
    ; REG_TIMERHIGH/TIMERLOW: write-only countdown timers, not readable
    ; REG_VRAMADD: not directly readable - LSPC2 internal scan continuously
    ;              overwrites the address counter; tested via VRAMRW round-trip

EXT_TEST_LSPC:
    PrintLn "LSPC2-A2 register test"
    move.w #0, d7

    ; =============================================
    ; REG_VRAMMOD ($3C0004) - write/readback
    ; =============================================
    WatchDog
    Print "> REG_VRAMMOD   "
    move.w #$0000, d5
    move.w d5, REG_VRAMMOD
    move.w REG_VRAMMOD, d1
    cmp.w d5, d1
    bne .failVRAMMOD
    move.w #$5555, d5
    move.w d5, REG_VRAMMOD
    move.w REG_VRAMMOD, d1
    cmp.w d5, d1
    bne .failVRAMMOD
    move.w #$AAAA, d5
    move.w d5, REG_VRAMMOD
    move.w REG_VRAMMOD, d1
    cmp.w d5, d1
    bne .failVRAMMOD
    move.w #$FFFF, d5
    move.w d5, REG_VRAMMOD
    move.w REG_VRAMMOD, d1
    cmp.w d5, d1
    bne .failVRAMMOD
    PrintLn "OK"
    jmp .testVRAMADD
.failVRAMMOD:
    PrintLn "FAIL"
    move.w #1, d7
    Print "  written=0x"
    move.l d5, d0
    JsrA6 printWord
    Print " read=0x"
    move.l d1, d0
    JsrA6 printWord
    move.l #.lblNl, a1
    PrintA1

    ; =============================================
    ; REG_VRAMADD + REG_VRAMRW round-trip
    ; REG_VRAMADD is not directly readable: the LSPC2 internal sprite scan
    ; continuously overwrites the address counter between 68k accesses.
    ; Test: write address, write VRAMRW, re-set same address, read VRAMRW back.
    ; Uses VRAM $7F00 (sprite 508 SCB1 area - safe, not displayed).
    ; =============================================
.testVRAMADD:
    WatchDog
    Print "> REG_VRAMADD   "
    move.w #$7F00, REG_VRAMADD
    move.w #1, REG_VRAMMOD
    Nop4
    move.w #$A5A5, REG_VRAMRW
    Nop8
    move.w #$7F00, REG_VRAMADD
    move.w #0, REG_VRAMMOD
    Nop4
    move.w REG_VRAMRW, d1
    cmp.w #$A5A5, d1
    bne .failVRAMADD
    PrintLn "OK"
    jmp .testAutoInc
.failVRAMADD:
    PrintLn "FAIL"
    move.w #1, d7
    Print "  expected=0xA5A5 read=0x"
    move.l d1, d0
    JsrA6 printWord
    move.l #.lblNl, a1
    PrintA1

    ; =============================================
    ; VRAM auto-increment behavioral test
    ; Write two distinct patterns with VRAMMOD=4, then verify each appears
    ; at the correct VRAM offset (does not rely on VRAMADD readback).
    ; =============================================
.testAutoInc:
    WatchDog
    Print "> VRAM auto-inc "
    move.w #$7F00, REG_VRAMADD
    move.w #4, REG_VRAMMOD
    Nop4
    move.w #$1234, REG_VRAMRW   ; -> VRAM[$7F00], addr -> $7F04
    Nop4
    move.w #$5678, REG_VRAMRW   ; -> VRAM[$7F04], addr -> $7F08
    Nop8
    move.w #0, REG_VRAMMOD
    move.w #$7F00, REG_VRAMADD
    Nop4
    move.w REG_VRAMRW, d1
    cmp.w #$1234, d1
    bne .failAutoInc
    move.w #$7F04, REG_VRAMADD
    Nop4
    move.w REG_VRAMRW, d1
    cmp.w #$5678, d1
    bne .failAutoInc
    PrintLn "OK"
    jmp .allDone
.failAutoInc:
    PrintLn "FAIL"
    move.w #1, d7
    Print "  read=0x"
    move.l d1, d0
    JsrA6 printWord
    move.l #.lblNl, a1
    PrintA1

    ; =============================================
    ; Restore safe state and print final result
    ; =============================================
.allDone:
    move.w #$0000, REG_VRAMADD
    move.w #1, REG_VRAMMOD
    cmp.w #0, d7
    bne .globalFail
    PrintLn "=> Test success"
    jmp .done
.globalFail:
    PrintLn "=> Test failure"
    jmp .done

.lblNl:
    dc.b "",10,0
    even

.done:
    WriteEOT
    jmp WAIT_FOR_COMMAND
