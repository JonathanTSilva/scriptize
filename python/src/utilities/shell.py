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

from rich.progress import (
    BarColumn,
    Progress,
    SpinnerColumn,
    TextColumn,
    TimeElapsedColumn,
)


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
    """Displays the output of a command inside a styled panel.

    Args:
        command: The command that was executed.
        result: The ShellResult object from the command's execution.
    """
    from . import alerts

    if not result.stdout and not result.stderr:
        return

    if result.returncode == 0:
        panel_title = f"Output of: [bold]{command}[/bold]"
        content = f"[bright_black]{result.stdout.strip()}[/bright_black]"
        style = "bright_black"
    else:
        panel_title = f"Error from: [bold]{command}[/bold]"
        content = f"[light_pink3]{result.stderr.strip()}[/light_pink3]"
        style = "light_pink3"

    alerts.panel(content, title=panel_title, style=style, title_align="left")


def _display_parallel_results(results: dict[str, ShellResult]) -> None:
    """Displays the formatted results of a parallel execution.

    This output is only shown if the log level is INFO or DEBUG.

    Args:
        results: A dictionary of commands and their ShellResult.
    """
    from . import alerts

    # Only display these detailed results in verbose logging modes.
    if logging.getLogger().getEffectiveLevel() > logging.INFO:
        return

    for cmd, res in results.items():
        # Use console.print for custom formatting to differentiate sub-tasks
        if res.returncode == 0:
            alerts.console.print(f" ╰──▹ [green]✔[/] '{cmd}'")
            # Use the helper to frame the output
            _frame_output(cmd, res)
        else:
            alerts.console.print(f" ╰──▹ [red]✖[/] '{cmd}'")
            # Use the helper to frame the error output
            _frame_output(cmd, res)


def run(
    command: str,
    *,
    check: bool = True,
    dry_run: bool = False,
    stream_output: bool = True,
    frame_output: bool = False,
    cwd: str | None = None,
) -> ShellResult:
    """Executes an external command with enhanced control and real-time output.

    Args:
        command: The command to execute as a single string.
        check: If True, raises `subprocess.CalledProcessError` if the
               command returns a non-zero exit code. Defaults to True.
        dry_run: If True, prints the command that would be executed
                 instead of running it, and returns a mock result.
        stream_output: If True, streams the command's stdout and stderr
                       to the console in real-time. This is ignored if
                       `frame_output` is True.
        frame_output: If True, captures the command's output and displays
                      it inside a styled panel upon completion, but only
                      if the logging level is set to DEBUG.
        cwd: The working directory to run the command from. Defaults to
             the current directory.

    Returns:
        A ShellResult object containing the command's output and status.

    Raises:
        subprocess.CalledProcessError: If `check` is True and the command fails.
        FileNotFoundError: If the command itself does not exist.
    """
    # Lazily import alerts to avoid circular dependency issues at module level
    from . import alerts

    if dry_run:
        alerts.info(f"[DRY RUN] Would execute: [bold]{command}[/bold]")
        return ShellResult(stdout="", stderr="", returncode=0, pid=-1)

    # If framing is requested, we must capture output, so raw streaming is disabled.
    should_stream_raw = stream_output and not frame_output

    args = shlex.split(command)
    stdout_lines: list[str] = []
    stderr_lines: list[str] = []

    try:
        with subprocess.Popen(
            args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            cwd=cwd,
        ) as proc:
            # Stream stdout
            if proc.stdout:
                for line in proc.stdout:
                    if should_stream_raw:
                        sys.stdout.write(line)
                        sys.stdout.flush()
                    stdout_lines.append(line)

            # Stream stderr
            if proc.stderr:
                for line in proc.stderr:
                    if should_stream_raw:
                        sys.stderr.write(line)
                        sys.stderr.flush()
                    stderr_lines.append(line)

            proc.wait()
            returncode = proc.returncode
            pid = proc.pid

        result = ShellResult(
            stdout="".join(stdout_lines),
            stderr="".join(stderr_lines),
            returncode=returncode,
            pid=pid,
        )

        if should_stream_raw and (result.stdout or result.stderr):
            alerts.console.line()

        if frame_output:
            _frame_output(command, result)

        if check and returncode != 0:
            raise subprocess.CalledProcessError(
                returncode,
                cmd=args,
                output=result.stdout,
                stderr=result.stderr,
            )

        return result

    except FileNotFoundError:
        raise FileNotFoundError(f"Command not found: {args[0]}") from None


def run_parallel(
    commands: list[str],
    *,
    max_workers: int = 4,
    description: str = "Running commands...",
) -> dict[str, ShellResult]:
    """Executes multiple commands in parallel using a thread pool.

    Displays a progress bar and returns a dictionary of results. Output from
    the commands themselves is suppressed to keep the progress bar clean.

    Args:
        commands: A list of command strings to execute.
        max_workers: The maximum number of threads to use.
        description: A description to display above the progress bar.

    Returns:
        A dictionary mapping each command to its ShellResult.
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
                executor.submit(run, cmd, stream_output=False, check=False): cmd for cmd in commands
            }
            for future in as_completed(future_to_cmd):
                cmd = future_to_cmd[future]
                try:
                    results[cmd] = future.result()
                except Exception as e:
                    # Store the exception as a mock result
                    results[cmd] = ShellResult(stdout="", stderr=str(e), returncode=1, pid=-1)
                progress.update(task, advance=1)
    return results


def run_background(command: str, *, cwd: str | None = None) -> subprocess.Popen:
    """Launches a command in the background and returns the Popen object.

    This is useful for starting long-running services or tasks that the
    main script does not need to wait for.

    Args:
        command: The command to execute.
        cwd: The working directory to run the command from.

    Returns:
        The `subprocess.Popen` object for the running process.
    """
    args = shlex.split(command)
    return subprocess.Popen(args, cwd=cwd)


# ==============================================================================
# Demonstration
# ==============================================================================

if __name__ == "__main__":
    # TODO(@jonathantsilva): [#1] Migrate this demo to a test suite using pytest (#3)
    try:
        from . import alerts
    except ImportError:
        sys.exit("This demo requires the 'alerts' module to be available.")

    alerts.setup_logging(level="DEBUG")
    alerts.section("ScriptizePy Shell Demo")

    # --- Successful Command with Framed Output ---
    alerts.header("Successful Command (Framed Output)")
    try:
        result = run("ls -l", frame_output=True)
        alerts.success(f"Command finished with exit code {result.returncode}")
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        alerts.error(f"Command failed: {e}")

    # --- Dry Run ---
    alerts.header("Dry Run")
    run("tldr man", dry_run=True)

    # --- Failing Command (check=True) ---
    alerts.header("Failing Command (check=True)")
    alerts.info("This will raise a CalledProcessError.")
    try:
        # Framing the output of a failing command also works
        run("ls non_existent_directory", frame_output=True)
    except subprocess.CalledProcessError:
        alerts.error("Caught expected error!")

    # --- Parallel Execution ---
    alerts.header("Parallel Execution")
    parallel_commands = [
        "sleep 1",
        "echo 'Task 2 Done'",
        "sleep 0.5",
        "ls -a",
        "echo 'Task 5 Done'",
        "this_command_fails",  # A failing command
    ]
    alerts.info(f"Running {len(parallel_commands)} commands in parallel...")
    parallel_results = run_parallel(parallel_commands)
    _display_parallel_results(parallel_results)
    alerts.success("Parallel execution finished.")

    # --- Background Process ---
    alerts.header("Background Process")
    alerts.info("Starting a background 'sleep' process...")
    proc = run_background("sleep 2")
    alerts.info(f"Process started with PID: {proc.pid}. Script continues immediately.")
    alerts.info("Waiting for background process to complete...")
    proc.wait()
    alerts.success(f"Background process {proc.pid} has finished.")
