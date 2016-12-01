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
# Format a string containing a number
#------------------------------------------------------------------------------
function(format_plural VAR)
  cmake_parse_arguments("" "" "ZERO;ONE;MANY" "" ${ARGN})
  set(_count ${_UNPARSED_ARGUMENTS})
  if(_count EQUAL 0)
    string(REPLACE "#" ${_count} _result "${_ZERO}")
  elseif(_count EQUAL 1)
    string(REPLACE "#" ${_count} _result "${_ONE}")
  else()
    string(REPLACE "#" ${_count} _result "${_MANY}")
  endif()
  set(${VAR} "${_result}" PARENT_SCOPE)
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
# Clear status flag and list of causes
#------------------------------------------------------------------------------
macro(clear_status STATUS)
  set(DASHBOARD_${STATUS} OFF)
  set(DASHBOARD_${STATUS}S "")
endmacro()

#------------------------------------------------------------------------------
# Set status flag and append step to causes for said flag
#------------------------------------------------------------------------------
macro(append_step_status STEP STATUS)
  set(DASHBOARD_${STATUS} ON)
  list(APPEND DASHBOARD_${STATUS}S "${STEP}")
endmacro()

#------------------------------------------------------------------------------
# Report build configuration
#------------------------------------------------------------------------------
function(report_configuration)
  set(_report_align 32)
  set(_empty_section FALSE)
  message("")

  # Convert input to token list
  string(REGEX REPLACE "[ \t\n]+" ";" _args "${ARGN}")

  # Iterate over tokens
  foreach(_token ${_args})
    # Group separator directive
    if(_token MATCHES "^=+$")

      if(NOT _empty_section)
        fill(_hr "  " "-" 80)
        message("${_hr}")
      endif()

      set(_env OFF)
      set(_display_prefix "")
      set(_value_prefix "")
      set(_empty_section TRUE)

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
      set(_empty_section FALSE)

    endif()
  endforeach()

  message("")
endfunction()

#------------------------------------------------------------------------------
# Prepend entries to an environment path
#------------------------------------------------------------------------------
function(prepend_path VAR)
  file(TO_CMAKE_PATH "$ENV{${VAR}}" _paths)
  list(INSERT _paths 0 ${ARGN})
  string(REPLACE ";" ":" _newpath "${_paths}")
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

#------------------------------------------------------------------------------
# Start a dashboard submission
#------------------------------------------------------------------------------
function(begin_stage)
  cmake_parse_arguments("_bs"
    ""
    "URL_NAME;BUILD_NAME;PROJECT_NAME"
    ""
    ${ARGN})

  set(CTEST_BUILD_NAME "${_bs_BUILD_NAME}" PARENT_SCOPE)
  set(CTEST_PROJECT_NAME "${_bs_PROJECT_NAME}" PARENT_SCOPE)
  set(CTEST_NIGHTLY_START_TIME "${DASHBOARD_NIGHTLY_START_TIME}" PARENT_SCOPE)
  set(CTEST_DROP_METHOD "https" PARENT_SCOPE)
  set(CTEST_DROP_SITE "${DASHBOARD_CDASH_SERVER}" PARENT_SCOPE)
  set(CTEST_DROP_LOCATION "/submit.php?project=${_bs_PROJECT_NAME}" PARENT_SCOPE)
  set(CTEST_DROP_SITE_CDASH ON PARENT_SCOPE)

  if(DEFINED _bs_URL_NAME)
    set(_preamble "CDash ${_bs_URL_NAME} URL")
  else()
    set(_preamble "CDash URL")
  endif()

  if(NOT DASHBOARD_CDASH_URL_MESSAGES MATCHES "${_preamble}")
    if(DASHBOARD_LABEL)
      set(_url_message
      "${_preamble}: https://${DASHBOARD_CDASH_SERVER}/index.php?project=${_bs_PROJECT_NAME}&showfilters=1&filtercount=2&showfilters=1&filtercombine=and&field1=label&compare1=61&value1=${DASHBOARD_LABEL}&field2=buildstarttime&compare2=84&value2=now")
    else()
      set(_url_message "${_preamble}:")
    endif()
    set(DASHBOARD_CDASH_URL_MESSAGES
      ${DASHBOARD_CDASH_URL_MESSAGES} ${_url_message}
      PARENT_SCOPE)
  endif()
endfunction()

#------------------------------------------------------------------------------
# Execute a build step
#------------------------------------------------------------------------------
macro(execute_step CONFIG NAME)
  include(${DASHBOARD_DRIVER_DIR}/configurations/${CONFIG}/step-${NAME}.cmake)
endmacro()
