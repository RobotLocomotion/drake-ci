# -*- mode: cmake; -*-
# vi: set ft=cmake:

set(DASHBOARD_BAZEL_VERSION)

if (DISTRIBUTION STREQUAL "noble" AND GENERATOR STREQUAL "cmake" AND
  COMPILER STREQUAL "gcc" AND NOT DEBUG)
  # Special case to extract Drake's minimum-supported Bazel version from the
  # sources manually. This is to provide CI coverage of multiple Bazel versions
  # simultaneously.
  file(READ "${DASHBOARD_SOURCE_DIRECTORY}/CMakeLists.txt" CML_CONTENTS)
  string(REGEX MATCH
    "set\\(MINIMUM_BAZEL_VERSION[ \t\n\r]+\"?([0-9.]+)\"?[ \t\n\r]*\\)"
    DASHBOARD_BAZEL_REGEX_MATCH_OUTPUT_VARIABLE
    "${CML_CONTENTS}"
  )
  if (DASHBOARD_BAZEL_REGEX_MATCH_OUTPUT_VARIABLE)
    set(DASHBOARD_BAZEL_VERSION_OVERRIDE "${CMAKE_MATCH_1}")
    # Write a .bazeliskrc, which takes precedence over Drake's .bazelversion.
    configure_file(
      "${DASHBOARD_TOOLS_DIR}/.bazeliskrc.in"
      "${CTEST_SOURCE_DIRECTORY}/.bazeliskrc"
      @ONLY)
  else()
    fatal("could not determine bazel version")
  endif()
endif()

# Extract Drake's .bazelversion, usually of the form x.y.z-*.
set(VERSION_ARGS "${DASHBOARD_BAZEL_STARTUP_OPTIONS} --output_user_root=${CTEST_BINARY_DIRECTORY} version")
separate_arguments(VERSION_ARGS_LIST UNIX_COMMAND "${VERSION_ARGS}")
execute_process(COMMAND ${DASHBOARD_BAZEL_COMMAND} ${VERSION_ARGS_LIST}
  WORKING_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}"
  RESULT_VARIABLE DASHBOARD_BAZEL_VERSION_RESULT_VARIABLE
  OUTPUT_VARIABLE DASHBOARD_BAZEL_VERSION_OUTPUT_VARIABLE
  ERROR_QUIET
  OUTPUT_STRIP_TRAILING_WHITESPACE)

if(DASHBOARD_BAZEL_VERSION_RESULT_VARIABLE EQUAL 0)
  string(REGEX MATCH "Build label: ([0-9a-zA-Z.\\-]+)"
       DASHBOARD_BAZEL_REGEX_MATCH_OUTPUT_VARIABLE
       "${DASHBOARD_BAZEL_VERSION_OUTPUT_VARIABLE}")
  if(DASHBOARD_BAZEL_REGEX_MATCH_OUTPUT_VARIABLE)
    set(DASHBOARD_BAZEL_VERSION "${CMAKE_MATCH_1}")
  endif()
else()
  fatal("could not determine bazel version")
endif()
