#!/usr/bin/env python3
"""Remove old cache server data files.

By default, files **accessed** more than 2 days ago will be deleted.  Since different
servers may require different cache eviction strategies, it is also possible to request
a different timedelta.  To keep the implementation simple (rather than trying to parse
a :class:`python:datetime.timedelta` from the command line), a different timedelta can
be created by supplying one of the supplemental time arguments ``--days``, ``--hours``,
``--minutes``.  These arguments are combined together to create the final timedelta,
each must be non-negative.  See:

https://docs.python.org/3/library/datetime.html#datetime.timedelta

.. note::

    The default for days is always 2.  If you desire to delete all files that have not
    been accessed within the last 5 hours, for example, you should supply both
    ``--days 0`` and ``--hours 5``.  Providing just `--hours 5`` will result in four
    days and five hours.
"""

from __future__ import annotations

import argparse
import os
import shutil
import sys
from datetime import datetime, timedelta
from enum import Enum, unique
from pathlib import Path

from cache_logging import cache_logging_basic_setup, log_message

DEFAULT_DELTA_MAX = timedelta(days=2)
"""Default time duration for determining files to remove."""


def bytes_to_human_string(size_bytes: int) -> str:
    """Return a human readable conversion of the provided ``size_bytes`` to either GiB,
    MiB, KiB, or Bytes.  The largest whole unit available is chosen."""
    BYTES_TO_GiB = 1073741824.0  # 1024.0 * 1024.0 * 1024.0
    BYTES_TO_MiB = 1048576.0  # 1024.0 * 1024.0
    BYTES_TO_KiB = 1024.0
    if size_bytes >= BYTES_TO_GiB:
        value = size_bytes / BYTES_TO_GiB
        units = "GiB"
    elif size_bytes >= BYTES_TO_MiB:
        value = size_bytes / BYTES_TO_MiB
        units = "MiB"
    elif size_bytes >= BYTES_TO_KiB:
        value = size_bytes / BYTES_TO_KiB
        units = "KiB"
    else:
        value = size_bytes
        units = "Bytes"

    return f"{round(value, 2)} {units}"


@unique
class TimeMetric(Enum):
    """Which time to query from stat (https://docs.python.org/3/library/stat.html)."""

    ACCESS_TIME = "access"
    """Query ``st_atime`` (time of last access)."""

    MODIFIED_TIME = "modified"
    """Query ``st_mtime`` (time of last modification)."""


@unique
class Strategy(Enum):
    """Which file removal strategy is being employed."""

    AUTO = "auto"
    """Automatic file removal mode: iteratively find the time metric needed to get the
    filesystem storage below a certain threshold utilization."""

    MANUAL = "manual"
    """Manual file removal mode: remove files utilizing the provided time duration such
    as --days 1 --hours 12."""


class CacheDirectory:
    """Scan and encapsulate the cache directory, accumulating files to be pruned.

    Usage:

    1. Create the CacheDirectory instance once.  Accumulating the list of all files
       takes the longest amount of time.
    2. Call :func:`CacheDirectory.gather_files_for_removal` with your desired timedelta
       to populate :attr:`CacheDirectory.files_to_remove`.
    3. Repeat step 2 as desired with new timedelta, e.g., for :data:`Strategy.AUTO`.
    4. Call :func:`CacheDirectory.maybe_remove_files` to remove the list of files that
       matched the latest gather / timedelta query (if not a dry run).

    **Attributes**
    root: Path
        Path to the cache directory root.

    time_metric: TimeMetric
        Which kind of time we are querying (access or modified time).

    dry_run: bool
        If true, no files will be deleted, only metrics printed.

    start_time: datetime
        The time at which scanning began for access time comparison to delta_max.

    files: list[tuple[Path, int, datetime]]
        The list of all files found.  Holds (file path, size bytes, access/modify time)
        tuples describing files to consider for deletion.

    files_to_remove: list[tuple[Path, int, datetime]]
        Candidates for deletion.  This list holds
        (file path, size bytes, access/modify time) tuples describing all files found
        under ``root`` that are older than ``delta`` time units.

    invalid_files: list[tuple[Path, str]]
        A list of tuples (file path, error message) of files whose access times could
        not be discovered.

    files_scanned: int
        Total number of files examined from the ``root`` directory.

    size_bytes: int
        Total size in bytes of all files described by ``files`` attribute.

    bytes_to_remove: int
        Total size in bytes of all files described by ``files_to_remove`` attribute.
    """

    def __init__(
        self,
        *,
        root: Path,
        time_metric: TimeMetric,
        dry_run: bool,
    ) -> None:
        self.root = root
        self.time_metric = time_metric
        self.dry_run = dry_run
        self.start_time = datetime.now()
        self.files: list[tuple[Path, int, datetime]] = []
        self.files_to_remove: list[tuple[Path, int, datetime]] = []
        self.invalid_files: list[tuple[Path, str]] = []
        self.files_scanned = 0
        self.size_bytes = 0
        self.bytes_to_remove = 0

        if self.time_metric == TimeMetric.ACCESS_TIME:
            time_attr = "st_atime"
        elif self.time_metric == TimeMetric.MODIFIED_TIME:
            time_attr = "st_mtime"

        # Gather all files that can be potentially removed, storing their time metric.
        for directory_root, _, file_names in os.walk(self.root):
            directory_root_path = Path(directory_root)
            for f in file_names:
                self.files_scanned += 1
                f_path: Path = directory_root_path / f
                try:
                    # NOTE: Path.stat() can raise on e.g., broken symlinks.
                    f_stat = f_path.stat()

                    # Convert the access / modification time from unix time to datetime.
                    # Skip if the file is newer than the start_time (this script may run
                    # while the cache is being populated, ignore newer files).
                    time_query = datetime.fromtimestamp(getattr(f_stat, time_attr))
                    if time_query >= self.start_time:
                        continue

                    # Gather the list of all possible files once.
                    self.files.append((f_path, f_stat.st_size, time_query))
                    self.size_bytes += f_stat.st_size
                except Exception as e:
                    self.invalid_files.append((f_path, str(e)))

    def gather_files_for_removal(self, delta_max: timedelta):
        """Returns total number of bytes that will be deleted by delta_max.

        All files able to be deleted will be added to self.files_to_remove."""
        self.bytes_to_remove = 0
        self.files_to_remove.clear()
        for f_path, size_bytes, time_query in self.files:
            # Add anything accessed/modified longer ago than the threshold.
            if (self.start_time - time_query) >= delta_max:
                self.files_to_remove.append((f_path, size_bytes, time_query))
                self.bytes_to_remove += size_bytes

    def log_invalid_files(self):
        if self.invalid_files:
            log_message("--- INVALID FILES:")
            for f_path, err_msg in self.invalid_files:
                log_message(f"INVALID: {f_path}: {err_msg}")
            log_message(f"--- END INVALID FILES ({len(self.invalid_files)} total)")

    def log_total_storage_found(self):
        log_message(f"Found: {self.files_scanned} total files.")
        log_message(f"       {bytes_to_human_string(self.size_bytes)} total data.")

    def log_files_to_remove(self):
        log_message(f"Found: {len(self.files_to_remove)} file(s) to remove.")
        log_message(
            f"       {bytes_to_human_string(self.bytes_to_remove)} disk space "
            "eligible for removal."
        )

    def log_all_statistics(self) -> None:
        """Log all statistics about the files and storage found."""
        # If there are invalid files (likely only broken symlinks), print them all first
        # so that the log has this information, but the more important data comes last.
        self.log_invalid_files()

        # Print out the most useful information last so it is readily available.
        log_message(f"==> {self.root}")
        self.log_total_storage_found()
        self.log_files_to_remove()

    def maybe_remove_files(self) -> None:
        """Print relevant data to the console and perform the pruning (if
        ``self.dry_run=False``)."""
        if not self.dry_run:
            # Because pruning can take a little while, it may give the
            # appearance that the script is stuck.  Print out incremental
            # progress so the user knows it is still running.  Do not use
            # anything fancy such as carriage returns or a progress meter, the
            # logfile will be very disorganized.
            n_files = len(self.files_to_remove)
            n_format = len(str(n_files))  # to align [ x / {n_files} ]
            one_tenth = int(n_files // 10) + 1
            errors: list[tuple[Path, str]] = []  # (path, error message)
            for i, (f_path, _, _) in enumerate(self.files_to_remove):
                if i == 0 or (i % one_tenth) == 0:
                    log_message(f"Removing file [{i+1: >{n_format}} / {n_files}] ...")
                try:
                    f_path.unlink()
                except Exception as e:
                    errors.append((f_path, str(e)))
            log_message("DONE.")

            if errors:
                log_message("Errors found deleting files:")
                for f_path, error_message in errors:
                    log_message(f"- {f_path}: {error_message}")
                sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "-m",
        "--mode",
        type=str,
        choices=[tm.value for tm in TimeMetric],
        default=TimeMetric.ACCESS_TIME.value,
        help="Which time metric of the file to consider (default: %(default)s).",
    )
    parser.add_argument(
        "-n",
        "--dry_run",
        dest="dry_run",
        action="store_true",
        help="Print what will be pruned without deleting.",
    )

    # NOTE: names for subparsers added must come from Strategy enum.
    subparsers = parser.add_subparsers(
        help="Choose a removal strategy: auto or manual.",
        required=True,
        dest="strategy",
    )
    parser_auto = subparsers.add_parser(Strategy.AUTO.value, help=Strategy.AUTO.__doc__)
    parser_auto.add_argument(
        "-t",
        "--threshold",
        type=float,
        default=70.0,
        help=(
            "Threshold to get disk utilization to (70.0 means target at most 70%% "
            "utilized, or 30%% free).  Default: %(default)s.  Must be in range [1,99] "
            "inclusive."
        ),
    )

    parser_manual = subparsers.add_parser(
        Strategy.MANUAL.value,
        help=Strategy.MANUAL.__doc__,
    )
    parser_manual.add_argument(
        "--days",
        type=float,
        default=DEFAULT_DELTA_MAX.days,
        help="Number of days for the timedelta (default: %(default)s).",
    )
    parser_manual.add_argument(
        "--hours",
        type=float,
        default=DEFAULT_DELTA_MAX.seconds // 3600,
        help="Number of hours for the timedelta (default: %(default)s).",
    )
    parser_manual.add_argument(
        "--minutes",
        type=float,
        default=(DEFAULT_DELTA_MAX.seconds // 60) % 60,
        help="Number of minutes for the timedelta (default: %(default)s).",
    )

    # NOTE: add the positional argument last.
    for sub_parser in (parser_auto, parser_manual):
        sub_parser.add_argument(
            "cache_dir",
            type=Path,
            help="Root directory to traverse and prune old files from.",
        )

    args = parser.parse_args()

    # Overwrite with the enum value (argparse has issues with Enum).
    if args.strategy == Strategy.AUTO.value:
        strategy = Strategy.AUTO
    elif args.strategy == Strategy.MANUAL.value:
        strategy = Strategy.MANUAL
    else:
        parser.error(f"unrecognized strategy: {args.strategy}")

    # Make sure they provided us a directory.
    if not args.cache_dir.is_dir():
        parser.error(f"the provided cache_dir='{args.cache_dir}' is not a directory...")

    # This script must be run as root in order to do all of its pruning.
    if os.geteuid() != 0:
        parser.error("this script must be run as root!")

    # Create the enum value rather than a `str` (argparse has issues with Enum).
    if args.mode == TimeMetric.ACCESS_TIME.value:
        time_metric = TimeMetric.ACCESS_TIME
    elif args.mode == TimeMetric.MODIFIED_TIME.value:
        time_metric = TimeMetric.MODIFIED_TIME
    else:
        # This should be unreachable given how the argument is added with `choices`.
        parser.error(f"unknown mode {args.mode}.")

    # Subparser specific validation.
    delta_max = DEFAULT_DELTA_MAX
    if strategy == Strategy.AUTO:
        # Do not allow anything outside of [1,99] inclusive.
        if args.threshold < 1.0 or args.threshold > 99.0:
            parser.error(f"threshold {args.threshold}% invalid, must be in [1,99].")
    else:  # Strategy.MANUAL
        # Make sure all timedelta kwargs are positive to avoid invalid comparisons.
        td_kwargs = {
            "days": args.days,
            "seconds": 0.0,
            "microseconds": 0,
            "milliseconds": 0,
            "minutes": args.minutes,
            "hours": args.hours,
            "weeks": 0,
        }
        bad_kwargs = {}
        for key, value in td_kwargs.items():
            if value < 0.0:
                bad_kwargs[key] = value
        if bad_kwargs:
            parser.error(
                f"the following argument{'s' if len(bad_kwargs) > 1 else ''} "
                "must be greater than or equal to 0: "
                f"{', '.join(f'{k}={v}' for k, v in bad_kwargs.items())}"
            )
        delta_max = timedelta(**td_kwargs)

    # Set up logging configurations.
    cache_logging_basic_setup()
    log_message(f"Age strategy:   {time_metric}")
    log_message(f"Time delta max: {delta_max}")
    if args.dry_run:
        log_message("NOTE: dry run, (no files will be removed).")

    cache_dir = CacheDirectory(
        root=args.cache_dir,
        time_metric=time_metric,
        dry_run=args.dry_run,
    )
    if strategy == Strategy.AUTO:
        try:
            du = shutil.disk_usage(args.cache_dir)
        except Exception as e:
            parser.error(f"error collecting disk usage on '{args.cache_dir}': {e}")

        # An invalid path may result in zero total size being reported.
        if du.total <= 0:
            parser.error(
                f"the provided cache_dir='{args.cache_dir}' has zero total size."
            )

        # Iterate backward until we find a suitable number to delete.
        current_percent_used = (du.used / du.total) * 100.0
        min_possible_percent_used = (
            (du.used - cache_dir.size_bytes) / du.total
        ) * 100.0
        if current_percent_used <= args.threshold:
            log_message(
                f"Disk usage for {args.cache_dir} is currently at "
                f"{current_percent_used}%, which is beneath the requested threshold of "
                f"{args.threshold}.\nNo files to remove."
            )
        elif min_possible_percent_used > args.threshold:
            cache_dir.log_all_statistics()
            parser.error(
                f"cannot trim to {args.threshold}% usage, the {args.cache_dir} has "
                f"{du.used} / {du.total} bytes used, and cumulatively "
                f"{cache_dir.size_bytes} total bytes eligbile for removal were found.  "
                "The best threshold that can be achieved is "
                f"{round(min_possible_percent_used, 2)}%."
            )
        else:
            log_message(f"==> {cache_dir.root}")
            cache_dir.log_total_storage_found()
            log_message(
                f"Scanning for timedelta to achieve <= {args.threshold}% utilization:"
            )
            delta_max = DEFAULT_DELTA_MAX
            while (
                delta_max.total_seconds() > 0 and current_percent_used > args.threshold
            ):
                cache_dir.gather_files_for_removal(delta_max)
                new_du_used = du.used - cache_dir.bytes_to_remove
                current_percent_used = (new_du_used / du.total) * 100.0
                log_message(f"{delta_max}:")
                cache_dir.log_files_to_remove()
                log_message(f"==> would achieve {round(current_percent_used, 2)}%")

                delta_max -= timedelta(hours=2)

            log_message(f"DONE: {delta_max}")
            cache_dir.maybe_remove_files()
    else:  # strategy == Strategy.MANUAL
        cache_dir.gather_files_for_removal(delta_max)
        cache_dir.log_all_statistics()
        cache_dir.maybe_remove_files()


if __name__ == "__main__":
    main()
