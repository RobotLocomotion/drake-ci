# Find the aws executable
find_program(DASHBOARD_AWS_COMMAND NAMES "aws")
if(NOT DASHBOARD_AWS_COMMAND)
  fatal("aws was not found")
endif()

# Generate temporary identity file
mktemp(DASHBOARD_SSH_IDENTITY_FILE id_rsa_XXXXXXXX "temporary identity file")
list(APPEND DASHBOARD_TEMPORARY_FILES DASHBOARD_SSH_IDENTITY_FILE)

# Download the identity file
message(STATUS "Downloading identity file from AWS S3...")
execute_process(
  COMMAND ${DASHBOARD_AWS_COMMAND} s3 cp
    s3://drake-provisioning/id_rsa
    "${DASHBOARD_SSH_IDENTITY_FILE}"
  RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE
  OUTPUT_VARIABLE DASHBOARD_AWS_S3_OUTPUT_VARIABLE
  ERROR_VARIABLE DASHBOARD_AWS_S3_OUTPUT_VARIABLE)
message("${DASHBOARD_AWS_S3_OUTPUT_VARIABLE}")

if(NOT DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
  fatal("download of identity file from AWS S3 was not successful")
endif()

# Verify the expected SHA of the identity file
file(SHA1 "${DASHBOARD_SSH_IDENTITY_FILE}" DASHBOARD_SSH_IDENTITY_FILE_SHA1)
if(NOT DASHBOARD_SSH_IDENTITY_FILE_SHA1 STREQUAL "8de7f79df9eb18344cf0e030d2ae3b658d81263b")
  fatal("SHA1 of identity file was not correct"
    DASHBOARD_SSH_IDENTITY_FILE_SHA1)
endif()

# Set permissions on identity file
chmod("${DASHBOARD_SSH_IDENTITY_FILE}" 0400 "identity file")

# Create git SSH wrapper
mktemp(DASHBOARD_GIT_SSH_FILE git_ssh_XXXXXXXX "temporary git_ssh file")
list(APPEND DASHBOARD_TEMPORARY_FILES DASHBOARD_GIT_SSH_FILE)

configure_file(
  "${DASHBOARD_TOOLS_DIR}/git_ssh.bash.in"
  "${DASHBOARD_GIT_SSH_FILE}"
  @ONLY)
chmod("${DASHBOARD_GIT_SSH_FILE}" 0755 "git_ssh file")

# Point git at our wrapper
set(ENV{GIT_SSH} "${DASHBOARD_GIT_SSH_FILE}")
file(WRITE "${DASHBOARD_WORKSPACE}/GIT_SSH" "${DASHBOARD_GIT_SSH_FILE}")
message(STATUS "Using ENV{GIT_SSH} to set credentials")
