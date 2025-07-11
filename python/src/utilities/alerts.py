"""A standardized module for displaying beautiful and consistent CLI alerts.

This module uses the 'rich' library to provide a rich set of pre-configured
UI components, including colored logging, user prompts, headers, and spinners.
The goal is to provide a single, easy-to-use interface for all CLI output.
"""

import logging
import sys
from collections.abc import Generator
from contextlib import contextmanager
from shutil import get_terminal_size

import typer
from rich.console import Console
from rich.live import Live
from rich.logging import RichHandler
from rich.panel import Panel
from rich.prompt import Confirm, Prompt
from rich.spinner import Spinner
from rich.text import Text

# Platform-specific imports
try:
    import termios
    import tty  # For Unix-like systems
except ImportError:
    import msvcrt  # For Windows

# ==================================================================================================
# Core Instances & Types
# ==================================================================================================

# A single, shared Console instance for the entire application.
# stderr is used by default to separate primary output (stdout) from logs/alerts.
console = Console(stderr=True, highlight=False)

# A dedicated logger for this module. Using a named logger is a best practice.
logger = logging.getLogger(__name__)

# ==================================================================================================
# Logging Configuration
# ==================================================================================================


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

    # Clear all handlers if already configured
    root_logger = logging.getLogger()
    if root_logger.hasHandlers():
        root_logger.handlers.clear()

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


# ==================================================================================================
# Primary Alert Functions
# ==================================================================================================


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
    logger.debug("[bold magenta]\\[DEBUG][/bold magenta] %s", message)


# ==================================================================================================
# UI & Structural Elements
# ==================================================================================================


def section(title: str, style: str = "bold magenta") -> None:
    """Displays a major section break with a prominent, centered title.

    This is designed to be more emphatic than a header, used for separating
    major parts of the application's output.

    Args:
        title: The title of the section.
        style: The color and style of the panel's border and title.
    """
    console.print()
    console.print(
        Panel(
            Text(f" {title.upper()} ", style="white", justify="center"),
            border_style=style,
            expand=True,
        )
    )


def header(title: str, style: str = "bold blue") -> None:
    """Displays a prominent, centered header using a Rich Rule."""
    prefix = "╭───⦗  "
    suffix = "  ⦘"
    end_marker = "╮"

    full_title = f"{prefix}{title}{suffix}"
    term_width = get_terminal_size().columns
    rule_fill_len = max(0, term_width - len(full_title) - len(end_marker))
    rule_fill = "─" * rule_fill_len

    line = f"{full_title}{rule_fill}{end_marker}"
    console.print()
    console.print(Text(line, style=style))


def panel(
    content: str,
    *,
    title: str | None = None,
    title_align: str | None = "center",
    style: str = "cyan",
    padding: tuple[int, int] = (1, 2),
) -> None:
    """Displays content inside a visually distinct panel.

    Args:
        content: The main text content for the panel.
        title: An optional title for the panel.
        title_align: The alignment of the title (e.g., "left", "center", "right").
        style: The border color of the panel.
        padding: Vertical and horizontal padding.
    """
    panel_title = Text.from_markup(title) if title else None
    console.print(
        Panel(
            Text.from_markup(content),
            title=panel_title,
            title_align=title_align,
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


# ==================================================================================================
# Interactive Prompts
# ==================================================================================================


def _get_key_windows() -> str:
    """Gets a single key press on Windows."""
    key = msvcrt.getch()
    if key == b"\r":
        return "ENTER"
    if key == b"\x03":
        raise KeyboardInterrupt
    if key in {b"\xe0", b"\x00"}:  # Arrow keys start with a prefix
        key = msvcrt.getch()
        if key == b"H":
            return "UP"
        if key == b"P":
            return "DOWN"
    return ""  # Ignore other keys


def _get_key_unix() -> str:
    """Gets a single key press on Unix-like systems."""
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        char = sys.stdin.read(1)
        if char == "\r":
            return "ENTER"
        if char == "\x03":  # Ctrl+C
            raise KeyboardInterrupt
        if char == "\x1b":  # Arrow keys start with an escape sequence
            seq = sys.stdin.read(2)
            if seq == "[A":
                return "UP"
            if seq == "[B":
                return "DOWN"
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
    return ""  # Ignore other keys


def _get_key() -> str:
    """Gets a single key press, platform-independently."""
    if "msvcrt" in sys.modules:
        return _get_key_windows()
    return _get_key_unix()


def selection[T](message: str, choices: list[T]) -> T:
    """Displays an interactive, navigable selection menu.

    Args:
        message: The prompt message to display above the choices.
        choices: A list of options for the user to choose from.

    Returns:
        The option selected by the user.
    """
    if not choices:
        error_msg = "Cannot make a selection from an empty list of choices."
        raise ValueError(error_msg)

    current_index = 0
    prompt_text = Text.from_markup(f"[bold yellow]\\[?][/bold yellow] {message}\n")

    def generate_menu() -> Text:
        """Generates the Rich Text object for the current menu state."""
        menu = Text()
        for i, choice in enumerate(choices):
            line_prefix = "  "
            if i == current_index:
                menu.append(f"{line_prefix}» ", style="bold orange1")
                menu.append(f"{choice}\n", style="bold orange1")
            else:
                menu.append(f"{line_prefix}  {choice}\n", style="dim")
        return prompt_text + menu

    try:
        with Live(generate_menu(), console=console, auto_refresh=False, transient=True) as live:
            while True:
                key = _get_key()
                if key == "UP":
                    current_index = (current_index - 1) % len(choices)
                elif key == "DOWN":
                    current_index = (current_index + 1) % len(choices)
                elif key == "ENTER":
                    break
                live.update(generate_menu(), refresh=True)
    except KeyboardInterrupt:
        # Ensure the cursor is shown and exit gracefully if user presses Ctrl+C
        console.show_cursor(show=True)
        fatal("User cancelled operation.", exit_code=0)

    selected_choice = choices[current_index]
    success(f"Selected: {selected_choice}")
    return selected_choice


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
    prompt_text = Text.from_markup(f"[bold yellow]\\[?][/bold yellow] {message}")
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
    prompt_text = Text.from_markup(f"[bold yellow]\\[?][/bold yellow] {message}")
    return Confirm.ask(prompt_text, default=default, console=console)


# ==================================================================================================
# Demonstration
# ==================================================================================================

if __name__ == "__main__":
    # TODO(jonathantsilva): [#1] Migrate this demo tests to a test suite using pytest
    # TODO(jonathantsilva): Create a logfile scheme with rotation and retention (timestamp, etc.)
    # This block allows you to run `python -m src.scriptizepy.alerts` to see a demo.
    import time

    def _simulate_failing_task() -> None:
        """Raise an exception to demonstrate error handling."""
        # Assign error message to a variable before raising
        error_msg = "Something went wrong during the simulation!"
        raise ValueError(error_msg)

    # --- LOGGING DEMO ---
    section("Logging Demo")
    header("Log Level: INFO")
    setup_logging(level="INFO")
    info("This is an informational message.")
    success("The operation completed successfully.")
    warning("Something might be wrong, please check.")
    error("A recoverable error occurred.")
    debug("This debug message will NOT be visible.")

    header("Log Level: DEBUG")
    setup_logging(level="DEBUG")
    debug("This debug message IS now visible.")

    # --- UI ELEMENTS DEMO ---
    section("UI Elements Demo")
    header("Standard Header")
    panel(
        "This is some important information that needs to stand out.\n"
        "You can put multiple lines of text in here.",
        title="Important Notice",
    )

    # --- SPINNER DEMO ---
    section("Spinner Demo")
    try:
        with spinner("Simulating a long-running task..."):
            time.sleep(5)
        success("Task finished.")

        with spinner("Another task that fails...", style="magenta"):
            time.sleep(5)
            _simulate_failing_task()
    except ValueError as e:
        error(f"The task failed: {e}")

    # --- INTERACTIVE DEMO ---
    section("Interactive Demo")
    try:
        name = prompt("What is your name?", default="Guest")
        info(f"Hello, {name}!")

        # --- SELECTION MENU DEMO ---
        project_type = selection(
            "Which project would you like to start?",
            ["React App", "Vue App", "Python CLI", "Go Microservice"],
        )
        if confirm(f"You chose '{project_type}'. Do you want to continue?", default=False):
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
