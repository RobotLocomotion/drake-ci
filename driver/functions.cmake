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
# Create a temporary file
#------------------------------------------------------------------------------
function(mktemp OUTVAR NAME MESSAGE)
  if(WIN32)
    string(RANDOM LENGTH 8 _random)
    string(REGEX REPLACE "XXXX+" "${_random}" _name
      "C:\\Windows\\Temp\\${NAME}")
    if(EXISTS "${_name}")
      file(REMOVE "${_name}")
      if(EXISTS "${_name}")
        fatal("creation of ${MESSAGE} was not successful")
      endif()
    endif()
  else()
    execute_process(COMMAND mktemp -q "/tmp/${NAME}"
      RESULT_VARIABLE _mktemp_result
      OUTPUT_VARIABLE _mktemp_output
      ERROR_VARIABLE _mktemp_error)
    if(NOT _mktemp_result EQUAL 0)
      fatal("creation of ${MESSAGE} was not successful"
        _mktemp_output
        _mktemp_error)
    endif()
    set(_name "${_mktemp_output}")
  endif()
  set(${OUTVAR} ${_name} PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------------
# Set POSIX permissions on file
#------------------------------------------------------------------------------
function(chmod PATH PERMISSIONS)
  if(NOT WIN32)
    execute_process(COMMAND chmod ${PERMISSIONS} "${PATH}"
      RESULT_VARIABLE _chmod_result
      OUTPUT_VARIABLE _chmod_output
      ERROR_VARIABLE _chmod_output)
    if(NOT _chmod_result EQUAL 0)
      fatal("setting permissions on ${MESSAGE} was not successful"
        _chmod_output)
    endif()
  endif()
endfunction()
