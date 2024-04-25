	include "inc/define.inc"

    global EXT_MEMDUMP

	section	text

EXT_MEMDUMP:

	; Return address to the host
    move.l (BRICO_COMMAND_PARAM_1).l,d0
    PortWriteD0
    move.l (BRICO_COMMAND_PARAM_1).l,d0
	swap d0
    PortWriteD0

	; Load base address => a2
    move.l (BRICO_COMMAND_PARAM_1).l,a2
	; Compute end of dump address => a3
    move.l (BRICO_COMMAND_PARAM_2).l,d0
	lsl.l d0 ; word size = x2 address increment
	move.l a2,a3
	add.l d0,a3

	; Now iterate from a2 to a3
.loop
	cmp.l a2,a3
	beq .endloop
	move.w (a2)+,d0
	PortWriteD0
	jmp .loop
.endloop;

    ; End of transmission
    WriteEOT

    ; Jump back to the command loop
    jmp WAIT_FOR_COMMAND