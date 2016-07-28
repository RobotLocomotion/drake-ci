#!/bin/bash -x
export PATH="/usr/local/bin:${PATH}"
ctest -Dbuildname="${JOB_NAME}" -Dsite="${NODE_NAME}" -S "${WORKSPACE}/ci/ctest_driver_script_catkin.cmake" --extra-verbose --no-compress-output --output-on-failure
[[ (-e "${WORKSPACE}/SUCCESS" || -e "${WORKSPACE}/UNSTABLE") && ! -e "${WORKSPACE}/FAILURE" ]]
