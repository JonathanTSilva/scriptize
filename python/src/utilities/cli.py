"""A standardized module for displaying beautiful and consistent CLI alerts.

This module uses the 'rich' library to provide a rich set of pre-configured
UI components, including colored logging, user prompts, headers, and spinners.
The goal is to provide a single, easy-to-use interface for all CLI output.
"""

import logging
import sys
from collections.abc import Iterator
from contextlib import contextmanager
from enum import Enum
from pathlib import Path
from shutil import get_terminal_size
from typing import Any, Literal

import typer
from rich.console import Console, RenderableType
from rich.live import Live
from rich.panel import Panel
from rich.prompt import Confirm, Prompt
from rich.text import Text
from rich.traceback import Traceback

# Platform-specific imports for single-key press detection
try:
    import termios
    import tty  # For Unix-like systems
except ImportError:
    import msvcrt  # For Windows

from .log_manager import setup_logging

# *====[ Core Instances & Types ]====*

# A single, shared Console instance for the entire application.
# stderr is used by default to separate primary output (stdout) from alerts.
console = Console(stderr=True, highlight=False)

# A dedicated logger for this module. Using a named logger is a best practice.
_logger = logging.getLogger(__name__)


class _AlertStyles(str, Enum):
    """Encapsulates the rich markup for different alert styles."""

    INFO = "[bold cyan]\\[*][/bold cyan]"
    SUCCESS = "[bold green]\\[+][/bold green]"
    WARNING = "[bold yellow]\\[!][/bold yellow]"
    ERROR = "[bold red]\\[x][/bold red]"
    FATAL = "[bold red]\\[!][/bold red]"
    DEBUG = "[bold magenta]\\[>][/bold magenta]"
    PROMPT = "[bold yellow]\\[?][/bold yellow]"


# *====[ Primary Alert Functions ]====*
def _log_alert(
    level: int,
    marker: str,
    message: str,
    context: dict[str, Any] | None = None,
) -> None:
    """Central helper to format and dispatch logs.

    Args:
        level: The logging level (e.g., logging.INFO).
        marker: The rich markup for the alert icon.
        message: The log message.
        context: Additional context to be included in the structured log.
    """
    console_message = f"{marker} {message}"

    # Create a clean, ASCII-only version for raw text logs
    plain_text = Text.from_markup(message).plain
    ascii_text = plain_text.encode("ascii", "ignore").decode("ascii")
    raw_message = " ".join(ascii_text.split())

    log_context = context if context is not None else {}
    _logger.log(
        level,
        console_message,
        stacklevel=3,
        extra={"extra_data": {"raw_message": raw_message, **log_context}},
    )


def info(message: str, context: dict[str, Any] | None = None) -> None:
    """Logs an informational message."""
    _log_alert(logging.INFO, _AlertStyles.INFO.value, message, context)


def success(message: str, context: dict[str, Any] | None = None) -> None:
    """Logs a success message."""
    _log_alert(logging.INFO, _AlertStyles.SUCCESS.value, message, context)


def warning(message: str, context: dict[str, Any] | None = None) -> None:
    """Logs a warning message."""
    _log_alert(logging.WARNING, _AlertStyles.WARNING.value, message, context)


def error(
    message: str,
    *,
    exc_info: bool = False,
    context: dict[str, Any] | None = None,
) -> None:
    """Logs an error message.

    If exc_info is True, displays a formatted traceback on the console.

    Args:
        message: The error message to display.
        exc_info: If True, prints the traceback to the console. Defaults to False.
        context: Additional context for structured logging.
    """
    _log_alert(logging.ERROR, _AlertStyles.ERROR.value, message, context)

    # If requested and an exception is available, print a rich traceback
    if exc_info and sys.exc_info()[0] is not None:
        tb = Traceback.from_exception(*sys.exc_info(), show_locals=False)
        console.print(tb)


def fatal(
    message: str,
    *,
    exit_code: int = 1,
    context: dict[str, Any] | None = None,
) -> None:
    """Logs a critical error and exits the application."""
    fatal_message = f"FATAL: {message}"
    _log_alert(logging.CRITICAL, _AlertStyles.FATAL.value, fatal_message, context)
    raise typer.Exit(code=exit_code)


def debug(message: str, context: dict[str, Any] | None = None) -> None:
    """Logs a debug message."""
    _log_alert(logging.DEBUG, _AlertStyles.DEBUG.value, message, context)


# *====[ UI & Structural Elements ]====*
def section(title: str, style: str = "bold white on #005f87") -> None:
    """Displays a beautiful, full-width, 'filled' section header.

    This creates a visually distinct, left-aligned separator that uses a
    solid background color to clearly break up application output.

    Args:
        title (str): The title of the section.
        style: The Rich style for the header (e.g., "white on blue").
    """
    # Format the title with a decorative icon and padding
    title_text = f" » {title.upper()} "
    try:
        terminal_width = get_terminal_size().columns
    except OSError:
        terminal_width = 80  # Default width

    padding_size = terminal_width - len(title_text)
    padding_size = max(padding_size, 0)
    padding = " " * padding_size
    full_line_text = title_text + padding
    full_line_markup = f"[{style}]{full_line_text}[/]"

    # Log a blank line, then the section to ensure correct order.
    _logger.info("", extra={"console_only": True})
    _logger.info(full_line_markup, extra={"console_only": True})


def header(title: str, style: str = "bold blue") -> None:
    """Displays a prominent, centered header using a Rich Rule.

    Args:
        title: The title text to display in the header.
        style: The color and style of the header line.
    """
    prefix, suffix, end_marker = "╭───⦗  ", "  ⦘", "╮"
    full_title = f"{prefix}{title}{suffix}"
    try:
        term_width = get_terminal_size().columns
    except OSError:
        term_width = 80  # Default width if not in a real terminal

    rule_fill_len = max(0, term_width - len(full_title) - len(end_marker))
    rule_fill = "─" * rule_fill_len
    line_text = f"{full_title}{rule_fill}{end_marker}"
    line_markup = f"[{style}]{line_text}[/]"

    # Log a blank line, then the header to preserve order and spacing.
    _logger.info("", extra={"console_only": True})
    _logger.info(line_markup, extra={"console_only": True})


def panel(
    content: RenderableType | str,
    *,
    title: str | None = None,
    title_align: str = "center",
    style: str = "cyan",
    padding: tuple[int, int] = (1, 2),
) -> None:
    """Displays content inside a visually distinct panel.

    Args:
        content: The text or Rich renderable to display.
        title: An optional title for the panel.
        title_align: Alignment for the title ('left', 'center', 'right').
        style: The border style for the panel.
        padding: The (vertical, horizontal) padding inside the panel.
    """
    renderable_content = Text.from_markup(content) if isinstance(content, str) else content
    panel_title = Text.from_markup(title) if title else None

    console.print(
        Panel(
            renderable_content,
            title=panel_title,
            title_align=title_align,
            border_style=style,
            padding=padding,
            expand=True,
        )
    )


def framed_box(
    content: RenderableType | str,
    *,
    title: str,
    style: Literal["info", "success", "error", "warning"] = "info",
) -> None:
    """Displays content inside a styled, bordered box.

    Args:
        content: The text or Rich renderable to display.
        title: The title displayed on the box's border.
        style: The predefined style/mood of the box, which determines its color.
    """
    style_map = {
        "info": "bright_black",
        "success": "green",
        "error": "light_pink3",
        "warning": "yellow",
    }
    border_style = style_map.get(style, "bright_black")

    panel(content, title=title, style=border_style, title_align="left")


@contextmanager
def spinner(text: str = "Processing...", *, style: str = "cyan") -> Iterator[None]:
    """A context manager that displays a spinner for long-running operations.

    Example:
        with alerts.spinner("Doing hard work..."):
            time.sleep(3)

    Args:
        text: The text to display next to the spinner.
        style: The color of the spinner.
    """
    with console.status(Text(text, style=style), spinner="dots"):
        yield


# *====[ Interactive Prompts ]====*
def _get_key_windows() -> str:
    """Gets a single key press on Windows."""
    key = msvcrt.getch()
    if key == b"\r":
        return "ENTER"
    if key == b"\x03":
        raise KeyboardInterrupt
    if key in {b"\xe0", b"\x00"}:  # Arrow keys start with a prefix
        second_byte = msvcrt.getch()
        key_map = {b"H": "UP", b"P": "DOWN"}
        return key_map.get(second_byte, "")
    return ""


def _get_key_unix() -> str:
    """Gets a single key press on Unix-like systems."""
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        char = sys.stdin.read(1)
        if char == "\x03":  # Ctrl+C
            raise KeyboardInterrupt
        if char == "\r":
            return "ENTER"
        if char == "\x1b" and sys.stdin.read(1) == "[":
            arrow_key = sys.stdin.read(1)
            key_map = {"A": "UP", "B": "DOWN"}
            return key_map.get(arrow_key, "")
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
    return ""


def _get_key() -> str:
    """Gets a single key press, platform-independently."""
    return _get_key_windows() if "msvcrt" in sys.modules else _get_key_unix()


def selection[T](message: str, choices: list[T]) -> T:
    """Displays an interactive, navigable selection menu.

    Args:
        message: The prompt message to display above the choices.
        choices: A list of options for the user to choose from.

    Returns:
        The option selected by the user.

    Raises:
        ValueError: If the 'choices' list is empty.
    """
    if not choices:
        msg = "Cannot make a selection from an empty list of choices."
        raise ValueError(msg)

    current_index = 0
    prompt_text = Text.from_markup(f"{_AlertStyles.PROMPT.value} {message}\n")

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
        choices: A list of valid string choices.

    Returns:
        The value entered by the user.
    """
    prompt_text = Text.from_markup(f"{_AlertStyles.PROMPT.value} {message}")
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
    prompt_text = Text.from_markup(f"{_AlertStyles.PROMPT.value} {message}")
    return Confirm.ask(prompt_text, default=default, console=console)


# *====[ Demonstration ]====*
def main() -> None:
    """Runs a demonstration of the CLI alerts module's capabilities."""
    # TODO(jonathantsilva): [#1] Migrate this demo tests to a test suite using pytest
    # TODO(jonathantsilva): Create a logfile scheme with rotation and retention

    log_level = "DEBUG" if "--verbose" in sys.argv else "INFO"
    setup_logging(default_level=log_level)

    section("Demonstrating the Logging System")

    if log_level == "INFO":
        info("Running in INFO mode. Use '--verbose' for DEBUG messages.")

    info("Application starting up.")
    debug("This is a verbose message, only visible with --verbose.")
    success("The setup was successful.")
    info(
        "Processing user request",
        context={"user_id": 42, "request_id": "a7b3c9", "scope": "read"},
    )
    warning("The 'legacy_api' is deprecated and will be removed next quarter.")

    try:
        non_existent_file = Path("a_file_that_does_not_exist.txt")
        non_existent_file.read_text()
    except FileNotFoundError:
        error(
            "A handled exception occurred!",
            exc_info=True,
            context={
                "failed_operation": "read_config_file",
                "path": str(non_existent_file),
            },
        )

    info("Demo finished successfully.")
    info("Check 'logs/app.log.json' for the structured output.")


if __name__ == "__main__":
    main()
