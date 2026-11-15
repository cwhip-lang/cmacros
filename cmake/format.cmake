# Build-time body of the format target. PATH is searched when the target
# runs, so a cwhip-format installed later is picked up without reconfiguring.

if(NOT DEFINED CMACROS_SOURCE_DIR OR CMACROS_SOURCE_DIR STREQUAL ""
        OR NOT DEFINED CMACROS_BINARY_DIR OR CMACROS_BINARY_DIR STREQUAL "")
    message(FATAL_ERROR
        "cwhip-format target requires CMACROS_SOURCE_DIR and CMACROS_BINARY_DIR")
endif()

find_program(CMACROS_CWHIP_FORMAT NAMES cwhip-format
    HINTS ENV PATH
    NO_DEFAULT_PATH)
if(NOT CMACROS_CWHIP_FORMAT)
    message(FATAL_ERROR "cwhip-format is not available")
endif()

cmake_path(SET cmacros_source NORMALIZE "${CMACROS_SOURCE_DIR}")
cmake_path(ABSOLUTE_PATH cmacros_source NORMALIZE)
cmake_path(SET cmacros_binary NORMALIZE "${CMACROS_BINARY_DIR}")
cmake_path(ABSOLUTE_PATH cmacros_binary NORMALIZE)
cmake_path(SET cmacros_checkout_build NORMALIZE "${cmacros_source}/build")

file(GLOB_RECURSE cmacros_cw_files LIST_DIRECTORIES false
    "${cmacros_source}/*.cw")

cmake_path(IS_PREFIX cmacros_source "${cmacros_binary}" NORMALIZE
    cmacros_binary_in_source)
set(cmacros_skip_binary FALSE)
if(cmacros_binary_in_source AND NOT cmacros_binary STREQUAL cmacros_source)
    set(cmacros_skip_binary TRUE)
endif()

set(cmacros_format_inputs)
foreach(cmacros_cw_file IN LISTS cmacros_cw_files)
    set(cmacros_skip FALSE)
    if(cmacros_skip_binary)
        cmake_path(IS_PREFIX cmacros_binary "${cmacros_cw_file}" NORMALIZE
            cmacros_in_binary)
        if(cmacros_in_binary)
            set(cmacros_skip TRUE)
        endif()
    endif()
    cmake_path(IS_PREFIX cmacros_checkout_build "${cmacros_cw_file}" NORMALIZE
        cmacros_in_checkout_build)
    if(cmacros_in_checkout_build)
        set(cmacros_skip TRUE)
    endif()
    if(NOT cmacros_skip)
        list(APPEND cmacros_format_inputs "${cmacros_cw_file}")
    endif()
endforeach()

if(NOT cmacros_format_inputs)
    message(FATAL_ERROR "cwhip-format found no .cw files")
endif()
list(SORT cmacros_format_inputs COMPARE STRING)

execute_process(
    COMMAND "${CMACROS_CWHIP_FORMAT}" -i ${cmacros_format_inputs}
    WORKING_DIRECTORY "${cmacros_source}"
    RESULT_VARIABLE cmacros_format_result)
if(NOT cmacros_format_result EQUAL 0)
    message(FATAL_ERROR "cwhip-format failed (${cmacros_format_result})")
endif()
