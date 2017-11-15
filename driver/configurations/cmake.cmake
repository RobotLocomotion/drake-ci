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

if(GUROBI OR MOSEK OR SNOPT)
  include(${DASHBOARD_DRIVER_DIR}/configurations/aws.cmake)
endif()

if(GUROBI)
  if(NOT APPLE)
    set(DASHBOARD_GUROBI_DISTRO "$ENV{HOME}/gurobi7.0.2_linux64.tar.gz")

    if(NOT EXISTS "${DASHBOARD_GUROBI_DISTRO}")
      message(STATUS "Downloading GUROBI archive from AWS S3...")
      execute_process(
        COMMAND "${DASHBOARD_AWS_COMMAND}" s3 cp
          s3://drake-provisioning/gurobi/gurobi7.0.2_linux64.tar.gz
          "${DASHBOARD_GUROBI_DISTRO}"
        RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE
        OUTPUT_VARIABLE DASHBOARD_AWS_S3_OUTPUT_VARIABLE
        ERROR_VARIABLE DASHBOARD_AWS_S3_OUTPUT_VARIABLE)
      message("${DASHBOARD_AWS_S3_OUTPUT_VARIABLE}")
    endif()

    if(NOT EXISTS "${DASHBOARD_GUROBI_DISTRO}")
      fatal(WARNING "GUROBI archive was NOT found")
    endif()

    execute_process(
      COMMAND "${CMAKE_COMMAND}" -E tar xzf "${DASHBOARD_GUROBI_DISTRO}"
      WORKING_DIRECTORY $ENV{HOME})
    set(ENV{GUROBI_PATH} "$ENV{HOME}/gurobi702/linux64")
  endif()

  set(DASHBOARD_GUROBI_LICENSE "$ENV{HOME}/gurobi.lic")

  if(NOT EXISTS "${DASHBOARD_GUROBI_LICENSE}")
    message(STATUS "Downloading GUROBI license file from AWS S3...")
    execute_process(
      COMMAND "${DASHBOARD_AWS_COMMAND}" s3 cp
        s3://drake-provisioning/gurobi/gurobi.lic "${DASHBOARD_GUROBI_LICENSE}"
      RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE
      OUTPUT_VARIABLE DASHBOARD_AWS_S3_OUTPUT_VARIABLE
      ERROR_VARIABLE DASHBOARD_AWS_S3_OUTPUT_VARIABLE)
    message("${DASHBOARD_AWS_S3_OUTPUT_VARIABLE}")
  endif()

  if(NOT EXISTS "${DASHBOARD_GUROBI_LICENSE}")
    fatal("GUROBI license file was NOT found")
  endif()

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
  set(DASHBOARD_MOSEK_LICENSE "$ENV{HOME}/mosek/mosek.lic")

  if(NOT EXISTS "${DASHBOARD_MOSEK_LICENSE}")
    message(STATUS "Downloading MOSEK license file from AWS S3...")
    execute_process(COMMAND "${CMAKE_COMMAND}" -E make_directory "$ENV{HOME}/mosek"
      RESULT_VARIABLE MAKE_DIRECTORY_RESULT_VARIABLE
      OUTPUT_VARIABLE MAKE_DIRECTORY_OUTPUT_VARIABLE
      ERROR_VARIABLE MAKE_DIRECTORY_OUTPUT_VARIABLE)
    message("${MAKE_DIRECTORY_OUTPUT_VARIABLE}")
    execute_process(
      COMMAND "${DASHBOARD_AWS_COMMAND}" s3 cp
        s3://drake-provisioning/mosek/mosek.lic "${DASHBOARD_MOSEK_LICENSE}"
      RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE
      OUTPUT_VARIABLE DASHBOARD_AWS_S3_OUTPUT_VARIABLE
      ERROR_VARIABLE DASHBOARD_AWS_S3_OUTPUT_VARIABLE)
    message("${DASHBOARD_AWS_S3_OUTPUT_VARIABLE}")
  endif()

  if(NOT EXISTS "${DASHBOARD_MOSEK_LICENSE}")
    fatal("MOSEK license file was NOT found")
  endif()

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
