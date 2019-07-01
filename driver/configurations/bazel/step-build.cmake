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

# CTEST_SOURCE_DIRECTORY and CTEST_BINARY_DIRECTORY are set in bazel.cmake.

notice("CTest Status: RUNNING BAZEL")

begin_stage(
  PROJECT_NAME "Drake"
  BUILD_NAME "${DASHBOARD_JOB_NAME}")

ctest_update(SOURCE "${CTEST_SOURCE_DIRECTORY}"
  RETURN_VALUE DASHBOARD_UPDATE_RETURN_VALUE
  CAPTURE_CMAKE_ERROR DASHBOARD_UPDATE_CAPTURE_CMAKE_ERROR
  QUIET)
if(DASHBOARD_UPDATE_RETURN_VALUE EQUAL -1 OR DASHBOARD_UPDATE_CAPTURE_CMAKE_ERROR EQUAL -1)
  message(WARNING "*** CTest update step was not successful")
endif()

if(DASHBOARD_ACTUAL_GIT_COMMIT)
  find_program(DASHBOARD_SED_COMMAND NAMES "sed")
  if(DASHBOARD_SED_COMMAND)
    file(STRINGS "${CTEST_BINARY_DIRECTORY}/Testing/TAG" DASHBOARD_TAG)
    list(GET DASHBOARD_TAG 0 DASHBOARD_BUILD_STAMP)
    if(APPLE)
      set(DASHBOARD_SED_INPLACE "-i .bak")
    else()
      set(DASHBOARD_SED_INPLACE "-i.bak")
    endif()
    execute_process(COMMAND "${DASHBOARD_SED_COMMAND}" "${DASHBOARD_SED_INPLACE}" "s/${DASHBOARD_GIT_COMMIT}/${DASHBOARD_ACTUAL_GIT_COMMIT}/g" "${CTEST_BINARY_DIRECTORY}/Testing/${DASHBOARD_BUILD_STAMP}/Update.xml"
      RESULT_VARIABLE SED_RESULT_VARIABLE)
    if(NOT SED_RESULT_VARIABLE EQUAL 0)
      message(WARNING "*** sed substitution was NOT successful")
    endif()
  else()
    message(WARNING "*** sed was NOT found")
  endif()
endif()

if(MIRROR_TO_S3)
  set(BUILD_ARGS
    "${DASHBOARD_BAZEL_STARTUP_OPTIONS} build ${DASHBOARD_BAZEL_BUILD_OPTIONS} //tools/workspace:mirror_to_s3")
elseif(PACKAGE)
  set(BUILD_ARGS
    "${DASHBOARD_BAZEL_STARTUP_OPTIONS} run ${DASHBOARD_BAZEL_BUILD_OPTIONS} //:install -- /opt/drake")
else()
  set(BUILD_ARGS
    "${DASHBOARD_BAZEL_STARTUP_OPTIONS} test ${DASHBOARD_BAZEL_BUILD_OPTIONS} ${DASHBOARD_BAZEL_TEST_OPTIONS} ...")
endif()

set(CTEST_CUSTOM_ERROR_EXCEPTION "^WARNING: " ":[0-9]+: Failure$")
set(CTEST_CUSTOM_ERROR_MATCH "^ERROR: " "^FAIL: " "^TIMEOUT: ")
set(CTEST_CUSTOM_WARNING_MATCH "^WARNING: ")

if(EXISTS "${CTEST_SOURCE_DIRECTORY}/CTestCustom.cmake.in")
  execute_process(COMMAND "${CMAKE_COMMAND}" -E copy
    "${CTEST_SOURCE_DIRECTORY}/CTestCustom.cmake.in"
    "${CTEST_BINARY_DIRECTORY}/CTestCustom.cmake")
  ctest_read_custom_files("${CTEST_BINARY_DIRECTORY}")
endif()

if(NOT PROVISION)
  if(DASHBOARD_UNIX_DISTRIBUTION STREQUAL "Apple")
    set(USER_ENVIRONMENT_PROVISION_DIR "mac")
  else()
    string(TOLOWER "${DASHBOARD_UNIX_DISTRIBUTION}" USER_ENVIRONMENT_PROVISION_DIR)
  endif()
  set(USER_ENVIRONMENT_PROVISION_SCRIPT
    "${DASHBOARD_SOURCE_DIRECTORY}/setup/${USER_ENVIRONMENT_PROVISION_DIR}/source_distribution/install_prereqs_user_environment.sh")
  message(STATUS "Executing user environment provisioning script...")
  execute_process(COMMAND bash "-c" "${USER_ENVIRONMENT_PROVISION_SCRIPT}"
    RESULT_VARIABLE INSTALL_PREREQS_USER_ENVIRONMENT_RESULT_VARIABLE)
  if(NOT INSTALL_PREREQS_USER_ENVIRONMENT_RESULT_VARIABLE EQUAL 0)
    fatal("user environment provisioning script did not complete successfully")
  endif()
endif()

separate_arguments(BUILD_ARGS_LIST UNIX_COMMAND "${BUILD_ARGS}")
execute_process(COMMAND ${DASHBOARD_BAZEL_COMMAND} ${BUILD_ARGS_LIST}
  WORKING_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}"
  RESULT_VARIABLE DASHBOARD_BUILD_RETURN_VALUE)

set(DASHBOARD_SUBMIT ON)

# https://bazel.build/blog/2016/01/27/continuous-integration.html
if(DASHBOARD_BUILD_RETURN_VALUE EQUAL 1)
  # Build failed.
  set(DASHBOARD_FAILURE ON)
  list(APPEND DASHBOARD_FAILURES "BAZEL BUILD")
elseif(DASHBOARD_BUILD_RETURN_VALUE EQUAL 2)
  # Command line problem, bad or illegal flags or command combination, or bad
  # environment variables. Your command line must be modified.
  set(DASHBOARD_FAILURE ON)
  list(APPEND DASHBOARD_FAILURES "BAZEL COMMAND OR ENVIRONMENT")
elseif(DASHBOARD_BUILD_RETURN_VALUE EQUAL 3)
  # Build OK, but some tests failed or timed out.
  set(DASHBOARD_UNSTABLE ON)
  list(APPEND DASHBOARD_UNSTABLES "BAZEL TEST")
elseif(DASHBOARD_BUILD_RETURN_VALUE EQUAL 4)
  # Build successful, but no tests were found even though testing was requested.
  set(DASHBOARD_UNSTABLE ON)
  list(APPEND DASHBOARD_UNSTABLES "BAZEL TEST")
elseif(DASHBOARD_BUILD_RETURN_VALUE EQUAL 8)
  # Build interrupted, but we terminated with an orderly shutdown.
  set(DASHBOARD_FAILURE ON)
  set(DASHBOARD_SUBMIT OFF)
  list(APPEND DASHBOARD_FAILURES "BAZEL BUILD OR TEST (BUILD INTERRUPTED)")
  message("*** Not submitting to CDash because build was interrupted")
elseif(NOT DASHBOARD_BUILD_RETURN_VALUE EQUAL 0)
  set(DASHBOARD_FAILURE ON)
  list(APPEND DASHBOARD_FAILURES "BAZEL BUILD OR TEST (UNKNOWN ERROR)")
endif()

if(DASHBOARD_SUBMIT)
  ctest_submit(PARTS Update
    RETRY_COUNT 4
    RETRY_DELAY 15
    RETURN_VALUE DASHBOARD_SUBMIT_UPDATE_RETURN_VALUE
    CAPTURE_CMAKE_ERROR DASHBOARD_SUBMIT_UPDATE_CAPTURE_CMAKE_ERROR
    QUIET)
  if(NOT DASHBOARD_SUBMIT_UPDATE_RETURN_VALUE EQUAL 0 OR DASHBOARD_SUBMIT_UPDATE_CAPTURE_CMAKE_ERROR EQUAL -1)
    message(WARNING "*** CTest submit update part was not successful")
  endif()

  ctest_submit(PARTS Upload
    RETRY_COUNT 4
    RETRY_DELAY 15
    RETURN_VALUE DASHBOARD_SUBMIT_UPLOAD_RETURN_VALUE
    CAPTURE_CMAKE_ERROR DASHBOARD_SUBMIT_UPLOAD_CAPTURE_CMAKE_ERROR
    QUIET)
  if(NOT DASHBOARD_SUBMIT_UPLOAD_RETURN_VALUE EQUAL 0 OR DASHBOARD_SUBMIT_UPLOAD_CAPTURE_CMAKE_ERROR EQUAL -1)
    message(WARNING "*** CTest submit upload part was not successful")
  endif()

  ctest_submit(CDASH_UPLOAD "${DASHBOARD_BUILD_EVENT_JSON_FILE}"
    CDASH_UPLOAD_TYPE BazelJSON
    RETRY_COUNT 4
    RETRY_DELAY 15
    RETURN_VALUE DASHBOARD_SUBMIT_BAZEL_JSON_RETURN_VALUE
    CAPTURE_CMAKE_ERROR DASHBOARD_SUBMIT_BAZEL_JSON_CAPTURE_CMAKE_ERROR
    QUIET)
  if(NOT DASHBOARD_SUBMIT_BAZEL_JSON_RETURN_VALUE EQUAL 0 OR DASHBOARD_SUBMIT_BAZEL_JSON_CAPTURE_CMAKE_ERROR EQUAL -1)
    message(WARNING "*** CTest submit CDash upload Bazel JSON was not successful")
  endif()
endif()

if(COVERAGE)
  set(KCOV_MERGED "${DASHBOARD_SOURCE_DIRECTORY}/bazel-kcov/kcov-merged")
  execute_process(COMMAND "${CMAKE_COMMAND}" -E copy "${KCOV_MERGED}/cobertura.xml" "${KCOV_MERGED}/coverage.xml")
  set(ENV{COBERTURADIR} "${KCOV_MERGED}")
  ctest_coverage(RETURN_VALUE DASHBOARD_COVERAGE_RETURN_VALUE
    CAPTURE_CMAKE_ERROR DASHBOARD_COVERAGE_CAPTURE_CMAKE_ERROR
    QUIET)
  if(NOT DASHBOARD_COVERAGE_RETURN_VALUE EQUAL 0 OR DASHBOARD_COVERAGE_CAPTURE_CMAKE_ERROR EQUAL -1)
    message(WARNING "*** CTest coverage step was not successful")
  endif()
  if(DASHBOARD_SUBMIT)
    ctest_submit(PARTS Coverage
      RETRY_COUNT 4
      RETRY_DELAY 15
      RETURN_VALUE DASHBOARD_SUBMIT_COVERAGE_RETURN_VALUE
      CAPTURE_CMAKE_ERROR DASHBOARD_SUBMIT_COVERAGE_CAPTURE_CMAKE_ERROR
      QUIET)
    if(NOT DASHBOARD_SUBMIT_COVERAGE_RETURN_VALUE EQUAL 0 OR DASHBOARD_SUBMIT_COVERAGE_CAPTURE_CMAKE_ERROR EQUAL -1)
      message(WARNING "*** CTest submit coverage part was not successful")
    endif()
  endif()
endif()

if(DASHBOARD_SUBMIT)
  ctest_submit(PARTS Done
    RETRY_COUNT 4
    RETRY_DELAY 15
    RETURN_VALUE DASHBOARD_SUBMIT_DONE_RETURN_VALUE
    CAPTURE_CMAKE_ERROR DASHBOARD_SUBMIT_DONE_CAPTURE_CMAKE_ERROR
    QUIET)
  if(NOT DASHBOARD_SUBMIT_DONE_RETURN_VALUE EQUAL 0 OR DASHBOARD_SUBMIT_DONE_CAPTURE_CMAKE_ERROR EQUAL -1)
    message(WARNING "*** CTest submit done part was not successful")
  endif()
endif()
