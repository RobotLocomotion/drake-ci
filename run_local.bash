#!/bin/bash

# Copyright (c) 2016, Massachusetts Institute of Technology.
# Copyright (c) 2016, Toyota Research Institute.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

export compiler=clang
export coverage=false
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
