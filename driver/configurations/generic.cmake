# Jenkins passes down an incorrect value of JAVA_HOME from master to agent for
# some inexplicable reason.
unset(ENV{JAVA_HOME})

# Set base configuration
set(CTEST_USE_LAUNCHERS ON)
set(ENV{CTEST_USE_LAUNCHERS_DEFAULT} 1)

include(${DASHBOARD_DRIVER_DIR}/configurations/aws.cmake)

# Clean out the old builds and/or installs
file(REMOVE_RECURSE "${CTEST_BINARY_DIRECTORY}")
file(MAKE_DIRECTORY "${CTEST_BINARY_DIRECTORY}")
file(REMOVE_RECURSE "${DASHBOARD_INSTALL_PREFIX}")

set(CTEST_CONFIGURATION_TYPE "${DASHBOARD_CONFIGURATION_TYPE}")
set(CTEST_TEST_TIMEOUT 300)

# Prepare initial cache
cache_flag(INSTALL_PREFIX PATH)

# Report build configuration
execute_step(common report-configuration)

# Build the superbuild
execute_step(generic pre-drake)

if(DASHBOARD_SUPERBUILD_FAILURE)
  notice("CTest Status: NOT CONTINUING BECAUSE SUPERBUILD WAS NOT SUCCESSFUL")
else()
  # Now start the actual drake build
  execute_step(generic drake)
endif()

# Determine build result
set(DASHBOARD_WARNING OFF)

if(NOT DASHBOARD_FAILURE)
  format_plural(DASHBOARD_MESSAGE
    ZERO "SUCCESS"
    ONE "SUCCESS BUT WITH 1 BUILD WARNING"
    MANY "SUCCESS BUT WITH # BUILD WARNINGS"
    ${DASHBOARD_NUMBER_BUILD_WARNINGS})
  if(DASHBOARD_NUMBER_BUILD_WARNINGS GREATER 0)
    set(DASHBOARD_WARNING ON)
  endif()

  if(DASHBOARD_TEST AND NOT DASHBOARD_TEST_RETURN_VALUE EQUAL 0)
    append_step_status("DRAKE TEST" UNSTABLE)
  endif()
endif()

# Report dashboard status
execute_step(common report-status)

# Touch "warm" file
if(NOT APPLE AND NOT DASHBOARD_WARM)
  file(WRITE "${DASHBOARD_WARM_FILE}")
endif()
