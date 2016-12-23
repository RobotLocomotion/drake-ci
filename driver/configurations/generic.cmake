# Set base configuration
if(GENERATOR STREQUAL "xcode")
  set(CTEST_USE_LAUNCHERS OFF)
  list(APPEND CTEST_CUSTOM_ERROR_EXCEPTION
    "configure.ac:[0-9]*: installing"
    "swig/Makefile.am:30: installing './py-compile'")
else()
  set(CTEST_USE_LAUNCHERS ON)
  set(ENV{CTEST_USE_LAUNCHERS_DEFAULT} 1)
endif()

set(DASHBOARD_COVERAGE OFF)
set(DASHBOARD_MEMCHECK OFF)
set(DASHBOARD_LINK_WHAT_YOU_USE OFF)

set(DASHBOARD_ENABLE_DOCUMENTATION OFF)
set(DASHBOARD_LONG_RUNNING_TESTS OFF)

if(DOCUMENTATION OR DOCUMENTATION STREQUAL "publish")
  set(DASHBOARD_ENABLE_DOCUMENTATION ON)
endif()

if(NOT DEFINED ENV{ghprbPullId})
  set(DASHBOARD_LONG_RUNNING_TESTS ON)
endif()

# Include additional configuration information
include(${DASHBOARD_DRIVER_DIR}/configurations/packages.cmake)
include(${DASHBOARD_DRIVER_DIR}/configurations/timeout.cmake)

if(NOT MINIMAL AND NOT OPEN_SOURCE)
  include(${DASHBOARD_DRIVER_DIR}/configurations/aws.cmake)
endif()

# Set up diagnostic tools
if(COMPILER STREQUAL "include-what-you-use")
  include(${DASHBOARD_DRIVER_DIR}/configurations/include-what-you-use.cmake)
elseif(COMPILER STREQUAL "link-what-you-use")
  include(${DASHBOARD_DRIVER_DIR}/configurations/link-what-you-use.cmake)
elseif(COMPILER STREQUAL "scan-build")
  include(${DASHBOARD_DRIVER_DIR}/configurations/scan-build.cmake)
endif()

if(COVERAGE)
  include(${DASHBOARD_DRIVER_DIR}/configurations/coverage.cmake)
endif()

if(MEMCHECK MATCHES "^(asan|lsan|msan|tsan|ubsan|valgrind)$")
  include(${DASHBOARD_DRIVER_DIR}/configurations/memcheck.cmake)
endif()

# Clean out the old builds and/or installs
file(REMOVE_RECURSE "${CTEST_BINARY_DIRECTORY}")
file(MAKE_DIRECTORY "${CTEST_BINARY_DIRECTORY}")
file(REMOVE_RECURSE "${DASHBOARD_INSTALL_PREFIX}")

# Prepare initial cache
cache_flag(C_FLAGS STRING)
cache_flag(CXX_FLAGS STRING)
cache_flag(CXX_STANDARD STRING EXTRA "CMAKE_CXX_STANDARD_REQUIRED:BOOL=ON")
cache_flag(FORTRAN_FLAGS STRING NAMES CMAKE_Fortran_FLAGS)
cache_flag(STATIC_LINKER_FLAGS STRING)
cache_flag(SHARED_LINKER_FLAGS STRING NAMES
  CMAKE_EXE_LINKER_FLAGS
  CMAKE_SHARED_LINKER_FLAGS)
cache_flag(INCLUDE_WHAT_YOU_USE STRING NAMES
  CMAKE_C_INCLUDE_WHAT_YOU_USE
  CMAKE_CXX_INCLUDE_WHAT_YOU_USE)
cache_flag(LINK_WHAT_YOU_USE BOOL)
cache_flag(POSITION_INDEPENDENT_CODE BOOL)
cache_flag(INSTALL_PREFIX PATH)
cache_flag(VERBOSE_MAKEFILE BOOL)
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

  if(NOT DASHBOARD_FAILURE)
    # Build the post-drake superbuild
    execute_step(generic post-drake)
  endif()
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

  if(DASHBOARD_WARNING)
    if(COMPILER MATCHES "^((include|link)-what-you-use|scan-build)$")
      append_step_status("STATIC ANALYSIS TOOL" UNSTABLE)
    endif()
  endif()

  if(DASHBOARD_TEST)
    if(NOT DASHBOARD_TEST_RETURN_VALUE EQUAL 0)
      append_step_status("DRAKE TEST" UNSTABLE)
    endif()

    if(NOT DASHBOARD_SUPERBUILD_TEST_RETURN_VALUE EQUAL 0)
      append_step_status("SUPERBUILD TEST" UNSTABLE)
    endif()
  endif()

  # if(DASHBOARD_COVERAGE AND NOT DASHBOARD_COVERAGE_RETURN_VALUE EQUAL 0)  # FIXME #3269
  #   append_step_status("COVERAGE TOOL" UNSTABLE)
  # endif()

  if(DASHBOARD_MEMCHECK AND (NOT DASHBOARD_MEMCHECK_RETURN_VALUE EQUAL 0 OR NOT DASHBOARD_MEMCHECK_DEFECT_COUNT EQUAL 0))
    append_step_status("MEMCHECK TOOL" UNSTABLE)
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
