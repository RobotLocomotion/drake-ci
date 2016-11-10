# Report build configuration
report_configuration("
  ==================================== >DASHBOARD_
  UNIX
  UNIX_DISTRIBUTION
  UNIX_DISTRIBUTION_VERSION
  APPLE
  ====================================
  CMAKE_VERSION
  ====================================
  CTEST_BUILD_NAME(DASHBOARD_BUILD_NAME)
  CTEST_CHANGE_ID
  CTEST_BUILD_FLAGS
  CTEST_CMAKE_GENERATOR
  CTEST_CONFIGURATION_TYPE
  CTEST_CONFIGURE_COMMAND
  CTEST_GIT_COMMAND
  CTEST_SITE
  CTEST_UPDATE_COMMAND
  CTEST_UPDATE_VERSION_ONLY
  ====================================
  ")

set(DASHBOARD_CDASH_SERVER "drake-cdash.csail.mit.edu")
set(DASHBOARD_NIGHTLY_START_TIME "00:00:00 EST")

set(DASHBOARD_SUPERBUILD_FAILURE OFF)

include(${DASHBOARD_DRIVER_DIR}/configurations/cpplint/step-download.cmake)

if(DASHBOARD_SUPERBUILD_FAILURE)
  notice("CTest Status: NOT CONTINUING BECAUSE SUPERBUILD WAS NOT SUCCESSFUL")
else()
  include(${DASHBOARD_DRIVER_DIR}/configurations/cpplint/step-lint.cmake)
endif()

include(${DASHBOARD_DRIVER_DIR}/configurations/common/step-report.cmake)
