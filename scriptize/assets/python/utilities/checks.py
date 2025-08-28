"""A collection of validation and verification functions.

This module provides a set of common checks for scripts, such as verifying
the existence of commands, validating data formats (e.g., email, IP),
and checking system states (e.g., internet connectivity, root access).
"""

import os
import shutil
import socket
import sys
from collections.abc import Callable
from contextlib import suppress
from pathlib import Path
from typing import Any

# Platform-specific imports
if sys.platform == "win32":
    import ctypes

# For robust validation of common data types, we use a dedicated library.
try:
    import validators
except ImportError:
    sys.stderr.write(
        "Error: The 'validators' library is required. "
        "Please install it by running 'pip install validators'\n"
    )
    sys.exit(1)

# Import for the demo function, kept optional.
cli: Any = None
with suppress(ImportError):
    from . import cli


# A more specific type hint for functions that can accept various inputs.
AcceptableTypes = str | int | float | list | dict | set | tuple | None


# *====[ System & Command Checks ]====*
def command_exists(name: str) -> bool:
    """Check if a command exists on the system's PATH.

    Args:
        name: The name of the command to check (e.g., "git").

    Returns:
        True if the command is found, False otherwise.

    Examples:
        >>> command_exists("python")
        True
        >>> command_exists("non_existent_command_12345")
        False
    """
    return shutil.which(name) is not None


def is_root() -> bool:
    """Check if the script is currently running with root/administrator privileges.

    Returns:
        True if running as root/admin, False otherwise.

    Examples:
        >>> # This test will pass regardless of the user, as it checks
        >>> # the function's output against the OS's direct report.
        >>> expected = (
        ...     (os.geteuid() == 0)
        ...     if sys.platform != "win32"
        ...     else (ctypes.windll.shell32.IsUserAnAdmin() != 0)
        ... )
        >>> is_root() == expected
        True
    """
    if sys.platform == "win32":
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    return os.geteuid() == 0


def is_internet_available(host: str = "1.1.1.1", port: int = 53, timeout: int = 3) -> bool:
    """Check for an active internet connection by connecting to a known server.

    Args:
        host: The server IP to connect to. Defaults to Cloudflare's DNS.
        port: The port to connect to. Defaults to 53 (DNS).
        timeout: The connection timeout in seconds.

    Returns:
        True if the connection is successful, False otherwise.

    Examples:
        >>> # This will likely be True if you have an internet connection.
        >>> # is_internet_available()
        >>> # This will always be False as it points to a reserved address.
        >>> is_internet_available(host="192.0.2.0", timeout=1)
        False
    """
    try:
        socket.setdefaulttimeout(timeout)
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.connect((host, port))
    except OSError:
        return False
    else:
        return True


def is_terminal() -> bool:
    """Check if the script is running in an interactive terminal.

    Returns:
        True if running in a TTY, False otherwise.

    Examples:
        >>> # This test checks the function's output against the direct sys call.
        >>> # When run with doctest, it is typically False.
        >>> is_terminal() == sys.stdout.isatty()
        True
    """
    return sys.stdout.isatty()


# *====[ File System Checks ]====*
def is_file(path: str | Path) -> bool:
    """Check if a given path exists and is a file.

    Args:
        path: The path to the file.

    Returns:
        True if the path is a file, False otherwise.

    Examples:
        >>> from pathlib import Path
        >>> # Setup: create a dummy file and directory
        >>> p_file = Path("doctest_temp.txt")
        >>> p_file.touch()
        >>> p_dir = Path("doctest_temp_dir")
        >>> p_dir.mkdir()
        >>> is_file(p_file)
        True
        >>> is_file("doctest_temp.txt")
        True
        >>> is_file(p_dir)
        False
        >>> is_file("non_existent_file.xyz")
        False
        >>> # Teardown: clean up created file and directory
        >>> p_file.unlink()
        >>> p_dir.rmdir()
    """
    return Path(path).is_file()


def is_dir(path: str | Path) -> bool:
    """Check if a given path exists and is a directory.

    Args:
        path: The path to the directory.

    Returns:
        True if the path is a directory, False otherwise.

    Examples:
        >>> from pathlib import Path
        >>> # Setup: create a dummy file and directory
        >>> p_file = Path("doctest_temp.txt")
        >>> p_file.touch()
        >>> p_dir = Path("doctest_temp_dir")
        >>> p_dir.mkdir()
        >>> is_dir(p_dir)
        True
        >>> is_dir("doctest_temp_dir")
        True
        >>> is_dir(p_file)
        False
        >>> is_dir("non_existent_dir/")
        False
        >>> # Teardown: clean up created file and directory
        >>> p_file.unlink()
        >>> p_dir.rmdir()
    """
    return Path(path).is_dir()


# *====[ Data Format & Type Validation ]====*
def is_email(value: str) -> bool:
    """Validate if a string is a valid email address.

    Args:
        value: The string to validate.

    Returns:
        True if the string is a valid email, False otherwise.

    Examples:
        >>> is_email("test@example.com")
        True
        >>> is_email("not-a-valid-email")
        False
        >>> is_email("test@localhost")
        False
    """
    return validators.email(value) is True


def is_ipv4(value: str) -> bool:
    """Validate if a string is a valid IPv4 address.

    Args:
        value: The string to validate.

    Returns:
        True if the string is a valid IPv4 address, False otherwise.

    Examples:
        >>> is_ipv4("192.168.0.1")
        True
        >>> is_ipv4("256.0.0.0")
        False
        >>> is_ipv4("not-an-ip")
        False
    """
    return validators.ipv4(value) is True


def is_ipv6(value: str) -> bool:
    """Validate if a string is a valid IPv6 address.

    Args:
        value: The string to validate.

    Returns:
        True if the string is a valid IPv6 address, False otherwise.

    Examples:
        >>> is_ipv6("2001:0db8:85a3:0000:0000:8a2e:0370:7334")
        True
        >>> is_ipv6("::1")
        True
        >>> is_ipv6("not-an-ipv6")
        False
    """
    return validators.ipv6(value) is True


def is_fqdn(value: str) -> bool:
    """Validate if a string is a fully qualified domain name.

    Args:
        value: The string to validate.

    Returns:
        True if the string is a valid FQDN, False otherwise.

    Examples:
        >>> is_fqdn("google.com")
        True
        >>> is_fqdn("a.b.c.co.uk")
        True
        >>> is_fqdn("not_a_domain")
        False
    """
    return validators.domain(value) is True


def is_numeric(value: AcceptableTypes) -> bool:
    """Check if a value can be interpreted as a number (integer or float).

    Args:
        value: The value to check.

    Returns:
        True if the value is numeric, False otherwise.

    Examples:
        >>> is_numeric(123)
        True
        >>> is_numeric(-45.67)
        True
        >>> is_numeric("99.9")
        True
        >>> is_numeric("-20")
        True
        >>> is_numeric("abc")
        False
        >>> is_numeric(None)
        False
        >>> is_numeric([1, 2])
        False
    """
    if isinstance(value, int | float):
        return True
    if isinstance(value, str):
        try:
            float(value)
        except (ValueError, TypeError):
            return False
        else:
            return True
    return False


# *====[ Boolean & Value Checks ]====*
def is_true(value: AcceptableTypes) -> bool:
    """Check if a value evaluates to a "true" boolean.

    Considers True, non-zero numbers, and strings like "true", "yes", "1".

    Args:
        value: The value to check.

    Returns:
        True if the value is considered true, False otherwise.

    Examples:
        >>> is_true("true")
        True
        >>> is_true("Yes")
        True
        >>> is_true("T")
        True
        >>> is_true("1")
        True
        >>> is_true(1)
        True
        >>> is_true(-1)
        True
        >>> is_true(True)
        True
        >>> is_true("false")
        False
        >>> is_true(0)
        False
        >>> is_true(None)
        False
        >>> is_true([])
        False
    """
    if isinstance(value, str):
        return value.lower() in {"true", "1", "t", "y", "yes"}
    return bool(value)


def is_empty(value: AcceptableTypes) -> bool:
    """Check if a value is empty.

    Considers None and collections with a length of zero (e.g., strings,
    lists, dictionaries).

    Args:
        value: The value to check.

    Returns:
        True if the value is considered empty, False otherwise.

    Examples:
        >>> is_empty(None)
        True
        >>> is_empty("")
        True
        >>> is_empty([])
        True
        >>> is_empty({})
        True
        >>> is_empty(set())
        True
        >>> is_empty("hello")
        False
        >>> is_empty([1, 2, 3])
        False
        >>> is_empty(0)
        False
        >>> is_empty(False)
        False
    """
    if value is None:
        return True
    if hasattr(value, "__len__"):
        return len(value) == 0
    return False


# *====[ Demonstration ]====*
def demo() -> None:
    """Demonstrates the functionality of the checks module.

    This function provides a visual demonstration of the check functions by
    printing their results to the console. It is intended for interactive
    use and does not have a return value or doctests.
    """
    # TODO(jonathantsilva): [#1] Migrate this tests to a test suite using pytest
    if cli is None:
        sys.stderr.write("Could not import the 'cli' module for this demonstration.\n")

        # Create a fallback for the demo if cli doesn't exist
        class FallbackAlerts:
            """A fallback class to provide dummy alert methods for the demo."""

            def __getattr__(self, name: str) -> Callable[..., None]:
                """Return a dummy printer for any attribute."""

                def printer(title: str, **_: object) -> None:
                    sys.stdout.write(f"\n--- {title.upper()} ---\n")

                return printer

        cli_fallback = FallbackAlerts()
    else:
        cli_fallback = cli

    cli_fallback.section("ScriptizePy Checks Demo")

    # A simple helper to format boolean checks for the demo output.
    def format_check(*, check: bool) -> str:
        """Formats a boolean value into a colored Yes/No string."""
        return "[bold green]✔ Yes[/]" if check else "[bold red]✖ No[/]"

    cli_fallback.setup_logging(default_level="INFO")
    # --- System Checks ---
    cli_fallback.header("System Checks")
    cli_fallback.info(f"Command 'python' exists: {format_check(check=command_exists('python'))}")
    cli_fallback.info(
        f"Command 'nonexistentcmd' exists: {format_check(check=command_exists('nonexistentcmd'))}"
    )
    cli_fallback.info(f"Running as root: {format_check(check=is_root())}")
    cli_fallback.info(f"Internet is available: {format_check(check=is_internet_available())}")
    cli_fallback.info(f"Running in a terminal: {format_check(check=is_terminal())}")

    # --- File System Checks ---
    cli_fallback.header("File System Checks")
    Path("temp_test_file.txt").touch()
    Path("temp_test_dir").mkdir(exist_ok=True)
    cli_fallback.info(
        f"Path 'temp_test_file.txt' is a file: {format_check(check=is_file('temp_test_file.txt'))}"
    )
    cli_fallback.info(
        f"Path 'temp_test_dir' is a file: {format_check(check=is_file('temp_test_dir'))}"
    )
    cli_fallback.info(
        f"Path 'temp_test_dir' is a directory: {format_check(check=is_dir('temp_test_dir'))}"
    )
    cli_fallback.info(
        f"Path 'nonexistent_path' is a directory: {format_check(check=is_dir('nonexistent_path'))}"
    )
    Path("temp_test_file.txt").unlink()
    Path("temp_test_dir").rmdir()

    # --- Data Format Validation ---
    cli_fallback.header("Data Format Validation")
    cli_fallback.info(
        f"'test@example.com' is an email: {format_check(check=is_email('test@example.com'))}"
    )
    cli_fallback.info(f"'not-an-email' is an email: {format_check(check=is_email('not-an-email'))}")
    cli_fallback.info(f"'192.168.1.1' is IPv4: {format_check(check=is_ipv4('192.168.1.1'))}")
    cli_fallback.info(f"'999.9.9.9' is IPv4: {format_check(check=is_ipv4('999.9.9.9'))}")
    cli_fallback.info(f"'google.com' is FQDN: {format_check(check=is_fqdn('google.com'))}")
    cli_fallback.info(f"'not_a_domain' is FQDN: {format_check(check=is_fqdn('not_a_domain'))}")
    cli_fallback.info(f"'123.45' is numeric: {format_check(check=is_numeric('123.45'))}")
    cli_fallback.info(f"'abc' is numeric: {format_check(check=is_numeric('abc'))}")

    # --- Boolean & Value Checks ---
    cli_fallback.header("Boolean & Value Checks")
    cli_fallback.info(f"is_true('yes'): {format_check(check=is_true('yes'))}")
    cli_fallback.info(f"is_true(0): {format_check(check=is_true(0))}")
    cli_fallback.info(f"is_empty([]): {format_check(check=is_empty([]))}")
    cli_fallback.info(f"is_empty('hello'): {format_check(check=is_empty('hello'))}")


if __name__ == "__main__":
    demo()
