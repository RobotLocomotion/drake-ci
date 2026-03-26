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
  notice("CTest Status: NOT MIRRORING TO S3 BECAUSE BAZEL BUILD WAS NOT SUCCESSFUL")
else()
  notice("CTest Status: MIRRORING SOURCE DEPENDENCY ARCHIVES TO S3")
  set(MIRROR_TO_S3_WORKSPACE_CMD "bazel-bin/tools/workspace/mirror_to_s3")
  if(NOT MIRROR_TO_S3 STREQUAL "publish")
    list(APPEND MIRROR_TO_S3_WORKSPACE_CMD "--no-upload")
  endif()
  execute_process(COMMAND ${MIRROR_TO_S3_WORKSPACE_CMD}
    WORKING_DIRECTORY "${CTEST_SOURCE_DIRECTORY}"
    RESULT_VARIABLE MIRROR_TO_S3_WORKSPACE_RESULT_VARIABLE)
  if(NOT MIRROR_TO_S3_WORKSPACE_RESULT_VARIABLE EQUAL 0)
    append_step_status("BAZEL MIRRORING SOURCE DEPENDENCY ARCHIVES TO S3" UNSTABLE)
  endif()

  notice("CTest Status: MIRRORING RELEASE ARTIFACTS TO S3")
  # Release artifact mirroring needs GitHub credentials to avoid rate limiting.
  file(MAKE_DIRECTORY "$ENV{HOME}/.config")
  file(WRITE
    "$ENV{HOME}/.config/readonly_github_api_token.txt"
    "$ENV{GITHUB_ACCESS_TOKEN}"
  )
  set(MIRROR_TO_S3_RELEASE_CMD "bazel-bin/tools/release_engineering/mirror_to_s3")
  if(NOT MIRROR_TO_S3 STREQUAL "publish")
    list(APPEND MIRROR_TO_S3_RELEASE_CMD "--dry-run")
  endif()
  execute_process(COMMAND ${MIRROR_TO_S3_RELEASE_CMD}
    WORKING_DIRECTORY "${CTEST_SOURCE_DIRECTORY}"
    RESULT_VARIABLE MIRROR_TO_S3_RELASE_RESULT_VARIABLE)
  if(NOT MIRROR_TO_S3_RELASE_RESULT_VARIABLE EQUAL 0)
    append_step_status("BAZEL MIRRORING RELEASE ARTIFACTS TO S3" UNSTABLE)
  endif()
endif()
