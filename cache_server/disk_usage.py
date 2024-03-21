#!/usr/bin/env python3
"""Gather usage statistics on the cache server volume utilization.

This script is expected to be run via /etc/crontab daily, as `root`.  Its output should
be redirected to a logfile.
"""

import argparse
import os
import shutil
import sys
from pathlib import Path
from textwrap import dedent

from cache_logging import cache_logging_basic_setup, log_message


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "-t",
        "--threshold",
        type=float,
        default=85.0,
        help="Threshold to send an email alert if disk usage exceeds this value.",
    )
    parser.add_argument(
        "mount_point",
        type=Path,
        help="The directory the cache is mounted on, e.g., `/cache/toyotacache`.",
    )

    args = parser.parse_args()

    # We compute a percent used, threshold must represent a percentage.
    if args.threshold <= 0.0 or args.threshold >= 100.0:
        parser.error("threshold must be in the exclusive range (0, 100).")

    # shutil.disk_usage accepts files as well, but we want a directory for this script.
    if not args.mount_point.is_dir():
        parser.error(
            f"the provided mount_point='{args.mount_point}' is not a directory."
        )

    # This script must should be run as root in order to analyze filesystems.
    if os.geteuid() != 0:
        parser.error("this script must be run as root!")

    # Gather disk usage data if possible.
    try:
        du = shutil.disk_usage(args.mount_point)
    except Exception as e:
        parser.error(f"error collecting disk usage on '{args.mount_point}': {e}")

    # An invalid path may result in zero total size being reported.
    if du.total <= 0:
        parser.error(
            f"the provided mount_point='{args.mount_point}' has zero total size."
        )

    # Set up logging configurations.
    cache_logging_basic_setup()

    # Compute and report the data / statistics we care about.  All of our cache servers
    # operate on the order of gigabytes, so there is no need to be able to detect
    # MB or KB, for example.
    BYTES_TO_GiB = 1073741824.0  # 1024.0 * 1024.0 * 1024.0
    used_GiB = du.used / BYTES_TO_GiB
    free_GiB = du.free / BYTES_TO_GiB
    total_GiB = du.total / BYTES_TO_GiB
    percent_used = (du.used / du.total) * 100.0
    mount_data = dedent(
        f"""
        - Mount: {args.mount_point}
        - Used:  {round(used_GiB, 4)} GiB
        - Free:  {round(free_GiB, 4)} GiB
        - Total: {round(total_GiB, 4)} GiB
        - %Used: {round(percent_used, 2)}%
    """
    )
    log_message(mount_data)

    if percent_used < args.threshold:
        # Simply report back to the logs everything is as expected.
        log_message(
            f"\n==> {percent_used:.2f}% usage is adequately beneath {args.threshold}%",
        )
    else:
        log_message(
            dedent(
                f"""
            [X] The cache server disk usage is too high:

            {percent_used:.2f}% usage exceeds provided threshold of {args.threshold}%

            The `remove_old_files.py` cron job runs every 15 minutes (e.g., at
            12:00, 12:15, 12:30, and 12:45).  It can take up to 5 minutes to
            complete, please wait until the automated file removal routine is
            complete and re-launch this cache server health check job.

            If it fails again, please start a thread in the #buildcop slack
            channel delegating to Kitware:

                https://drakedevelopers.slack.com/archives/C270MN28G

            Or follow the instructions to prune manually:

                https://github.com/RobotLocomotion/drake-ci/tree/main/cache_server
        """
            )
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
