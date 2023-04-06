#!/usr/bin/env python3
"""Gather usage statistics on the cache server volume utilization.

This script is expected to be run via /etc/crontab daily, as `root`.  Its output should
be redirected to a logfile.
"""

import argparse
import logging
import os
from pathlib import Path
import shutil
import sys
from textwrap import dedent


def log(
    msg: str,
):
    """Log each line in ``msg`` (individually) to ``logging.warning``.  Assumes
    ``logging.basicConfig`` has already been configured.

    In the log files we want an organized structure with all messages preceded
    by their date.
    """
    for line in msg.splitlines():
        logging.warning(line)


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
            f"the provided mount_point='{str(args.mount_point)}' is not a directory."
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
            f"the provided mount_point='{str(args.mount_point)}' has zero total size."
        )

    # Configure the logging format *before* any `log` calls are issued.
    logging.basicConfig(
        format="%(asctime)s :: %(message)s", datefmt="%Y-%m-%d %H:%M:%S"
    )

    # Make it easy for the reviewer to find separate entries in the logfile.
    log("=" * 80)

    # Compute and report the data / statistics we care about.  All of our cache servers
    # operate on the order of gigabytes, so there is no need to be able to detect
    # MB or KB, for example.
    BYTES_TO_GB = 1073741824.0  # 1024.0 * 1024.0 * 1024.0
    used_GB = du.used / BYTES_TO_GB
    free_GB = du.free / BYTES_TO_GB
    total_GB = du.total / BYTES_TO_GB
    percent_used = (du.used / du.total) * 100.0
    mount_data = dedent(
        f"""
        - Mount: {str(args.mount_point)}
        - Used:  {round(used_GB, 4)} GB
        - Free:  {round(free_GB, 4)} GB
        - Total: {round(total_GB, 4)} GB
        - %Used: {round(percent_used, 2)}%
    """
    )
    log(mount_data)

    if percent_used < args.threshold:
        # Simply report back to the logs everything is as expected.
        log(
            f"\n==> {percent_used}% usage is adequately beneath {args.threshold}%!",
        )
    else:
        log(
            dedent(
                f"""
            [X] The cache server disk usage is too high:

            {percent_used}% usage exceeds the provided threshold of {args.threshold}%!

            Please start a thread in the #buildcop slack channel delegating to Kitware:

            https://drakedevelopers.slack.com/archives/C270MN28G

            Or follow the instructions to cleanup manually:

            https://github.com/RobotLocomotion/drake-ci/tree/main/cache_server
        """
            )
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
