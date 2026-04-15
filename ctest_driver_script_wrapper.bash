#!/bin/bash

set -euxo pipefail

readonly CI_ROOT="$(dirname "${BASH_SOURCE}")"

[[ -z "${TERM}" ]] || export CLICOLOR_FORCE=1

export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"

# Ensure the Jenkins workspace is cleared from previous runs.
readonly GLOBAL_WORKSPACE="$(realpath ${WORKSPACE}/..)"
if [[ "${GLOBAL_WORKSPACE}" == *workspace ]]; then
    sudo find "${GLOBAL_WORKSPACE}" -mindepth 1 -maxdepth 1 \
        -not -path "${WORKSPACE}" -not -path "${WORKSPACE}@tmp" \
        -exec rm -rf {} +
fi

# Provision image, if required (Linux only).
if [[ "$(uname -s)" == "Linux" && "${JOB_NAME}" =~ unprovisioned ]]; then
    sudo PATH="${PATH}" WORKSPACE="${WORKSPACE}" \
        "${CI_ROOT}/setup/ubuntu/install_prereqs"
fi

# Synchronize the system clock (so log timestamps will be accurate).
if [ -n "$(type -P chronyc)" ]; then
    # Synchronize using chrony.
    sudo PATH="${PATH}" chronyc makestep
    chronyc tracking
elif [ "$(uname)" == "Darwin" ]; then
    : # Allow macOS to proceed without explicit synchronization.
else
    echo "Unable to locate NTP interface" >&2
    exit 1
fi

# Set up SSH agent, used to fetch from private repositories.
AGENT=ssh-agent
[[ "$SSH_PRIVATE_KEY_FILE" == '-' ]] && AGENT=

# macOS: Since we're running back-to-back on the same AWS instance,
# clear the Bazel output root.
# See https://bazel.build/remote/output-directories.
if [[ "$(uname -s)" == Darwin ]]; then
  sudo rm -rf $HOME/Library/Caches/bazel
fi

# macOS: Enable multicast traffic on loopback interface for LCM.
# sudo is needed to modify the routing table
if [[ "$(uname -s)" == Darwin ]]; then
    sudo route -nv delete 224.0.0.0/4
    sudo route -nv add -net 224.0.0.0/4 -interface lo0
    netstat -nr
fi

# Hand off to the CMake driver script.
$AGENT ctest --extra-verbose --no-compress-output --script "${CI_ROOT}/ctest_driver_script.cmake"
