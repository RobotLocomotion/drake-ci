# Set base configuration
set(CTEST_USE_LAUNCHERS ON)
set(ENV{CTEST_USE_LAUNCHERS_DEFAULT} 1)

set(DASHBOARD_COVERAGE OFF)
set(DASHBOARD_MEMCHECK OFF)
set(DASHBOARD_LINK_WHAT_YOU_USE OFF)

set(DASHBOARD_LONG_RUNNING_TESTS OFF)

if(NOT DEFINED ENV{ghprbPullId})
  set(DASHBOARD_LONG_RUNNING_TESTS ON)
endif()

set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_WORKSPACE}/src/drake")
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/build")

# Include additional configuration information
include(${DASHBOARD_DRIVER_DIR}/configurations/packages.cmake)
include(${DASHBOARD_DRIVER_DIR}/configurations/timeout.cmake)

if(NOT MINIMAL AND NOT OPEN_SOURCE)
  include(${DASHBOARD_DRIVER_DIR}/configurations/aws.cmake)
endif()

# Set up diagnostic tools
if(COMPILER STREQUAL "include-what-you-use")
  include(${DASHBOARD_DRIVER_DIR}/configurations/include-what-you-use.cmake)
elseif(COMPILER STREQUAL "link-what-you-use")
  include(${DASHBOARD_DRIVER_DIR}/configurations/link-what-you-use.cmake)
elseif(COMPILER STREQUAL "scan-build")
  include(${DASHBOARD_DRIVER_DIR}/configurations/scan-build.cmake)
endif()

if(COVERAGE)
  include(${DASHBOARD_DRIVER_DIR}/configurations/coverage.cmake)
endif()

# Prepare configure arguments and build environment
set(ENV{CMAKE_CONFIG_TYPE} "${DASHBOARD_CONFIGURATION_TYPE}")
set(CTEST_CONFIGURATION_TYPE "${DASHBOARD_CONFIGURATION_TYPE}")

cache_flag(C_FLAGS STRING)
cache_flag(CXX_FLAGS STRING)
cache_flag(CXX_STANDARD STRING EXTRA "CMAKE_CXX_STANDARD_REQUIRED:BOOL=ON")
cache_flag(FORTRAN_FLAGS STRING NAMES CMAKE_Fortran_FLAGS)
cache_flag(STATIC_LINKER_FLAGS STRING)
cache_flag(SHARED_LINKER_FLAGS STRING NAMES
  CMAKE_EXE_LINKER_FLAGS
  CMAKE_SHARED_LINKER_FLAGS)
cache_flag(POSITION_INDEPENDENT_CODE BOOL)
# cache_flag(INSTALL_PREFIX PATH) TODO really not needed?
cache_flag(VERBOSE_MAKEFILE BOOL)
cache_append(ENABLE_DOCUMENTATION BOOL OFF)
cache_append(LONG_RUNNING_TESTS BOOL ${DASHBOARD_LONG_RUNNING_TESTS})
cache_append(CMAKE_BUILD_TYPE STRING ${DASHBOARD_CONFIGURATION_TYPE})

string(REGEX REPLACE "\n([0-9A-Za-z_]+)" " -D\\1"
  DASHBOARD_CONFIGURE_ARGS "\n${CACHE_CONTENT}")
string(REPLACE "\n" " "
  DASHBOARD_CONFIGURE_ARGS "${DASHBOARD_CONFIGURE_ARGS}")

# Report build configuration
set(ROS_ENVIRONMENT
  ROS_DISTRO
  ROS_ETC_DIR
  ROS_HOME
  ROS_MASTER_URI
  ROS_PACKAGE_PATH
  ROS_ROOT
)
execute_step(common report-configuration)

# Build the catkin superbuild, up to and including Drake
execute_step(catkin superbuild)

# Run Drake's tests
if(NOT DASHBOARD_FAILURE)
  execute_step(catkin drake-tests)
endif()

# Build the rest of the catkin superbuild
if(NOT DASHBOARD_FAILURE)
  execute_step(catkin post-drake)
endif()

# Run tests for ROS Packages
if(NOT DASHBOARD_FAILURE)
  execute_step(catkin ros-tests)
endif()

# Determine build result
if(NOT DASHBOARD_FAILURE)
  # TODO add warnings and format success message
  set(DASHBOARD_MESSAGE "SUCCESS")
endif()

# Report dashboard status
execute_step(common report-status)

# Touch "warm" file
if(NOT APPLE AND NOT DASHBOARD_WARM)
  file(WRITE "${DASHBOARD_WARM_FILE}")
endif()
