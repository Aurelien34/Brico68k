    include "inc/define.inc"

    global port_write_d0_JsrA6
    global print_a1_JsrA6
    global printWord_JsrA6
    global getButtonStateStr_JsrA6

	section	text

port_write_d0_JsrA6:
    InlinePortWriteD0
    RtsA6

print_a1_JsrA6:			; string address in a1
    InlinePrintA1
    RtsA6

printWord_JsrA6: 
;input : d0 = 16-bit word - 0x8642 for example
;output : print a 4 digit hex value of d0
;d1 d7 d3 are used for vram test errors

    move.l d0, d2    ; save d0 to d2
    moveq.l #12, d4  ; initialize loop counter to 12 for the most significant nibble

    .hexloop:
        
        move.l d2, d0
        lsr.l d4, d0  ; shift right by the current value of d4
        andi.w #$F, d0 ; mask the lower 4 bits
        addi.w #48, d0 ; convert to ASCII

        cmpi.w #58, d0 ; if > 9
        blt.s .printChar
        addi.w #7, d0 ; convert to A-F

    .printChar:
        InlinePortWriteD0

        subi.l #4, d4 ; decrement counter by 4 bits
        bpl.s .hexloop ; continue loop if d4 >= 0

    RtsA6

getButtonStateStr_JsrA6:
; input:  d1 = byte holding the button/switch bits, d2 = bit index to test
; output: a1 = address of "PRESSED"/"released" string (0-terminated)
    btst d2,d1
    beq .buttonIsPressed
    move.l #.lblReleased,a1
    RtsA6
.buttonIsPressed:
    move.l #.lblPressed,a1
    RtsA6

.lblPressed:
    dc.b "PRESSED",10,0
.lblReleased:
    dc.b "released",10,0
    even



