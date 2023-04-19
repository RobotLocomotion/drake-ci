#!/bin/bash

# shellcheck disable=SC2016
doc='This script is expected to be run on an AWS linux instance, launched by a
production jenkins job so that buildcops will receive failure notifications.

Arguments:
  $1: The server ip address of the cache server to health check.  This should
      be the same as the value of `DASHBOARD_REMOTE_CACHE` in
      driver/configurations/cache.cmake.

  $2: The login uri of the cache server.  For the MacStadium server it should be
      the same as $1.  For the linux cache server on AWS, there is a different
      ip address (view the instance on AWS EC2 to see).

The script performs in order:

1. Verify that the server is running via an HTTP GET $1/.  This public ip
   address is what bazel will try to connect to.
2. Download the cache server ssh key from S3.
3. Login to the server $2 and run disk_usage_alert.py to monitor free space.

To develop locally, you will need to have the AWS CLI configured to be able to
`aws s3 cp ...` (make sure `~/.aws` is configured for drake).  To test:

- The mac-arm64 cache server: connect to the TRI VPN.
- The linux cache server: you need to get behind the firewall either by
  connecting to a new AWS EC2 instance, or via pull requests.  You can connect
  to the Kitware VPN to check $2, but the ip address used in $1 is not reachable
  outside of EC2 (you can comment out the call to `curl ... GET /` to just check
  the status of the linux cache server storage from the Kitware VPN).'

function usage() {
    echo -e "Usage:\n    $0 <server_uri> <login_uri>\n\n${doc}" >&2
    exit 1
}

# NOTE: we rely on core utilities such as `timeout` that are not in the  macos
# images.  The script also needs to be `exec arch -arch arm64`'ed as done in
# `ctest_driver_script_wrapper.bash`.  Since the linux runners are faster to
# boot and connect to, we do not want to run this on macOS CI.
[[ "$(uname -s)" != "Linux" ]] && usage
[[ $# != 2 ]] && usage

readonly public_ip="$1"
readonly private_ip="$2"

set -exo pipefail

# Basic healthcheck: can we contact the server?
curl --fail \
    --connect-timeout 10 \
    -X GET \
    "${public_ip}/"

# Download the cache server ssh key and make it usable.
this_file_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cache_server_id_rsa_path="${this_file_dir}/cache_server_id_rsa"
aws s3 cp \
  s3://drake-provisioning/cache_server/cache_server_id_rsa \
  "${cache_server_id_rsa_path}"
chmod 0600 "${cache_server_id_rsa_path}"
eval "$(ssh-agent -s)"

# This file should already live on the cache server in this exact location.
# If anything goes wrong (script not there, ssh hangs) the below command will
# produce a nonzero exit code.
#
# Requires being root, yes.  Using -o StrictHostKeyChecking=no tells ssh to
# accept new finger prints (~/.ssh/known_hosts does not know the cache server
# when this runs in CI).
timeout 120 \
    ssh \
        -v \
        -i "${cache_server_id_rsa_path}" \
        -o StrictHostKeyChecking=no\
        "root@${private_ip}" \
        '/cache/drake-ci/cache_server/disk_usage.py /cache/data'

# Remove downloaded files.
rm -f "${cache_server_id_rsa_path}"
