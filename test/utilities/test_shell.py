# ruff: noqa: S101, FBT001, SLF001
"""Tests for the shell utility module.

This test suite covers all features of the run, run_parallel, and
run_background functions, including success cases, error handling,
output modes, and edge cases.
"""

import logging
import subprocess
import time
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from scriptize.assets.python.utilities import shell


class TestRunFunction:
    """Tests for the main `run()` function."""

    def test_run_success_capture_mode(self) -> None:
        """Verify a successful command returns the correct result in capture mode."""
        result = shell.run("echo 'hello world'", output_mode="capture")
        assert result.returncode == 0
        assert result.stdout.strip() == "hello world"
        assert result.stderr == ""
        assert isinstance(result.pid, int)

    def test_run_failure_no_check(self) -> None:
        """Verify a failing command with check=False returns a non-zero exit code."""
        result = shell.run("ls non_existent_dir_xyz", check=False, output_mode="silent")
        assert result.returncode != 0
        assert "No such file or directory" in result.stderr

    def test_run_failure_check_raises(self) -> None:
        """Verify a failing command with check=True raises CalledProcessError."""
        with pytest.raises(subprocess.CalledProcessError) as exc_info:
            shell.run("ls non_existent_dir_xyz", output_mode="silent")
        assert "No such file or directory" in exc_info.value.stderr

    def test_run_command_not_found_raises(self) -> None:
        """Verify that a non-existent command raises FileNotFoundError."""
        with pytest.raises(FileNotFoundError, match="Command not found"):
            shell.run("non_existent_command_12345", output_mode="silent")

    def test_run_dry_run(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """Verify dry_run=True prints the command and returns a mock result."""
        mock_info = MagicMock()
        monkeypatch.setattr(shell.cli, "info", mock_info)
        result = shell.run("echo 'test'", dry_run=True)
        assert result.returncode == 0
        assert result.pid == -1
        mock_info.assert_called_once_with("[DRY RUN] Would execute: [bold]echo 'test'[/bold]")

    def test_run_with_cwd(self, tmp_path: Path) -> None:
        """Verify a command runs in the specified working directory."""
        (tmp_path / "file.txt").touch()
        result = shell.run("ls", cwd=tmp_path, output_mode="capture")
        assert "file.txt" in result.stdout

    def test_run_stream_mode_with_stdout_and_stderr(
        self,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        """Verify 'stream' mode prints both stdout and stderr."""
        command = "sh -c \"echo 'out' && >&2 echo 'err'\""
        shell.run(command, output_mode="stream", check=False)
        captured = capsys.readouterr()
        assert "out" in captured.out
        assert "err" in captured.err

    @patch("scriptize.assets.python.utilities.shell._frame_output")
    def test_run_frame_mode(self, mock_frame_output: MagicMock) -> None:
        """Verify that output_mode='frame' calls the framing helper function."""
        shell.run("echo 'framed'", output_mode="frame")
        mock_frame_output.assert_called_once()


class TestRunParallelFunction:
    """Tests for the `run_parallel()` function."""

    def test_run_parallel_command_not_found(self) -> None:
        """Verify parallel execution handles commands that are not found."""
        commands = ["non_existent_command_12345"]
        results = shell.run_parallel(commands, show_progress=False, show_summary=False)
        assert results[commands[0]].returncode == 1
        assert "Command not found" in results[commands[0]].stderr

    @patch("scriptize.assets.python.utilities.shell._display_parallel_results")
    @patch("scriptize.assets.python.utilities.shell.Progress")
    def test_run_parallel_visuals(
        self,
        mock_progress: MagicMock,
        mock_display: MagicMock,
    ) -> None:
        """Verify that visual components are called when enabled."""
        shell.run_parallel(["echo 'test'"], show_progress=True, show_summary=True)
        mock_progress.assert_called_once()
        mock_display.assert_called_once()


class TestRunBackgroundFunction:
    """Tests for the `run_background()` function."""

    def test_run_background_process(self) -> None:
        """Verify that a background process is started and can be managed."""
        start_time = time.monotonic()
        proc = shell.run_background("sleep 0.2")
        assert isinstance(proc, subprocess.Popen)
        max_startup_time = 0.1
        assert time.monotonic() - start_time < max_startup_time
        assert proc.poll() is None
        return_code = proc.wait(timeout=1)
        assert return_code == 0


class TestInternalHelpers:
    """Tests for internal helper functions."""

    @pytest.mark.parametrize(
        ("returncode", "stdout", "stderr", "should_call"),
        [
            (0, "output", "", True),
            (0, "", "", False),
            (1, "", "error", True),
            (1, "", "", False),
        ],
    )
    @patch("scriptize.assets.python.utilities.shell.cli")
    def test_frame_output(
        self,
        mock_cli: MagicMock,
        returncode: int,
        stdout: str,
        stderr: str,
        should_call: bool,
    ) -> None:
        """Verify _frame_output branches on different results."""
        result = shell.ShellResult(stdout, stderr, returncode, pid=123)
        shell._frame_output("command", result)
        if should_call:
            mock_cli.framed_box.assert_called_once()
        else:
            mock_cli.framed_box.assert_not_called()

    @patch("scriptize.assets.python.utilities.shell._frame_output")
    @patch("scriptize.assets.python.utilities.shell.cli")
    def test_display_parallel_results(
        self,
        mock_cli: MagicMock,
        mock_frame: MagicMock,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Verify _display_parallel_results prints summaries and respects log level."""
        results = {
            "success_cmd": shell.ShellResult("out", "", 0, 1),
            "fail_cmd": shell.ShellResult("", "err", 1, 2),
        }

        # Test that it prints when level is INFO
        monkeypatch.setattr(logging.getLogger(), "level", logging.INFO)
        shell._display_parallel_results(results)
        expected_call_count = 2
        assert mock_cli.console.print.call_count == expected_call_count
        assert mock_frame.call_count == expected_call_count

        # Test that it does nothing when level is WARNING
        mock_cli.reset_mock()
        mock_frame.reset_mock()
        monkeypatch.setattr(logging.getLogger(), "level", logging.WARNING)
        shell._display_parallel_results(results)
        mock_cli.console.print.assert_not_called()

    @patch("subprocess.Popen")
    def test_execute_process_handles_none_streams(self, mock_popen: MagicMock) -> None:
        """Verify _execute_process handles Popen objects with None for stdout/stderr."""
        mock_proc = MagicMock()
        mock_proc.stdout = None
        mock_proc.stderr = None
        mock_popen.return_value.__enter__.return_value = mock_proc

        shell._execute_process(["cmd"], should_stream_raw=True, cwd=None)
        mock_proc.wait.assert_called_once()
