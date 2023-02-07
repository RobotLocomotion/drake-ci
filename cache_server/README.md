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

3. Each server should have a `cron` job running each evening to cleanup older
   files.  This is managed by [`cleanup_old_files.py`](cleanup_old_files.py),
   a sample entry in `/etc/crontab`:

   ```shell
    # This cache server's date / time are in UTC!  Conversion:
    # EST: +5 hours to get to UTC
    # EDT: +4 hours to get to UTC
    # Cache cleanup: run ~10pm eastern (before nightlies).
    0 3     * * *   root    /cache/drake-ci/cache_server/cleanup_old_files.py -s --days 4 /cache/toyotacache
   ```

4. Each server should also have a `cron` job running each morning to confirm
   the cache cleanup routine is pruning everything it needs to.  Overutilized
   caches litter the nightly and continuous jobs with 500 internal server errors
   as the `nginx` server cannot write any new files.  This is managed by
   [`disk_usage_alert.sh`](disk_usage_alert.sh), a sample entry in
   `/etc/crontab`:

   ```shell
    # This cache server's date / time are in UTC!  Conversion:
    # EST: +5 hours to get to UTC
    # EDT: +4 hours to get to UTC
    #
    # Cache (over)utilization alerting: run ~7am eastern.
    0 12    * * *   root    /cache/drake-ci/cache_server/disk_usage_alert.sh
   ```

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

2. Install `ssmtp` and `mailutils` and update the contents of
   `/etc/ssmtp/ssmtp.conf` with [our `ssmtp.conf`](ssmtp.conf).  A new cache
   server should receive a new App Password, which should be stored in the
   [AWS Secrets Manager][aws_secrets].  This is the value for `AuthPass`.

   Test that you can use `ssmtp` to send a test email to yourself from the
   server before continuing:

   ```console
   # Create a text file with a subject and message body.
   $ cat test_message.txt
   Subject: Drake Cache Email Test

   This message is coming from the cache server!

   # Send a test e-mail to ONLY you.  Do not spam buildcop emails.
   $ ssmtp -F "Drake Cache Server" my.email@domain.com < test_message.txt
   ```

   This will confirm that `ssmtp` can authenticate and send emails.

3. Configure [`disk_usage_alerts.sh`](disk_usage_alerts.sh) to update the
   variables at the top for the cache server in question.  Place it at
   `/cache/disk_usage_alerts.sh` and add an entry to `/etc/crontab` as shown
   above.  We desire this alert to run around 7am eastern, take care to confirm
   which time zone your cache server believes it is in.

4. Copy [`cleanup_old_files.py`](cleanup_old_files.py) to
   `/cache/cleanup_old_files.py` and add an entry to `/etc/crontab` as shown
   above.  We desire this cleanup to run around 10pm eastern, take care to
   confirm which time zone your cache server believes it is in.

5. Make sure that the new server will have its initial `DASHBOARD_REMOTE_CACHE`
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

[aws_secrets]: https://us-east-1.console.aws.amazon.com/secretsmanager/listsecrets?region=us-east-1
