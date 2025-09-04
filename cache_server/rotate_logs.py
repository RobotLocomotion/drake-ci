#!/usr/bin/env python3
"""Rotate log files using ``logrotate`` and restart ``nginx``.

This script is expected to run by cron. See the associated
``logrotate_cache.conf`` for the ``logrotate`` command which specifies the
directories and rules for log files being rotated.

After ``logrotate`` runs, however, the log files
``/opt/cache_server/nginx/{access,error}.log`` may have been removed.  Running
``nginx -s reload`` will close the file handles ``nginx`` had open to the previous
(now possibly rotated to a new filename) log files, and open new ones.  Without
reloading, all nginx logging for logs that have been rotated will stop.
"""

from __future__ import annotations

import os
import platform
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import NoReturn

from cache_logging import cache_logging_basic_setup, log_message


def error(msg: str, exit_code: int = 1) -> NoReturn:
    """
    Print ``msg`` to ``stderr`` followed by a newline and exit with the provided code.
    """
    sys.stderr.write(msg)
    sys.stderr.write("\n")
    sys.exit(exit_code)


def log_stdout_stderr(proc: subprocess.CompletedProcess):
    """Log ``stdout`` and ``stderr`` of the completed process, if non-empty."""
    stdout = proc.stdout.decode("utf-8").strip()
    if stdout:
        log_message(stdout)
    stderr = proc.stderr.decode("utf-8").strip()
    if stderr:
        log_message(stderr)


def main():
    # Our cache server is Linux and the commands below all assume this.
    if platform.system() != "Linux":
        error("This script only runs on linux.")

    # This script must be run as root in order to create the right permissions and
    # manage services.
    if os.geteuid() != 0:
        error("This script must be run as root.")

    logrotate = shutil.which("logrotate")
    if logrotate is None:
        error("Could not find the `logrotate` command.  Is it installed?")

    # Logs are stored in /opt/cache_server/log/.  Send the logging output of the
    # ``logrotate`` command to /opt/cache_server/logrotate.log, and then re-log that to
    # stdout (this script should run under cron and redirect to
    # /opt/cache_server/log/rotate_logs.log).
    this_file_dir = Path(__file__).parent.absolute()
    logrotate_conf_path = this_file_dir / "logrotate_cache.conf"
    if not logrotate_conf_path.is_file():
        error(f"'{logrotate_conf_path}' is not a file.")

    # ``logrotate`` setup.
    opt_cache_server = Path("/opt") / "cache_server"
    logrotate_log_path = opt_cache_server / "logrotate.log"
    logrotate_log_path.unlink(missing_ok=True)
    logrotate_args = [
        logrotate,
        "--verbose",
        "--log",
        str(logrotate_log_path),
        str(logrotate_conf_path),
    ]

    cache_logging_basic_setup()
    log_message(f"Running: {logrotate_args}")

    # Run and log ``logrotate``.
    logrotate_proc = subprocess.run(
        logrotate_args,
        capture_output=True,
        check=True,
    )
    log_stdout_stderr(logrotate_proc)

    # Log any messages from the ``logrotate`` logfile.  It gets recreated each time the
    # command is run, so deleting after logging it is safe.
    if logrotate_log_path.is_file():
        with open(logrotate_log_path, "r") as f:
            log_message(f.read().strip())
        logrotate_log_path.unlink()

    # Recreate the ``nginx`` logging files with the correct ownership in the event that
    # ``logrotate`` deleted them.
    log_message("Requesting nginx re-open its logfiles.")
    nginx_proc = subprocess.run(
        ["nginx", "-s", "reopen"], capture_output=True, check=True
    )
    log_stdout_stderr(nginx_proc)

    # These calls are non-blocking, give time before checking.
    sleep_duration = 3.0
    log_message(f"Sleeping for {sleep_duration} seconds...")
    time.sleep(sleep_duration)

    log_message("Checking that nginx service is active:")
    # Gives a non-zero exit code if it is not active.
    systemctl_proc = subprocess.run(
        ["systemctl", "is-active", "nginx"], capture_output=True, check=True
    )
    log_stdout_stderr(systemctl_proc)

    nginx_log_dir = opt_cache_server / "log" / "nginx"
    access_log = nginx_log_dir / "access.log"
    error_log = nginx_log_dir / "error.log"
    nginx_log_files = [access_log, error_log]
    log_message(
        "Verifying nginx logging files ("
        f"{', '.join([str(f) for f in nginx_log_files])}):"
    )
    for f in nginx_log_files:
        if not f.is_file():
            error(f"Expected nginx log file '{f}' to be a file but it was not.")

    # Fixup the permissions issues.
    log_message(f"Changing ownership of {nginx_log_dir} to www-data:www-data.")
    chown_proc = subprocess.run(
        ["chown", "-R", "www-data:www-data", str(nginx_log_dir)],
        capture_output=True,
        check=True,
    )
    log_stdout_stderr(chown_proc)


if __name__ == "__main__":
    main()
