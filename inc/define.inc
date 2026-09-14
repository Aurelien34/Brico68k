SYSTEM_ROM	equ $C00000
SYSTEM_ROM_MIRROR	equ $C20000
RAM_RESERVED_SYS_ROM	equ $10F300

RAM_START	equ $100000
RAM_USER_END	equ $10F300;
RAM_END	equ $110000

BACKUP_RAM_START equ $d00000
BACKUP_RAM_END equ $d10000

PALETTE_RAM_START equ $400000
PALETTE_RAM_END equ $402000
PALETTE_BACKDROP equ $401FFE

REG_PALBANK0 equ $3A001F
REG_PALBANK1 equ $3A000F
REG_BRDFIX equ $3A000B

ROM_NAME_SECTION_ORG	equ $100
INITIAL_PC_ORG          equ $402

REG_WATCHDOG	equ $300001
REG_LSPCMODE	equ $3C0006
REG_IRQACK		equ $3C000C

BRICO_PORT_OUT	equ SYSTEM_ROM + $1FF02
BRICO_PORT_EOT	equ BRICO_PORT_OUT - 2

BRICO_EXT_OUTPUT_TYPE_VOID equ $0
BRICO_EXT_OUTPUT_TYPE_WORD equ $1
BRICO_EXT_OUTPUT_TYPE_STRING equ $2
BRICO_EXT_OUTPUT_TYPE_DUMP equ $3

; BricoNeo special flags
BRICO_SPECIAL_FLAG_ENABLE_EXTENSIONS equ $0001		; Command extensions are active
BRICO_SPECIAL_FLAG_68K_SENDS_COMMANDS equ $0002		; The 68k can send commands using the output port

; VRAM memory mapped registers
REG_VRAMADD	equ $3C0000
REG_VRAMRW	equ $3C0002
REG_VRAMMOD	equ $3C0004

; Inputs memory mapped registers
REG_P1CNT_REG_DIPSW equ $300000
REG_SYSTYPE equ $300080
REG_SOUND equ $320000
REG_STATUS_A equ $320001
REG_P2CNT equ $340000
REG_STATUS_B equ $380000

	macro BRICONEO_VERSION
		dc.w \1	; Major
		dc.w \2	; Minor
	endm

	macro DECLARE_EXTENSION
		dc.l \1	; Extension address
		dc.w \2	; Return type
		dc.b \3	; Command name (0 terminated)
		dc.b 0
		align 1	; Parity
		dc.b \4	; Description (0 terminated)
		dc.b 0
		align 1	; Parity
	endm

	macro WatchDog
		move.b	d0,(REG_WATCHDOG).l
	endm

	macro WriteEOT
		move.w (BRICO_PORT_EOT).l,d0
	endm

    macro JsrA6
		lea (.\@), a6
		jmp \1_JsrA6
.\@:
	endm

	macro RtsA6
		jmp (a6)
	endm

	macro PortWriteD0
		JsrA6 port_write_d0
	endm

	macro InlinePortWriteD0
		and.l #$0000ffff,d0				; cleanup high word
		lsl.l d0						; times 2 (16 bits ROM)
		add.l #SYSTEM_ROM_MIRROR,d0		; locate in ROM mirror range to trigger the /OE line (under 0x0100, OE will not be triggered on non mirror location)
		exg d0,a0						; Switch value to address register, as data is read on the address bus!
		move.w (BRICO_PORT_OUT).l,d0	; trigger port write
		move.w (a0),d0					; write value
	endm

	macro Print							; String constant passed as a parameter
		PrintHandleCRLF \1,0
	endm

	macro PrintLn						; String constant passed as a parameter
		PrintHandleCRLF \1,1
	endm

	macro PrintHandleCRLF				; P1 is string constant, P2 is either 0 or 1 depending on LF ending
		move.l #.\@StringAddress,a1
		jmp .\@PrintStart
	.\@StringAddress:
		dc.b \1
		ifc "\2","1"
		dc.b 10
		endc
		dc.b 0
	align 1
	.\@PrintStart:
		PrintA1
	.\@PrintEnd:
	endm

	macro PrintA1
		JsrA6 print_a1
	endm

	macro InlinePrintA1			; string address in a1
	.\@lbl0000PrintStart:
		cmp.b #0,(a1)
		beq .\@lbl0000PrintEnd
		move.w #0,d0
		move.b (a1)+,d0
		InlinePortWriteD0
		jmp .\@lbl0000PrintStart
	.\@lbl0000PrintEnd:
	endm

	macro EnableInterrupts
		move #$2000,sr				; Supervisor mode + all interrupts enabled
	endm

	macro DisableInterrupts
		move #$2700,sr				; Supervisor mode + all interrupts disabled
	endm

	macro Nop2
		nop
		nop
	endm

	macro Nop4
		Nop2
		Nop2
	endm

	macro Nop6
		Nop2
		Nop4
	endm

	macro Nop8
		Nop4
		Nop4
	endm

	macro Nop12
		Nop8
		Nop4
	endm

	macro Nop16
		Nop8
		Nop8
	endm