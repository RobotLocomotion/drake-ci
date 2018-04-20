if(NOT APPLE)
  set(ENV{GUROBI_PATH} "/opt/gurobi752/linux64")
endif()

set(GRB_LICENSE_FILE "/tmp/gurobi.lic")
file(REMOVE "${GRB_LICENSE_FILE}")

message(STATUS "Downloading Gurobi license file from AWS S3...")
execute_process(
  COMMAND "${DASHBOARD_AWS_COMMAND}" s3 cp
    s3://drake-provisioning/gurobi/gurobi.lic "${GRB_LICENSE_FILE}"
  RESULT_VARIABLE DASHBOARD_AWS_S3_RESULT_VARIABLE
  OUTPUT_VARIABLE DASHBOARD_AWS_S3_OUTPUT_VARIABLE
  ERROR_VARIABLE DASHBOARD_AWS_S3_OUTPUT_VARIABLE)
list(APPEND DASHBOARD_TEMPORARY_FILES GRB_LICENSE_FILE)
message("${DASHBOARD_AWS_S3_OUTPUT_VARIABLE}")

if(NOT EXISTS "${GRB_LICENSE_FILE}")
  fatal("Gurobi license file was NOT found")
endif()

set(ENV{GRB_LICENSE_FILE} "${GRB_LICENSE_FILE}")
