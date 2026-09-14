	include "inc/define.inc"
    include "inc/trace.inc"

	global EXT_TEST_AUDIO

	section text

EXT_TEST_AUDIO:
	
    PrintLn "Neo-Geo unibios like audio test"
    WriteEOT
    

    ;Breakpoint

	; Match the UniBIOS pattern: write directly to the BRDFIX address to enable SM1 audio
	move.b #$00,$3A000B.l

    ;PrintLn "Z80 handshake..."
    ;WriteEOT
    
    ;Send first command to Z80, and  for ACK $01
    bsr.w   SM1_Send01AndWaitAck

    tst.b   D0
    bne.s   EXT_TEST_AUDIO_Z80_ACK_OK
    bsr.w   EXT_TEST_AUDIO_Z80_TIMEOUT

EXT_TEST_AUDIO_Z80_ACK_OK:
    PrintLn "Z80 ACK $01 received"
    ;cette trace ne s'affiche pas !
    WriteEOT
    




    ; ------------------------------------------------------------
    ; step 2. Reproduction de UNIBIOS BIOSF_Z80_InitSeq :
    ;    $01 -> long delay -> $03 -> long delay -> $07 -> short delay
    ; ------------------------------------------------------------

    
    move.b  #1,(REG_SOUND).l
    bsr.w   SM1_CommandDelay

    PrintLn "Sending 0x3 and 0x07 to reset and prepare Z80 (unibios retro-engineering)"
    
    move.b  #3,(REG_SOUND).l
    bsr.w   SM1_CommandDelay

    move.b  #$07,(REG_SOUND).l
    bsr.w   SM1_ShortWait 



    PrintLn "Init Z80 OK"
    
	; Step 3: send the left / right / center channel commands.

	PrintLn " BEEP Left   : "
	moveq.l #$5C,d0
	move.b d0,(REG_SOUND).l    
	bsr.w   Wait_1Second


	PrintLn "BEEP Right  : "
	moveq.l #$5D,d0
	move.b d0,(REG_SOUND).l
	bsr.w   Wait_1Second
    
	PrintLn "BEEP Center : "
	moveq.l #$5E,d0
	move.b d0,(REG_SOUND).l
	bsr.w   Wait_1Second


    ; Step 4: send the stop command to the Z80.
    move.b  #3,(REG_SOUND).l
    bsr.w   SM1_CommandDelay
    PrintLn "Test stopped "
	
	
    WriteEOT
    jmp WAIT_FOR_COMMAND

; ------------------------------------------------------------------------
; SM1_Send01AndWaitAck
;
; Sortie :
;   D0.b = 1 : ACK $01 reçu
;   D0.b = 0 : timeout
;
; Détruit :
;   D0, D1, A0
; ------------------------------------------------------------------------

SM1_Send01AndWaitAck:
    lea.l   (REG_SOUND).l,A0

    ; Reproduit l'attente courte BIOS, avant l'envoi.
    bsr.w   SM1_ShortWait

    ; Envoie la commande PREPARE / ACK request.
    move.b  #1,(A0)

    ; Laisse le Z80 traiter le port avant le polling.
    bsr.w   SM1_ShortWait

    move.w  #$0FFF,D1

.poll:
    cmpi.b  #1,(A0)
    beq.s   .ack

    dbra    D1,.poll

.timeout:
    moveq   #0,D0
    rts

.ack:
    moveq   #1,D0
    rts


; ------------------------------------------------------------
; Attente courte, équivalent structurel de BIOSF_Menu_ShortWait.
; ------------------------------------------------------------

SM1_ShortWait:
    moveq   #$0F,D1

.outer:
    move.w  #$0400,D0

.inner:
    dbra    D0,.inner
    move.b  D0,(REG_SYSTYPE).l
    dbra    D1,.outer
    rts


; ------------------------------------------------------------
; Équivalent structurel de BIOSF_Menu_Scroll avec D1=$40.
; Le BIOS effectue 65 × 1025 boucles environ.
; ------------------------------------------------------------
SM1_CommandDelay:
    move.w  #$0040,D1

.outer:
    move.w  #$0400,D0

.inner:
    dbra    D0,.inner

    move.b  D0,$300001.l       ; même accès strobe que le BIOS
    dbra    D1,.outer
    rts


; Environ 1 seconde :
; SM1_CommandDelay ~= 55 ms
; 18 passages ~= 990 ms à 1 s

Wait_1Second:
    moveq   #17,D2                ; DBRA = 18 passages

WAIT_1SECOND_LOOP:
    bsr.w   SM1_CommandDelay
    dbra    D2,WAIT_1SECOND_LOOP
    rts

EXT_TEST_AUDIO_Z80_TIMEOUT:
    PrintLn "ERROR: no Z80 ACK $01"
    WriteEOT
    jmp     WAIT_FOR_COMMAND