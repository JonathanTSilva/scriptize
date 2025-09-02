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
from typing import Literal

from rich.progress import (
    BarColumn,
    Progress,
    SpinnerColumn,
    TextColumn,
    TimeElapsedColumn,
)

from scriptize.logger.log_manager import setup_logging

from . import cli


# A clear and structured way to return the results of a command.
@dataclass(frozen=True)
class ShellResult:
    """Represents the outcome of an executed shell command.

    Attributes:
        stdout (str): The standard output of the command, decoded as a string.
        stderr (str): The standard error of the command, decoded as a string.
        returncode (int): The exit code of the command.
        pid (int): The process ID of the executed command.
    """

    stdout: str
    stderr: str
    returncode: int
    pid: int


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


def _execute_process(args: list[str], *, should_stream_raw: bool, cwd: str | None) -> ShellResult:
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
        pid = proc.pid

    return ShellResult(
        stdout="".join(stdout_lines),
        stderr="".join(stderr_lines),
        returncode=returncode,
        pid=pid,
    )


def run(
    command: str,
    *,
    check: bool = True,
    output_mode: Literal["stream", "frame", "capture"] = "stream",
    dry_run: bool = False,
    cwd: str | None = None,
) -> ShellResult:
    """Executes an external command with enhanced control and output options.

    Args:
        command (str): The command to execute as a single string.
        check (bool): If True, raises `subprocess.CalledProcessError` on a
            non-zero exit code. Defaults to True.
        output_mode (Literal["stream", "frame", "capture"]): Defines how the
            command's output is handled.
            - "stream": (Default) Output is printed to the console in real-time.
            - "frame": Output is captured and displayed in a styled panel.
            - "capture": Output is captured but not displayed.
        dry_run (bool): If True, prints the command that would be executed
            instead of running it and returns a mock result.
        cwd (str | None): The working directory to run the command from.
            Defaults to the current directory.

    Returns:
        ShellResult: An object containing the command's output and status.

    Raises:
        subprocess.CalledProcessError: If `check` is True and the command fails.
        FileNotFoundError: If the command itself does not exist.
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
) -> dict[str, ShellResult]:
    """Executes multiple commands in parallel using a thread pool.

    Displays a rich progress bar while commands are running. Output from the
    commands themselves is suppressed to keep the progress bar clean, but the
    results (including stdout/stderr) are returned upon completion.

    Args:
        commands (list[str]): A list of command strings to execute.
        max_workers (int): The maximum number of threads to use for parallel
            execution.
        description (str): A description to display above the progress bar.

    Returns:
        dict[str, ShellResult]: A dictionary mapping each command to its ShellResult.
    """
    results: dict[str, ShellResult] = {}
    progress_columns = [
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
        TimeElapsedColumn(),
    ]

    with Progress(*progress_columns, transient=True) as progress:
        task = progress.add_task(description, total=len(commands))
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            future_to_cmd = {
                executor.submit(run, cmd, output_mode="capture", check=False): cmd
                for cmd in commands
            }
            for future in as_completed(future_to_cmd):
                cmd = future_to_cmd[future]
                try:
                    results[cmd] = future.result()
                except (subprocess.CalledProcessError, FileNotFoundError) as e:
                    results[cmd] = ShellResult(stdout="", stderr=str(e), returncode=1, pid=-1)
                progress.update(task, advance=1)
    return results


def run_background(command: str, *, cwd: str | None = None) -> subprocess.Popen:
    """Launches a command in the background.

    This function is useful for starting long-running services or tasks that
    the main script does not need to wait for. It immediately returns the
    process object for further management.

    Args:
        command (str): The command to execute.
        cwd (str | None): The working directory to run the command from.

    Returns:
        subprocess.Popen: The Popen object for the running process, allowing
            for interaction (e.g., `proc.wait()`, `proc.terminate()`).
    """
    args = shlex.split(command)
    # S603 is suppressed as shlex.split is used.
    return subprocess.Popen(args, cwd=cwd)  # noqa: S603


# *====[ Demonstration ]====*
def demo() -> None:
    """Demonstrates the various features of the shell utility module."""
    # TODO(@jonathantsilva): [#1] Migrate this demo to a test suite using pytest
    setup_logging(default_level="INFO")
    cli.section("ScriptizePy Shell Demo")

    # --- Successful Command with Framed Output ---
    cli.header("Successful Command (Framed Output)")
    try:
        result = run("ls -l", output_mode="frame")
        cli.success(f"Command finished with exit code {result.returncode}")
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        cli.error(f"Command failed: {e}")

    # --- Dry Run ---
    cli.header("Dry Run")
    run("tldr man", dry_run=True)

    # --- Failing Command (check=True) ---
    cli.header("Failing Command (check=True)")
    cli.info("This will raise a CalledProcessError.")
    try:
        # Framing the output of a failing command also works
        run("ls non_existent_directory", output_mode="frame")
    except subprocess.CalledProcessError:
        cli.error("Caught expected error!")

    # --- Parallel Execution ---
    cli.header("Parallel Execution")
    parallel_commands = [
        "sleep 1",
        "echo 'Task 2 Done'",
        "sleep 0.5",
        "ls -a",
        "echo 'Task 5 Done'",
        "this_command_fails",  # A failing command
    ]
    cli.info(f"Running {len(parallel_commands)} commands in parallel...")
    parallel_results = run_parallel(parallel_commands)
    _display_parallel_results(parallel_results)
    cli.success("Parallel execution finished.")

    # --- Background Process ---
    cli.header("Background Process")
    cli.info("Starting a background 'sleep' process...")
    proc = run_background("sleep 2")
    cli.info(f"Process started with PID: {proc.pid}. Script continues immediately.")
    cli.info("Waiting for background process to complete...")
    proc.wait()
    cli.success(f"Background process {proc.pid} has finished.")


if __name__ == "__main__":
    demo()
