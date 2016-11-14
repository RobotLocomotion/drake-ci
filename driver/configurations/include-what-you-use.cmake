set(DASHBOARD_INSTALL OFF)
set(DASHBOARD_TEST OFF)
set(DASHBOARD_CONFIGURATION_TYPE "Debug")

find_program(DASHBOARD_INCLUDE_WHAT_YOU_USE_COMMAND include-what-you-use)
if(NOT DASHBOARD_INCLUDE_WHAT_YOU_USE_COMMAND)
  fatal("include-what-you-use was not found")
endif()

set(DASHBOARD_INCLUDE_WHAT_YOU_USE
  "${DASHBOARD_INCLUDE_WHAT_YOU_USE_COMMAND}"
  "-Xiwyu"
  "--mapping_file=${DASHBOARD_WORKSPACE}/drake/include-what-you-use.imp")
