"""Minimal common logging utilities for keeping the logging output of cache server
monitoring consistent (formatting and style).  Scripts are expected to first call
``logging_basic_config`` to configure the python logging module, and then use the
``log_message`` method to prefix every line of logged output with timestamps.

This file must live in the same directory as the helper scripts that use it."""

import logging
import sys


def _logging_basic_config(
    format: str = "%(asctime)s :: %(message)s",
    datefmt: str = "%Y-%m-%d %H:%M:%S",
    **kwargs
) -> None:
    """Configure the builtin python logging module log format.  This needs to be
    executed by the script running (rather than execute this at the module scope)."""
    if "stream" not in kwargs:
        kwargs["stream"] = sys.stdout
    logging.basicConfig(format=format, datefmt=datefmt, **kwargs)


def log_message(message: str) -> None:
    """Log each line in ``message`` (individually) to ``logging.warning``.  Assumes
    ``logging.basicConfig`` has already been configured.

    In the log files we want an organized structure with all messages preceded
    by their date.
    """
    assert isinstance(message, str), "log_message parameter must be a string."
    for line in message.splitlines():
        logging.warning(line)


def cache_logging_basic_setup(**kwargs):
    """Create the basic logging configuration and log a separation line to the console
    for making log entries easy to distinguish in remote logfiles.

    The keyword arguments are simply passed-through to ``logging.basicConfig``.
    """
    _logging_basic_config(**kwargs)
    log_message("=" * 80)
