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
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/_wheel_$ENV{USER}")

set(DASHBOARD_BUILD_EVENT_JSON_FILE "${CTEST_BINARY_DIRECTORY}/BUILD.JSON")

if(APPLE)
  set(DASHBOARD_EXPERIMENTAL_SCALE_TIMEOUTS 2.0)
else()
  set(DASHBOARD_EXPERIMENTAL_SCALE_TIMEOUTS 1.0)
endif()

if(VERBOSE)
  set(DASHBOARD_SUBCOMMANDS "yes")
else()
  set(DASHBOARD_SUBCOMMANDS "no")
endif()

include(${DASHBOARD_DRIVER_DIR}/configurations/aws.cmake)

string(TIMESTAMP DATE "%Y.%m.%d")
string(TIMESTAMP TIME "%H.%M.%S")
execute_process(COMMAND "${CTEST_GIT_COMMAND}" rev-parse --short=8 HEAD
  WORKING_DIRECTORY "${CTEST_SOURCE_DIRECTORY}"
  RESULT_VARIABLE GIT_REV_PARSE_RESULT_VARIABLE
  OUTPUT_VARIABLE GIT_REV_PARSE_OUTPUT_VARIABLE
  OUTPUT_STRIP_TRAILING_WHITESPACE)
if(GIT_REV_PARSE_RESULT_VARIABLE EQUAL 0)
  set(DASHBOARD_DRAKE_VERSION
    "0.0.${DATE}.${TIME}+git${GIT_REV_PARSE_OUTPUT_VARIABLE}")
else()
  set(DASHBOARD_DRAKE_VERSION "0.0.${DATE}.${TIME}+unknown")
endif()
string(REGEX REPLACE "[.]0([0-9])" ".\\1"
  DASHBOARD_DRAKE_VERSION "${DASHBOARD_DRAKE_VERSION}")

# Report build configuration
report_configuration("
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
  GIT_COMMIT
  ACTUAL_GIT_COMMIT
  DRAKE_VERSION
  ==================================== >DASHBOARD_
  REMOTE_CACHE_KEY_VERSION
  REMOTE_CACHE_KEY
  ====================================
  ")

if(DEFINED ENV{WHEEL_OUTPUT_DIRECTORY})
  set(DASHBOARD_WHEEL_OUTPUT_DIRECTORY "$ENV{WHEEL_OUTPUT_DIRECTORY}")
else()
  set(DASHBOARD_WHEEL_OUTPUT_DIRECTORY "/opt/drake/wheelhouse")
  mkdir("${DASHBOARD_WHEEL_OUTPUT_DIRECTORY}" 1777 "wheel output directory")
  list(APPEND DASHBOARD_TEMPORARY_FILES DASHBOARD_WHEEL_OUTPUT_DIRECTORY)
endif()

if(APPLE)
  # Ensure the build can write to /opt and /opt/drake; the latter might have
  # been created as a parent of DASHBOARD_WHEEL_OUTPUT_DIRECTORY and needs to
  # be writable by not-root
  mkdir(/opt/drake 1777 "drake install directory")
  chmod(/opt 1777 /opt)
endif()

set(BUILD_ARGS
  run //tools/wheel:builder --
  -t -o "${DASHBOARD_WHEEL_OUTPUT_DIRECTORY}" "${DASHBOARD_DRAKE_VERSION}")

if(APPLE)
    # Run the build, including tests (includes provisioning)
    execute_step(wheel build-and-test)
else()
    # Prepare build host
    execute_step(wheel provision)

    # Run the build, including tests
    execute_step(wheel build-and-test)
endif()

# Determine build result
if(NOT DASHBOARD_FAILURE AND NOT DASHBOARD_UNSTABLE)
  set(DASHBOARD_MESSAGE "SUCCESS")
endif()
