"""A command-line bridge for writing structured JSON logs from Bash.

This script ensures that logs generated from Bash scripts are consistent in
format with those from the Python logging system.
"""

import argparse
import json
import sys
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path


@dataclass
class LogEntry:
    """A structured container for log data passed from the command line."""

    logfile: Path
    level: str
    message: str
    module: str
    function: str
    line: int


def write_bash_log_entry(entry: LogEntry) -> None:
    """Constructs and appends a single JSON log entry to the specified log file."""
    try:
        entry.logfile.parent.mkdir(parents=True, exist_ok=True)
        timestamp = datetime.now(UTC).isoformat()

        log_object = {
            "timestamp": timestamp,
            "level": entry.level.upper(),
            "message": entry.message,
            "module": entry.module,
            "function": entry.function,
            "line": entry.line,
            "source": "bash",
        }

        with entry.logfile.open("a", encoding="utf-8") as f:
            f.write(json.dumps(log_object) + "\n")

    except (OSError, PermissionError) as e:
        # Use sys.stderr.write for more robust error reporting in scripts.
        error_message = f"FATAL: Could not write to log file '{entry.logfile}'. Error: {e}\n"
        sys.stderr.write(error_message)
        sys.exit(1)


def main() -> None:
    """Parses command-line arguments and triggers the log writing."""
    parser = argparse.ArgumentParser(description="Write a JSON log entry from a Bash script.")
    parser.add_argument("--logfile", required=True, type=Path)
    parser.add_argument("--level", required=True)
    parser.add_argument("--message", required=True)
    parser.add_argument("--module", required=True)
    parser.add_argument("--func", required=True, dest="function")
    parser.add_argument("--lineno", required=True, type=int, dest="line")
    args = parser.parse_args()

    log_entry = LogEntry(**vars(args))
    write_bash_log_entry(log_entry)


if __name__ == "__main__":
    main()
