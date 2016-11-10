#------------------------------------------------------------------------------
# Display one or more formatted notice messages
#------------------------------------------------------------------------------
function(notice)
  set(_hr "
  ------------------------------------------------------------------------------
  ")
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
