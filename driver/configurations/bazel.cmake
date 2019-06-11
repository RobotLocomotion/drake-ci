# -*- mode: cmake -*-
# vi: set ft=cmake :

# Copyright (c) 2016, Massachusetts Institute of Technology.
# Copyright (c) 2016, Toyota Research Institute.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# Jenkins passes down an incorrect value of JAVA_HOME from master to agent for
# some inexplicable reason.
unset(ENV{JAVA_HOME})

set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}")
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/_bazel_$ENV{USER}")

find_program(DASHBOARD_BAZEL_COMMAND NAMES "bazel")
if(NOT DASHBOARD_BAZEL_COMMAND)
  fatal("bazel was not found")
endif()

# Set bazel options
set(DASHBOARD_BAZEL_STARTUP_OPTIONS)
set(DASHBOARD_BAZEL_STARTUP_OPTIONS_CI
  "--output_user_root=${CTEST_BINARY_DIRECTORY}")

# Extract the version. Usually of the form x.y.z-*.
set(VERSION_ARGS "${DASHBOARD_BAZEL_STARTUP_OPTIONS} ${DASHBOARD_BAZEL_STARTUP_OPTIONS_CI} version")
separate_arguments(VERSION_ARGS_LIST UNIX_COMMAND "${VERSION_ARGS}")
execute_process(COMMAND ${DASHBOARD_BAZEL_COMMAND} ${VERSION_ARGS_LIST}
  RESULT_VARIABLE DASHBOARD_BAZEL_VERSION_RESULT_VARIABLE
  OUTPUT_VARIABLE DASHBOARD_BAZEL_VERSION_OUTPUT_VARIABLE
  ERROR_QUIET
  OUTPUT_STRIP_TRAILING_WHITESPACE)

if(DASHBOARD_BAZEL_VERSION_RESULT_VARIABLE EQUAL 0)
  string(REGEX MATCH "Build label: ([0-9a-zA-Z.\\-]+)"
       DASHBOARD_BAZEL_REGEX_MATCH_OUTPUT_VARIABLE
       "${DASHBOARD_BAZEL_VERSION_OUTPUT_VARIABLE}")
  if(DASHBOARD_BAZEL_REGEX_MATCH_OUTPUT_VARIABLE)
    set(DASHBOARD_BAZEL_VERSION "${CMAKE_MATCH_1}")
  endif()
else()
  fatal("could not determine bazel version")
endif()

set(DASHBOARD_BAZEL_BUILD_OPTIONS "--compilation_mode")
set(DASHBOARD_BAZEL_BUILD_OPTIONS_CI "--keep_going --action_env=GIT_SSH --announce_rc")

if(DEBUG)
  set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS}=dbg")
else()
  set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS}=opt")
endif()

if(DEFINED ENV{TERM})
  if(COMPILER STREQUAL "clang")
    set(DASHBOARD_BAZEL_BUILD_OPTIONS_CI "--copt=-fcolor-diagnostics ${DASHBOARD_BAZEL_BUILD_OPTIONS_CI}")
  elseif(COMPILER STREQUAL "gcc")
    set(DASHBOARD_BAZEL_BUILD_OPTIONS_CI "--copt=-fdiagnostics-color=always ${DASHBOARD_BAZEL_BUILD_OPTIONS_CI}")
  endif()
  set(DASHBOARD_BAZEL_BUILD_OPTIONS_CI "--color=yes ${DASHBOARD_BAZEL_BUILD_OPTIONS_CI}")
endif()

if(NOT APPLE)
  if(COMPILER STREQUAL "clang")
    set(ENV{CC} "clang${DASHBOARD_CLANG_COMPILER_SUFFIX}")
    set(ENV{CXX} "clang++${DASHBOARD_CLANG_COMPILER_SUFFIX}")
  elseif(COMPILER STREQUAL "gcc")
    set(ENV{CC} "gcc${DASHBOARD_GNU_COMPILER_SUFFIX}")
    set(ENV{CXX} "g++${DASHBOARD_GNU_COMPILER_SUFFIX}")
  else()
    fatal("unknown compiler '${COMPILER}'")
  endif()
endif()

if(DASHBOARD_PROCESSOR_COUNT GREATER 1)
  math(EXPR DASHBOARD_JOBS "3 * ${DASHBOARD_PROCESSOR_COUNT} / 4")
else()
  set(DASHBOARD_JOBS 1)
endif()

set(DASHBOARD_BAZEL_BUILD_OPTIONS_CI "${DASHBOARD_BAZEL_BUILD_OPTIONS_CI} --jobs=${DASHBOARD_JOBS}")

include(${DASHBOARD_DRIVER_DIR}/configurations/aws.cmake)
include(${DASHBOARD_DRIVER_DIR}/configurations/gurobi.cmake)
include(${DASHBOARD_DRIVER_DIR}/configurations/mosek.cmake)
include(${DASHBOARD_DRIVER_DIR}/configurations/snopt.cmake)

if(CXX EQUAL 17)
  set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --cxxopt=-std=c++17 --host_cxxopt=-std=c++17")
endif()

if(PYTHON EQUAL 3)
  set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --config=python3")
endif()

set(DASHBOARD_TEST_TAG_FILTERS)

if(EVERYTHING)
  set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --config=everything")
elseif(GUROBI OR MOSEK OR PACKAGE OR SNOPT)
  set(DASHBOARD_TEST_TAG_FILTERS
    "-gurobi"
    "-mosek"
    "-snopt"
  )
  if(GUROBI)
    set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --config=gurobi")
    list(REMOVE_ITEM DASHBOARD_TEST_TAG_FILTERS "-gurobi")
  endif()
  if(MOSEK)
    set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --config=mosek")
    list(REMOVE_ITEM DASHBOARD_TEST_TAG_FILTERS "-mosek")
  endif()
  if(PACKAGE OR SNOPT)
    if(SNOPT STREQUAL "F2C")
      set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --config=snopt_f2c")
    elseif(SNOPT STREQUAL "Fortran")
      set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --config=snopt_fortran")
    else()
      set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --config=snopt")
    endif()
    list(REMOVE_ITEM DASHBOARD_TEST_TAG_FILTERS "-snopt")
  endif()
endif()

if(COVERAGE)
  if(EVERYTHING)
    string(REPLACE
      "--config=everything"
      "--config=kcov_everything"
      DASHBOARD_BAZEL_BUILD_OPTIONS
      "${DASHBOARD_BAZEL_BUILD_OPTIONS}")
  else()
    set(DASHBOARD_BAZEL_BUILD_OPTIONS
      "${DASHBOARD_BAZEL_BUILD_OPTIONS} --config=kcov")
    if(DASHBOARD_TEST_TAG_FILTERS)
      list(APPEND DASHBOARD_TEST_TAG_FILTERS "-no_kcov")
    endif()
  endif()
endif()

if(MEMCHECK)
  set(MEMCHECK_BAZEL_CONFIG "")
  if(MEMCHECK MATCHES "(asan|address-sanitizer)")
    set(MEMCHECK_BAZEL_CONFIG "asan")
    if(DASHBOARD_TEST_TAG_FILTERS)
      list(APPEND DASHBOARD_TEST_TAG_FILTERS "-no_asan" "-no_lsan")
    endif()
  elseif(MEMCHECK MATCHES "(lsan|leak-sanitizer)")
    set(MEMCHECK_BAZEL_CONFIG "lsan")
    if(DASHBOARD_TEST_TAG_FILTERS)
      list(APPEND DASHBOARD_TEST_TAG_FILTERS "-no_lsan")
    endif()
  elseif(MEMCHECK MATCHES "(tsan|thread-sanitizer)")
    set(MEMCHECK_BAZEL_CONFIG "tsan")
    if(DASHBOARD_TEST_TAG_FILTERS)
      list(APPEND DASHBOARD_TEST_TAG_FILTERS "-no_tsan")
    endif()
  elseif(MEMCHECK MATCHES "(ubsan|undefined-behavior-sanitizer)")
    set(MEMCHECK_BAZEL_CONFIG "ubsan")
    if(DASHBOARD_TEST_TAG_FILTERS)
      list(APPEND DASHBOARD_TEST_TAG_FILTERS "-no_ubsan")
    endif()
  elseif(MEMCHECK MATCHES "(valgrind|valgrind-memcheck)")
    set(MEMCHECK_BAZEL_CONFIG "memcheck")
    if(DASHBOARD_TEST_TAG_FILTERS)
      list(APPEND DASHBOARD_TEST_TAG_FILTERS "-no_memcheck")
    endif()
  else()
    fatal("memcheck is invalid")
  endif()
  if(EVERYTHING)
    string(REPLACE
      "--config=everything"
      "--config=${MEMCHECK_BAZEL_CONFIG}_everything"
      DASHBOARD_BAZEL_BUILD_OPTIONS
      "${DASHBOARD_BAZEL_BUILD_OPTIONS}")
  else()
    set(DASHBOARD_BAZEL_BUILD_OPTIONS
      "${DASHBOARD_BAZEL_BUILD_OPTIONS} --config=${MEMCHECK_BAZEL_CONFIG}")
  endif()
endif()

if(DASHBOARD_TEST_TAG_FILTERS)
  list(JOIN DASHBOARD_TEST_TAG_FILTERS "," DASHBOARD_TEST_TAG_FILTERS_STRING)
  set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --test_tag_filters=${DASHBOARD_TEST_TAG_FILTERS_STRING}")
endif()

if(REMOTE_CACHE)
  set(DASHBOARD_REMOTE_HTTP_CACHE_URL "http://172.31.20.109")
  mktemp(DASHBOARD_FILE_DOWNLOAD_TEMP file_download_XXXXXXXX "temporary download file")
  list(APPEND DASHBOARD_TEMPORARY_FILES DASHBOARD_FILE_DOWNLOAD_TEMP)
  file(DOWNLOAD "${DASHBOARD_REMOTE_HTTP_CACHE_URL}" "${DASHBOARD_FILE_DOWNLOAD_TEMP}"
    STATUS DASHBOARD_DOWNLOAD_STATUS)
  list(GET DASHBOARD_DOWNLOAD_STATUS 0 DASHBOARD_DOWNLOAD_STATUS_0)
  if(DASHBOARD_DOWNLOAD_STATUS_0 EQUAL 0)
    set(DASHBOARD_BAZEL_BUILD_OPTIONS_CI "${DASHBOARD_BAZEL_BUILD_OPTIONS_CI} --experimental_guard_against_concurrent_changes --remote_http_cache=${DASHBOARD_REMOTE_HTTP_CACHE_URL} --remote_local_fallback --remote_local_fallback_strategy=sandboxed")
    if(DEBUG)
      set(DASHBOARD_BAZEL_BUILD_OPTIONS_CI "${DASHBOARD_BAZEL_BUILD_OPTIONS_CI} --experimental_remote_retry_max_attempts=1 --remote_max_connections=64")
      if(DASHBOARD_BAZEL_VERSION VERSION_LESS 0.23)
        set(DASHBOARD_BAZEL_BUILD_OPTIONS_CI "${DASHBOARD_BAZEL_BUILD_OPTIONS_CI} --remote_timeout=1")
      else()
        if(APPLE)
          set(DASHBOARD_BAZEL_BUILD_OPTIONS_CI "${DASHBOARD_BAZEL_BUILD_OPTIONS_CI} --remote_timeout=360")
        else()
          set(DASHBOARD_BAZEL_BUILD_OPTIONS_CI "${DASHBOARD_BAZEL_BUILD_OPTIONS_CI} --remote_timeout=240")
        endif()
      endif()
    else()
      set(DASHBOARD_BAZEL_BUILD_OPTIONS_CI "${DASHBOARD_BAZEL_BUILD_OPTIONS_CI} --remote_max_connections=128")
      if(DASHBOARD_BAZEL_VERSION VERSION_LESS 0.23)
        set(DASHBOARD_BAZEL_BUILD_OPTIONS_CI "${DASHBOARD_BAZEL_BUILD_OPTIONS_CI} --remote_timeout=1")
      else()
        if(APPLE)
          set(DASHBOARD_BAZEL_BUILD_OPTIONS_CI "${DASHBOARD_BAZEL_BUILD_OPTIONS_CI} --remote_timeout=180")
        else()
          set(DASHBOARD_BAZEL_BUILD_OPTIONS_CI "${DASHBOARD_BAZEL_BUILD_OPTIONS_CI} --remote_timeout=120")
        endif()
      endif()
    endif()
  else()
    message(WARNING "*** Could NOT contact remote HTTP cache")
  endif()

  if(DASHBOARD_TRACK STREQUAL "Nightly")
    set(DASHBOARD_BAZEL_BUILD_OPTIONS_CI "${DASHBOARD_BAZEL_BUILD_OPTIONS_CI} --noremote_accept_cached")
  elseif(DASHBOARD_TRACK STREQUAL "Continuous" AND DEBUG)
    set(DASHBOARD_BAZEL_BUILD_OPTIONS_CI "${DASHBOARD_BAZEL_BUILD_OPTIONS_CI} --noremote_accept_cached")
  elseif(DASHBOARD_TRACK STREQUAL "Experimental")
    set(DASHBOARD_BAZEL_BUILD_OPTIONS_CI "${DASHBOARD_BAZEL_BUILD_OPTIONS_CI} --noremote_upload_local_results")
  endif()
endif()

set(DASHBOARD_BAZEL_TEST_OPTIONS)
set(DASHBOARD_BAZEL_TEST_OPTIONS_CI "--test_summary=short")

if(APPLE)
  set(DASHBOARD_BAZEL_TEST_OPTIONS "${DASHBOARD_BAZEL_TEST_OPTIONS} --test_timeout=300,1500,4500,-1")
endif()

if(VERBOSE)
    set(DASHBOARD_BAZEL_BUILD_OPTIONS_CI
      "${DASHBOARD_BAZEL_BUILD_OPTIONS_CI} --subcommands")
endif()

# Report build configuration
report_configuration("
  ==================================== ENV
  CC
  CXX
  DISPLAY
  GUROBI_PATH
  SNOPT_PATH
  TERM
  ==================================== >DASHBOARD_
  UNIX
  UNIX_DISTRIBUTION
  UNIX_DISTRIBUTION_VERSION
  APPLE
  ====================================
  CMAKE_VERSION
  ====================================
  CTEST_BUILD_NAME(DASHBOARD_JOB_NAME)
  CTEST_BINARY_DIRECTORY
  CTEST_CHANGE_ID
  CTEST_GIT_COMMAND
  CTEST_SITE
  CTEST_SOURCE_DIRECTORY
  CTEST_UPDATE_COMMAND
  CTEST_UPDATE_VERSION_ONLY
  CTEST_UPDATE_VERSION_OVERRIDE
  ==================================== >DASHBOARD_
  BAZEL_COMMAND
  BAZEL_VERSION
  BAZEL_STARTUP_OPTIONS
  BAZEL_STARTUP_OPTIONS_CI
  BAZEL_BUILD_OPTIONS
  BAZEL_BUILD_OPTIONS_CI
  BAZEL_TEST_OPTIONS
  BAZEL_TEST_OPTIONS_CI
  ==================================== >DASHBOARD_
  GIT_COMMIT
  ACTUAL_GIT_COMMIT
  ====================================
  ")

if(PACKAGE)
  message(STATUS "Creating package output directory...")
  set(DASHBOARD_PACKAGE_OUTPUT_DIRECTORY "/opt/drake")
  execute_process(COMMAND sudo "${CMAKE_COMMAND}" -E make_directory "${DASHBOARD_PACKAGE_OUTPUT_DIRECTORY}"
    RESULT_VARIABLE MAKE_DIRECTORY_RESULT_VARIABLE)
  if(NOT MAKE_DIRECTORY_RESULT_VARIABLE EQUAL 0)
    fatal("creation of package output directory was not successful")
  endif()
  list(APPEND DASHBOARD_TEMPORARY_FILES DASHBOARD_PACKAGE_OUTPUT_DIRECTORY)
  execute_process(COMMAND sudo chmod 0777 "${DASHBOARD_PACKAGE_OUTPUT_DIRECTORY}"
    RESULT_VARIABLE CHMOD_RESULT_VARIABLE)
  if(NOT CHMOD_RESULT_VARIABLE EQUAL 0)
    fatal("setting permissions on package output directory was not successful")
  endif()
endif()

# Run the build
execute_step(bazel build)

if(PACKAGE AND NOT DISTRIBUTION STREQUAL "xenial")
  execute_process(COMMAND "${DASHBOARD_BAZEL_COMMAND}" ${DASHBOARD_BAZEL_STARTUP_OPTIONS_CI} clean --expunge)
  file(REMOVE_RECURSE "${CTEST_BINARY_DIRECTORY}")
  file(MAKE_DIRECTORY "${CTEST_BINARY_DIRECTORY}")

  string(REPLACE "packaging" "python3-packaging" DASHBOARD_JOB_NAME "${DASHBOARD_JOB_NAME}")
  set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --config=python3")

  report_configuration("
  ==================================== >DASHBOARD_
  BAZEL_COMMAND
  BAZEL_VERSION
  BAZEL_STARTUP_OPTIONS
  BAZEL_STARTUP_OPTIONS_CI
  BAZEL_BUILD_OPTIONS
  BAZEL_BUILD_OPTIONS_CI
  BAZEL_TEST_OPTIONS
  BAZEL_TEST_OPTIONS_CI
  ====================================
  ")

  execute_step(bazel build)
endif()

# Determine build result
if(NOT DASHBOARD_FAILURE AND NOT DASHBOARD_UNSTABLE)
  set(DASHBOARD_MESSAGE "SUCCESS")
endif()

# Build and publish documentation, if requested, and if build succeeded.
if(DOCUMENTATION)
  execute_step(bazel build-documentation)
  if(DOCUMENTATION STREQUAL "publish")
    execute_step(bazel publish-documentation)
  endif()
endif()

if(MIRROR_TO_S3 STREQUAL "publish")
  execute_step(bazel mirror-to-s3)
endif()

if(PACKAGE)
  execute_step(bazel create-package-archive)
  execute_step(bazel upload-package-archive)
endif()

# Report Bazel command without CI-specific options
execute_step(bazel report-bazel-command)

