# -*- mode: cmake; -*-
# vi: set ft=cmake:

cmake_minimum_required(VERSION 3.15)

set(DASHBOARD_CI_DIR ${CMAKE_CURRENT_LIST_DIR})
set(DASHBOARD_DRIVER_DIR ${CMAKE_CURRENT_LIST_DIR}/driver)
set(DASHBOARD_SETUP_DIR ${CMAKE_CURRENT_LIST_DIR}/setup)
set(DASHBOARD_TOOLS_DIR ${CMAKE_CURRENT_LIST_DIR}/tools)
if(EXISTS "/media/ephemeral0/tmp")
  set(DASHBOARD_TEMP_DIR "/media/ephemeral0/tmp")
else()
  set(DASHBOARD_TEMP_DIR "/tmp")
endif()
set(DASHBOARD_TEMPORARY_FILES "")
set(DASHBOARD_REMOTE_CACHE "http://10.221.188.9")

include(${DASHBOARD_DRIVER_DIR}/functions.cmake)

mktemp(DASHBOARD_FILE_DOWNLOAD_TEMP file_download_XXXXXXXX
  "temporary download file"
)
list(APPEND DASHBOARD_TEMPORARY_FILES DASHBOARD_FILE_DOWNLOAD_TEMP)
message(STATUS
    "Testing download of remote cache server: '${DASHBOARD_REMOTE_CACHE}'")
file(DOWNLOAD "${DASHBOARD_REMOTE_CACHE}" "${DASHBOARD_FILE_DOWNLOAD_TEMP}"
  STATUS DASHBOARD_DOWNLOAD_STATUS
  LOG DASHBOARD_DOWNLOAD_LOG
)
list(GET DASHBOARD_DOWNLOAD_STATUS 0 DASHBOARD_DOWNLOAD_STATUS_0)
if(NOT DASHBOARD_DOWNLOAD_STATUS_0 EQUAL 0)
  message(WARNING
    "*** Disabling remote cache because could NOT contact remote cache server"
    "\n${DASHBOARD_DOWNLOAD_LOG}"
  )
endif()
