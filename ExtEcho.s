	include "inc/define.inc"

    global EXT_ECHO

	section	text

EXT_ECHO:

    ; Read the first parameter
    move.l (BRICO_COMMAND_PARAM_1).l,d0

    ; Write the parameter value back to the BricoNeo
    PortWriteD0

    ; End of transmission
    WriteEOT

    ; Jump back to the command loop
    jmp WAIT_FOR_COMMAND