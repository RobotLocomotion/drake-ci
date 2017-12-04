# Jenkins passes down an incorrect value of JAVA_HOME from master to agent for
# some inexplicable reason.
unset(ENV{JAVA_HOME})

set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}")
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/_bazel_$ENV{USER}")

find_program(DASHBOARD_BAZEL_COMMAND NAMES bazel)
if(NOT DASHBOARD_BAZEL_COMMAND)
  fatal("bazel was not found")
endif()

# Extract the version. Usually of the form x.y.z-*.
execute_process(COMMAND ${DASHBOARD_BAZEL_COMMAND} version
  RESULT_VARIABLE DASHBOARD_BAZEL_VERSION_RESULT_VARIABLE
  OUTPUT_VARIABLE DASHBOARD_BAZEL_VERSION_OUTPUT_VARIABLE)

if(DASHBOARD_BAZEL_VERSION_RESULT_VARIABLE EQUAL 0)
  string(REGEX MATCH "Build label: ([0-9a-zA-Z.\\-]+)"
       DASHBOARD_BAZEL_REGEX_MATCH_OUTPUT_VARIABLE
       "${DASHBOARD_BAZEL_VERSION_OUTPUT_VARIABLE}")
  if(DASHBOARD_BAZEL_REGEX_MATCH_OUTPUT_VARIABLE)
    set(DASHBOARD_BAZEL_VERSION "${CMAKE_MATCH_1}")
  endif()
else()
  fatal("could not determine bazel version")
endif()

# Set bazel options
set(DASHBOARD_BAZEL_STARTUP_OPTIONS
  "--output_user_root=${CTEST_BINARY_DIRECTORY}")

set(DASHBOARD_BAZEL_BUILD_OPTIONS "--compilation_mode")

if(DEBUG)
  set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS}=dbg")
else()
  set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS}=opt")
endif()

if(COMPILER STREQUAL "gcc")
  set(DASHBOARD_BAZEL_BUILD_OPTIONS
    "${DASHBOARD_BAZEL_BUILD_OPTIONS} --compiler=gcc${DASHBOARD_GNU_COMPILER_SUFFIX}")
endif()

if(DOCUMENTATION STREQUAL "publish" OR EVERYTHING OR PACKAGE OR SNOPT)
  include(${DASHBOARD_DRIVER_DIR}/configurations/aws.cmake)
endif()

if(EVERYTHING OR PACKAGE OR SNOPT)
  set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --action_env=GIT_SSH")
  if(EVERYTHING)
    if(NOT APPLE)
      set(DASHBOARD_GUROBI_DISTRO "$ENV{HOME}/gurobi7.5.2_linux64.tar.gz")
      if(NOT EXISTS "${DASHBOARD_GUROBI_DISTRO}")
        message(STATUS "Downloading GUROBI archive from AWS S3...")
        execute_process(
          COMMAND "${DASHBOARD_AWS_COMMAND}" s3 cp
            s3://drake-provisioning/gurobi/gurobi7.5.2_linux64.tar.gz
            "${DASHBOARD_GUROBI_DISTRO}"
          RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE
          OUTPUT_VARIABLE DASHBOARD_AWS_S3_OUTPUT_VARIABLE
          ERROR_VARIABLE DASHBOARD_AWS_S3_OUTPUT_VARIABLE)
        message("${DASHBOARD_AWS_S3_OUTPUT_VARIABLE}")
      endif()
      if(EXISTS "${DASHBOARD_GUROBI_DISTRO}")
        execute_process(COMMAND ${CMAKE_COMMAND} -E tar xzf ${DASHBOARD_GUROBI_DISTRO}
          WORKING_DIRECTORY $ENV{HOME})
        set(ENV{GUROBI_PATH} "$ENV{HOME}/gurobi752/linux64")
      else()
        message(WARNING "*** GUROBI archive was NOT found")
      endif()
    endif()
    set(DASHBOARD_GUROBI_LICENSE "$ENV{HOME}/gurobi.lic")
    if(NOT EXISTS "${DASHBOARD_GUROBI_LICENSE}")
      message(STATUS "Downloading GUROBI license file from AWS S3...")
      execute_process(
        COMMAND "${DASHBOARD_AWS_COMMAND}" s3 cp
          s3://drake-provisioning/gurobi/gurobi.lic
          "${DASHBOARD_GUROBI_LICENSE}"
        RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE
        OUTPUT_VARIABLE DASHBOARD_AWS_S3_OUTPUT_VARIABLE
        ERROR_VARIABLE DASHBOARD_AWS_S3_OUTPUT_VARIABLE)
      message("${DASHBOARD_AWS_S3_OUTPUT_VARIABLE}")
    endif()
    if(NOT EXISTS "${DASHBOARD_GUROBI_LICENSE}")
      message(WARNING "*** GUROBI license file was NOT found")
    endif()
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
          s3://drake-provisioning/mosek/mosek.lic
          "${DASHBOARD_MOSEK_LICENSE}"
        RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE
        OUTPUT_VARIABLE DASHBOARD_AWS_S3_OUTPUT_VARIABLE
        ERROR_VARIABLE DASHBOARD_AWS_S3_OUTPUT_VARIABLE)
      message("${DASHBOARD_AWS_S3_OUTPUT_VARIABLE}")
    endif()
    if(NOT EXISTS "${DASHBOARD_MOSEK_LICENSE}")
      message(WARNING "*** MOSEK license file was NOT found")
    endif()
    set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --config=everything")
  endif()
  if(PACKAGE OR SNOPT)
    set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --config=snopt")
  endif()
endif()

set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --keep_going")

if(APPLE)
  set(DASHBOARD_BAZEL_TEST_OPTIONS "--test_timeout=300,1500,4500,-1")
else()
  set(DASHBOARD_BAZEL_TEST_OPTIONS)
endif()

set(MEMCHECK_BAZEL_CONFIG "")
if(MEMCHECK STREQUAL "asan")
  set(MEMCHECK_BAZEL_CONFIG "asan")
elseif(MEMCHECK STREQUAL "lsan")
  set(MEMCHECK_BAZEL_CONFIG "lsan")
elseif(MEMCHECK STREQUAL "msan")
  set(MEMCHECK_BAZEL_CONFIG "msan")
elseif(MEMCHECK STREQUAL "tsan")
  set(MEMCHECK_BAZEL_CONFIG "tsan")
elseif(MEMCHECK STREQUAL "ubsan")
  set(MEMCHECK_BAZEL_CONFIG "ubsan")
elseif(MEMCHECK STREQUAL "valgrind")
  set(MEMCHECK_BAZEL_CONFIG "memcheck")
endif()
if(MEMCHECK_BAZEL_CONFIG)
  if(EVERYTHING)
    string(REPLACE
      "--config=everything"
      "--config=${MEMCHECK_BAZEL_CONFIG}_everything"
      DASHBOARD_BAZEL_BUILD_OPTIONS
      "${DASHBOARD_BAZEL_BUILD_OPTIONS}")
  else()
    set(DASHBOARD_BAZEL_BUILD_OPTIONS
      "${DASHBOARD_BAZEL_BUILD_OPTIONS} --config=${MEMCHECK_BAZEL_CONFIG}")
  endif()
endif()

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
  CTEST_GIT_COMMAND
  CTEST_SITE
  CTEST_UPDATE_COMMAND
  CTEST_UPDATE_VERSION_ONLY
  ==================================== >DASHBOARD_
  BAZEL_COMMAND
  BAZEL_VERSION
  BAZEL_STARTUP_OPTIONS
  BAZEL_BUILD_OPTIONS
  BAZEL_TEST_OPTIONS
  ====================================
  ")

# Run the build
execute_step(bazel build)

# Determine build result
if(NOT DASHBOARD_FAILURE)
  format_plural(DASHBOARD_MESSAGE
    ZERO "SUCCESS"
    ONE "SUCCESS BUT WITH 1 BUILD WARNING"
    MANY "SUCCESS BUT WITH # BUILD WARNINGS"
    ${DASHBOARD_NUMBER_BUILD_WARNINGS})
endif()

# Build and publish documentation, if requested, and if build succeeded.
if(DOCUMENTATION)
  execute_step(bazel build-documentation)
  if(DOCUMENTATION STREQUAL "publish")
    execute_step(bazel publish-documentation)
  endif()
endif()

# Report dashboard status
execute_step(common report-status)
