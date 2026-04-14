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
set(DASHBOARD_APPLE ${APPLE})

if(NOT APPLE)
  set(ENV{DISPLAY} ":99")
endif()

# Execute provisioning script, if requested
if(PROVISION)
  if(APPLE)
    fatal("provisioning is not supported on macOS")
  else()
    string(TOLOWER "${DASHBOARD_UNIX_DISTRIBUTION}" PROVISION_DIR)
    set(PROVISION_SUDO "sudo")
  endif()

  if(GENERATOR STREQUAL "cmake")
    set(PROVISION_ARGS "--without-test-only")
     if(PACKAGE)
        string(APPEND PROVISION_ARGS " --with-maintainer-only")
     endif()
  elseif(DOCUMENTATION)
    set(PROVISION_ARGS "--with-doc-only")
  elseif(MIRROR_TO_S3)
    set(PROVISION_ARGS "--with-doc-only --with-maintainer-only")
  else()
    set(PROVISION_ARGS)
  endif()

  set(PROVISION_SCRIPT
    "${DASHBOARD_SOURCE_DIRECTORY}/setup/${PROVISION_DIR}/install_prereqs.sh")

  if(EXISTS "${PROVISION_SCRIPT}")
    message(STATUS "Executing provisioning script...")
    execute_process(COMMAND bash "-c" "yes | ${PROVISION_SUDO} ${PROVISION_SCRIPT} ${PROVISION_ARGS}"
      RESULT_VARIABLE INSTALL_PREREQS_RESULT_VARIABLE)
    if(NOT INSTALL_PREREQS_RESULT_VARIABLE EQUAL 0)
      fatal("provisioning script did not complete successfully")
    endif()
  else()
    fatal("provisioning script not available for this platform")
  endif()

  find_program(DASHBOARD_BAZEL_COMMAND NAMES "bazel")
  if(NOT DASHBOARD_BAZEL_COMMAND)
    fatal("bazel was not found")
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
