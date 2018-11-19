# -*- mode: cmake -*-
# vi: set ft=cmake :

# Copyright (c) 2016, Massachusetts Institute of Technology.
# Copyright (c) 2016, Toyota Research Institute.
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

# Set site
if(APPLE)
  string(REGEX REPLACE "(.*)_(.*)" "\\1"
    DASHBOARD_NODE_NAME "${DASHBOARD_NODE_NAME}")
else()
  string(REGEX REPLACE "(.*) (.*)" "\\1"
    DASHBOARD_NODE_NAME "${DASHBOARD_NODE_NAME}")
endif()
set(CTEST_SITE "${DASHBOARD_NODE_NAME}")

# Set build name
if(TRACK STREQUAL "experimental")
  if(DEBUG)
    string(REGEX MATCH  "-debug$" STRING_REGEX_MATCH_OUTPUT_VARIABLE
      "${DASHBOARD_JOB_NAME}")
    if(NOT STRING_REGEX_MATCH_OUTPUT_VARIABLE)
      set(DASHBOARD_JOB_NAME "${DASHBOARD_JOB_NAME}-debug")
    endif()
  else()
    string(REGEX MATCH  "-release$" STRING_REGEX_MATCH_OUTPUT_VARIABLE
      "${DASHBOARD_JOB_NAME}")
    if(NOT STRING_REGEX_MATCH_OUTPUT_VARIABLE)
      set(DASHBOARD_JOB_NAME "${DASHBOARD_JOB_NAME}-release")
    endif()
  endif()
endif()

# set model and track for submission
set(DASHBOARD_MODEL "Experimental")
if(TRACK STREQUAL "continuous")
  set(DASHBOARD_TRACK "Continuous")
elseif(TRACK MATCHES "(nightly|weekly)")
  set(DASHBOARD_TRACK "Nightly")
else()
  set(DASHBOARD_TRACK "Experimental")
endif()

# Set build id
if(DEFINED ENV{BUILD_ID})
  string(STRIP "$ENV{BUILD_ID}" DASHBOARD_BUILD_ID)
  set(DASHBOARD_LABEL "jenkins-${DASHBOARD_JOB_NAME}-${DASHBOARD_BUILD_ID}")
  set_property(GLOBAL PROPERTY Label "${DASHBOARD_LABEL}")
else()
  message(WARNING "*** ENV{BUILD_ID} was not set")
  set(DASHBOARD_LABEL "")
endif()

# Set git commit
if(DEFINED ENV{GIT_COMMIT})
  string(STRIP "$ENV{GIT_COMMIT}" DASHBOARD_GIT_COMMIT)
else()
  message(WARNING "*** ENV{GIT_COMMIT} was not set")
  set(DASHBOARD_GIT_COMMIT "")
endif()

# Set pull request id
if(DEFINED ENV{CHANGE_ID})
  string(STRIP "$ENV{CHANGE_ID}" CTEST_CHANGE_ID)
  string(STRIP "$ENV{CHANGE_TITLE}" DASHBOARD_CHANGE_TITLE)
  string(STRIP "$ENV{CHANGE_URL}" DASHBOARD_CHANGE_URL)
elseif(DEFINED ENV{ghprbPullId})
  string(STRIP "$ENV{ghprbPullId}" CTEST_CHANGE_ID)
  string(STRIP "$ENV{ghprbPullTitle}" DASHBOARD_CHANGE_TITLE)
  string(STRIP "$ENV{ghprbPullLink}" DASHBOARD_CHANGE_URL)
endif()
if(CTEST_CHANGE_ID)
  string(LENGTH "${DASHBOARD_CHANGE_TITLE}" DASHBOARD_CHANGE_TITLE_LENGTH)
  if(DASHBOARD_CHANGE_TITLE_LENGTH GREATER 30)
    string(SUBSTRING "${DASHBOARD_CHANGE_TITLE}" 0 27
      DASHBOARD_CHANGE_TITLE_SUBSTRING)
    set(DASHBOARD_CHANGE_TITLE_SHORT "${DASHBOARD_CHANGE_TITLE_SUBSTRING}...")
  else()
    set(DASHBOARD_CHANGE_TITLE_SHORT "${DASHBOARD_CHANGE_TITLE}")
  endif()
  set(DASHBOARD_BUILD_DESCRIPTION
    "*** Build Description: <a title=\"${DASHBOARD_CHANGE_TITLE}\" href=\"${DASHBOARD_CHANGE_URL}\">PR #${CTEST_CHANGE_ID}</a>: ${DASHBOARD_CHANGE_TITLE_SHORT}")
else()
  string(SUBSTRING "${DASHBOARD_GIT_COMMIT}" 0 7 DASHBOARD_GIT_COMMIT_SUBSTRING)
  set(DASHBOARD_BUILD_DESCRIPTION
    "*** Build Description: <a title=\"${DASHBOARD_GIT_COMMIT}\" href=\"https://github.com/RobotLocomotion/drake/commit/${DASHBOARD_GIT_COMMIT}\">${DASHBOARD_GIT_COMMIT_SUBSTRING}</a>")
endif()
message("${DASHBOARD_BUILD_DESCRIPTION}")
