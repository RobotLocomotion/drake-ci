#!/bin/bash

# macOS: Turn on some debugging for dyld.
if [[ "$(uname -s)" == Darwin ]]; then
    export DYLD_PRINT_FRAMEWORKS=1
    export DYLD_PRINT_LIBRARIES=1
    export DYLD_PRINT_SEGMENTS=1
    export DYLD_PRINT_SEARCHING=1
fi

readonly CI_ROOT="$(dirname "${BASH_SOURCE}")"

ctest --extra-verbose --no-compress-output --script "${CI_ROOT}/ctest_driver_script.cmake"