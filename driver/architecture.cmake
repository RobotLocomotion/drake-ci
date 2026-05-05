# -*- mode: cmake; -*-
# vi: set ft=cmake:

if(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "x86_64")
  # Check we have an architecture variant enabled; if not, the output is empty.
  execute_process(
      COMMAND "dpkg-query" "--show" "--showformat=\${Architecture-Variant}" "libc6"
      OUTPUT_VARIABLE DASHBOARD_DEB_ARCH
      COMMAND_ECHO NONE
      OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT DASHBOARD_DEB_ARCH)
    set(DASHBOARD_DEB_ARCH "amd64")
  endif()
elseif(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "arm64" OR
  CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "aarch64")
  set(DASHBOARD_DEB_ARCH "arm64")
else()
  fatal("Unable to determine architecture, or unsupported: ${CMAKE_HOST_SYSTEM_PROCESSOR}")
endif()
