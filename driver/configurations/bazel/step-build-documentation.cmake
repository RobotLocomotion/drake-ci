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
  notice("CTest Status: NOT BUILDING DOCUMENTATION BECAUSE BAZEL BUILD WAS NOT SUCCESSFUL")
else()
  notice("CTest Status: BUILDING DOCUMENTATION")

  set(BUILD_DOCUMENTATION_ARGS
    "${DASHBOARD_BAZEL_STARTUP_OPTIONS} run ${DASHBOARD_BAZEL_BUILD_OPTIONS} //doc:build -- --out_dir=${DASHBOARD_DOCUMENTATION_DIRECTORY}")
  separate_arguments(BUILD_DOCUMENTATION_ARGS_LIST UNIX_COMMAND "${BUILD_DOCUMENTATION_ARGS}")
  execute_process(COMMAND ${DASHBOARD_BAZEL_COMMAND} ${BUILD_DOCUMENTATION_ARGS_LIST}
    WORKING_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}"
    RESULT_VARIABLE DASHBOARD_BUILD_DOCUMENTATION_RESULT_VARIABLE)
  if(NOT DASHBOARD_BUILD_DOCUMENTATION_RESULT_VARIABLE EQUAL 0)
    append_step_status("BUILDING DOCUMENTATION" UNSTABLE)
  endif()

  file(WRITE "${DASHBOARD_DOCUMENTATION_DIRECTORY}/CNAME" "drake.mit.edu")
  file(WRITE "${DASHBOARD_DOCUMENTATION_DIRECTORY}/googleb54a1809ac854371.html" "google-site-verification: googleb54a1809ac854371.html")
  file(TOUCH "${DASHBOARD_DOCUMENTATION_DIRECTORY}/.nojekyll")
endif()
