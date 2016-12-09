# Collect a list of all the ROS packages in the workspace
execute_process(COMMAND catkin list -u
                WORKING_DIRECTORY ${DASHBOARD_WORKSPACE}
                RESULT_VARIABLE RUN_RESULT
                OUTPUT_VARIABLE ROS_PACKAGES
                OUTPUT_STRIP_TRAILING_WHITESPACE)
# Replace newlines with ; to turn output into a list
string(REPLACE "\n" ";" ROS_PACKAGES_LIST "${ROS_PACKAGES}")

# Update ROS Environment after build, equivalent to sourcing devel/setup.bash
foreach(PKG ${ROS_PACKAGES_LIST})
  prepend_path(ROS_PACKAGE_PATH "${DASHBOARD_WORKSPACE}/src/${PKG}")
endforeach()
prepend_path(LD_LIBRARY_PATH} "${DASHBOARD_WORKSPACE}/devel/lib")
prepend_path(PKG_CONFIG_PATH "${DASHBOARD_WORKSPACE}/devel/lib/pkgconfig")
prepend_path(CMAKE_PREFIX_PATH "${DASHBOARD_WORKSPACE}/devel")
set_path(ROSLISP_PACKAGE_DIRECTORIES}
  "${DASHBOARD_WORKSPACE}/devel/share/common-lisp")

# Loop through all detected packages and run tests
foreach(PKG ${ROS_PACKAGES_LIST})
  if (NOT ${PKG} STREQUAL "drake")
    ctest_test(BUILD "${DASHBOARD_WORKSPACE}/build/${PKG}" ${CTEST_TEST_ARGS}
      RETURN_VALUE DASHBOARD_TEST_RETURN_VALUE QUIET APPEND)
    if(NOT DASHBOARD_TEST_RETURN_VALUE EQUAL 0)
      append_step_status("${PKG} TEST" UNSTABLE)
    endif()
    ctest_submit(PARTS Test QUIET)
  endif()
endforeach()
if(DASHBOARD_COVERAGE)
  ctest_coverage(RETURN_VALUE DASHBOARD_COVERAGE_RETURN_VALUE QUIET)
  if(NOT DASHBOARD_COVERAGE_RETURN_VALUE EQUAL 0)
    append_step_status("COVERAGE TOOL" UNSTABLE)
  endif()
  ctest_submit(PARTS Coverage QUIET)
endif()
