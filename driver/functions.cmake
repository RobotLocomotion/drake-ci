#------------------------------------------------------------------------------
# Pad a string with specified fill character
#------------------------------------------------------------------------------
function(fill VAR TEXT FILLER LENGTH)
  string(LENGTH "${TEXT}${FILLER}" _n)
  if(_n LESS LENGTH)
    fill(_out "${TEXT}" "${FILLER}${FILLER}" ${LENGTH})
  else()
    string(SUBSTRING "${TEXT}${FILLER}" 0 ${LENGTH} _out)
  endif()
  set(${VAR} "${_out}" PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------------
# Display one or more formatted notice messages
#------------------------------------------------------------------------------
function(notice)
  fill(_hr "  " "-" 80)
  set(_hr "\n${_hr}\n")
  set(_text "${_hr}")
  foreach(_message ${ARGN})
    set(_text "${_text}  *** ${_message}${_hr}")
  endforeach()
  message( "${_text}")
endfunction()

#------------------------------------------------------------------------------
# Issue a fatal error
#------------------------------------------------------------------------------
function(fatal MESSAGE)
  foreach(_var ${ARGN})
    message(STATUS "${_var}: ${${_var}}")
  endforeach()
  if(DEFINED DASHBOARD_WORKSPACE)
    file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
  endif()
  string(TOUPPER "${MESSAGE}" MESSAGE)
  message(FATAL_ERROR "*** CTest Result: FAILURE BECAUSE ${MESSAGE}")
endfunction()

#------------------------------------------------------------------------------
# Report build configuration
#------------------------------------------------------------------------------
function(report_configuration)
  set(_report_align 32)
  message("")

  # Convert input to token list
  string(REGEX REPLACE "[ \t\n]+" ";" _args "${ARGN}")

  # Iterate over tokens
  foreach(_token ${_args})
    # Group separator directive
    if(_token MATCHES "^=+$")

      fill(_hr "  " "-" 80)
      message("${_hr}")

      set(_env OFF)
      set(_display_prefix "")
      set(_value_prefix "")

    elseif(_token STREQUAL "ENV")

      # Environment variables directive
      set(_env ON)

    elseif(_token MATCHES "^[.]")

      # Align column directive
      string(SUBSTRING "${_token}" 1 -1 _report_align)

    elseif(_token MATCHES "^<")

      # Display name prefix directive
      string(SUBSTRING "${_token}" 1 -1 _display_prefix)

    elseif(_token MATCHES "^>")

      # Value name prefix directive
      string(SUBSTRING "${_token}" 1 -1 _value_prefix)

    else()

      # Get name and value
      if(_token MATCHES "(.+)[(](.+)[)]")
        set(_name ${_display_prefix}${CMAKE_MATCH_1})
        set(_value ${_value_prefix}${CMAKE_MATCH_2})
      else()
        set(_name ${_display_prefix}${_token})
        set(_value ${_value_prefix}${_token})
      endif()

      # Report value
      if(_env)
        fill(_aligned_name "  ${_name}" " " ${_report_align})
        message("${_aligned_name} = $ENV{${_value}}")
      else()
        fill(_aligned_name "  ${_name}" " " ${_report_align})
        message("${_aligned_name} = ${${_value}}")
      endif()

    endif()
  endforeach()

  message("")
endfunction()

#------------------------------------------------------------------------------
# Prepend entries to an environment path
#------------------------------------------------------------------------------
function(prepend_path VAR)
  file(TO_CMAKE_PATH "$ENV{${VAR}}" _paths)
  list(APPEND _paths ${ARGN})
  file(TO_NATIVE_PATH "${_paths}" _newpath)
  set(ENV{${VAR}} "${_newpath}")
endfunction()

#------------------------------------------------------------------------------
# Set an environment path
#------------------------------------------------------------------------------
function(set_path VAR)
  unset(ENV{${VAR}})
  prepend_path(${VAR} ${ARGN})
endfunction()

#------------------------------------------------------------------------------
# Prepend entries to a flags (space separated) variable
#------------------------------------------------------------------------------
function(prepend_flags VAR)
  list(REVERSE ARGN)
  foreach(_flag ${ARGN})
    if(NOT "${VAR}" STREQUAL "")
      set(${VAR} "${_flag} ${${VAR}}")
    else()
      set(${VAR} "${_flag}")
    endif()
  endforeach()
  set(${VAR} "${${VAR}}" PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------------
# Add an entry to the generated CMake cache
#------------------------------------------------------------------------------
macro(cache_append_literal STRING)
  set(CACHE_CONTENT "${CACHE_CONTENT}${STRING}\n")
endmacro()

#------------------------------------------------------------------------------
# Add an entry to the generated CMake cache
#------------------------------------------------------------------------------
macro(cache_append NAME TYPE VALUE)
  cache_append_literal("${NAME}:${TYPE}=${VALUE}")
endmacro()

#------------------------------------------------------------------------------
# Add flags to the generated CMake cache
#------------------------------------------------------------------------------
function(cache_flag NAME TYPE)
  cmake_parse_arguments("_cf" "" "" "NAMES;EXTRA" ${ARGN})
  if(DASHBOARD_${NAME})
    if(DEFINED _cf_NAMES)
      foreach(_name ${_cf_NAMES})
        cache_append(${_name} ${TYPE} "${DASHBOARD_${NAME}}")
      endforeach()
    else()
      cache_append(CMAKE_${NAME} ${TYPE} "${DASHBOARD_${NAME}}")
    endif()
    foreach(_extra ${_cf_EXTRA})
      cache_append_literal("${_extra}")
    endforeach()
    set(CACHE_CONTENT "${CACHE_CONTENT}" PARENT_SCOPE)
  endif()
endfunction()

#------------------------------------------------------------------------------
# Create a temporary file
#------------------------------------------------------------------------------
function(mktemp OUTVAR NAME MESSAGE)
  execute_process(COMMAND mktemp -q "/tmp/${NAME}"
    RESULT_VARIABLE _mktemp_result
    OUTPUT_VARIABLE _mktemp_output
    ERROR_VARIABLE _mktemp_error)
  if(NOT _mktemp_result EQUAL 0)
    fatal("creation of ${MESSAGE} was not successful"
      _mktemp_output
      _mktemp_error)
  endif()
  set(${OUTVAR} "${_mktemp_output}" PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------------
# Set POSIX permissions on file
#------------------------------------------------------------------------------
function(chmod PATH PERMISSIONS)
  execute_process(COMMAND chmod ${PERMISSIONS} "${PATH}"
    RESULT_VARIABLE _chmod_result
    OUTPUT_VARIABLE _chmod_output
    ERROR_VARIABLE _chmod_output)
  if(NOT _chmod_result EQUAL 0)
    fatal("setting permissions on ${MESSAGE} was not successful"
      _chmod_output)
  endif()
endfunction()
