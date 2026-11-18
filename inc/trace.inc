; ---------------------------------------------------------------------------
; Debugger protocol v2 constants.
; Shared with Brico16Bits/Commands/DebugProtocol.h : values MUST be identical.
; This file must not define any label (it is included by Trace.s, which has to
; assemble the same way standalone and inside the Brico68k ROM).
; ---------------------------------------------------------------------------

; BIOS patch (offset in the system ROM image, seen by the 68k at $C00000 + offset)
BIOS_PATCH_TRACE_ROUTINE_OFFSET     equ $4200
BIOS_PATCH_TRACE_ROUTINE_ADDRESS    equ $C00000+BIOS_PATCH_TRACE_ROUTINE_OFFSET ; $C04200
BIOS_PATCH_TRACE_ROUTINE_MAX_BYTES  equ $100 ; = SNK BIOS random table, already overwritten in v1 (UniBIOS 4 has code at $4310)

; Pico -> 68k mailbox (offsets in the system ROM image). $1FFFA is reserved (BricoExt)
DEBUG_MAILBOX_ARG0_OFFSET   equ $1FFF0 ; long : address (READ_MEM, WRITE_MEM) / target PC (RUN_UNTIL)
DEBUG_MAILBOX_ARG1_OFFSET   equ $1FFF4 ; long : word count (READ_MEM) / minimum SP (RUN_UNTIL) / value (WRITE_MEM, bits 0-15, bit 31 = word)
DEBUG_MAILBOX_BREAK_OFFSET  equ $1FFF8 ; word : non-zero = stop at next handler entry
DEBUG_MAILBOX_CMD_OFFSET    equ $1FFFC ; word : command code
DEBUG_MAILBOX_CTR_OFFSET    equ $1FFFE ; word : request counter, written last by the Pico

; Mailbox addresses as seen by the 68k
DEBUG_MAILBOX_ARG0          equ $C00000+DEBUG_MAILBOX_ARG0_OFFSET   ; $C1FFF0
DEBUG_MAILBOX_ARG1          equ $C00000+DEBUG_MAILBOX_ARG1_OFFSET   ; $C1FFF4
DEBUG_MAILBOX_BREAK         equ $C00000+DEBUG_MAILBOX_BREAK_OFFSET  ; $C1FFF8
DEBUG_MAILBOX_CMD           equ $C00000+DEBUG_MAILBOX_CMD_OFFSET    ; $C1FFFC
DEBUG_MAILBOX_CTR           equ $C00000+DEBUG_MAILBOX_CTR_OFFSET    ; $C1FFFE

; 68k -> Pico ports (BricoExt output port and EOT)
; Bus watcher constraint (Brico16Bits PioBusWatcherPort.pio, port_detected):
; after a read of TRACE_PORT_OUT, the Pico captures the address of the 2nd
; following system ROM access ($Cxxxxx) as the value. A "move.w <ea>,Dn" port
; read ends with "nr np" (the np is a prefetch in the handler's ROM), so the
; value read must be the first bus access of the next instruction:
;     lea     <value address>,An      ; computed BEFORE the port read
;     move.w  TRACE_PORT_OUT,Dn       ; any <ea> for the port read
;     move.w  (An),Dn                 ; or (An)+ / -(An): "nr np" / "n nr np"
; Never d16(An), (d8,An,Xn), abs.w or abs.l for the value read: they insert a
; prefetch ("np" / "n np") before the read, and the wrong address is captured.
; The code must run from system ROM (true in modes A and B), and nothing may
; read TRACE_PORT_EOT within the 2 system ROM accesses following a port read.
TRACE_PORT_OUT      equ $0C1FF02
TRACE_PORT_EOT      equ TRACE_PORT_OUT - 2

; Commands
DEBUG_CMD_STEP      equ 0
DEBUG_CMD_CONTINUE  equ 1
DEBUG_CMD_GET_REGS  equ 2
DEBUG_CMD_READ_MEM  equ 3
DEBUG_CMD_RUN_UNTIL equ 4
DEBUG_CMD_WRITE_MEM equ 5
DEBUG_WRITE_MEM_WORD equ $80000000 ; WRITE_MEM: bit 31 of ARG1 set = word write (move.w), clear = byte write (move.b)

DEBUG_PROTOCOL_MAGIC        equ $DB02
DEBUG_STOP_FRAME_WORDS      equ 5   ; MAGIC, SR, PC hi, PC lo, CTR
DEBUG_REGS_RESPONSE_WORDS   equ 37  ; d0-d7, a0-a6, SSP_INTERRUPTED, USP (2 words each), SR, PC hi, PC lo
DEBUG_READ_MEM_MAX_WORDS    equ 256

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
