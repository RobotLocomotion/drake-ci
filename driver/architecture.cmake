# -*- mode: cmake; -*-
# vi: set ft=cmake:

if(NOT APPLE)
  execute_process(
    COMMAND
      "dpkg-query" "--show"
      [==[--showformat=${Architecture-Variant}\n${Architecture}\n]==]
      "libc6"
    COMMAND
      "grep" "-m" "1" "."
    OUTPUT_VARIABLE DASHBOARD_DEB_ARCH
    RESULT_VARIABLE DASHBOARD_DEB_ARCH_RESULT
    ERROR_VARIABLE DASHBOARD_DEB_ARCH_ERROR
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  if (NOT DASHBOARD_DEB_ARCH_RESULT EQUAL 0)
    fatal("Unable to determine architecture: ${DASHBOARD_DEB_ARCH_ERROR}")
  endif()
endif()
