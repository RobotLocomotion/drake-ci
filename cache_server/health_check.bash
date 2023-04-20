#!/bin/bash

# shellcheck disable=SC2016
doc='This script is expected to be launched by a production jenkins job so that
buildcops will receive failure notifications.  It runs on the distribution
associated with the cache server being checked (an AWS linux instance to check
the AWS cache server, a macos-arm64 instance to check the macOS cache server).

Arguments:
    server_name:
        The name of the server to health check.  Must be `linux` or `mac-arm64`.
        Internally the script will determine the server_ip based on the provided
        name.

The script performs in order:

1. Verify that the server is running via an HTTP GET ${server_ip}/.  This
   will confirm that the nginx server is running (or fail if not).
2. Download the cache server ssh key from S3.
3. Login to the server at ${server_ip} and run disk_usage.py to monitor free
   space.

To develop locally, you will need to have the AWS CLI configured to be able to
`aws s3 cp ...` (make sure `~/.aws` is configured for drake).  To test:

- The mac-arm64 cache server: connect to the TRI VPN.  You can run this test
  from a linux machine.
- The linux cache server: you must spin up a test instance on EC2 with the
  groups `default`, `ping`, `ssh`, and `node` as well as set the IAM role to
  `aws-ec2-role-for-s3`.'

function usage() {
    echo -e "Usage:\n    $0 <server_name>\n\n${doc}" >&2
    exit 1
}

# Determine cache server ip address to health check based off provided name.
# This is setup this way so that we do not have to edit the drake-jenkins-jobs
# yaml in addition to drake-ci whenever a cache server ip address changes.
# Instead, we hard-code the values here and in driver/configurations/cache.cmake
# in order to be able to update them once.  Co-modifying drake-ci and
# drake-jenkins-jobs is an unnecessary maintenance burden.
[[ $# != 1 ]] && usage
[[ "$1" =~ ^(linux|mac-arm64)$ ]] || usage
readonly server_name="$1"
if [[ "${server_name}" == "linux" ]]; then
    readonly server_ip="172.31.19.73"
elif [[ "${server_name}" == "mac-arm64" ]]; then
    readonly server_ip="10.221.188.9"
else
    echo "INTERNAL ERROR: unexpected server_name=${server_name}." >&2
    exit 1
fi

# On m1 mac, detect if we can re-run the script under arm64, since Jenkins'
# login initially runs in an emulated x86_64 (Rosetta 2) environment.
if [[ "$(uname -s)" == Darwin && "$(uname -p)" != "arm" ]]; then
    if arch -arch arm64 true &>/dev/null; then
        exec arch -arch arm64 "$0" "$@"
    fi
    export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"
    # For `timeout` and `aws` commands.
    HOMEBREW_NO_AUTO_UPDATE=1 brew install coreutils awscli
fi

set -exo pipefail

# Basic healthcheck: can we contact the server?
curl --fail \
    --connect-timeout 10 \
    -X GET \
    "${server_ip}/"

# Download the cache server ssh key.
this_file_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cache_server_id_rsa_path="${this_file_dir}/cache_server_id_rsa"
aws s3 cp \
  s3://drake-provisioning/cache_server/cache_server_id_rsa \
  "${cache_server_id_rsa_path}"

# Remove downloaded files on exit (success *and* failure).
# shellcheck disable=SC2064
trap "rm -f \"${cache_server_id_rsa_path}\"" EXIT

# Make the downloaded ssh key usable.
chmod 0600 "${cache_server_id_rsa_path}"
eval "$(ssh-agent -s)"

# This file should already live on the cache server in this exact location.
# If anything goes wrong (script not there, ssh hangs), the below command will
# produce a nonzero exit code.
#
# The disk_usage.py script must be run as `root` to access `/cache/data`.  Using
# `-o StrictHostKeyChecking=no` tells ssh to accept new fingerprints
# (~/.ssh/known_hosts does not know the cache server when this runs in CI).
timeout 120 \
    ssh \
        -o IdentitiesOnly=yes \
        -o StrictHostKeyChecking=no \
        -i "${cache_server_id_rsa_path}" \
        "root@${server_ip}" \
        '/cache/drake-ci/cache_server/disk_usage.py /cache/data'
