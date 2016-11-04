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

set(DASHBOARD_CONFIGURATION_TYPE "Release")

set(DASHBOARD_INSTALL ON)
set(DASHBOARD_TEST ON)

# Set up the site and build information
include(${DASHBOARD_DRIVER_DIR}/site.cmake)

# Set up the compiler and build platform
include(${DASHBOARD_DRIVER_DIR}/platform.cmake)

# Set up status variables
set(DASHBOARD_FAILURE OFF)
set(DASHBOARD_FAILURES "")

# check for compiler settings
if(COMPILER MATCHES "^xenial")
  set(ENV{F77} "gfortran-5")
  set(ENV{FC} "gfortran-5")
elseif(COMPILER MATCHES "^(clang|gcc|(include|link)-what-you-use|scan-build)")
  if(APPLE)
    set(ENV{F77} "gfortran")
    set(ENV{FC} "gfortran")
  else()
    set(ENV{F77} "gfortran-4.9")
    set(ENV{FC} "gfortran-4.9")
  endif()
endif()
if(COMPILER MATCHES "^xenial-gcc")
  set(ENV{CC} "gcc-5")
  set(ENV{CXX} "g++-5")
elseif(COMPILER MATCHES "^xenial-clang")
  set(ENV{CC} "clang-3.9")
  set(ENV{CXX} "clang++-3.9")
elseif(COMPILER MATCHES "^gcc")
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
endif()

if(NOT MINIMAL AND NOT OPEN_SOURCE AND NOT COMPILER STREQUAL "cpplint")
  include(${DASHBOARD_DRIVER_DIR}/configurations/aws.cmake)
endif()

set(DASHBOARD_COVERAGE OFF)
set(DASHBOARD_MEMCHECK OFF)

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
  set(DASHBOARD_CCC_ANALYZER_HTML "${DASHBOARD_WORKSPACE}/build/drake/html")
  set(ENV{CCC_ANALYZER_HTML} "${DASHBOARD_CCC_ANALYZER_HTML}")
  file(MAKE_DIRECTORY "${DASHBOARD_CCC_ANALYZER_HTML}")
endif()

if(PROVISION)
  if(COMPILER MATCHES "^xenial")
    execute_process(COMMAND bash "-c" "yes | sudo ${DASHBOARD_WORKSPACE}/setup/ubuntu/16.04/install_prereqs.sh"
      RESULT_VARIABLE INSTALL_PREREQS_RESULT_VARIABLE
      OUTPUT_VARIABLE INSTALL_PREREQS_OUTPUT_VARIABLE
      ERROR_VARIABLE INSTALL_PREREQS_ERROR_VARIABLE
      OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(NOT INSTALL_PREREQS_RESULT_VARIABLE EQUAL 0)
      message("${INSTALL_PREREQS_OUTPUT_VARIABLE}")
      message("${INSTALL_PREREQS_ERROR_VARIABLE}")
      fatal("provisioning script did not complete successfully")
    endif()
  endif()
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

if(DEBUG)
  set(DASHBOARD_CONFIGURATION_TYPE "Debug")
endif()

set(ENV{CMAKE_CONFIG_TYPE} "${DASHBOARD_CONFIGURATION_TYPE}")
set(CTEST_CONFIGURATION_TYPE "${DASHBOARD_CONFIGURATION_TYPE}")

set(DASHBOARD_VERBOSE_MAKEFILE ON)
set(ENV{CMAKE_FLAGS}
  "-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON $ENV{CMAKE_FLAGS}")  # HACK

include(${DASHBOARD_DRIVER_DIR}/configurations/packages.cmake)
include(${DASHBOARD_DRIVER_DIR}/configurations/timeout.cmake)

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
