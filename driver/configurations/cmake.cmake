# -*- mode: cmake; -*-
# vi: set ft=cmake:

# Set build locations and ensure there are no leftover artifacts.
set(DASHBOARD_INSTALL_PREFIX /opt/drake)
# Use the Bazel output user root even under CMake builds, in case we caught a
# warm machine that previously ran a Bazel build so we can share cache.
set(DASHBOARD_OUTPUT_USER_ROOT "${DASHBOARD_BINARY_DIRECTORY}/_bazel_$ENV{USER}")

file(REMOVE_RECURSE "${CTEST_BINARY_DIRECTORY}")
file(MAKE_DIRECTORY "${CTEST_BINARY_DIRECTORY}")

file(REMOVE_RECURSE "${DASHBOARD_INSTALL_PREFIX}")

# Exclude packaging jobs from CDash uploads, since uploads for steps after
# CMake install are not set up (so actual failures show as successes).
if (PACKAGE)
  set(DASHBOARD_SUBMIT OFF)
endif()

# Set up build configuration
set(CTEST_CONFIGURATION_TYPE "${DASHBOARD_CONFIGURATION_TYPE}")
set(CTEST_TEST_TIMEOUT 300)

cache_append(CMAKE_INSTALL_PREFIX PATH ${DASHBOARD_INSTALL_PREFIX})
cache_append(DRAKE_CI_ENABLE_PACKAGING BOOL ${PACKAGE})
cache_append(DRAKE_CI_ENABLE_EVERYTHING BOOL ${EVERYTHING})

file(COPY "${DASHBOARD_CI_DIR}/user.bazelrc"
  DESTINATION "${DASHBOARD_SOURCE_DIRECTORY}")

file(APPEND "${DASHBOARD_SOURCE_DIRECTORY}/user.bazelrc"
  "startup --output_user_root=${DASHBOARD_OUTPUT_USER_ROOT}\n")

# Set up cache
include(${DASHBOARD_DRIVER_DIR}/configurations/cache.cmake)

if(REMOTE_CACHE)
  file(APPEND "${DASHBOARD_SOURCE_DIRECTORY}/user.bazelrc"
    "build --remote_download_outputs=all\n"
    "build --remote_cache=${DASHBOARD_REMOTE_CACHE}\n"
    "build --remote_local_fallback=yes\n"
    "build --remote_max_connections=64\n"
    "build --remote_retries=4\n"
    "build --remote_timeout=120\n"
    "build --remote_accept_cached=${DASHBOARD_REMOTE_ACCEPT_CACHED}\n"
    "build --remote_upload_local_results=${DASHBOARD_REMOTE_UPLOAD_LOCAL_RESULTS}\n")
endif()

# Set package version
execute_step(common set-package-version)
cache_append(DRAKE_VERSION_OVERRIDE STRING "${DASHBOARD_DRAKE_VERSION}")

# Report build configuration
execute_step(common get-bazel-version)

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
  ==================================== >DASHBOARD_ <CMAKE_
  INSTALL_PREFIX
  ====================================
  CTEST_BUILD_NAME(DASHBOARD_JOB_NAME)
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
  ====================================
  PACKAGE
  ==================================== >DASHBOARD_
  GIT_COMMIT
  DRAKE_VERSION
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

if(PACKAGE)
  set(DASHBOARD_PACKAGE_OUTPUT_DIRECTORY "${DASHBOARD_INSTALL_PREFIX}")
  mkdir("${DASHBOARD_PACKAGE_OUTPUT_DIRECTORY}" 1777
    "package output directory")
  list(APPEND DASHBOARD_TEMPORARY_FILES DASHBOARD_PACKAGE_OUTPUT_DIRECTORY)
endif()

# Run the build
execute_step(cmake build)

# Determine build result
if(NOT DASHBOARD_FAILURE)
  set(DASHBOARD_MESSAGE "SUCCESS")
endif()

# Create packages (if applicable)
if(PACKAGE)
  execute_step(cmake install)
  execute_step(cmake create-package-archive)
  if(NOT APPLE)
    execute_step(cmake create-debian-archive)
  endif()
  if(PACKAGE STREQUAL "publish")
    execute_step(cmake upload-package-archive)
    if(NOT APPLE)
      execute_step(cmake upload-debian-archive)
    endif()
  endif()
  if(DOCKER)
    # The default Ubuntu version for Docker should be the newest base OS.
    # If this value changes, the Docker documentation in the drake repository
    # (drake/doc/_pages/docker.md) also needs to be updated.
    set(DEFAULT_DOCKER_DISTRIBUTION "noble")

    execute_step(cmake build-docker-image)
    if(DOCKER STREQUAL "publish")
      execute_step(cmake push-docker-image)
    endif()
  endif()
  if(DISTRIBUTION STREQUAL "noble" AND CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "x86_64" AND DASHBOARD_GROUP STREQUAL "nightly")
    execute_step(cmake push-nightly-release-branch)
  endif()
endif()
