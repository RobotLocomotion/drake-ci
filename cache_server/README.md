# Drake CI Cache Server Infrastructure

> :warning: :construction: **Under Construction** :construction: :warning:
>
> This document is a work in progress, consolidation of the build cache servers
> is ongoing and more information will be added to this document as this effort
> is concluded.

## Available Cache Servers

- mac-arm64
    - Hosted on-site at MacStadium.  Requires TRI VPN to access.
    - Currently: 500GB, anticipated: 1TB storage total.
    - IP address: `10.221.188.4`
    - Username: `administrator`
    - Password: see ip plan.
- TODO: mac-x86
    - Hosted on-site at MacStadium.  Planned to be decommisioned / swapped out.
- TODO: linux
    - Hosted on AWS.
    - Infrastructure update required.

## Cache Server Overview

Each cache server is running an `nginx` server as the backend.  For more
information on the cache server choice, see [drake issue 18286][drake_18286].
Each different build flavor for the server is "salted" to avoid issues with
`bazel` "over-caching" results, and when using the `nginx` server this amounts
to simply setting the `bazel` cache server entries to different subdirectories.

1. A consuming build will configure [`remote.bazelrc.in`][remote_bazelrc]:

   i. If this build is populating the cache (`nightly`, `continuous`) or reading
      from the cache (`experimental`).  Some special jobs (e.g., packaging) do
      not use the cache at all.  Jobs setting `--remote_accept_cache` to `yes`
      can read from the cache, jobs setting `--remote_upload_local_results` to
      `yes` populate the cache.  Experimental jobs should never populate the
      cache as these are typically going to be pull request builds, which will
      start creating conflicts.
   ii. The salt for the build, computed in [`cache.cmake`][cache_cmake], which
       determines the final server url for the `--remote_cache={url}` flag.
       When using `nginx` as the server backend, suppose the server is running
       at ip address `x.y.z`.  The computation in [`cache.cmake`][cache_cmake]
       will result in setting `--remote_cache=x.y.z/{version}/{salt}`.

2. The cache server must **always** support being able to `GET /`, the
   [`cache.cmake`][cache_cmake] performs this step at the beginning to confirm
   the remote cache can be communicated with -- if `GET /` fails, the remote
   cache is disabled.

3. Each server should have three `cron` jobs running to cleanup old files
   using [`cleanup_old_files.py`](cleanup_old_files.py), monitor the disk usage
   using [`disk_usage_alert.py`](disk_usage_alert.py), and rotate the logs
   (using `logrotate`).


[drake_18286]: https://github.com/RobotLocomotion/drake/issues/18286
[remote_bazelrc]: https://github.com/RobotLocomotion/drake-ci/blob/main/tools/remote.bazelrc.in
[cache_cmake]: https://github.com/RobotLocomotion/drake-ci/blob/main/driver/configurations/cache.cmake

## Configuring a Cache Server

By convention, our caches are mounted at `/cache/toyotacache` and the helper
scripts are placed in `/cache` directly.  Keeping a clone of `drake-ci` runs the
risk of accidentally overwriting cache-server specific data such as which device
the storage is mounted to or how often cleanup should happen.

1. Install and configure `nginx` as a systemd service, updating the contents of
   `/etc/nginx/nginx.conf` with [our `nginx.conf`](nginx.conf).  **Important**:

   - Confirm your service is configured to start on boot, so that if the machine
     is rebooted for any reason the `nginx` service will revive.
     `sudo systemctl enable nginx` should achieve this.
   - You can confirm your server is running by `curl localhost:6060` on the
     machine, noting that the port is defined by [`nginx.conf`](nginx.conf).

2. Install required software and configure root user.

    - `apt-get install [ final package list ]`
    - Add `export EDITOR=vim` to the `root` account's `~/.bashrc`.  Otherwise
      when running `crontab -e` later it may choose nonsense such as `nano`.

3. Make the logging directory: `sudo mkdir /cache/logs`.  This is where we will
   be storing logging information about disk usage alerts as well as file
   cleanup.

4. Clone `drake-ci` to `/cache/drake-ci`.  Do be careful that when editing files
   on a given cache server you are conscious of the fact that these files are
   live and a cron job may run.  After a given PR merges, login to each server
   and `git pull` and checkout `main`.

5. Become the `root` user, and execute `crontab -e`.  Your final crontab entries
   for the root user should be:

   ```bash
   # This cache server's date / time are in UTC!  Conversion:
   # EST: +5 hours to get to UTC
   # EDT: +4 hours to get to UTC
   # Cache cleanup: run ~10pm eastern (before nightlies).
   0 3     * * *   /cache/drake-ci/cache_server/cleanup_old_files.py -s --days 3 /cache/toyotacache >>/cache/logs/cleanup_old_files.log 2>&1
   #
   # Cache (over)utilization alerting: run ~7am eastern.
   0 12    * * *   /cache/drake-ci/cache_server/disk_usage_alert.py /cache/toyotacache >>/cache/logs/disk_usage_alert.log 2>&1
   #
   # Rotate cache logs.  Note that the verbose output of logrotate goes to the
   # provided logfile, but it always overwrites.  We do not want it rotating
   # itself, so it goes to /cache/logrotate.log (not /cache/logs/logrotate.log).
   # Run this daily after the other jobs are anticipated to finish: ~10am eastern.
   0 15    * * *   /usr/sbin/logrotate --verbose --log /cache/logrotate.log /cache/drake-ci/cache_server/logrotate_cache.conf >/dev/null 2>&1
   ```

   You should be able to save and `cat /var/spool/cron/crontabs/root` to confirm.

6. Make sure that the new server will have its initial `DASHBOARD_REMOTE_CACHE`
   value set at the top of [`cache.cmake`][cache_cmake], doing so in a pull
   request against drake-ci.  You can test a populate / read job by temporarily
   changing [`remote.bazelrc.in`][remote_bazelrc] to have hard-coded values.
   To populate the cache:

   ```diff
   - build --remote_accept_cached=@DASHBOARD_REMOTE_ACCEPT_CACHED@
   + build --remote_accept_cached=no
   - build --remote_upload_local_results=@DASHBOARD_REMOTE_UPLOAD_LOCAL_RESULTS@
   + build --remote_upload_local_results=yes
   ```

   To read from the cache:

   ```diff
   - build --remote_accept_cached=@DASHBOARD_REMOTE_ACCEPT_CACHED@
   + build --remote_accept_cached=yes
   - build --remote_upload_local_results=@DASHBOARD_REMOTE_UPLOAD_LOCAL_RESULTS@
   + build --remote_upload_local_results=no
   ```

   After testing the populate / read jobs work as desired, manually delete the
   cache so that it starts clean when nightly / continuous begin running.

7. Give better docs on how to add a dummy commit to test an experimental job
   for (a) populating the cache and (b) reading from the cache.  Note that best
   course of action is to observer `tail -f /var/log/nginx/access.log` and
   `tail -f /var/log/nginx/error.log` while this test job is running.

[aws_secrets]: https://us-east-1.console.aws.amazon.com/secretsmanager/listsecrets?region=us-east-1
