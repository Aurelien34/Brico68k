cmake_minimum_required(VERSION 3.16)
project(Brico68k NONE)

set(TARGET_NAME Brico68k)

# --- Locate vasm / vlink -----------------------------------------------
# Both tools are looked up on PATH first. If they are installed elsewhere,
# point VASM_ROOT / VLINK_ROOT at their directory, or set VASM_EXECUTABLE /
# VLINK_EXECUTABLE directly to the full path of the executable.
set(VASM_ROOT "" CACHE PATH "Directory containing the vasm executable (optional, PATH is searched first)")
set(VLINK_ROOT "" CACHE PATH "Directory containing the vlink executable (optional, PATH is searched first)")

find_program(VASM_EXECUTABLE
    NAMES vasmm68k_mot vasmm68k_mot_win32 vasmm68k_mot_win64 vasmm68k_mot.exe vasmm68k_mot_win32.exe vasmm68k_mot_win64.exe
    HINTS ${VASM_ROOT}
    DOC "Path to the vasm m68k assembler (vasmm68k_mot)"
)
find_program(VLINK_EXECUTABLE
    NAMES vlink vlink.exe
    HINTS ${VLINK_ROOT}
    DOC "Path to the vlink linker"
)

if(NOT VASM_EXECUTABLE)
    message(FATAL_ERROR
        "vasm (vasmm68k_mot) was not found. Install it and make sure it is in "
        "PATH, or configure with -DVASM_ROOT=<dir> / -DVASM_EXECUTABLE=<path>."
    )
endif()
if(NOT VLINK_EXECUTABLE)
    message(FATAL_ERROR
        "vlink was not found. Install it and make sure it is in PATH, or "
        "configure with -DVLINK_ROOT=<dir> / -DVLINK_EXECUTABLE=<path>."
    )
endif()

# --- Assemble & link ----------------------------------------------------
set(ASFLAGS -chklabels -nocase -Fvobj -m68000 -Dvasm=1 -DBuildNEO=1 -I${CMAKE_SOURCE_DIR}/inc -spaces -quiet)
set(LDFLAGS -brawbin1 -T${CMAKE_SOURCE_DIR}/${TARGET_NAME}.ld)

set(OBJ_DIR ${CMAKE_BINARY_DIR}/obj)
set(PRECOMP_DIR ${CMAKE_BINARY_DIR}/precomp)
set(ROM_DIR ${CMAKE_BINARY_DIR}/rom)
file(MAKE_DIRECTORY ${OBJ_DIR} ${PRECOMP_DIR} ${ROM_DIR})

file(GLOB ASM_SOURCES CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/*.s)
set(INC_FILE ${CMAKE_SOURCE_DIR}/inc/define.inc)

set(OBJ_FILES "")
foreach(src ${ASM_SOURCES})
    get_filename_component(name ${src} NAME_WE)
    set(obj ${OBJ_DIR}/${name}.o)
    add_custom_command(
        OUTPUT ${obj}
        COMMAND ${VASM_EXECUTABLE} ${ASFLAGS} -L ${PRECOMP_DIR}/${name}.s.txt -o ${obj} ${src}
        DEPENDS ${src} ${INC_FILE}
        COMMENT "Assembling ${name}.s"
        VERBATIM
    )
    list(APPEND OBJ_FILES ${obj})
endforeach()

set(BIN_FILE ${ROM_DIR}/${TARGET_NAME}.bin)
add_custom_command(
    OUTPUT ${BIN_FILE}
    COMMAND ${VLINK_EXECUTABLE} ${LDFLAGS} -o ${BIN_FILE} ${OBJ_FILES}
    DEPENDS ${OBJ_FILES} ${CMAKE_SOURCE_DIR}/${TARGET_NAME}.ld
    COMMENT "Linking ${TARGET_NAME}.bin"
    VERBATIM
)

add_custom_target(rom ALL DEPENDS ${BIN_FILE})

# --- Deployment to the external mass storage device ---------------------
# The build itself never touches the mass storage device: only the "run"
# and "store" targets do, and only when explicitly invoked.
set(MASS_STORAGE_PATH "" CACHE PATH "Path to the external USB mass storage device the ROM is copied to")

add_custom_target(run
    COMMAND ${CMAKE_COMMAND}
        -DMASS_STORAGE_PATH=${MASS_STORAGE_PATH}
        -DSRC_FILE=${BIN_FILE}
        -DDEST_FILE=${MASS_STORAGE_PATH}/ROM.bio
        -P ${CMAKE_SOURCE_DIR}/cmake/CopyToMassStorage.cmake
    DEPENDS ${BIN_FILE}
    COMMENT "Copying ROM to the mass storage device (current ROM slot)"
    VERBATIM
)

add_custom_target(store
    COMMAND ${CMAKE_COMMAND}
        -DMASS_STORAGE_PATH=${MASS_STORAGE_PATH}
        -DSRC_FILE=${BIN_FILE}
        -DDEST_FILE=${MASS_STORAGE_PATH}/BANK0/ROM.bio
        -P ${CMAKE_SOURCE_DIR}/cmake/CopyToMassStorage.cmake
    DEPENDS ${BIN_FILE}
    COMMENT "Copying ROM to the mass storage device (BANK0 slot)"
    VERBATIM
)
