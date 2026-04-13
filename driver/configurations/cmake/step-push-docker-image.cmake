# -*- mode: cmake; -*-
# vi: set ft=cmake:

macro(docker_push TAG)
  if(NOT DASHBOARD_UNSTABLE)
    set(DOCKER_PUSH_IMAGE_ARGS "push robotlocomotion/drake:${TAG}")
    separate_arguments(
      DOCKER_PUSH_IMAGE_ARGS_LIST UNIX_COMMAND
      "${DOCKER_PUSH_IMAGE_ARGS}")
    foreach(RETRIES RANGE 3)
      execute_process(
        COMMAND "sudo" "${DASHBOARD_DOCKER_COMMAND}"
                ${DOCKER_PUSH_IMAGE_ARGS_LIST}
        RESULT_VARIABLE DOCKER_PUSH_IMAGE_RESULT_VARIABLE)
      if(DOCKER_PUSH_IMAGE_RESULT_VARIABLE EQUAL 0)
        break()
      endif()
      execute_process(COMMAND "sleep" "15")
    endforeach()
    if(NOT DOCKER_PUSH_IMAGE_RESULT_VARIABLE EQUAL 0)
      append_step_status(
        "CMAKE PUSHING DOCKER IMAGE (ROBOTLOCOMOTION/DRAKE:${TAG})" UNSTABLE)
    endif()
  endif()
endmacro()

if(DASHBOARD_FAILURE OR DASHBOARD_UNSTABLE)
  notice("CTest Status: NOT PUSHING DOCKER IMAGE BECAUSE CMAKE BUILD WAS NOT SUCCESSFUL")
else()
  notice("CTest Status: PUSHING DOCKER IMAGE")

  if(NOT DASHBOARD_UNSTABLE)
    set(DOCKER_LOGIN_ARGS "login --username $ENV{DOCKER_USERNAME} --password-stdin")
    separate_arguments(DOCKER_LOGIN_ARGS_LIST UNIX_COMMAND "${DOCKER_LOGIN_ARGS}")
    execute_process(COMMAND "sudo" "${DASHBOARD_DOCKER_COMMAND}" ${DOCKER_LOGIN_ARGS_LIST}
      RESULT_VARIABLE DOCKER_LOGIN_RESULT_VARIABLE
      INPUT_FILE "$ENV{DOCKER_PASSWORD_FILE}")
    if(NOT DOCKER_LOGIN_RESULT_VARIABLE EQUAL 0)
      append_step_status("CMAKE PUSHING DOCKER IMAGE (DOCKER LOGIN)" UNSTABLE)
    endif()
  endif()

  if(DASHBOARD_TRACK STREQUAL "Nightly")
    # Push the nightly images, tagged both with and without the distro name.
    docker_push("${DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME}-${DATE}")
    docker_push("${DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME}")
    if(DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME STREQUAL ${DEFAULT_DOCKER_DISTRIBUTION})
      docker_push("${DATE}")
      docker_push("latest")
    endif()
  elseif(DASHBOARD_TRACK STREQUAL "Staging")
    # Push the staging images, tagged both with and without the distro name.
    docker_push("${DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME}-${DASHBOARD_DRAKE_VERSION}-staging")
    if(DASHBOARD_UNIX_DISTRIBUTION_CODE_NAME STREQUAL ${DEFAULT_DOCKER_DISTRIBUTION})
      docker_push("${DASHBOARD_DRAKE_VERSION}-staging")
    endif()
  else()
    # Should never get here...
    notice("CTest Status: NOT PUSHING DOCKER IMAGE DUE TO UNEXPECTED TRACK ${DASHBOARD_TRACK}")
  endif()
endif()
