#!/bin/bash

export compiler=clang
export debug=false
export documentation=false
export everything=false
export generator=bazel
export matlab=false
export package=false
export provision=false
export snopt=false
export track=experimental

export BUILD_ID="$(date -u +'%y%j.%H.%M')"
export JOB_NAME="unix-${compiler}-experimental"
export NODE_NAME=$(hostname -s)
export WORKSPACE="${HOME}/workspace/${JOB_NAME}"
export GIT_COMMIT=""

export PATH="/usr/local/bin:${PATH}"

ctest -Dbuildname="${JOB_NAME}" -Dsite="${NODE_NAME}" -S "${WORKSPACE}/ci/ctest_driver_script.cmake" --extra-verbose --output-on-failure
[[ (-e "${WORKSPACE}/SUCCESS" || -e "${WORKSPACE}/UNSTABLE") && ! -e "${WORKSPACE}/FAILURE" ]]
