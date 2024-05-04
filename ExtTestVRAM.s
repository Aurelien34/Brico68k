	include "inc/define.inc"

    global EXT_TEST_VRAM_LOWER
    global EXT_TEST_VRAM_UPPER

	section	text

    ; d7 = start of local address space in words
    ; d6 = RAM size - 1 in words

EXT_TEST_VRAM_LOWER:
    move.w #0, d7
    move.w #$7fff, d6
    jmp EXT_TEST_VRAM

EXT_TEST_VRAM_UPPER:
    move.w #$8000, d7
    move.w #$5ff, d6; after $8600, data is set by the video IC
    jmp EXT_TEST_VRAM

EXT_TEST_VRAM:

    PrintLn "VRAM test"

    ; Set VRAM start address
    move.w d7,REG_VRAMADD

    ; Increment after each write
    move.w #1,REG_VRAMMOD

    ; Prepare the loop on words
    move.w #0,d3
    move.w d6,d2
.writeLoop
    WatchDog
    Nop4
    ; Write test value
    move.w d3,REG_VRAMRW
    add.w #1, d3
    ; Loop
    dbra d2, .writeLoop
    Nop8

    ; Prepare the loop on 16384 words of slow VRAM
    move.w #0,d3
    move.w d6,d2
.readLoop
    WatchDog
    ; Set address to be read
    move.w d7,REG_VRAMADD
    ; Read VRAM data
    move.w REG_VRAMRW, d1
    ; Compare
    cmp.w d1,d3
    bne .error
    add.w #1,d7
    add.w #1,d3
    dbra d2, .readLoop
    PrintLn "=> Test success"
    jmp .done

.error:
    move.w d7,$100000
    move.w d1,$100002
    move.w d3,$100004
	move.l #.lblErrorMessage,a1
    PrintA1
    jmp .done

.done
    ; End of transmission
    WriteEOT

    ; Jump back to the command loop
    jmp WAIT_FOR_COMMAND

.lblErrorMessage:
	dc.b "=> Test failure ", 10
	dc.b "Dump 3 words @$100000", 10
	dc.b "- Address where the error occurred", 10
	dc.b "- Word read", 10
	dc.b "- Word expected", 0
