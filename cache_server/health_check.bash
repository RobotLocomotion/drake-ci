#!/bin/bash

# shellcheck disable=SC2016
doc='This script is expected to be launched by a production jenkins job so that
buildcops will receive failure notifications.

The script performs, in order:

1. Verify that the server is running via an HTTP GET ${server_ip}/.  This
   will confirm that the nginx server is running (or fail if not).
2. Download the cache server ssh key from S3.
3. Log in to the server at ${server_ip} and run disk_usage.py to monitor free
   space.

To develop locally, you will need to have the AWS CLI configured to be able to
`aws s3 cp ...` (make sure `~/.aws` is configured for drake).  To test, you
must spin up a test instance on EC2 with the groups `default`, `ping`, `ssh`,
and `node` as well as set the IAM role to `aws-ec2-role-for-s3`.'

readonly server_ip="172.31.18.175"

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
# Check disk usage for `/cache/`, which stores data in `data/` and logs in `logs/`.
timeout 120 \
    ssh \
        -o IdentitiesOnly=yes \
        -o StrictHostKeyChecking=no \
        -i "${cache_server_id_rsa_path}" \
        "root@${server_ip}" \
        '/opt/cache_server/drake-ci/cache_server/disk_usage.py /cache/'
# Also check disk usage for `/`. Theoretically, nothing is stored here besides
# the drake-ci clone, but it's a very small disk, and it holds the root
# filesystem, so if anything is unexpected we should know immediately.
timeout 120 \
    ssh \
        -o IdentitiesOnly=yes \
        -o StrictHostKeyChecking=no \
        -i "${cache_server_id_rsa_path}" \
        "root@${server_ip}" \
        '/opt/cache_server/drake-ci/cache_server/disk_usage.py / -t 80'
