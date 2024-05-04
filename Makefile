#COM=COM4
#SEND=.\BricoNeoSend
#STORE=.\BricoNeoStore
BRICONEO_MASS_STORAGE_PATH=E:
COMPILE_TOOLS_BASE_DIRECTORY=D:\68kAssembly\68000DevTools\Utils\Vasm

BRICONEO_MASS_STORAGE_PATH_CURRENT_ROM=$(BRICONEO_MASS_STORAGE_PATH)\LOADROM\ROM.bio
BRICONEO_MASS_STORAGE_PATH_BANK0=$(BRICONEO_MASS_STORAGE_PATH)\ROMBANKS\ROM0\ROM.bio
TARGET=Brico68k
AS=$(COMPILE_TOOLS_BASE_DIRECTORY)\vasmm68k_mot_win32.exe
LD=$(COMPILE_TOOLS_BASE_DIRECTORY)\vlink.exe
ASFLAGS=-chklabels -nocase -Fvobj -m68000 -Dvasm=1 -DBuildNEO=1 -Iinc -spaces #-quiet
LDFLAGS=-brawbin1 -T$(TARGET).ld
OBJPATH = obj
OBJ = $(patsubst %.s,$(OBJPATH)/%.o,$(wildcard *.s))
INCS = inc/define.inc
OUTPUT_DIR = rom
PRECOMPPATH = precomp

all:
	make $(OUTPUT_DIR)/$(TARGET).bin
	make run

$(OUTPUT_DIR)/$(TARGET).bin: $(OUTPUT_DIR) $(OBJPATH) $(OBJ) $(TARGET).ld
	$(LD) $(LDFLAGS) -o $(OUTPUT_DIR)/$(TARGET).bin $(OBJ)

$(OBJPATH)/%.o: %.s $(INCS) $(PRECOMPPATH)
	$(AS) $(ASFLAGS) -L $(PRECOMPPATH)/$<.txt -o $@ $<

$(OUTPUT_DIR):
	mkdir $(OUTPUT_DIR)

$(OBJPATH):
	mkdir $(OBJPATH)

$(PRECOMPPATH):
	mkdir $(PRECOMPPATH)

clean:
	rmdir /S /Q precomp
	rmdir /S /Q obj
	rmdir /S /Q rom

run: $(OUTPUT_DIR)/$(TARGET).bin
	cd $(OUTPUT_DIR) && copy $(TARGET).bin $(BRICONEO_MASS_STORAGE_PATH_CURRENT_ROM)

#run: $(OUTPUT_DIR)/$(TARGET).bin
#	$(SEND) $(COM) $(subst /,\\,$(OUTPUT_DIR)/$(TARGET).bin)

store: $(OUTPUT_DIR)/$(TARGET).bin
	cd $(OUTPUT_DIR) && copy $(TARGET).bin $(BRICONEO_MASS_STORAGE_PATH_BANK0)

