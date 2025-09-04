# Drake CI Cache Server Infrastructure

- [Cache Server Overview](#cache-server-overview)
- [Configuring a New Cache Server](#configuring-a-new-cache-server)
- [Cache Server Automated Monitoring](#cache-server-automated-monitoring)
- [Manually Cleaning the Cache](#manually-cleaning-the-cache)

## Cache Server Overview

For instructions on logging into or creating a new cache server, see the drake
continuous integration details document. The current cache server used by Linux
and macOS jobs is hosted on AWS with a 2TB TBS volume, and requires Kitware or
TRI VPN to access.

The cache server is running an `nginx` server as the backend.  For more
information on the cache server choice, see [drake issue 18286][drake_18286].
Each different build flavor for the server is "salted" to avoid issues with
`bazel` "over-caching" results, and when using the `nginx` server this amounts
to simply setting the `bazel` cache server entries to different subdirectories.

1. A cached build will configure [`remote.bazelrc.in`][remote_bazelrc]:

    - If this build is populating the cache (`nightly`, `continuous`) or reading
      from the cache (`experimental`).  Some special jobs (e.g., packaging) do
      not use the cache at all.  Jobs setting `--remote_accept_cache` to `yes`
      can read from the cache, jobs setting `--remote_upload_local_results` to
      `yes` populate the cache.  Experimental jobs should never populate the
      cache as these are typically going to be pull request builds, which will
      start creating conflicts.
    - The salt for the build, computed in [`cache.cmake`][cache_cmake], which
      determines the final server url for the `--remote_cache=${url}` flag.
      When using `nginx` as the server backend, suppose the server is running
      at ip address `x.y.z`.  The computation in [`cache.cmake`][cache_cmake]
      will result in setting `--remote_cache=x.y.z/${version}/${salt}`.

2. The cache server must **always** support being able to `GET /`. If `GET /`
   fails for any reason, CI jobs will fail so that buildcops are notified and
   the issue can be resolved. In the `nginx` configuration, we solve this by
   setting `autoindex on;` which allows us to query directory contents
   (including viewing `/`).

3. Each server should have three `cron` jobs running to remove old files
   using [`remove_old_files.py`](./remove_old_files.py), monitor the disk
   usage using [`disk_usage.py`](./disk_usage.py), and rotate the logs
   (using `logrotate`).

4. Each server is checked by a daily automated jenkins production job (that
   emails buildcops upon failure).  This `cache-server-health-check` job will
   first verify that each cache server is reachable, then log in and verify that
   the server has enough disk space remaining for additional cache uploads from
   nightly / continuous.

[drake_18286]: https://github.com/RobotLocomotion/drake/issues/18286
[remote_bazelrc]: ../tools/remote.bazelrc.in
[cache_cmake]: ../driver/configurations/cache.cmake

## Configuring a New Cache Server

By convention:

- Cache data storage volumes are mounted to `/cache`.
- This repository should be cloned to `/opt/cache_server/drake-ci`.  Do not put
  it on the same volume as the cache data storage.  If monitoring or file
  removal are not working correctly, you will not be able to develop in
  production (e.g., cannot `git pull` new files) or get new logging information.
    - **NOTE**: this directory path is also used by
      [`health_check.bash`](./health_check.bash).
- The logs for `nginx`, file removal, and disk monitoring are are stored in
  `/opt/cache_server/log`.
- The build cache is written to `/cache/data`.  The [`cache.cmake`][cache_cmake]
  configuration sets as an example `DASHBOARD_REMOTE_CACHE_KEY_VERSION=v7`, so
  the action cache (ac) and content addressed storage (cas) will be stored at
  `/cache/data/v7/${salt}/ac` and `/cache/data/v7/${salt}/cas` (see
  [Cache Server Overview](#cache-server-overview) for description of "salt").
    - If the cache needs to get purged, incrementing the cache key version is
      the easiest way to do so.

All of the configuration options should be executed as `root`.

1. Become the `root` user: `sudo -i -u root`

2. When you first image a new cache server, make sure to fully upgrade it:

    ```console
    apt-get update && apt-get upgrade
    ```

    Pay attention to the output, if the kernel upgrades, make sure to `reboot`
    it and prune the old kernels.  See the "Biannual Linux Kernel/Security
    Update" section of the drake-ci document for more information.

3. Make the directory structure we need with ownership that `nginx` will be able
   to work with:

    ```console
    (
        mkdir -p \
            /cache/data \
            /opt/cache_server \
            /opt/cache_server/log/nginx;
        chown -R www-data:www-data /cache/data /opt/cache_server/log/nginx;
    )
    ```

4. Install the packages we need (and desire):

    ```console
    apt-get install -y \
        git \
        python3-venv \
        nginx \
        nginx-extras \
        ncdu \
        tmux \
        tree \
        vim
    ```

5. Set the timezone to New York rather than UTC using
   `timedatectl set-timezone America/New_York`.  The timezone of the server is
   relevant for the `cron` entries that follow!

6. Add the line `export EDITOR=vim` to the top of `/root/.bashrc`.  This way
   when we run `crontab -e` later on, it will use `vim` rather than `nano`.

7. Log out of `root` (`ctrl+d`) and log back in (`sudo -i -u root`) and confirm
   `echo $EDITOR` prints `vim`.

8. Clone this repository to `/opt/cache_server/drake-ci`:

    ```console
    (
        cd /opt/cache_server && \
        git clone https://github.com/RobotLocomotion/drake-ci.git
    )
    ```

    Be aware that changing branches or making local edits to files on a cache
    server under `/opt/cache_server/drake-ci` affects a production system.  The
    file removal routines under `cron` as well as Jenkins monitoring scripts may
    behave unexpectedly depending on what local changes are made.

    Also be aware that changes to the `nginx` configuration (e.g., via
    `git pull`) do **not** go live.  The newly updated configuration should be
    validated by `nginx -t` and then the service must be restarted via
    `systemctl restart nginx`.

9. Link our server configuration to `/etc/nginx/conf.d` (which is included by
   `/etc/nginx/nginx.conf`):

    ```console
    ln -s \
        /opt/cache_server/drake-ci/cache_server/drake_cache_server_nginx.conf \
        /etc/nginx/conf.d/
    ```

10. Remove the default server (which also uses port 80):
    `rm /etc/nginx/sites-enabled/default`.

11. Now that our server configurations are in place, verify that `nginx` is
    happy with `nginx -t`:

    ```console
    $ nginx -t
    nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
    nginx: configuration file /etc/nginx/nginx.conf test is successful
    ```

12. Restart `nginx`, and make sure it is configured to start on boot:

    ```console
    $ systemctl restart nginx
    $ systemctl enable nginx
    $ systemctl status nginx
    ● nginx.service - A high performance web server and a reverse proxy server
         Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
         Active: active (running) since Fri YYYY-MM-DD HH:MM:SS UTC; X days ago
           Docs: man:nginx(8)
        Process: 11870 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
        Process: 11871 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
       Main PID: 11872 (nginx)
          Tasks: 133 (limit: 19065)
         Memory: 14.3G
            CPU: 1h 25min 37.252s
         CGroup: /system.slice/nginx.service
                 ├─11872 "nginx: master process /usr/sbin/nginx -g daemon on; master_process on;"
                 ├─11873 "nginx: worker process" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" ""
                 ├─11874 "nginx: worker process" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" ""
                 ├─11875 "nginx: worker process" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" ""
                 └─11884 "nginx: worker process" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" ""

    Apr 07 16:53:18 tytrsr-ubuntu-01 systemd[1]: Starting A high performance web server and a reverse proxy server...
    Apr 07 16:53:18 tytrsr-ubuntu-01 systemd[1]: Started A high performance web server and a reverse proxy server.
    ```

13. Confirm that `echo $USER` reveals you are `root`, and then execute
    `crontab -e`.  Your final crontab entries for the `root` user should be:

    ```bash
    # Important:  Scripts use this environment variable to detect if they are
    # running under cron or not.
    DRAKE_CRON_JOB=1
    #
    # This cache server's date / time are in America/New_York!
    # Cache pruning (https://crontab.guru/#*/15_*_*_*_*): every 15th minute.
    */15 * * * *   /opt/cache_server/drake-ci/cache_server/remove_old_files.py auto /cache/data >>/opt/cache_server/log/remove_old_files.log 2>&1
    #
    # Disk usage monitoring: on minute 40 (the file removal above runs on minute
    # 30, allow it to complete before checking).  Note that there is a continuous
    # cache server health check job that runs on a completely unrelated
    # schedule.  This log primarily exists as a backup for us to consult if we
    # desire to monitor how much is deleted when.
    40 * * * *   /opt/cache_server/drake-ci/cache_server/disk_usage.py /cache/data >>/opt/cache_server/log/disk_usage_cache_data.log 2>&1
    #
    # Additionally monitor disk usage of the root volume.  This is where the
    # logging data is stored.
    40 * * * *   /opt/cache_server/drake-ci/cache_server/disk_usage.py / -t 80 >>/opt/cache_server/log/disk_usage_root.log 2>&1
    #
    # Rotate cache logs.  See the script for more information, this must be run
    # frequently since the nginx access.log can grow quite quickly.  Run it when
    # the other two jobs above are unlikely to also be running (and logging).
    5-59/10 * * * *   /opt/cache_server/drake-ci/cache_server/rotate_logs.py >>/opt/cache_server/log/rotate_logs.log 2>&1
    ```

    You should be able to save and `cat /var/spool/cron/crontabs/root` to
    confirm.

    **Note**: if updating the `remove_old_files.py` cron job interval, please
    also update the verbiage in `disk_usage.py` to match the new schedule.

14. Add the new cache server to `drake-ci` in a pull request that sets the
    appropriate `DASHBOARD_REMOTE_CACHE` value set at the top of
    [`cache.cmake`][cache_cmake].  To test the server (before merging the PR
    adding it), we will need to add two dummy commits to launch test jobs
    against: a "cache populate job" and a "cache read job".  For each of these
    jobs, add a commit that modifies [`remote.bazelrc.in`][remote_bazelrc] to
    have hard-coded values (these commits will need to be force pushed away
    before the final merge).

    When a given test job (populate or read) is getting launched, you should
    have a terminal open and logged into the cache server in question.  Launch
    your experimental jenkins job parameterized with the appropriate `drake-ci`
    PR, and in the terminal on the cache server observe
    `tail -f /opt/cache_server/log/nginx/access.log`.

    Typically, the right job to select would be
    "default compiler, bazel, release", e.g.,
    `linux-${codename}-gcc-bazel-experimental-release`.  If choosing a
    different job to test with, make sure that previous build logs reveal that
    job is actually cached!

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

15. After testing that the populate / read jobs work as desired, manually delete
    the cache so that it starts clean when nightly / continuous begin running:
    `rm -rf /cache/data/*`

16. Consult the drake continuous integration details document for the final
    steps needed to set up the cache server (copy over authentication
    credentials to enable the jenkins cache server monitoring jobs).

## Cache Server Automated Monitoring

In addition to routine logging via `cron`, it is helpful to know that the cache
server has enough space via some form of direct notification.  When a cache
server is out of disk space, builds will continue on Jenkins without failing and
can go unnoticed.  The build log for jobs that populate the cache (nightly,
continuous) will be littered with HTTP "500 Internal Server Error"s.  `bazel`
tried to do an HTTP `PUT`, but the server did not have the ability to store it.
While the `bazel build` will continue without error, this means that our cache
is getting out of sync and pruning should happen quickly.  After pruning, it may
be worth checking the logs in `/opt/cache_server/log/` for more data on when the cache
server disk utilization started growing too quickly.  Perhaps the nightly
pruning routine should be more aggressive.

The easiest way to achieve email notifications about this is to have production
jobs on Jenkins that run [`health_check.bash`](./health_check.bash) for a given
cache server.  The health check first checks that we can perform an HTTP `GET`
at `/` on the public ip address that `bazel build` uses (the same values as
`DASHBOARD_REMOTE_CACHE` in [`cache.cmake`][cache_cmake]).  Then it logs into
the server and runs [`disk_usage.py`](./disk_usage.py) to make sure there is
enough space available to upload new cache entries.  If either one of these
fails, buildcops will receive an email via Jenkins.

## Manually Cleaning the Cache

In the event that the `cron` job running
[`remove_old_files.py`](./remove_old_files.py) is not removing enough disk
space, the monitoring jobs in the previous section will start notifying the
buildcops.  You must log in to the cache server and run the script manually
with new arguments for the window of time to consider.

Connect to the Kitware VPN and `ssh` into the `drake-webdav` EC2 instance
(right click => connect). Once on the server, become the `root` user
(`sudo -iu root`) and run a handful of different time windows using the `-n`
(dry run) flag:

```console
/opt/cache_server/drake-ci/cache_server/remove_old_files.py -n auto -t 60 /cache/data/
```

Or manually search yourself:

```
$ /opt/cache_server/drake-ci/cache_server/remove_old_files.py -n manual --days 2 /cache/data/
$ /opt/cache_server/drake-ci/cache_server/remove_old_files.py -n manual --days 1 /cache/data/
$ /opt/cache_server/drake-ci/cache_server/remove_old_files.py -n manual --days 1 --hours 12 /cache/data/
```

While the data on the cache server itself is fairly easy to replace (it is never
worth making a backup of this data), **be extremely conscious of what you are
doing**.  If you delete the entire cache during the day, **all pull request
builds will become over 10x slower** and will not speed up until continuous
and/or nightly start repopulating the cache.

Depending on your findings, likely you will want to choose one or more of:

- Update the time interval for the `cron` job running
  [`remove_old_files.py`](./remove_old_files.py).
- Change the disk percent usage threshold in the `cron` job.
- Increase the storage attached to the cache server.
- Reduce the number of jenkins jobs that add to the cache server.

## Debugging Cache Cleaning

File removal with [`remove_old_files.py`](./remove_old_files.py) has a
`-v` (verbose) flag to log additional information on the files being removed.
Only use this as necessary --- especially if updating the `cron` job --- as
it will increase the size of the log file and slows down the removal process
proportional to how many files are being removed.
You may need to modify [`logrotate_cache.conf`](./logrotate_cache.conf) if the
`remove_old_files.log` is becoming too large.
