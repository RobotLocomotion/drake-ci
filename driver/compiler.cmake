# -*- mode: cmake; -*-
# vi: set ft=cmake:

if(APPLE)
  set(DASHBOARD_CC_COMMAND "/usr/bin/clang")
  set(DASHBOARD_CXX_COMMAND "/usr/bin/clang++")
else()
  if(GENERATOR STREQUAL "bazel" AND COMPILER STREQUAL "clang")
    # Ask Bazel which Clang it's using.
    determine_compiler(DASHBOARD_CC_COMMAND DASHBOARD_CXX_COMMAND)
  else()
    set(DASHBOARD_CC_COMMAND "/usr/bin/gcc")
    set(DASHBOARD_CXX_COMMAND "/usr/bin/g++")
  endif()
endif()
compiler_version_string("${DASHBOARD_CC_COMMAND}" DASHBOARD_CC_VERSION_STRING)
compiler_version_string("${DASHBOARD_CXX_COMMAND}" DASHBOARD_CXX_VERSION_STRING)

string(TOUPPER "${COMPILER}" COMPILER_UPPER)
