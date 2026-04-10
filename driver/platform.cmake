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

include(ProcessorCount)
ProcessorCount(DASHBOARD_PROCESSOR_COUNT)

if(DASHBOARD_PROCESSOR_COUNT EQUAL 0)
  message(WARNING "*** Processor count could NOT be determined")
  set(DASHBOARD_PROCESSOR_COUNT 1)
endif()

set(CTEST_TEST_ARGS ${CTEST_TEST_ARGS}
  PARALLEL_LEVEL ${DASHBOARD_PROCESSOR_COUNT})

set(CTEST_CMAKE_GENERATOR "Unix Makefiles")

# Set up specific platform
set(DASHBOARD_APPLE OFF)

if(APPLE)
  set(DASHBOARD_APPLE ON)
  include(${DASHBOARD_DRIVER_DIR}/platform/apple.cmake)
endif()

if(NOT APPLE)
  set(ENV{DISPLAY} ":99")
endif()

# Execute provisioning script, if requested
if(PROVISION)
  if(APPLE)
    fatal("provisioning is not supported on macOS")
  endif()

  set(PROVISION_SCRIPT "${DASHBOARD_SOURCE_DIRECTORY}/setup/install_prereqs")
  set(PROVISION_ARGS "-y")
  if(NOT GENERATOR STREQUAL "cmake" OR PACKAGE)
    string(APPEND PROVISION_ARGS " --developer")
  endif()

  if(EXISTS "${PROVISION_SCRIPT}")
    message(STATUS "Executing provisioning script...")
    execute_process(COMMAND bash "-c" "${PROVISION_SCRIPT} ${PROVISION_ARGS}"
      RESULT_VARIABLE INSTALL_PREREQS_RESULT_VARIABLE)
    if(NOT INSTALL_PREREQS_RESULT_VARIABLE EQUAL 0)
      fatal("provisioning script did not complete successfully")
    endif()
  else()
    fatal("provisioning script was not found")
  endif()

  if(NOT GENERATOR STREQUAL "cmake" OR PACKAGE)
    find_program(DASHBOARD_BAZEL_COMMAND NAMES "bazel")
  else()
    # When Bazel is not installed (per `--developer`, above), use the vendored
    # copy of bazelisk to determine the compiler (see `determine_compiler`).
    # TODO(tyler-yankee): When most of the compiler chasing goes away (except
    # for linux-.*-clang-bazel builds), CMake builds should no longer need
    # DASHBOARD_BAZEL_COMMAND, so this stanza can be removed.
    find_program(DASHBOARD_BAZEL_COMMAND
      NAMES "bazelisk.py"
      PATHS "${DASHBOARD_SOURCE_DIRECTORY}/third_party/com_github_bazelbuild_bazelisk"
    )
  endif()
  if(NOT DASHBOARD_BAZEL_COMMAND)
    fatal("bazel was not found")
  endif()
endif()

if(APPLE)
  find_program(DASHBOARD_BREW_COMMAND NAMES "brew")
  if(NOT DASHBOARD_BREW_COMMAND)
    fatal("brew was NOT found")
  endif()
  execute_process(COMMAND "${DASHBOARD_BREW_COMMAND}" "list" "--formula" "--versions")
  execute_process(COMMAND "${DASHBOARD_BREW_COMMAND}" "list" "--cask" "--versions")

  # Update this version of pip as Drake updates its supported Python versions.
  find_program(DASHBOARD_PIP_COMMAND NAMES "pip3.14")
  if (NOT DASHBOARD_PIP_COMMAND)
    fatal("pip3.14 was not found")
  endif()
  execute_process(COMMAND "${DASHBOARD_PIP_COMMAND}" "list")
endif()
