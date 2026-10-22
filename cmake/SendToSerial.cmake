# Sends a ROM image to BricoNeo through its dedicated ROM upload serial port.
# The image is loaded into BricoNeo's RAM and the Neo Geo is reset.
# If BANK is set, "StoreBank <BANK>" is then sent on the console serial port
# to persist the image in flash.
#
# Expected variables: SRC_FILE, ROM_UPLOAD_PORT, and CONSOLE_PORT + BANK (optional)

if(NOT DEFINED ROM_UPLOAD_PORT OR ROM_UPLOAD_PORT STREQUAL "")
    message(FATAL_ERROR
        "ROM_UPLOAD_PORT is not set.\n"
        "Configure the project with -DROM_UPLOAD_PORT=<BricoNeo ROM upload serial port> (the second BricoNeo serial port), e.g.\n"
        "  cmake -DROM_UPLOAD_PORT=COM4 -B build                       (Windows)\n"
        "  cmake -DROM_UPLOAD_PORT=/dev/cu.usbmodemXXXX3 -B build      (macOS)\n"
        "  cmake -DROM_UPLOAD_PORT=/dev/ttyACM1 -B build               (Linux)\n"
        "then re-run this target."
    )
endif()

if(DEFINED BANK AND NOT BANK STREQUAL "" AND (NOT DEFINED CONSOLE_PORT OR CONSOLE_PORT STREQUAL ""))
    message(FATAL_ERROR
        "CONSOLE_PORT is not set.\n"
        "Configure the project with -DCONSOLE_PORT=<BricoNeo console serial port> (the first BricoNeo serial port), e.g.\n"
        "  cmake -DCONSOLE_PORT=COM3 -B build                          (Windows)\n"
        "  cmake -DCONSOLE_PORT=/dev/cu.usbmodemXXXX1 -B build         (macOS)\n"
        "  cmake -DCONSOLE_PORT=/dev/ttyACM0 -B build                  (Linux)\n"
        "then re-run this target."
    )
endif()

# Windows only accepts COM10 and above through the \\.\ device namespace
function(native_port_name port out_var)
    if(WIN32 AND port MATCHES "^[Cc][Oo][Mm][0-9]+$")
        set(port "\\\\.\\${port}")
    endif()
    set(${out_var} "${port}" PARENT_SCOPE)
endfunction()

# Writes a file to a serial port, as raw binary data
function(send_file_to_port file port)
    native_port_name("${port}" native_port)
    if(WIN32)
        file(TO_NATIVE_PATH "${file}" native_file)
        execute_process(
            COMMAND cmd /c copy /b "${native_file}" "${native_port}"
            RESULT_VARIABLE result
            OUTPUT_QUIET
        )
    else()
        # The port is kept open while switching it to raw mode, so that no byte gets translated (e.g. LF -> CRLF)
        execute_process(
            COMMAND sh -c "exec 3<>\"$1\" && stty raw -echo <&3 && cat \"$2\" >&3" sh "${native_port}" "${file}"
            RESULT_VARIABLE result
        )
    endif()
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "Failed to send '${file}' to serial port '${port}'. Make sure BricoNeo is plugged in, the port is correct and no other application has it open.")
    endif()
endfunction()

send_file_to_port("${SRC_FILE}" "${ROM_UPLOAD_PORT}")
message(STATUS "Sent ${SRC_FILE} -> ${ROM_UPLOAD_PORT}")

if(DEFINED BANK AND NOT BANK STREQUAL "")
    # Leave BricoNeo enough time to detect the end of transfer and process the image
    execute_process(COMMAND ${CMAKE_COMMAND} -E sleep 1)

    get_filename_component(command_file "${SRC_FILE}.storebank.txt" ABSOLUTE)
    file(WRITE "${command_file}" "StoreBank ${BANK}\r\n")
    send_file_to_port("${command_file}" "${CONSOLE_PORT}")
    file(REMOVE "${command_file}")
    message(STATUS "Sent 'StoreBank ${BANK}' -> ${CONSOLE_PORT}")
endif()
