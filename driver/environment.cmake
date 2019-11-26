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

if(EXISTS "/media/ephemeral0/tmp")
  set(DASHBOARD_TEMP_DIR "/media/ephemeral0/tmp")
else()
  set(DASHBOARD_TEMP_DIR "/tmp")
endif()

# Verify workspace location and convert to CMake path
if(NOT DEFINED ENV{WORKSPACE})
  fatal("could not extract WORKSPACE from environment")
endif()

file(TO_CMAKE_PATH "$ENV{WORKSPACE}" DASHBOARD_WORKSPACE)

string(STRIP "$ENV{JOB_NAME}" DASHBOARD_JOB_NAME)
if(NOT DASHBOARD_JOB_NAME)
  fatal("could not extract JOB_NAME from environment")
endif()

string(STRIP "$ENV{NODE_NAME}" DASHBOARD_NODE_NAME)
if(NOT DASHBOARD_NODE_NAME)
  fatal("could not extract NODE_NAME from environment")
endif()

string(REGEX MATCH "(linux|mac)" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  set(OS "${REGEX_MATCH_RESULT}")
else()
  fatal("could not extract operating system from job name")
endif()
if(APPLE)
  if(NOT OS STREQUAL "mac")
    fatal("incorrect operating system in job name")
  endif()
else()
  if(NOT OS STREQUAL "linux")
    fatal("incorrect operating system in job name")
  endif()
endif()

if(APPLE)
  set(DISTRIBUTION_REGEX "(mojave|catalina)")
else()
  set(DISTRIBUTION_REGEX "bionic")
endif()
string(REGEX MATCH "${DISTRIBUTION_REGEX}"
  REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  set(DISTRIBUTION "${REGEX_MATCH_RESULT}")
else()
  fatal("could not extract distribution from job name")
endif()
include(${DASHBOARD_DRIVER_DIR}/distribution.cmake)
if(NOT DISTRIBUTION STREQUAL DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME)
  fatal("incorrect operating system code name in job name")
endif()

string(REGEX MATCH "(clang|gcc)" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  set(COMPILER "${REGEX_MATCH_RESULT}")
else()
  fatal("could not extract compiler from job name")
endif()

string(REGEX MATCH "(bazel|cmake)" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  set(GENERATOR "${REGEX_MATCH_RESULT}")
else()
  fatal("could not extract generator from job name")
endif()

string(REGEX MATCH "(continuous|experimental|nightly|weekly)"
  REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  set(TRACK "${REGEX_MATCH_RESULT}")
else()
  fatal("could not extract track from job name")
endif()

string(REGEX MATCH "debug" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  set(DEBUG ON)
else()
  set(DEBUG OFF)
endif()

string(REGEX MATCH "((address|leak|thread|undefined-behavior)-sanitizer|valgrind-(drd|helgrind|memcheck))"
  REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  set(DEBUG ON)
  set(MEMCHECK "${REGEX_MATCH_RESULT}")
else()
  set(MEMCHECK OFF)
endif()

string(REGEX MATCH "coverage" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  set(COVERAGE ON)
  set(DEBUG ON)
else()
  set(COVERAGE OFF)
endif()

string(REGEX MATCH "cache" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  set(REMOTE_CACHE ON)
else()
  set(REMOTE_CACHE OFF)
endif()

string(REGEX MATCH "release" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  set(DEBUG OFF)
  if(NOT APPLE AND NOT CXX EQUAL 17)
    set(REMOTE_CACHE ON)
  endif()
endif()

string(REGEX MATCH "(minsizerel|relwithdebinfo)" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  set(DEBUG OFF)
  set(BUILD_TYPE "${REGEX_MATCH_RESULT}")
elseif(DEBUG)
  set(BUILD_TYPE "debug")
else()
  set(BUILD_TYPE "release")
endif()

string(REGEX MATCH "gurobi" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  set(GUROBI ON)
else()
  set(GUROBI OFF)
endif()

string(REGEX MATCH "mosek" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  set(MOSEK ON)
else()
  set(MOSEK OFF)
endif()

string(REGEX MATCH "snopt" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  set(SNOPT ON)
  string(REGEX MATCH "snopt-f2c" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
  if(REGEX_MATCH_RESULT)
    set(SNOPT "F2C")
  endif()
  string(REGEX MATCH "snopt-fortran" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
  if(REGEX_MATCH_RESULT)
    set(SNOPT "Fortran")
  endif()
else()
  set(SNOPT OFF)
endif()

string(REGEX MATCH "everything" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  set(EVERYTHING ON)
  set(GUROBI ON)
  set(MOSEK ON)
  set(SNOPT ON)
else()
  set(EVERYTHING OFF)
endif()

if(GUROBI AND MOSEK AND SNOPT)
  set(EVERYTHING ON)
endif()

string(REGEX MATCH "documentation" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  if(TRACK STREQUAL "nightly")
    set(DOCUMENTATION "publish")
  else()
    set(DOCUMENTATION ON)
  endif()
else()
  set(DOCUMENTATION OFF)
endif()

string(REGEX MATCH "mirror-to-s3" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  if(TRACK MATCHES "experimental")
    set(MIRROR_TO_S3 ON)
  else()
    set(MIRROR_TO_S3 "publish")
  endif()
else()
  set(MIRROR_TO_S3 OFF)
endif()

string(REGEX MATCH "packaging" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  set(PACKAGE "publish")
  if(APPLE)
    set(DOCKER OFF)
  else()
    if(TRACK MATCHES "nightly")
      set(DOCKER "publish")
    else()
      set(DOCKER ON)
    endif()
  endif()
else()
  set(PACKAGE OFF)
  set(DOCKER OFF)
endif()

string(REGEX MATCH "unprovisioned" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  set(PROVISION ON)
  set(REMOTE_CACHE OFF)
else()
  set(PROVISION OFF)
endif()

string(REGEX MATCH "^linux-bionic-clang-bazel-(continuous|experimental|nightly|weekly)-leak-sanitizer$" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  set(REMOTE_CACHE ON)
endif()

string(REGEX MATCH "^linux-bionic-gcc-bazel-(continuous|experimental|nightly|weekly)-debug$" REGEX_MATCH_RESULT "${DASHBOARD_JOB_NAME}")
if(REGEX_MATCH_RESULT)
  set(REMOTE_CACHE ON)
endif()

string(STRIP "$ENV{verbose}" VERBOSE)
if(VERBOSE)
  set(VERBOSE ON)
else()
  set(VERBOSE OFF)
endif()

# Set the source tree
set(DASHBOARD_SOURCE_DIRECTORY "${DASHBOARD_WORKSPACE}/src")

# Set the build tree
# TODO(jamiesnape) make this ${DASHBOARD_WORKSPACE}/build
set(DASHBOARD_BINARY_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}/build")

# Determine if build volume is "warm"
set(DASHBOARD_TIMESTAMP_FILE "${DASHBOARD_TEMP_DIR}/TIMESTAMP")
if(NOT APPLE)
  if(EXISTS "${DASHBOARD_TIMESTAMP_FILE}")
    message("*** This EBS volume is warm")
  else()
    message("*** This EBS volume is cold")
  endif()
endif()
string(TIMESTAMP DASHBOARD_TIMESTAMP "%s")
file(WRITE "${DASHBOARD_TIMESTAMP_FILE}" "${DASHBOARD_TIMESTAMP}")
