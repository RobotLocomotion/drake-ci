# -*- mode: cmake; -*-
# vi: set ft=cmake:

# BSD 3-Clause License
#
# Copyright (c) 2016, Massachusetts Institute of Technology.
# Copyright (c) 2016, Toyota Research Institute.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#------------------------------------------------------------------------------
# Sleep for an interval of time
#------------------------------------------------------------------------------
function(sleep SECONDS)
  execute_process(COMMAND "sleep" "${SECONDS}"
    COMMAND_ECHO STDERR)
endfunction()

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
    file(WRITE "${DASHBOARD_WORKSPACE}/RESULT" "FAILURE")
  endif()
  # Remove any temporary files that we created
  foreach(_file ${DASHBOARD_TEMPORARY_FILES})
    file(REMOVE_RECURSE ${${_file}})
  endforeach()
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
# Set dashboard status message and write status file for specified status
#------------------------------------------------------------------------------
function(report_status STATUS MESSAGE)
  string(REPLACE ";" " / " _steps "${DASHBOARD_${STATUS}S}")
  string(REPLACE "%STEPS%" "${_steps}" _message "${MESSAGE}")
  set(DASHBOARD_MESSAGE "${_message}" PARENT_SCOPE)
  file(WRITE "${DASHBOARD_WORKSPACE}/RESULT" "${STATUS}")
endfunction()

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
  execute_process(COMMAND mktemp -q "${DASHBOARD_TEMP_DIR}/${NAME}"
    RESULT_VARIABLE _mktemp_result
    OUTPUT_VARIABLE _mktemp_output
    ERROR_VARIABLE _mktemp_error
    OUTPUT_STRIP_TRAILING_WHITESPACE)
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
function(chmod PATH PERMISSIONS MESSAGE)
  execute_process(COMMAND sudo chmod ${PERMISSIONS} "${PATH}"
    RESULT_VARIABLE _chmod_result
    OUTPUT_VARIABLE _chmod_output
    ERROR_VARIABLE _chmod_output)
  if(NOT _chmod_result EQUAL 0)
    fatal("setting permissions on ${MESSAGE} was not successful"
      _chmod_output)
  endif()
endfunction()

#------------------------------------------------------------------------------
# Change ownership of a file or directory to the current user
#------------------------------------------------------------------------------
function(chown PATH)
  execute_process(
    COMMAND whoami
    OUTPUT_VARIABLE _current_user
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  execute_process(
    COMMAND sudo chown ${_current_user} "${PATH}"
    RESULT_VARIABLE _chown_result)
  if(NOT _chown_result EQUAL 0)
    fatal("Could not change ownership of ${PATH}")
  endif()
endfunction()

#------------------------------------------------------------------------------
# Create a directory with specified permissions
#------------------------------------------------------------------------------
function(mkdir PATH PERMISSIONS MESSAGE)
  message(STATUS "Creating ${MESSAGE}...")
  execute_process(
    COMMAND sudo "${CMAKE_COMMAND}" -E make_directory "${PATH}"
    RESULT_VARIABLE _mkdir_result)
  if(NOT _mkdir_result EQUAL 0)
    fatal("creation of ${MESSAGE} was not successful")
  endif()
  chmod("${PATH}" "${PERMISSIONS}" "${MESSAGE}")
  chown("${PATH}")
endfunction()

#------------------------------------------------------------------------------
# Upload an artifact to AWS
#------------------------------------------------------------------------------
macro(aws_upload ARTIFACT UNSTABLE_MESSAGE)
  execute_process(
    COMMAND ${DASHBOARD_PYTHON_COMMAND}
      "${DASHBOARD_TOOLS_DIR}/upload-to-aws.py"
      --bucket "drake-packages"
      --track "${DASHBOARD_TRACK}"
      --aws "${DASHBOARD_AWS_COMMAND}"
      --log "${CTEST_BINARY_DIRECTORY}/aws_artifacts.log"
      "${ARTIFACT}"
    RESULT_VARIABLE DASHBOARD_AWS_UPLOAD_RESULT_VARIABLE)
  if(NOT DASHBOARD_AWS_UPLOAD_RESULT_VARIABLE EQUAL 0)
    append_step_status("${UNSTABLE_MESSAGE}" UNSTABLE)
  endif()
endmacro()

#------------------------------------------------------------------------------
# Report list of artifacts uploaded to AWS
#------------------------------------------------------------------------------
macro(aws_report)
  if(EXISTS "${CTEST_BINARY_DIRECTORY}/aws_artifacts.log")
    message(STATUS "Artifacts uploaded to AWS:")
    execute_process(
      COMMAND grep -vE "[.]sha[0-9]*\$"
        "${CTEST_BINARY_DIRECTORY}/aws_artifacts.log")
  endif()
endmacro()

#------------------------------------------------------------------------------
# Generate the pip index url
#------------------------------------------------------------------------------
macro(generate_pip_index_url)
  # NOTE: this macro should only run at the end *AFTER* the wheel build has
  # completed.  Rather than making the setup/ logic for drake-ci more
  # complicated, defer to the end and use a virtual environment to install
  # boto3.  By the end of the script, python3 will be available.
  set(venv "${DASHBOARD_TOOLS_DIR}/venv")
  execute_process(
    COMMAND ${DASHBOARD_PYTHON_COMMAND} -m venv "${venv}"
    RESULT_VARIABLE DASHBOARD_PYTHON_VENV_RESULT_VARIABLE)
  if(DASHBOARD_PYTHON_VENV_RESULT_VARIABLE EQUAL 0)
    execute_process(
      COMMAND "${venv}/bin/pip" install boto3
      RESULT_VARIABLE DASHBOARD_PYTHON_PIP_BOTO3_RESULT_VARIABLE)
    if(DASHBOARD_PYTHON_PIP_BOTO3_RESULT_VARIABLE EQUAL 0)
      execute_process(
        COMMAND "${venv}/bin/python3" "${DASHBOARD_TOOLS_DIR}/pip_index_url.py"
        RESULT_VARIABLE DASHBOARD_PIP_INDEX_URL_RESULT_VARIABLE)
      if(NOT DASHBOARD_PIP_INDEX_URL_RESULT_VARIABLE EQUAL 0)
        append_step_status("PIP INDEX URL" UNSTABLE)
      endif()
    else()
      append_step_status("PIP INDEX URL PIP INSTALL BOTO3" UNSTABLE)
    endif()
  else()
    append_step_status("PIP INDEX URL VENV CREATION" UNSTABLE)
  endif()
  unset(venv)
endmacro()

#------------------------------------------------------------------------------
# Start a dashboard submission
#------------------------------------------------------------------------------
function(begin_stage)
  cmake_parse_arguments("_bs"
    ""
    "BUILD_NAME;PROJECT_NAME"
    ""
    ${ARGN})

  # Set dashboard parameters
  set(CTEST_BUILD_NAME "${_bs_BUILD_NAME}")
  set(CTEST_PROJECT_NAME "${_bs_PROJECT_NAME}")
  set(CTEST_NIGHTLY_START_TIME "${DASHBOARD_NIGHTLY_START_TIME}")
  set(CTEST_DROP_METHOD "https")
  set(CTEST_DROP_SITE "${DASHBOARD_CDASH_SERVER}")
  set(CTEST_DROP_LOCATION "/submit.php?project=${_bs_PROJECT_NAME}")
  set(CTEST_DROP_SITE_CDASH ON)

  # Prepare message to report CDash URL to Jenkins
  if(DASHBOARD_LABEL)
    set(DASHBOARD_CDASH_URL
      "https://${DASHBOARD_CDASH_SERVER}/index.php?project=${_bs_PROJECT_NAME}&showfilters=1&filtercount=2&showfilters=1&filtercombine=and&field1=label&compare1=61&value1=${DASHBOARD_LABEL}&field2=buildstarttime&compare2=84&value2=now"
      PARENT_SCOPE)
  endif()

  # Set up the dashboard
  ctest_start("${DASHBOARD_MODEL}" TRACK "${DASHBOARD_TRACK}" QUIET)

  # Upload the Jenkins job URL to add link on CDash
  set(DASHBOARD_BUILD_URL_FILE
    "${CTEST_BINARY_DIRECTORY}/${_bs_BUILD_NAME}.url")
  string(STRIP "$ENV{BUILD_URL}" DASHBOARD_BUILD_URL)
  file(WRITE "${DASHBOARD_BUILD_URL_FILE}" "${DASHBOARD_BUILD_URL}")
  ctest_upload(FILES "${DASHBOARD_BUILD_URL_FILE}"
    CAPTURE_CMAKE_ERROR DASHBOARD_UPLOAD_CAPTURE_CMAKE_ERROR
    QUIET)
  if(DASHBOARD_UPLOAD_CAPTURE_CMAKE_ERROR EQUAL -1)
    message(WARNING "*** CTest upload step was not successful")
  endif()

  # Set CTest variables in parent scope
  set(_vars
    BUILD_NAME PROJECT_NAME NIGHTLY_START_TIME
    DROP_METHOD DROP_SITE DROP_LOCATION DROP_SITE_CDASH)
  foreach(_var ${_vars})
    set(CTEST_${_var} "${CTEST_${_var}}" PARENT_SCOPE)
  endforeach()
endfunction()

#------------------------------------------------------------------------------
# Execute a build step
#------------------------------------------------------------------------------
macro(execute_step CONFIG NAME)
  include(${DASHBOARD_DRIVER_DIR}/configurations/${CONFIG}/step-${NAME}.cmake)
endmacro()

#------------------------------------------------------------------------------
# Set DASHBOARD_(CC|CXX)_COMMAND based on the COMPILER from the job name by
# invoking tooling within Drake. This is used conditionally in compiler.cmake
# to select the compiler for the current build.
#------------------------------------------------------------------------------
function(determine_compiler)
  # Query what compiler is specified by `--config=${COMPILER}`.
  set(COMPILER_CONFIG_ARGS
    run --config=${COMPILER}
    //tools/cc_toolchain:print_compiler_config)

  execute_process(COMMAND ${DASHBOARD_BAZEL_COMMAND} ${COMPILER_CONFIG_ARGS}
    WORKING_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}"
    OUTPUT_VARIABLE COMPILER_CONFIG_OUTPUT
    RESULT_VARIABLE COMPILER_CONFIG_RETURN_VALUE)

  if(NOT COMPILER_CONFIG_RETURN_VALUE EQUAL 0)
    fatal("compiler configuration could not be obtained")
  endif()

  # Clean up the Bazel environment; otherwise, if we try to run Bazel again
  # with different arguments (`--output_user_root` in particular?), things go
  # horribly sideways.
  execute_process(COMMAND ${DASHBOARD_BAZEL_COMMAND} clean
    WORKING_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}")

  # Extract the compiler (CC, CXX) names.
  STRING(REPLACE "\n" ";" COMPILER_CONFIG_OUTPUT "${COMPILER_CONFIG_OUTPUT}")
  foreach(COMPILER_CONFIG_ENTRY IN LISTS COMPILER_CONFIG_OUTPUT)
    if("${COMPILER_CONFIG_ENTRY}" MATCHES "^([A-Z]+)=(.*)$")
      set(DASHBOARD_${CMAKE_MATCH_1}_COMMAND "${CMAKE_MATCH_2}")
    endif()
  endforeach()

  # Fail if the above extraction didn't work.
  if("${DASHBOARD_CC_COMMAND}" STREQUAL "")
    fatal("compiler configuration (CC) could not be obtained")
  endif()
  if("${DASHBOARD_CXX_COMMAND}" STREQUAL "")
    fatal("compiler configuration (CXX) could not be obtained")
  endif()

  set(DASHBOARD_CC_COMMAND "${DASHBOARD_CC_COMMAND}" PARENT_SCOPE)
  set(DASHBOARD_CXX_COMMAND "${DASHBOARD_CXX_COMMAND}" PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------------
# Verify that (cc|c++) and (gcc|g++) exist and that they resolve to the same
# path as each other, respectively. Store the output paths to cc and c++ in the
# respective output variables. This is used conditionally under some build
# configurations when we do not want to provide a compiler explicitly, to
# provide additional CI coverage of Drake's compiler identification logic.
#------------------------------------------------------------------------------
function(verify_cc_is_gcc OUTPUT_CC_VARIABLE OUTPUT_CXX_VARIABLE)
  find_program(CC_COMMAND NAMES "cc")
  if(NOT CC_COMMAND)
    fatal("cc was not found")
  endif()
  find_program(CPP_COMMAND NAMES "c++")
  if(NOT CPP_COMMAND)
    fatal("c++ was not found")
  endif()
  find_program(GCC_COMMAND NAMES "gcc")
  if(NOT GCC_COMMAND)
    fatal("gcc was not found")
  endif()
  find_program(GPP_COMMAND NAMES "g++")
  if(NOT GPP_COMMAND)
    fatal("g++ was not found")
  endif()

  file(REAL_PATH "${CC_COMMAND}" CC_REALPATH)
  file(REAL_PATH "${GCC_COMMAND}" GCC_REALPATH)
  if(NOT CC_REALPATH STREQUAL GCC_REALPATH)
    fatal("cc and gcc are not the same" CC_REALPATH GCC_REALPATH)
  endif()

  file(REAL_PATH "${CPP_COMMAND}" CPP_REALPATH)
  file(REAL_PATH "${GPP_COMMAND}" GPP_REALPATH)
  if(NOT CPP_REALPATH STREQUAL GPP_REALPATH)
    fatal("cc and gcc are not the same" CPP_REALPATH GPP_REALPATH)
  endif()

  set(${OUTPUT_CC_VARIABLE} "${CC_COMMAND}" PARENT_SCOPE)
  set(${OUTPUT_CXX_VARIABLE} "${CPP_COMMAND}" PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------------
# Execute `${COMPILER} --version` and store the first line of the result in
# `OUTPUT_VARIABLE`.  This function is used in compiler.cmake only to be able
# to log the compiler version in Jenkins, we do not care about detecting exact
# major / minor / patch versions of a given compiler.
#------------------------------------------------------------------------------
function(compiler_version_string COMPILER OUTPUT_VARIABLE)
  if(NOT ARGC EQUAL 2)
    fatal("Usage: compiler_version_string(\${COMPILER} OUTPUT_VARIABLE)")
  endif()
  # Execute `${COMPILER} --version`
  execute_process(COMMAND "${COMPILER}" "--version"
    OUTPUT_VARIABLE compiler_version
    ERROR_VARIABLE compiler_error
    RESULT_VARIABLE compiler_result_variable)
  if(compiler_result_variable)
    fatal("unable to determine '${compiler} --version': ${compiler_error}")
  endif()
  # Extract the first line and set the output.
  string(REGEX REPLACE ";" "\\\\;" compiler_version "${compiler_version}")
  string(REGEX REPLACE "\n" ";" compiler_version "${compiler_version}")
  list(GET compiler_version 0 compiler_version)
  set(${OUTPUT_VARIABLE} "${compiler_version}" PARENT_SCOPE)
endfunction()
