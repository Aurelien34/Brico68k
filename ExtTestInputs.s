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
.lbl0;
	dc.b "0", 0
.lbl1;
	dc.b "1", 0
	even
.data

    ; Jump back to the command loop
    jmp WAIT_FOR_COMMAND