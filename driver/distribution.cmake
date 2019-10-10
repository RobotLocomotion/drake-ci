if(APPLE)
  set(DASHBOARD_UNIX_DISTRIBUTION "Apple")
  find_program(DASHBOARD_SW_VERS_COMMAND NAMES "sw_vers")
  if(NOT DASHBOARD_SW_VERS_COMMAND)
    fatal("sw_vers was not found")
  endif()
  execute_process(COMMAND "${DASHBOARD_SW_VERS_COMMAND}" "-productVersion"
    RESULT_VARIABLE SW_VERS_RESULT_VARIABLE
    OUTPUT_VARIABLE SW_VERS_OUTPUT_VARIABLE
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT SW_VERS_RESULT_VARIABLE EQUAL 0)
    fatal("unable to determine distribution release version")
  endif()
  if(SW_VERS_OUTPUT_VARIABLE MATCHES "([0-9]+[.][0-9]+)([.][0-9]+)?")
    set(DASHBOARD_UNIX_DISTRIBUTION_VERSION "${CMAKE_MATCH_1}")
  else()
    fatal("unable to determine distribution release version")
  endif()
  if(DASHBOARD_UNIX_DISTRIBUTION_VERSION VERSION_EQUAL "10.13")
    set(DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME "high-sierra")
  elseif(DASHBOARD_UNIX_DISTRIBUTION_VERSION VERSION_EQUAL "10.14")
    set(DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME "mojave")
  elseif(DASHBOARD_UNIX_DISTRIBUTION_VERSION VERSION_EQUAL "10.15")
    set(DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME "catalina")
  else()
    fatal("unable to determine distribution code name")
  endif()
else()
  find_program(DASHBOARD_LSB_RELEASE_COMMAND NAMES "lsb_release")
  if(NOT DASHBOARD_LSB_RELEASE_COMMAND)
    fatal("lsb_release was not found")
  endif()
  execute_process(COMMAND "${DASHBOARD_LSB_RELEASE_COMMAND}" "--id" "--short"
    RESULT_VARIABLE LSB_RELEASE_RESULT_VARIABLE
    OUTPUT_VARIABLE DASHBOARD_UNIX_DISTRIBUTION
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT LSB_RELEASE_RESULT_VARIABLE EQUAL 0)
    fatal("unable to determine distribution name")
  endif()
  execute_process(COMMAND "${DASHBOARD_LSB_RELEASE_COMMAND}" "--release" "--short"
    RESULT_VARIABLE LSB_RELEASE_RESULT_VARIABLE
    OUTPUT_VARIABLE DASHBOARD_UNIX_DISTRIBUTION_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT LSB_RELEASE_RESULT_VARIABLE EQUAL 0)
    fatal("unable to determine distribution release version")
  endif()
  execute_process(COMMAND "${DASHBOARD_LSB_RELEASE_COMMAND}" "--codename" "--short"
    RESULT_VARIABLE LSB_RELEASE_RESULT_VARIABLE
    OUTPUT_VARIABLE DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT LSB_RELEASE_RESULT_VARIABLE EQUAL 0)
    fatal("unable to determine distribution code name")
  endif()
endif()
