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

# Jenkins passes down an incorrect value of JAVA_HOME from controller to agent
# for some inexplicable reason.
unset(ENV{JAVA_HOME})

set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}")
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/_bazel_$ENV{USER}")

# Set bazel options
set(DASHBOARD_BAZEL_STARTUP_OPTIONS)
set(DASHBOARD_OUTPUT_USER_ROOT "${CTEST_BINARY_DIRECTORY}")

# Extract the version. Usually of the form x.y.z-*.
set(VERSION_ARGS "${DASHBOARD_BAZEL_STARTUP_OPTIONS} --output_user_root=${DASHBOARD_OUTPUT_USER_ROOT} version")
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

set(DASHBOARD_BUILD_EVENT_JSON_FILE "${CTEST_BINARY_DIRECTORY}/BUILD.JSON")

if(COMPILER STREQUAL "clang")
  set(DASHBOARD_COPT "-fcolor-diagnostics")
elseif(COMPILER STREQUAL "gcc")
  set(DASHBOARD_COPT "-fdiagnostics-color=always")
else()
  set(DASHBOARD_COPT)
endif()

if(APPLE)
  set(DASHBOARD_EXPERIMENTAL_SCALE_TIMEOUTS 2.0)
else()
  set(DASHBOARD_EXPERIMENTAL_SCALE_TIMEOUTS 1.0)
endif()

if(DASHBOARD_PROCESSOR_COUNT GREATER 1)
  # NOTE: linux clang address sanitizer builds experience spurious errors, see
  # https://github.com/RobotLocomotion/drake/issues/17560
  if(NOT APPLE AND COMPILER STREQUAL "clang" AND DASHBOARD_JOB_NAME MATCHES "address-sanitizer")
    if(DASHBOARD_PROCESSOR_COUNT GREATER 2)
      math(EXPR DASHBOARD_JOBS "7 * ${DASHBOARD_PROCESSOR_COUNT} / 16")
    else()
      set(DASHBOARD_JOBS 1)
    endif()
  else()
    math(EXPR DASHBOARD_JOBS "7 * ${DASHBOARD_PROCESSOR_COUNT} / 8")
  endif()
else()
  set(DASHBOARD_JOBS 1)
endif()

if(VERBOSE)
  set(DASHBOARD_SUBCOMMANDS "yes")
else()
  set(DASHBOARD_SUBCOMMANDS "no")
endif()

include(${DASHBOARD_DRIVER_DIR}/configurations/cache.cmake)

if(REMOTE_CACHE)
  set(DASHBOARD_REMOTE_ACCEPT_CACHED "yes")
  set(DASHBOARD_REMOTE_UPLOAD_LOCAL_RESULTS "yes")
  if(DASHBOARD_TRACK STREQUAL "Nightly")
    set(DASHBOARD_REMOTE_ACCEPT_CACHED "no")
  elseif(DASHBOARD_TRACK STREQUAL "Continuous" AND DEBUG)
    set(DASHBOARD_REMOTE_ACCEPT_CACHED "no")
  elseif(DASHBOARD_TRACK STREQUAL "Experimental")
    set(DASHBOARD_REMOTE_UPLOAD_LOCAL_RESULTS "no")
  endif()
  if(DEBUG)
    set(DASHBOARD_REMOTE_MAX_CONNECTIONS 16)
    set(DASHBOARD_REMOTE_RETRIES 1)
    set(DASHBOARD_REMOTE_TIMEOUT 240)
  else()
    set(DASHBOARD_REMOTE_MAX_CONNECTIONS 64)
    set(DASHBOARD_REMOTE_RETRIES 4)
    set(DASHBOARD_REMOTE_TIMEOUT 120)
  endif()
  configure_file("${DASHBOARD_TOOLS_DIR}/remote.bazelrc.in"
    "${CTEST_SOURCE_DIRECTORY}/remote.bazelrc" @ONLY
  )
endif()

set(DASHBOARD_BAZEL_BUILD_OPTIONS "--config=${COMPILER} --compilation_mode")

if(DEBUG)
  set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS}=dbg")
else()
  set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS}=opt")
endif()

include(${DASHBOARD_DRIVER_DIR}/configurations/aws.cmake)
include(${DASHBOARD_DRIVER_DIR}/configurations/gurobi.cmake)
include(${DASHBOARD_DRIVER_DIR}/configurations/mosek.cmake)
include(${DASHBOARD_DRIVER_DIR}/configurations/snopt.cmake)

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
    set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --config=snopt")
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
  if(MEMCHECK STREQUAL "address-sanitizer")
    set(MEMCHECK_BAZEL_CONFIG "asan")
    if(DASHBOARD_TEST_TAG_FILTERS)
      list(APPEND DASHBOARD_TEST_TAG_FILTERS "-no_asan" "-no_lsan")
    endif()
  elseif(MEMCHECK STREQUAL "leak-sanitizer")
    set(MEMCHECK_BAZEL_CONFIG "lsan")
    if(DASHBOARD_TEST_TAG_FILTERS)
      list(APPEND DASHBOARD_TEST_TAG_FILTERS "-no_lsan")
    endif()
  elseif(MEMCHECK STREQUAL "thread-sanitizer")
    set(MEMCHECK_BAZEL_CONFIG "tsan")
    if(DASHBOARD_TEST_TAG_FILTERS)
      list(APPEND DASHBOARD_TEST_TAG_FILTERS "-no_tsan")
    endif()
  elseif(MEMCHECK STREQUAL "undefined-behavior-sanitizer")
    set(MEMCHECK_BAZEL_CONFIG "ubsan")
    if(DASHBOARD_TEST_TAG_FILTERS)
      list(APPEND DASHBOARD_TEST_TAG_FILTERS "-no_ubsan")
    endif()
  elseif(MEMCHECK STREQUAL "valgrind-drd")
    set(MEMCHECK_BAZEL_CONFIG "drd")
    if(DASHBOARD_TEST_TAG_FILTERS)
      list(APPEND DASHBOARD_TEST_TAG_FILTERS "-no_drd,-no_valgrind_tools")
    endif()
  elseif(MEMCHECK STREQUAL "valgrind-helgrind")
    set(MEMCHECK_BAZEL_CONFIG "helgrind")
    if(DASHBOARD_TEST_TAG_FILTERS)
      list(APPEND DASHBOARD_TEST_TAG_FILTERS "-no_helgrind,-no_valgrind_tools")
    endif()
  elseif(MEMCHECK STREQUAL "valgrind-memcheck")
    set(MEMCHECK_BAZEL_CONFIG "memcheck")
    if(DASHBOARD_TEST_TAG_FILTERS)
      list(APPEND DASHBOARD_TEST_TAG_FILTERS "-no_memcheck,-no_valgrind_tools")
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

set(DASHBOARD_BAZEL_TEST_OPTIONS)

if(APPLE)
  set(DASHBOARD_BAZEL_TEST_OPTIONS "${DASHBOARD_BAZEL_TEST_OPTIONS} --test_timeout=300,1500,4500,-1")
endif()

configure_file("${DASHBOARD_TOOLS_DIR}/user.bazelrc.in" "${CTEST_SOURCE_DIRECTORY}/user.bazelrc" @ONLY)

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
  UNIX_DISTRIBUTION_CODE_NAME
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
  BAZEL_BUILD_OPTIONS
  BAZEL_TEST_OPTIONS
  ==================================== >DASHBOARD_
  GIT_COMMIT
  ACTUAL_GIT_COMMIT
  ==================================== >DASHBOARD_
  ${COMPILER_UPPER}_CACHE_VERSION(CC_CACHE_VERSION)
  GFORTRAN_CACHE_VERSION
  JAVA_CACHE_VERSION
  OS_CACHE_VERSION
  PYTHON_CACHE_VERSION
  ==================================== >DASHBOARD_
  REMOTE_CACHE_KEY_VERSION
  REMOTE_CACHE_KEY
  ====================================
  ")

if(PACKAGE)
  set(DASHBOARD_PACKAGE_OUTPUT_DIRECTORY "/opt/drake")
  mkdir("${DASHBOARD_PACKAGE_OUTPUT_DIRECTORY}" 1777
    "package output directory")
  list(APPEND DASHBOARD_TEMPORARY_FILES DASHBOARD_PACKAGE_OUTPUT_DIRECTORY)
endif()

# Run the build
execute_step(bazel build)

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
  if(NOT APPLE)
    execute_step(bazel create-debian-archive)
  endif()
  if(PACKAGE STREQUAL "publish")
    execute_step(bazel upload-package-archive)
    if(NOT APPLE)
      execute_step(bazel upload-debian-archive)
    endif()
  endif()
  if(DOCKER)
    execute_step(bazel build-docker-image)
    if(DOCKER STREQUAL "publish")
      execute_step(bazel push-docker-image)
    endif()
  endif()
  if(DISTRIBUTION STREQUAL "focal" AND DASHBOARD_TRACK STREQUAL "Nightly")
    execute_step(bazel push-nightly-release-branch)
  endif()
endif()

# Report Bazel command without CI-specific options
execute_step(bazel report-bazel-command)

