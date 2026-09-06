	include "inc/define.inc"

    global EXT_TEST_INPUTS

	section	text

EXT_TEST_INPUTS:

	; DIP switches
	move.l #.lblDipSwitches,a1
    PrintA1
	move.w REG_P1CNT_REG_DIPSW,d1
	; Loop on data bits
	move.w #7,d2
.loopDip:
	btst d2, d1
	beq .showDip1
	move.l #.lbl0, a1
    PrintA1
	jmp .endShowDip
.showDip1
	move.l #.lbl1, a1
    PrintA1
.endShowDip
	dbra d2, .loopDip

	; Player 1 controls
	move.l #.lblP1Controls,a1
    PrintA1
	move.b REG_P1CNT_REG_DIPSW,d1
	; Loop on data bits
	move.w #7,d2
.loopP1Controls:
	btst d2, d1
	beq .showP1Controls1
	move.l #.lbl0, a1
    PrintA1
	jmp .endShowP1Controls
.showP1Controls1
	move.l #.lbl1, a1
    PrintA1
.endShowP1Controls
	dbra d2, .loopP1Controls
	PrintLn ""

	; Player 1 controls - clear breakdown
	move.b REG_P1CNT_REG_DIPSW,d1
	Print "  Up      : "
	move.w #0,d2
	JsrA6 getButtonStateStr
	PrintA1
	Print "  Down    : "
	move.w #1,d2
	JsrA6 getButtonStateStr
	PrintA1
	Print "  Left    : "
	move.w #2,d2
	JsrA6 getButtonStateStr
	PrintA1
	Print "  Right   : "
	move.w #3,d2
	JsrA6 getButtonStateStr
	PrintA1
	Print "  Button A: "
	move.w #4,d2
	JsrA6 getButtonStateStr
	PrintA1
	Print "  Button B: "
	move.w #5,d2
	JsrA6 getButtonStateStr
	PrintA1
	Print "  Button C: "
	move.w #6,d2
	JsrA6 getButtonStateStr
	PrintA1
	Print "  Button D: "
	move.w #7,d2
	JsrA6 getButtonStateStr
	PrintA1

	; Player 2 controls
	move.l #.lblP2Controls,a1
    PrintA1
	move.b REG_P2CNT,d1
	; Loop on data bits
	move.w #7,d2
.loopP2Controls:
	btst d2, d1
	beq .showP2Controls1
	move.l #.lbl0, a1
    PrintA1
	jmp .endShowP2Controls
.showP2Controls1
	move.l #.lbl1, a1
    PrintA1
.endShowP2Controls
	dbra d2, .loopP2Controls
	PrintLn ""

	; Player 2 controls - clear breakdown
	move.b REG_P2CNT,d1
	Print "  Up      : "
	move.w #0,d2
	JsrA6 getButtonStateStr
	PrintA1
	Print "  Down    : "
	move.w #1,d2
	JsrA6 getButtonStateStr
	PrintA1
	Print "  Left    : "
	move.w #2,d2
	JsrA6 getButtonStateStr
	PrintA1
	Print "  Right   : "
	move.w #3,d2
	JsrA6 getButtonStateStr
	PrintA1
	Print "  Button A: "
	move.w #4,d2
	JsrA6 getButtonStateStr
	PrintA1
	Print "  Button B: "
	move.w #5,d2
	JsrA6 getButtonStateStr
	PrintA1
	Print "  Button C: "
	move.w #6,d2
	JsrA6 getButtonStateStr
	PrintA1
	Print "  Button D: "
	move.w #7,d2
	JsrA6 getButtonStateStr
	PrintA1

	; StartSelect
	move.l #.lblStartSelect,a1
    PrintA1
	move.b REG_STATUS_B,d1
	; Loop on data bits
	move.w #3,d2
.loopStartSelect:
	btst d2, d1
	beq .showStartSelect1
	move.l #.lbl0, a1
    PrintA1
	jmp .endShowStartSelect
.showStartSelect1
	move.l #.lbl1, a1
    PrintA1
.endShowStartSelect
	dbra d2, .loopStartSelect
	PrintLn ""

	; Start / Select - clear breakdown, per player
	move.b REG_STATUS_B,d1
	Print "  P1 Start : "
	move.w #0,d2
	JsrA6 getButtonStateStr
	PrintA1
	Print "  P1 Select: "
	move.w #1,d2
	JsrA6 getButtonStateStr
	PrintA1
	Print "  P2 Start : "
	move.w #2,d2
	JsrA6 getButtonStateStr
	PrintA1
	Print "  P2 Select: "
	move.w #3,d2
	JsrA6 getButtonStateStr
	PrintA1

	; CoinsService
	move.l #.lblCoinsService,a1
    PrintA1
	move.b REG_STATUS_A,d1
	; Loop on data bits
	move.w #2,d2
.loopCoinsService:
	btst d2, d1
	beq .showCoinsService1
	move.l #.lbl0, a1
    PrintA1
	jmp .endShowCoinsService
.showCoinsService1
	move.l #.lbl1, a1
    PrintA1
.endShowCoinsService
	dbra d2, .loopCoinsService

	; Memory card / hardware mode (STATUS_B high nibble, $380000)
	move.l #.lblMemCard,a1
    PrintA1
	move.b REG_STATUS_B,d1

	; Raw high nibble in binary, bit 7 down to bit 4
	Print "  Bits 7654 (raw)           : "
	move.w #7,d3
	move.w #3,d2
.loopMcBits:
	btst d3,d1
	beq .showMcBit0
	move.l #.lbl1,a1
    PrintA1
	jmp .endShowMcBit
.showMcBit0:
	move.l #.lbl0,a1
    PrintA1
.endShowMcBit:
	sub.w #1,d3
	dbra d2,.loopMcBits
	PrintLn ""

	; Bits 5-4: memory card status (2-bit field)
	;   00 = card correctly inserted
	;   10 or 01 = problem with the card
	;   11 = no card connected
	btst #5,d1
	beq .mcBit5Zero
	btst #4,d1
	beq .mcProblem          ; 10
	move.l #.lblMcNoCard,a1 ; 11
    PrintA1
	jmp .mcWriteProtect
.mcBit5Zero:
	btst #4,d1
	beq .mcOk                ; 00
.mcProblem:                  ; falls through here for 01 too
	move.l #.lblMcProblem,a1
    PrintA1
	jmp .mcWriteProtect
.mcOk:
	move.l #.lblMcOk,a1
    PrintA1

.mcWriteProtect:
	; Bit 6: memory card write protected when 1
	btst #6,d1
	beq .mcNotProtected
	move.l #.lblMcWriteProtYes,a1
    PrintA1
	jmp .hwMode
.mcNotProtected:
	move.l #.lblMcWriteProtNo,a1
    PrintA1

.hwMode:
	; Bit 7: hardware mode, 0 = AES, 1 = MVS
	btst #7,d1
	bne .hwMVS
	move.l #.lblHwAES,a1
    PrintA1
	jmp .endOfTest
.hwMVS:
	move.l #.lblHwMVS,a1
    PrintA1

.endOfTest:
    ; End of transmission
    WriteEOT

	jmp .data
.lblDipSwitches:
	dc.b "87654321 DIP Switches (NEO-F0)", 10, 0
.lblP1Controls:
	dc.b 10, 10, "DCBARLDU Player 1 controls (NEO-C1)", 10, 0
.lblP2Controls:
	dc.b 10, 10, "DCBARLDU Player 2 controls (NEO-C1)", 10, 0
.lblStartSelect:
	dc.b 10, 10, "P2 Select, P2 Start, P1 Select, P1 Start (NEO-C1)", 10, 0
.lblCoinsService:
	dc.b 10, 10, "P1 Coin-in, P2 Coin-in, Service button (NEO-F0)", 10, 0
.lblMemCard:
	dc.b 10, 10, "Memory card / Hardware mode (STATUS_B $380000 high nibble)", 10, 0
.lblMcOk:
	dc.b "  Memory card status         : OK (inserted)", 10, 0
.lblMcProblem:
	dc.b "  Memory card status         : PROBLEM (check card/slot)", 10, 0
.lblMcNoCard:
	dc.b "  Memory card status         : NO CARD CONNECTED", 10, 0
.lblMcWriteProtYes:
	dc.b "  Memory card write protect  : YES", 10, 0
.lblMcWriteProtNo:
	dc.b "  Memory card write protect  : NO", 10, 0
.lblHwAES:
	dc.b "  Hardware mode             : AES", 10, 0
.lblHwMVS:
	dc.b "  Hardware mode             : MVS", 10, 0
.lbl0;
	dc.b "0", 0
.lbl1;
	dc.b "1", 0
	even
.data

    ; Jump back to the command loop
    jmp WAIT_FOR_COMMAND