# -*- mode: cmake; -*-
# vi: set ft=cmake:

if(APPLE)
  set(DASHBOARD_CC_COMMAND "/usr/bin/clang")
else()
  if(GENERATOR STREQUAL "bazel" AND COMPILER STREQUAL "clang")
    # Ask Bazel which Clang it's using.
    determine_compiler(DASHBOARD_CC_COMMAND)
  else()
    set(DASHBOARD_CC_COMMAND "/usr/bin/gcc")
  endif()
endif()
compiler_version_string("${DASHBOARD_CC_COMMAND}" DASHBOARD_CC_VERSION_STRING)

string(TOUPPER "${COMPILER}" COMPILER_UPPER)

if(COMPILER STREQUAL "clang")
  set(DASHBOARD_COPT "-fcolor-diagnostics")
else()  # gcc
  set(DASHBOARD_COPT "-fdiagnostics-color=always")
endif()
