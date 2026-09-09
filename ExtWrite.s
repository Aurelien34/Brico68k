	include "inc/define.inc"

    global EXT_WRITE
    global EXT_WRITE_B

	section	text

EXT_WRITE:

    ; Read word to be written
    move.l (BRICO_COMMAND_PARAM_1).l,d0

    ; Read address
    move.l (BRICO_COMMAND_PARAM_2).l,a0

    ; Write data
    move.w d0,(a0)

    ; End of transmission
    WriteEOT

    ; Jump back to the command loop
    jmp WAIT_FOR_COMMAND

EXT_WRITE_B:

    ; Read byte to be written
    move.b (BRICO_COMMAND_PARAM_1+3).l,d0 ; take the first byte of the dword

    ; Read address
    move.l (BRICO_COMMAND_PARAM_2).l,a0

    ; Write data
    move.b d0,(a0)

    ; End of transmission
    WriteEOT

    ; Jump back to the command loop
    jmp WAIT_FOR_COMMAND