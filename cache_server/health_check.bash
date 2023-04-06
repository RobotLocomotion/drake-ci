#!/bin/bash

set -exo pipefail

# On m1 mac, detect if we can re-run the script under arm64, since Jenkins'
# login initially runs in an emulated x86_64 (Rosetta 2) environment.
if [[ "$(uname -s)" == Darwin && "$(uname -p)" != "arm" ]]; then
    if arch -arch arm64 true &>/dev/null; then
        exec arch -arch arm64 "$0" "$@"
    fi
fi

export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"

# TODO(svenevs): this will get added to jenkins credentials instead and we are
# expected to be able to login to the cache server directly from there.
aws s3 cp \
  s3://drake-provisioning/cache_server/cache_server_id_rsa \
  ./cache_server_id_rsa
chmod 0600 cache_server_id_rsa
eval "$(ssh-agent -s)"
ssh-add cache_server_id_rsa

# Define cache server url and port.  The port is only needed for trying to
# perform a GET /, for logging in we just need the ip.
case "$(uname -s)" in
    Darwin)
        brew install coreutils  # for timeout command
        readonly cache_server_url="10.221.188.9"
        readonly cache_server_port=":6060"
        ;;

    Linux)
        # TODO(svenevs): linux unhandled, new IP inbound, firewall involved.
        # Login procedure may need to change.
        readonly cache_server_url="172.31.20.109"
        readonly cache_server_port=""
        ;;

    *)
        echo "Uknown operating system: $(uname -s)" >&2
        exit 1
        ;;
esac

# Basic healthcheck: can we contact the server?
curl --fail \
    --connect-timeout 10 \
    -X GET \
    "${cache_server_url}${cache_server_port}/"

# This file should already live on the cache server in this exact location.
# If anything goes wrong (script not there, ssh hangs) the below command will
# produce a nonzero exit code.
#
# Requires being root, yes.  Using -o StrictHostKeyChecking=no tells ssh to
# accept new finger prints (~/.ssh/known_hosts does not know the cache server).
timeout 30 \
    ssh \
    -o StrictHostKeyChecking=no\
    "root@${cache_server_url}" \
    '/cache/disk_usage_alert.py /cache/toyotacache -t 1'
