"""A robust, user-friendly utility for executing external shell commands.

This module provides a powerful wrapper around Python's `subprocess` module,
offering features like real-time output streaming, parallel execution with
progress bars, background process management, and clear, predictable error
handling.
"""

import logging
import shlex
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

from rich.progress import (
    BarColumn,
    Progress,
    SpinnerColumn,
    TaskID,
    TextColumn,
    TimeElapsedColumn,
)

from . import cli


# A clear and structured way to return the results of a command.
@dataclass(frozen=True)
class ShellResult:
    """Represents the outcome of an executed shell command.

    Attributes:
        stdout: The standard output of the command, decoded as a string.
        stderr: The standard error of the command, decoded as a string.
        returncode: The exit code of the command.
        pid: The process ID of the executed command.
    """

    stdout: str
    stderr: str
    returncode: int
    pid: int


def run(
    command: str,
    *,
    check: bool = True,
    output_mode: Literal["stream", "frame", "capture", "silent"] = "stream",
    dry_run: bool = False,
    cwd: str | Path | None = None,
) -> ShellResult:
    r"""Executes an external command with enhanced control and output options.

    Args:
        command: The command to execute as a single string.
        check: If True, raises `subprocess.CalledProcessError` on a non-zero
            exit code. Defaults to True.
        output_mode: Defines how the command's output is handled.
            - "stream": (Default) Output is printed to the console in real-time.
            - "frame": Output is captured and displayed in a styled panel.
            - "capture": Output is captured but not displayed.
            - "silent": Output is captured but not displayed, and no error
              messages are printed by this function's helpers.
        dry_run: If True, prints the command that would be executed
            instead of running it and returns a mock result.
        cwd: The working directory to run the command from. Defaults to the
            current directory.

    Returns:
        An object containing the command's output and status.

    Raises:
        subprocess.CalledProcessError: If `check` is True and the command fails.
        FileNotFoundError: If the command itself does not exist.

    Examples:
        >>> # 1. Successful command with captured output
        >>> result = run("echo 'Hello, World!'", output_mode="capture")
        >>> result.stdout.strip()
        'Hello, World!'

        >>> # 2. Failing command run silently for testing
        >>> result = run("ls non_existent_dir_12345", check=False, output_mode="silent")
        >>> result.returncode != 0
        True
        >>> "No such file or directory" in result.stderr
        True

        >>> # 3. Failing command with check=True (raises an exception)
        >>> import subprocess
        >>> try:
        ...     run("ls non_existent_dir_12345", output_mode="silent")
        ... except subprocess.CalledProcessError as e:
        ...     print(f"Caught expected error with code {e.returncode}")
        Caught expected error with code ...

        >>> # 4. Dry run mode
        >>> result = run("echo 'This will not run'", dry_run=True)
        >>> result.returncode
        0

        >>> # 5. Run in a specific directory (cwd)
        >>> import tempfile
        >>> from pathlib import Path
        >>> with tempfile.TemporaryDirectory() as tempdir:
        ...     _ = (Path(tempdir) / "test.txt").touch()
        ...     result = run("ls", cwd=tempdir, output_mode="capture")
        ...     "test.txt" in result.stdout
        True
    """
    if dry_run:
        return _handle_dry_run(command)

    should_stream_raw = output_mode == "stream"
    should_frame = output_mode == "frame"
    args = shlex.split(command)

    try:
        result = _execute_process(args, should_stream_raw=should_stream_raw, cwd=cwd)
    except FileNotFoundError:
        error_msg = f"Command not found: {args[0]}"
        raise FileNotFoundError(error_msg) from None
    else:
        if should_stream_raw and (result.stdout or result.stderr):
            cli.console.line()
        if should_frame:
            _frame_output(command, result)
        if check and result.returncode != 0:
            raise subprocess.CalledProcessError(
                result.returncode,
                cmd=args,
                output=result.stdout,
                stderr=result.stderr,
            )
        return result


def run_parallel(
    commands: list[str],
    *,
    max_workers: int = 4,
    description: str = "Running commands...",
    show_progress: bool = True,
    show_summary: bool = True,
) -> dict[str, ShellResult]:
    r"""Executes multiple commands in parallel.

    Args:
        commands: A list of command strings to execute.
        max_workers: The maximum number of threads to use.
        description: A description to display above the progress bar.
        show_progress: If True, displays a rich progress bar.
        show_summary: If True, displays a summary of results after completion.

    Returns:
        A dictionary mapping each command to its `ShellResult`.

    Examples:
        >>> cmds = ["echo 'first'", "echo 'second'", "this_command_fails"]
        >>> # Run silently for the test by disabling visual components
        >>> results = run_parallel(cmds, show_progress=False, show_summary=False)
        >>> sorted(results.keys())
        ["echo 'first'", "echo 'second'", 'this_command_fails']
        >>> results["echo 'first'"].stdout.strip()
        'first'
        >>> results["this_command_fails"].returncode != 0
        True
    """
    results: dict[str, ShellResult] = {}

    def _run_tasks(progress: Progress | None = None, task: TaskID | None = None) -> None:
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            future_to_cmd = {
                executor.submit(run, cmd, output_mode="capture", check=False): cmd
                for cmd in commands
            }
            for future in as_completed(future_to_cmd):
                cmd = future_to_cmd[future]
                try:
                    results[cmd] = future.result()
                except FileNotFoundError as e:
                    results[cmd] = ShellResult(stdout="", stderr=str(e), returncode=1, pid=-1)
                if progress and task:
                    progress.update(task, advance=1)

    if show_progress:
        progress_columns = [
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
            TimeElapsedColumn(),
        ]
        with Progress(*progress_columns, transient=True) as progress:
            task = progress.add_task(description, total=len(commands))
            _run_tasks(progress, task)
    else:
        _run_tasks()

    if show_summary:
        _display_parallel_results(results)
    return results


def run_background(command: str, *, cwd: str | None = None) -> subprocess.Popen:
    """Launches a command in the background and returns the process object.

    Args:
        command: The command to execute.
        cwd: The working directory to run the command from.

    Returns:
        The `subprocess.Popen` object for the running process.

    Examples:
        >>> import time
        >>> start_time = time.monotonic()
        >>> proc = run_background("sleep 0.2")
        >>> # The script continues immediately, without waiting for sleep
        >>> duration = time.monotonic() - start_time
        >>> duration < 0.1
        True
        >>> return_code = proc.wait()  # Clean up the process
        >>> return_code
        0
    """
    args = shlex.split(command)
    # S603 is suppressed as shlex.split is used.
    return subprocess.Popen(args, cwd=cwd)  # noqa: S603


def _frame_output(command: str, result: ShellResult) -> None:
    """Displays the output of a command by calling alerts.framed_box."""
    if result.returncode == 0:
        if not result.stdout:
            return
        cli.framed_box(
            result.stdout.strip(),
            title=f"Output of: [bold]{command}[/bold]",
            style="info",
        )
    else:
        if not result.stderr:
            return
        cli.framed_box(
            result.stderr.strip(),
            title=f"Error from: [bold]{command}[/bold]",
            style="error",
        )


def _display_parallel_results(results: dict[str, ShellResult]) -> None:
    """Displays the formatted results of a parallel execution.

    This function iterates through the results of `run_parallel` and prints
    a formatted summary for each command, indicating success or failure.
    Output is only shown if the log level is INFO or DEBUG.

    Args:
        results (dict[str, ShellResult]): A dictionary mapping each command
            string to its corresponding ShellResult.
    """
    if logging.getLogger().getEffectiveLevel() > logging.INFO:
        return

    for cmd, res in results.items():
        if res.returncode == 0:
            cli.console.print(f" ╰──▹ [green]✔[/] '{cmd}'")
            _frame_output(cmd, res)
        else:
            cli.console.print(f" ╰──▹ [red]✖[/] '{cmd}'")
            _frame_output(cmd, res)


def _handle_dry_run(command: str) -> ShellResult:
    """Handles the logic for a dry run by printing the command and returning a mock result.

    Args:
        command (str): The command that would have been executed.

    Returns:
        ShellResult: A mock result object with a return code of 0.
    """
    cli.info(f"[DRY RUN] Would execute: [bold]{command}[/bold]")
    return ShellResult(stdout="", stderr="", returncode=0, pid=-1)


def _execute_process(
    args: list[str], *, should_stream_raw: bool, cwd: str | Path | None
) -> ShellResult:
    """Executes the given command arguments in a subprocess.

    Streams stdout and stderr in real-time if requested and captures all output
    for the final result.

    Args:
        args (list[str]): The command and its arguments as a list.
        should_stream_raw (bool): If True, streams output directly to sys.stdout/stderr.
        cwd (str | None): The working directory to run the command from.

    Returns:
        ShellResult: An object containing the captured stdout, stderr, return code,
            and process ID.
    """
    stdout_lines: list[str] = []
    stderr_lines: list[str] = []

    # S603 is suppressed as shlex.split is used, which is the recommended
    # practice for safely handling command strings.
    with subprocess.Popen(  # noqa: S603
        args,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        cwd=cwd,
    ) as proc:
        pid = proc.pid
        if proc.stdout:
            for line in proc.stdout:
                if should_stream_raw:
                    sys.stdout.write(line)
                    sys.stdout.flush()
                stdout_lines.append(line)
        if proc.stderr:
            for line in proc.stderr:
                if should_stream_raw:
                    sys.stderr.write(line)
                    sys.stderr.flush()
                stderr_lines.append(line)
        proc.wait()
        returncode = proc.returncode

    return ShellResult(
        stdout="".join(stdout_lines),
        stderr="".join(stderr_lines),
        returncode=returncode,
        pid=pid,
    )
