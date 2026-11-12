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

set(OBJ_DIR ${CMAKE_BINARY_DIR}/obj)
set(PRECOMP_DIR ${CMAKE_BINARY_DIR}/precomp)
set(ROM_DIR ${CMAKE_BINARY_DIR}/rom)
file(MAKE_DIRECTORY ${OBJ_DIR} ${PRECOMP_DIR} ${ROM_DIR})

# --- ROM version ----------------------------------------------------------
# By default, the ROM gets the number of the next release: the highest
# vMAJOR.MINOR git tag, with MINOR + 1 (v1.34 -> 1.35). It is computed at
# configure time, so re-run the configure step after fetching new tags.
# Both values can be forced with -DVERSION_MAJOR=<n> -DVERSION_MINOR=<n>.
set(VERSION_MAJOR "" CACHE STRING "Forced ROM major version (empty = computed from git tags)")
set(VERSION_MINOR "" CACHE STRING "Forced ROM minor version (empty = computed from git tags)")

if(NOT VERSION_MAJOR STREQUAL "" AND NOT VERSION_MINOR STREQUAL "")
    set(ROM_VERSION_MAJOR ${VERSION_MAJOR})
    set(ROM_VERSION_MINOR ${VERSION_MINOR})
else()
    set(ROM_VERSION_MAJOR 0)
    set(ROM_VERSION_MINOR 0)
    find_package(Git QUIET)
    if(GIT_FOUND)
        execute_process(
            COMMAND ${GIT_EXECUTABLE} tag --list "v*" --sort=-v:refname
            WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
            OUTPUT_VARIABLE GIT_TAGS
            ERROR_QUIET
        )
        if(GIT_TAGS MATCHES "^v([0-9]+)\\.([0-9]+)")
            set(ROM_VERSION_MAJOR ${CMAKE_MATCH_1})
            math(EXPR ROM_VERSION_MINOR "${CMAKE_MATCH_2} + 1")
        endif()
    endif()
endif()
message(STATUS "ROM version: ${ROM_VERSION_MAJOR}.${ROM_VERSION_MINOR}")
# Read by the GitHub workflow to name the release
file(WRITE ${ROM_DIR}/version.txt "${ROM_VERSION_MAJOR}.${ROM_VERSION_MINOR}\n")

# --- Assemble & link ----------------------------------------------------
set(ASFLAGS -chklabels -nocase -Fvobj -m68000 -Dvasm=1 -DBuildNEO=1
    -DVERSION_MAJOR=${ROM_VERSION_MAJOR} -DVERSION_MINOR=${ROM_VERSION_MINOR}
    -I${CMAKE_SOURCE_DIR}/inc -spaces -quiet)
set(LDFLAGS -brawbin1 -T${CMAKE_SOURCE_DIR}/${TARGET_NAME}.ld)

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

# --- Deployment to BricoNeo through its serial ports ----------------------
# The build itself never touches BricoNeo: only the "run" and "store"
# targets do, and only when explicitly invoked.
set(ROM_UPLOAD_PORT "" CACHE STRING "BricoNeo ROM upload serial port (second port), e.g. COM4 or /dev/ttyACM1")
set(CONSOLE_PORT "" CACHE STRING "BricoNeo console serial port (first port, only used by the store target), e.g. COM3 or /dev/ttyACM0")

add_custom_target(run
    COMMAND ${CMAKE_COMMAND}
        -DROM_UPLOAD_PORT=${ROM_UPLOAD_PORT}
        -DSRC_FILE=${BIN_FILE}
        -P ${CMAKE_SOURCE_DIR}/cmake/SendToSerial.cmake
    DEPENDS ${BIN_FILE}
    COMMENT "Sending ROM to BricoNeo RAM through the ROM upload serial port"
    VERBATIM
)

add_custom_target(store
    COMMAND ${CMAKE_COMMAND}
        -DROM_UPLOAD_PORT=${ROM_UPLOAD_PORT}
        -DCONSOLE_PORT=${CONSOLE_PORT}
        -DBANK=0
        -DSRC_FILE=${BIN_FILE}
        -P ${CMAKE_SOURCE_DIR}/cmake/SendToSerial.cmake
    DEPENDS ${BIN_FILE}
    COMMENT "Sending ROM to BricoNeo through the ROM upload serial port and storing it in bank 0"
    VERBATIM
)
