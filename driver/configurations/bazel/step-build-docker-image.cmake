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

if(DASHBOARD_FAILURE OR DASHBOARD_UNSTABLE)
  notice("CTest Status: NOT BUILDING DOCKER IMAGE BECAUSE BAZEL BUILD WAS NOT SUCCESSFUL")
else()
  notice("CTest Status: BUILDING DOCKER IMAGE")

  set(DOCKER_BUILD_WORKING_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}/tools/install/dockerhub")
  if(EXISTS "${DASHBOARD_SOURCE_DIRECTORY}/tools/install/dockerhub/${DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME}/Dockerfile")
    set(DOCKER_BUILD_WORKING_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}/tools/install/dockerhub/${DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME}")
  endif()

  execute_process(COMMAND "${CMAKE_COMMAND}" -E copy "${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}" "${DOCKER_BUILD_WORKING_DIRECTORY}/drake-latest-${DASHBOARD_PACKAGE_ARCHIVE_DISTRIBUTION}.tar.gz"
    RESULT_VARIABLE COPY_PACKAGE_ARCHIVE_RESULT_VARIABLE
    COMMAND_ECHO STDERR)
  if(NOT COPY_PACKAGE_ARCHIVE_RESULT_VARIABLE EQUAL 0)
    append_step_status("BAZEL BUILDING DOCKER IMAGE (COPY PACKAGE ARCHIVE)" UNSTABLE)
  endif()

  if(NOT DASHBOARD_UNSTABLE)
    execute_process(COMMAND "sudo" "${DASHBOARD_SETUP_DIR}/docker/install_prereqs"
      RESULT_VARIABLE DOCKER_INSTALL_PREREQS_RESULT_VARIABLE
      COMMAND_ECHO STDERR)
    if(NOT DOCKER_INSTALL_PREREQS_RESULT_VARIABLE EQUAL 0)
      append_step_status("BAZEL BUILDING DOCKER IMAGE (INSTALL DOCKER PREREQUISITES)" UNSTABLE)
    endif()
  endif()

  if(NOT DASHBOARD_UNSTABLE)
    find_program(DASHBOARD_DOCKER_COMMAND NAMES "docker")
    if(NOT DASHBOARD_DOCKER_COMMAND)
      append_step_status("BAZEL BUILDING DOCKER IMAGE (FIND DOCKER)" UNSTABLE)
    endif()
  endif()

  if(NOT DASHBOARD_UNSTABLE)
    set(DOCKER_PULL_ARGS "pull ubuntu:${DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME}")
    separate_arguments(DOCKER_PULL_ARGS_LIST UNIX_COMMAND "${DOCKER_PULL_ARGS}")
    foreach(RETRIES RANGE 3)
      execute_process(COMMAND "sudo" "${DASHBOARD_DOCKER_COMMAND}" ${DOCKER_PULL_ARGS_LIST}
        RESULT_VARIABLE DOCKER_PULL_RESULT_VARIABLE
        COMMAND_ECHO STDERR)
      if(DOCKER_PULL_RESULT_VARIABLE EQUAL 0)
        break()
      endif()
      sleep(15)
    endforeach()
    if(NOT DOCKER_PULL_RESULT_VARIABLE EQUAL 0)
      append_step_status("BAZEL PULLING DOCKER IMAGE (DOCKER PULL)" UNSTABLE)
    endif()
  endif()

  if(DASHBOARD_TRACK STREQUAL "Staging")
    set(DOCKER_TAG "${DASHBOARD_DRAKE_VERSION}-staging")
  else()
    set(DOCKER_TAG "${DATE}")
  endif()

  if(NOT DASHBOARD_UNSTABLE)
    set(DOCKER_BUILD_ARGS "build -t robotlocomotion/drake:${DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME} -t robotlocomotion/drake:${DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME}-${DOCKER_TAG} .")
    separate_arguments(DOCKER_BUILD_ARGS_LIST UNIX_COMMAND "${DOCKER_BUILD_ARGS}")
    execute_process(COMMAND "sudo" "${DASHBOARD_DOCKER_COMMAND}" ${DOCKER_BUILD_ARGS_LIST}
      WORKING_DIRECTORY "${DOCKER_BUILD_WORKING_DIRECTORY}"
      RESULT_VARIABLE DOCKER_BUILD_RESULT_VARIABLE
      COMMAND_ECHO STDERR)
    if(NOT DOCKER_BUILD_RESULT_VARIABLE EQUAL 0)
      append_step_status("BAZEL BUILDING DOCKER IMAGE (DOCKER BUILD)" UNSTABLE)
    endif()
  endif()

  if(DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME STREQUAL "focal")
    if(NOT DASHBOARD_UNSTABLE)
      set(DOCKER_TAG_ARGS "tag robotlocomotion/drake:${DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME} robotlocomotion/drake:${DOCKER_TAG}")
      separate_arguments(DOCKER_TAG_ARGS_LIST UNIX_COMMAND "${DOCKER_TAG_ARGS}")
      execute_process(COMMAND "sudo" "${DASHBOARD_DOCKER_COMMAND}" ${DOCKER_TAG_ARGS_LIST}
        RESULT_VARIABLE DOCKER_TAG_RESULT_VARIABLE
        COMMAND_ECHO STDERR)
      if(NOT DOCKER_TAG_RESULT_VARIABLE EQUAL 0)
        append_step_status("BAZEL BUILDING DOCKER IMAGE (DOCKER TAG ${DOCKER_TAG})" UNSTABLE)
      endif()
    endif()

    if(DASHBOARD_TRACK STREQUAL "Nightly" AND NOT DASHBOARD_UNSTABLE)
      set(DOCKER_TAG_LATEST_ARGS "tag robotlocomotion/drake:${DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME} robotlocomotion/drake:latest")
      separate_arguments(DOCKER_TAG_LATEST_ARGS_LIST UNIX_COMMAND "${DOCKER_TAG_LATEST_ARGS}")
      execute_process(COMMAND "sudo" "${DASHBOARD_DOCKER_COMMAND}" ${DOCKER_TAG_LATEST_ARGS_LIST}
        RESULT_VARIABLE DOCKER_TAG_LATEST_RESULT_VARIABLE
        COMMAND_ECHO STDERR)
      if(NOT DOCKER_TAG_LATEST_RESULT_VARIABLE EQUAL 0)
        append_step_status("BAZEL BUILDING DOCKER IMAGE (DOCKER TAG LATEST)" UNSTABLE)
      endif()
    endif()
  endif()
endif()
