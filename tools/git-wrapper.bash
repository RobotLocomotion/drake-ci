#!/bin/bash

# NOTE: Dump a whole bunch of trace diagnostics in an attempt to figure out why
# git sometimes cannot lock the submodule config file.
# See https://github.com/RobotLocomotion/drake/issues/4034
trace=
[ $(type -t strace) = 'file' ] && trace='strace -f -e trace=file'

tries=${GIT_RETRIES:-5}

for (( i = 0; i < tries; ++i )); do
  $trace git "$@" && break
done
