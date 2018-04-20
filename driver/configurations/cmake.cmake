# Jenkins passes down an incorrect value of JAVA_HOME from master to agent for
# some inexplicable reason.
unset(ENV{JAVA_HOME})

set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}")
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/_cmake_$ENV{USER}")
set(DASHBOARD_INSTALL_PREFIX "${CTEST_BINARY_DIRECTORY}/install")

set(CTEST_CONFIGURATION_TYPE "${DASHBOARD_CONFIGURATION_TYPE}")
set(CTEST_TEST_TIMEOUT 300)

file(REMOVE_RECURSE "${CTEST_BINARY_DIRECTORY}")
file(MAKE_DIRECTORY "${CTEST_BINARY_DIRECTORY}")
file(REMOVE_RECURSE "${DASHBOARD_INSTALL_PREFIX}")

include(${DASHBOARD_DRIVER_DIR}/configurations/aws.cmake)
include(${DASHBOARD_DRIVER_DIR}/configurations/gurobi.cmake)
include(${DASHBOARD_DRIVER_DIR}/configurations/mosek.cmake)

if(GUROBI)
  set(DASHBOARD_WITH_GUROBI ON)
else()
  set(DASHBOARD_WITH_GUROBI OFF)
endif()

if(MATLAB)
  set(DASHBOARD_WITH_MATLAB ON)
else()
  set(DASHBOARD_WITH_MATLAB OFF)
endif()

if(MOSEK)
  set(DASHBOARD_WITH_MOSEK ON)
else()
  set(DASHBOARD_WITH_MOSEK OFF)
endif()

if(SNOPT)
  set(DASHBOARD_WITH_SNOPT ON)
else()
  set(DASHBOARD_WITH_SNOPT OFF)
endif()

cache_flag(INSTALL_PREFIX PATH)
cache_append(WITH_GUROBI BOOL ${DASHBOARD_WITH_GUROBI})
cache_append(WITH_MATLAB BOOL ${DASHBOARD_WITH_MATLAB})
cache_append(WITH_MOSEK BOOL ${DASHBOARD_WITH_MOSEK})
cache_append(WITH_SNOPT BOOL ${DASHBOARD_WITH_SNOPT})

file(COPY "${DASHBOARD_CI_DIR}/.bazelrc"
  DESTINATION "${DASHBOARD_SOURCE_DIRECTORY}")

file(APPEND "${DASHBOARD_SOURCE_DIRECTORY}/.bazelrc"
  "startup --output_user_root=${DASHBOARD_WORKSPACE}/_bazel_$ENV{USER}\n")

if(APPLE)
  file(APPEND "${DASHBOARD_SOURCE_DIRECTORY}/.bazelrc"
    "build --python_path=/usr/local/opt/python/libexec/bin/python\n")
endif()

report_configuration("
  ==================================== ENV
  CC
  CXX
  ==================================== >DASHBOARD_
  UNIX
  UNIX_DISTRIBUTION
  UNIX_DISTRIBUTION_VERSION
  APPLE
  ====================================
  CMAKE_VERSION
  ==================================== >DASHBOARD_ <CMAKE_
  INSTALL_PREFIX
  ====================================
  CTEST_BUILD_NAME(DASHBOARD_BUILD_NAME)
  CTEST_BINARY_DIRECTORY
  CTEST_BUILD_FLAGS
  CTEST_CHANGE_ID
  CTEST_CMAKE_GENERATOR
  CTEST_CONFIGURATION_TYPE
  CTEST_GIT_COMMAND
  CTEST_SITE
  CTEST_SOURCE_DIRECTORY
  CTEST_TEST_TIMEOUT
  CTEST_UPDATE_COMMAND
  CTEST_UPDATE_VERSION_ONLY
  CTEST_USE_LAUNCHERS
  ==================================== >DASHBOARD_
  WITH_GUROBI
  WITH_MATLAB
  WITH_MOSEK
  WITH_SNOPT
  ====================================
  ")

execute_step(cmake build)

if(NOT DASHBOARD_FAILURE)
  format_plural(DASHBOARD_MESSAGE
    ZERO "SUCCESS"
    ONE "SUCCESS BUT WITH 1 BUILD WARNING"
    MANY "SUCCESS BUT WITH # BUILD WARNINGS"
    ${DASHBOARD_BUILD_NUMBER_WARNINGS})

  if(MATLAB AND (NOT DASHBOARD_TEST_RETURN_VALUE EQUAL 0 OR DASHBOARD_TEST_CAPTURE_CMAKE_ERROR EQUAL -1))
    append_step_status("CMAKE TEST" UNSTABLE)
  endif()
endif()

execute_step(common report-status)
