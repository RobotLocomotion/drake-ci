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
  notice("CTest Status: NOT UPLOADING PACKAGE ARCHIVE BECAUSE BAZEL BUILD WAS NOT SUCCESSFUL")
else()
  notice("CTest Status: UPLOADING PACKAGE ARCHIVE")
  set(DASHBOARD_PACKAGE_ARCHIVE_STORAGE_CLASS STANDARD)
  if(DASHBOARD_TRACK STREQUAL "Nightly")
    set(DASHBOARD_PACKAGE_ARCHIVE_CACHE_CONTROL_MAX_AGE 31536000)  # 365 days.
    set(DASHBOARD_PACKAGE_ARCHIVE_LATEST_CACHE_CONTROL_MAX_AGE 64800)  # 18 hours.
  else()
    set(DASHBOARD_PACKAGE_ARCHIVE_CACHE_CONTROL_MAX_AGE 2419200)  # 28 days.
    set(DASHBOARD_PACKAGE_ARCHIVE_LATEST_CACHE_CONTROL_MAX_AGE 1800)  # 30 minutes.
  endif()
  if(DASHBOARD_TRACK STREQUAL "Experimental")
    set(DASHBOARD_PACKAGE_ARCHIVE_TOTAL_UPLOADS 1)
  else()
    set(DASHBOARD_PACKAGE_ARCHIVE_TOTAL_UPLOADS 2)
  endif()
  string(TOLOWER "${DASHBOARD_TRACK}" DASHBOARD_PACKAGE_ARCHIVE_FOLDER)
  message(STATUS "Uploading package archive 1 of ${DASHBOARD_PACKAGE_ARCHIVE_TOTAL_UPLOADS} to AWS S3...")
  foreach(RETRIES RANGE 3)
    execute_process(
      COMMAND ${DASHBOARD_AWS_COMMAND} s3 cp
        --acl public-read
        --cache-control max-age=${DASHBOARD_PACKAGE_ARCHIVE_CACHE_CONTROL_MAX_AGE}
        --storage-class ${DASHBOARD_PACKAGE_ARCHIVE_STORAGE_CLASS}
        "${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}"
        "s3://drake-packages/drake/${DASHBOARD_PACKAGE_ARCHIVE_FOLDER}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}"
      RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE
      COMMAND_ECHO STDERR)
    if(DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
      break()
    endif()
    sleep(15)
  endforeach()
  if(DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
    message(STATUS "Package URL 1 of ${DASHBOARD_PACKAGE_ARCHIVE_TOTAL_UPLOADS}: https://drake-packages.csail.mit.edu/drake/${DASHBOARD_PACKAGE_ARCHIVE_FOLDER}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}")
  else()
    append_step_status("BAZEL PACKAGE ARCHIVE UPLOAD 1 OF ${DASHBOARD_PACKAGE_ARCHIVE_TOTAL_UPLOADS}" UNSTABLE)
  endif()
  if(NOT DASHBOARD_UNSTABLE)
    file(SHA512 "${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}" DASHBOARD_PACKAGE_SHA512)
    file(WRITE "${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}.sha512" "${DASHBOARD_PACKAGE_SHA512}  ${DASHBOARD_PACKAGE_ARCHIVE_NAME}")
    message(STATUS "Uploading package archive checksum 1 of ${DASHBOARD_PACKAGE_ARCHIVE_TOTAL_UPLOADS} to AWS S3...")
    foreach(RETRIES RANGE 3)
      execute_process(
        COMMAND ${DASHBOARD_AWS_COMMAND} s3 cp
          --acl public-read
          --cache-control max-age=${DASHBOARD_PACKAGE_ARCHIVE_CACHE_CONTROL_MAX_AGE}
          --storage-class ${DASHBOARD_PACKAGE_ARCHIVE_STORAGE_CLASS}
          "${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}.sha512"
          "s3://drake-packages/drake/${DASHBOARD_PACKAGE_ARCHIVE_FOLDER}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}.sha512"
        RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE
        COMMAND_ECHO STDERR)
      if(DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
        break()
      endif()
      sleep(15)
    endforeach()
    if(NOT DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
      append_step_status("BAZEL PACKAGE ARCHIVE CHECKSUM UPLOAD 1 OF ${DASHBOARD_PACKAGE_ARCHIVE_TOTAL_UPLOADS}" UNSTABLE)
    endif()
  endif()
  if(DASHBOARD_PACKAGE_ARCHIVE_TOTAL_UPLOADS EQUAL 2)
    set(DASHBOARD_PACKAGE_LATEST_NAME "drake-latest")
    set(DASHBOARD_PACKAGE_ARCHIVE_LATEST_NAME "${DASHBOARD_PACKAGE_LATEST_NAME}-${DASHBOARD_PACKAGE_ARCHIVE_DISTRIBUTION}.tar.gz")
    if(NOT DASHBOARD_UNSTABLE)
      message(STATUS "Uploading package archive 2 of 2 to AWS S3...")
      foreach(RETRIES RANGE 3)
        execute_process(
          COMMAND ${DASHBOARD_AWS_COMMAND} s3 cp
            --acl public-read
            --cache-control max-age=${DASHBOARD_PACKAGE_ARCHIVE_LATEST_CACHE_CONTROL_MAX_AGE}
            --storage-class ${DASHBOARD_PACKAGE_ARCHIVE_STORAGE_CLASS}
            "${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}"
            "s3://drake-packages/drake/${DASHBOARD_PACKAGE_ARCHIVE_FOLDER}/${DASHBOARD_PACKAGE_ARCHIVE_LATEST_NAME}"
          RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE
          COMMAND_ECHO STDERR)
        if(DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
          break()
        endif()
        sleep(15)
      endforeach()
      if(DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
        message(STATUS "Package URL 2 of 2: https://drake-packages.csail.mit.edu/drake/${DASHBOARD_PACKAGE_ARCHIVE_FOLDER}/${DASHBOARD_PACKAGE_ARCHIVE_LATEST_NAME}")
      else()
        append_step_status("BAZEL PACKAGE ARCHIVE UPLOAD 2 OF 2" UNSTABLE)
      endif()
    endif()
    if(NOT DASHBOARD_UNSTABLE)
      file(WRITE "${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_LATEST_NAME}.sha512" "${DASHBOARD_PACKAGE_SHA512}  ${DASHBOARD_PACKAGE_ARCHIVE_LATEST_NAME}")
      message(STATUS "Uploading package archive checksum 2 of 2 to AWS S3...")
      foreach(RETRIES RANGE 3)
        execute_process(
          COMMAND ${DASHBOARD_AWS_COMMAND} s3 cp
            --acl public-read
            --cache-control max-age=${DASHBOARD_PACKAGE_ARCHIVE_LATEST_CACHE_CONTROL_MAX_AGE}
            --storage-class ${DASHBOARD_PACKAGE_ARCHIVE_STORAGE_CLASS}
            "${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_LATEST_NAME}.sha512"
            "s3://drake-packages/drake/${DASHBOARD_PACKAGE_ARCHIVE_FOLDER}/${DASHBOARD_PACKAGE_ARCHIVE_LATEST_NAME}.sha512"
          RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE
          COMMAND_ECHO STDERR)
        if(DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
          break()
        endif()
        sleep(15)
      endforeach()
      if(NOT DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
        append_step_status("BAZEL PACKAGE ARCHIVE CHECKSUM UPLOAD 2 OF 2" UNSTABLE)
      endif()
    endif()
  endif()
endif()
