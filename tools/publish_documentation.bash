#!/bin/bash -ex

# BSD 3-Clause License
#
# Copyright (c) 2017, Massachusetts Institute of Technology.
# Copyright (c) 2017, Toyota Research Institute.
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

workspace="$1"
doc="$2"

export PATH="/usr/local/bin:${PATH}"
git clone --quiet --single-branch git@github.com:RobotLocomotion/RobotLocomotion.github.io.git "${workspace}/gh-pages"
rsync --archive --delete \
      --exclude .buildinfo \
      --exclude .git \
      --exclude .github \
      --exclude .gitignore \
      --exclude googleb54a1809ac854371.html \
      --exclude LICENSE \
      --exclude README.md \
      --quiet "${doc}/" "${workspace}/gh-pages/"
cd "${workspace}/gh-pages"
git config user.name drake-jenkins-bot
git config user.email drake.jenkins.bot@gmail.com
git add --all
if git diff-index --quiet HEAD; then
  echo "*** Documentation is unchanged"
else
  git commit --message="Documentation: RobotLocomotion/drake@$GIT_COMMIT" --quiet
  git push --quiet origin master
fi
