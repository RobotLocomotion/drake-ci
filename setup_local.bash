#!/bin/bash -x

ci="$(dirname "$(perl -MCwd -le 'print Cwd::abs_path(shift)' "$0")")"
drake=~/workspace/repo/drake

mkdir -p ~/workspace/repo

git clone https://github.com/robotlocomotion/drake $drake

for compiler in gcc clang; do
  workspace=~/workspace/unix-$compiler-experimental
  mkdir -p $workspace/src
  ln -s $ci $workspace/ci
  ln -s $drake $workspace/src/drake
done
