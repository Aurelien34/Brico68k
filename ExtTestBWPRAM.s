	include "inc/define.inc"

    global EXT_TEST_WRAM
    global EXT_TEST_BRAM
    global EXT_TEST_PRAM

	section	text

EXT_TEST_WRAM:
	move.b #0,d7 ; Work test
	move.l #RAM_START, a6
	move.l #RAM_END, a5
	jmp START_TEST

EXT_TEST_BRAM:
	move.b #1,d7 ; Backup test
	move.l #BACKUP_RAM_START, a6
	move.l #BACKUP_RAM_END, a5
	move.b #$ff, $3A001D; unprotect backup RAM
	jmp START_TEST

EXT_TEST_PRAM:
	move.b #2,d7 ; Palette test
	move.l #PALETTE_RAM_START, a6
	move.l #PALETTE_RAM_END, a5
	jmp START_TEST

START_TEST:

	; Pretty print test type
	cmp.b #1, d7	; 1 is BRAM test
	beq .titleBRAM
	cmp.b #2, d7	; 2 is PRAM test
	beq .titlePRAM
	; WRAM
	move.l #.lblTestWram,a1
	jmp .startTest
.titleBRAM
	; BRAM
	move.l #.lblTestBram,a1
	jmp .startTest
.titlePRAM
	; PRAM
	move.l #.lblTestPram,a1
	jmp .startTest
.startTest
	PrintA1

	; Write all zeroes
    Print "> 0000 Test "
	move.l a6,a1
.writeZeroesLoop:
	WatchDog
	move.w #$0000,(a1)+
	cmp.l a5,a1
	bne .writeZeroesLoop
	WatchDog

	; Check all zeroes
	move.l a6,a1
.readZeroesLoop:
	WatchDog
	move.w (a1)+,d1
	cmp.w #$0000,d1
	bne .reportResultError
	cmp.l a5,a1
	bne .readZeroesLoop
	WatchDog
	move.l #.lblTestSuccess,a1
    PrintA1

	; Write all 5555
    Print "> 5555 Test "
	move.l a6,a1
.write5555Loop:
	WatchDog
	move.w #$5555,(a1)+
	cmp.l a5,a1
	bne .write5555Loop
	WatchDog

	; Check all 5555
	move.l a6,a1
.read5555Loop:
	WatchDog
	move.w (a1)+,d1
	cmp.w #$5555,d1
	bne .reportResultError
	cmp.l a5,a1
	bne .read5555Loop
	WatchDog
	move.l #.lblTestSuccess,a1
    PrintA1

	; Write a1
    Print "> Increment Test "
	move.l a6,a1
.writea1Loop:
	WatchDog
	move.w a1,d1
	lsr.w d1
	move.w d1,(a1)+
	cmp.l a5,a1
	bne .writea1Loop
	WatchDog

	; Check a1
	move.l a6,a1
.reada1Loop:
	WatchDog
	move.w a1,d2
	lsr.w d2
	move.w (a1)+,d1
	cmp.w d2,d1
	bne .reportResultError
	cmp.l a5,a1
	bne .reada1loop
	WatchDog
	move.l #.lblTestSuccess,a1
    PrintA1

    ; Complete success!
	move.l #.lblTestFinal,a1
    PrintA1
	move.l #.lblTestSuccess,a1
    PrintA1

.reportResultOK:

    jmp .endOfTest;

.reportResultError:
	move.l #.lblTestFailure,a1
    PrintA1
	move.l #.lblTestFinal,a1
    PrintA1
	move.l #.lblTestFailure,a1
    PrintA1

    jmp .endOfTest;

.endOfTest:
	move.b #$ff, $3A000D; protect backup RAM

    ; End of transmission
    WriteEOT

	jmp .data
.lblTestWram:
	dc.b "Work RAM (WRAM) test",10,0
.lblTestBram:
	dc.b "Backup RAM (BRAM) test",10,0
.lblTestPram:
	dc.b "Palette RAM (PRAM) test",10,0
.lblTestSuccess:
	dc.b "Success",10,0
.lblTestFailure:
	dc.b "Failure",10,0
.lblTestFinal:
	dc.b "=> Test ",0
	even
.data

    ; Jump back to the command loop
    jmp WAIT_FOR_COMMAND