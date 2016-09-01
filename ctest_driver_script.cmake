# ctest --extra-verbose --no-compress-output --output-on-failure
#
# Variables:
#
#   ENV{BUILD_ID}         optional    value of Jenkins BUILD_ID
#   ENV{WORKSPACE}        required    value of Jenkins WORKSPACE
#
#   ENV{compiler}         optional    "gcc" | "gcc-ninja" |
#                                     "clang" | "clang-ninja" |
#                                     "msvc-32" | "msvc-ninja-32" |
#                                     "msvc-64" | "msvc-ninja-64" |
#                                     "scan-build" | "scan-build-ninja" |
#                                     "include-what-you-use" |
#                                     "include-what-you-use-ninja" |
#                                     "link-what-you-use" |
#                                     "link-what-you-use-ninja" |
#                                     "cpplint"
#   ENV{coverage}         optional    boolean
#   ENV{debug}            optional    boolean
#   ENV{documentation}    optional    boolean | "publish"
#   ENV{ghprbPullId}      optional    value for CTEST_CHANGE_ID
#   ENV{matlab}           optional    boolean
#   ENV{memcheck}         optional    "asan" | "msan" | "tsan" | "valgrind"
#   ENV{minimal}          optional    boolean
#   ENV{openSource}       optional    boolean
#   ENV{ros}              optional    boolean
#   ENV{track}            optional    "continuous" | "experimental" | "nightly"
#
#   buildname             optional    value for CTEST_BUILD_NAME
#   site                  optional    value for CTEST_SITE

cmake_minimum_required(VERSION 3.6 FATAL_ERROR)

set(DASHBOARD_DRIVER_DIR ${CMAKE_CURRENT_LIST_DIR}/driver)
set(DASHBOARD_TOOLS_DIR ${CMAKE_CURRENT_LIST_DIR}/tools)
set(DASHBOARD_TEMPORARY_FILES "")

include(${DASHBOARD_DRIVER_DIR}/functions.cmake)

# Set default compiler (if not specified) or copy from environment
if(NOT DEFINED ENV{compiler})
  message(WARNING "*** ENV{compiler} was not set")
  if(WIN32)
    set(COMPILER "msvc-64")
  elseif(APPLE)
    set(COMPILER "clang")
  else()
    set(COMPILER "gcc")
  endif()
else()
  set(COMPILER $ENV{compiler})
endif()

# Copy remaining configuration from environment
set(COVERAGE $ENV{coverage})
set(DEBUG $ENV{debug})
set(DOCUMENTATION $ENV{documentation})
set(MATLAB $ENV{matlab})
set(MEMCHECK $ENV{memcheck})
set(MINIMAL $ENV{minimal})
set(OPEN_SOURCE $ENV{openSource})
set(ROS $ENV{ros})
set(TRACK $ENV{track})

# Verify workspace location and convert to CMake path
if(NOT DEFINED ENV{WORKSPACE})
  fatal("ENV{WORKSPACE} was not set")
endif()

file(TO_CMAKE_PATH "$ENV{WORKSPACE}" DASHBOARD_WORKSPACE)

if(NOT APPLE)
  if(WIN32)
    set(DASHBOARD_WARM_FILE "C:\\Windows\\Temp\\WARM")
  else()
    set(DASHBOARD_WARM_FILE "/tmp/WARM")
  endif()

  if(EXISTS "${DASHBOARD_WARM_FILE}")
    set(DASHBOARD_WARM ON)
    set(DASHBOARD_WARM_MESSAGE "*** This EBS volume is warm")
  else()
    set(DASHBOARD_WARM OFF)
    set(DASHBOARD_WARM_MESSAGE "*** This EBS volume is cold")
  endif()
  message("${DASHBOARD_WARM_MESSAGE}")
endif()

# Set initial configuration
set(CTEST_TEST_ARGS "")

set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_WORKSPACE}")
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/build")
set(DASHBOARD_INSTALL_PREFIX "${CTEST_BINARY_DIRECTORY}/install")

set(CTEST_GIT_COMMAND "git")
set(CTEST_UPDATE_COMMAND "${CTEST_GIT_COMMAND}")
set(CTEST_UPDATE_VERSION_ONLY ON)

# Set up the site and build information
include(${DASHBOARD_DRIVER_DIR}/site.cmake)

# Set up compiler
include(ProcessorCount)
ProcessorCount(DASHBOARD_PROCESSOR_COUNT)

if(DASHBOARD_PROCESSOR_COUNT EQUAL 0)
  message(WARNING "*** CTEST_TEST_ARGS PARALLEL_LEVEL was not set")
else()
  set(CTEST_TEST_ARGS ${CTEST_TEST_ARGS}
    PARALLEL_LEVEL ${DASHBOARD_PROCESSOR_COUNT})
endif()

if(WIN32)
  if(COMPILER MATCHES "ninja")
    set(CTEST_CMAKE_GENERATOR "Ninja")
    set(CTEST_USE_LAUNCHERS ON)
    set(ENV{CTEST_USE_LAUNCHERS_DEFAULT} 1)
    set(ENV{CC} "cl")
    set(ENV{CXX} "cl")
    # load 64 or 32 bit compiler environments
    if(COMPILER STREQUAL "msvc-ninja-64")
      include(${CMAKE_CURRENT_LIST_DIR}/ctest_environment_msvc_64.cmake)
    else()
      include(${CMAKE_CURRENT_LIST_DIR}/ctest_environment_msvc_32.cmake)
    endif()
  else()
    set(CTEST_CMAKE_GENERATOR "Visual Studio 14 2015")
    set(ENV{CMAKE_FLAGS} "-G \"Visual Studio 14 2015\"")  # HACK
    set(CTEST_USE_LAUNCHERS OFF)
    set(ENV{CXXFLAGS} "-MP")
    set(ENV{CFLAGS} "-MP")
  endif()
else()
  if(COMPILER MATCHES "ninja")
    set(CTEST_CMAKE_GENERATOR "Ninja")
  else()
    set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
    if(NOT DASHBOARD_PROCESSOR_COUNT EQUAL 0)
      set(CTEST_BUILD_FLAGS "-j${DASHBOARD_PROCESSOR_COUNT}")
    endif()
  endif()
  if(NOT COMPILER STREQUAL "cpplint")
    set(CTEST_USE_LAUNCHERS ON)
    set(ENV{CTEST_USE_LAUNCHERS_DEFAULT} 1)
  endif()
endif()

# check for compiler settings
if(COMPILER MATCHES "^(clang|gcc|(include|link)-what-you-use|scan-build)")
  if(APPLE)
    set(ENV{F77} "gfortran")
    set(ENV{FC} "gfortran")
  else()
    set(ENV{F77} "gfortran-4.9")
    set(ENV{FC} "gfortran-4.9")
  endif()
endif()
if(COMPILER MATCHES "^gcc")
  set(ENV{CC} "gcc-4.9")
  set(ENV{CXX} "g++-4.9")
elseif(COMPILER MATCHES "^(clang|cpplint|(include|link)-what-you-use)")
  set(ENV{CC} "clang")
  set(ENV{CXX} "clang++")
elseif(COMPILER MATCHES "^scan-build")
  find_program(DASHBOARD_CCC_ANALYZER_COMMAND NAMES "ccc-analyzer"
    PATHS "/usr/local/libexec" "/usr/libexec")
  find_program(DASHBOARD_CXX_ANALYZER_COMMAND NAMES "c++-analyzer"
    PATHS "/usr/local/libexec" "/usr/libexec")
  if(NOT DASHBOARD_CCC_ANALYZER_COMMAND OR NOT DASHBOARD_CXX_ANALYZER_COMMAND)
    fatal("scan-build was not found")
  endif()
  set(ENV{CC} "${DASHBOARD_CCC_ANALYZER_COMMAND}")
  set(ENV{CXX} "${DASHBOARD_CXX_ANALYZER_COMMAND}")
  set(ENV{CCC_CC} "clang")
  set(ENV{CCC_CXX} "clang++")
elseif(COMPILER STREQUAL "msvc-64")
  set(CTEST_CMAKE_GENERATOR "Visual Studio 14 2015 Win64")
  set(ENV{CMAKE_FLAGS} "-G \"Visual Studio 14 2015 Win64\"")  # HACK
endif()

if(WIN32)
  if(COMPILER MATCHES "ninja")
    # grab Ninja
    message(STATUS "Downloading Ninja for Windows...")
    file(DOWNLOAD
      "https://github.com/ninja-build/ninja/releases/download/v1.7.1/ninja-win.zip"
      "${DASHBOARD_WORKSPACE}/ninja-win.zip"
      SHOW_PROGRESS STATUS DASHBOARD_DOWNLOAD_NINJA_STATUS
      EXPECTED_HASH SHA1=38c5b4192f845b953f26fa6aae7d2c9e7078f2f1
      TLS_VERIFY ON)
    list(GET DASHBOARD_DOWNLOAD_NINJA_STATUS 0
      DASHBOARD_DOWNLOAD_NINJA_RESULT_VARIABLE)
    if(NOT DASHBOARD_DOWNLOAD_NINJA_RESULT_VARIABLE EQUAL 0)
      fatal("Ninja download was not successful")
    endif()
    message("Extracting Ninja for Windows...")
    execute_process(COMMAND ${CMAKE_COMMAND} -E tar xvf
      "${DASHBOARD_WORKSPACE}/ninja-win.zip"
      WORKING_DIRECTORY ${DASHBOARD_WORKSPACE}
      RESULT_VARIABLE DASHBOARD_NINJA_UNZIP_RESULT_VARIABLE
      OUTPUT_VARIABLE DASHBOARD_NINJA_UNZIP_OUTPUT_VARIABLE
      ERROR_VARIABLE DASHBOARD_NINJA_UNZIP_OUTPUT_VARIABLE)
    message("${DASHBOARD_NINJA_UNZIP_OUTPUT_VARIABLE}")
    if(NOT DASHBOARD_NINJA_UNZIP_RESULT_VARIABLE EQUAL 0)
      fatal("extracting Ninja for Windows was not successful")
    endif()
  endif()
  message(STATUS "Downloading pkg-config for Windows...")
  file(DOWNLOAD
    "https://s3.amazonaws.com/drake-provisioning/pkg-config.exe"
    "${DASHBOARD_WORKSPACE}/pkg-config.exe"
    SHOW_PROGRESS STATUS DASHBOARD_DOWNLOAD_PKG_CONFIG_STATUS
    EXPECTED_HASH SHA1=4aed4ddb0135ab6234c60b0d6ab9f912476f6bff TLS_VERIFY ON)
  list(GET DASHBOARD_DOWNLOAD_PKG_CONFIG_STATUS 0
    DASHBOARD_DOWNLOAD_PKG_CONFIG_RESULT_VARIABLE)
  if(NOT DASHBOARD_DOWNLOAD_PKG_CONFIG_RESULT_VARIABLE EQUAL 0)
    fatal("pkg-config download was not successful")
  endif()
  set(PATH
    "${DASHBOARD_WORKSPACE}"
    "${DASHBOARD_INSTALL_PREFIX}/bin"
    "${DASHBOARD_INSTALL_PREFIX}/lib")
  foreach(p ${PATH})
    file(TO_NATIVE_PATH "${p}" path)
    list(APPEND paths "${path}")
  endforeach()
  set(curPath "$ENV{PATH}")
  set(ENV{PATH} "${paths};${curPath}")
elseif(APPLE)
  set(ENV{PATH} "/opt/X11/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:$ENV{PATH}")
endif()

if(MATLAB)
  if(WIN32)
    if(COMPILER MATCHES "^msvc-(ninja-)?64$")
      set(ENV{PATH} "C:\\Program Files\\MATLAB\\R2015b\\runtime\\win64;C:\\Program Files\\MATLAB\\R2015b\\bin;C:\\Program Files\\MATLAB\\R2015b\\bin\\win64;$ENV{PATH}")
    else()
      set(ENV{PATH} "C:\\Program Files (x86)\\MATLAB\\R2015b\\runtime\\win32;C:\\Program Files (x86)\\MATLAB\\R2015b\\bin;C:\\Program Files (x86)\\MATLAB\\R2015b\\bin\\win32;$ENV{PATH}")
    endif()
    message(STATUS "Setting default C compiler for MEX...")
    execute_process(COMMAND mex -setup c
      RESULT_VARIABLE DASHBOARD_MEX_C_RESULT_VARIABLE
      OUTPUT_VARIABLE DASHBOARD_MEX_C_OUTPUT_VARIABLE
      ERROR_VARIABLE DASHBOARD_MEX_C_OUTPUT_VARIABLE)
    message("${DASHBOARD_MEX_C_OUTPUT_VARIABLE}")
    if(NOT DASHBOARD_MEX_C_RESULT_VARIABLE EQUAL 0)
      fatal("setting default C compiler for mex was not successful")
    endif()
    message(STATUS "Setting default C++ compiler for MEX...")
    execute_process(COMMAND mex -setup c++
      RESULT_VARIABLE DASHBOARD_MEX_CXX_RESULT_VARIABLE
      OUTPUT_VARIABLE DASHBOARD_MEX_CXX_OUTPUT_VARIABLE
      ERROR_VARIABLE DASHBOARD_MEX_CXX_OUTPUT_VARIABLE)
    message("${DASHBOARD_MEX_CXX_OUTPUT_VARIABLE}")
    if(NOT DASHBOARD_MEX_CXX_RESULT_VARIABLE EQUAL 0)
      fatal("setting default C++ compiler for mex was not successful")
    endif()
  elseif(APPLE)
    set(ENV{PATH} "/Applications/MATLAB_R2015b.app/bin:/Applications/MATLAB_R2015b.app/runtime/maci64:$ENV{PATH}")
  else()
    set(ENV{PATH} "/usr/local/MATLAB/R2015b/bin:$ENV{PATH}")
  endif()
endif()

if(ROS AND EXISTS "/opt/ros/indigo/setup.bash")
  set(ENV{ROS_ROOT} "/opt/ros/indigo/share/ros")
  set(ENV{ROS_PACKAGE_PATH} "/opt/ros/indigo/share:/opt/ros/indigo/stacks")
  set(ENV{ROS_MASTER_URI} "http://localhost:11311")
  set(ENV{LD_LIBRARY_PATH} "/opt/ros/indigo/lib:$ENV{LD_LIBRARY_PATH}")
  set(ENV{CPATH} "/opt/ros/indigo/include:$ENV{CPATH}")
  set(ENV{PATH} "/opt/ros/indigo/bin:$ENV{PATH}")
  set(ENV{ROSLISP_PACKAGE_DIRECTORIES} "")
  set(ENV{ROS_DISTRO} "indigo")
  set(ENV{PYTHONPATH} "/opt/ros/indigo/lib/python2.7/dist-packages:$ENV{PYTHONPATH}")
  set(ENV{PKG_CONFIG_PATH} "/opt/ros/indigo/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}")
  set(ENV{CMAKE_PREFIX_PATH} "/opt/ros/indigo")
  set(ENV{ROS_ETC_DIR} "/opt/ros/indigo/etc/ros")
  set(ENV{ROS_HOME} "$ENV{WORKSPACE}")
endif()

if(NOT MINIMAL AND NOT OPEN_SOURCE AND NOT COMPILER STREQUAL "cpplint")
  include(${DASHBOARD_DRIVER_DIR}/configurations/aws.cmake)
endif()

# clean out the old builds
file(REMOVE_RECURSE "${CTEST_BINARY_DIRECTORY}")
file(MAKE_DIRECTORY "${CTEST_BINARY_DIRECTORY}")

set(DASHBOARD_CONFIGURE_AND_BUILD_SUPERBUILD ON)
set(DASHBOARD_CONFIGURE ON)
set(DASHBOARD_INSTALL ON)
set(DASHBOARD_TEST ON)

set(DASHBOARD_COVERAGE OFF)
set(DASHBOARD_MEMCHECK OFF)

if(COMPILER STREQUAL "cpplint")
  set(DASHBOARD_CONFIGURE OFF)
  set(DASHBOARD_INSTALL OFF)
  set(DASHBOARD_TEST OFF)
endif()

# clean out any old installs
file(REMOVE_RECURSE "${DASHBOARD_INSTALL_PREFIX}")

set(DASHBOARD_CONFIGURATION_TYPE "Release")

set(DASHBOARD_C_FLAGS "")
set(DASHBOARD_CXX_FLAGS "")
set(DASHBOARD_CXX_STANDARD "")
set(DASHBOARD_FORTRAN_FLAGS "")
set(DASHBOARD_LINK_WHAT_YOU_USE OFF)
set(DASHBOARD_NINJA_LINK_POOL_SIZE 0)
set(DASHBOARD_POSITION_INDEPENDENT_CODE OFF)
set(DASHBOARD_SHARED_LINKER_FLAGS "")
set(DASHBOARD_STATIC_LINKER_FLAGS "")
set(DASHBOARD_VERBOSE_MAKEFILE OFF)

if(COMPILER MATCHES "^include-what-you-use")
  set(DASHBOARD_INSTALL OFF)
  set(DASHBOARD_TEST OFF)
  set(DASHBOARD_CONFIGURATION_TYPE "Debug")
  find_program(DASHBOARD_INCLUDE_WHAT_YOU_USE_COMMAND
    NAMES "include-what-you-use")
  if(NOT DASHBOARD_INCLUDE_WHAT_YOU_USE_COMMAND)
    fatal("include-what-you-use was not found")
  endif()
  set(DASHBOARD_INCLUDE_WHAT_YOU_USE
    "${DASHBOARD_INCLUDE_WHAT_YOU_USE_COMMAND}" "-Xiwyu" "--mapping_file=${DASHBOARD_WORKSPACE}/drake/include-what-you-use.imp")
endif()

if(COMPILER MATCHES "^link-what-you-use")
  set(DASHBOARD_INSTALL OFF)
  set(DASHBOARD_TEST OFF)
  set(DASHBOARD_CONFIGURATION_TYPE "Debug")
  set(DASHBOARD_LINK_WHAT_YOU_USE ON)
endif()

if(COMPILER MATCHES "^scan-build")
  set(DASHBOARD_INSTALL OFF)
  set(DASHBOARD_TEST OFF)
  set(DASHBOARD_CONFIGURATION_TYPE "Debug")
  set(DASHBOARD_EXTRA_DEBUG_FLAGS "-O0")
  set(DASHBOARD_C_FLAGS "${DASHBOARD_EXTRA_DEBUG_FLAGS} ${DASHBOARD_C_FLAGS}")
  set(DASHBOARD_CXX_FLAGS
    "${DASHBOARD_EXTRA_DEBUG_FLAGS} ${DASHBOARD_CXX_FLAGS}")
  set(DASHBOARD_FORTRAN_FLAGS
    "${DASHBOARD_EXTRA_DEBUG_FLAGS} ${DASHBOARD_FORTRAN_FLAGS}")
  set(DASHBOARD_CCC_ANALYZER_HTML "${DASHBOARD_WORKSPACE}/drake/build/html")
  set(ENV{CCC_ANALYZER_HTML} "${DASHBOARD_CCC_ANALYZER_HTML}")
  file(MAKE_DIRECTORY "${DASHBOARD_CCC_ANALYZER_HTML}")
endif()

# set compiler flags for coverage builds
if(COVERAGE)
  set(DASHBOARD_COVERAGE ON)
  set(DASHBOARD_INSTALL ON)
  set(DASHBOARD_CONFIGURATION_TYPE "Debug")
  set(DASHBOARD_COVERAGE_FLAGS "-fprofile-arcs -ftest-coverage")
  set(DASHBOARD_EXTRA_DEBUG_FLAGS "-O0")
  set(DASHBOARD_C_FLAGS
    "${DASHBOARD_COVERAGE_FLAGS} ${DASHBOARD_EXTRA_DEBUG_FLAGS} ${DASHBOARD_C_FLAGS}")
  set(DASHBOARD_CXX_FLAGS
    "${DASHBOARD_COVERAGE_FLAGS} ${DASHBOARD_EXTRA_DEBUG_FLAGS} ${DASHBOARD_CXX_FLAGS}")
  set(DASHBOARD_FORTRAN_FLAGS
    "${DASHBOARD_EXTRA_DEBUG_FLAGS} ${DASHBOARD_FORTRAN_FLAGS}")
  set(DASHBOARD_SHARED_LINKER_FLAGS
    "${DASHBOARD_COVERAGE_FLAGS} ${DASHBOARD_SHARED_LINKER_FLAGS}")

  if(COMPILER MATCHES "^clang")
    if(APPLE)
      find_program(DASHBOARD_XCRUN_COMMAND NAMES "xcrun")
      if(NOT DASHBOARD_XCRUN_COMMAND)
        fatal("xcrun was not found")
      endif()
      execute_process(COMMAND "${DASHBOARD_XCRUN_COMMAND}" -f llvm-cov
        RESULT_VARIABLE DASHBOARD_XCRUN_RESULT_VARIABLE
        OUTPUT_VARIABLE DASHBOARD_XCRUN_OUTPUT_VARIABLE
        ERROR_VARIABLE DASHBOARD_XCRUN_ERROR_VARIABLE
        OUTPUT_STRIP_TRAILING_WHITESPACE)
      if(DASHBOARD_XCRUN_RESULT_VARIABLE EQUAL 0)
        set(DASHBOARD_COVERAGE_COMMAND "${DASHBOARD_XCRUN_OUTPUT_VARIABLE}")
      else()
        message("${DASHBOARD_XCRUN_OUTPUT_VARIABLE}")
        message("${DASHBOARD_XCRUN_ERROR_VARIABLE}")
      endif()
    else()
      find_program(DASHBOARD_COVERAGE_COMMAND NAMES "llvm-cov")
    endif()
    if(NOT DASHBOARD_COVERAGE_COMMAND)
      fatal("llvm-cov was not found")
    endif()
    set(DASHBOARD_COVERAGE_EXTRA_FLAGS "gcov")
  elseif(COMPILER MATCHES "^gcc")
    find_program(DASHBOARD_COVERAGE_COMMAND NAMES "gcov-4.9")
    if(NOT DASHBOARD_COVERAGE_COMMAND)
      fatal("gcov-4.9 was not found")
    endif()
  else()
    fatal("CTEST_COVERAGE_COMMAND was not set")
  endif()

  set(CTEST_COVERAGE_COMMAND "${DASHBOARD_COVERAGE_COMMAND}")
  set(CTEST_COVERAGE_EXTRA_FLAGS "${DASHBOARD_COVERAGE_EXTRA_FLAGS}")

  set(CTEST_CUSTOM_COVERAGE_EXCLUDE
    ${CTEST_CUSTOM_COVERAGE_EXCLUDE}
    ".*/thirdParty/.*"
    ".*/test/.*"
  )
endif()

# set compiler flags for memcheck builds
if(MEMCHECK MATCHES "^([amt]san|valgrind)$")
  set(DASHBOARD_MEMCHECK ON)
  set(DASHBOARD_INSTALL ON)
  set(DASHBOARD_CONFIGURATION_TYPE "Debug")
  set(DASHBOARD_EXTRA_DEBUG_FLAGS "-O1 -fno-omit-frame-pointer")
  set(DASHBOARD_C_FLAGS "${DASHBOARD_EXTRA_DEBUG_FLAGS} ${DASHBOARD_C_FLAGS}")
  set(DASHBOARD_CXX_FLAGS
    "${DASHBOARD_EXTRA_DEBUG_FLAGS} ${DASHBOARD_CXX_FLAGS}")
  set(DASHBOARD_FORTRAN_FLAGS
    "${DASHBOARD_EXTRA_DEBUG_FLAGS} ${DASHBOARD_FORTRAN_FLAGS}")
  if(MEMCHECK STREQUAL "msan")
    set(ENV{LD_LIBRARY_PATH} "/usr/local/libcxx_msan/lib:$ENV{LD_LIBRARY_PATH}")
    set(DASHBOARD_C_FLAGS
      "-I/usr/local/libcxx_msan/include ${DASHBOARD_C_FLAGS}")
    set(DASHBOARD_CXX_FLAGS
      "-stdlib=libc++ -L/usr/local/libcxx_msan/lib -lc++abi -I/usr/local/libcxx_msan/include -I/usr/local/libcxx_msan/include/c++/v1 ${DASHBOARD_CXX_FLAGS}")
    set(DASHBOARD_CXX_STANDARD 11)
  endif()
  if(MEMCHECK STREQUAL "asan")
    set(DASHBOARD_MEMORYCHECK_TYPE "AddressSanitizer")
    set(DASHBOARD_SANITIZE_FLAGS "-fsanitize=address")
    set(DASHBOARD_C_FLAGS "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_C_FLAGS}")
    set(DASHBOARD_CXX_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_CXX_FLAGS}")
    set(DASHBOARD_SHARED_LINKER_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_SHARED_LINKER_FLAGS}")
  elseif(MEMCHECK STREQUAL "msan")
    set(DASHBOARD_MEMORYCHECK_TYPE "MemorySanitizer")
    set(DASHBOARD_SANITIZE_FLAGS "-fsanitize=memory")
    set(DASHBOARD_C_FLAGS "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_C_FLAGS}")
    set(DASHBOARD_CXX_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_CXX_FLAGS}")
    set(DASHBOARD_SHARED_LINKER_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_SHARED_LINKER_FLAGS}")
  elseif(MEMCHECK STREQUAL "tsan")
    set(DASHBOARD_MEMORYCHECK_TYPE "ThreadSanitizer")
    set(DASHBOARD_SANITIZE_FLAGS "-fsanitize=thread")
    set(DASHBOARD_C_FLAGS "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_C_FLAGS}")
    set(DASHBOARD_CXX_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_CXX_FLAGS}")
    set(DASHBOARD_SHARED_LINKER_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_SHARED_LINKER_FLAGS}")
    set(DASHBOARD_POSITION_INDEPENDENT_CODE ON)
  elseif(MEMCHECK STREQUAL "valgrind")
    set(DASHBOARD_MEMORYCHECK_TYPE "Valgrind")
    find_program(DASHBOARD_MEMORYCHECK_COMMAND NAMES "valgrind")
    set(CTEST_MEMORYCHECK_COMMAND "${DASHBOARD_MEMORYCHECK_COMMAND}")
    set(CTEST_MEMORYCHECK_COMMAND_OPTIONS "--show-leak-kinds=definite,possible")
    set(CTEST_MEMORYCHECK_SUPPRESSIONS_FILE
      "${DASHBOARD_WORKSPACE}/drake/valgrind.supp")
    if(NOT EXISTS "${DASHBOARD_WORKSPACE}/drake/valgrind.supp")
      fatal("CTEST_MEMORYCHECK_SUPPRESSIONS_FILE was not found")
    endif()
  else()
    fatal("CTEST_MEMORYCHECK_TYPE was not set")
  endif()
  set(CTEST_MEMORYCHECK_TYPE "${DASHBOARD_MEMORYCHECK_TYPE}")
endif()

if(DEBUG)
  set(DASHBOARD_CONFIGURATION_TYPE "Debug")
endif()

set(ENV{CMAKE_CONFIG_TYPE} "${DASHBOARD_CONFIGURATION_TYPE}")
set(CTEST_CONFIGURATION_TYPE "${DASHBOARD_CONFIGURATION_TYPE}")

set(DASHBOARD_VERBOSE_MAKEFILE ON)
set(ENV{CMAKE_FLAGS}
  "-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON $ENV{CMAKE_FLAGS}")  # HACK

if(COMPILER STREQUAL "msvc-ninja-32" AND DEBUG)
  set(DASHBOARD_NINJA_LINK_POOL_SIZE 2)
endif()

include(${DASHBOARD_DRIVER_DIR}/configurations/packages.cmake)
include(${DASHBOARD_DRIVER_DIR}/configurations/timeout.cmake)

set(DASHBOARD_APPLE OFF)
set(DASHBOARD_UNIX OFF)
set(DASHBOARD_WIN32 OFF)
if(APPLE)
  set(DASHBOARD_APPLE ON)
endif()
if(UNIX)
  set(DASHBOARD_UNIX ON)
endif()
if(WIN32)
  set(DASHBOARD_WIN32 ON)
endif()

include(${DASHBOARD_DRIVER_DIR}/configurations/generic.cmake)

# Remove any temporary files that we created
foreach(_file ${DASHBOARD_TEMPORARY_FILES})
  file(REMOVE ${${_file}})
endforeach()

if(NOT APPLE AND NOT DASHBOARD_WARM AND NOT COMPILER STREQUAL "cpplint")
  file(WRITE "${DASHBOARD_WARM_FILE}")
endif()

# Report any failures and set return value
if(DASHBOARD_FAILURE)
  message(FATAL_ERROR
    "*** Return value set to NON-ZERO due to failure during build")
endif()
