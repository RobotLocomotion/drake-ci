#!/bin/bash



readonly CI_ROOT="$(dirname "${BASH_SOURCE}")"

ctest --extra-verbose --no-compress-output --script "${CI_ROOT}/ctest_driver_script.cmake"
