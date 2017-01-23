# ctest --extra-verbose --no-compress-output --output-on-failure
#
# Variables:
#
#   ENV{BUILD_ID}         optional    value of Jenkins BUILD_ID
#   ENV{WORKSPACE}        required    value of Jenkins WORKSPACE
#   ENV{compiler}         optional    "gcc" | "clang" | "scan-build" |
#                                     "include-what-you-use" |
#                                     "link-what-you-use" |
#                                     "cpplint"
#   ENV{coverage}         optional    boolean
#   ENV{debug}            optional    boolean
#   ENV{documentation}    optional    boolean | "publish"
#   ENV{generator}        optional    "bazel" | "make" | "ninja" | "xcode"
#   ENV{ghprbPullId}      optional    value for CTEST_CHANGE_ID
#   ENV{matlab}           optional    boolean
#   ENV{memcheck}         optional    "asan" | "lsan" | "msan" | "tsan" |
#                                     "ubsan" | "valgrind"
#   ENV{minimal}          optional    boolean
#   ENV{openSource}       optional    boolean
#   ENV{provision}        optional    boolean
#   ENV{ros}              optional    boolean
#   ENV{track}            optional    "continuous" | "experimental" | "nightly"
#
#   buildname             optional    value for CTEST_BUILD_NAME
#   site                  optional    value for CTEST_SITE

cmake_minimum_required(VERSION 3.6 FATAL_ERROR)

set(CTEST_RUN_CURRENT_SCRIPT OFF)  # HACK

set(DASHBOARD_CDASH_SERVER "drake-cdash.csail.mit.edu")
set(DASHBOARD_NIGHTLY_START_TIME "00:00:00 EST")

set(DASHBOARD_DRIVER_DIR ${CMAKE_CURRENT_LIST_DIR}/driver)
set(DASHBOARD_TOOLS_DIR ${CMAKE_CURRENT_LIST_DIR}/tools)
set(DASHBOARD_TEMPORARY_FILES "")

include(${DASHBOARD_DRIVER_DIR}/functions.cmake)
include(${DASHBOARD_DRIVER_DIR}/environment.cmake)

# Set initial configuration
set(CTEST_TEST_ARGS "")

set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}")
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_BINARY_DIRECTORY}")
set(DASHBOARD_INSTALL_PREFIX "${DASHBOARD_BINARY_DIRECTORY}/install")

set(CTEST_GIT_COMMAND "git")
set(CTEST_UPDATE_COMMAND "${CTEST_GIT_COMMAND}")
set(CTEST_UPDATE_VERSION_ONLY ON)

if(DEBUG)
  set(DASHBOARD_CONFIGURATION_TYPE "Debug")
else()
  set(DASHBOARD_CONFIGURATION_TYPE "Release")
endif()

set(DASHBOARD_INSTALL ON)
set(DASHBOARD_TEST ON)

# Set up the site and build information
include(${DASHBOARD_DRIVER_DIR}/site.cmake)

# Set up the compiler and build platform
include(${DASHBOARD_DRIVER_DIR}/platform.cmake)
include(${DASHBOARD_DRIVER_DIR}/compiler.cmake)

# Set up status variables
clear_status(FAILURE)
clear_status(UNSTABLE)
set(DASHBOARD_CDASH_URL_MESSAGES "")

set(ENV{CMAKE_CONFIG_TYPE} "${DASHBOARD_CONFIGURATION_TYPE}")
set(CTEST_CONFIGURATION_TYPE "${DASHBOARD_CONFIGURATION_TYPE}")

set(DASHBOARD_VERBOSE_MAKEFILE ON)
set(ENV{CMAKE_FLAGS}
  "-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON $ENV{CMAKE_FLAGS}")  # HACK

# Invoke the appropriate build driver for the selected configuration
if(COMPILER STREQUAL "cpplint")
  include(${DASHBOARD_DRIVER_DIR}/configurations/cpplint.cmake)
elseif(GENERATOR STREQUAL "bazel")
  include(${DASHBOARD_DRIVER_DIR}/configurations/bazel.cmake)
elseif(ROS)
  include(${DASHBOARD_DRIVER_DIR}/configurations/catkin.cmake)
else()
  include(${DASHBOARD_DRIVER_DIR}/configurations/generic.cmake)
endif()

# Remove any temporary files that we created
foreach(_file ${DASHBOARD_TEMPORARY_FILES})
  file(REMOVE ${${_file}})
endforeach()

# Report any failures and set return value
if(DASHBOARD_FAILURE)
  message(FATAL_ERROR
    "*** Return value set to NON-ZERO due to failure during build")
endif()
