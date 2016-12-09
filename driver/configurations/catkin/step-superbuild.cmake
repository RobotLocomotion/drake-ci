notice("CTest Status: CONFIGURING / BUILDING SUPERBUILD")

# Set up parameters for dashboard submission
begin_stage(
  URL_NAME "Superbuild"
  PROJECT_NAME "drake-superbuild"
  BUILD_NAME "${DASHBOARD_BUILD_NAME}")

# Set the following to suppress false positives
set(CTEST_CUSTOM_ERROR_EXCEPTION
   ${CTEST_CUSTOM_ERROR_EXCEPTION}
   "configure.ac:[0-9]*: installing"
   "swig/Makefile.am:30: installing './py-compile'"
)

# Update the sources
ctest_update(SOURCE "${CTEST_SOURCE_DIRECTORY}" QUIET)
ctest_submit(PARTS Update QUIET)

# Create ROS symlink
if(NOT DASHBOARD_FAILURE)
  set(CTEST_CONFIGURE_COMMAND "cmake -E create_symlink ${DASHBOARD_WORKSPACE}/src/drake/ros ${DASHBOARD_WORKSPACE}/src/drake_ros_integration")
  ctest_configure(BUILD "${DASHBOARD_WORKSPACE}"
                  SOURCE "${DASHBOARD_WORKSPACE}"
                  RETURN_VALUE DASHBOARD_CONFIGURE_RETURN_VALUE QUIET)
  if(NOT DASHBOARD_CONFIGURE_RETURN_VALUE EQUAL 0)
    append_step_status("ROS SYMLINK CREATION" FAILURE)
  endif()
endif()

# Run catkin init step
if(NOT DASHBOARD_FAILURE)
  set(CTEST_CONFIGURE_COMMAND "catkin init")
  ctest_configure(BUILD "${DASHBOARD_WORKSPACE}"
                  SOURCE "${DASHBOARD_WORKSPACE}"
                  RETURN_VALUE DASHBOARD_CONFIGURE_RETURN_VALUE QUIET APPEND)
  if(NOT DASHBOARD_CONFIGURE_RETURN_VALUE EQUAL 0)
    append_step_status("CATKIN INIT" FAILURE)
  endif()
endif()

# Run catkin configure step
if(NOT DASHBOARD_FAILURE)
  set(CTEST_CONFIGURE_COMMAND "catkin config ${DASHBOARD_CONFIGURE_ARGS} -DCATKIN_ENABLE_TESTING=True")
  ctest_configure(BUILD "${DASHBOARD_WORKSPACE}"
                  SOURCE "${DASHBOARD_WORKSPACE}"
                  RETURN_VALUE DASHBOARD_CONFIGURE_RETURN_VALUE QUIET APPEND)
  ctest_submit(PARTS Configure QUIET)
  if(NOT DASHBOARD_CONFIGURE_RETURN_VALUE EQUAL 0)
    append_step_status("CATKIN CONFIGURE" FAILURE)
  endif()
endif()

# Run catkin build step
if(NOT DASHBOARD_FAILURE)
  set(CTEST_BUILD_COMMAND "catkin build --no-status -v -i drake")
  ctest_build(BUILD "${DASHBOARD_WORKSPACE}" APPEND
    RETURN_VALUE DASHBOARD_BUILD_RETURN_VALUE
    NUMBER_ERRORS DASHBOARD_NUMBER_BUILD_ERRORS QUIET)
  ctest_submit(PARTS Build QUIET)

  # ERROR detection doesn't work correctly with catkin... use error code instead
  if(NOT DASHBOARD_BUILD_RETURN_VALUE EQUAL 0)
    append_step_status("BUILD" FAILURE)
  else()
    # TODO get warnings
    set(DASHBOARD_MESSAGE "SUCCESS")
  endif()
endif()
