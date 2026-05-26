# -*- mode: cmake; -*-
# vi: set ft=cmake:

include(${DASHBOARD_DRIVER_DIR}/configurations/cache.cmake)

if(REMOTE_CACHE)
  if(DEBUG)
    set(DASHBOARD_REMOTE_MAX_CONNECTIONS 16)
    set(DASHBOARD_REMOTE_RETRIES 1)
    set(DASHBOARD_REMOTE_TIMEOUT 240)
  else()
    set(DASHBOARD_REMOTE_MAX_CONNECTIONS 64)
    set(DASHBOARD_REMOTE_RETRIES 4)
    set(DASHBOARD_REMOTE_TIMEOUT 120)
  endif()
  configure_file("${DASHBOARD_TOOLS_DIR}/remote.bazelrc.in"
    "${CTEST_SOURCE_DIRECTORY}/remote.bazelrc" @ONLY
  )
  configure_file("${DASHBOARD_TOOLS_DIR}/remote-v9.1.bazelrc.in"
    "${CTEST_SOURCE_DIRECTORY}/remote-v9.1.bazelrc" @ONLY
  )
endif()
