# ctest --extra-verbose --no-compress-output --output-on-failure
#
# Variables:
#
#   ENV{BUILD_ID}         optional    value of Jenkins BUILD_ID
#   ENV{WORKSPACE}        required    value of Jenkins WORKSPACE
#
#   ENV{generator}        optional    "make" | "ninja"
#   ENV{compiler}         optional    "gcc" | "clang" | "scan-build" |
#                                     "include-what-you-use" |
#                                     "link-what-you-use" |
#                                     "cpplint" |
#                                     "xenial-gcc" | "xenial-clang"
#   ENV{coverage}         optional    boolean
#   ENV{debug}            optional    boolean
#   ENV{documentation}    optional    boolean | "publish"
#   ENV{ghprbPullId}      optional    value for CTEST_CHANGE_ID
#   ENV{matlab}           optional    boolean
#   ENV{memcheck}         optional    "asan" | "msan" | "tsan" | "valgrind"
#   ENV{minimal}          optional    boolean
#   ENV{openSource}       optional    boolean
#   ENV{provision}        optional    boolean
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
include(${DASHBOARD_DRIVER_DIR}/environment.cmake)

# Set initial configuration
set(CTEST_TEST_ARGS "")

set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_WORKSPACE}")
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/build")
set(DASHBOARD_INSTALL_PREFIX "${CTEST_BINARY_DIRECTORY}/install")

set(CTEST_GIT_COMMAND "git")
set(CTEST_UPDATE_COMMAND "${CTEST_GIT_COMMAND}")
set(CTEST_UPDATE_VERSION_ONLY ON)

if(DEBUG)
  set(DASHBOARD_CONFIGURATION_TYPE "Debug")
else()
  set(DASHBOARD_CONFIGURATION_TYPE "Release")
endif()

set(DASHBOARD_INSTALL ON)
set(DASHBOARD_TEST ON)

# Set up the site and build information
include(${DASHBOARD_DRIVER_DIR}/site.cmake)

# Set up the compiler and build platform
include(driver/platform.cmake)
if(NOT COMPILER STREQUAL "cpplint")
  include(driver/compiler.cmake)
endif()

# Set up status variables
set(DASHBOARD_FAILURE OFF)
set(DASHBOARD_FAILURES "")

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
  set(DASHBOARD_CCC_ANALYZER_HTML "${DASHBOARD_WORKSPACE}/build/drake/html")
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
    "${DASHBOARD_COVERAGE_FLAGS} ${DASHBOARD_EXTRA_DEBUG_FLAGS} ${DASHBOARD_FORTRAN_FLAGS}")
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
    set(DASHBOARD_Fortran_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_Fortran_FLAGS}")
    set(DASHBOARD_SHARED_LINKER_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_SHARED_LINKER_FLAGS}")
  elseif(MEMCHECK STREQUAL "msan")
    set(DASHBOARD_MEMORYCHECK_TYPE "MemorySanitizer")
    set(DASHBOARD_SANITIZE_FLAGS "-fsanitize=memory")
    set(DASHBOARD_C_FLAGS "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_C_FLAGS}")
    set(DASHBOARD_CXX_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_CXX_FLAGS}")
    set(DASHBOARD_Fortran_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_Fortran_FLAGS}")
    set(DASHBOARD_SHARED_LINKER_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_SHARED_LINKER_FLAGS}")
  elseif(MEMCHECK STREQUAL "tsan")
    set(DASHBOARD_MEMORYCHECK_TYPE "ThreadSanitizer")
    set(DASHBOARD_SANITIZE_FLAGS "-fsanitize=thread")
    set(DASHBOARD_C_FLAGS "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_C_FLAGS}")
    set(DASHBOARD_CXX_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_CXX_FLAGS}")
    set(DASHBOARD_Fortran_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_Fortran_FLAGS}")
    set(DASHBOARD_SHARED_LINKER_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} ${DASHBOARD_SHARED_LINKER_FLAGS}")
    set(DASHBOARD_POSITION_INDEPENDENT_CODE ON)
  elseif(MEMCHECK STREQUAL "valgrind")
    set(DASHBOARD_MEMORYCHECK_TYPE "Valgrind")
    find_program(DASHBOARD_MEMORYCHECK_COMMAND NAMES "valgrind")
    set(CTEST_MEMORYCHECK_COMMAND "${DASHBOARD_MEMORYCHECK_COMMAND}")
    set(CTEST_MEMORYCHECK_COMMAND_OPTIONS
      "--show-leak-kinds=definite,possible --trace-children=yes --trace-children-skip=/bin/*,/usr/bin/*,/usr/local/bin/*,/usr/local/MATLAB/*,/Applications/*,${DASHBOARD_WORKSPACE}/build/install/bin/directorPython")
    set(CTEST_MEMORYCHECK_SUPPRESSIONS_FILE
      "${DASHBOARD_WORKSPACE}/drake/valgrind.supp")
    if(NOT EXISTS "${DASHBOARD_WORKSPACE}/drake/valgrind.supp")
      fatal("CTEST_MEMORYCHECK_SUPPRESSIONS_FILE was not found")
    endif()
    set(ENV{GTEST_DEATH_TEST_USE_FORK} 1)
  else()
    fatal("CTEST_MEMORYCHECK_TYPE was not set")
  endif()
  set(CTEST_MEMORYCHECK_TYPE "${DASHBOARD_MEMORYCHECK_TYPE}")
endif()

set(ENV{CMAKE_CONFIG_TYPE} "${DASHBOARD_CONFIGURATION_TYPE}")
set(CTEST_CONFIGURATION_TYPE "${DASHBOARD_CONFIGURATION_TYPE}")

set(DASHBOARD_VERBOSE_MAKEFILE ON)
set(ENV{CMAKE_FLAGS}
  "-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON $ENV{CMAKE_FLAGS}")  # HACK

# Invoke the appropriate build driver for the selected configuration
if(COMPILER STREQUAL "cpplint")
  include(${DASHBOARD_DRIVER_DIR}/configurations/cpplint.cmake)
else()
  include(${DASHBOARD_DRIVER_DIR}/configurations/generic.cmake)
endif()

# Remove any temporary files that we created
foreach(_file ${DASHBOARD_TEMPORARY_FILES})
  file(REMOVE ${${_file}})
endforeach()

# Report any failures and set return value
if(DASHBOARD_FAILURE)
  message(FATAL_ERROR
    "*** Return value set to NON-ZERO due to failure during build")
endif()
