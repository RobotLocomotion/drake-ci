# -*- mode: cmake; -*-
# vi: set ft=cmake:

# Set build locations and ensure there are no leftover artifacts.
set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}")
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/_wheel_$ENV{USER}")

set(WHEEL_BUILD_PATHS
  "${CTEST_BINARY_DIRECTORY}"
  # The paths below should match those used by Drake during the wheel build.
  "$ENV{HOME}/.drake-wheel-build"
  "$ENV{HOME}/.cache/drake-wheel-build")
foreach(_wheel_path IN LISTS WHEEL_BUILD_PATHS)
  file(REMOVE_RECURSE "${_wheel_path}")
  file(MAKE_DIRECTORY "${_wheel_path}")
endforeach()

set(DASHBOARD_BUILD_EVENT_JSON_FILE "${CTEST_BINARY_DIRECTORY}/BUILD.JSON")

if(APPLE)
  set(DASHBOARD_EXPERIMENTAL_SCALE_TIMEOUTS 2.0)
else()
  set(DASHBOARD_EXPERIMENTAL_SCALE_TIMEOUTS 1.0)
endif()

if(VERBOSE)
  set(DASHBOARD_SUBCOMMANDS "yes")
else()
  set(DASHBOARD_SUBCOMMANDS "no")
endif()

include(${DASHBOARD_DRIVER_DIR}/configurations/aws.cmake)

# Set package version
execute_step(common set-package-version)

# Report build configuration
report_configuration("
  ==================================== >DASHBOARD_
  CC_COMMAND
  CC_VERSION_STRING
  CXX_COMMAND
  CXX_VERSION_STRING
  ====================================
  CMAKE_VERSION
  ====================================
  CTEST_BUILD_NAME(DASHBOARD_JOB_NAME)
  CTEST_BINARY_DIRECTORY
  CTEST_CHANGE_ID
  CTEST_GIT_COMMAND
  CTEST_SITE
  CTEST_SOURCE_DIRECTORY
  CTEST_UPDATE_COMMAND
  CTEST_UPDATE_VERSION_ONLY
  ==================================== >DASHBOARD_
  GIT_COMMIT
  DRAKE_VERSION
  ==================================== >DASHBOARD_
  REMOTE_CACHE_KEY_VERSION
  REMOTE_CACHE_KEY
  ====================================
  ")

if(DEFINED ENV{WHEEL_OUTPUT_DIRECTORY})
  set(DASHBOARD_WHEEL_OUTPUT_DIRECTORY "$ENV{WHEEL_OUTPUT_DIRECTORY}")
else()
  set(DASHBOARD_WHEEL_OUTPUT_DIRECTORY "$ENV{HOME}/.drake-wheel-build/wheels")
  mkdir("${DASHBOARD_WHEEL_OUTPUT_DIRECTORY}" 1777 "wheel output directory")
  list(APPEND DASHBOARD_TEMPORARY_FILES DASHBOARD_WHEEL_OUTPUT_DIRECTORY)
endif()

set(BUILD_ARGS
  run //tools/wheel:builder --
  --output-dir "${DASHBOARD_WHEEL_OUTPUT_DIRECTORY}" "${DASHBOARD_DRAKE_VERSION}")

if(APPLE)
  # Run the build, including tests (includes provisioning)
  execute_step(wheel build-and-test)
else()
  # Prepare build host
  execute_step(wheel provision)

  # Run the build, including tests
  execute_step(wheel build-and-test)
endif()

execute_step(wheel upload-wheel)
execute_step(wheel upload-pip-index-url)

# Determine build result
if(NOT DASHBOARD_FAILURE AND NOT DASHBOARD_UNSTABLE)
  set(DASHBOARD_MESSAGE "SUCCESS")
endif()
