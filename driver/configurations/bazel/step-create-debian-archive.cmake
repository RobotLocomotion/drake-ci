# -*- mode: cmake; -*-
# vi: set ft=cmake:

# BSD 3-Clause License
#
# Copyright (c) 2022, Massachusetts Institute of Technology.
# Copyright (c) 2022, Toyota Research Institute.
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

if(DASHBOARD_FAILURE OR DASHBOARD_UNSTABLE)
  notice("CTest Status: NOT CREATING DEBIAN ARCHIVE BECAUSE BAZEL BUILD WAS NOT SUCCESSFUL")
else()
  notice("CTest Status: CREATING DEBIAN ARCHIVE")
  # NOTE: do not use DASHBOARD_BAZEL_*_OPTIONS with this script.
  set(DEBIAN_ARGS "run //tools/release_engineering/dev:repack_deb -- --tgz ${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_NAME} --output-dir ${DASHBOARD_WORKSPACE}")
  separate_arguments(DEBIAN_ARGS_LIST UNIX_COMMAND "${DEBIAN_ARGS}")
  execute_process(COMMAND ${DASHBOARD_BAZEL_COMMAND} ${DEBIAN_ARGS_LIST}
    WORKING_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}"
    RESULT_VARIABLE DEBIAN_RESULT_VARIABLE)

  # https://bazel.build/blog/2016/01/27/continuous-integration.html
  if(DEBIAN_RESULT_VARIABLE EQUAL 1)
    # Build failed.
    set(DASHBOARD_FAILURE ON)
    append_step_status("BAZEL DEBIAN ARCHIVE CREATION" UNSTABLE)
  elseif(DEBIAN_RESULT_VARIABLE EQUAL 2)
    # Command line problem, bad or illegal flags or command combination, or bad
    # environment variables. Your command line must be modified.
    set(DASHBOARD_FAILURE ON)
    append_step_status("BAZEL DEBIAN ARCHIVE CREATION COMMAND OR ENVIRONMENT" UNSTABLE)
  elseif(DEBIAN_RESULT_VARIABLE EQUAL 8)
    # Build interrupted, but we terminated with an orderly shutdown.
    set(DASHBOARD_FAILURE ON)
    append_step_status("BAZEL DEBIAN ARCHIVE CREATION INTERRUPTED" UNSTABLE)
  elseif(NOT DEBIAN_RESULT_VARIABLE EQUAL 0)
    set(DASHBOARD_FAILURE ON)
    append_step_status("BAZEL DEBIAN ARCHIVE CREATION (UNKNOWN ERROR CODE=${DEBIAN_RESULT_VARIABLE})" UNSTABLE)
  else()
    # Find the output debian file, its output name will differ depending on the
    # contents of VERSION.txt from step-create-package-archive.
    file(GLOB DEBIAN_ARCHIVE "${DASHBOARD_WORKSPACE}/*.deb")
    list(LENGTH DEBIAN_ARCHIVE DEBIAN_ARCHIVE_LIST_LENGTH)
    if(NOT DEBIAN_ARCHIVE_LIST_LENGTH EQUAL 1)
      append_step_status("BAZEL PACKAGE DEBIAN CREATION COULD NOT FIND SINGLE .deb ${DEBIAN_ARCHIVE}" UNSTABLE)
    else()
      # The file basename is needed in step-upload-debian-archive, but we will
      # print the full path to the console.
      get_filename_component(DASHBOARD_DEBIAN_ARCHIVE_NAME "${DEBIAN_ARCHIVE}" NAME)
      message(STATUS "Debian archive created: ${DEBIAN_ARCHIVE}")
    endif()
  endif()
endif()
