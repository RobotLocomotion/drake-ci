# -*- mode: cmake; -*-
# vi: set ft=cmake:

report_configuration(".38
  ==================================== ENV
  CC
  CXX
  ==================================== >DASHBOARD_
  CC_COMMAND
  CC_VERSION_STRING
  CXX_COMMAND
  CXX_VERSION_STRING
  ==================================== >DASHBOARD_
  UNIX
  UNIX_DISTRIBUTION
  UNIX_DISTRIBUTION_CODE_NAME
  UNIX_DISTRIBUTION_VERSION
  APPLE
  ====================================
  CMAKE_VERSION
  ====================================
  CTEST_BUILD_NAME(DASHBOARD_JOB_NAME)
  CTEST_CHANGE_ID
  CTEST_BUILD_FLAGS
  CTEST_CMAKE_GENERATOR
  CTEST_CONFIGURATION_TYPE
  CTEST_GIT_COMMAND
  CTEST_SITE
  CTEST_TEST_TIMEOUT
  CTEST_UPDATE_COMMAND
  CTEST_UPDATE_VERSION_ONLY
  CTEST_USE_LAUNCHERS
  ====================================
  ")
