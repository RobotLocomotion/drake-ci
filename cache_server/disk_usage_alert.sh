#!/bin/bash
#
# Gather usage statistics on the cache server volume utilization, email
# developers when the cache server utilization is too high.  This script should
# be run via /etc/crontab daily, as `root`.  /etc/ssmtp/ssmtp.conf must already
# be configured, see the README for more:
# https://github.com/RobotLocomotion/drake-ci/tree/main/cache_server
#
# Different cache servers will have this mounted at different locations, update
# both of these variables when configuring a new deployment.
cache_mount_point="/dev/sdb1"
cache_server_name="Drake Mac arm64 Cache Server"

# Example output:
#
#   df -h /dev/sdb1
#   Filesystem      Size  Used Avail Use% Mounted on
#   /dev/sdb1       492G  269G  198G  58% /cache
#
# So we will use the Use% column by taking the last line, and the fifth column,
# and remove the % sign.  Store separately so that the results can be used in
# the notification email.
df_query="$(df -h "${cache_mount_point}")"
percent_used="$(echo "${df_query}" | tail -1 | awk '{ print $5 }' | tr -d '%')"

# Logs for crontab show up in /var/log/syslog, dump some information to indicate
# status for reviewers.
echo "Disk utilization of '${cache_mount_point}' is at ${percent_used}%:"
echo "${df_query}"

# If utilization is above 85% then send a notification email.
if [[ "${percent_used}" -gt 85 ]]; then
    tmp_file="$(mktemp)"
    # So emails always start a new thread, include day/month/year hour:minute.
    time_stamp="$(date -u '+%F %R UTC')"
    # NOTE: don't word-wrap sentences, it looks weird in the email.
    echo "Subject: Cache Overutilized ${time_stamp}

The ${cache_server_name} disk usage is too high, manual cleanup may be required.

The cache is mounted at ${cache_mount_point}, the results of df -h \"${cache_mount_point}\":

${df_query}

The cache utilization is at ${percent_used}%!

Please start a thread in the #buildcop slack channel https://drakedevelopers.slack.com/archives/C270MN28G delegating to Kitware, or follow the instructions at https://github.com/RobotLocomotion/drake-ci/tree/main/cache_server to cleanup manually." > "${tmp_file}"
    ssmtp \
        -F "${cache_server_name}" \
        "drake-alerts+jenkins@tri.global" \
        "drake-developers+build-cop@kitware.com" \
        < "${tmp_file}"
    rm -f "${tmp_file}"
fi

