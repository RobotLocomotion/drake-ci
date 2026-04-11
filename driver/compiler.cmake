# -*- mode: cmake; -*-
# vi: set ft=cmake:

if (GENERATOR STREQUAL "cmake" AND COMPILER STREQUAL "gcc")
  # Provide CI coverage of Drake's build logic for compiler identification by
  # explicitly not specifying the compiler.
  set(DASHBOARD_CC_COMMAND)
  set(DASHBOARD_CXX_COMMAND)
  verify_cc_is_gcc(CC_COMMAND CXX_COMMAND)
  compiler_version_string("${CC_COMMAND}" DASHBOARD_CC_VERSION_STRING)
  compiler_version_string("${CXX_COMMAND}" DASHBOARD_CXX_VERSION_STRING)
  unset(CC_COMMAND)
  unset(CXX_COMMAND)
else()
  determine_compiler(DASHBOARD_CC_COMMAND DASHBOARD_CXX_COMMAND)
  compiler_version_string("${DASHBOARD_CC_COMMAND}" DASHBOARD_CC_VERSION_STRING)
  compiler_version_string("${DASHBOARD_CXX_COMMAND}" DASHBOARD_CXX_VERSION_STRING)
endif()

string(TOUPPER "${COMPILER}" COMPILER_UPPER)
