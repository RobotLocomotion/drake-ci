# Set base configuration
set(CTEST_USE_LAUNCHERS ON)
set(ENV{CTEST_USE_LAUNCHERS_DEFAULT} 1)

set(DASHBOARD_ENABLE_DOCUMENTATION OFF)
set(DASHBOARD_LONG_RUNNING_TESTS OFF)

if(DOCUMENTATION OR DOCUMENTATION STREQUAL "publish")
  set(DASHBOARD_ENABLE_DOCUMENTATION ON)

  if(DOCUMENTATION STREQUAL "publish")
    set(ENV{OXYGEN_DIR} "/usr/local/oxygen")
  endif()
endif()

if(NOT DEFINED ENV{ghprbPullId})
  set(DASHBOARD_LONG_RUNNING_TESTS ON)
endif()

include(${DASHBOARD_DRIVER_DIR}/configurations/aws.cmake)

# Clean out the old builds and/or installs
file(REMOVE_RECURSE "${CTEST_BINARY_DIRECTORY}")
file(MAKE_DIRECTORY "${CTEST_BINARY_DIRECTORY}")
file(REMOVE_RECURSE "${DASHBOARD_INSTALL_PREFIX}")

set(ENV{CMAKE_CONFIG_TYPE} "${DASHBOARD_CONFIGURATION_TYPE}")
set(CTEST_CONFIGURATION_TYPE "${DASHBOARD_CONFIGURATION_TYPE}")

include(${DASHBOARD_DRIVER_DIR}/configurations/timeout.cmake)

# Prepare initial cache
cache_flag(C_FLAGS STRING)
cache_flag(CXX_FLAGS STRING)
cache_flag(CXX_STANDARD STRING EXTRA "CMAKE_CXX_STANDARD_REQUIRED:BOOL=ON")
cache_flag(FORTRAN_FLAGS STRING NAMES CMAKE_Fortran_FLAGS)
cache_flag(STATIC_LINKER_FLAGS STRING)
cache_flag(SHARED_LINKER_FLAGS STRING NAMES
  CMAKE_EXE_LINKER_FLAGS
  CMAKE_SHARED_LINKER_FLAGS)
cache_flag(POSITION_INDEPENDENT_CODE BOOL)
cache_flag(INSTALL_PREFIX PATH)
cache_append(LONG_RUNNING_TESTS BOOL ${DASHBOARD_LONG_RUNNING_TESTS})
cache_append(SKIP_DRAKE_BUILD BOOL ON)

# Report build configuration
execute_step(common report-configuration)

# Build the pre-drake superbuild
execute_step(generic pre-drake)

if(DASHBOARD_SUPERBUILD_FAILURE)
  notice("CTest Status: NOT CONTINUING BECAUSE SUPERBUILD (PRE-DRAKE) WAS NOT SUCCESSFUL")
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

# Publish documentation, if requested, and if build succeeded
if(DOCUMENTATION STREQUAL "publish")
  execute_step(generic publish)
endif()

# Report dashboard status
execute_step(common report-status)

# Touch "warm" file
if(NOT APPLE AND NOT DASHBOARD_WARM)
  file(WRITE "${DASHBOARD_WARM_FILE}")
endif()
