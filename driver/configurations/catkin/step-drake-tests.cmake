# Switch the dashboard to the drake only dashboard
begin_stage(
  PROJECT_NAME "Drake"
  BUILD_NAME "${DASHBOARD_BUILD_NAME}-drake")

# Update the sources
ctest_update(SOURCE "${CTEST_SOURCE_DIRECTORY}" QUIET)
ctest_submit(PARTS Update QUIET)

# Run Drake's tests
ctest_test(BUILD "${DASHBOARD_WORKSPACE}/build/drake/drake" ${CTEST_TEST_ARGS}
  RETURN_VALUE DASHBOARD_TEST_RETURN_VALUE QUIET APPEND)
ctest_submit(PARTS Test QUIET)
if(NOT DASHBOARD_TEST_RETURN_VALUE EQUAL 0)
  append_step_status("DRAKE TEST" UNSTABLE)
endif()
