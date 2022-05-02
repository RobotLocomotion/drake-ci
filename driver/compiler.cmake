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

# Query what compiler is specified by `--config=${COMPILER}`.
set(COMPILER_CONFIG_ARGS
  run --config=${COMPILER}
  //tools/cc_toolchain:print_compiler_config)

execute_process(COMMAND ${DASHBOARD_BAZEL_COMMAND} ${COMPILER_CONFIG_ARGS}
  WORKING_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}"
  OUTPUT_VARIABLE COMPILER_CONFIG_OUTPUT
  RESULT_VARIABLE COMPILER_CONFIG_RETURN_VALUE)

if(NOT COMPILER_CONFIG_RETURN_VALUE EQUAL 0)
  fatal("compiler configuration could not be obtained")
endif()

# Clean up the Bazel environment; otherwise, if we try to run Bazel again with
# different arguments (`--output_user_root` in particular?), things go horribly
# sideways.
execute_process(COMMAND ${DASHBOARD_BAZEL_COMMAND} clean
  WORKING_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}")

# Extract the compiler (CC, CXX) names.
STRING(REPLACE "\n" ";" COMPILER_CONFIG_OUTPUT "${COMPILER_CONFIG_OUTPUT}")
foreach(COMPILER_CONFIG_ENTRY IN LISTS COMPILER_CONFIG_OUTPUT)
  if("${COMPILER_CONFIG_ENTRY}" MATCHES "^([A-Z]+)=(.*)$")
    set(DASHBOARD_${CMAKE_MATCH_1}_COMMAND "${CMAKE_MATCH_2}")
  endif()
endforeach()

if("${DASHBOARD_CC_COMMAND}" STREQUAL "")
  fatal("compiler configuration (CC) could not be obtained")
endif()

if("${DASHBOARD_CXX_COMMAND}" STREQUAL "")
  fatal("compiler configuration (CXX) could not be obtained")
endif()

string(TOUPPER "${COMPILER}" COMPILER_UPPER)
