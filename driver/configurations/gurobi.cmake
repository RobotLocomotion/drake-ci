# -*- mode: cmake; -*-
# vi: set ft=cmake:

if(GUROBI)
  set(GRB_LICENSE_FILE "${DASHBOARD_TEMP_DIR}/gurobi.lic")
  file(REMOVE "${GRB_LICENSE_FILE}")

  message(STATUS "Downloading Gurobi license file from AWS S3...")
  set(TOTAL_DOWNLOAD_ATTEMPTS 3)
  foreach(DOWNLOAD_ATTEMPT RANGE ${TOTAL_DOWNLOAD_ATTEMPTS})
    execute_process(
      COMMAND "${DASHBOARD_AWS_COMMAND}" s3 cp
        s3://drake-provisioning/gurobi/gurobi.lic "${GRB_LICENSE_FILE}"
      RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE)
    if(DASHBOARD_AWS_S3_RESULT_VARIABLE EQUAL 0)
      break()
    elseif(DOWNLOAD_ATTEMPT LESS TOTAL_DOWNLOAD_ATTEMPTS)
      message(STATUS "Download was NOT successful. Retrying...")
    else()
      fatal("Download of Gurobi license file from AWS S3 was NOT successful")
    endif()
  endforeach()

  if(NOT EXISTS "${GRB_LICENSE_FILE}")
    fatal("Gurobi license file was NOT found")
  endif()

  list(APPEND DASHBOARD_TEMPORARY_FILES GRB_LICENSE_FILE)
endif()

# Always set environment variable so remote caches may be shared.
set(ENV{GRB_LICENSE_FILE} "${GRB_LICENSE_FILE}")
