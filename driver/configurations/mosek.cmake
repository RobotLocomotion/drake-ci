# -*- mode: cmake; -*-
# vi: set ft=cmake:

set(MOSEKLM_LICENSE_FILE "${DASHBOARD_TEMP_DIR}/mosek.lic")
file(REMOVE "${MOSEKLM_LICENSE_FILE}")

if(MOSEK)
  message(STATUS "Downloading MOSEK license file from AWS S3...")
  set(TOTAL_DOWNLOAD_ATTEMPTS 3)
  foreach(DOWNLOAD_ATTEMPT RANGE ${TOTAL_DOWNLOAD_ATTEMPTS})
    execute_process(
      COMMAND "${DASHBOARD_AWS_COMMAND}" s3 cp
        s3://drake-provisioning/mosek/mosek.lic "${MOSEKLM_LICENSE_FILE}"
      RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE)
    if(DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
      break()
    elseif(DOWNLOAD_ATTEMPT LESS TOTAL_DOWNLOAD_ATTEMPTS)
      message(STATUS "Download was NOT successful. Retrying...")
    else()
      fatal("Download of MOSEK license file from AWS S3 was NOT successful")
    endif()
  endforeach()

  if(NOT EXISTS "${MOSEKLM_LICENSE_FILE}")
    fatal("MOSEK license file was NOT found")
  endif()

  list(APPEND DASHBOARD_TEMPORARY_FILES MOSEKLM_LICENSE_FILE)
endif()

# Always set environment variable so remote caches may be shared.
set(ENV{MOSEKLM_LICENSE_FILE} "${MOSEKLM_LICENSE_FILE}")
