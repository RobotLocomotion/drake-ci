set(DASHBOARD_PROJECT_NAME "Drake")

set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_WORKSPACE}/drake")
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/build/drake")

# Identify actions to be performed and report what we are doing
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

notice("CTest Status: ${DASHBOARD_STEPS_STRING} DRAKE")

# Switch the dashboard to the drake only dashboard
# TODO remove when subprojects arrive
set(CTEST_BUILD_NAME "${DASHBOARD_BUILD_NAME}-drake")
set(CTEST_PROJECT_NAME "${DASHBOARD_PROJECT_NAME}")
set(CTEST_NIGHTLY_START_TIME "${DASHBOARD_NIGHTLY_START_TIME}")
set(CTEST_DROP_METHOD "https")
set(CTEST_DROP_SITE "${DASHBOARD_CDASH_SERVER}")
set(CTEST_DROP_LOCATION "/submit.php?project=${DASHBOARD_PROJECT_NAME}")
set(CTEST_DROP_SITE_CDASH ON)

# Clean out old scan-build output
if(COMPILER STREQUAL "scan-build")
  file(REMOVE_RECURSE "${DASHBOARD_CCC_ANALYZER_HTML}")
  file(MAKE_DIRECTORY "${DASHBOARD_CCC_ANALYZER_HTML}")
endif()

# Set up the build and update the sources
ctest_start("${DASHBOARD_MODEL}" TRACK "${DASHBOARD_TRACK}" QUIET)
ctest_update(SOURCE "${CTEST_SOURCE_DIRECTORY}"
  RETURN_VALUE DASHBOARD_UPDATE_RETURN_VALUE QUIET)

# Add any needed overrides to the cache and reconfigure
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

# Set up some testing parameters
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

# Run the build
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

# Run tests, coverage, etc.
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

# Upload the Jenkins job URL to add link on CDash
set(DASHBOARD_BUILD_URL_FILE
  "${CTEST_BINARY_DIRECTORY}/${DASHBOARD_BUILD_NAME}.url")
file(WRITE "${DASHBOARD_BUILD_URL_FILE}" "$ENV{BUILD_URL}")
ctest_upload(FILES "${DASHBOARD_BUILD_URL_FILE}" QUIET)

# Submit the results
ctest_submit(RETRY_COUNT 4 RETRY_DELAY 15
  RETURN_VALUE DASHBOARD_SUBMIT_RETURN_VALUE QUIET)
