# HARDWARE_NOTES.md — BricoNeo (Brico68kMAC)

Notes techniques extraites du dépôt `Brico68kMAC-main` en vue de la
conception d'un **analyseur de port cartouche Neo Geo** (carte interposée
avec CPLD, entre le connecteur cartouche de la console et une cartouche de
jeu), destiné aux tests et à la réparation de consoles Neo Geo.

---

## 1. Rôle du projet

Ce dépôt contient le **firmware 68000 embarqué de la carte BricoNeo**
(`Brico68k.s` → `rom/Brico68k.bin` / `rom/ROM.BIO`), une carte de diagnostic
qui se place dans le connecteur cartouche d'une Neo Geo (AES/MVS) à la place
du jeu. Le firmware s'exécute directement depuis le mapping `SYSTEM_ROM`
($C00000) de la cartouche, attend des **commandes envoyées par un hôte
externe** (a priori un microcontrôleur type RP2040 sur la carte BricoNeo,
communiquant via un port mémoire mappé dans le mirroir de la ROM), exécute
des **extensions de test** (RAM, VRAM, LSPC, inputs, bus P, echo/lecture/
écriture mémoire arbitraire) et renvoie les résultats en texte/binaire via
ce même port. Ce n'est pas un jeu : c'est un outil de bring-up/diagnostic
matériel de la console, avec un protocole hôte↔68000 simple à base de
commandes et paramètres en RAM ([Brico68k.s](Brico68k.s), [inc/define.inc](inc/define.inc)).

Le projet est bâti avec `vasmm68k_mot` + `vlink` (`-m68000`, format binaire
brut `-brawbin1`), voir [Makefile](Makefile), [Makefile.linux](Makefile.linux),
[MakefilePC](MakefilePC) et le script de link [Brico68k.ld](Brico68k.ld).

---

## 2. Bus cartouche et 68000

### 2.1 Mapping mémoire utilisé par le firmware

Toutes les constantes viennent de [inc/define.inc](inc/define.inc) (référence
citée en tête de [Brico68k.s:1](Brico68k.s#L1) : wiki.neogeodev.org 68k memory map).

| Zone | Adresse | Taille / fin | Rôle |
|---|---|---|---|
| ROM cartouche (P ROM), zone système | `$C00000` (`SYSTEM_ROM`) | — | Code du firmware BricoNeo, vecteurs 68000 en tête |
| Miroir ROM système | `$C20000` (`SYSTEM_ROM_MIRROR`) | — | Utilisé comme **déclencheur du signal /OE** pour l'écriture de sortie hôte (voir 2.4) |
| RAM travail (WRAM) | `$100000` (`RAM_START`) | `$110000` (`RAM_END`) | RAM système 68000 ; `RAM_RESERVED_SYS_ROM=$10F300` réservée BIOS/pile |
| Zone WRAM testable | `$100000` | `$10F300` (`RAM_USER_END`) | Bornes utilisées par le test WRAM |
| Backup RAM (BRAM) | `$D00000` | `$D10000` | RAM de sauvegarde, protégée en écriture (voir 2.5) |
| Palette RAM | `$400000` | `$402000` | RAM palette ; `PALETTE_BACKDROP=$401FFE` |
| Registre banque palette 0 | `$3A001F` | — | `REG_PALBANK0` |
| Registre banque palette 1 | `$3A000F` | — | `REG_PALBANK1` |
| Watchdog | `$300001` | — | `REG_WATCHDOG` (écriture périodique obligatoire) |
| LSPC mode | `$3C0006` | — | `REG_LSPCMODE` |
| Acquittement IRQ | `$3C000C` | — | `REG_IRQACK` |
| VRAM adresse | `$3C0000` | — | `REG_VRAMADD` |
| VRAM data (R/W) | `$3C0002` | — | `REG_VRAMRW` |
| VRAM modulo (auto-incrément) | `$3C0004` | — | `REG_VRAMMOD` |
| Timer high | `$3C0008` | — | `REG_TIMERHIGH` (écriture seule, voir 3) |
| Timer low | `$3C000A` | — | `REG_TIMERLOW` (écriture seule) |
| Timer stop | `$3C000E` | — | `REG_TIMERSTOP` |
| Inputs P1 / DIP switches | `$300000` | — | `REG_P1CNT_REG_DIPSW` (word: DIP en high byte, P1 en low byte — voir usage dans [ExtTestInputs.s](ExtTestInputs.s)) |
| Type système | `$300080` | — | `REG_SYSTYPE` |
| Registre son | `$320000` | — | `REG_SOUND` |
| Status A (coin/service) | `$320001` | — | `REG_STATUS_A` |
| Inputs P2 | `$340000` | — | `REG_P2CNT` |
| Status B (start/select) | `$380000` | — | `REG_STATUS_B` |
| BRAM unprotect | `$3A001D` | — | écrit `$FF` pour déverrouiller la BRAM ([ExtTestBWPRAM.s:27](ExtTestBWPRAM.s#L27)) |
| BRAM protect | `$3A000D` | — | écrit `$FF` pour reverrouiller la BRAM ([ExtTestBWPRAM.s:332](ExtTestBWPRAM.s#L332)) |

Adresses spécifiques au protocole BricoNeo (dans le miroir de ROM système) :

| Nom | Adresse | Rôle |
|---|---|---|
| `BRICO_PORT_OUT` | `SYSTEM_ROM + $1FF02` = `$C1FF02` | Port de sortie 68000 → hôte (déclenché par lecture, voir 2.4) |
| `BRICO_PORT_EOT` | `BRICO_PORT_OUT - 2` = `$C1FF00` | Marqueur "fin de transmission" écrit après chaque extension |

Cible mémoire des vecteurs/en-tête ROM (voir [Brico68k.ld](Brico68k.ld) et
[Brico68k.s](Brico68k.s)) :
- `VECTORS` : org `$C00000`, longueur `$80` (table de vecteurs 68000 standard,
  avec vecteur reset SP=`RAM_RESERVED_SYS_ROM`, PC=`START`, tous les autres
  vecteurs à 0 sauf réservés).
- `ROM` (code) : org `$C00080`, longueur `$7F80`.
- `ROM_NAME_SECTION_ORG` = `$100` et `INITIAL_PC_ORG` = `$402` : offsets
  documentés mais non utilisés directement dans le code visible (probablement
  convention BIOS Neo Geo pour nom de ROM / PC initial).

### 2.2 Registres mémoire mappés côté cartouche/BricoNeo

- Un **en-tête magique** est placé en tout début de section code (juste après
  les vecteurs) : la chaîne ASCII `"BricoNeo"` (8 octets), suivie d'une
  version (`BRICONEO_VERSION` = 2 mots : major, minor — actuellement `1.32`),
  puis un mot de **flags spéciaux** (`BRICO_SPECIAL_FLAG_ENABLE_EXTENSIONS`,
  `BRICO_SPECIAL_FLAG_68K_SENDS_COMMANDS`). Voir [Brico68k.s:59-64](Brico68k.s#L59-L64).
  → Ceci ressemble à un identifiant lisible par l'hôte externe (le
  contrôleur de la carte BricoNeo) en lisant la ROM depuis le bus, avant même
  d'exécuter du code — utile pour qu'une carte analyseur détecte la présence
  et la version du firmware BricoNeo sans exécution.
- Juste après, une instruction `jmp` codée en dur (`$4ef9`) suivie de 4
  **emplacements mémoire dans le code ROM** : `BRICO_COMMAND_IN`,
  `BRICO_COMMAND_PARAM_1/2/3` ([Brico68k.s:66-75](Brico68k.s#L66-L75)).
  Ces emplacements sont documentés comme **écrits par la carte BricoNeo à
  l'exécution** — donc bien que physiquement en zone ROM cartouche, ils sont
  en pratique **RAM/registres pilotés par la carte interposée elle-même**
  (probablement via le CPLD qui intercepte les cycles bus et substitue une
  RAM réelle à ces offsets, ou remappe transparemment ces adresses). C'est
  le mécanisme central à étudier pour la nouvelle carte analyseur : la
  cartouche BricoNeo n'est pas une ROM passive, elle **injecte des données
  dans le flux d'instructions exécuté par le 68000 de la console**.
- Une **table d'extensions** (`EXTENSIONS_TABLE`) est déclarée juste après :
  liste d'entrées `DECLARE_EXTENSION` avec adresse, type de retour, nom de
  commande, description ; terminée par `$FFFFFFFF` ([Brico68k.s:77-93](Brico68k.s#L77-L93)).
  Cette table est probablement lue par l'hôte externe pour construire
  dynamiquement son menu de commandes/tests disponibles.

### 2.3 Boot / séquence d'initialisation

Voir [Brico68k.s:95-123](Brico68k.s#L95-L123) (`START` puis boucle
`WAIT_FOR_COMMAND`) :

1. `move #$2700,sr` — mode superviseur, toutes interruptions masquées.
2. Kick watchdog immédiat (`move.b d0,(REG_WATCHDOG).l`).
3. `move.w #7,(REG_IRQACK).l` — acquitte toutes les IRQ en attente.
4. `move.w #$4000,(REG_LSPCMODE).l` — stoppe les animations du LSPC (évite
   que le contrôleur vidéo perturbe l'accès VRAM / le scan).
5. `lea RAM_RESERVED_SYS_ROM,sp` — initialise le stack pointer dans la zone
   RAM BIOS réservée (`$10F300`), en dehors de la zone testée par le firmware.
6. Boucle `WAIT_FOR_COMMAND` :
   - Attend d'abord que `BRICO_COMMAND_IN` (mot 32 bits en RAM ROM-mirroir)
     repasse à 0 (poignée de main : évite de relancer une commande déjà
     traitée).
   - Puis attend qu'il redevienne non nul : c'est l'**adresse de l'extension
     à exécuter**, écrite par la carte hôte.
   - Saute directement dessus via `JUMP_TO_COMMAND` (`jmp` auto-modifiant
     dont l'opérande `BRICO_COMMAND_IN` est réécrit par l'hôte) — **sans
     `jsr`/pile**, car la RAM travail n'est pas garantie fonctionnelle à ce
     stade (le firmware sert justement à tester la RAM).
   - Le `WatchDog` est tapé à chaque itération de boucle (busy-wait), donc
     le timing de la boucle d'attente = fréquence à laquelle le watchdog
     matériel doit être servi.

### 2.4 Protocole de sortie 68000 → hôte (`PortWrite`)

Mécanisme clé pour comprendre comment le 68000 "parle" à la carte
interposée via le bus, sans registre I/O dédié classique — voir
[inc/define.inc:88-99](inc/define.inc#L88-L99) (macro `InlinePortWriteD0`) :

```
and.l #$0000ffff,d0            ; nettoie le mot haut
lsl.l d0                       ; x2 (ROM 16 bits, adressage par mot)
add.l #SYSTEM_ROM_MIRROR,d0    ; place l'adresse dans le miroir ROM ($C20000+)
exg d0,a0                      ; la valeur à transmettre devient une ADRESSE
move.w (BRICO_PORT_OUT).l,d0   ; déclenche l'écriture "port" (lecture à $C1FF02)
move.w (a0),d0                 ; lit à l'adresse encodée -> déclenche /OE avec la valeur en clair sur le bus d'adresse
```

**Interprétation matérielle** : comme une ROM ne peut pas être écrite par le
68000, BricoNeo encode la valeur à transmettre **dans les lignes d'adresse
elles-mêmes** (`move.w (a0),d0` où `a0` = valeur*2 + offset miroir), puis
lit à cette adresse. Le CPLD/la logique de la carte BricoNeo surveille
probablement `/OE` + la plage d'adresse du miroir ROM système pour capturer
la valeur transmise directement depuis le bus d'adresse (pas depuis le bus
de données). Le commentaire source précise explicitement :
> "locate in ROM mirror range to trigger the /OE line (under 0x0100, OE
> will not be triggered on non mirror location)"

Ceci implique un **quirk de décodage d'adresse documenté** : en dessous de
l'offset `$0100` dans le mirroir, `/OE` n'est pas généré côté cartouche/
carte mère — donc toute la logique d'interception doit cibler `$C20000 +
offset*2` avec `offset >= $0100` pour être fiable. C'est un point très
pertinent pour la nouvelle carte interposée : le décodeur (CPLD) doit
répliquer ou comprendre cette même fenêtre d'adresses pour intercepter le
"port" de sortie.

- `BRICO_PORT_OUT` (`$C1FF02`) : lu (pas écrit) pour déclencher un cycle
  "port write" — la vraie valeur transmise passe par l'adresse lue juste
  après (`move.w (a0),d0`).
- `BRICO_PORT_EOT` (`$C1FF00`, macro `WriteEOT`) : lu à la fin de chaque
  extension pour signaler la fin de transmission à l'hôte
  ([inc/define.inc:74-76](inc/define.inc#L74-L76)).
- Ce mécanisme signifie que **le 68000 ne fait jamais d'écriture mémoire
  réelle vers la carte** pour transmettre des données : tout passe par des
  **lectures à des adresses codées**, ce qui est cohérent avec le fait que
  le bus cartouche Neo Geo (P-ROM socket) ne fournit normalement que /OE, et
  pas de ligne d'écriture générique exploitable simplement pour une "fausse
  ROM".

### 2.5 Signaux de contrôle identifiés (déduits du code)

| Signal / mécanisme | Où il apparaît | Rôle déduit |
|---|---|---|
| `/OE` (Output Enable) | [inc/define.inc:95](inc/define.inc#L95) commentaire explicite | Déclenché par lecture dans le miroir ROM ≥ offset `$0100`, utilisé pour capturer les octets envoyés par le 68000 vers l'hôte |
| Watchdog (`REG_WATCHDOG` = `$300001`) | macro `WatchDog`, appelée dans **toutes** les boucles chaudes | Un chien de garde matériel doit être servi régulièrement, y compris pendant les tests mémoire/VRAM longs — la carte interposée doit soit le laisser passer sans interférer, soit le simuler si elle isole le 68000 |
| `/IRQ` / `/VEC` | Table de vecteurs quasi vide (que des `0`), `REG_IRQACK` ($3C000C) acquitte "toutes les IRQ" au boot | Le firmware désactive volontairement les interruptions (`DisableInterrupts` = `$2700`) presque partout ; seules VBLANK/HBLANK sont réservées dans la table (mais pointent sur 0) |
| BRAM write-protect | `$3A001D` (unprotect) / `$3A000D` (protect) | Ligne de protection en écriture de la BRAM pilotée par bit mappé mémoire, pas par un vrai `/RESET` cartouche |
| Reset 68000 côté hôte | Commentaire TODO dans [Brico68k.s:10](Brico68k.s#L10) : *"Commande RESET RP2040>68000"* | Fonctionnalité **non implémentée** au moment de l'analyse — l'hôte (probablement un RP2040) est censé pouvoir forcer un reset du 68000, mécanisme à concevoir/vérifier côté carte interposée |

### 2.6 Timing bus

Aucune valeur de timing explicite (cycles, wait states) n'est documentée en
commentaire. Le seul indice indirect est l'usage systématique de macros
`Nop2`/`Nop4`/`Nop6`/.../`Nop16` ([inc/define.inc:147-175](inc/define.inc#L147-L175))
**avant/après quasiment tous les accès à `REG_VRAMADD` / `REG_VRAMRW` /
`REG_VRAMMOD`**, par exemple dans [ExtTestLSPC.s:71-77](ExtTestLSPC.s#L71-L77)
ou [ExtTestVRAM.s:36-43](ExtTestVRAM.s#L36-L43). Ceci confirme empiriquement
que le **LSPC2-A2 a un temps de traitement interne non négligeable entre
deux accès registre**, et que le firmware insère des délais fixes (nops)
plutôt que du polling de statut — mais aucune valeur en ns/cycles n'est
donnée nulle part dans ce dépôt (à mesurer au CPLD/analyseur logique, voir
§5).

---

## 3. Comportements matériels particuliers

### 3.1 Quirks documentés en commentaire

- **Fenêtre `/OE` du miroir ROM** : `/OE` non déclenché sous offset `$0100`
  du miroir `$C20000` → nécessite `SYSTEM_ROM_MIRROR + offset*2` avec offset
  `≥ $0100` ([inc/define.inc:95](inc/define.inc#L95)). Comportement clé du
  décodage d'adresse de la carte BricoNeo (probablement dans son CPLD), à
  reproduire/vérifier pour toute nouvelle carte interposée qui voudrait
  utiliser le même mécanisme, ou à contourner si on veut un protocole
  différent.
- **`REG_VRAMADD` non relisible fiablement** : le balayage interne du LSPC2
  écrase en continu le compteur d'adresse entre deux accès 68000 — donc
  impossible de simplement écrire puis relire `REG_VRAMADD` pour vérifier
  une adresse. Le firmware teste indirectement via un round-trip
  écriture/lecture sur `REG_VRAMRW` à adresse fixe
  ([ExtTestLSPC.s:11-14](ExtTestLSPC.s#L11-L14), [ExtTestLSPC.s:59-89](ExtTestLSPC.s#L59-L89)).
- **`REG_TIMERHIGH`/`REG_TIMERLOW` écriture seule** : confirmés non lisibles
  ([ExtTestLSPC.s:12](ExtTestLSPC.s#L12)), donc non testés par le firmware.
- **`REG_LSPCMODE` partiellement lisible** : les bits hauts reflètent le
  compteur de scanline en temps réel (donc changent en continu) — non
  testable en simple écriture/lecture ([ExtTestLSPC.s:11](ExtTestLSPC.s#L11)).
- **VRAM haute ($8600+)** : au-delà de cette adresse, le contenu est piloté
  par le circuit vidéo (LSPC) lui-même et n'est donc pas fiable pour un test
  RAM générique — le test VRAM "upper" s'arrête à `$8000 + $5FF`
  ([ExtTestVRAM.s:18](ExtTestVRAM.s#L18)).
- **Position de la WRAM sur AES vs MVS** : le test incrémental de RAM
  détecte spécifiquement si l'octet de poids faible ou de poids fort est en
  faute, et indique dans ce cas que *"On the AES board, the WRAM is located
  in the lower/upper position"* — indique une différence de brochage/
  position physique de la puce WRAM connue entre cartes AES et MVS
  ([ExtTestBWPRAM.s:280-316](ExtTestBWPRAM.s#L280-L316)).
- **BRAM nécessite déverrouillage explicite** avant test, puis reverrouillage
  après ([ExtTestBWPRAM.s:27](ExtTestBWPRAM.s#L27), [ExtTestBWPRAM.s:332](ExtTestBWPRAM.s#L332))
  via bits mappés mémoire `$3A001D`/`$3A000D` — mécanisme de protection en
  écriture piloté logiciellement, pas un simple strap matériel.

### 3.2 Séquences boot / détection cartouche

Voir §2.3. Points notables pour une carte analyseur :
- Le firmware BricoNeo **s'auto-identifie** en clair dans les 12 premiers
  octets de code (`"BricoNeo"` + version + flags), lisible dès le reset par
  simple lecture bus, sans exécution — un point d'ancrage simple pour
  qu'une carte interposée détecte "c'est bien BricoNeo qui tourne".
- Le firmware ne fait **aucune vérification de checksum de la ROM
  elle-même** ni de la cartouche de jeu insérée par ailleurs (le firmware
  BricoNeo *remplace* la cartouche de jeu dans le port, il n'y a donc pas
  de C-ROM/checksum de jeu à valider dans ce contexte, sauf pour le test
  `TestPBus` qui suppose la présence d'une vraie cartouche additionnelle,
  voir §3.3).
- Aucune séquence de détection "cartouche présente / absente" n'est
  implémentée dans ce firmware — la détection de présence semble être un
  rôle attendu de la carte interposée elle-même (CPLD), pas du 68000.

### 3.3 Protections / anti-piratage

Rien dans ce dépôt n'implémente de mécanisme anti-piratage Neo Geo standard
(pas de PRO-CT0/CMC/NEO-SMA/PCM2 emulation, pas de checksum de C-ROM). Seule
mention pertinente :
- `EXT_TEST_PBUS` (**test visuel du bus P / adressage tuiles C-ROM**)
  nécessite explicitement qu'une **vraie cartouche de jeu** soit insérée
  simultanément pour fournir la C-ROM ("REQUIRES: game cartridge in slot
  (provides C ROM on P bus)", [ExtTestPBus.s:21](ExtTestPBus.s#L21) et
  [Brico68k.s:92](Brico68k.s#L92)). Cela implique que la carte BricoNeo (et
  donc potentiellement la future carte analyseur) doit pouvoir **coexister
  électriquement avec une cartouche de jeu réelle en aval**, pas seulement
  se substituer à elle — point de conception important pour une carte
  "interposée" (pass-through + interception), à la différence d'une carte
  qui remplace totalement le slot cartouche.
- Le test P-Bus documente explicitement ses limites : il ne teste que les
  bits d'adresse de tuile 0-19 (via 20 sprites en walking-one), pas les
  bits d'adressage intra-tuile (P20-P23 environ) — voir commentaire
  [ExtTestPBus.s:20](ExtTestPBus.s#L20) et note finale affichée à l'écran
  ([ExtTestPBus.s:204](ExtTestPBus.s#L204)).

### 3.4 CPLD / décodage d'adresses / accès à des signaux normalement inaccessibles

Le dépôt ne contient **pas de sources CPLD/VHDL/Verilog** (c'est un dépôt
firmware 68000 uniquement) — mais le code révèle indirectement le contrat
que la logique CPLD de BricoNeo doit respecter :

1. Elle doit **mapper une RAM réelle** derrière les 4 longs mots
   `BRICO_COMMAND_IN`/`PARAM_1/2/3`, situés dans l'espace adresse ROM
   système (`$C00000+` selon l'offset dans le fichier lié), alors que le
   reste de cette zone est une vraie ROM en lecture seule
   ([Brico68k.s:66-75](Brico68k.s#L66-L75)). Autrement dit, le CPLD doit
   savoir distinguer/aiguiller un sous-ensemble précis d'adresses vers de
   la RAM au lieu de la ROM.
2. Elle doit **surveiller `/OE` sur la fenêtre d'adresses `$C20000+$0100*2`
   et au-delà** dans le miroir ROM système pour capturer les octets du
   protocole de sortie (§2.4), en lisant la **valeur portée par le bus
   d'adresse** au moment de `/OE`, pas le bus de données.
3. Elle doit permettre l'écriture de la commande depuis l'hôte externe
   (RP2040 ou équivalent) dans `BRICO_COMMAND_IN`/`PARAM_x` de façon
   asynchrone par rapport au 68000 — un point de synchronisation/mutex
   simple existe déjà côté firmware (attente que `BRICO_COMMAND_IN` repasse
   à 0 avant d'accepter une nouvelle commande, [Brico68k.s:103-110](Brico68k.s#L103-L110)).
4. Le TODO non résolu *"Commande RESET RP2040>68000"* ([Brico68k.s:10](Brico68k.s#L10))
   suggère que le contrôle du signal `/RESET` du 68000 depuis l'hôte externe
   était prévu mais pas encore réalisé/câblé au moment de ce commit — à
   vérifier/implémenter dans la nouvelle carte si utile aux tests de
   réparation (reset contrôlé pour relancer une séquence de test sans
   couper l'alimentation).
5. D'autres TODO en tête de fichier évoquent des travaux en cours :
   *"External screen"*, *"PIO trace swap KO => potentially fixed"*,
   *"BRAM backup and switch"*, *"Pas d'erreur sur commande inconnue?"*
   ([Brico68k.s:6-10](Brico68k.s#L6-L10)) — pistes de bugs/fonctionnalités
   non finalisées côté carte BricoNeo d'origine, à garder en tête si le
   nouveau projet s'en inspire ou en reprend le protocole.

---

## 4. Tests / outils réutilisables pour une carte interposée

Chaque extension ci-dessous est un bloc 68000 autonome, déclenché par le
protocole commande/paramètres décrit en §2.2-2.4, et peut servir de
référence directe (voire être ré-assemblé tel quel) pour valider une
nouvelle carte interposée sur le port cartouche :

| Extension | Fichier | Ce qu'elle exerce sur le bus / la cartouche |
|---|---|---|
| `EXT_ECHO` | [ExtEcho.s](ExtEcho.s) | Aller-retour paramètre → port de sortie ; test minimal de bonne communication hôte↔68000, sans toucher au bus mémoire de la console. Idéal premier test de bring-up d'une nouvelle carte. |
| `EXT_READ` | [ExtRead.s](ExtRead.s) | Lecture 16 bits à une adresse 68000 arbitraire fournie par l'hôte — utile pour sonder n'importe quelle adresse du bus depuis l'extérieur. |
| `EXT_WRITE` | [ExtWrite.s](ExtWrite.s) | Écriture 16 bits à une adresse arbitraire — complète `EXT_READ` pour un accès mémoire générique piloté depuis l'hôte. |
| `EXT_MEMDUMP` | [ExtMemDump.s](ExtMemDump.s) | Dump binaire d'une plage mémoire (adresse + nombre de mots) vers le port de sortie ; base d'un "memory dumper" générique réutilisable pour scanner tout l'espace adressable de la cartouche/console. |
| `EXT_TEST_INPUTS` | [ExtTestInputs.s](ExtTestInputs.s) | Lit et affiche bit à bit DIP switches (NEO-F0), contrôles P1/P2 (NEO-C1), Start/Select, Coin/Service (NEO-F0) — utile pour valider que les lignes d'I/O restent accessibles/non perturbées à travers la carte interposée. |
| `EXT_TEST_WRAM` / `EXT_TEST_BRAM` / `EXT_TEST_PRAM` | [ExtTestBWPRAM.s](ExtTestBWPRAM.s) | Tests RAM classiques (0000/FFFF/AAAA/5555/incrémental) avec diagnostic bit par bit (poids fort/faible) et bornes RAM_START/END, BACKUP_RAM_START/END, PALETTE_RAM_START/END — directement réutilisable pour valider qu'une carte interposée ne dégrade pas l'intégrité des bus RAM. |
| `EXT_TEST_VRAM_LOWER/UPPER` | [ExtTestVRAM.s](ExtTestVRAM.s) | Test séquentiel simple d'écriture/lecture VRAM via `REG_VRAMADD/REG_VRAMRW/REG_VRAMMOD`, avec bornes différenciées lente/rapide ($0000-$7FFF / $8000-$85FF). |
| `EXT_TEST_MARCH_VRAM_LOWER/UPPER` | [ExtTestMarchVram.s](ExtTestMarchVram.s) | Algorithme **March-C** complet (6 passes up/down, r0w1/r1w0) sur la VRAM — bon modèle d'algorithme de test mémoire robuste, transposable à toute RAM accessible via la nouvelle carte. |
| `EXT_TEST_LSPC` | [ExtTestLSPC.s](ExtTestLSPC.s) | Test round-trip `REG_VRAMMOD`, `REG_VRAMADD`+`REG_VRAMRW`, et auto-incrément VRAM — bon exemple de test de registre "à quirks" (non directement relisible) à adapter si la nouvelle carte doit valider d'autres registres non triviaux du chipset. |
| `EXT_TEST_PBUS` | [ExtTestPBus.s](ExtTestPBus.s) | Test **visuel** (20 sprites en walking-one) des bits d'adresse de tuile 0-19 du bus P (bus cartouche C-ROM) — le test le plus directement pertinent pour un analyseur de port cartouche, car il exerce spécifiquement les lignes d'adresse vers la cartouche de jeu plutôt que la RAM interne console. Nécessite une vraie cartouche insérée. |
| `printWord` (outil) | [Tools.s](Tools.s) | Conversion mot 16 bits → 4 chiffres hexa ASCII, réutilisé par tous les tests pour le reporting — utilitaire générique à garder. |
| `InlinePortWriteD0` / `InlinePrintA1` | [inc/define.inc](inc/define.inc) | Primitives bas niveau du protocole de sortie (§2.4) — à ré-implémenter à l'identique si la nouvelle carte veut rester compatible avec ce protocole, ou à étudier comme référence si on en conçoit un nouveau plus simple (ex: vrai port I/O mappé mémoire côté CPLD plutôt que ce détournement via `/OE` + bus d'adresse). |
| Macros `Nop2..Nop16` | [inc/define.inc:147-175](inc/define.inc#L147-L175) | Délais fixes calibrés empiriquement pour le LSPC2 — point de départ pour caractériser au timing réel (oscillo/analyseur logique) les contraintes d'accès registre du chipset vidéo à travers la nouvelle carte. |

Le `Makefile`/`Makefile.linux`/`MakefilePC` montrent aussi le pipeline de
build (`vasmm68k_mot` + `vlink`, format `-brawbin1`) et un mécanisme de
déploiement par copie sur un volume monté (`BRICONEO_MASS_STORAGE_PATH`) —
réutilisable tel quel si le nouveau projet garde un firmware 68000 similaire
chargé depuis une carte SD/stockage de masse exposée par le contrôleur hôte.

---

## 5. Points d'incertitude / hypothèses à re-vérifier au CPLD / analyseur logique

- **Nature exacte du contrôleur hôte** : le code suppose un hôte externe
  (commentaire `RP2040>68000` en TODO) mais aucun schéma/CPLD n'est présent
  dans ce dépôt pour confirmer le rôle exact du CPLD vs un microcontrôleur
  séparé. À vérifier : est-ce le CPLD seul qui décode les adresses et pilote
  un port parallèle vers un MCU, ou le CPLD fait-il aussi du séquencement
  actif (état, FIFO) ?
- **Timing réel des accès bus** : aucune valeur numérique de cycles d'attente
  ou de durée n'est documentée ; seuls des `Nop2`..`Nop16` empiriques sont
  utilisés autour des accès LSPC/VRAM. À mesurer précisément à l'oscillo ou
  à l'analyseur logique une fois la nouvelle carte en place, en particulier
  autour de `REG_VRAMADD`/`REG_VRAMRW`/`REG_VRAMMOD` ($3C0000/$3C0002/$3C0004).
- **Comportement précis du seuil `/OE` à `$0100`** dans le miroir ROM
  ($C20000+$0100*2) : documenté en commentaire mais jamais justifié
  électriquement dans ce dépôt (pas de lien avec un composant physique
  précis: PAL/GAL de la carte mère AES/MVS vs CPLD BricoNeo). À confirmer
  si ce seuil vient du décodage natif de la carte mère Neo Geo (donc
  contrainte universelle pour toute carte interposée) ou spécifiquement du
  CPLD BricoNeo (donc négociable pour un nouveau design).
- **Portée réelle des lignes bus exercées par `EXT_TEST_PBUS`** : le
  commentaire indique lui-même que les bits P20-P23 (adressage intra-tuile)
  ne sont "pas testables de cette façon" ([ExtTestPBus.s:20](ExtTestPBus.s#L20))
  — reste à concevoir un test complémentaire (probablement en observant
  directement le bus avec l'analyseur logique plutôt qu'en visuel) pour ces
  lignes.
- **Fiabilité de `REG_LSPCMODE`, `REG_VRAMADD` en lecture, `REG_TIMERHIGH/LOW`
  en lecture** : documentés comme non fiables/non lisibles d'après le
  comportement observé par les développeurs BricoNeo ([ExtTestLSPC.s:11-14](ExtTestLSPC.s#L11-L14)),
  mais ce sont des observations empiriques non sourcées vers une datasheet
  LSPC2-A2 dans ce dépôt — à valider indépendamment.
- **Différence AES/MVS de position de la puce WRAM** (poids fort/faible)
  mentionnée en dur dans les messages d'erreur ([ExtTestBWPRAM.s:282](ExtTestBWPRAM.s#L282),
  [ExtTestBWPRAM.s:313](ExtTestBWPRAM.s#L313)) — présentée comme un fait
  connu de l'équipe BricoNeo mais sans référence croisée dans ce dépôt ; à
  reconfirmer physiquement sur les cartes mères ciblées par le nouveau
  projet.
- **Gestion d'erreur sur commande inconnue** : notée explicitement comme
  point ouvert ("Pas d'erreur sur commande inconnue?", [Brico68k.s:9](Brico68k.s#L9))
  — le protocole actuel ne semble pas avoir de retour d'erreur défini si
  l'hôte envoie une adresse de commande invalide ; à spécifier clairement
  dans le nouveau protocole carte↔hôte pour éviter un plantage silencieux du
  68000 pendant les tests.
- **`/RESET` piloté par l'hôte** : non implémenté dans ce firmware (TODO),
  donc le mécanisme électrique par lequel une carte interposée pourrait
  forcer un reset du 68000 de la console reste à concevoir et à valider
  matériellement (impact sur les autres puces de la carte mère partageant
  la ligne `/RESET`).
- **Fichiers binaires `rom/Brico68k.bin` et `rom/ROM.BIO`** : présents mais
  non désassemblés dans le cadre de cette analyse (analyse basée sur les
  sources assembleur, qui sont a priori strictement équivalentes au binaire
  produit par le Makefile) — à recouper avec un désassemblage si une
  divergence source/binaire est suspectée.
