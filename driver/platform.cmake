# Set number of CPU's to use
include(ProcessorCount)
ProcessorCount(DASHBOARD_PROCESSOR_COUNT)

if(DASHBOARD_PROCESSOR_COUNT EQUAL 0)
  message(WARNING "*** CTEST_TEST_ARGS PARALLEL_LEVEL was not set")
else()
  set(CTEST_TEST_ARGS ${CTEST_TEST_ARGS}
    PARALLEL_LEVEL ${DASHBOARD_PROCESSOR_COUNT})
endif()

if(GENERATOR STREQUAL "ninja")
  set(CTEST_CMAKE_GENERATOR "Ninja")
else()
  set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
  if(NOT DASHBOARD_PROCESSOR_COUNT EQUAL 0)
    set(CTEST_BUILD_FLAGS "-j${DASHBOARD_PROCESSOR_COUNT}")
  endif()
endif()

set(DASHBOARD_APPLE OFF)

if(APPLE)
  set(DASHBOARD_APPLE ON)
  include(${DASHBOARD_DRIVER_DIR}/platform/apple.cmake)
endif()

set(DASHBOARD_UNIX ON)

include(${DASHBOARD_DRIVER_DIR}/platform/unix.cmake)
