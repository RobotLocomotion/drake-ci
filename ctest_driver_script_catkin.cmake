cmake_minimum_required(VERSION 3.5 FATAL_ERROR)

if(NOT DEFINED ENV{compiler})
  set(ENV{compiler} "gcc")
endif()

if("$ENV{compiler}" MATCHES "clang")
  set(ENV{CC} "clang-3.7")
  set(ENV{CXX} "clang++-3.7")
else()
  set(ENV{CC} "gcc-4.9")
  set(ENV{CXX} "g++-4.9")
endif()
set(ENV{F77} "gfortran-4.9")
set(ENV{FC} "gfortran-4.9")

if("$ENV{WORKSPACE}" STREQUAL "")
  message(FATAL_ERROR "WORKSPACE environment variable is not set, please set it and try again.")
endif()

file(TO_CMAKE_PATH "$ENV{WORKSPACE}" DASHBOARD_WORKSPACE)

set(DASHBOARD_CDASH_SERVER "drake-cdash.csail.mit.edu")
set(DASHBOARD_NIGHTLY_START_TIME "00:00:00 EST")
set(DASHBOARD_SITE "${site}")
set(CTEST_SITE "${DASHBOARD_SITE}")
set(CTEST_BUILD_NAME "drake-catkin-ros")
set(CTEST_DROP_METHOD "https")
set(CTEST_DROP_SITE "${DASHBOARD_CDASH_SERVER}")
set(CTEST_DROP_SITE_CDASH ON)
set(CTEST_NIGHTLY_START_TIME "${DASHBOARD_NIGHTLY_START_TIME}")
#set(DASHBOARD_SUPERBUILD_PROJECT_NAME "drake-catkin-ros")
set(DASHBOARD_SUPERBUILD_PROJECT_NAME "drake-superbuild")
set(CTEST_PROJECT_NAME "${DASHBOARD_SUPERBUILD_PROJECT_NAME}")
set(CTEST_DROP_LOCATION
    "/submit.php?project=${DASHBOARD_SUPERBUILD_PROJECT_NAME}")

set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_WORKSPACE}")
set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/build")

include(ProcessorCount)
ProcessorCount(DASHBOARD_PROCESSOR_COUNT)

set(CTEST_TEST_ARGS "")

if(DASHBOARD_PROCESSOR_COUNT EQUAL 0)
  message(WARNING "*** CTEST_TEST_ARGS PARALLEL_LEVEL was not set")
else()
  set(CTEST_TEST_ARGS ${CTEST_TEST_ARGS}
    PARALLEL_LEVEL ${DASHBOARD_PROCESSOR_COUNT})
endif()
set(DASHBOARD_CONFIGURE_AND_BUILD_SUPERBUILD ON)

if(DEFINED ENV{BUILD_ID})
  set(DASHBOARD_LABEL "jenkins-${CTEST_BUILD_NAME}-$ENV{BUILD_ID}")
  set_property(GLOBAL PROPERTY Label "${DASHBOARD_LABEL}")
else()
  message(WARNING "*** ENV{BUILD_ID} was not set")
  set(DASHBOARD_LABEL "")
endif()

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
set(ENV{ROS_HOME} "${DASHBOARD_WORKSPACE}")

set(DASHBOARD_TRACK "Experimental")
set(DASHBOARD_SUPERBUILD_START_MESSAGE
  "*** CTest Status: CONFIGURING / BUILDING SUPERBUILD")
message("
  ------------------------------------------------------------------------------
  ${DASHBOARD_SUPERBUILD_START_MESSAGE}
  ------------------------------------------------------------------------------
  ")
ctest_start("${DASHBOARD_MODEL}" TRACK "${DASHBOARD_TRACK}" QUIET)
ctest_update(SOURCE "${CTEST_SOURCE_DIRECTORY}" QUIET)

set(CTEST_CONFIGURE_COMMAND "cmake -E create_symlink ${DASHBOARD_WORKSPACE}/src/drake/ros ${DASHBOARD_WORKSPACE}/src/drake_ros_integration")
ctest_configure(BUILD "${DASHBOARD_WORKSPACE}"
                SOURCE "${DASHBOARD_WORKSPACE}"
                RETURN_VALUE DASHBOARD_CONFIGURE_RETURN_VALUE QUIET)
if(NOT DASHBOARD_CONFIGURE_RETURN_VALUE EQUAL 0)
  message(FATAL_ERROR
    "*** CTest Result: FAILURE BECAUSE CREATION OF ROS SYMLINK WAS NOT SUCCESSFUL")
endif()

set(CTEST_CONFIGURE_COMMAND "catkin init")
ctest_configure(BUILD "${DASHBOARD_WORKSPACE}"
                SOURCE "${DASHBOARD_WORKSPACE}"
                RETURN_VALUE DASHBOARD_CONFIGURE_RETURN_VALUE QUIET)
if(NOT DASHBOARD_CONFIGURE_RETURN_VALUE EQUAL 0)
  message(FATAL_ERROR
    "*** CTest Result: FAILURE BECAUSE EXECUTION OF catkin init WAS NOT SUCCESSFUL")
endif()

set(CTEST_BUILD_COMMAND "catkin build --no-status -v -i -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCATKIN_ENABLE_TESTING=True")
ctest_build(BUILD "${DASHBOARD_WORKSPACE}" APPEND
  RETURN_VALUE DASHBOARD_BUILD_RETURN_VALUE
  NUMBER_ERRORS DASHBOARD_NUMBER_BUILD_ERRORS QUIET)
ctest_submit(PARTS Build)

# ERROR detection doesn't work correctly with catkin... use error code instead
#if(NOT DASHBOARD_NUMBER_BUILD_ERRORS EQUAL 0)
if(NOT DASHBOARD_BUILD_RETURN_VALUE EQUAL 0)
  message(FATAL_ERROR
    "*** CTest Result: FAILURE BECAUSE OF BUILD FAILURES")
else()
  if(DASHBOARD_NUMBER_BUILD_WARNINGS EQUAL 1)
    set(DASHBOARD_WARNING ON)
    set(DASHBOARD_MESSAGE "SUCCESS BUT WITH 1 BUILD WARNING")
  elseif(DASHBOARD_NUMBER_BUILD_WARNINGS GREATER 1)
    set(DASHBOARD_WARNING ON)
    set(DASHBOARD_MESSAGE "SUCCESS BUT WITH ${DASHBOARD_NUMBER_BUILD_WARNINGS} BUILD WARNINGS")
  else()
    set(DASHBOARD_MESSAGE "SUCCESS")
  endif()
endif()

set(ENV{ROS_PACKAGE_PATH} "${DASHBOARD_WORKSPACE}/src/drake:${DASHBOARD_WORKSPACE}/src/drake_ros:$ENV{ROS_PACKAGE_PATH}")
set(ENV{LD_LIBRARY_PATH} "${DASHBOARD_WORKSPACE}/devel/lib::$ENV{LD_LIBRARY_PATH}")
set(ENV{ROSLISP_PACKAGE_DIRECTORIES} "${DASHBOARD_WORKSPACE}/devel/share/common-lisp")
set(ENV{PKG_CONFIG_PATH} "${DASHBOARD_WORKSPACE}/devel/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}")
set(ENV{CMAKE_PREFIX_PATH} "${DASHBOARD_WORKSPACE}/devel:$ENV{CMAKE_PREFIX_PATH}")

set(DASHBOARD_UNSTABLE OFF)
set(DASHBOARD_UNSTABLES "")

ctest_test(BUILD "${DASHBOARD_WORKSPACE}/build/drake/drake" ${CTEST_TEST_ARGS}
  RETURN_VALUE DASHBOARD_TEST_RETURN_VALUE QUIET APPEND)
ctest_submit(PARTS Test)
if(NOT DASHBOARD_TEST_RETURN_VALUE EQUAL 0)
  set(DASHBOARD_UNSTABLE ON)
  list(APPEND DASHBOARD_UNSTABLES "TEST DRAKE")
endif()

# Run tests on every ROS Package in the workspace
execute_process(COMMAND catkin list -u
                WORKING_DIRECTORY ${DASHBOARD_WORKSPACE}
                RESULT_VARIABLE RUN_RESULT
                OUTPUT_VARIABLE ROS_PACKAGES
                OUTPUT_STRIP_TRAILING_WHITESPACE)
# Replace newlines with ; to turn output into a list
string(REPLACE "\n" ";" ROS_PACKAGES_LIST "${ROS_PACKAGES}")

# Loop through all detected packages and run tests
foreach(PKG ${ROS_PACKAGES_LIST})
  if (NOT ${PKG} STREQUAL "drake")
    #message("Testing ROS Package: ${PKG}")
    ctest_test(BUILD "${DASHBOARD_WORKSPACE}/build/${PKG}" ${CTEST_TEST_ARGS}
      RETURN_VALUE DASHBOARD_TEST_RETURN_VALUE QUIET APPEND)
    if(NOT DASHBOARD_TEST_RETURN_VALUE EQUAL 0)
      set(DASHBOARD_UNSTABLE ON)
      list(APPEND DASHBOARD_UNSTABLES "TEST ${PKG}")
    endif()
    ctest_submit(PARTS Test)
  endif()
endforeach()

if(DASHBOARD_UNSTABLE)
  string(REPLACE ";" " / " DASHBOARD_UNSTABLES_STRING "${DASHBOARD_UNSTABLES}")
  set(DASHBOARD_MESSAGE
    "UNSTABLE DUE TO ${DASHBOARD_UNSTABLES_STRING} FAILURES")
  file(WRITE "${DASHBOARD_WORKSPACE}/UNSTABLE")
else()
  file(WRITE "${DASHBOARD_WORKSPACE}/SUCCESS")
endif()

set(DASHBOARD_MESSAGE "*** CTest Result: ${DASHBOARD_MESSAGE}")

if(DASHBOARD_CONFIGURE_AND_BUILD_SUPERBUILD AND DASHBOARD_LABEL)
  set(DASHBOARD_CDASH_SUPERBUILD_URL_MESSAGE
    "*** CDash Superbuild URL: https://${DASHBOARD_CDASH_SERVER}/index.php?project=${DASHBOARD_SUPERBUILD_PROJECT_NAME}&showfilters=1&filtercount=2&showfilters=1&filtercombine=and&field1=label&compare1=61&value1=${DASHBOARD_LABEL}&field2=buildstarttime&compare2=84&value2=now")
else()
  set(DASHBOARD_CDASH_SUPERBUILD_URL_MESSAGE "*** CDash Superbuild URL:")
endif()

if(NOT DASHBOARD_SUPERBUILD_FAILURE AND DASHBOARD_LABEL)
  set(DASHBOARD_CDASH_URL_MESSAGE
    "*** CDash URL: https://${DASHBOARD_CDASH_SERVER}/index.php?project=${DASHBOARD_PROJECT_NAME}&showfilters=1&filtercount=2&showfilters=1&filtercombine=and&field1=label&compare1=61&value1=${DASHBOARD_LABEL}&field2=buildstarttime&compare2=84&value2=now")
else()
  set(DASHBOARD_CDASH_URL_MESSAGE "*** CDash URL:")
endif()

message("
  ------------------------------------------------------------------------------
  ${DASHBOARD_MESSAGE}
  ------------------------------------------------------------------------------
  ${DASHBOARD_CDASH_SUPERBUILD_URL_MESSAGE}
  ------------------------------------------------------------------------------
  ${DASHBOARD_CDASH_URL_MESSAGE}
  ------------------------------------------------------------------------------
  ")
