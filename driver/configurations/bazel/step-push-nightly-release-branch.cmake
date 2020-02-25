# -*- mode: cmake -*-
# vi: set ft=cmake :

# Copyright (c) 2019, Massachusetts Institute of Technology.
# Copyright (c) 2019, Toyota Research Institute.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

if(DASHBOARD_FAILURE OR DASHBOARD_UNSTABLE)
  notice("CTest Status: NOT PUSHING NIGHTLY RELEASE BRANCH BECAUSE BAZEL BUILD OR TEST WAS NOT SUCCESSFUL")
else()
  notice("CTest Status: PUSHING NIGHTLY RELEASE BRANCH")

  set(GIT_FETCH_ARGS "fetch --no-tags --progress origin +refs/heads/nightly-release")
  separate_arguments(GIT_FETCH_ARGS_LIST UNIX_COMMAND "${GIT_FETCH_ARGS}")
  execute_process(COMMAND "${CTEST_GIT_COMMAND}" ${GIT_FETCH_ARGS_LIST}
    WORKING_DIRECTORY "${CTEST_SOURCE_DIRECTORY}"
    RESULT_VARIABLE DASHBOARD_GIT_FETCH_NIGHTLY_RELEASE_BRANCH_RESULT_VARIABLE
    COMMAND_ECHO STDERR)
  if(NOT DASHBOARD_GIT_FETCH_NIGHTLY_RELEASE_BRANCH_RESULT_VARIABLE EQUAL 0)
    append_step_status("PUSHING NIGHTLY RELEASE BRANCH (GIT FETCH)" UNSTABLE)
  endif()

  if(NOT DASHBOARD_UNSTABLE)
    set(GIT_PUSH_ARGS "push --progress origin HEAD:refs/heads/nightly-release")
    separate_arguments(GIT_PUSH_ARGS_LIST UNIX_COMMAND "${GIT_PUSH_ARGS}")
    execute_process(COMMAND "${CTEST_GIT_COMMAND}" ${GIT_PUSH_ARGS_LIST}
      WORKING_DIRECTORY "${CTEST_SOURCE_DIRECTORY}"
      RESULT_VARIABLE DASHBOARD_GIT_PUSH_NIGHTLY_RELEASE_BRANCH_RESULT_VARIABLE
      COMMAND_ECHO STDERR)
    if(NOT DASHBOARD_GIT_PUSH_NIGHTLY_RELEASE_BRANCH_RESULT_VARIABLE EQUAL 0)
      append_step_status("PUSHING NIGHTLY RELEASE BRANCH (GIT PUSH)" UNSTABLE)
    endif()
  endif()
endif()
