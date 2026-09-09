	macro TraceOn
    	ori.w #$8000,sr ; Activate trace flag
        nop ; Trace starts after next instruction
	endm

	macro Breakpoint
    	TraceOn
	endm

	macro TraceOff
    	and.w #$7fff,sr ; Disable trace flag
	endm
