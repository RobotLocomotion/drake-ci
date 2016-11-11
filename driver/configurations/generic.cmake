# Set base configuration
set(CTEST_USE_LAUNCHERS ON)
set(ENV{CTEST_USE_LAUNCHERS_DEFAULT} 1)

set(DASHBOARD_COVERAGE OFF)
set(DASHBOARD_MEMCHECK OFF)
set(DASHBOARD_LINK_WHAT_YOU_USE OFF)

set(DASHBOARD_BUILD_DOCUMENTATION OFF)
set(DASHBOARD_LONG_RUNNING_TESTS OFF)

if(DOCUMENTATION OR DOCUMENTATION STREQUAL "publish")
  set(DASHBOARD_BUILD_DOCUMENTATION ON)
endif()

if(NOT DEFINED ENV{ghprbPullId})
  set(DASHBOARD_LONG_RUNNING_TESTS ON)
endif()

# Include additional configuration information
include(${DASHBOARD_DRIVER_DIR}/configurations/packages.cmake)
include(${DASHBOARD_DRIVER_DIR}/configurations/timeout.cmake)

if(NOT MINIMAL AND NOT OPEN_SOURCE AND NOT COMPILER STREQUAL "cpplint")
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

if(MEMCHECK MATCHES "^([amt]san|valgrind)$")
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
cache_append(BUILD_DOCUMENTATION BOOL ${DASHBOARD_BUILD_DOCUMENTATION})
cache_append(BUILD_DOCUMENTATION_ALWAYS BOOL ${DASHBOARD_BUILD_DOCUMENTATION})
cache_append(LONG_RUNNING_TESTS BOOL ${DASHBOARD_LONG_RUNNING_TESTS})
cache_append(SKIP_DRAKE_BUILD BOOL ON)

# Report build configuration
report_configuration(".38
  ==================================== ENV
  CC
  CCC_CC
  CCC_CXX
  CXX
  F77
  FC
  ==================================== ENV
  GTEST_DEATH_TEST_USE_FORK
  ==================================== ENV
  ROS_DISTRO
  ROS_ETC_DIR
  ROS_HOME
  ROS_MASTER_URI
  ROS_PACKAGE_PATH
  ROS_ROOT
  ==================================== >DASHBOARD_
  UNIX
  UNIX_DISTRIBUTION
  UNIX_DISTRIBUTION_VERSION
  APPLE
  ====================================
  CMAKE_VERSION
  ==================================== >DASHBOARD_ <CMAKE_
  C_FLAGS
  CXX_FLAGS
  CXX_STANDARD
  FORTRAN_FLAGS
  INSTALL_PREFIX
  INCLUDE_WHAT_YOU_USE
  LINK_WHAT_YOU_USE
  POSITION_INDEPENDENT_CODE
  EXE_LINKER_FLAGS(SHARED_LINKER_FLAGS)
  SHARED_LINKER_FLAGS
  STATIC_LINKER_FLAGS
  VERBOSE_MAKEFILE
  ====================================
  CTEST_BUILD_NAME(DASHBOARD_BUILD_NAME)
  CTEST_CHANGE_ID
  CTEST_BUILD_FLAGS
  CTEST_CMAKE_GENERATOR
  CTEST_CONFIGURATION_TYPE
  CTEST_CONFIGURE_COMMAND
  CTEST_COVERAGE_COMMAND
  CTEST_COVERAGE_EXTRA_FLAGS
  CTEST_GIT_COMMAND
  CTEST_MEMORYCHECK_COMMAND
  CTEST_MEMORYCHECK_COMMAND_OPTIONS
  CTEST_MEMORYCHECK_SUPPRESSIONS_FILE
  CTEST_MEMORYCHECK_TYPE
  CTEST_SITE
  CTEST_TEST_TIMEOUT
  CTEST_UPDATE_COMMAND
  CTEST_UPDATE_VERSION_ONLY
  CTEST_USE_LAUNCHERS
  ==================================== >DASHBOARD_
  BUILD_DOCUMENTATION
  LONG_RUNNING_TESTS
  TEST_TIMEOUT_MULTIPLIER
  ==================================== <WITH_ >DASHBOARD_WITH_
  ${DASHBOARD_PACKAGES}
  ====================================
  ")

set(DASHBOARD_CDASH_SERVER "drake-cdash.csail.mit.edu")
set(DASHBOARD_NIGHTLY_START_TIME "00:00:00 EST")

set(DASHBOARD_SUPERBUILD_FAILURE OFF)

set(DASHBOARD_SUPERBUILD_PROJECT_NAME "drake-superbuild")

set(CTEST_BUILD_NAME "${DASHBOARD_BUILD_NAME}-pre-drake")
set(CTEST_PROJECT_NAME "${DASHBOARD_SUPERBUILD_PROJECT_NAME}")
set(CTEST_NIGHTLY_START_TIME "${DASHBOARD_NIGHTLY_START_TIME}")
set(CTEST_DROP_METHOD "https")
set(CTEST_DROP_SITE "${DASHBOARD_CDASH_SERVER}")
set(CTEST_DROP_LOCATION
  "/submit.php?project=${DASHBOARD_SUPERBUILD_PROJECT_NAME}")
set(CTEST_DROP_SITE_CDASH ON)

notice("CTest Status: CONFIGURING / BUILDING SUPERBUILD")

ctest_start("${DASHBOARD_MODEL}" TRACK "${DASHBOARD_TRACK}" QUIET)
ctest_update(SOURCE "${CTEST_SOURCE_DIRECTORY}"
  RETURN_VALUE DASHBOARD_SUPERBUILD_UPDATE_RETURN_VALUE QUIET)

# write initial cache
file(WRITE "${CTEST_BINARY_DIRECTORY}/CMakeCache.txt" "${CACHE_CONTENT}")

ctest_configure(BUILD "${CTEST_BINARY_DIRECTORY}"
  SOURCE "${CTEST_SOURCE_DIRECTORY}"
  RETURN_VALUE DASHBOARD_SUPERBUILD_CONFIGURE_RETURN_VALUE QUIET)
if(NOT DASHBOARD_SUPERBUILD_CONFIGURE_RETURN_VALUE EQUAL 0)
  set(DASHBOARD_FAILURE ON)
  list(APPEND DASHBOARD_FAILURES "CONFIGURE SUPERBUILD (PRE-DRAKE)")
endif()

ctest_build(BUILD "${CTEST_BINARY_DIRECTORY}" APPEND
  NUMBER_ERRORS DASHBOARD_SUPERBUILD_NUMBER_BUILD_ERRORS QUIET)
if(DASHBOARD_SUPERBUILD_NUMBER_BUILD_ERRORS GREATER 0)
  set(DASHBOARD_FAILURE ON)
  list(APPEND DASHBOARD_FAILURES "BUILD SUPERBUILD (PRE-DRAKE)")
endif()

set(DASHBOARD_BUILD_URL_FILE
  "${CTEST_BINARY_DIRECTORY}/${DASHBOARD_BUILD_NAME}.url")
file(WRITE "${DASHBOARD_BUILD_URL_FILE}" "$ENV{BUILD_URL}")
ctest_upload(FILES "${DASHBOARD_BUILD_URL_FILE}" QUIET)

ctest_submit(RETRY_COUNT 4 RETRY_DELAY 15
  RETURN_VALUE DASHBOARD_SUPERBUILD_SUBMIT_RETURN_VALUE QUIET)

set(DASHBOARD_SUPERBUILD_FAILURE ${DASHBOARD_FAILURE})

set(DASHBOARD_STEPS "")
list(APPEND DASHBOARD_STEPS "CONFIGURING")
list(APPEND DASHBOARD_STEPS "BUILDING")
if(DASHBOARD_INSTALL)
  list(APPEND DASHBOARD_STEPS "INSTALLING")
endif()
if(DASHBOARD_TEST)
  list(APPEND DASHBOARD_STEPS "TESTING")
endif()
string(REPLACE ";" " / " DASHBOARD_STEPS_STRING "${DASHBOARD_STEPS}")

if(DASHBOARD_SUPERBUILD_FAILURE)
  notice("CTest Status: NOT CONTINUING BECAUSE SUPERBUILD (PRE-DRAKE) WAS NOT SUCCESSFUL")
else()
  set(DASHBOARD_PROJECT_NAME "Drake")

  # now start the actual drake build
  set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_WORKSPACE}/drake")
  set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/build/drake")

  # switch the dashboard to the drake only dashboard
  set(CTEST_BUILD_NAME "${DASHBOARD_BUILD_NAME}-drake")
  set(CTEST_PROJECT_NAME "${DASHBOARD_PROJECT_NAME}")
  set(CTEST_NIGHTLY_START_TIME "${DASHBOARD_NIGHTLY_START_TIME}")
  set(CTEST_DROP_METHOD "https")
  set(CTEST_DROP_SITE "${DASHBOARD_CDASH_SERVER}")
  set(CTEST_DROP_LOCATION "/submit.php?project=${DASHBOARD_PROJECT_NAME}")
  set(CTEST_DROP_SITE_CDASH ON)

  if(COMPILER STREQUAL "scan-build")
    file(REMOVE_RECURSE "${DASHBOARD_CCC_ANALYZER_HTML}")
    file(MAKE_DIRECTORY "${DASHBOARD_CCC_ANALYZER_HTML}")
  endif()

  notice("CTest Status: ${DASHBOARD_STEPS_STRING} DRAKE")

  ctest_start("${DASHBOARD_MODEL}" TRACK "${DASHBOARD_TRACK}" QUIET)
  ctest_update(SOURCE "${CTEST_SOURCE_DIRECTORY}"
    RETURN_VALUE DASHBOARD_UPDATE_RETURN_VALUE QUIET)

  set(DRAKE_CACHE_ARGS "")
  set(DRAKE_CACHE_VARS
    CACHE_BUILD_DOCUMENTATION_ALWAYS
    CACHE_BUILD_DOCUMENTATION
    CACHE_VERBOSE_MAKEFILE
    CACHE_LONG_RUNNING_TESTS
    CACHE_TEST_TIMEOUT_MULTIPLIER
    CACHE_C_INCLUDE_WHAT_YOU_USE
    CACHE_CXX_INCLUDE_WHAT_YOU_USE
    CACHE_LINK_WHAT_YOU_USE
    CACHE_POSITION_INDEPENDENT_CODE
  )
  foreach(DRAKE_CACHE_VAR ${DRAKE_CACHE_VARS})
    if(NOT ${DRAKE_CACHE_VAR} STREQUAL "")
      list(APPEND DRAKE_CACHE_ARGS "-D${${DRAKE_CACHE_VAR}}")
    endif()
  endforeach()
  ctest_configure(BUILD "${CTEST_BINARY_DIRECTORY}"
    OPTIONS "${DRAKE_CACHE_ARGS}"
    SOURCE "${CTEST_SOURCE_DIRECTORY}"
    RETURN_VALUE DASHBOARD_CONFIGURE_RETURN_VALUE QUIET)
  if(NOT DASHBOARD_CONFIGURE_RETURN_VALUE EQUAL 0)
    set(DASHBOARD_FAILURE ON)
    list(APPEND DASHBOARD_FAILURES "CONFIGURE")
  endif()

  ctest_read_custom_files("${CTEST_BINARY_DIRECTORY}")

  if(COMPILER MATCHES "^(include|link)-what-you-use")
    set(CTEST_CUSTOM_MAXIMUM_NUMBER_OF_ERRORS 1000)
    set(CTEST_CUSTOM_MAXIMUM_NUMBER_OF_WARNINGS 1000)
  else()
    set(CTEST_CUSTOM_MAXIMUM_NUMBER_OF_ERRORS 100)
    set(CTEST_CUSTOM_MAXIMUM_NUMBER_OF_WARNINGS 100)
  endif()

  if(MATLAB)
    set(CTEST_CUSTOM_MAXIMUM_FAILED_TEST_OUTPUT_SIZE 307200)
    set(CTEST_CUSTOM_MAXIMUM_PASSED_TEST_OUTPUT_SIZE 307200)
  endif()

  ctest_build(APPEND NUMBER_ERRORS DASHBOARD_NUMBER_BUILD_ERRORS
    NUMBER_WARNINGS DASHBOARD_NUMBER_BUILD_WARNINGS QUIET)
  if(DASHBOARD_NUMBER_BUILD_ERRORS GREATER 0)
    set(DASHBOARD_FAILURE ON)
    list(APPEND DASHBOARD_FAILURES "BUILD")
  endif()

  if(DASHBOARD_FAILURE)
    notice("CTest Status: NOT CONTINUING BECAUSE BUILD WAS NOT SUCCESSFUL")

    set(DASHBOARD_INSTALL OFF)
    set(DASHBOARD_TEST OFF)
    set(DASHBOARD_COVERAGE OFF)
    set(DASHBOARD_MEMCHECK OFF)
  endif()

  if(DASHBOARD_INSTALL)
    ctest_submit(RETRY_COUNT 4 RETRY_DELAY 15
      RETURN_VALUE DASHBOARD_SUBMIT_RETURN_VALUE QUIET)
    ctest_build(TARGET "install" APPEND
      RETURN_VALUE DASHBOARD_INSTALL_RETURN_VALUE QUIET)
    if(DASHBOARD_INSTALL AND NOT DASHBOARD_INSTALL_RETURN_VALUE EQUAL 0)
      set(DASHBOARD_FAILURE ON)
      list(APPEND DASHBOARD_FAILURES "INSTALL")
    endif()
  endif()

  if(DASHBOARD_TEST)
    ctest_test(BUILD "${CTEST_BINARY_DIRECTORY}" ${CTEST_TEST_ARGS}
      RETURN_VALUE DASHBOARD_TEST_RETURN_VALUE QUIET)
  endif()

  if(DASHBOARD_COVERAGE)
    ctest_coverage(RETURN_VALUE DASHBOARD_COVERAGE_RETURN_VALUE QUIET)
  endif()

  if(DASHBOARD_MEMCHECK)
    ctest_memcheck(RETURN_VALUE DASHBOARD_MEMCHECK_RETURN_VALUE QUIET)
  endif()

  # upload the Jenkins job URL to add link on CDash
  set(DASHBOARD_BUILD_URL_FILE
    "${CTEST_BINARY_DIRECTORY}/${DASHBOARD_BUILD_NAME}.url")
  file(WRITE "${DASHBOARD_BUILD_URL_FILE}" "$ENV{BUILD_URL}")
  ctest_upload(FILES "${DASHBOARD_BUILD_URL_FILE}" QUIET)

  ctest_submit(RETRY_COUNT 4 RETRY_DELAY 15
    RETURN_VALUE DASHBOARD_SUBMIT_RETURN_VALUE QUIET)

  if(NOT DASHBOARD_FAILURE)
    set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_WORKSPACE}")
    set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/build")

    set(CTEST_BUILD_NAME "${DASHBOARD_BUILD_NAME}-post-drake")
    set(CTEST_PROJECT_NAME "${DASHBOARD_SUPERBUILD_PROJECT_NAME}")
    set(CTEST_NIGHTLY_START_TIME "${DASHBOARD_NIGHTLY_START_TIME}")
    set(CTEST_DROP_METHOD "https")
    set(CTEST_DROP_SITE "${DASHBOARD_CDASH_SERVER}")
    set(CTEST_DROP_LOCATION
      "/submit.php?project=${DASHBOARD_SUPERBUILD_PROJECT_NAME}")
    set(CTEST_DROP_SITE_CDASH ON)

    ctest_start("${DASHBOARD_MODEL}" TRACK "${DASHBOARD_TRACK}" QUIET)

    ctest_configure(BUILD "${CTEST_BINARY_DIRECTORY}"
      OPTIONS "-DSKIP_DRAKE_BUILD:BOOL=OFF"
      SOURCE "${CTEST_SOURCE_DIRECTORY}"
      RETURN_VALUE DASHBOARD_SUPERBUILD_CONFIGURE_RETURN_VALUE QUIET)
    if(NOT DASHBOARD_SUPERBUILD_CONFIGURE_RETURN_VALUE EQUAL 0)
      set(DASHBOARD_FAILURE ON)
      list(APPEND DASHBOARD_FAILURES "CONFIGURE SUPERBUILD (POST-DRAKE)")
    endif()

    ctest_build(BUILD "${CTEST_BINARY_DIRECTORY}" APPEND
      NUMBER_ERRORS DASHBOARD_SUPERBUILD_NUMBER_BUILD_ERRORS QUIET)
    if(DASHBOARD_SUPERBUILD_NUMBER_BUILD_ERRORS GREATER 0)
      set(DASHBOARD_FAILURE ON)
      list(APPEND DASHBOARD_FAILURES "BUILD SUPERBUILD (POST-DRAKE)")
    endif()

    set(DASHBOARD_BUILD_URL_FILE
      "${CTEST_BINARY_DIRECTORY}/${DASHBOARD_BUILD_NAME}.url")
    file(WRITE "${DASHBOARD_BUILD_URL_FILE}" "$ENV{BUILD_URL}")
    ctest_upload(FILES "${DASHBOARD_BUILD_URL_FILE}" QUIET)

    ctest_submit(RETRY_COUNT 4 RETRY_DELAY 15
      RETURN_VALUE DASHBOARD_SUPERBUILD_SUBMIT_RETURN_VALUE QUIET)
  endif()
endif()

# Determine build result
set(DASHBOARD_WARNING OFF)

if(DASHBOARD_FAILURE)
  string(REPLACE ";" " / " DASHBOARD_FAILURES_STRING "${DASHBOARD_FAILURES}")
  set(DASHBOARD_MESSAGE "FAILURE DURING ${DASHBOARD_FAILURES_STRING}")
  file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
else()
  format_plural(DASHBOARD_MESSAGE
    ZERO "SUCCESS"
    ONE "SUCCESS BUT WITH 1 BUILD WARNING"
    MANY "SUCCESS BUT WITH # BUILD WARNINGS"
    DASHBOARD_NUMBER_BUILD_WARNINGS)
  if(DASHBOARD_NUMBER_BUILD_WARNINGS GREATER 0)
    set(DASHBOARD_WARNING ON)
  endif()

  set(DASHBOARD_UNSTABLE OFF)
  set(DASHBOARD_UNSTABLES "")

  if(DASHBOARD_WARNING)
    if(COMPILER MATCHES "^((include|link)-what-you-use|scan-build)")
      set(DASHBOARD_UNSTABLE ON)
      list(APPEND DASHBOARD_UNSTABLES "STATIC ANALYSIS TOOL")
    endif()
  endif()

  if(DASHBOARD_TEST AND NOT DASHBOARD_TEST_RETURN_VALUE EQUAL 0)
    set(DASHBOARD_UNSTABLE ON)
    list(APPEND DASHBOARD_UNSTABLES "TEST")
  endif()

  # if(DASHBOARD_COVERAGE AND NOT DASHBOARD_COVERAGE_RETURN_VALUE EQUAL 0)  # FIXME #3269
  #   set(DASHBOARD_UNSTABLE ON)
  #   list(APPEND DASHBOARD_UNSTABLES "COVERAGE TOOL")
  # endif()

  if(DASHBOARD_MEMCHECK AND NOT DASHBOARD_MEMCHECK_RETURN_VALUE EQUAL 0)
    set(DASHBOARD_UNSTABLE ON)
    list(APPEND DASHBOARD_UNSTABLES "MEMCHECK TOOL")
  endif()

  if(DASHBOARD_UNSTABLE)
    string(REPLACE ";" " / " DASHBOARD_UNSTABLES_STRING "${DASHBOARD_UNSTABLES}")
    set(DASHBOARD_MESSAGE
      "UNSTABLE DUE TO ${DASHBOARD_UNSTABLES_STRING} FAILURES")
    file(WRITE "${DASHBOARD_WORKSPACE}/UNSTABLE")
  else()
    file(WRITE "${DASHBOARD_WORKSPACE}/SUCCESS")
  endif()
endif()

# Publish documentation, if requested, and if build succeeded
if(DOCUMENTATION STREQUAL "publish")
  if(DASHBOARD_FAILURE OR DASHBOARD_UNSTABLE)
    set(DASHBOARD_PUBLISH_DOCUMENTATION OFF)
    notice("CTest Status: NOT PUBLISHING DOCUMENTATION BECAUSE BUILD WAS NOT SUCCESSFUL")
  else()
    set(DASHBOARD_PUBLISH_DOCUMENTATION ON)
    notice("CTest Status: PUBLISHING DOCUMENTATION")
  endif()
  if(DASHBOARD_PUBLISH_DOCUMENTATION)
    execute_process(COMMAND "${DASHBOARD_TOOLS_DIR}/publish_documentation.bash"
      WORKING_DIRECTORY "${DASHBOARD_WORKSPACE}"
      RESULT_VARIABLE DASHBOARD_PUBLISH_DOCUMENTATION_RESULT_VARIABLE
      OUTPUT_VARIABLE DASHBOARD_PUBLISH_DOCUMENTATION_OUTPUT_VARIABLE
      ERROR_VARIABLE DASHBOARD_PUBLISH_DOCUMENTATION_OUTPUT_VARIABLE)
    message("${DASHBOARD_PUBLISH_DOCUMENTATION_OUTPUT_VARIABLE}")
    if(NOT DASHBOARD_PUBLISH_DOCUMENTATION_RESULT_VARIABLE EQUAL 0)
      set(DASHBOARD_UNSTABLE ON)
      set(DASHBOARD_MESSAGE "UNSTABLE DUE TO FAILURE PUBLISHING DOCUMENTATION")
      file(REMOVE "${DASHBOARD_WORKSPACE}/SUCCESS")
      file(WRITE "${DASHBOARD_WORKSPACE}/UNSTABLE")
    endif()
  endif()
endif()

# Report dashboard status
include(${DASHBOARD_DRIVER_DIR}/configurations/common/step-report.cmake)

# Touch "warm" file
if(NOT APPLE AND NOT DASHBOARD_WARM)
  file(WRITE "${DASHBOARD_WARM_FILE}")
endif()
