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

set(COVERAGE $ENV{coverage})
set(DEBUG $ENV{debug})
set(DOCUMENTATION $ENV{documentation})
set(MATLAB $ENV{matlab})
set(MEMCHECK $ENV{memcheck})
set(MINIMAL $ENV{minimal})
set(OPEN_SOURCE $ENV{openSource})
set(ROS $ENV{ros})
set(TRACK $ENV{track})

if(NOT DEFINED ENV{WORKSPACE})
  message(FATAL_ERROR
    "*** CTest Result: FAILURE BECAUSE ENV{WORKSPACE} WAS NOT SET")
endif()

file(TO_CMAKE_PATH "$ENV{WORKSPACE}" DASHBOARD_WORKSPACE)

if(NOT TRACK)
  set(TRACK "experimental")
endif()

# set site and build name
if(DEFINED site)
  if(APPLE)
    string(REGEX REPLACE "(.*)_(.*)" "\\1" DASHBOARD_SITE "${site}")
  elseif(NOT WIN32)
    string(REGEX REPLACE "(.*) (.*)" "\\1" DASHBOARD_SITE "${site}")
  else()
    set(DASHBOARD_SITE "${site}")
  endif()
  set(CTEST_SITE "${DASHBOARD_SITE}")
else()
  message(WARNING "*** CTEST_SITE was not set")
endif()

if(DEFINED buildname)
  set(CTEST_BUILD_NAME "${buildname}")
  if(TRACK STREQUAL "experimental")
    if(DEBUG)
      set(CTEST_BUILD_NAME "${CTEST_BUILD_NAME}-debug")
    else()
      set(CTEST_BUILD_NAME "${CTEST_BUILD_NAME}-release")
    endif()
  endif()
else()
  message(WARNING "*** CTEST_BUILD_NAME was not set")
endif()

include(ProcessorCount)
ProcessorCount(DASHBOARD_PROCESSOR_COUNT)

set(CTEST_TEST_ARGS "")

if(DASHBOARD_PROCESSOR_COUNT EQUAL 0)
  message(WARNING "*** CTEST_TEST_ARGS PARALLEL_LEVEL was not set")
else()
  set(CTEST_TEST_ARGS ${CTEST_TEST_ARGS}
    PARALLEL_LEVEL ${DASHBOARD_PROCESSOR_COUNT})
endif()

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
    file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
    message(FATAL_ERROR
      "*** CTest Result: FAILURE BECAUSE SCAN-BUILD WAS NOT FOUND")
  endif()
  set(ENV{CC} "${DASHBOARD_CCC_ANALYZER_COMMAND}")
  set(ENV{CXX} "${DASHBOARD_CXX_ANALYZER_COMMAND}")
  set(ENV{CCC_CC} "clang")
  set(ENV{CCC_CXX} "clang++")
elseif(COMPILER STREQUAL "msvc-64")
  set(CTEST_CMAKE_GENERATOR "Visual Studio 14 2015 Win64")
  set(ENV{CMAKE_FLAGS} "-G \"Visual Studio 14 2015 Win64\"")  # HACK
endif()

set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_WORKSPACE}")
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/build")
set(DASHBOARD_INSTALL_PREFIX "${CTEST_BINARY_DIRECTORY}/install")

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
      file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
      message(FATAL_ERROR
        "*** CTest Result: FAILURE BECAUSE NINJA DOWNLOAD WAS NOT SUCCESSFUL")
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
      file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
      message(FATAL_ERROR
        "*** CTest Result: FAILURE BECAUSE EXTRACTING NINJA FOR WINDOWS WAS NOT SUCCESSFUL")
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
    file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
    message(FATAL_ERROR
      "*** CTest Result: FAILURE BECAUSE PKG-CONFIG DOWNLOAD WAS NOT SUCCESSFUL")
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
      file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
      message(FATAL_ERROR
        "*** CTest Result: FAILURE BECAUSE SETTING DEFAULT C COMPILER FOR MEX WAS NOT SUCCESSFUL")
    endif()
    message(STATUS "Setting default C++ compiler for MEX...")
    execute_process(COMMAND mex -setup c++
      RESULT_VARIABLE DASHBOARD_MEX_CXX_RESULT_VARIABLE
      OUTPUT_VARIABLE DASHBOARD_MEX_CXX_OUTPUT_VARIABLE
      ERROR_VARIABLE DASHBOARD_MEX_CXX_OUTPUT_VARIABLE)
    message("${DASHBOARD_MEX_CXX_OUTPUT_VARIABLE}")
    if(NOT DASHBOARD_MEX_CXX_RESULT_VARIABLE EQUAL 0)
      file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
      message(FATAL_ERROR
        "*** CTest Result: FAILURE BECAUSE SETTING DEFAULT C++ COMPILER FOR MEX WAS NOT SUCCESSFUL")
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

set(CTEST_GIT_COMMAND "git")
set(CTEST_UPDATE_COMMAND "${CTEST_GIT_COMMAND}")
set(CTEST_UPDATE_VERSION_ONLY ON)

if(NOT MINIMAL AND NOT OPEN_SOURCE AND NOT COMPILER STREQUAL "cpplint")
  if(WIN32)
    set(DASHBOARD_SSH_IDENTITY_FILE "C:\\Windows\\Temp\\id_rsa_$ENV{RANDOM}")
    if(EXISTS "${DASHBOARD_SSH_IDENTITY_FILE}")
      file(REMOVE "${DASHBOARD_SSH_IDENTITY_FILE}")
    endif()
  else()
    execute_process(COMMAND mktemp -q /tmp/id_rsa_XXXXXXXX
      RESULT_VARIABLE DASHBOARD_MKTEMP_RESULT_VARIABLE
      OUTPUT_VARIABLE DASHBOARD_MKTEMP_OUTPUT_VARIABLE
      ERROR_VARIABLE DASHBOARD_MKTEMP_ERROR_VARIABLE)
    if(NOT DASHBOARD_MKTEMP_RESULT_VARIABLE EQUAL 0)
      message("${DASHBOARD_MKTEMP_OUTPUT_VARIABLE}")
      message("${DASHBOARD_MKTEMP_ERROR_VARIABLE}")
      file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
      message(FATAL_ERROR
        "*** CTest Result: FAILURE BECAUSE CREATION OF TEMPORARY IDENTITY FILE WAS NOT SUCCESSFUL")
    endif()
    set(DASHBOARD_SSH_IDENTITY_FILE "${DASHBOARD_MKTEMP_OUTPUT_VARIABLE}")
  endif()
  find_program(DASHBOARD_AWS_COMMAND NAMES "aws")
  if(NOT DASHBOARD_AWS_COMMAND)
    file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
    message(FATAL_ERROR "*** CTest Result: FAILURE BECAUSE AWS WAS NOT FOUND")
  endif()
  message(STATUS "Downloading identity file from AWS S3...")
  execute_process(COMMAND ${DASHBOARD_AWS_COMMAND} s3 cp s3://drake-provisioning/id_rsa "${DASHBOARD_SSH_IDENTITY_FILE}"
    RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE
    OUTPUT_VARIABLE DASHBOARD_AWS_S3_OUTPUT_VARIABLE
    ERROR_VARIABLE DASHBOARD_AWS_S3_OUTPUT_VARIABLE)
  message("${DASHBOARD_AWS_S3_OUTPUT_VARIABLE}")
  if(NOT DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
    file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
    message(FATAL_ERROR
      "*** CTest Result: FAILURE BECAUSE DOWNLOAD OF IDENTITY FILE FROM AWS S3 WAS NOT SUCCESSFUL")
  endif()
  file(SHA1 "${DASHBOARD_SSH_IDENTITY_FILE}" DASHBOARD_SSH_IDENTITY_FILE_SHA1)
  if(NOT DASHBOARD_SSH_IDENTITY_FILE_SHA1 STREQUAL "8de7f79df9eb18344cf0e030d2ae3b658d81263b")
    file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
    message(FATAL_ERROR
      "*** CTest Result: FAILURE BECAUSE SHA1 OF IDENTITY FILE WAS NOT CORRECT")
  endif()
  if(WIN32)
    set(DASHBOARD_GIT_SSH_FILE "C:\\Windows\\Temp\\git_ssh_$ENV{RANDOM}.bat")
    if(EXISTS "${DASHBOARD_GIT_SSH_FILE}")
      file(REMOVE "${DASHBOARD_GIT_SSH_FILE}")
    endif()
    configure_file("${CMAKE_CURRENT_LIST_DIR}/git_ssh.bat.in" "${DASHBOARD_GIT_SSH_FILE}" @ONLY)
  else()
    execute_process(COMMAND chmod 0400 "${DASHBOARD_SSH_IDENTITY_FILE}"
      RESULT_VARIABLE DASHBOARD_CHMOD_RESULT_VARIABLE
      OUTPUT_VARIABLE DASHBOARD_CHMOD_OUTPUT_VARIABLE
      ERROR_VARIABLE DASHBOARD_CHMOD_OUTPUT_VARIABLE)
    if(NOT DASHBOARD_CHMOD_RESULT_VARIABLE EQUAL 0)
      message("${DASHBOARD_CHMOD_OUTPUT_VARIABLE}")
      file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
      message(FATAL_ERROR
        "*** CTest Result: FAILURE BECAUSE SETTING PERMISSIONS ON IDENTITY FILE WAS NOT SUCCESSFUL")
    endif()
    execute_process(COMMAND mktemp -q /tmp/git_ssh_XXXXXXXX
      RESULT_VARIABLE DASHBOARD_MKTEMP_RESULT_VARIABLE
      OUTPUT_VARIABLE DASHBOARD_MKTEMP_OUTPUT_VARIABLE
      ERROR_VARIABLE DASHBOARD_MKTEMP_ERROR_VARIABLE)
    if(NOT DASHBOARD_MKTEMP_RESULT_VARIABLE EQUAL 0)
      message("${DASHBOARD_MKTEMP_OUTPUT_VARIABLE}")
      message("${DASHBOARD_MKTEMP_ERROR_VARIABLE}")
      file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
      message(FATAL_ERROR
        "*** CTest Result: FAILURE BECAUSE CREATION OF TEMPORARY GIT_SSH FILE WAS NOT SUCCESSFUL")
    endif()
    set(DASHBOARD_GIT_SSH_FILE "${DASHBOARD_MKTEMP_OUTPUT_VARIABLE}")
    configure_file("${CMAKE_CURRENT_LIST_DIR}/git_ssh.bash.in" "${DASHBOARD_GIT_SSH_FILE}" @ONLY)
    execute_process(COMMAND chmod 0755 "${DASHBOARD_GIT_SSH_FILE}"
      RESULT_VARIABLE DASHBOARD_CHMOD_RESULT_VARIABLE
      OUTPUT_VARIABLE DASHBOARD_CHMOD_OUTPUT_VARIABLE
      ERROR_VARIABLE DASHBOARD_CHMOD_OUTPUT_VARIABLE)
    if(NOT DASHBOARD_CHMOD_RESULT_VARIABLE EQUAL 0)
      message("${DASHBOARD_CHMOD_OUTPUT_VARIABLE}")
      file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
      message(FATAL_ERROR
        "*** CTest Result: FAILURE BECAUSE SETTING PERMISSIONS ON GIT_SSH FILE WAS NOT SUCCESSFUL")
    endif()
  endif()
  set(ENV{GIT_SSH} "${DASHBOARD_GIT_SSH_FILE}")
  file(WRITE "${DASHBOARD_WORKSPACE}/GIT_SSH" "${DASHBOARD_GIT_SSH_FILE}")
  message(STATUS "Using ENV{GIT_SSH} to set credentials")
endif()

# clean out the old builds
file(REMOVE_RECURSE "${CTEST_BINARY_DIRECTORY}")
file(MAKE_DIRECTORY "${CTEST_BINARY_DIRECTORY}")

# set model and track for submission
set(DASHBOARD_MODEL "Experimental")
if(TRACK STREQUAL "continuous")
  set(DASHBOARD_TRACK "Continuous")
elseif(TRACK STREQUAL "nightly")
  set(DASHBOARD_MODEL "Nightly")
  set(DASHBOARD_TRACK "Nightly")
else()
  set(DASHBOARD_TRACK "Experimental")
endif()

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
set(DASHBOARD_TEST_TIMEOUT 600)

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
    file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
    message(FATAL_ERROR
      "*** CTest Result: FAILURE BECAUSE INCLUDE-WHAT-YOU-USE WAS NOT FOUND")
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
  set(DASHBOARD_INSTALL OFF)
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
        file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
        message(FATAL_ERROR
          "*** CTest Result: FAILURE BECAUSE XCRUN WAS NOT FOUND")
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
      file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
      message(FATAL_ERROR
        "*** CTest Result: FAILURE BECAUSE LLVM-COV WAS NOT FOUND")
    endif()
    set(DASHBOARD_COVERAGE_EXTRA_FLAGS "gcov")
  elseif(COMPILER MATCHES "^gcc")
    find_program(DASHBOARD_COVERAGE_COMMAND NAMES "gcov-4.9")
    if(NOT DASHBOARD_COVERAGE_COMMAND)
      file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
      message(FATAL_ERROR
        "*** CTest Result: FAILURE BECAUSE GCOV-4.9 WAS NOT FOUND")
    endif()
  else()
    file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
    message(FATAL_ERROR
      "*** CTest Result: FAILURE BECAUSE CTEST_COVERAGE_COMMAND WAS NOT SET")
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
  set(DASHBOARD_INSTALL OFF)
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
      file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
      message(FATAL_ERROR
        "*** CTest Result: FAILURE BECAUSE CTEST_MEMORYCHECK_SUPPRESSIONS_FILE WAS NOT FOUND")
    endif()
  else()
    file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
    message(FATAL_ERROR
      "*** CTest Result: FAILURE BECAUSE CTEST_MEMORYCHECK_TYPE WAS NOT SET")
  endif()
  set(CTEST_MEMORYCHECK_TYPE "${DASHBOARD_MEMORYCHECK_TYPE}")
endif()

if(DEBUG)
  set(DASHBOARD_CONFIGURATION_TYPE "Debug")
endif()

if(DASHBOARD_CONFIGURATION_TYPE STREQUAL "Debug")
  set(DASHBOARD_TEST_TIMEOUT 2400)
endif()

if(MATLAB)
   math(EXPR DASHBOARD_TEST_TIMEOUT "${DASHBOARD_TEST_TIMEOUT} + 600")
endif()

set(ENV{CMAKE_CONFIG_TYPE} "${DASHBOARD_CONFIGURATION_TYPE}")
set(CTEST_CONFIGURATION_TYPE "${DASHBOARD_CONFIGURATION_TYPE}")
set(CTEST_TEST_TIMEOUT ${DASHBOARD_TEST_TIMEOUT})

set(DASHBOARD_VERBOSE_MAKEFILE ON)
set(ENV{CMAKE_FLAGS}
  "-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON $ENV{CMAKE_FLAGS}")  # HACK

if(COMPILER STREQUAL "msvc-ninja-32" AND DEBUG)
  set(DASHBOARD_NINJA_LINK_POOL_SIZE 2)
endif()

include(driver/configurations/packages.cmake)

if(DEFINED ENV{BUILD_ID})
  set(DASHBOARD_LABEL "jenkins-${CTEST_BUILD_NAME}-$ENV{BUILD_ID}")
  set_property(GLOBAL PROPERTY Label "${DASHBOARD_LABEL}")
else()
  message(WARNING "*** ENV{BUILD_ID} was not set")
  set(DASHBOARD_LABEL "")
endif()

# set pull request id
if(DEFINED ENV{ghprbPullId})
  set(CTEST_CHANGE_ID "$ENV{ghprbPullId}")
  set(DASHBOARD_CHANGE_TITLE "$ENV{ghprbPullTitle}")
  string(LENGTH "${DASHBOARD_CHANGE_TITLE}" DASHBOARD_CHANGE_TITLE_LENGTH)
  if(DASHBOARD_CHANGE_TITLE_LENGTH GREATER 30)
    string(SUBSTRING "${DASHBOARD_CHANGE_TITLE}" 0 27
      DASHBOARD_CHANGE_TITLE_SUBSTRING)
    set(DASHBOARD_CHANGE_TITLE "${DASHBOARD_CHANGE_TITLE_SUBSTRING}...")
  endif()
  set(DASHBOARD_BUILD_DESCRIPTION
    "*** Build Description: <a title=\"$ENV{ghprbPullTitle}\" href=\"$ENV{ghprbPullLink}\">PR ${CTEST_CHANGE_ID}</a>: ${DASHBOARD_CHANGE_TITLE}")
  message("${DASHBOARD_BUILD_DESCRIPTION}")
endif()

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

include(driver/configurations/generic.cmake)

if(EXISTS "${DASHBOARD_GIT_SSH_FILE}")
  file(REMOVE "${DASHBOARD_GIT_SSH_FILE}")
endif()
if(EXISTS "${DASHBOARD_SSH_IDENTITY_FILE}")
  if(WIN32)
    file(REMOVE "${DASHBOARD_SSH_IDENTITY_FILE}")
  else()
    execute_process(COMMAND chmod 0600 "${DASHBOARD_SSH_IDENTITY_FILE}"
      RESULT_VARIABLE DASHBOARD_CHMOD_RESULT_VARIABLE
      OUTPUT_VARIABLE DASHBOARD_CHMOD_OUTPUT_VARIABLE
      ERROR_VARIABLE DASHBOARD_CHMOD_OUTPUT_VARIABLE)
    if(DASHBOARD_CHMOD_RESULT_VARIABLE EQUAL 0)
      message("${DASHBOARD_CHMOD_OUTPUT_VARIABLE}")
      file(REMOVE "${DASHBOARD_SSH_IDENTITY_FILE}")
    else()
      message(WARNING "*** Setting permissions on identity file was not successful")
    endif()
  endif()
endif()

if(DASHBOARD_FAILURE)
  message(FATAL_ERROR
    "*** Return value set to NON-ZERO due to failure during build")
endif()
