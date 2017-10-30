include(ProcessorCount)
ProcessorCount(DASHBOARD_PROCESSOR_COUNT)

if(NOT DASHBOARD_PROCESSOR_COUNT EQUAL 0)
  set(CTEST_TEST_ARGS ${CTEST_TEST_ARGS}
    PARALLEL_LEVEL ${DASHBOARD_PROCESSOR_COUNT})
endif()

set(CTEST_CMAKE_GENERATOR "Unix Makefiles")

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
  if(DASHBOARD_UNIX_DISTRIBUTION STREQUAL "Apple")
    set(PROVISION_DIR "mac")
    set(PROVISION_SUDO)
  else()
    if(DASHBOARD_UNIX_DISTRIBUTION_VERSION VERSION_LESS 16.04)
      execute_process(COMMAND bash "-c" "echo 'oracle-java8-installer shared/accepted-oracle-license-v1-1 select true' | sudo debconf-set-selections"
        RESULT_VARIABLE DEBCONF_SET_SELECTIONS_RESULT_VARIABLE
        OUTPUT_VARIABLE DEBCONF_SET_SELECTIONS_OUTPUT_VARIABLE
        ERROR_VARIABLE DEBCONF_SET_SELECTIONS_OUTPUT_VARIABLE
        OUTPUT_STRIP_TRAILING_WHITESPACE)
      if(NOT DEBCONF_SET_SELECTIONS_RESULT_VARIABLE EQUAL 0)
        message("${DEBCONF_SET_SELECTIONS_OUTPUT_VARIABLE}")
        fatal("provisioning script did not complete successfully")
      endif()
    endif()
    string(TOLOWER
      "${DASHBOARD_UNIX_DISTRIBUTION}/${DASHBOARD_UNIX_DISTRIBUTION_VERSION}"
      PROVISION_DIR)
    set(PROVISION_SUDO "sudo")
  endif()

  set(PROVISION_SCRIPT
    "${DASHBOARD_SOURCE_DIRECTORY}/setup/${PROVISION_DIR}/install_prereqs.sh")

  if(EXISTS "${PROVISION_SCRIPT}")
    execute_process(COMMAND bash "-c" "yes | ${PROVISION_SUDO} ${PROVISION_SCRIPT}"
      RESULT_VARIABLE INSTALL_PREREQS_RESULT_VARIABLE
      OUTPUT_VARIABLE INSTALL_PREREQS_OUTPUT_VARIABLE
      ERROR_VARIABLE INSTALL_PREREQS_OUTPUT_VARIABLE
      OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(NOT INSTALL_PREREQS_RESULT_VARIABLE EQUAL 0)
      message("${INSTALL_PREREQS_OUTPUT_VARIABLE}")
      fatal("provisioning script did not complete successfully")
    endif()
  else()
    fatal("provisioning script not available for this platform")
  endif()
endif()
