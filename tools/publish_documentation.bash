#!/bin/bash

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

set -eu -o pipefail

notice () {
  echo "*** $1"
}

die () {
  echo >&2 "$@"
  exit 1
}

readonly workspace="$1"
readonly doc="$2"

if [[ -z "${workspace}" || -z "${doc}" ]]; then
  die "Missing argument; Usage: $0 <workspace> <doc>"
fi

# Clone the GH pages repository.
git clone --single-branch \
  git@github.com:RobotLocomotion/RobotLocomotion.github.io.git \
  "${workspace}/gh-pages"

# Dump the generated documentation into the local checkout.
rsync --archive --delete --quiet \
      --exclude .buildinfo \
      --exclude .git \
      --exclude .github \
      --exclude .gitignore \
      --exclude googleb54a1809ac854371.html \
      --exclude LICENSE \
      --exclude README.md \
       "${doc}/" "${workspace}/gh-pages/"
cd "${workspace}/gh-pages"

# Commit our most recent changes, if any.
git config user.name drake-jenkins-bot
git config user.email drake.jenkins.bot@gmail.com
git add --all
if git diff-index --quiet HEAD; then
  notice "Documentation is unchanged."
  exit 0
fi
git commit -m "Documentation: RobotLocomotion/drake@$GIT_COMMIT"

# Determine if we need to prune the history. Allow up to `commit_max`, at which
# point the oldest commits are squashed and history is re-rooted to contain
# only the `commit_min` most recent commits.
readonly commit_min=30
readonly commit_max=100
maybe_force_push=
if [ "$(git rev-list --count HEAD)" -lt "${commit_max}" ]; then
  notice "No pruning to be done."
else
  notice "Commit limit reached (${commit_max})."
  notice "Pruning to the most recent ${commit_min} commits..."
  readonly offset=$((commit_min - 1))

  # Assemble our commit message.
  readonly last_sha=$(git rev-parse --short HEAD~${commit_min})
  readonly last_date=$(git show -s --date=short --format='%ad' ${last_sha})
  readonly last_message=$(git show -s --format='%h %s' ${last_sha})
  readonly commit_message=$(cat <<EOF
Reset history as of ${last_date}

${last_message}
EOF
)

  # Reset history.
  git checkout --orphan temp HEAD~${offset}
  git commit -m "${commit_message}"
  git checkout master
  git rebase --onto temp HEAD~${offset}
  git branch -D temp

  maybe_force_push=--force
fi

notice "Pushing changes..."
git push origin master ${maybe_force_push}
