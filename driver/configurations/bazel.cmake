# -*- mode: cmake; -*-
# vi: set ft=cmake:

# Set build locations and ensure there are no leftover artifacts.
set(DASHBOARD_INSTALL_PREFIX "${CTEST_BINARY_DIRECTORY}/install")
set(DASHBOARD_DOCUMENTATION_DIRECTORY "${DASHBOARD_INSTALL_PREFIX}/share/doc/drake")

file(REMOVE_RECURSE "${CTEST_BINARY_DIRECTORY}")
file(MAKE_DIRECTORY "${CTEST_BINARY_DIRECTORY}")

# Set bazel options
set(DASHBOARD_BAZEL_STARTUP_OPTIONS)
set(DASHBOARD_OUTPUT_USER_ROOT "${CTEST_BINARY_DIRECTORY}")

execute_step(common get-bazel-version)

set(DASHBOARD_EXPERIMENTAL_SCALE_TIMEOUTS 2.0)

set(DASHBOARD_BAZEL_BUILD_OPTIONS)

# The only time we use a non-default compiler is the Clang variant on Ubuntu.
if(NOT APPLE AND COMPILER STREQUAL "clang")
  string(APPEND DASHBOARD_BAZEL_BUILD_OPTIONS " --config=${COMPILER}")
endif()

if(DEBUG)
  string(APPEND DASHBOARD_BAZEL_BUILD_OPTIONS " --config=debug")
else()
  string(APPEND DASHBOARD_BAZEL_BUILD_OPTIONS " --compilation_mode=opt")
endif()

if(EVERYTHING)
  string(APPEND DASHBOARD_BAZEL_BUILD_OPTIONS " --config=everything")
endif()

if(COVERAGE)
  string(APPEND DASHBOARD_BAZEL_BUILD_OPTIONS " --config=kcov")
endif()

if(MEMCHECK)
  set(MEMCHECK_BAZEL_CONFIG)
  if(MEMCHECK STREQUAL "address-sanitizer")
    set(MEMCHECK_BAZEL_CONFIG "asan")
  elseif(MEMCHECK STREQUAL "leak-sanitizer")
    set(MEMCHECK_BAZEL_CONFIG "lsan")
  elseif(MEMCHECK STREQUAL "thread-sanitizer")
    set(MEMCHECK_BAZEL_CONFIG "tsan")
  elseif(MEMCHECK STREQUAL "undefined-behavior-sanitizer")
    set(MEMCHECK_BAZEL_CONFIG "ubsan")
  elseif(MEMCHECK STREQUAL "valgrind-memcheck")
    set(MEMCHECK_BAZEL_CONFIG "memcheck")
  else()
    fatal("memcheck is invalid")
  endif()
  string(APPEND DASHBOARD_BAZEL_BUILD_OPTIONS " --config=${MEMCHECK_BAZEL_CONFIG}")
endif()

if (REMOTE_CACHE)
  # TODO
  string(APPEND DASHBOARD_BAZEL_BUILD_OPTIONS " --remote_download_outputs=minimal")
endif()

set(DASHBOARD_BAZEL_TEST_OPTIONS)

if(APPLE)
  string(APPEND DASHBOARD_BAZEL_TEST_OPTIONS " --test_timeout=300,1500,4500,-1")
endif()

configure_file("${DASHBOARD_TOOLS_DIR}/user.bazelrc.in" "${CTEST_SOURCE_DIRECTORY}/user.bazelrc" @ONLY)

# Report build configuration
report_configuration("
  ==================================== ENV
  DISPLAY
  SNOPT_PATH
  TERM
  ==================================== >DASHBOARD_
  CC_COMMAND
  CC_VERSION_STRING
  ==================================== >DASHBOARD_
  UNIX_DISTRIBUTION
  UNIX_DISTRIBUTION_CODE_NAME
  UNIX_DISTRIBUTION_VERSION
  APPLE
  ====================================
  CMAKE_VERSION
  ====================================
  CTEST_BUILD_NAME(DASHBOARD_JOB_NAME)
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
  ==================================== >DASHBOARD_
  GIT_COMMIT
  ==================================== >DASHBOARD_
  ${COMPILER_UPPER}_CACHE_VERSION(CC_CACHE_VERSION)
  GFORTRAN_CACHE_VERSION
  JAVA_CACHE_VERSION
  OS_CACHE_VERSION
  PYTHON_CACHE_VERSION
  ==================================== >DASHBOARD_
  REMOTE_CACHE_KEY_VERSION
  REMOTE_CACHE_KEY
  ====================================
  ")

# Run the build
execute_step(bazel build)

# Determine build result
if(NOT DASHBOARD_FAILURE AND NOT DASHBOARD_UNSTABLE)
  set(DASHBOARD_MESSAGE "SUCCESS")
endif()

# Build, publish, and upload documentation, if requested, and if build
# succeeded.
if(DOCUMENTATION)
  execute_step(bazel build-documentation)
  if(DOCUMENTATION STREQUAL "publish")
    execute_step(bazel publish-documentation)
  else()
    execute_step(common set-package-version)
    execute_step(bazel create-documentation-archive)
    execute_step(bazel upload-documentation)
  endif()
endif()

if(MIRROR_TO_S3)
  execute_step(bazel mirror-to-s3)
endif()

# Report Bazel command without CI-specific options
execute_step(bazel report-bazel-command)
