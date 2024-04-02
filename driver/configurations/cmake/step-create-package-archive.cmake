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
  notice("CTest Status: NOT CREATING PACKAGE ARCHIVE BECAUSE BAZEL BUILD WAS NOT SUCCESSFUL")
else()
  notice("CTest Status: CREATING PACKAGE ARCHIVE")
  if(NOT DASHBOARD_UNSTABLE)
    if(APPLE)
      if(APPLE_ARM64)
        set(DASHBOARD_PACKAGE_ARCHIVE_DISTRIBUTION mac-arm64)
      else()
        set(DASHBOARD_PACKAGE_ARCHIVE_DISTRIBUTION mac)
      endif()
    else()
      set(DASHBOARD_PACKAGE_ARCHIVE_DISTRIBUTION "${DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME}")
    endif()

    set(DASHBOARD_PACKAGE_NAME "drake-${DASHBOARD_DRAKE_VERSION}")
    set(DASHBOARD_PACKAGE_ARCHIVE_NAME "${DASHBOARD_PACKAGE_NAME}-${DASHBOARD_PACKAGE_ARCHIVE_DISTRIBUTION}.tar.gz")

    execute_process(COMMAND "${CMAKE_COMMAND}" -E tar czf "${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}" drake
      WORKING_DIRECTORY /opt
      RESULT_VARIABLE TAR_RESULT_VARIABLE)
    if(NOT TAR_RESULT_VARIABLE EQUAL 0)
      append_step_status("BAZEL PACKAGE ARCHIVE CREATION" UNSTABLE)
    endif()
  endif()
endif()
