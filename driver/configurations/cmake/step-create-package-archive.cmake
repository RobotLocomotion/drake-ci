# -*- mode: cmake; -*-
# vi: set ft=cmake:

if(DASHBOARD_FAILURE OR DASHBOARD_UNSTABLE)
  notice("CTest Status: NOT CREATING PACKAGE ARCHIVE BECAUSE CMAKE BUILD WAS NOT SUCCESSFUL")
else()
  notice("CTest Status: CREATING PACKAGE ARCHIVE")
  if(NOT DASHBOARD_UNSTABLE)
    if(APPLE)
      set(DASHBOARD_PACKAGE_ARCHIVE_DISTRIBUTION mac-arm64)
    else()
      # For compatibility reasons, our Noble amd64 binaries are named plainly
      # without any architecture information. For all other binaries moving
      # forward (e.g., Noble arm64, and all Resolute), incorporate the
      # architecture and variant as applicable in all package names.
      if(DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME STREQUAL "noble" AND CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "x86_64")
        set(DASHBOARD_PACKAGE_ARCHIVE_DISTRIBUTION "${DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME}")
      else()
        set(DASHBOARD_PACKAGE_ARCHIVE_DISTRIBUTION "${DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME}-${DASHBOARD_DEB_ARCH}")
      endif()
    endif()

    set(DASHBOARD_PACKAGE_NAME "drake-${DASHBOARD_DRAKE_VERSION}")
    set(DASHBOARD_PACKAGE_ARCHIVE_NAME "${DASHBOARD_PACKAGE_NAME}-${DASHBOARD_PACKAGE_ARCHIVE_DISTRIBUTION}.tar.gz")

    execute_process(COMMAND "${CMAKE_COMMAND}" -E tar czf "${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}" drake
      WORKING_DIRECTORY /opt
      RESULT_VARIABLE TAR_RESULT_VARIABLE)
    if(NOT TAR_RESULT_VARIABLE EQUAL 0)
      append_step_status("CMAKE PACKAGE ARCHIVE CREATION" UNSTABLE)
    endif()
  endif()
endif()
