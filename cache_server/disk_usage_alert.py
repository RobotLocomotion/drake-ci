#!/usr/bin/env python3
"""Gather usage statistics on the cache server volume utilization, emailing
developers when the cache server utilization is too high.

This script is expected to be run via /etc/crontab daily, as `root`.  The
/etc/ssmtp/ssmtp.conf must already must already be configured, see the README for more:
https://github.com/RobotLocomotion/drake-ci/tree/main/cache_server

For cron jobs, provide the argument ``--log-file /path/to/desired.log`` so that
administrators can review the scripts automated actions.  Use ``--log-console`` to
instead have output print to the console.  One of ``--log-file`` or ``--log-console``
must be provided.  Usage of ``--log-console`` via ``cron`` is discouraged, any output
to stdout / stderr in cron will get emailed (to nobody) via ``ssmtp``.
"""

import argparse
from datetime import datetime, timezone
import logging
import os
from pathlib import Path
import shutil
import subprocess
from textwrap import dedent


def log(
    msg: str,
    *,
    to_console: bool,
):
    """Log ``msg`` to the console, or log each line in ``msg`` (individually) to
    ``logging.warning``.  Assumes ``logging.basicConfig`` has already been
    configured.

    In the log files we want an organized structure with all messages preceded
    by their date.  When logging to the console, this information is less useful.
    """
    if to_console:
        print(msg)
    else:
        for line in msg.splitlines():
            logging.warning(line)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "-n",
        "--name",
        type=str,
        required=True,
        choices=[
            "mac-arm64"
            # TODO(svenevs): add in the other cache servers when they are alive.
            # "mac-x86",
            # "linux",
        ],
        help="The name of the cache server (used in emails).",
    )
    parser.add_argument(
        "-t",
        "--threshold",
        type=float,
        default=80.0,
        help="Threshold to send an email alert if disk usage exceeds this value.",
    )
    log_group = parser.add_mutually_exclusive_group(required=True)
    log_group.add_argument(
        "--log-file",
        dest="log_file",
        type=Path,
        help="File to log to.  If the file exists, it will be appended to.",
    )
    log_group.add_argument(
        "--log-console",
        dest="log_console",
        action="store_true",
        help="Log to the console rather than to a file.",
    )
    parser.add_argument(
        "-e",
        "--emails",
        nargs="+",
        default=[
            "drake-alerts+jenkins@tri.global",
            "drake-developers+build-cop@kitware.com",
        ],
        help="Where to send emails to if disk usage is too high.",
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
    basic_config_kwargs = dict(
        format="%(asctime)s :: %(message)s", datefmt="%Y-%m-%d %H:%M:%S"
    )
    if not args.log_console:
        basic_config_kwargs["filename"] = args.log_file
        basic_config_kwargs["filemode"] = "a"  # append is default, but be explicit
    logging.basicConfig(**basic_config_kwargs)  # type: ignore[arg-type]

    # When logging to a file, make it easy for the reviewer to find separate entries.
    if not args.log_console:
        log("=" * 80, to_console=args.log_console)

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
    log(mount_data, to_console=args.log_console)

    if percent_used < args.threshold:
        # Simply report back to the logs everything is as expected.
        log(
            f"\n==> {percent_used}% usage is adequately beneath {args.threshold}%!",
            to_console=args.log_console,
        )
    else:
        # Different servers are in different regions, primarily operated in US/Eastern
        # but some of them have their clocks set to UTC.
        now = datetime.now(timezone.utc)
        # NOTE: include the year-month-day hour:minute in subject so that each alert
        # will start a new "email thread".
        subject = f"Cache Overutilized {now.strftime('%Y-%m-%d %H:%M:%S UTC')}"

        # NOTE: do not word-wrap sentences to the next line, it looks weird in the
        # actual email body.  This `last_sentence` is to be all on one line, but for
        # code line-length purposes we define it this way.
        last_sentence = (
            "Please start a thread in the #buildcop slack channel "
            "https://drakedevelopers.slack.com/archives/C270MN28G delegating to "
            "Kitware, or follow the instructions at "
            "https://github.com/RobotLocomotion/drake-ci/tree/main/cache_server to "
            "cleanup manually."
        )
        cache_server_name = f"Drake {args.name} Cache Server"
        # ssmtp parses for the line `Subject: ...` for the email subject.
        # NOTE: `mount_data` needs to be formatted *after* dedent.
        ssmtp_email = dedent(
            f"""\
            Subject: {subject}

            The {cache_server_name} disk usage is too high:
            {{mount_data}}
            {percent_used}% exceeds the provided threshold of {args.threshold}%.

            {last_sentence}
        """
        ).format(mount_data=mount_data)
        log(
            f"\n(!) Emailing alert to: {', '.join(args.emails)} (!)\n\n",
            to_console=args.log_console,
        )
        log(ssmtp_email, to_console=args.log_console)

        ssmtp_args = [
            "ssmtp",
            "-F",
            cache_server_name,
            *args.emails,
        ]
        try:
            proc = subprocess.run(
                ssmtp_args,
                capture_output=True,
                input=bytes(ssmtp_email, "utf-8"),
            )
            if proc.returncode != 0:
                log(
                    dedent(
                        f"""
                        ERROR:
                          Nonzero exit code of {proc.returncode} running {ssmtp_args}
                          {proc.stdout.decode('ascii')}
                          {proc.stderr.decode('ascii')}
                    """
                    ),
                    to_console=args.log_console,
                )
            else:
                log(f"\nSUCCESS: Alert sent: {ssmtp_args}", to_console=args.log_console)
        except Exception as e:
            log(
                dedent(
                    f"""
                    ERROR:
                      Unable to execute {ssmtp_args}:
                      {e}
                """
                ),
                to_console=args.log_console,
            )


if __name__ == "__main__":
    main()
