#!/bin/bash

# Copyright (c) 2020, Massachusetts Institute of Technology.
# Copyright (c) 2020, Toyota Research Institute.
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

set -euxo pipefail

readonly workspace="$1"

git config --global user.email drake.jenkins.bot@gmail.com
git config --global user.name drake-jenkins-bot

readonly codename="$(lsb_release -cs)"

gbp clone \
  --debian-branch="debian/${codename}" \
  --repo-email=GIT \
  --repo-user=GIT \
  git@github.com:RobotLocomotion/debian-drake.git \
  "${workspace}/debian-drake"

pushd "${workspace}/debian-drake"

git remote add upstream "${workspace}/src"

readonly version="0.0.$(date +%Y%m%d)"

git checkout upstream
git pull upstream master
git tag "upstream/${version}"

git checkout "debian/${codename}"
git merge --no-edit "upstream/${version}"

sudo mk-build-deps --host-arch amd64 -irt 'apt-get --no-install-recommends -qy' \
  "${workspace}/debian-drake/debian/control"

gbp buildpackage ---git-export=WC --git-no-pristine-tar -us -uc -nc

popd
