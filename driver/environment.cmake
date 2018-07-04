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

# Set default compiler and generator (if not specified) or copy from environment
if(NOT DEFINED ENV{compiler})
  if(APPLE)
    message(WARNING "*** ENV{compiler} was not set; defaulting to 'clang'")
    set(COMPILER "clang")
  else()
    message(WARNING "*** ENV{compiler} was not set; defaulting to 'gcc'")
    set(COMPILER "gcc")
  endif()
else()
  set(COMPILER $ENV{compiler})
endif()
if(NOT DEFINED ENV{generator})
  message(WARNING "*** ENV{generator} was not set; defaulting to 'make'")
  set(GENERATOR "make")
else()
  set(GENERATOR $ENV{generator})
endif()

# Copy remaining configuration from environment
set(COVERAGE $ENV{coverage})
set(DEBUG $ENV{debug})
set(DOCUMENTATION $ENV{documentation})
set(EVERYTHING $ENV{everything})
set(GUROBI $ENV{gurobi})
set(MATLAB $ENV{matlab})
set(MEMCHECK $ENV{memcheck})
set(MOSEK $ENV{mosek})
set(PACKAGE $ENV{package})
set(PROVISION $ENV{provision})
set(REMOTE_CACHE $ENV{remote_cache})
set(SNOPT $ENV{snopt})
set(TRACK $ENV{track})

# Verify workspace location and convert to CMake path
if(NOT DEFINED ENV{WORKSPACE})
  fatal("ENV{WORKSPACE} was not set")
endif()

file(TO_CMAKE_PATH "$ENV{WORKSPACE}" DASHBOARD_WORKSPACE)

# Determine location of git working tree
if(EXISTS "${DASHBOARD_WORKSPACE}/.git")
  set(DASHBOARD_SOURCE_DIRECTORY "${DASHBOARD_WORKSPACE}")
elseif(EXISTS ${DASHBOARD_WORKSPACE}/src/.git)
  set(DASHBOARD_SOURCE_DIRECTORY "${DASHBOARD_WORKSPACE}/src")
elseif(EXISTS "${DASHBOARD_WORKSPACE}/src/drake/.git")
  set(DASHBOARD_SOURCE_DIRECTORY "${DASHBOARD_WORKSPACE}/src/drake")
else()
  fatal("git working tree was not found")
endif()

# Set the build tree
# TODO(jamiesnape) make this ${DASHBOARD_WORKSPACE}/build
set(DASHBOARD_BINARY_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}/build")

# Determine if build machine is "warm"
if(NOT APPLE)
  set(DASHBOARD_WARM_FILE "/tmp/WARM")
  if(EXISTS "${DASHBOARD_WARM_FILE}")
    set(DASHBOARD_WARM ON)
    message("*** This EBS volume is warm")
  else()
    set(DASHBOARD_WARM OFF)
    message("*** This EBS volume is cold")
  endif()
endif()
