# -*- mode: cmake -*-
# vi: set ft=cmake :

# Copyright (c) 2018, Massachusetts Institute of Technology.
# Copyright (c) 2018, Toyota Research Institute.
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

set(MOSEKLM_LICENSE_FILE "${DASHBOARD_TEMP_DIR}/mosek.lic")
file(REMOVE "${MOSEKLM_LICENSE_FILE}")

message(STATUS "Downloading MOSEK license file from AWS S3...")
execute_process(
  COMMAND "${DASHBOARD_AWS_COMMAND}" s3 cp
    s3://drake-provisioning/mosek/mosek.lic "${MOSEKLM_LICENSE_FILE}"
  RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE)
list(APPEND DASHBOARD_TEMPORARY_FILES MOSEKLM_LICENSE_FILE)

if(NOT EXISTS "${MOSEKLM_LICENSE_FILE}")
  fatal("MOSEK license file was NOT found")
endif()

set(ENV{MOSEKLM_LICENSE_FILE} "${MOSEKLM_LICENSE_FILE}")
