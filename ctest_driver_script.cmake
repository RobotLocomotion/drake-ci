# -*- mode: cmake; -*-
# vi: set ft=cmake:

# ctest --extra-verbose --no-compress-output --output-on-failure
#
# Variables:
#
#   ENV{BUILD_ID}              optional
#   ENV{CHANGE_ID}             optional
#   ENV{CHANGE_TITLE}          optional
#   ENV{CHANGE_URL}            optional
#   ENV{DRAKE_VERSION}         required for staging builds
#   ENV{GIT_COMMIT}            optional
#   ENV{HOME}                  required
#   ENV{JOB_NAME}              required
#   ENV{NODE_NAME}             required
#   ENV{SSH_PRIVATE_KEY_FILE}  optional
#   ENV{USER}                  required
#   ENV{WORKSPACE}             required

cmake_minimum_required(VERSION 3.28)

set(DASHBOARD_CDASH_SERVER "drake-cdash.csail.mit.edu")
set(DASHBOARD_NIGHTLY_START_TIME "00:00:00 EST")

set(DASHBOARD_CI_DIR ${CMAKE_CURRENT_LIST_DIR})
set(DASHBOARD_DRIVER_DIR ${CMAKE_CURRENT_LIST_DIR}/driver)
set(DASHBOARD_SETUP_DIR ${CMAKE_CURRENT_LIST_DIR}/setup)
set(DASHBOARD_TOOLS_DIR ${CMAKE_CURRENT_LIST_DIR}/tools)
set(DASHBOARD_TEMPORARY_FILES "")

# Always log commands from `execute_process` in CI.
set(CMAKE_EXECUTE_PROCESS_COMMAND_ECHO STDERR)

include(${DASHBOARD_DRIVER_DIR}/functions.cmake)
include(${DASHBOARD_DRIVER_DIR}/architecture.cmake)
include(${DASHBOARD_DRIVER_DIR}/environment.cmake)

# Set initial configuration
set(CTEST_TEST_ARGS "")

set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}")
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_BINARY_DIRECTORY}")

find_program(DASHBOARD_GIT_COMMAND NAMES "git")
if(NOT DASHBOARD_GIT_COMMAND)
  fatal("git was not found")
endif()
set(CTEST_GIT_COMMAND "${DASHBOARD_GIT_COMMAND}")
set(CTEST_UPDATE_COMMAND "${CTEST_GIT_COMMAND}")
set(CTEST_UPDATE_VERSION_ONLY ON)

find_program(DASHBOARD_PYTHON_COMMAND NAMES "python3"
  NO_CMAKE_PATH
  NO_CMAKE_ENVIRONMENT_PATH
  NO_CMAKE_SYSTEM_PATH
)
if(NOT DASHBOARD_PYTHON_COMMAND)
  fatal("python was not found")
endif()

if(DEBUG)
  set(DASHBOARD_CONFIGURATION_TYPE "Debug")
else()
  set(DASHBOARD_CONFIGURATION_TYPE "Release")
endif()

set(DASHBOARD_INSTALL ON)
set(DASHBOARD_TEST ON)
set(DASHBOARD_SUBMIT ON)

# Set up the site and build information
include(${DASHBOARD_DRIVER_DIR}/site.cmake)

# Set up the compiler and build platform
include(${DASHBOARD_DRIVER_DIR}/platform.cmake)
include(${DASHBOARD_DRIVER_DIR}/compiler.cmake)

# Set up status variables
clear_status(FAILURE)
clear_status(UNSTABLE)
set(DASHBOARD_CDASH_URL "")

set(ENV{CMAKE_CONFIG_TYPE} "${DASHBOARD_CONFIGURATION_TYPE}")
set(CTEST_CONFIGURATION_TYPE "${DASHBOARD_CONFIGURATION_TYPE}")

# Report resource usage before build
execute_step(common report-resource-usage)

# Invoke the appropriate build driver for the selected configuration
if(GENERATOR STREQUAL "bazel")
  include(${DASHBOARD_DRIVER_DIR}/configurations/bazel.cmake)
elseif(GENERATOR STREQUAL "cmake")
  include(${DASHBOARD_DRIVER_DIR}/configurations/cmake.cmake)
elseif(GENERATOR STREQUAL "wheel")
  include(${DASHBOARD_DRIVER_DIR}/configurations/wheel.cmake)
else()
  fatal("generator is invalid")
endif()

# Report resource usage after build
execute_step(common report-resource-usage)

# Report uploads (if any)
execute_step(common report-uploads)

# Remove any temporary files that we created
foreach(_file ${DASHBOARD_TEMPORARY_FILES})
  file(REMOVE_RECURSE ${${_file}})
endforeach()

# Report dashboard status
execute_step(common report-status)

# Finally, report any failures and set return value
if(DASHBOARD_FAILURE)
  message(FATAL_ERROR
    "*** Return value set to NON-ZERO due to failure during build")
endif()
