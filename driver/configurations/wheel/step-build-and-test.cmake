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

# CTEST_SOURCE_DIRECTORY and CTEST_BINARY_DIRECTORY are set in wheel.cmake.

notice("CTest Status: RUNNING WHEEL")

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

if(EXISTS "${CTEST_SOURCE_DIRECTORY}/CTestCustom.cmake.in")
  execute_process(COMMAND "${CMAKE_COMMAND}" -E copy
    "${CTEST_SOURCE_DIRECTORY}/CTestCustom.cmake.in"
    "${CTEST_BINARY_DIRECTORY}/CTestCustom.cmake")
  ctest_read_custom_files("${CTEST_BINARY_DIRECTORY}")
endif()

execute_process(COMMAND ${DASHBOARD_PYTHON_COMMAND} ${BUILD_ARGS}
  WORKING_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}"
  RESULT_VARIABLE DASHBOARD_BUILD_RETURN_VALUE)

set(DASHBOARD_SUBMIT ON)

# https://bazel.build/blog/2016/01/27/continuous-integration.html
if(NOT DASHBOARD_BUILD_RETURN_VALUE EQUAL 0)
  # Build failed.
  set(DASHBOARD_FAILURE ON)
  list(APPEND DASHBOARD_FAILURES "WHEEL BUILD")
endif()

if(DASHBOARD_SUBMIT)
  ctest_submit(PARTS Update
    BUILD_ID DASHBOARD_CDASH_BUILD_ID
    RETRY_COUNT 4
    RETRY_DELAY 15
    RETURN_VALUE DASHBOARD_SUBMIT_UPDATE_RETURN_VALUE
    CAPTURE_CMAKE_ERROR DASHBOARD_SUBMIT_UPDATE_CAPTURE_CMAKE_ERROR
    QUIET)
  if(NOT DASHBOARD_SUBMIT_UPDATE_RETURN_VALUE EQUAL 0 OR DASHBOARD_SUBMIT_UPDATE_CAPTURE_CMAKE_ERROR EQUAL -1)
    message(WARNING "*** CTest submit update part was not successful")
  endif()

  if(DASHBOARD_CDASH_BUILD_ID)
    message(STATUS "Submitted to CDash with build id ${DASHBOARD_CDASH_BUILD_ID}")
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
