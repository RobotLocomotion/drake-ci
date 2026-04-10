# -*- mode: cmake; -*-
# vi: set ft=cmake:

include(ProcessorCount)
ProcessorCount(DASHBOARD_PROCESSOR_COUNT)

if(DASHBOARD_PROCESSOR_COUNT EQUAL 0)
  message(WARNING "*** Processor count could NOT be determined")
  set(DASHBOARD_PROCESSOR_COUNT 1)
endif()

set(CTEST_TEST_ARGS ${CTEST_TEST_ARGS}
  PARALLEL_LEVEL ${DASHBOARD_PROCESSOR_COUNT})

set(CTEST_CMAKE_GENERATOR "Unix Makefiles")

# Set up specific platform
set(DASHBOARD_APPLE OFF)

if(APPLE)
  set(DASHBOARD_APPLE ON)
  include(${DASHBOARD_DRIVER_DIR}/platform/apple.cmake)
endif()

if(NOT APPLE)
  set(ENV{DISPLAY} ":99")
endif()

# Execute provisioning script, if requested
if(PROVISION)
  if(APPLE)
    fatal("provisioning is not supported on macOS")
  endif()

  set(PROVISION_SCRIPT "${DASHBOARD_SOURCE_DIRECTORY}/setup/install_prereqs")
  set(PROVISION_ARGS "-y")
  if(NOT GENERATOR STREQUAL "cmake" OR PACKAGE)
    string(APPEND PROVISION_ARGS " --developer")
  endif()

  if(EXISTS "${PROVISION_SCRIPT}")
    message(STATUS "Executing provisioning script...")
    execute_process(COMMAND bash "-c" "${PROVISION_SCRIPT} ${PROVISION_ARGS}"
      RESULT_VARIABLE INSTALL_PREREQS_RESULT_VARIABLE)
    if(NOT INSTALL_PREREQS_RESULT_VARIABLE EQUAL 0)
      fatal("provisioning script did not complete successfully")
    endif()
  else()
    fatal("provisioning script was not found")
  endif()

  if(NOT GENERATOR STREQUAL "cmake" OR PACKAGE)
    find_program(DASHBOARD_BAZEL_COMMAND NAMES "bazel")
    if(NOT DASHBOARD_BAZEL_COMMAND)
      fatal("bazel was not found")
    endif()
  endif()
endif()

if(APPLE)
  find_program(DASHBOARD_BREW_COMMAND NAMES "brew")
  if(NOT DASHBOARD_BREW_COMMAND)
    fatal("brew was NOT found")
  endif()
  execute_process(COMMAND "${DASHBOARD_BREW_COMMAND}" "list" "--formula" "--versions")
  execute_process(COMMAND "${DASHBOARD_BREW_COMMAND}" "list" "--cask" "--versions")

  # Update this version of pip as Drake updates its supported Python versions.
  find_program(DASHBOARD_PIP_COMMAND NAMES "pip3.14")
  if (NOT DASHBOARD_PIP_COMMAND)
    fatal("pip3.14 was not found")
  endif()
  execute_process(COMMAND "${DASHBOARD_PIP_COMMAND}" "list")
endif()
