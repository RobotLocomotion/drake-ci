#!/bin/bash -ex
workspace="$1"
installation="$2"

export PATH="/usr/local/bin:${PATH}"
git clone --quiet --single-branch git@github.com:RobotLocomotion/RobotLocomotion.github.io.git "${workspace}/gh-pages"
rsync --archive --delete --exclude=.git --exclude=.gitignore --exclude=LICENSE --exclude=README.md --quiet "${installation}/share/doc/drake/" "${workspace}/gh-pages/"
cd "${workspace}/gh-pages"
git add --all
if git diff-index --quiet HEAD; then
  echo "*** Documentation is unchanged"
else
  git commit --message="Documentation: RobotLocomotion/drake@$GIT_COMMIT" --quiet
  git push --quiet origin master
fi
