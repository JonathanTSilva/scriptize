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
from pathlib import Path

# Platform-specific imports
if sys.platform == "win32":
    import ctypes

# For robust validation of common data types, we use a dedicated library.
# This should be added to your pyproject.toml dependencies.
# poetry add validators / uv pip install validators
try:
    import validators
except ImportError:
    sys.stderr.write(
        "Error: The 'validators' library is required. "
        "Please install it by running 'pip install validators'\n"
    )
    sys.exit(1)

# A more specific type hint for functions that can accept various inputs.
AcceptableTypes = str | int | float | list | dict | set | tuple | None


# ==================================================================================================
# System & Command Checks
# ==================================================================================================


def command_exists(name: str) -> bool:
    """Check if a command exists on the system's PATH.

    Args:
        name: The name of the command to check (e.g., "git").

    Returns:
        True if the command is found, False otherwise.
    """
    return shutil.which(name) is not None


def is_root() -> bool:
    """Check if the script is currently running with root/administrator privileges.

    Returns:
        True if running as root/admin, False otherwise.
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
    """
    return sys.stdout.isatty()


# ==================================================================================================
# File System Checks
# ==================================================================================================


def is_file(path: str | Path) -> bool:
    """Check if a given path exists and is a file.

    Args:
        path: The path to the file.

    Returns:
        True if the path is a file, False otherwise.
    """
    return Path(path).is_file()


def is_dir(path: str | Path) -> bool:
    """Check if a given path exists and is a directory.

    Args:
        path: The path to the directory.

    Returns:
        True if the path is a directory, False otherwise.
    """
    return Path(path).is_dir()


# ==================================================================================================
# Data Format & Type Validation
# ==================================================================================================


def is_email(value: str) -> bool:
    """Validate if a string is a valid email address.

    Args:
        value: The string to validate.

    Returns:
        True if the string is a valid email, False otherwise.
    """
    return validators.email(value) is True


def is_ipv4(value: str) -> bool:
    """Validate if a string is a valid IPv4 address.

    Args:
        value: The string to validate.

    Returns:
        True if the string is a valid IPv4 address, False otherwise.
    """
    return validators.ipv4(value) is True


def is_ipv6(value: str) -> bool:
    """Validate if a string is a valid IPv6 address.

    Args:
        value: The string to validate.

    Returns:
        True if the string is a valid IPv6 address, False otherwise.
    """
    return validators.ipv6(value) is True


def is_fqdn(value: str) -> bool:
    """Validate if a string is a fully qualified domain name.

    Args:
        value: The string to validate.

    Returns:
        True if the string is a valid FQDN, False otherwise.
    """
    return validators.domain(value) is True


def is_numeric(value: AcceptableTypes) -> bool:
    """Check if a value can be interpreted as a number (integer or float).

    Args:
        value: The value to check.

    Returns:
        True if the value is numeric, False otherwise.
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


# ==================================================================================================
# Boolean & Value Checks
# ==================================================================================================


def is_true(value: AcceptableTypes) -> bool:
    """Check if a value evaluates to a "true" boolean.

    Considers True, non-zero numbers, and strings like "true", "yes", "1".

    Args:
        value: The value to check.

    Returns:
        True if the value is considered true, False otherwise.
    """
    if isinstance(value, str):
        return value.lower() in {"true", "1", "t", "y", "yes"}
    return bool(value)


def is_empty(value: AcceptableTypes) -> bool:
    """Check if a value is empty.

    Considers None, empty strings, empty collections (list, dict, etc.), and 0.

    Args:
        value: The value to check.

    Returns:
        True if the value is considered empty, False otherwise.
    """
    if value is None:
        return True
    if hasattr(value, "__len__"):
        return len(value) == 0
    return False


# ==================================================================================================
# Demonstration
# ==================================================================================================

if __name__ == "__main__":
    # TODO(jonathantsilva): [#1] Migrate this tests to a test suite using pytest
    # To run this demo, you need the alerts module from this library.
    # This demonstrates how the library modules can work together.
    try:
        # Use a relative import to find the alerts module within the same package.
        from . import alerts
    except ImportError:
        sys.stderr.write("Could not import the 'alerts' module for this demonstration.\n")

        # Create a fallback for the demo if alerts doesn't exist
        class FallbackAlerts:
            """A fallback class to provide dummy alert methods for the demo."""

            def __getattr__(self, name: str) -> Callable[..., None]:
                """Return a dummy printer for any attribute."""

                def printer(title: str, **_: object) -> None:
                    sys.stdout.write(f"\n--- {title.upper()} ---\n")

                return printer

        alerts = FallbackAlerts()  # type: ignore[assignment]

    alerts.section("ScriptizePy Checks Demo")

    # A simple helper to format boolean checks for the demo output.
    def format_check(*, check: bool) -> str:
        """Formats a boolean value into a colored Yes/No string."""
        return "[bold green]✔ Yes[/]" if check else "[bold red]✖ No[/]"

    alerts.setup_logging(level="INFO")
    # --- System Checks ---
    alerts.header("System Checks")
    alerts.info(f"Command 'python' exists: {format_check(check=command_exists('python'))}")
    alerts.info(
        f"Command 'nonexistentcmd' exists: {format_check(check=command_exists('nonexistentcmd'))}"
    )
    alerts.info(f"Running as root: {format_check(check=is_root())}")
    alerts.info(f"Internet is available: {format_check(check=is_internet_available())}")
    alerts.info(f"Running in a terminal: {format_check(check=is_terminal())}")

    # --- File System Checks ---
    alerts.header("File System Checks")
    Path("temp_test_file.txt").touch()
    Path("temp_test_dir").mkdir(exist_ok=True)
    alerts.info(
        f"Path 'temp_test_file.txt' is a file: {format_check(check=is_file('temp_test_file.txt'))}"
    )
    alerts.info(f"Path 'temp_test_dir' is a file: {format_check(check=is_file('temp_test_dir'))}")
    alerts.info(
        f"Path 'temp_test_dir' is a directory: {format_check(check=is_dir('temp_test_dir'))}"
    )
    alerts.info(
        f"Path 'nonexistent_path' is a directory: {format_check(check=is_dir('nonexistent_path'))}"
    )
    Path("temp_test_file.txt").unlink()
    Path("temp_test_dir").rmdir()

    # --- Data Format Validation ---
    alerts.header("Data Format Validation")
    alerts.info(
        f"'test@example.com' is an email: {format_check(check=is_email('test@example.com'))}"
    )
    alerts.info(f"'not-an-email' is an email: {format_check(check=is_email('not-an-email'))}")
    alerts.info(f"'192.168.1.1' is IPv4: {format_check(check=is_ipv4('192.168.1.1'))}")
    alerts.info(f"'999.9.9.9' is IPv4: {format_check(check=is_ipv4('999.9.9.9'))}")
    alerts.info(f"'google.com' is FQDN: {format_check(check=is_fqdn('google.com'))}")
    alerts.info(f"'not_a_domain' is FQDN: {format_check(check=is_fqdn('not_a_domain'))}")
    alerts.info(f"'123.45' is numeric: {format_check(check=is_numeric('123.45'))}")
    alerts.info(f"'abc' is numeric: {format_check(check=is_numeric('abc'))}")

    # --- Boolean & Value Checks ---
    alerts.header("Boolean & Value Checks")
    alerts.info(f"is_true('yes'): {format_check(check=is_true('yes'))}")
    alerts.info(f"is_true(0): {format_check(check=is_true(0))}")
    alerts.info(f"is_empty([]): {format_check(check=is_empty([]))}")
    alerts.info(f"is_empty('hello'): {format_check(check=is_empty('hello'))}")
