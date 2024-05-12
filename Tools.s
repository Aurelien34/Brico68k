	include "inc/define.inc"

    global port_write_d0_JsrA6
    global print_a1_JsrA6

	section	text

port_write_d0_JsrA6:
    InlinePortWriteD0
    RtsA6

print_a1_JsrA6:			; string address in a1
    InlinePrintA1
    RtsA6
