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

set(DASHBOARD_BAZEL_VERSION)

if (DISTRIBUTION STREQUAL "noble" AND GENERATOR STREQUAL "cmake" AND
  COMPILER STREQUAL "gcc" AND BUILD_TYPE STREQUAL "release")
  # Special case to extract Drake's minimum-supported Bazel version from the
  # sources manually. This is to provide CI coverage of multiple Bazel versions
  # simultaneously.
  file(READ "${DASHBOARD_SOURCE_DIRECTORY}/CMakeLists.txt" CML_CONTENTS)
  string(REGEX MATCH
    "set\\(MINIMUM_BAZEL_VERSION[ \t\n\r]+\"?([0-9.]+)\"?[ \t\n\r]*\\)"
    DASHBOARD_BAZEL_REGEX_MATCH_OUTPUT_VARIABLE
    "${CML_CONTENTS}"
  )
  if (DASHBOARD_BAZEL_REGEX_MATCH_OUTPUT_VARIABLE)
    set(DASHBOARD_BAZEL_VERSION "${CMAKE_MATCH_1}")
    # Write a .bazeliskrc, which takes precedence over Drake's .bazelversion.
    configure_file(
      "${DASHBOARD_TOOLS_DIR}/.bazeliskrc.in"
      "${CTEST_SOURCE_DIRECTORY}/.bazeliskrc"
      @ONLY)
  else()
    fatal("could not determine bazel version")
  endif()
endif()

# Extract Drake's .bazelversion, usually of the form x.y.z-*.
set(VERSION_ARGS
  "${DASHBOARD_BAZEL_STARTUP_OPTIONS} --output_user_root=${CTEST_BINARY_DIRECTORY} version"
)
separate_arguments(VERSION_ARGS_LIST UNIX_COMMAND "${VERSION_ARGS}")
execute_process(COMMAND ${DASHBOARD_BAZEL_COMMAND} ${VERSION_ARGS_LIST}
  WORKING_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}"
  RESULT_VARIABLE DASHBOARD_BAZEL_VERSION_RESULT_VARIABLE
  OUTPUT_VARIABLE DASHBOARD_BAZEL_VERSION_OUTPUT_VARIABLE
  ERROR_QUIET
  OUTPUT_STRIP_TRAILING_WHITESPACE)

if(DASHBOARD_BAZEL_VERSION_RESULT_VARIABLE EQUAL 0)
  string(REGEX MATCH "Build label: ([0-9a-zA-Z.\\-]+)"
      DASHBOARD_BAZEL_REGEX_MATCH_OUTPUT_VARIABLE
      "${DASHBOARD_BAZEL_VERSION_OUTPUT_VARIABLE}")
  if(DASHBOARD_BAZEL_REGEX_MATCH_OUTPUT_VARIABLE)
    set(DASHBOARD_BAZEL_VERSION "${CMAKE_MATCH_1}")
  endif()
else()
  fatal("could not determine bazel version")
endif()
