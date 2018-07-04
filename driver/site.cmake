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
if(DEFINED site)
  if(APPLE)
    string(REGEX REPLACE "(.*)_(.*)" "\\1" DASHBOARD_SITE "${site}")
  else()
    string(REGEX REPLACE "(.*) (.*)" "\\1" DASHBOARD_SITE "${site}")
  endif()
  set(CTEST_SITE "${DASHBOARD_SITE}")
else()
  message(WARNING "*** CTEST_SITE was not set")
endif()

# Set build track
if(NOT TRACK)
  set(TRACK "experimental")
endif()

# Set build name
if(DEFINED buildname)
  set(DASHBOARD_BUILD_NAME "${buildname}")
  if(TRACK STREQUAL "experimental")
    if(DEBUG)
      string(REGEX MATCH  "-debug$" STRING_REGEX_MATCH_OUTPUT_VARIABLE
        "${DASHBOARD_BUILD_NAME}")
      if(NOT STRING_REGEX_MATCH_OUTPUT_VARIABLE)
        set(DASHBOARD_BUILD_NAME "${DASHBOARD_BUILD_NAME}-debug")
      endif()
    else()
      string(REGEX MATCH  "-release$" STRING_REGEX_MATCH_OUTPUT_VARIABLE
        "${DASHBOARD_BUILD_NAME}")
      if(NOT STRING_REGEX_MATCH_OUTPUT_VARIABLE)
        set(DASHBOARD_BUILD_NAME "${DASHBOARD_BUILD_NAME}-release")
      endif()
    endif()
  endif()
else()
  message(WARNING "*** DASHBOARD_BUILD_NAME was not set")
endif()

# set model and track for submission
set(DASHBOARD_MODEL "Experimental")
if(TRACK STREQUAL "continuous")
  set(DASHBOARD_TRACK "Continuous")
elseif(TRACK STREQUAL "nightly")
  set(DASHBOARD_TRACK "Nightly")
else()
  set(DASHBOARD_TRACK "Experimental")
endif()

# Set build id
if(DEFINED ENV{BUILD_ID})
  set(DASHBOARD_LABEL "jenkins-${DASHBOARD_BUILD_NAME}-$ENV{BUILD_ID}")
  set_property(GLOBAL PROPERTY Label "${DASHBOARD_LABEL}")
else()
  message(WARNING "*** ENV{BUILD_ID} was not set")
  set(DASHBOARD_LABEL "")
endif()

# Set git commit
if(DEFINED ENV{GIT_COMMIT})
  set(DASHBOARD_GIT_COMMIT "$ENV{GIT_COMMIT}")
else()
  message(WARNING "*** ENV{GIT_COMMIT} was not set")
  set(DASHBOARD_GIT_COMMIT "")
endif()

# Set pull request id
if(DEFINED ENV{ghprbPullId})
  set(CTEST_CHANGE_ID "$ENV{ghprbPullId}")
  set(DASHBOARD_CHANGE_TITLE "$ENV{ghprbPullTitle}")
  string(LENGTH "${DASHBOARD_CHANGE_TITLE}" DASHBOARD_CHANGE_TITLE_LENGTH)
  if(DASHBOARD_CHANGE_TITLE_LENGTH GREATER 30)
    string(SUBSTRING "${DASHBOARD_CHANGE_TITLE}" 0 27
      DASHBOARD_CHANGE_TITLE_SUBSTRING)
    set(DASHBOARD_CHANGE_TITLE "${DASHBOARD_CHANGE_TITLE_SUBSTRING}...")
  endif()
  set(DASHBOARD_BUILD_DESCRIPTION
    "*** Build Description: <a title=\"$ENV{ghprbPullTitle}\" href=\"$ENV{ghprbPullLink}\">PR ${CTEST_CHANGE_ID}</a>: ${DASHBOARD_CHANGE_TITLE}")
  message("${DASHBOARD_BUILD_DESCRIPTION}")
endif()
