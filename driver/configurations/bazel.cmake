# Jenkins passes down an incorrect value of JAVA_HOME from master to agent for
# some inexplicable reason.
unset(ENV{JAVA_HOME})

set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}")
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/_bazel_$ENV{USER}")

find_program(DASHBOARD_BAZEL_COMMAND NAMES bazel)
if(NOT DASHBOARD_BAZEL_COMMAND)
  fatal("bazel was not found")
endif()

# Set bazel options
set(DASHBOARD_BAZEL_STARTUP_OPTIONS
  "--output_user_root=${CTEST_BINARY_DIRECTORY}")

# Extract the version. Usually of the form x.y.z-*.
execute_process(COMMAND ${DASHBOARD_BAZEL_COMMAND} ${DASHBOARD_BAZEL_STARTUP_OPTIONS} version
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

set(DASHBOARD_BAZEL_BUILD_OPTIONS "--keep_going --action_env=GIT_SSH --announce_rc --compilation_mode")

if(DEBUG)
  set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS}=dbg")
else()
  set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS}=opt")
endif()

if(COMPILER STREQUAL "gcc")
  set(DASHBOARD_BAZEL_BUILD_OPTIONS
    "${DASHBOARD_BAZEL_BUILD_OPTIONS} --compiler=gcc${DASHBOARD_GNU_COMPILER_SUFFIX}")
endif()

if(DASHBOARD_PROCESSOR_COUNT GREATER 1)
  math(EXPR DASHBOARD_JOBS "3 * ${DASHBOARD_PROCESSOR_COUNT} / 4")
else()
  set(DASHBOARD_JOBS 1)
endif()

set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --jobs=${DASHBOARD_JOBS}")

include(${DASHBOARD_DRIVER_DIR}/configurations/aws.cmake)
include(${DASHBOARD_DRIVER_DIR}/configurations/gurobi.cmake)
include(${DASHBOARD_DRIVER_DIR}/configurations/mosek.cmake)

if(EVERYTHING)
  set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --config=everything --flaky_test_attempts=3")
else()
  if(GUROBI)
    set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --config=gurobi --flaky_test_attempts=3")
  endif()
  if(MOSEK)
    set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --config=mosek")
  endif()
  if(PACKAGE OR SNOPT)
    set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --config=snopt")
  endif()
endif()

if(REMOTE_CACHE)
  set(DASHBOARD_REMOTE_HTTP_CACHE_URL "http://172.31.19.207")
  mktemp(DASHBOARD_FILE_DOWNLOAD_TEMP file_download_XXXXXXXX "temporary download file")
  list(APPEND DASHBOARD_TEMPORARY_FILES DASHBOARD_FILE_DOWNLOAD_TEMP)
  file(DOWNLOAD "${DASHBOARD_REMOTE_HTTP_CACHE_URL}" "${DASHBOARD_FILE_DOWNLOAD_TEMP}"
    STATUS DASHBOARD_DOWNLOAD_STATUS)
  list(GET DASHBOARD_DOWNLOAD_STATUS 0 DASHBOARD_DOWNLOAD_STATUS_0)
  if(DASHBOARD_DOWNLOAD_STATUS_0 EQUAL 0)
    set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --experimental_remote_spawn_cache --remote_http_cache=${DASHBOARD_REMOTE_HTTP_CACHE_URL} --remote_local_fallback")
    if(DEBUG)
       if(APPLE)
        set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --remote_timeout=360")
      else()
        set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --remote_timeout=180")
      endif()
    else()
      if(APPLE)
        set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --remote_timeout=180")
      else()
        set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --remote_timeout=90")
      endif()
    endif()
  else()
    message(WARNING "*** Could NOT contact remote HTTP cache")
  endif()

  if(DASHBOARD_TRACK STREQUAL "Nightly")
    set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --noremote_accept_cached")
  elseif(DASHBOARD_TRACK STREQUAL "Experimental")
    set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS} --noremote_upload_local_results")
  endif()
endif()

set(DASHBOARD_BAZEL_TEST_OPTIONS "--test_summary=short")

if(APPLE)
  set(DASHBOARD_BAZEL_TEST_OPTIONS "${DASHBOARD_BAZEL_TEST_OPTIONS} --test_timeout=300,1500,4500,-1")
endif()

if(COVERAGE)
  if(EVERYTHING)
    string(REPLACE
      "--config=everything"
      "--config=kcov_everything"
      DASHBOARD_BAZEL_BUILD_OPTIONS
      "${DASHBOARD_BAZEL_BUILD_OPTIONS}")
  else()
    set(DASHBOARD_BAZEL_BUILD_OPTIONS
      "${DASHBOARD_BAZEL_BUILD_OPTIONS} --config=kcov")
  endif()
endif()

set(MEMCHECK_BAZEL_CONFIG "")
if(MEMCHECK STREQUAL "asan")
  set(MEMCHECK_BAZEL_CONFIG "asan")
elseif(MEMCHECK STREQUAL "lsan")
  set(MEMCHECK_BAZEL_CONFIG "lsan")
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
  CTEST_BINARY_DIRECTORY
  CTEST_CHANGE_ID
  CTEST_GIT_COMMAND
  CTEST_SITE
  CTEST_SOURCE_DIRECTORY
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
