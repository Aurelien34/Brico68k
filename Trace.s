; ---------------------------------------------------------------------------
; TRACE exception handler - live debugger protocol v2 (see inc/trace.inc).
;
; This file must assemble identically in two contexts:
;  - mode A: assembled alone as a raw binary (target trace_routine), injected by
;    the Pico at $C04200 in a standard BIOS ;
;  - mode B: linked inside the Brico68k ROM (TRACE vector).
; Hence: position independent code only (relative branches), absolute addresses
; only for the ports $C1FFxx (mailbox / BricoExt), $C2xxxx (value window) and
; $300001 (watchdog), no RAM used outside of the stack, no external label.
; Size: at most BIOS_PATCH_TRACE_ROUTINE_MAX_BYTES (checked at the end).
;
; Entry: (SP) = SR (16 bits), 2(SP) = PC (32 bits). SSP before the exception
; (SSP_INTERRUPTED) is the frame address + 6.
;
; BricoExt bus watcher constraint (see TRACE_PORT_OUT in inc/trace.inc): the
; Pico captures the 2nd system ROM access after a read of TRACE_PORT_OUT. The
; port read is a "move.w <ea>,Dn" (ends with "nr np"), so the value read must
; be the very first bus access of the next instruction: "move.w (An),Dn" with
; An computed beforehand. Never use d16(An), (d8,An,Xn) or abs for it.
; ---------------------------------------------------------------------------

	include "inc/trace.inc"

    global TRACE

; BricoExt value window: reading $C20000 + value*2 sends value to the Pico
TRACE_PORT_VALUE_BASE   equ $C20000

; Full path base register a4 = TRACE_PORT_EOT ($C1FF00): ports and mailbox
; are reached with d16(a4), the value window is at a4 + $100.
TRACE_A4_PORT_OUT       equ TRACE_PORT_OUT-TRACE_PORT_EOT
TRACE_A4_ARG0           equ DEBUG_MAILBOX_ARG0-TRACE_PORT_EOT
TRACE_A4_ARG1           equ DEBUG_MAILBOX_ARG1-TRACE_PORT_EOT
TRACE_A4_CMD            equ DEBUG_MAILBOX_CMD-TRACE_PORT_EOT
TRACE_A4_CTR            equ DEBUG_MAILBOX_CTR-TRACE_PORT_EOT
TRACE_A4_VALUE_BASE     equ TRACE_PORT_VALUE_BASE-TRACE_PORT_EOT

; Stack layout once d0-d7/a0-a6 are saved by the full path
TRACE_SAVED_REGS_BYTES  equ 15*4                        ; d0-d7/a0-a6
TRACE_FRAME_SR          equ TRACE_SAVED_REGS_BYTES      ; stacked SR, then PC (long)

    macro KickWatchdog
        move.b	d0,$300001                  ; no register nor flag modified
    endm

	section	text

TRACE:
    KickWatchdog

    ; -----------------------------------------------------------------------
    ; RUN_UNTIL fast path. No register of the traced code may change here
    ; (only d0 is used, saved and restored). Flags may be clobbered freely:
    ; the traced code's CCR lives in the stacked SR, which is never modified
    ; on this path and restored by rte.
    ; -----------------------------------------------------------------------
    cmpi.w  #DEBUG_CMD_RUN_UNTIL,(DEBUG_MAILBOX_CMD).l
    bne.s   .fullPath
    tst.w   (DEBUG_MAILBOX_BREAK).l
    bne.s   .fullPath                       ; break requested by the Pico
    move.l  d0,-(sp)                        ; frame now at 4(sp)
    move.l  4+2(sp),d0                      ; stacked PC
    cmp.l   (DEBUG_MAILBOX_ARG0).l,d0
    bne.s   .fastResume                     ; PC != target: keep running
    moveq   #4+6,d0
    add.l   sp,d0                           ; SSP_INTERRUPTED (d0 saved + frame)
    cmp.l   (DEBUG_MAILBOX_ARG1).l,d0
    bhs.s   .fastStop                       ; SSP_INTERRUPTED >= min SP (unsigned): stop
.fastResume:
    move.l  (sp)+,d0
    rte                                     ; T still set: next instruction traced
.fastStop:
    move.l  (sp)+,d0

    ; -----------------------------------------------------------------------
    ; Full path: stop frame, then command loop.
    ; Interrupts are masked in the handler's own SR only (atomic frames, no
    ; BricoExt traffic from interrupt code while we talk to the Pico). The
    ; traced code's SR is the stacked one, restored by rte.
    ; Registers: a4 = $C1FF00 (EOT port / mailbox base), a5 = value window,
    ; d7 = ctr. All registers are restored by the final movem.
    ; -----------------------------------------------------------------------
.fullPath:
    ori.w   #$0700,sr
    movem.l d0-d7/a0-a6,-(sp)
    lea     (TRACE_PORT_EOT).l,a4
    lea     TRACE_A4_VALUE_BASE(a4),a5

    ; Stop frame: MAGIC, SR, PC hi, PC lo, CTR, then EOT
    move.w  TRACE_A4_CTR(a4),d7             ; d7 = ctr (current request counter)
    move.w  #DEBUG_PROTOCOL_MAGIC,d0
    bsr.s   .sendWord
    lea     TRACE_FRAME_SR(sp),a1
    moveq   #3-1,d6
    bsr.s   .sendWords                      ; SR, PC hi, PC lo
    move.w  d7,d0
    bsr.s   .sendWord
    bra.s   .endAnswer

    ; Layout: the subroutines sit between the stop frame and the command loop,
    ; so that every bsr.s / bra.s / bcc.s stays within its 8 bits range.

    ; Send value d0.w to the Pico. Uses d1/d2/a2, preserves d0. Needs a4/a5.
    ; .sendLong sends d0.l, high word first.
    ; Bus watcher constraint: the value address is computed BEFORE the port
    ; read. Bus accesses from the port read on:
    ;   move.w d16(a4),d2 : np [nr port] np   -> 1st access after the port
    ;   move.w (a2),d2    : [nr value] np     -> 2nd access: captured value
.sendLong:
    swap    d0
    bsr.s   .sendWord
    swap    d0
.sendWord:
    moveq   #0,d1
    move.w  d0,d1
    add.l   d1,d1                           ; value * 2 (16 bits ROM)
    lea     (a5,d1.l),a2                    ; address computed before the port read
    move.w  TRACE_A4_PORT_OUT(a4),d2        ; trigger port write
    move.w  (a2),d2                         ; value is read on the address bus
    rts

    ; Send d6.w+1 words read from (a1)+. Uses d0/d1/d2/a2, needs a4/a5.
.sendWords:
    KickWatchdog
    move.w  (a1)+,d0
    bsr.s   .sendWord
    dbra    d6,.sendWords
    rts

    ; WRITE_MEM: ARG0 = address, ARG1 bits 0-15 = value, ARG1 bit 31 = size
    ; (0 = byte, 1 = word). A word at an odd address is refused by the Pico
    ; (it would raise an address error here). Answer: EOT only (falls through).
.cmdWriteMem:
    movea.l TRACE_A4_ARG0(a4),a1
    move.l  TRACE_A4_ARG1(a4),d0            ; N = bit 31 = size
    bmi.s   .writeWord
    move.b  d0,(a1)
    bra.s   .endAnswer
.writeWord:
    move.w  d0,(a1)

    ; End of a stop frame or of a command answer, then wait for a command
.endAnswer:
    move.w  (a4),d2                         ; EOT ("nr np", no port read pending)

    ; Command loop: wait for CTR != ctr. CTR is a single 16 bits write of the
    ; Pico, done last: one read is enough.
.waitCmd:
    KickWatchdog
    cmp.w   TRACE_A4_CTR(a4),d7
    beq.s   .waitCmd
    move.w  TRACE_A4_CTR(a4),d7

    move.w  TRACE_A4_CMD(a4),d0
    subq.w  #DEBUG_CMD_GET_REGS,d0
    beq.s   .cmdGetRegs
    subq.w  #DEBUG_CMD_READ_MEM-DEBUG_CMD_GET_REGS,d0
    beq.s   .cmdReadMem
    subq.w  #DEBUG_CMD_WRITE_MEM-DEBUG_CMD_READ_MEM,d0
    beq.s   .cmdWriteMem
    addq.w  #DEBUG_CMD_WRITE_MEM-DEBUG_CMD_CONTINUE,d0
    bne.s   .resume                         ; STEP, RUN_UNTIL, unknown: T unchanged
    andi.w  #$7fff,TRACE_FRAME_SR(sp)       ; CONTINUE: clear T in the stacked SR
.resume:
    movem.l (sp)+,d0-d7/a0-a6
    rte

    ; GET_REGS: d0-d7, a0-a6, SSP_INTERRUPTED, USP (2 words each), SR, PC hi, PC lo
.cmdGetRegs:
    movea.l sp,a1
    moveq   #15*2-1,d6
    bsr.s   .sendWords                      ; d0-d7/a0-a6, a1 = frame address
    moveq   #6,d0
    add.l   a1,d0                           ; SSP before the exception
    bsr.s   .sendLong
    move.l  usp,a0
    move.l  a0,d0
    bsr.s   .sendLong
    moveq   #3-1,d6                         ; SR, PC hi, PC lo from (a1)
.sendWordsAndEnd:
    bsr.s   .sendWords
    bra.s   .endAnswer

    ; READ_MEM: ARG0 = even address, ARG1 = word count (1..256).
    ; Invalid request (count 0 or > 256, odd address): no memory access at all,
    ; only EOT is sent, so the Pico sees a short answer instead of garbage.
.cmdReadMem:
    move.l  TRACE_A4_ARG1(a4),d6
    subq.l  #1,d6                           ; count - 1, 0..255 when valid
    move.l  d6,d1
    lsr.l   #8,d1                           ; unsigned: catches 0 and > 256
    bne.s   .endAnswer
    move.l  TRACE_A4_ARG0(a4),d0
    movea.l d0,a1
    lsr.b   #1,d0
    bcs.s   .endAnswer                      ; odd address: would raise an address error
    bra.s   .sendWordsAndEnd

    if (*-TRACE)>BIOS_PATCH_TRACE_ROUTINE_MAX_BYTES
        fail "TRACE handler bigger than BIOS_PATCH_TRACE_ROUTINE_MAX_BYTES"
    endif
