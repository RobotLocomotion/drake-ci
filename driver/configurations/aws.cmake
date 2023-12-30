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

# Download our private known_hosts file and make it available to workers.
# It includes hosts for GitHub and more, see tools/generate_known_hosts.py.
set(SSH_USER_DIRECTORY "$ENV{HOME}/.ssh")
# NOTE: there are problems downloading directly to ~/.ssh, download first then
# move the file to the right place.
set(SSH_KNOWN_HOSTS_DESTINATION_PATH "${SSH_USER_DIRECTORY}/known_hosts")
mkdir("${SSH_USER_DIRECTORY}" 0700 "${SSH_USER_DIRECTORY}")
# Apple is special: https://apple.stackexchange.com/a/319743
# This appears to be why we cannot download directly to ~/.ssh/known_hosts.
if(APPLE)
  # Things seem to go wrong when the file is first created.
  set(xattr_locations "${SSH_USER_DIRECTORY}")
  foreach(location IN LISTS xattr_locations)
    message(STATUS  "Running xattr -c ${location}")
    execute_process(COMMAND
      sudo xattr -c "${location}"
      RESULT_VARIABLE _xattr_result
      OUTPUT_VARIABLE _xattr_output
      ERROR_VARIABLE _xattr_error)
    if(NOT _xattr_result EQUAL 0)
      fatal(
        "Unable to xattr -c ${location}: "
        "${_xattr_output} ${_xattr_error}.")
    endif()
  endforeach()
endif()

message(STATUS "Downloading private known_hosts from AWS S3...")
execute_process(
  COMMAND "${DASHBOARD_AWS_COMMAND}" s3 cp
    s3://drake-provisioning/drake_known_hosts
    "${SSH_KNOWN_HOSTS_DESTINATION_PATH}"
  RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE)
if(NOT DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
  fatal("download of private known_hosts from AWS S3 was not successful")
endif()
chmod("${SSH_KNOWN_HOSTS_DESTINATION_PATH}" 0600 "Creating ${SSH_KNOWN_HOSTS_DESTINATION_PATH}")

# Verify the expected SHA-1 of the private key file
file(SHA1 "${SSH_KNOWN_HOSTS_DESTINATION_PATH}" SSH_KNOWN_HOSTS_DESTINATION_PATH_SHA1)
if(NOT SSH_KNOWN_HOSTS_DESTINATION_PATH_SHA1 STREQUAL "3d935ef12d588e6e090de122ab8d9198d263e219")
  fatal("SHA-1 of private key file was not correct"
  SSH_KNOWN_HOSTS_DESTINATION_PATH_SHA1)
endif()


# Add private key to agent
if(NOT SSH_PRIVATE_KEY_FILE STREQUAL "-")
  message(STATUS "Adding private key to ssh-agent")
  execute_process(
    COMMAND ssh-add "${SSH_PRIVATE_KEY_FILE}"
    RESULT_VARIABLE DASHBOARD_SSH_AGENT_RESULT_VARIABLE)

  if(NOT DASHBOARD_SSH_AGENT_RESULT_VARIABLE EQUAL 0)
    fatal("adding private key to ssh-agent was not successful")
  endif()
endif()
