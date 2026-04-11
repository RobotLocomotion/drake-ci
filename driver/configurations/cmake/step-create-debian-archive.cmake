# -*- mode: cmake; -*-
# vi: set ft=cmake:

if(DASHBOARD_FAILURE OR DASHBOARD_UNSTABLE)
  notice("CTest Status: NOT CREATING DEBIAN ARCHIVE BECAUSE CMAKE BUILD WAS NOT SUCCESSFUL")
else()
  notice("CTest Status: CREATING DEBIAN ARCHIVE")
  # NOTE: do not use DASHBOARD_BAZEL_*_OPTIONS with this script.
  set(DEBIAN_ARGS
    "run" "//tools/release_engineering:repack_deb" "--" "--tgz"
    "${DASHBOARD_WORKSPACE}/${DASHBOARD_PACKAGE_ARCHIVE_NAME}"
    "--output-dir" "${DASHBOARD_WORKSPACE}")
  execute_process(COMMAND ${DASHBOARD_BAZEL_COMMAND} ${DEBIAN_ARGS}
    WORKING_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}"
    RESULT_VARIABLE DEBIAN_RESULT_VARIABLE)

  if(NOT DEBIAN_RESULT_VARIABLE EQUAL 0)
    append_step_status(
      "CMAKE DEBIAN ARCHIVE CREATION (ERROR CODE=${DEBIAN_RESULT_VARIABLE})"
      UNSTABLE)
  else()
    set(repack_deb_output "drake-dev_${DASHBOARD_DRAKE_VERSION}-1_${DASHBOARD_DEB_ARCH}.deb")
    set(repack_deb_path "${DASHBOARD_WORKSPACE}/${repack_deb_output}")
    if(NOT EXISTS "${repack_deb_path}")
      append_step_status("CMAKE PACKAGE DEBIAN CREATION COULD NOT FIND ${repack_deb_output} in ${DASHBOARD_WORKSPACE}" UNSTABLE)
    else()
      # For the uploaded package name, we want to structure it to include the
      # ubuntu codename (e.g. noble).
      set(DASHBOARD_DEBIAN_ARCHIVE_NAME
        "drake-dev_${DASHBOARD_DRAKE_VERSION}-1_${DASHBOARD_DEB_ARCH}-${DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME}.deb")
      file(RENAME "${repack_deb_path}" "${DASHBOARD_WORKSPACE}/${DASHBOARD_DEBIAN_ARCHIVE_NAME}")
      if(NOT EXISTS "${DASHBOARD_WORKSPACE}/${DASHBOARD_DEBIAN_ARCHIVE_NAME}")
        append_step_status("CMAKE PACKAGE DEBIAN CREATION COULD NOT RENAME ${repack_deb_path} to ${DASHBOARD_DEBIAN_ARCHIVE_NAME} in ${DASHBOARD_WORKSPACE}" UNSTABLE)
      else()
        message(STATUS "Debian archive created: ${DASHBOARD_DEBIAN_ARCHIVE_NAME}")
      endif()
    endif()
  endif()
endif()
