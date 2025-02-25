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

# Set build locations and ensure there are no leftover artifacts
set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}")
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/_cmake_$ENV{USER}")
set(DASHBOARD_INSTALL_PREFIX "/opt/drake")

file(REMOVE_RECURSE "${CTEST_BINARY_DIRECTORY}")
file(MAKE_DIRECTORY "${CTEST_BINARY_DIRECTORY}")
file(REMOVE_RECURSE "${DASHBOARD_INSTALL_PREFIX}")

# Jenkins passes down an incorrect value of JAVA_HOME from controller to agent
# for some inexplicable reason.
unset(ENV{JAVA_HOME})

# Pass along compiler
set(ENV{CC} "${DASHBOARD_CC_COMMAND}")
set(ENV{CXX} "${DASHBOARD_CXX_COMMAND}")

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

# Set up build configuration
set(CTEST_CONFIGURATION_TYPE "${DASHBOARD_CONFIGURATION_TYPE}")
set(CTEST_TEST_TIMEOUT 300)

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

if(OPENMP)
  set(DASHBOARD_WITH_OPENMP ON)
else()
  set(DASHBOARD_WITH_OPENMP OFF)
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
cache_append(WITH_OPENMP BOOL ${DASHBOARD_WITH_OPENMP})
cache_append(DRAKE_CI_ENABLE_PACKAGING BOOL ${PACKAGE})

file(COPY "${DASHBOARD_CI_DIR}/user.bazelrc"
  DESTINATION "${DASHBOARD_SOURCE_DIRECTORY}")

file(APPEND "${DASHBOARD_SOURCE_DIRECTORY}/user.bazelrc"
  "startup --output_user_root=${DASHBOARD_WORKSPACE}/_bazel_$ENV{USER}\n")

# Set up cache
include(${DASHBOARD_DRIVER_DIR}/configurations/cache.cmake)

if(REMOTE_CACHE)
  file(APPEND "${DASHBOARD_SOURCE_DIRECTORY}/user.bazelrc"
    "build --experimental_guard_against_concurrent_changes=yes\n"
    "build --remote_download_outputs=all\n"
    "build --remote_cache=${DASHBOARD_REMOTE_CACHE}\n"
    "build --remote_local_fallback=yes\n"
    "build --remote_max_connections=64\n"
    "build --remote_retries=4\n"
    "build --remote_timeout=120\n"
    "build --remote_accept_cached=${DASHBOARD_REMOTE_ACCEPT_CACHED}\n"
    "build --remote_upload_local_results=${DASHBOARD_REMOTE_UPLOAD_LOCAL_RESULTS}\n")
endif()

# Set package version
execute_step(common set-package-version)
cache_append(DRAKE_VERSION_OVERRIDE STRING "${DASHBOARD_DRAKE_VERSION}")

# Report build configuration
execute_step(common get-bazel-version)

report_configuration("
  ==================================== ENV
  CC
  CXX
  DISPLAY
  GUROBI_PATH
  SNOPT_PATH
  TERM
  ==================================== >DASHBOARD_
  CC_COMMAND
  CC_VERSION_STRING
  CXX_COMMAND
  CXX_VERSION_STRING
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
  ====================================
  PACKAGE
  ==================================== >DASHBOARD_
  WITH_GUROBI
  WITH_MOSEK
  WITH_ROBOTLOCOMOTION_SNOPT
  WITH_OPENMP
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
  BAZEL_COMMAND
  BAZEL_VERSION
  ==================================== >DASHBOARD_
  REMOTE_CACHE_KEY_VERSION
  REMOTE_CACHE_KEY
  ====================================
  ")

if(PACKAGE)
  set(DASHBOARD_PACKAGE_OUTPUT_DIRECTORY "${DASHBOARD_INSTALL_PREFIX}")
  mkdir("${DASHBOARD_PACKAGE_OUTPUT_DIRECTORY}" 1777
    "package output directory")
  list(APPEND DASHBOARD_TEMPORARY_FILES DASHBOARD_PACKAGE_OUTPUT_DIRECTORY)
endif()

# Run the build
execute_step(cmake build)

# Determine build result
if(NOT DASHBOARD_FAILURE)
  set(DASHBOARD_MESSAGE "SUCCESS")
endif()

# Create packages (if applicable)
if(PACKAGE)
  execute_step(cmake install)
  execute_step(cmake create-package-archive)
  if(NOT APPLE)
    execute_step(cmake create-debian-archive)
  endif()
  if(PACKAGE STREQUAL "publish")
    execute_step(cmake upload-package-archive)
    if(NOT APPLE)
      execute_step(cmake upload-debian-archive)
    endif()
  endif()
  if(DOCKER)
    # The default Ubuntu version for Docker should be the newest base OS.
    # If this value changes, the Docker documentation in the drake repository
    # (drake/doc/_pages/docker.md) also needs to be updated.
    set(DEFAULT_DOCKER_DISTRIBUTION "jammy")

    execute_step(cmake build-docker-image)
    if(DOCKER STREQUAL "publish")
      execute_step(cmake push-docker-image)
    endif()
  endif()
  if(DISTRIBUTION STREQUAL "jammy" AND DASHBOARD_TRACK STREQUAL "Nightly")
    execute_step(cmake push-nightly-release-branch)
  endif()
endif()
