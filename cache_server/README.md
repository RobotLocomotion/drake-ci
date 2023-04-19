# Drake CI Cache Server Infrastructure

- [Available Cache Servers](#available-cache-servers)
- [Cache Server Overview](#cache-server-overview)
- [Configuring a New Cache Server](#configuring-a-new-cache-server)
- [Cache Server Automated Monitoring](#cache-server-automated-monitoring)

## Available Cache Servers

For instructions on logging into or creating a new cache server, see the drake
continuous integration details document.

- mac-arm64:
    - Hosted on-site at MacStadium.  Requires TRI VPN to access.
    - 1TB SAN storage.
    - IP address: `10.221.188.9`
- linux:
    - Hosted on AWS.  Requires Kitware VPN to access.
    - 1TB EBS volume.
    - IP address: `172.31.20.109`

## Cache Server Overview

Each cache server is running an `nginx` server as the backend.  For more
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

2. The cache server must **always** support being able to `GET /`, the
   [`cache.cmake`][cache_cmake] performs this step at the beginning to confirm
   the remote cache can be communicated with.  The remote cache is disabled if
   `GET /` fails for any reason.  In the `nginx` configuration, we solve this by
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
- This repository should be cloned to `/cache/drake-ci`.
- The logs are stored in `/cache/log/nginx/{access,error}.log`.
- The build cache is written to `/cache/data`.  The [`cache.cmake`][cache_cmake]
  configuration sets as an example `DASHBOARD_REMOTE_CACHE_KEY_VERSION=v2`, so
  the action cache (ac) and content addressed storage (cas) will be stored at
  `/cache/data/v2/ac` and `/cache/data/cas`.
    - If the cache needs to get purged, incrementing the cache key version is
      the easiest way to do so.

All of the configuration options should be executed as `root`.

1. Become the `root` user: `sudo -i -u root`

2. Make the directory structure we need with ownership that `nginx` will be able
   to work with:

    ```console
    mkdir -p /cache/data /cache/log/nginx
    chown -R www-data:www-data /cache/data /cache/log/nginx
    ```

3. Install the packages we need (and desire):

    ```console
    $ apt-get install -y \
        git \
        nginx \
        nginx-extras \
        ncdu \
        tree \
        vim
    ```

4. Set the timezone to New York rather than UTC using
   `timedatectl set-timezone America/New_York`.  The timezone of the server is
   relevant for the `cron` entries that follow!

5. Add the line `export EDITOR=vim` to the top of `/root/.bashrc`.  This way
   when we run `crontab -e` later on, it will use `vim` rather than `nano`.

6. Log out of `root` (`ctrl+d`) and log back in (`sudo -i -u root`) and confirm
   `echo $EDITOR` prints `vim`.

7. Clone this repository to `/cache/drake-ci`:

    ```console
    $ (cd /cache && git clone https://github.com/RobotLocomotion/drake-ci.git)
    ```

    Be aware that changing branches or making local edits to files on a cache
    server under `/cache/drake-ci` affects a production system.  The pruning
    routines under `cron` as well as monitoring scripts may behave unexpectedly
    depending on what local changes are made.

    Also be aware that changes to the `nginx` configuration (e.g., via
    `git pull`) do **not** go live.  The newly updated configuration should be
    validated by `nginx -t` and then the service must be restarted via
    `systemctl restart nginx`.

7. Link our server configuration to `/etc/nginx/conf.d` (which is included by
   `/etc/nginx/nginx.conf`):

    ```console
    $ ln -s \
        /cache/drake-ci/cache_server/drake_cache_server_nginx.conf \
        /etc/nginx/conf.d/
    ```

8. Remove the default server (which also uses port 80):
   `rm /etc/nginx/sites-enabled/default`.

9. Now that our server configurations are in place, verify that `nginx` is happy
   with `nginx -t`:

    ```console
    $ nginx -t
    nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
    nginx: configuration file /etc/nginx/nginx.conf test is successful
    ```
10. Restart `nginx`, and make sure it is configured to start on boot:

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

11. Confirm that `echo $USER` reveals you are `root`, and then execute
    `crontab -e`.  Your final crontab entries for the `root` user should be:

    ```bash
    # This cache server's date / time are in America/New_York!
    # Cache pruning: run 10pm eastern (before nightlies).
    0 22 * * *   /cache/drake-ci/cache_server/remove_old_files.py -s --days 3 /cache/data >>/cache/log/remove_old_files.log 2>&1
    #
    # Disk usage monitoring: run 7am eastern.
    0 7  * * *   /cache/drake-ci/cache_server/disk_usage.py /cache/data >>/cache/log/disk_usage.log 2>&1
    #
    # Rotate cache logs.  Note that the verbose output of logrotate goes to the
    # provided logfile, but it always overwrites.  We do not want it rotating
    # itself, so it goes to /cache/logrotate.log (not /cache/log/logrotate.log).
    # Run this daily after the other jobs are anticipated to finish: 10am eastern.
    0 10 * * *   /usr/sbin/logrotate --verbose --log /cache/logrotate.log /cache/drake-ci/cache_server/logrotate_cache.conf >/dev/null 2>&1
    ```

    You should be able to save and `cat /var/spool/cron/crontabs/root` to
    confirm.

12. Add the new cache server to `drake-ci` in a pull request that sets the
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
    `tail -f /cache/log/nginx/access.log`.

    Typically, the right job to select would be
    "default compiler, bazel, release", e.g.,
    `linux-${codename}-gcc-bazel-experimental-release` or
    `mac-arm-${codename}-clang-bazel-experimental-release`.  If choosing a
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

13. After testing that the populate / read jobs work as desired, manually delete
    the cache so that it starts clean when nightly / continuous begin running:
    `rm -rf /cache/data/*`

14. Consult the drake continuous integration details document for the final
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
be worth checking the logs in `/cache/log/` for more data on when the cache
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
