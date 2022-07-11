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
  set(DEBIAN_ARGS
    "run" "//tools/release_engineering:repack_deb" "--" "--tgz"
    "${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}" "--output-dir"
    "${DASHBOARD_WORKSPACE}")
  execute_process(COMMAND ${DASHBOARD_BAZEL_COMMAND} ${DEBIAN_ARGS}
    WORKING_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}"
    RESULT_VARIABLE DEBIAN_RESULT_VARIABLE)

  if(NOT DEBIAN_RESULT_VARIABLE EQUAL 0)
    set(DASHBOARD_FAILURE ON)
    append_step_status(
      "BAZEL DEBIAN ARCHIVE CREATION (ERROR CODE=${DEBIAN_RESULT_VARIABLE})"
      UNSTABLE)
  else()
    # In step-create-package-archive the variable DASHBOARD_PACKAGE_DATE_TIME
    # is exported to match whatever the .tar.gz had in its VERSION.txt (which
    # is used for the version number of the .deb file).
    #
    # NOTE: if CI ever gains the ability to provide `--version` to repack_deb,
    # this logic needs to be reworked since the filename will changes depending
    # on the version (by default DASHBOARD_PACKAGE_DATE_TIME).
    #
    # For the uploaded package name, we want to structure it to include the
    # ubuntu codename (focal, jammy, etc.).  Additionally, for nightly uploads
    # we only want YYYYMMDD so that the users do not need to guess the build
    # time, and for the other builds inject the commit hash.  The version of the
    # installed debian package will report YYYYMMDDHHMMSS for all, but the
    # upload artifact name is what is being changed.
    set(repack_deb_output "drake-dev_0.0.${DASHBOARD_PACKAGE_DATE_TIME}-1_amd64.deb")
    set(repack_deb_path "${DASHBOARD_WORKSPACE}/${repack_deb_output}")
    if(NOT EXISTS "${repack_deb_path}")
      set(DASHBOARD_FAILURE ON)
      append_step_status("BAZEL PACKAGE DEBIAN CREATION COULD NOT FIND ${repack_deb_output} in ${DASHBOARD_WORKSPACE}" UNSTABLE)
    else()
      if(DASHBOARD_TRACK STREQUAL "Nightly")
        set(DASHBOARD_DEBIAN_ARCHIVE_NAME
          "drake-dev_0.0.${DASHBOARD_PACKAGE_DATE}-1_amd64-${DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME}.deb")
      else()
        set(DASHBOARD_DEBIAN_ARCHIVE_NAME
          "drake-dev_0.0.${DASHBOARD_PACKAGE_DATE_TIME}-${DASHBOARD_PACKAGE_COMMIT}-1_amd64-${DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME}.deb")
      endif()
      file(RENAME "${repack_deb_path}" "${DASHBOARD_WORKSPACE}/${DASHBOARD_DEBIAN_ARCHIVE_NAME}")
      if(NOT EXISTS "${DASHBOARD_WORKSPACE}/${DASHBOARD_DEBIAN_ARCHIVE_NAME}")
        set(DASHBOARD_FAILURE ON)
        append_step_status("BAZEL PACKAGE DEBIAN CREATION COULD NOT RENAME ${repack_deb_path} to ${DASHBOARD_DEBIAN_ARCHIVE_NAME} in ${DASHBOARD_WORKSPACE}" UNSTABLE)
      else()
        message(STATUS "Debian archive created: ${DASHBOARD_DEBIAN_ARCHIVE_NAME}")
      endif()
    endif()
  endif()
endif()
