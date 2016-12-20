#!/bin/bash

# NOTE: Dump a whole bunch of trace diagnostics in an attempt to figure out why
# git sometimes cannot lock the submodule config file.
# See https://github.com/RobotLocomotion/drake/issues/4034
trace=
if [ $(type -t strace) = 'file' ]; then
  log=".git-$(date -u +%F-%T.%N)-$$"
  trace="strace -f -e trace=file"
  echo "git $@" > $log.cmd
fi

tries=${GIT_RETRIES:-5}

for (( i = 0; i < tries; ++i )); do
  ${trace:+$trace -o $log.trace.$i} git "$@" && break
  result=$?
  touch "$WORKSPACE/GIT_ERROR"
  sleep $(( 2 ** i ))
done

exit $result
