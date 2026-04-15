# -*- mode: cmake; -*-
# vi: set ft=cmake:

if(DASHBOARD_FAILURE OR DASHBOARD_UNSTABLE)
  notice("CTest Status: NOT UPLOADING WHEEL BECAUSE WHEEL BUILD WAS NOT SUCCESSFUL")
else()
  notice("CTest Status: UPLOADING WHEEL(S)")
  # Some builds will produce multiple wheels, and in any case the exact names
  # can be extremely hard to predict aside from simply listing known names
  # (which is a maintenance nightmare). So, don't even bother trying; just
  # upload anything that's a '.whl' in the output directory.
  file(GLOB DASHBOARD_WHEELS "${DASHBOARD_WHEEL_OUTPUT_DIRECTORY}/*.whl")
  foreach(WHEEL IN LISTS DASHBOARD_WHEELS)
    aws_upload("${WHEEL}" "WHEEL UPLOAD")
  endforeach()
endif()
