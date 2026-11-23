# ruff: noqa: S101, PLR2004
"""Tests for the Bash-to-JSON logging bridge."""

import json
import runpy
import sys
from pathlib import Path

import pytest

from scriptize.logger import bash_logger
from scriptize.logger.bash_logger import LogEntry


def _entry(logfile: Path, **overrides: object) -> LogEntry:
    fields: dict[str, object] = {
        "logfile": logfile,
        "level": "info",
        "message": "hello",
        "module": "demo.sh",
        "function": "main",
        "line": 7,
    }
    fields.update(overrides)
    return LogEntry(**fields)  # type: ignore[arg-type]


class TestWriteBashLogEntry:
    """Tests for `write_bash_log_entry()`."""

    def test_appends_json_line(self, tmp_path: Path) -> None:
        """Each call appends one JSON object and uppercases the level."""
        logfile = tmp_path / "nested" / "out.jsonl"

        bash_logger.write_bash_log_entry(_entry(logfile))
        bash_logger.write_bash_log_entry(_entry(logfile, message="again"))

        lines = logfile.read_text(encoding="utf-8").splitlines()
        assert len(lines) == 2
        first = json.loads(lines[0])
        assert first["level"] == "INFO"
        assert first["message"] == "hello"
        assert first["module"] == "demo.sh"
        assert first["function"] == "main"
        assert first["line"] == 7
        assert first["source"] == "bash"
        assert "timestamp" in first
        assert json.loads(lines[1])["message"] == "again"

    def test_unwritable_logfile_exits_with_error(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        """An OS error is reported on stderr and exits with status 1."""
        blocker = tmp_path / "file"
        blocker.write_text("x", encoding="utf-8")

        with pytest.raises(SystemExit) as exc_info:
            bash_logger.write_bash_log_entry(_entry(blocker / "out.jsonl"))

        assert exc_info.value.code == 1
        assert "FATAL: Could not write to log file" in capsys.readouterr().err


class TestMain:
    """Tests for the command-line entry point."""

    ARGS = (
        "--level",
        "warning",
        "--message",
        "from bash",
        "--module",
        "m.sh",
        "--func",
        "fn",
        "--lineno",
        "42",
    )

    def test_main_parses_arguments(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        """Arguments are mapped onto a log entry and written."""
        logfile = tmp_path / "cli.jsonl"
        monkeypatch.setattr(sys, "argv", ["bash_logger", "--logfile", str(logfile), *self.ARGS])

        bash_logger.main()

        record = json.loads(logfile.read_text(encoding="utf-8"))
        assert record["level"] == "WARNING"
        assert record["line"] == 42
        assert record["function"] == "fn"

    def test_missing_arguments_exit(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """Argparse rejects a call without the required options."""
        monkeypatch.setattr(sys, "argv", ["bash_logger"])
        with pytest.raises(SystemExit) as exc_info:
            bash_logger.main()
        assert exc_info.value.code == 2

    def test_runs_as_script(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        """Executing the module as `__main__` calls `main()`."""
        logfile = tmp_path / "script.jsonl"
        monkeypatch.setattr(sys, "argv", ["bash_logger", "--logfile", str(logfile), *self.ARGS])

        runpy.run_path(str(Path(bash_logger.__file__)), run_name="__main__")

        assert json.loads(logfile.read_text(encoding="utf-8"))["message"] == "from bash"
