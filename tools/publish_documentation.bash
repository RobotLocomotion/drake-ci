#!/bin/bash -ex
export PATH="/usr/local/bin:${PATH}"
git clone --quiet --single-branch git@github.com:RobotLocomotion/RobotLocomotion.github.io.git "${WORKSPACE}/gh-pages"
rsync --archive --delete --exclude=.git --exclude=.gitignore --exclude=LICENSE --exclude=README --quiet "${WORKSPACE}/src/build/install/share/doc/" "${WORKSPACE}/gh-pages/"
cd "${WORKSPACE}/gh-pages"
git add --all
if git diff-index --quiet HEAD; then
  echo "*** Documentation is unchanged"
else
  git commit --message="Documentation: RobotLocomotion/drake@$GIT_COMMIT" --quiet
  git push --quiet origin master
fi
