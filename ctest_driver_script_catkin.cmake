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
                RETURN_VALUE DASHBOARD_SUPERBUILD_CONFIGURE_RETURN_VALUE QUIET)

set(CTEST_CONFIGURE_COMMAND "catkin init")
ctest_configure(BUILD "${DASHBOARD_WORKSPACE}"
                SOURCE "${DASHBOARD_WORKSPACE}"
                RETURN_VALUE DASHBOARD_SUPERBUILD_CONFIGURE_RETURN_VALUE QUIET)

set(CTEST_BUILD_COMMAND "catkin build --no-status -v -i -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCATKIN_ENABLE_TESTING=True")
ctest_build(BUILD "${DASHBOARD_WORKSPACE}" APPEND
  NUMBER_ERRORS DASHBOARD_SUPERBUILD_NUMBER_BUILD_ERRORS QUIET)
ctest_submit(PARTS Build)

set(ENV{ROS_PACKAGE_PATH} "${DASHBOARD_WORKSPACE}/src/drake:${DASHBOARD_WORKSPACE}/src/drake_ros:$ENV{ROS_PACKAGE_PATH}")
set(ENV{LD_LIBRARY_PATH} "${DASHBOARD_WORKSPACE}/devel/lib::$ENV{LD_LIBRARY_PATH}")
set(ENV{ROSLISP_PACKAGE_DIRECTORIES} "${DASHBOARD_WORKSPACE}/devel/share/common-lisp")
set(ENV{PKG_CONFIG_PATH} "${DASHBOARD_WORKSPACE}/devel/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}")
set(ENV{CMAKE_PREFIX_PATH} "${DASHBOARD_WORKSPACE}/devel:$ENV{CMAKE_PREFIX_PATH}")

ctest_test(BUILD "${DASHBOARD_WORKSPACE}/build/drake/drake" ${CTEST_TEST_ARGS}
  RETURN_VALUE DASHBOARD_TEST_RETURN_VALUE QUIET APPEND)
ctest_submit(PARTS Test)

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
    ctest_submit(PARTS Test)
  endif()
endforeach()
