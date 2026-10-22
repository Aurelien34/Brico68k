	include "inc/define.inc"

    global EXT_COLOR

	section	text

EXT_COLOR:

    ; Read color
    move.l (BRICO_COMMAND_PARAM_1).l,d0

    ; Point to palettes area
    move.l #$400000,a0

    ; Set backdrop color
    move.w #$8000,(a0)+

    ; Set last color address
    move.l #$402000,a1

    ; Iterate through colors
.loop:
    move.w d0,(a0)+
    cmp.l a0,a1
    bne .loop

    ; End of transmission
    WriteEOT

    ; Jump back to the command loop
    jmp WAIT_FOR_COMMAND