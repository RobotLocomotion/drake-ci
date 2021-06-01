# -*- mode: cmake; -*-
# vi: set ft=cmake:

# BSD 3-Clause License
#
# Copyright (c) 2017, Massachusetts Institute of Technology.
# Copyright (c) 2017, Toyota Research Institute.
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
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/_cmake_$ENV{USER}")
set(DASHBOARD_INSTALL_PREFIX "${CTEST_BINARY_DIRECTORY}/install")

set(DASHBOARD_CXX_FLAGS)
if(DEFINED ENV{TERM})
  if(COMPILER STREQUAL "clang")
    set(DASHBOARD_CXX_FLAGS "-fcolor-diagnostics ${DASHBOARD_CXX_FLAGS}")
  elseif(COMPILER STREQUAL "gcc")
    set(DASHBOARD_CXX_FLAGS "-fdiagnostics-color=always ${DASHBOARD_CXX_FLAGS}")
  endif()
  set(DASHBOARD_COLOR_MAKEFILE ON)
else()
  set(DASHBOARD_COLOR_MAKEFILE OFF)
endif()

set(CTEST_CONFIGURATION_TYPE "${DASHBOARD_CONFIGURATION_TYPE}")
set(CTEST_TEST_TIMEOUT 300)

file(REMOVE_RECURSE "${CTEST_BINARY_DIRECTORY}")
file(MAKE_DIRECTORY "${CTEST_BINARY_DIRECTORY}")
file(REMOVE_RECURSE "${DASHBOARD_INSTALL_PREFIX}")

include(${DASHBOARD_DRIVER_DIR}/configurations/aws.cmake)
include(${DASHBOARD_DRIVER_DIR}/configurations/gurobi.cmake)
include(${DASHBOARD_DRIVER_DIR}/configurations/mosek.cmake)
include(${DASHBOARD_DRIVER_DIR}/configurations/snopt.cmake)

if(GUROBI)
  set(DASHBOARD_WITH_GUROBI ON)
else()
  set(DASHBOARD_WITH_GUROBI OFF)
endif()

if(MOSEK)
  set(DASHBOARD_WITH_MOSEK ON)
else()
  set(DASHBOARD_WITH_MOSEK OFF)
endif()

if(SNOPT)
  set(DASHBOARD_WITH_ROBOTLOCOMOTION_SNOPT ${SNOPT})
else()
  set(DASHBOARD_WITH_ROBOTLOCOMOTION_SNOPT OFF)
endif()

if(VERBOSE)
  set(DASHBOARD_VERBOSE_MAKEFILE ON)
else()
  set(DASHBOARD_VERBOSE_MAKEFILE OFF)
endif()

cache_flag(COLOR_MAKEFILE BOOL)
cache_flag(CXX_FLAGS STRING)
cache_flag(INSTALL_PREFIX PATH)
cache_flag(VERBOSE_MAKEFILE BOOL)
cache_append(WITH_GUROBI BOOL ${DASHBOARD_WITH_GUROBI})
cache_append(WITH_MOSEK BOOL ${DASHBOARD_WITH_MOSEK})
cache_append(WITH_ROBOTLOCOMOTION_SNOPT STRING ${DASHBOARD_WITH_ROBOTLOCOMOTION_SNOPT})

file(COPY "${DASHBOARD_CI_DIR}/user.bazelrc"
  DESTINATION "${DASHBOARD_SOURCE_DIRECTORY}")

file(APPEND "${DASHBOARD_SOURCE_DIRECTORY}/user.bazelrc"
  "startup --output_user_root=${DASHBOARD_WORKSPACE}/_bazel_$ENV{USER}\n")

include(${DASHBOARD_DRIVER_DIR}/configurations/cache.cmake)

if(REMOTE_CACHE)
  file(APPEND "${DASHBOARD_SOURCE_DIRECTORY}/user.bazelrc"
    "build --experimental_guard_against_concurrent_changes=yes\n"
    "build --remote_cache=${DASHBOARD_REMOTE_CACHE}\n"
    "build --remote_local_fallback=yes\n"
    "build --remote_max_connections=64\n"
    "build --remote_retries=4\n"
    "build --remote_timeout=120\n")
  if(DASHBOARD_TRACK STREQUAL "Nightly")
    file(APPEND "${DASHBOARD_SOURCE_DIRECTORY}/user.bazelrc"
      "build --remote_accept_cached=no\n"
      "build --remote_upload_local_results=yes\n")
  elseif(DASHBOARD_TRACK STREQUAL "Experimental")
    file(APPEND "${DASHBOARD_SOURCE_DIRECTORY}/user.bazelrc"
      "build --remote_accept_cached=yes\n"
      "build --remote_upload_local_results=no\n")
  else()
     file(APPEND "${DASHBOARD_SOURCE_DIRECTORY}/user.bazelrc"
      "build --remote_accept_cached=yes\n"
      "build --remote_upload_local_results=yes\n")
  endif()
endif()

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
  ==================================== >DASHBOARD_ <CMAKE_
  COLOR_MAKEFILE
  CXX_FLAGS
  INSTALL_PREFIX
  VERBOSE_MAKEFILE
  ====================================
  CTEST_BUILD_NAME(DASHBOARD_JOB_NAME)
  CTEST_BINARY_DIRECTORY
  CTEST_BUILD_FLAGS
  CTEST_CHANGE_ID
  CTEST_CMAKE_GENERATOR
  CTEST_CONFIGURATION_TYPE
  CTEST_GIT_COMMAND
  CTEST_SITE
  CTEST_SOURCE_DIRECTORY
  CTEST_TEST_TIMEOUT
  CTEST_UPDATE_COMMAND
  CTEST_UPDATE_VERSION_ONLY
  CTEST_UPDATE_VERSION_OVERRIDE
  CTEST_USE_LAUNCHERS
  ==================================== >DASHBOARD_
  WITH_GUROBI
  WITH_MOSEK
  WITH_ROBOTLOCOMOTION_SNOPT
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

execute_step(cmake build)

if(NOT DASHBOARD_FAILURE)
  format_plural(DASHBOARD_MESSAGE
    ZERO "SUCCESS"
    ONE "SUCCESS BUT WITH 1 BUILD WARNING"
    MANY "SUCCESS BUT WITH # BUILD WARNINGS"
    ${DASHBOARD_BUILD_NUMBER_WARNINGS})
endif()

