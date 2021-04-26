# -*- mode: cmake; -*-
# vi: set ft=cmake:

# BSD 3-Clause License
#
# Copyright (c) 2016, Massachusetts Institute of Technology.
# Copyright (c) 2016, Toyota Research Institute.
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

# Find the aws executable
find_program(DASHBOARD_AWS_COMMAND NAMES "aws")
if(NOT DASHBOARD_AWS_COMMAND)
  fatal("aws was not found")
endif()

if(DEFINED ENV{SSH_PRIVATE_KEY_FILE})
  set(SSH_PRIVATE_KEY_FILE "$ENV{SSH_PRIVATE_KEY_FILE}")
else()
  # Generate temporary private key file
  mktemp(SSH_PRIVATE_KEY_FILE id_rsa_XXXXXXXX "temporary private key file")
  list(APPEND DASHBOARD_TEMPORARY_FILES SSH_PRIVATE_KEY_FILE)

  # Download the private key file
  message(STATUS "Downloading private key file from AWS S3...")
  execute_process(
    COMMAND "${DASHBOARD_AWS_COMMAND}" s3 cp
      s3://drake-provisioning/id_rsa
      "${SSH_PRIVATE_KEY_FILE}"
    RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE)

  if(NOT DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
    fatal("download of private key file from AWS S3 was not successful")
  endif()

  # Verify the expected SHA-1 of the private key file
  file(SHA1 "${SSH_PRIVATE_KEY_FILE}" SSH_PRIVATE_KEY_FILE_SHA1)
  if(NOT SSH_PRIVATE_KEY_FILE_SHA1 STREQUAL "8de7f79df9eb18344cf0e030d2ae3b658d81263b")
    fatal("SHA-1 of private key file was not correct"
      SSH_PRIVATE_KEY_FILE_SHA1)
  endif()

  # Set permissions on private key file
  chmod("${SSH_PRIVATE_KEY_FILE}" 0400 "private key file")
endif()

# Create git SSH wrapper
set(DASHBOARD_GIT_SSH_FILE "${DASHBOARD_TEMP_DIR}/git_ssh")
list(APPEND DASHBOARD_TEMPORARY_FILES DASHBOARD_GIT_SSH_FILE)
file(REMOVE "${DASHBOARD_GIT_SSH_FILE}")
configure_file(
  "${DASHBOARD_TOOLS_DIR}/git_ssh.bash.in"
  "${DASHBOARD_GIT_SSH_FILE}"
  @ONLY)
chmod("${DASHBOARD_GIT_SSH_FILE}" 0755 "git_ssh file")

# Point git at our wrapper
set(ENV{GIT_SSH} "${DASHBOARD_GIT_SSH_FILE}")
message(STATUS "Using ENV{GIT_SSH} to set credentials")
