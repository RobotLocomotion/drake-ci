# -*- mode: cmake; -*-
# vi: set ft=cmake:

# BSD 3-Clause License
#
# Copyright (c) 2019, Massachusetts Institute of Technology.
# Copyright (c) 2019, Toyota Research Institute.
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

if(APPLE)
  set(DASHBOARD_UNIX_DISTRIBUTION "Apple")
  find_program(DASHBOARD_SW_VERS_COMMAND NAMES "sw_vers")
  if(NOT DASHBOARD_SW_VERS_COMMAND)
    fatal("sw_vers was not found")
  endif()
  execute_process(COMMAND "${DASHBOARD_SW_VERS_COMMAND}" "-productVersion"
    RESULT_VARIABLE SW_VERS_RESULT_VARIABLE
    OUTPUT_VARIABLE SW_VERS_OUTPUT_VARIABLE
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT SW_VERS_RESULT_VARIABLE EQUAL 0)
    fatal("unable to determine distribution release version")
  endif()
  if(SW_VERS_OUTPUT_VARIABLE MATCHES "([0-9]+)[.]([0-9]+)([.][0-9]+)?")
    set(DASHBOARD_UNIX_DISTRIBUTION_MAJOR_VERSION "${CMAKE_MATCH_1}")
    set(DASHBOARD_UNIX_DISTRIBUTION_MINOR_VERSION "${CMAKE_MATCH_2}")
  else()
    fatal("unable to determine distribution release version")
  endif()
  if(DASHBOARD_UNIX_DISTRIBUTION_MAJOR_VERSION EQUAL 15)
    set(DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME "sequoia")
  elseif(DASHBOARD_UNIX_DISTRIBUTION_MAJOR_VERSION EQUAL 26)
    set(DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME "tahoe")
  else()
    fatal("unable to determine distribution code name")
  endif()
  set(DASHBOARD_UNIX_DISTRIBUTION_VERSION "${DASHBOARD_UNIX_DISTRIBUTION_MAJOR_VERSION}")
else()
  cmake_host_system_information(RESULT DASHBOARD_UNIX_DISTRIBUTION QUERY DISTRIB_NAME)
  if(NOT DASHBOARD_UNIX_DISTRIBUTION)
    fatal("unable to determine distribution name")
  endif()
  cmake_host_system_information(
    RESULT DASHBOARD_UNIX_DISTRIBUTION_VERSION QUERY DISTRIB_VERSION_ID)
  if(NOT DASHBOARD_UNIX_DISTRIBUTION_VERSION)
    fatal("unable to determine distribution release version")
  endif()
  cmake_host_system_information(
    RESULT DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME QUERY DISTRIB_VERSION_CODENAME)
  if(NOT DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME)
    fatal("unable to determine distribution code name")
  endif()
endif()
