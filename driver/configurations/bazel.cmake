# Jenkins passes down the value of JAVA_HOME from master to slave for
# inexplicable reasons.
if(UNIX_DISTRIBUTION STREQUAL "Ubuntu" AND UNIX_DISTRIBUTION_VERSION STREQUAL "16.04")
  set(ENV{JAVA_HOME} "/usr/lib/jvm/java-8-openjdk-amd64")
endif()

find_program(DASHBOARD_BAZEL_COMMAND bazel)
if(NOT DASHBOARD_BAZEL_COMMAND)
  fatal("bazel was not found")
endif()

# Extract the version. Usually of the form x.y.z-*.
execute_process(COMMAND ${DASHBOARD_BAZEL_COMMAND} version
  RESULT_VARIABLE DASHBOARD_BAZEL_VERSION_RESULT_VARIABLE
  OUTPUT_VARIABLE DASHBOARD_BAZEL_VERSION_OUTPUT_VARIABLE)

if(DASHBOARD_BAZEL_VERSION_RESULT_VARIABLE EQUAL 0)
  string(REGEX MATCH "Build label: ([0-9a-zA-Z.\\-]+)"
       DASHBOARD_BAZEL_REGEX_MATCH_OUTPUT_VARIABLE
       "${DASHBOARD_BAZEL_VERSION_OUTPUT_VARIABLE}")
  if(DASHBOARD_BAZEL_REGEX_MATCH_OUTPUT_VARIABLE)
    set(DASHBOARD_BAZEL_VERSION "${CMAKE_MATCH_1}")
  endif()
endif()

# Set bazel options
set(DASHBOARD_BAZEL_STARTUP_OPTIONS
  "--output_user_root=${CTEST_BINARY_DIRECTORY}")
set(DASHBOARD_BAZEL_BUILD_OPTIONS "--compilation_mode")

if(DEBUG)
  set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS}=dbg")
else()
  set(DASHBOARD_BAZEL_BUILD_OPTIONS "${DASHBOARD_BAZEL_BUILD_OPTIONS}=opt")
endif()

# Report build configuration
report_configuration("
  ==================================== >DASHBOARD_
  UNIX
  UNIX_DISTRIBUTION
  UNIX_DISTRIBUTION_VERSION
  APPLE
  ====================================
  CMAKE_VERSION
  ====================================
  CTEST_BUILD_NAME(DASHBOARD_BUILD_NAME)
  CTEST_CHANGE_ID
  CTEST_GIT_COMMAND
  CTEST_SITE
  CTEST_UPDATE_COMMAND
  CTEST_UPDATE_VERSION_ONLY
  ==================================== ENV
  JAVA_HOME
  ==================================== >DASHBOARD_
  BAZEL_COMMAND
  BAZEL_VERSION
  BAZEL_STARTUP_OPTIONS
  BAZEL_BUILD_OPTIONS
  ====================================
  ")

# Run the build
execute_step(bazel build)

# Determine build result
if(NOT DASHBOARD_FAILURE)
  format_plural(DASHBOARD_MESSAGE
    ZERO "SUCCESS"
    ONE "SUCCESS BUT WITH 1 BUILD WARNING"
    MANY "SUCCESS BUT WITH # BUILD WARNINGS"
    ${DASHBOARD_NUMBER_BUILD_WARNINGS})
endif()

# Report dashboard status
execute_step(common report-status)
