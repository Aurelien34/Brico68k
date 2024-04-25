	include "inc/define.inc"

    global EXT_READ

	section	text

EXT_READ:

    ; Read address
    move.l (BRICO_COMMAND_PARAM_1).l,a0

    ; Read data
    move.w (a0),d0

    ; Send value
    PortWriteD0

    ; End of transmission
    WriteEOT

    ; Jump back to the command loop
    jmp WAIT_FOR_COMMAND