# -*- mode: cmake; -*-
# vi: set ft=cmake:

notice("CTest Status: INSTALL DOCKER PREREQUISITES")

execute_process(COMMAND "docker" "run" "hello-world"
  RESULT_VARIABLE DOCKER_RESULT_VARIABLE)
if(DOCKER_RESULT_VARIABLE EQUAL 0)
  return()
endif()

execute_process(COMMAND "sudo" "${DASHBOARD_SETUP_DIR}/docker/install_prereqs"
  RESULT_VARIABLE DOCKER_INSTALL_PREREQS_RESULT_VARIABLE)
if(NOT DOCKER_INSTALL_PREREQS_RESULT_VARIABLE EQUAL 0)
  append_step_status("WHEEL PROVISION (INSTALL DOCKER PREREQUISITES)" UNSTABLE)
endif()
