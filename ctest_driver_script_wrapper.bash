#!/bin/bash

# BSD 3-Clause License
#
# Copyright (c) 2016, Massachusetts Institute of Technology.
# Copyright (c) 2016, Toyota Research Institute.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

set -euxo pipefail

readonly CI_ROOT="$(dirname "${BASH_SOURCE}")"

[[ -z "${TERM}" ]] || export CLICOLOR_FORCE=1

# On m1 mac, detect if we can re-run the script under arm64, since Jenkins'
# login initially runs in an emulated x86_64 (Rosetta 2) environment.
if [[ "$(uname -s)" == Darwin && "$(uname -p)" != "arm" ]]; then
    if arch -arch arm64 true &>/dev/null; then
        exec arch -arch arm64 "$0" "$@"
    fi
fi

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
    sudo --preserve-env "${CI_ROOT}/setup/ubuntu/install_prereqs"
fi

# Synchronize the system clock (so log timestamps will be accurate).
if [ -n "$(type -P chronyc)" ]; then
    # Synchronize using chrony.
    sudo --preserve-env chronyc makestep
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

# macOS: Enable multicast traffic on loopback interface for LCM.
# sudo is needed to modify the routing table
if [[ "$(uname -s)" == Darwin ]]; then
    sudo route -nv delete 224.0.0.0/4
    sudo route -nv add -net 224.0.0.0/4 -interface lo0
    netstat -nr
fi

# macOS: Since we're running back-to-back on the same AWS instance,
# clear the Bazel output root.
# See https://bazel.build/remote/output-directories.
if [[ "$(uname -s)" == Darwin ]]; then
  # TODO(tyler-yankee): The former directory is the default location of the
  # output root under Bazel <9, and can be removed once Drake switches to Bazel
  # 9 on this platform.
  sudo rm -rf /private/var/tmp/_bazel_$USER $HOME/Library/Caches/bazel
fi

# Hand off to the CMake driver script.
$AGENT ctest --extra-verbose --no-compress-output --script "${CI_ROOT}/ctest_driver_script.cmake"
