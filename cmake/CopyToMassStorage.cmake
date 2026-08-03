if(NOT DEFINED MASS_STORAGE_PATH OR MASS_STORAGE_PATH STREQUAL "")
    message(FATAL_ERROR
        "MASS_STORAGE_PATH is not set.\n"
        "Configure the project with -DMASS_STORAGE_PATH=<path to your USB mass storage device>, e.g.\n"
        "  cmake -DMASS_STORAGE_PATH=D:/ -B build              (Windows)\n"
        "  cmake -DMASS_STORAGE_PATH=/Volumes/BRICO -B build   (macOS)\n"
        "  cmake -DMASS_STORAGE_PATH=/media/$ENV{USER}/BRICO -B build   (Linux)\n"
        "then re-run this target."
    )
endif()

if(NOT EXISTS "${MASS_STORAGE_PATH}")
    message(FATAL_ERROR
        "MASS_STORAGE_PATH ('${MASS_STORAGE_PATH}') does not exist. "
        "Make sure the USB mass storage device is plugged in and the path is correct."
    )
endif()

get_filename_component(dest_dir "${DEST_FILE}" DIRECTORY)
file(MAKE_DIRECTORY "${dest_dir}")

execute_process(
    COMMAND ${CMAKE_COMMAND} -E copy "${SRC_FILE}" "${DEST_FILE}"
    RESULT_VARIABLE copy_result
)
if(NOT copy_result EQUAL 0)
    message(FATAL_ERROR "Failed to copy '${SRC_FILE}' to '${DEST_FILE}'.")
endif()

message(STATUS "Copied ${SRC_FILE} -> ${DEST_FILE}")
