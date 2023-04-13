#!/usr/bin/env python3
"""Expunge old cache server data files.

By default, files **accessed** more than 4 days ago will be deleted.  Since different
servers may require different cache eviction strategies, it is also possible to request
a different timedelta.  To keep the implementation simple (rather than trying to parse
a :class:`python:datetime.timedelta` from the command line), a different timedelta can
be created by supplying one of the supplemental time arguments ``--days``,
``--seconds``, ``--minutes``, ``--hours``, and/or ``--weeks``.  These arguments are
combined together to create the final timedelta, and each must be non-negative.  See:

https://docs.python.org/3/library/datetime.html#datetime.timedelta

.. note::

    The default for days is always 4.  If you desire to delete all files that have not
    been accessed within the last 5 hours, for example, you should supply both
    ``--days 0`` and ``--hours 5``.  Providing just `--hours 5`` will result in four
    days and five hours.
"""

from __future__ import annotations

import argparse
import os
import sys
from datetime import datetime, timedelta
from enum import Enum, unique
from pathlib import Path

from cache_logging import cache_logging_basic_setup, log_message


def bytes_to_human_string(size_bytes: int) -> str:
    """Return a human readable conversion of the provided ``size_bytes`` to either GiB,
    MiB, KiB, or Bytes (all base 1024).  The largest whole unit available is chosen."""
    BYTES_TO_GB = 1073741824.0  # 1024.0 * 1024.0 * 1024.0
    BYTES_TO_MB = 1048576.0  # 1024.0 * 1024.0
    BYTES_TO_KB = 1024.0
    if size_bytes >= BYTES_TO_GB:
        value = size_bytes / BYTES_TO_GB
        units = "GiB"
    elif size_bytes >= BYTES_TO_MB:
        value = size_bytes / BYTES_TO_MB
        units = "MiB"
    elif size_bytes >= BYTES_TO_KB:
        value = size_bytes / BYTES_TO_KB
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


class CacheDirectory:
    """Scan and encapsulate the cache directory, accumulating files to be pruned.

    **Attributes**
    root: Path
        Path to the cache directory root.

    time_metric: TimeMetric
        Which kind of time we are querying (access or modified time).

    delta_max: timedelta
        The timedelta used for querying file access time results.

    dry_run: bool
        If true, no files will be deleted, only metrics printed.

    start_time: datetime
        The time at which scanning began for access time comparison to delta_max.

    files: list[tuple[Path, int, datetime]]
        Candidates for deletion, this list holds (file path, size bytes, access time)
        tuples describing all files found under ``root`` that are older than ``delta``
        time units.

    invalid_files: list[tuple[Path, str]]
        A list of tuples (file path, error message) of files whose access times could
        not be discovered.

    files_scanned: int
        Total number of files examined from the ``root`` directory.

    size_bytes: int
        Total size in bytes of all files described by ``files`` attribute.
    """

    def __init__(
        self,
        *,
        root: Path,
        time_metric: TimeMetric,
        delta_max: timedelta,
        dry_run: bool,
    ) -> None:
        self.root = root
        self.time_metric = time_metric
        self.delta_max = delta_max
        self.dry_run = dry_run
        self.start_time = datetime.now()
        self.files: list[tuple[Path, int, datetime]] = []
        self.invalid_files: list[tuple[Path, str]] = []
        self.files_scanned = 0
        self.size_bytes = 0

        if self.time_metric == TimeMetric.ACCESS_TIME:
            time_attr = "st_atime"
        elif self.time_metric == TimeMetric.MODIFIED_TIME:
            time_attr = "st_mtime"

        for directory_root, _, file_names in os.walk(self.root):
            directory_root_path = Path(directory_root)
            for f in file_names:
                self.files_scanned += 1
                f_path: Path = directory_root_path / f
                try:
                    # NOTE: Path.stat() can raise on e.g., broken symlinks.
                    f_stat = f_path.stat()

                    # Convert the access time from unix time to datetime.  Skip if the
                    # file is newer than the start_time (this script may run while the
                    # cache is being populated, newer files should be ignored).
                    time_query = datetime.fromtimestamp(getattr(f_stat, time_attr))
                    if time_query >= self.start_time:
                        continue

                    # Add anything accessed longer ago than the provided threshold.
                    if (self.start_time - time_query) >= delta_max:
                        self.files.append((f_path, f_stat.st_size, time_query))
                        self.size_bytes += f_stat.st_size
                except Exception as e:
                    self.invalid_files.append((f_path, str(e)))

    def dump_stats(self, summary_only: bool = False) -> None:
        """Print various statistics about the files and storage found.

        If ``summary_only=True``, only the final summary is printed.
        """
        # If there are invalid files (likely only broken symlinks), print them all first
        # so that the log has this information, but the more important data comes last.
        if not summary_only and self.invalid_files:
            log_message("--- INVALID FILES:")
            for f_path, err_msg in self.invalid_files:
                log_message(f"INVALID: {str(f_path)}: {err_msg}")
            log_message(f"--- END INVALID FILES ({len(self.invalid_files)} total)")

        # Reorganize a mapping of access time => (path, size_bytes) to make
        # sorting and binning based off date easier.
        time_map: dict[datetime, list[tuple[Path, int]]] = {}
        for f_path, size_bytes, time_query in self.files:
            value = (f_path, size_bytes)
            if time_query in time_map:
                time_map[time_query].append(value)
            else:
                time_map[time_query] = [value]

        # Print by access times first, gather data for dumping by size after.
        if not summary_only:
            log_message(f"==> By access times ({len(time_map)} total):")
            size_to_time_map: dict[int, list[datetime]] = {}
            for key in sorted(time_map):
                file_path_size_bytes = time_map[key]
                size_bytes = sum(fpsb[1] for fpsb in file_path_size_bytes)
                # Two access times *may* end up having the same total size_bytes,
                # make sure not to overwrite.
                if size_bytes in size_to_time_map:
                    size_to_time_map[size_bytes].append(key)
                else:
                    size_to_time_map[size_bytes] = [key]
                human_readable = bytes_to_human_string(size_bytes)
                log_message(f"{key} ({len(value)} total): {human_readable}")

        # Print out by size next.
        if not summary_only:
            log_message(f"==> By size ({len(size_to_time_map)} total):")
            for size_bytes in reversed(sorted(size_to_time_map)):
                values = size_to_time_map[size_bytes]
                human_readable = bytes_to_human_string(size_bytes)
                # Duplicates are printed multiple times for simplicity.
                for v in values:
                    log_message(f"{human_readable}: {v}")

        # Print out the most useful information last so it is readily available.
        log_message(f"==> {str(self.root)}")
        log_message(f"Found: {self.files_scanned} total files.")
        log_message(f"{len(self.files)} file(s) eligible for pruning.")
        human_readbale = bytes_to_human_string(self.size_bytes)
        log_message(f"{human_readbale} disk space eligible for pruning.")

    def maybe_prune(self) -> None:
        """Print relevant data to the console and perform the pruning (if
        ``self.dry_run=False``)."""
        if not self.dry_run:
            # Because pruning can take a little while, it may give the
            # appearance that the script is stuck.  Print out incremental
            # progress so the user knows it is still running.  Do not use
            # anything fancy such as carriage returns or a progress meter, the
            # logfile will be very disorganized.
            n_files = len(self.files)
            one_tenth = int(n_files // 10) + 1
            percent_indicator = 0
            errors: list[tuple[Path, str]] = []  # (path, error message)
            for i, (f_path, _, _) in enumerate(self.files):
                if i == 0 or (i % one_tenth) == 0:
                    log_message(f"{percent_indicator}% ...")
                    percent_indicator += 10
                try:
                    f_path.unlink()
                except Exception as e:
                    errors.append((f_path, str(e)))
            log_message("DONE.")

            if errors:
                log_message("Errors found deleting files:")
                for f_path, error_message in errors:
                    log_message(f"- {str(f_path)}: {error_message}")
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
        "-s",
        "--summary",
        action="store_true",
        help="Only print a summary in the statistics.",
    )
    parser.add_argument(
        "-n",
        "--dry_run",
        dest="dry_run",
        action="store_true",
        help="Print what will be pruned without deleting.",
    )
    parser.add_argument(
        "--days",
        type=float,
        default=4.0,
        help="Number of days for the timedelta (default: %(default)s).",
    )
    parser.add_argument(
        "--seconds",
        type=float,
        default=0.0,
        help="Number of seconds for the timedelta (default: %(default)s).",
    )
    parser.add_argument(
        "--minutes",
        type=float,
        default=0.0,
        help="Number of minutes for the timedelta (default: %(default)s).",
    )
    parser.add_argument(
        "--hours",
        type=float,
        default=0.0,
        help="Number of hours for the timedelta (default: %(default)s).",
    )
    parser.add_argument(
        "--weeks",
        type=float,
        default=0.0,
        help="Number of weeks for the timedelta (default: %(default)s).",
    )
    # NOTE: add the positional argument last.
    parser.add_argument(
        "cache_dir",
        type=Path,
        help="Root directory to traverse and prune old files from.",
    )

    args = parser.parse_args()

    # Make sure all timedelta kwargs are positive to avoid invalid comparisons.
    td_kwargs = {
        "days": args.days,
        "seconds": args.seconds,
        "microseconds": 0,
        "milliseconds": 0,
        "minutes": args.minutes,
        "hours": args.hours,
        "weeks": args.weeks,
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

    delta_max = timedelta(**td_kwargs)

    # Setup logging configurations.
    cache_logging_basic_setup()
    log_message(f"Age strategy:   {time_metric}")
    log_message(f"Time delta max: {delta_max}")

    cache_dir = CacheDirectory(
        root=args.cache_dir,
        time_metric=time_metric,
        delta_max=delta_max,
        dry_run=args.dry_run,
    )
    cache_dir.dump_stats(summary_only=args.summary)
    cache_dir.maybe_prune()


if __name__ == "__main__":
    main()
