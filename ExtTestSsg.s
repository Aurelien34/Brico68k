	include "inc/define.inc"

    global EXT_TEST_SSG

	section	text

EXT_TEST_SSG:

    ; Reset the audio hardware
    reset
    JsrA6 wait_for_z80
    
    ; Send the chime command (uses SSG1-4 + noise + Timer A)
    move.b #$7f, REG_SOUND
    JsrA6 wait_for_z80

    ; End of transmission
    WriteEOT

    ; Jump back to the command loop
    jmp WAIT_FOR_COMMAND

wait_for_z80_JsrA6:
    move.w #400,d0
.loop1:
    move.w #40,d1
.loop2:
    dbra.w d1,.loop2
    dbra.w d0,.loop1
    RtsA6
