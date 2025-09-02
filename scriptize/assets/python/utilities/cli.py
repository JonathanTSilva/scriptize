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
from shutil import get_terminal_size
from typing import Any, Literal, TypeVar, overload

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


# *====[ Core Instances & Types ]====*

# Define a TypeVar for use in generic functions and overloads
T = TypeVar("T")

# A single, shared Console instance for the entire application.
# stderr is used by default to separate primary output (stdout) from alerts.
console = Console(stderr=True, highlight=False)

# A dedicated logger for this module. Using a named logger is a best practice.
_logger = logging.getLogger(__name__)


class _AlertStyles(str, Enum):
    """Encapsulates the rich markup for different alert styles.

    Attributes:
        INFO: Markup for informational messages.
        SUCCESS: Markup for success messages.
        WARNING: Markup for warning messages.
        ERROR: Markup for error messages.
        FATAL: Markup for fatal error messages.
        DEBUG: Markup for debug messages.
        PROMPT: Markup for interactive prompts.
    """

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
        level: The logging level (e.g., `logging.INFO`).
        marker: The rich markup for the alert icon (e.g., `_AlertStyles.INFO`).
        message: The primary log message to display.
        context: Optional dictionary for structured logging context.
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
    """Logs an informational message to the console.

    Args:
        message: The informational message to display.
        context: Optional dictionary for structured logging context.

    Examples:
        >>> info("The application has started successfully.")  # doctest: +SKIP
        >>> info("User logged in.", context={"user_id": 123})  # doctest: +SKIP
    """
    _log_alert(logging.INFO, _AlertStyles.INFO.value, message, context)


def success(message: str, context: dict[str, Any] | None = None) -> None:
    """Logs a success message to the console.

    Args:
        message: The success message to display.
        context: Optional dictionary for structured logging context.

    Examples:
        >>> success("File downloaded and verified.")  # doctest: +SKIP
    """
    _log_alert(logging.INFO, _AlertStyles.SUCCESS.value, message, context)


def warning(message: str, context: dict[str, Any] | None = None) -> None:
    """Logs a warning message to the console.

    Args:
        message: The warning message to display.
        context: Optional dictionary for structured logging context.

    Examples:
        >>> warning(
        ...     "The API is deprecated and will be removed in a future version."
        ... )  # doctest: +SKIP
    """
    _log_alert(logging.WARNING, _AlertStyles.WARNING.value, message, context)


def error(
    message: str,
    *,
    exc_info: bool = False,
    context: dict[str, Any] | None = None,
) -> None:
    """Logs an error message, with an optional traceback.

    Args:
        message: The error message to display.
        exc_info: If True, prints a formatted traceback of the current
            exception to the console. Defaults to False.
        context: Optional dictionary for structured logging context.

    Examples:
        >>> error("Failed to connect to the database.")  # doctest: +SKIP

        >>> try:  # doctest: +SKIP
        ...     1 / 0
        ... except ZeroDivisionError:
        ...     error("An unexpected mathematical error occurred.", exc_info=True)
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
    """Logs a critical error message and exits the application.

    Args:
        message: The fatal error message to display before exiting.
        exit_code: The exit code to use for the application. Defaults to 1.
        context: Optional dictionary for structured logging context.

    Raises:
        typer.Exit: Always raises this exception to terminate the application.

    Examples:
        >>> fatal("Configuration file not found. Cannot continue.")  # doctest: +SKIP
    """
    fatal_message = f"FATAL: {message}"
    _log_alert(logging.CRITICAL, _AlertStyles.FATAL.value, fatal_message, context)
    raise typer.Exit(code=exit_code)


def debug(message: str, context: dict[str, Any] | None = None) -> None:
    """Logs a debug message.

    Note:
        These messages are only visible if the logging level is set to DEBUG.

    Args:
        message: The debug message to display.
        context: Optional dictionary for structured logging context.

    Examples:
        >>> debug(f"Current working directory: {Path.cwd()}")  # doctest: +SKIP
    """
    _log_alert(logging.DEBUG, _AlertStyles.DEBUG.value, message, context)


# *====[ UI & Structural Elements ]====*
def section(title: str, style: str = "bold white on #005f87") -> None:
    """Displays a full-width, styled section header.

    This creates a visually distinct separator to break up application output.

    Args:
        title: The title of the section.
        style: The `rich` style for the header's background and text.

    Examples:
        >>> section("User Configuration")  # doctest: +SKIP
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
    """Displays a prominent, centered header with a rule line.

    Args:
        title: The title text to display in the header.
        style: The `rich` style for the header's text and rule line.

    Examples:
        >>> header("System Checks")  # doctest: +SKIP
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
    title_align: Literal["left", "center", "right"] = "center",
    style: str = "cyan",
    padding: tuple[int, int] = (1, 2),
) -> None:
    """Displays content inside a visually distinct, bordered panel.

    Args:
        content: The text or `rich` renderable to display inside the panel.
        title: An optional title for the panel.
        title_align: Alignment for the title ('left', 'center', 'right').
        style: The `rich` style for the panel's border.
        padding: A tuple of (vertical, horizontal) padding inside the panel.

    Examples:
        >>> panel("This is important information.", title="Notice")  # doctest: +SKIP
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
    """Displays content inside a pre-styled, bordered box.

    Args:
        content: The text or `rich` renderable to display.
        title: The title displayed on the box's border.
        style: The pre-defined style ('info', 'success', 'error', 'warning')
            which determines the box's color.

    Examples:
        >>> framed_box("Installation complete!", title="Success", style="success")  # doctest: +SKIP
        >>> framed_box(
        ...     "Network connection timed out.", title="Error", style="error"
        ... )  # doctest: +SKIP
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
    """Provides a context manager that displays a spinner for long operations.

    Args:
        text: The text to display next to the spinner.
        style: The `rich` style for the spinner and text.

    Yields:
        None: This is a context manager and does not yield a value.

    Examples:
        >>> with spinner("Downloading files..."):  # doctest: +SKIP
        ...     time.sleep(5)
        >>> success("Download complete.")  # doctest: +SKIP
    """
    with console.status(Text(text, style=style), spinner="dots"):
        yield


# *====[ Interactive Prompts ]====*
def _get_key_windows() -> str:
    """Gets a single key press on Windows.

    This function reads raw byte input to detect special keys like Enter
    and arrow keys, translating them into standardized strings.

    Returns:
        A string representing the key: "ENTER", "UP", "DOWN", or an empty
        string for unhandled keys.

    Raises:
        KeyboardInterrupt: If the user presses Ctrl+C.
    """
    key = msvcrt.getch()  # type: ignore[attr-defined]
    if key == b"\r":
        return "ENTER"
    if key == b"\x03":
        raise KeyboardInterrupt
    if key in {b"\xe0", b"\x00"}:  # Arrow keys start with a prefix
        second_byte = msvcrt.getch()  # type: ignore[attr-defined]
        key_map = {b"H": "UP", b"P": "DOWN"}
        return key_map.get(second_byte, "")
    return ""


def _get_key_unix() -> str:
    """Gets a single key press on Unix-like systems.

    This function temporarily sets the terminal to raw mode to capture a
    single character without requiring the user to press Enter. It ensures
    the original terminal settings are restored.

    Returns:
        A string representing the key: "ENTER", "UP", "DOWN", or an empty
        string for unhandled keys.

    Raises:
        KeyboardInterrupt: If the user presses Ctrl+C.
    """
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
    """Gets a single key press, platform-independently.

    This function acts as a dispatcher, calling the appropriate OS-specific
    function to capture user input.

    Returns:
        The string representation of the pressed key (e.g., "ENTER").

    Raises:
        KeyboardInterrupt: If the user cancels the input.
    """
    return _get_key_windows() if "msvcrt" in sys.modules else _get_key_unix()


def selection[T](message: str, choices: list[T]) -> T:
    """Displays an interactive, navigable selection menu for the user.

    The user can navigate with arrow keys and select with Enter.

    Args:
        message: The prompt message to display above the choices.
        choices: A list of options for the user to choose from.

    Returns:
        The option selected by the user.

    Raises:
        ValueError: If the 'choices' list is empty.
        KeyboardInterrupt: If the user cancels with Ctrl+C.

    Examples:
        >>> options = ["Option A", "Option B", "Option C"]  # doctest: +SKIP
        >>> chosen_option = selection("Please choose an option:", options)  # doctest: +SKIP
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


@overload
def prompt[T](
    message: str,
    *,
    default: T,
    secret: bool = False,
    choices: list[str] | None = None,
) -> T: ...


@overload
def prompt(
    message: str,
    *,
    default: None = None,
    secret: bool = False,
    choices: list[str] | None = None,
) -> str: ...


def prompt(
    message: str,
    *,
    default: Any = None,
    secret: bool = False,
    choices: list[str] | None = None,
) -> Any:
    """Prompts the user for text input.

    Args:
        message: The message to display to the user.
        default: A default value to return if the user enters nothing.
        secret: If True, the user's input will be masked (for passwords).
        choices: A list of valid string choices to validate against.

    Returns:
        The value entered by the user. If a `default` is provided, the
        return type will match the type of the default value. Otherwise,
        it returns a string.

    Examples:
        >>> name = prompt("Enter your name:", default="Guest")  # doctest: +SKIP
        >>> password = prompt("Enter your password:", secret=True)  # doctest: +SKIP
        >>> color = prompt("Choose a color:", choices=["red", "green", "blue"])  # doctest: +SKIP
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
        `True` if the user confirms, `False` otherwise.

    Examples:
        >>> if confirm("Are you sure you want to proceed?"):  # doctest: +SKIP
        ...     info("Proceeding with operation.")
    """
    prompt_text = Text.from_markup(f"{_AlertStyles.PROMPT.value} {message}")
    return Confirm.ask(prompt_text, default=default, console=console)
