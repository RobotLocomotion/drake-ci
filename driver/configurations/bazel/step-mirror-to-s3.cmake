# -*- mode: cmake; -*-
# vi: set ft=cmake:

if(DASHBOARD_FAILURE OR DASHBOARD_UNSTABLE)
  notice("CTest Status: NOT MIRRORING TO S3 BECAUSE BAZEL BUILD WAS NOT SUCCESSFUL")
else()
  notice("CTest Status: MIRRORING SOURCE DEPENDENCY ARCHIVES TO S3")
  set(MIRROR_TO_S3_WORKSPACE_CMD "bazel-bin/tools/workspace/mirror_to_s3")
  if(NOT MIRROR_TO_S3 STREQUAL "publish")
    list(APPEND MIRROR_TO_S3_WORKSPACE_CMD "--no-upload")
  endif()
  execute_process(COMMAND ${MIRROR_TO_S3_WORKSPACE_CMD}
    WORKING_DIRECTORY "${CTEST_SOURCE_DIRECTORY}"
    RESULT_VARIABLE MIRROR_TO_S3_WORKSPACE_RESULT_VARIABLE)
  if(NOT MIRROR_TO_S3_WORKSPACE_RESULT_VARIABLE EQUAL 0)
    append_step_status("BAZEL MIRRORING SOURCE DEPENDENCY ARCHIVES TO S3" UNSTABLE)
  endif()

  notice("CTest Status: MIRRORING RELEASE ARTIFACTS TO S3")
  # Release artifact mirroring needs GitHub credentials to avoid rate limiting.
  file(MAKE_DIRECTORY "$ENV{HOME}/.config")
  file(WRITE
    "$ENV{HOME}/.config/readonly_github_api_token.txt"
    "$ENV{GITHUB_ACCESS_TOKEN}"
  )
  set(MIRROR_TO_S3_RELEASE_CMD "bazel-bin/tools/release_engineering/mirror_to_s3")
  if(NOT MIRROR_TO_S3 STREQUAL "publish")
    list(APPEND MIRROR_TO_S3_RELEASE_CMD "--dry-run")
  endif()
  execute_process(COMMAND ${MIRROR_TO_S3_RELEASE_CMD}
    WORKING_DIRECTORY "${CTEST_SOURCE_DIRECTORY}"
    RESULT_VARIABLE MIRROR_TO_S3_RELASE_RESULT_VARIABLE)
  if(NOT MIRROR_TO_S3_RELASE_RESULT_VARIABLE EQUAL 0)
    append_step_status("BAZEL MIRRORING RELEASE ARTIFACTS TO S3" UNSTABLE)
  endif()
endif()
