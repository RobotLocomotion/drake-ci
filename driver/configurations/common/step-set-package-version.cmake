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

if(DASHBOARD_TRACK STREQUAL "Staging")
  if(NOT "$ENV{DRAKE_VERSION}" MATCHES "^[0-9].[0-9]")
    fatal("drake version is invalid or not set")
  endif()
  set(DASHBOARD_DRAKE_VERSION "$ENV{DRAKE_VERSION}")
else()
  string(TIMESTAMP DATE "%Y%m%d")
  string(TIMESTAMP TIME "%H%M%S")
  set(DASHBOARD_PACKAGE_DATE "${DATE}")
  set(DASHBOARD_PACKAGE_DATE_TIME "${DATE}.${TIME}")
  execute_process(COMMAND "${CTEST_GIT_COMMAND}" rev-parse --short=8 HEAD
    WORKING_DIRECTORY "${CTEST_SOURCE_DIRECTORY}"
    RESULT_VARIABLE GIT_REV_PARSE_RESULT_VARIABLE
    OUTPUT_VARIABLE GIT_REV_PARSE_OUTPUT_VARIABLE
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  # For nightly uploads we only want YYYYMMDD so that the users do not need to
  # guess the build time.  For all other builds, we want the date, time, and
  # also the commit hash.
  if(DASHBOARD_TRACK STREQUAL "Nightly")
    set(DASHBOARD_DRAKE_VERSION "0.0.${DASHBOARD_PACKAGE_DATE}")
  elseif(GIT_REV_PARSE_RESULT_VARIABLE EQUAL 0)
    set(DASHBOARD_PACKAGE_COMMIT "${GIT_REV_PARSE_OUTPUT_VARIABLE}")
    set(DASHBOARD_DRAKE_VERSION "0.0.${DASHBOARD_PACKAGE_DATE_TIME}+git${DASHBOARD_PACKAGE_COMMIT}")
  else()
    set(DASHBOARD_PACKAGE_COMMIT "unknown")
    set(DASHBOARD_DRAKE_VERSION "0.0.${DASHBOARD_PACKAGE_DATE_TIME}+unknown")
  endif()

  string(REGEX REPLACE "[.]0+([0-9])" ".\\1"
    DASHBOARD_DRAKE_VERSION "${DASHBOARD_DRAKE_VERSION}")
  set(ENV{DRAKE_VERSION} "${DASHBOARD_DRAKE_VERSION}")
endif()
