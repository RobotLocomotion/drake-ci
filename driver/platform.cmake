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

set(DASHBOARD_UNIX ON)

include(${DASHBOARD_DRIVER_DIR}/platform/unix.cmake)

if(NOT APPLE)
  set(ENV{DISPLAY} ":99")
endif()

if(APPLE)
  find_program(DASHBOARD_BREW_COMMAND NAMES "brew")
  if(NOT DASHBOARD_BREW_COMMAND)
    fatal("brew was NOT found")
  endif()
endif()

# Execute provisioning script, if requested
if(PROVISION)
  if(DASHBOARD_UNIX_DISTRIBUTION STREQUAL "Apple")
    set(PROVISION_DIR "mac")
    set(PROVISION_SUDO)

    message(STATUS "Updating and upgrading Homebrew...")
    set(ENV{HOMEBREW_CURL_RETRIES} 4)
    execute_process(COMMAND "${DASHBOARD_BREW_COMMAND}" "update" "--force")
    execute_process(COMMAND "${DASHBOARD_BREW_COMMAND}" "pin" "cmake")
    execute_process(COMMAND "${DASHBOARD_BREW_COMMAND}" "pin" "temurin@17")
    execute_process(COMMAND "${DASHBOARD_BREW_COMMAND}" "upgrade" "--force" "--ignore-pinned")
    execute_process(COMMAND "${DASHBOARD_BREW_COMMAND}" "unpin" "cmake")
    execute_process(COMMAND "${DASHBOARD_BREW_COMMAND}" "cleanup" "-s")
    set(ENV{HOMEBREW_NO_INSTALL_CLEANUP} 1)

    message(STATUS "Removing pip cache directory...")
    file(REMOVE_RECURSE "$ENV{HOME}/Library/Caches/pip")
  else()
    string(TOLOWER "${DASHBOARD_UNIX_DISTRIBUTION}" PROVISION_DIR)
    set(PROVISION_SUDO "sudo")
  endif()

  if(GENERATOR STREQUAL "cmake")
    set(PROVISION_ARGS "--without-test-only")
     if(PACKAGE AND NOT APPLE)
        set(PROVISION_ARGS "${PROVISION_ARGS} --with-maintainer-only")
     endif()
  elseif(DOCUMENTATION)
    set(PROVISION_ARGS "--with-doc-only")
  elseif(MIRROR_TO_S3)
    set(PROVISION_ARGS "--with-doc-only")
    if(NOT APPLE)
        set(PROVISION_ARGS "${PROVISION_ARGS} --with-maintainer-only")
     endif()
  else()
    set(PROVISION_ARGS)
  endif()

  set(PROVISION_SCRIPT
    "${DASHBOARD_SOURCE_DIRECTORY}/setup/${PROVISION_DIR}/install_prereqs.sh")

  if(EXISTS "${PROVISION_SCRIPT}")
    message(STATUS "Executing provisioning script...")
    execute_process(COMMAND bash "-c" "yes | ${PROVISION_SUDO} ${PROVISION_SCRIPT} ${PROVISION_ARGS}"
      RESULT_VARIABLE INSTALL_PREREQS_RESULT_VARIABLE)
    if(NOT INSTALL_PREREQS_RESULT_VARIABLE EQUAL 0)
      fatal("provisioning script did not complete successfully")
    endif()
  else()
    fatal("provisioning script not available for this platform")
  endif()

  find_program(DASHBOARD_BAZEL_COMMAND NAMES "bazel")
  if(NOT DASHBOARD_BAZEL_COMMAND)
    fatal("bazel was not found")
  endif()
endif()

if(APPLE)
  execute_process(COMMAND "${DASHBOARD_BREW_COMMAND}" "list" "--formula" "--versions")
  execute_process(COMMAND "${DASHBOARD_BREW_COMMAND}" "list" "--cask" "--versions")
  set(DASHBOARD_PIP_COMMAND "pip3.9")
  if(NOT DASHBOARD_PIP_COMMAND)
    fatal("pip3 was not found")
  endif()
  execute_process(COMMAND "${DASHBOARD_PIP_COMMAND}" "list")
endif()
