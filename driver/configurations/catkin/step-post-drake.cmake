# Switch the dashboard (back) to the drake superbuild dashboard
begin_stage(
  URL_NAME "Superbuild"
  PROJECT_NAME "drake-superbuild"
  BUILD_NAME "${DASHBOARD_BUILD_NAME}-post-drake")

# Update the sources
ctest_update(SOURCE "${CTEST_SOURCE_DIRECTORY}" QUIET)

# Drake is built; blacklist to collect build info for drake_ros_integration
# only so that catkin does not attempt to re-build drake
set(CTEST_CONFIGURE_COMMAND "catkin config --blacklist drake")
ctest_configure(BUILD "${DASHBOARD_WORKSPACE}"
                SOURCE "${DASHBOARD_WORKSPACE}"
                RETURN_VALUE DASHBOARD_CONFIGURE_RETURN_VALUE QUIET)
if(NOT DASHBOARD_CONFIGURE_RETURN_VALUE EQUAL 0)
  append_step_status("CATKIN CONFIGURE" FAILURE)
endif()

if(NOT DASHBOARD_FAILURE)
  # (Re)run catkin build step
  set(CTEST_BUILD_COMMAND "catkin build --no-status -v -i")
  ctest_build(BUILD "${DASHBOARD_WORKSPACE}" APPEND
    RETURN_VALUE DASHBOARD_BUILD_RETURN_VALUE
    NUMBER_ERRORS DASHBOARD_NUMBER_BUILD_ERRORS QUIET)

  # ERROR detection doesn't work correctly with catkin... use error code instead
  if(NOT DASHBOARD_BUILD_RETURN_VALUE EQUAL 0)
    append_step_status("CATKIN BUILD" FAILURE)
  else()
    # TODO get warnings
    set(DASHBOARD_MESSAGE "SUCCESS")
  endif()
endif()

# Submit the results
ctest_submit(RETRY_COUNT 4 RETRY_DELAY 15
  RETURN_VALUE DASHBOARD_SUBMIT_RETURN_VALUE QUIET)
