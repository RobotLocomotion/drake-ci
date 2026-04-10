# -*- mode: cmake; -*-
# vi: set ft=cmake:

if(DASHBOARD_TRACK STREQUAL "Staging")
  if(NOT "$ENV{DRAKE_VERSION}" MATCHES "^[0-9].[0-9]")
    fatal("drake version is invalid or not set")
  endif()
  set(DASHBOARD_DRAKE_VERSION "$ENV{DRAKE_VERSION}")
else()
  string(TIMESTAMP DATE "%Y%m%d")
  string(TIMESTAMP TIME "%H%M%S")
  set(DASHBOARD_PACKAGE_DATE "${DATE}")
  set(DASHBOARD_PACKAGE_DATE_TIME "${DATE}.${TIME}")
  execute_process(COMMAND "${CTEST_GIT_COMMAND}" rev-parse --short=8 HEAD
    WORKING_DIRECTORY "${CTEST_SOURCE_DIRECTORY}"
    RESULT_VARIABLE GIT_REV_PARSE_RESULT_VARIABLE
    OUTPUT_VARIABLE GIT_REV_PARSE_OUTPUT_VARIABLE
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  # For nightly uploads we only want YYYYMMDD so that the users do not need to
  # guess the build time.  For all other builds, we want the date, time, and
  # also the commit hash.
  if(DASHBOARD_TRACK STREQUAL "Nightly")
    set(DASHBOARD_DRAKE_VERSION "0.0.${DASHBOARD_PACKAGE_DATE}")
  elseif(GIT_REV_PARSE_RESULT_VARIABLE EQUAL 0)
    set(DASHBOARD_PACKAGE_COMMIT "${GIT_REV_PARSE_OUTPUT_VARIABLE}")
    set(DASHBOARD_DRAKE_VERSION "0.0.${DASHBOARD_PACKAGE_DATE_TIME}+git${DASHBOARD_PACKAGE_COMMIT}")
  else()
    set(DASHBOARD_PACKAGE_COMMIT "unknown")
    set(DASHBOARD_DRAKE_VERSION "0.0.${DASHBOARD_PACKAGE_DATE_TIME}+unknown")
  endif()

  string(REGEX REPLACE "[.]0+([0-9])" ".\\1"
    DASHBOARD_DRAKE_VERSION "${DASHBOARD_DRAKE_VERSION}")
  set(ENV{DRAKE_VERSION} "${DASHBOARD_DRAKE_VERSION}")
endif()
