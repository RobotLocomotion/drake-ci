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

if(NOT DEFINED ENV{compiler})
  fatal("ENV{compiler} was not set")
endif()

if(NOT DEFINED ENV{generator})
  fatal("ENV{generator} was not set")
endif()

if(NOT DEFINED ENV{track})
  fatal("ENV{track} was not set")
endif()

# Copy configuration from environment
set(COMPILER $ENV{compiler})
set(COVERAGE $ENV{coverage})
set(DEBUG $ENV{debug})
set(DOCUMENTATION $ENV{documentation})
set(EVERYTHING $ENV{everything})
set(GENERATOR $ENV{generator})
set(GUROBI $ENV{gurobi})
set(MATLAB $ENV{matlab})
set(MEMCHECK $ENV{memcheck})
set(MOSEK $ENV{mosek})
set(PACKAGE $ENV{package})
set(PROVISION $ENV{provision})
set(REMOTE_CACHE $ENV{remote_cache})
set(SNOPT $ENV{snopt})
set(TRACK $ENV{track})

if(EXISTS "/media/ephemeral0/tmp")
  set(DASHBOARD_TEMP_DIR "/media/ephemeral0/tmp")
else()
  set(DASHBOARD_TEMP_DIR "/tmp")
endif()

string(STRIP "$ENV{JOB_NAME}" DASHBOARD_JOB_NAME)
if(NOT DASHBOARD_JOB_NAME)
  fatal("ENV{JOB_NAME} was not set")
endif()

string(STRIP "$ENV{NODE_NAME}" DASHBOARD_NODE_NAME)
if(NOT DASHBOARD_NODE_NAME)
  fatal("ENV{NODE_NAME} was not set")
endif()

# Verify workspace location and convert to CMake path
if(NOT DEFINED ENV{WORKSPACE})
  fatal("ENV{WORKSPACE} was not set")
endif()

file(TO_CMAKE_PATH "$ENV{WORKSPACE}" DASHBOARD_WORKSPACE)

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
