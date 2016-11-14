# Report build configuration
message("
  ------------------------------------------------------------------------------
  APPLE                               = ${DASHBOARD_APPLE}
  UNIX                                = ${DASHBOARD_UNIX}
  ------------------------------------------------------------------------------
  CMAKE_VERSION                       = ${CMAKE_VERSION}
  ------------------------------------------------------------------------------
  CTEST_BUILD_NAME                    = ${DASHBOARD_BUILD_NAME}
  CTEST_CHANGE_ID                     = ${CTEST_CHANGE_ID}
  CTEST_BUILD_FLAGS                   = ${CTEST_BUILD_FLAGS}
  CTEST_CMAKE_GENERATOR               = ${CTEST_CMAKE_GENERATOR}
  CTEST_CONFIGURATION_TYPE            = ${CTEST_CONFIGURATION_TYPE}
  CTEST_CONFIGURE_COMMAND             = ${CTEST_CONFIGURE_COMMAND}
  CTEST_GIT_COMMAND                   = ${CTEST_GIT_COMMAND}
  CTEST_SITE                          = ${CTEST_SITE}
  CTEST_UPDATE_COMMAND                = ${CTEST_UPDATE_COMMAND}
  CTEST_UPDATE_VERSION_ONLY           = ${CTEST_UPDATE_VERSION_ONLY}
  CTEST_USE_LAUNCHERS                 = ${CTEST_USE_LAUNCHERS}
  ------------------------------------------------------------------------------
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
