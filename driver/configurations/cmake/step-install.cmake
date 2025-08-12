# -*- mode: cmake; -*-
# vi: set ft=cmake:

# BSD 3-Clause License
#
# Copyright (c) 2017, Massachusetts Institute of Technology.
# Copyright (c) 2017, Toyota Research Institute.
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
  notice("CTest Status: NOT INSTALLING BECAUSE CMAKE BUILD WAS NOT SUCCESSFUL")
else()
  notice("CTest Status: INSTALLING DRAKE")
  ctest_build(BUILD "${CTEST_BINARY_DIRECTORY}"
    TARGET install APPEND
    RETURN_VALUE DASHBOARD_BUILD_RETURN_VALUE
    CAPTURE_CMAKE_ERROR DASHBOARD_BUILD_CAPTURE_CMAKE_ERROR
    QUIET)

  if(NOT DASHBOARD_BUILD_RETURN_VALUE EQUAL 0 OR DASHBOARD_BUILD_CAPTURE_CMAKE_ERROR EQUAL -1)
    append_step_status("CMAKE INSTALL" FAILURE)
  endif()

  if(DASHBOARD_SUBMIT)
    ctest_submit(
      BUILD_ID DASHBOARD_CDASH_BUILD_ID
      RETRY_COUNT 4
      RETRY_DELAY 15
      RETURN_VALUE DASHBOARD_SUBMIT_RETURN_VALUE
      CAPTURE_CMAKE_ERROR DASHBOARD_SUBMIT_CAPTURE_CMAKE_ERROR
      QUIET)
    if(NOT DASHBOARD_SUBMIT_RETURN_VALUE EQUAL 0 OR DASHBOARD_SUBMIT_CAPTURE_CMAKE_ERROR EQUAL -1)
      message(WARNING "*** CTest submit step was not successful")
    endif()
  endif()
endif()
