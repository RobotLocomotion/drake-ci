#!/bin/bash

# This is a sample UNIX shell script to run ctest_driver_script.cmake locally
# without Jenkins.
# 1. Update variables in this script to build you want, including the path to
#    the cmake executable.
# 2. Clone drake into the path specified in $WORKSPACE.
# 3. Run this script.

export compiler=gcc
export coverage=false
export debug=false
export documentation=false
export matlab=false
export minimal=false
export openSource=true
export ros=false
export track=experimental

export BUILD_ID=0
export JOB_NAME=unix-experimental
export NODE_NAME=$(hostname -s)
export WORKSPACE="${HOME}/workspace/unix-experimental"

export PATH="/usr/local/bin:${PATH}"

ctest -Dbuildname="${JOB_NAME}" -Dsite="${NODE_NAME}" -S "${WORKSPACE}/ci/ctest_driver_script.cmake" --extra-verbose --output-on-failure
[[ (-e "${WORKSPACE}/SUCCESS" || -e "${WORKSPACE}/UNSTABLE") && ! -e "${WORKSPACE}/FAILURE" ]]
