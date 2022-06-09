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
  notice("CTest Status: NOT UPLOADING DEBIAN ARCHIVE BECAUSE BAZEL BUILD WAS NOT SUCCESSFUL")
else()
  notice("CTest Status: UPLOADING DEBIAN ARCHIVE")
  # NOTE: the following variables have already been setup in
  # step-upload-package-archive.cmake which runs before this script.  The debian
  # and .tar.gz should always be uploaded to the same folder (not drake-apt).
  set(DASHBOARD_DEBIAN_ARCHIVE_TOTAL_UPLOADS "${DASHBOARD_PACKAGE_ARCHIVE_TOTAL_UPLOADS}")
  set(DASHBOARD_DEBIAN_ARCHIVE_CACHE_CONTROL_MAX_AGE "${DASHBOARD_PACKAGE_ARCHIVE_CACHE_CONTROL_MAX_AGE}")
  set(DASHBOARD_DEBIAN_ARCHIVE_STORAGE_CLASS "${DASHBOARD_PACKAGE_ARCHIVE_STORAGE_CLASS}")
  set(DASHBOARD_DEBIAN_ARCHIVE_FOLDER "${DASHBOARD_PACKAGE_ARCHIVE_FOLDER}")
  set(DASHBOARD_DEBIAN_ARCHIVE_DISTRIBUTION "${DASHBOARD_PACKAGE_ARCHIVE_DISTRIBUTION}")

  message(STATUS "Uploading debian archive 1 of ${DASHBOARD_DEBIAN_ARCHIVE_TOTAL_UPLOADS} to AWS S3...")
  foreach(RETRIES RANGE 3)
    execute_process(
      COMMAND ${DASHBOARD_AWS_COMMAND} s3 cp
        --acl public-read
        --cache-control max-age=${DASHBOARD_DEBIAN_ARCHIVE_CACHE_CONTROL_MAX_AGE}
        --storage-class ${DASHBOARD_DEBIAN_ARCHIVE_STORAGE_CLASS}
        "${DASHBOARD_WORKSPACE}/${DASHBOARD_DEBIAN_ARCHIVE_NAME}"
        "s3://drake-packages/drake/${DASHBOARD_DEBIAN_ARCHIVE_FOLDER}/${DASHBOARD_DEBIAN_ARCHIVE_NAME}"
      RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE
      COMMAND_ECHO STDERR)
    if(DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
      break()
    endif()
    sleep(15)
  endforeach()
  if(DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
    message(STATUS "Debian URL 1 of ${DASHBOARD_DEBIAN_ARCHIVE_TOTAL_UPLOADS}: https://drake-packages.csail.mit.edu/drake/${DASHBOARD_DEBIAN_ARCHIVE_FOLDER}/${DASHBOARD_DEBIAN_ARCHIVE_NAME}")
  else()
    append_step_status("BAZEL DEBIAN ARCHIVE UPLOAD 1 OF ${DASHBOARD_DEBIAN_ARCHIVE_TOTAL_UPLOADS}" UNSTABLE)
  endif()
  if(NOT DASHBOARD_UNSTABLE)
    file(SHA512 "${DASHBOARD_WORKSPACE}/${DASHBOARD_DEBIAN_ARCHIVE_NAME}" DASHBOARD_DEBIAN_SHA512)
    file(WRITE "${DASHBOARD_WORKSPACE}/${DASHBOARD_DEBIAN_ARCHIVE_NAME}.sha512" "${DASHBOARD_DEBIAN_SHA512}  ${DASHBOARD_DEBIAN_ARCHIVE_NAME}")
    message(STATUS "Uploading debian archive checksum 1 of ${DASHBOARD_DEBIAN_ARCHIVE_TOTAL_UPLOADS} to AWS S3...")
    foreach(RETRIES RANGE 3)
      execute_process(
        COMMAND ${DASHBOARD_AWS_COMMAND} s3 cp
          --acl public-read
          --cache-control max-age=${DASHBOARD_DEBIAN_ARCHIVE_CACHE_CONTROL_MAX_AGE}
          --storage-class ${DASHBOARD_DEBIAN_ARCHIVE_STORAGE_CLASS}
          "${DASHBOARD_WORKSPACE}/${DASHBOARD_DEBIAN_ARCHIVE_NAME}.sha512"
          "s3://drake-packages/drake/${DASHBOARD_DEBIAN_ARCHIVE_FOLDER}/${DASHBOARD_DEBIAN_ARCHIVE_NAME}.sha512"
        RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE
        COMMAND_ECHO STDERR)
      if(DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
        break()
      endif()
      sleep(15)
    endforeach()
    if(NOT DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
      append_step_status("BAZEL DEBIAN ARCHIVE CHECKSUM UPLOAD 1 OF ${DASHBOARD_DEBIAN_ARCHIVE_TOTAL_UPLOADS}" UNSTABLE)
    endif()
  endif()
  if(DASHBOARD_DEBIAN_ARCHIVE_TOTAL_UPLOADS EQUAL 2)
    set(DASHBOARD_DEBIAN_LATEST_NAME "drake-latest")
    set(DASHBOARD_DEBIAN_ARCHIVE_LATEST_NAME "${DASHBOARD_DEBIAN_LATEST_NAME}-${DASHBOARD_DEBIAN_ARCHIVE_DISTRIBUTION}.deb")
    if(NOT DASHBOARD_UNSTABLE)
      message(STATUS "Uploading debian archive 2 of 2 to AWS S3...")
      foreach(RETRIES RANGE 3)
        execute_process(
          COMMAND ${DASHBOARD_AWS_COMMAND} s3 cp
            --acl public-read
            --cache-control max-age=${DASHBOARD_DEBIAN_ARCHIVE_CACHE_CONTROL_MAX_AGE}
            --storage-class ${DASHBOARD_DEBIAN_ARCHIVE_STORAGE_CLASS}
            "${DASHBOARD_WORKSPACE}/${DASHBOARD_DEBIAN_ARCHIVE_NAME}"
            "s3://drake-packages/drake/${DASHBOARD_DEBIAN_ARCHIVE_FOLDER}/${DASHBOARD_DEBIAN_ARCHIVE_LATEST_NAME}"
          RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE
          COMMAND_ECHO STDERR)
        if(DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
          break()
        endif()
        sleep(15)
      endforeach()
      if(DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
        message(STATUS "Debian URL 2 of 2: https://drake-packages.csail.mit.edu/drake/${DASHBOARD_DEBIAN_ARCHIVE_FOLDER}/${DASHBOARD_DEBIAN_ARCHIVE_LATEST_NAME}")
      else()
        append_step_status("BAZEL DEBIAN ARCHIVE UPLOAD 2 OF 2" UNSTABLE)
      endif()
    endif()
    if(NOT DASHBOARD_UNSTABLE)
      file(WRITE "${DASHBOARD_WORKSPACE}/${DASHBOARD_DEBIAN_ARCHIVE_LATEST_NAME}.sha512" "${DASHBOARD_DEBIAN_SHA512}  ${DASHBOARD_DEBIAN_ARCHIVE_LATEST_NAME}")
      message(STATUS "Uploading debian archive checksum 2 of 2 to AWS S3...")
      foreach(RETRIES RANGE 3)
        execute_process(
          COMMAND ${DASHBOARD_AWS_COMMAND} s3 cp
            --acl public-read
            --cache-control max-age=${DASHBOARD_DEBIAN_ARCHIVE_CACHE_CONTROL_MAX_AGE}
            --storage-class ${DASHBOARD_DEBIAN_ARCHIVE_STORAGE_CLASS}
            "${DASHBOARD_WORKSPACE}/${DASHBOARD_DEBIAN_ARCHIVE_LATEST_NAME}.sha512"
            "s3://drake-packages/drake/${DASHBOARD_DEBIAN_ARCHIVE_FOLDER}/${DASHBOARD_DEBIAN_ARCHIVE_LATEST_NAME}.sha512"
          RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE
          COMMAND_ECHO STDERR)
        if(DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
          break()
        endif()
        sleep(15)
      endforeach()
      if(NOT DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
        append_step_status("BAZEL DEBIAN ARCHIVE CHECKSUM UPLOAD 2 OF 2" UNSTABLE)
      endif()
    endif()
  endif()
endif()
