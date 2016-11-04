# Set number of CPU's to use
include(ProcessorCount)
ProcessorCount(DASHBOARD_PROCESSOR_COUNT)

if(DASHBOARD_PROCESSOR_COUNT EQUAL 0)
  message(WARNING "*** CTEST_TEST_ARGS PARALLEL_LEVEL was not set")
else()
  set(CTEST_TEST_ARGS ${CTEST_TEST_ARGS}
    PARALLEL_LEVEL ${DASHBOARD_PROCESSOR_COUNT})
endif()

if(GENERATOR STREQUAL "ninja")
  set(CTEST_CMAKE_GENERATOR "Ninja")
else()
  set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
  if(NOT DASHBOARD_PROCESSOR_COUNT EQUAL 0)
    set(CTEST_BUILD_FLAGS "-j${DASHBOARD_PROCESSOR_COUNT}")
  endif()
endif()

# Set up specific platform
set(DASHBOARD_APPLE OFF)

if(APPLE)
  set(DASHBOARD_APPLE ON)
  include(${DASHBOARD_DRIVER_DIR}/platform/apple.cmake)
endif()

set(DASHBOARD_UNIX ON)

include(${DASHBOARD_DRIVER_DIR}/platform/unix.cmake)

# Execute provisioning script, if requested
if(PROVISION)
  string(TOLOWER
    "${UNIX_DISTRIBUTION}/${UNIX_DISTRIBUTION_VERSION}"
    PROVISION_DIR)
  set(PROVISION_SCRIPT
    "${DASHBOARD_WORKSPACE}/setup/${PROVISION_DIR}/install_prereqs.sh")

  if(EXISTS "${PROVISION_SCRIPT}")
    execute_process(COMMAND bash "-c" "yes | sudo ${PROVISION_SCRIPT}"
      RESULT_VARIABLE INSTALL_PREREQS_RESULT_VARIABLE
      OUTPUT_VARIABLE INSTALL_PREREQS_OUTPUT_VARIABLE
      ERROR_VARIABLE INSTALL_PREREQS_ERROR_VARIABLE
      OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(NOT INSTALL_PREREQS_RESULT_VARIABLE EQUAL 0)
      message("${INSTALL_PREREQS_OUTPUT_VARIABLE}")
      message("${INSTALL_PREREQS_ERROR_VARIABLE}")
      fatal("provisioning script did not complete successfully")
    endif()
  else()
    fatal("provisioning script not available for this platform")
  endif()
endif()
