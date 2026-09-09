; https://wiki.neogeodev.org/index.php?title=68k_memory_map
; Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
; C:\Users\Aurelien\AppData\Local\Microsoft\WindowsApps>winget install GnuWin32.Make
; Base address: 0xc00000

; External screen
; PIO trace swap KO => potentially fixed
; BRAM backup and switch
; Pas d'erreur sur commande inconnue?
; Commande RESET RP2040>68000

	include "inc/define.inc"
	include "inc/trace.inc"

	section vectors,data

	dc.l	RAM_RESERVED_SYS_ROM
	dc.l	START
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	TRACE
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0
	dc.l	0 
	dc.l	0

	; Could be used by extension functions
	global BRICO_COMMAND_IN
	global BRICO_COMMAND_PARAM_1
	global BRICO_COMMAND_PARAM_2
	global BRICO_COMMAND_PARAM_3
	; Used to return after the execution of a extension function
	global  WAIT_FOR_COMMAND

	section	text,code

	; Magic word - 8 bytes
	dc.b "BricoNeo"
	; Version - 4 bytes
	BRICONEO_VERSION 1,33
	; Special modes
	dc.w BRICO_SPECIAL_FLAG_ENABLE_EXTENSIONS + BRICO_SPECIAL_FLAG_68K_SENDS_COMMANDS

JUMP_TO_COMMAND:
	dc.w $4ef9 ; jmp opcode, in order to jump directly to the following address
BRICO_COMMAND_IN:
	dc.l $0000 ; Address of the next extension to be launched - 4 bytes set by the BricoNeo card at runtime
BRICO_COMMAND_PARAM_1:
	dc.l $0000 ; Address the extension parameters - 3 times 4 bytes set by the BricoNeo card at runtime
BRICO_COMMAND_PARAM_2:
	dc.l $0000
BRICO_COMMAND_PARAM_3:
	dc.l $0000

EXTENSIONS_TABLE:
	; Available extensions list. Ends with address $ffffffff
	DECLARE_EXTENSION EXT_ECHO, 			BRICO_EXT_OUTPUT_TYPE_WORD,		"Echo",				"Echo test. Place value to be returned in P1 (no WRAM used)"
	DECLARE_EXTENSION EXT_READ, 			BRICO_EXT_OUTPUT_TYPE_WORD,		"Read",				"Read word as even address P1 (no WRAM used)"
	DECLARE_EXTENSION EXT_WRITE, 			BRICO_EXT_OUTPUT_TYPE_VOID,		"Write",			"Write word P1 at 68000 even address P2 (no WRAM used)"
	DECLARE_EXTENSION EXT_MEMDUMP, 			BRICO_EXT_OUTPUT_TYPE_DUMP,		"Dump",				"Memory dump. Place start address in P1 and word count in P2 (no WRAM used)"
	DECLARE_EXTENSION EXT_TEST_INPUTS,		BRICO_EXT_OUTPUT_TYPE_STRING,	"TestInp",			"Inputs tests, NEO-F0 / NEO-C1 (no WRAM used)"
	DECLARE_EXTENSION EXT_TEST_WRAM,		BRICO_EXT_OUTPUT_TYPE_STRING,	"TestWRAM",			"Work RAM test. 0000, 5555, FFFF, AAAA and increment tests. See mem dump $100000 (no WRAM used)"
	DECLARE_EXTENSION EXT_TEST_BRAM,		BRICO_EXT_OUTPUT_TYPE_STRING,	"TestBRAM",			"Backup RAM test. 0000, 5555, FFFF, AAAA and increment tests. See mem dump $D00000 (no WRAM used)"
	DECLARE_EXTENSION EXT_TEST_PRAM,		BRICO_EXT_OUTPUT_TYPE_STRING,	"TestPRAM",			"Palette RAM test. 0000, 5555, FFFF, AAAA and increment tests. See mem dump $400000 (no WRAM used)"
	DECLARE_EXTENSION EXT_TEST_VRAM_LOWER,		BRICO_EXT_OUTPUT_TYPE_STRING,	"TestVRAML",		"Video RAM test (lower / slow RAM). (no WRAM used)"
	DECLARE_EXTENSION EXT_TEST_VRAM_UPPER,		BRICO_EXT_OUTPUT_TYPE_STRING,	"TestVRAMU",		"Video RAM test (upper / fast RAM). (no WRAM used)"
	DECLARE_EXTENSION EXT_TEST_MARCH_VRAM_LOWER,	BRICO_EXT_OUTPUT_TYPE_STRING,	"MarchVRAML",		"March-C VRAM test (lower / slow RAM). (no WRAM used)"
	DECLARE_EXTENSION EXT_TEST_MARCH_VRAM_UPPER,	BRICO_EXT_OUTPUT_TYPE_STRING,	"MarchVRAMU",		"March-C VRAM test (upper / fast RAM). (no WRAM used)"
	DECLARE_EXTENSION EXT_TEST_LSPC,		BRICO_EXT_OUTPUT_TYPE_STRING,	"TestLSPC",			"LSPC2-A2 chip test: VRAMMOD write/readback, VRAMADD+VRAMRW round-trip, VRAM auto-inc. (no WRAM used)"
	dc.l $ffffffff ; No more extensions

START:
	move #$2700,sr					; Supervisor mode + all interrupts disabled
	WatchDog 						; kick watchdog
	move.w	#7,(REG_IRQACK).l 		; ack all IRQs
	move.w  #$4000,(REG_LSPCMODE).l ; stop animations
	lea RAM_RESERVED_SYS_ROM,sp		; Set stack pointer to BIOS_WORKRAM
	DisableInterrupts 				; Interrupts are disabled by default

WAIT_FOR_COMMAND:
	; Wait for the command to be 0 again
	DisableInterrupts ; Interrupts are disabled in extensions by default as the work RAM might not work
.loop_wait_for_no_command:
	WatchDog
	move.l (BRICO_COMMAND_IN).l,d0
	cmp.l #0,d0
	bne .loop_wait_for_no_command

.loop_wait_for_command:
	WatchDog
	; Read command number from the BricoNeo port
	move.l (BRICO_COMMAND_IN).l,d0
	cmp.l #0,d0
	beq .loop_wait_for_command

	; From there, we should have a command address in BRICO_COMMAND_IN.
	; Jump to the requested command
	; There will be no RTS as we are not sure the work RAM is working

	jmp JUMP_TO_COMMAND
