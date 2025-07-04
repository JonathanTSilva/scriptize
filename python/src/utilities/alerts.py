"""A standardized module for displaying beautiful and consistent CLI alerts.

This module uses the 'rich' library to provide a rich set of pre-configured
UI components, including colored logging, user prompts, headers, and spinners.
The goal is to provide a single, easy-to-use interface for all CLI output.
"""

import logging
from collections.abc import Generator
from contextlib import contextmanager

import typer
from rich.console import Console
from rich.logging import RichHandler
from rich.panel import Panel
from rich.prompt import Confirm, Prompt
from rich.rule import Rule
from rich.spinner import Spinner
from rich.text import Text

# ==============================================================================
# Core Instances & Types
# ==============================================================================

# A single, shared Console instance for the entire application.
# stderr is used by default to separate primary output (stdout) from logs/alerts.
console = Console(stderr=True, highlight=False)

# A dedicated logger for this module. Using a named logger is a best practice.
logger = logging.getLogger(__name__)

# ==============================================================================
# Logging Configuration
# ==============================================================================


def setup_logging(level: str = "INFO") -> None:
    """Configure the root logger for beautiful, colored, and leveled output.

    This function sets up a RichHandler, which directs Python's standard
    logging output to the rich Console with beautiful formatting.

    Args:
        level: The minimum logging level to display (e.g., "DEBUG",
               "INFO", "WARNING", "ERROR"). Defaults to "INFO".
    """
    log_level = level.upper()
    try:
        # Ensure the log level is a valid one
        logging.getLevelName(log_level)
    except (AttributeError, ValueError) as e:
        # Create the error message separately to avoid complex f-strings in exceptions
        error_message = f"Invalid log level: {log_level}"
        raise ValueError(error_message) from e

    # Configure the handler
    handler = RichHandler(
        console=console,
        show_time=False,
        show_path=False,
        show_level=False,
        rich_tracebacks=True,
        markup=True,
    )

    # Configure the root logger
    logging.basicConfig(
        level=log_level,
        format="%(message)s",
        datefmt="[%X]",
        handlers=[handler],
    )


# ==============================================================================
# Primary Alert Functions
# ==============================================================================


# ==============================================================================
# Primary Alert Functions
# ==============================================================================


def info(message: str) -> None:
    """Logs an informational message."""
    logger.info("[bold cyan]\\[*][/bold cyan] %s", message)


def success(message: str) -> None:
    """Logs a success message."""
    logger.info("[bold green]\\[+][/bold green] %s", message)


def warning(message: str) -> None:
    """Logs a warning message."""
    logger.warning("[bold yellow]\\[!][/bold yellow] %s", message)


def error(message: str) -> None:
    """Logs an error message."""
    logger.error("[bold red]\\[x][/bold red] %s", message)


def fatal(message: str, exit_code: int = 1) -> None:
    """Logs a critical error message and exits the application."""
    logger.critical("[bold red]\\[!][/bold red] FATAL: %s", message)
    raise typer.Exit(code=exit_code)


def debug(message: str) -> None:
    """Logs a debug message, only visible when log level is set to DEBUG."""
    logger.debug("[bold magenta][DEBUG][/bold magenta] %s", message)


# ==============================================================================
# UI & Structural Elements
# ==============================================================================


def header(title: str, style: str = "bold blue") -> None:
    """Displays a prominent, centered header using a Rich Rule."""
    console.print(Rule(Text(f" {title} ", style=style), style=style))


def panel(
    content: str,
    *,
    title: str | None = None,
    style: str = "cyan",
    padding: tuple[int, int] = (1, 2),
) -> None:
    """Displays content inside a visually distinct panel.

    Args:
        content: The main text content for the panel.
        title: An optional title for the panel.
        style: The border color of the panel.
        padding: Vertical and horizontal padding.
    """
    panel_title = Text(title, style=f"bold {style}") if title else None
    console.print(
        Panel(
            Text(content, style="white"),
            title=panel_title,
            border_style=style,
            padding=padding,
            expand=True,
        )
    )


@contextmanager
def spinner(text: str = "Processing...", *, style: str = "cyan") -> Generator[Spinner]:
    """A context manager that displays a spinner for long-running operations.

    Example:
        with alerts.spinner("Doing hard work..."):
            time.sleep(3)

    Args:
        text: The text to display next to the spinner.
        style: The color of the spinner.
    """
    with console.status(Text(text, style=style), spinner="dots") as status:
        yield status


# ==============================================================================
# Interactive Prompts
# ==============================================================================


def prompt[T](
    message: str,
    *,
    default: T | None = None,
    secret: bool = False,
    choices: list[str] | None = None,
) -> T:
    """Prompts the user for input with a standardized style.

    Args:
        message: The message to display to the user.
        default: A default value if the user enters nothing.
        secret: If True, the input will be masked.
        choices: A list of valid choices.

    Returns:
        The value entered by the user.
    """
    prompt_text = Text.from_markup(f"[bold yellow][?][/bold yellow] {message}")
    return Prompt.ask(
        prompt_text,
        password=secret,
        default=default,
        choices=choices,
        console=console,
    )


def confirm(message: str, *, default: bool = False) -> bool:
    """Asks the user for a yes/no confirmation.

    Args:
        message: The confirmation question to ask.
        default: The default result if the user just presses Enter.

    Returns:
        True if the user confirms, False otherwise.
    """
    prompt_text = Text.from_markup(f"[bold yellow][?][/bold yellow] {message}")
    return Confirm.ask(prompt_text, default=default, console=console)


# ==============================================================================
# Demonstration
# ==============================================================================

if __name__ == "__main__":
    # This block allows you to run `python -m src.scriptizepy.alerts` to see a demo.
    import time

    def _simulate_failing_task() -> None:
        """Raise an exception to demonstrate error handling."""
        # Assign error message to a variable before raising
        error_msg = "Something went wrong during the simulation!"
        raise ValueError(error_msg)

    # --- LOGGING DEMO ---
    header("Logging Demo (Level: INFO)")
    setup_logging(level="INFO")
    info("This is an informational message.")
    success("The operation completed successfully.")
    warning("Something might be wrong, please check.")
    error("A recoverable error occurred.")
    debug("This debug message will NOT be visible.")
    console.print()

    header("Logging Demo (Level: DEBUG)")
    setup_logging(level="DEBUG")
    debug("This debug message IS now visible.")
    console.print()

    # --- UI ELEMENTS DEMO ---
    header("UI Elements Demo")
    panel(
        "This is some important information that needs to stand out.\n"
        "You can put multiple lines of text in here.",
        title="Important Notice",
    )
    console.print()

    # --- SPINNER DEMO ---
    try:
        with spinner("Simulating a long-running task..."):
            time.sleep(10)
        success("Task finished.")
        console.print()

        with spinner("Another task that fails...", style="magenta"):
            time.sleep(10)
            _simulate_failing_task()
    except ValueError as e:
        error(f"The task failed: {e}")
    console.print()

    # --- INTERACTIVE DEMO ---
    header("Interactive Demo")
    try:
        name = prompt("What is your name?", default="Guest")
        info(f"Hello, {name}!")

        if confirm("Do you want to continue?", default=False):
            success("Great, let's proceed!")
        else:
            warning("Okay, stopping here.")

        # --- FATAL ERROR DEMO ---
        if confirm("Do you want to test a fatal error?", default=False):
            fatal("This is a simulated fatal error. The script will now exit.")

    except (KeyboardInterrupt, EOFError):
        # Handle Ctrl+C or Ctrl+D gracefully
        fatal("User cancelled operation.", exit_code=0)

    success("Demo finished successfully.")
