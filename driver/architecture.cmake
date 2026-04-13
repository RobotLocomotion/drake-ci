# -*- mode: cmake; -*-
# vi: set ft=cmake:

if(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "x86_64")
  set(DASHBOARD_DEB_ARCH "amd64")
elseif(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "arm64" OR
  CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "aarch64")
  set(DASHBOARD_DEB_ARCH "arm64")
else()
  fatal("Unable to determine architecture, or unsupported: ${CMAKE_HOST_SYSTEM_PROCESSOR}")
endif()
