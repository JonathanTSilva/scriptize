"""A collection of robust and convenient string manipulation utilities.

This module provides helper functions for common string operations like
cleaning, trimming, case conversion, encoding/decoding, and pattern matching
using regular expressions.
"""

import html
import re
import sys
from urllib.parse import quote, unquote


# *====[ Trimming & Cleaning ]====*
def trim(text: str) -> str:
    """Removes leading and trailing whitespace from a string."""
    return text.strip()


def ltrim(text: str) -> str:
    """Removes leading whitespace from a string."""
    return text.lstrip()


def rtrim(text: str) -> str:
    """Removes trailing whitespace from a string."""
    return text.rstrip()


def strip_ansi(text: str) -> str:
    """Removes ANSI escape codes (used for color and styling) from a string.

    Args:
        text: The string to clean.

    Returns:
        The string with all ANSI codes removed.
    """
    ansi_escape = re.compile(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")
    return ansi_escape.sub("", text)


def clean_string(text: str) -> str:
    """Performs a series of cleaning operations on a string.

    - Trims leading/trailing whitespace.
    - Replaces multiple spaces with a single space.

    Args:
        text: The string to clean.

    Returns:
        The cleaned string.
    """
    text = text.strip()
    return re.sub(r"\s+", " ", text)


# *====[ Case Conversion ]====*
def to_lower(text: str) -> str:
    """Converts a string to lowercase."""
    return text.lower()


def to_upper(text: str) -> str:
    """Converts a string to uppercase."""
    return text.upper()


# *====[ Encoding & Decoding ]====*
def encode_url(text: str) -> str:
    """URL-encodes a string.

    Args:
        text: The string to encode.

    Returns:
        The URL-encoded string.
    """
    return quote(text)


def decode_url(text: str) -> str:
    """Decodes a URL-encoded string.

    Args:
        text: The string to decode.

    Returns:
        The decoded string.
    """
    return unquote(text)


def encode_html(text: str) -> str:
    """HTML-encodes a string, converting special characters to entities.

    Args:
        text: The string to encode.

    Returns:
        The HTML-encoded string.
    """
    return html.escape(text)


def decode_html(text: str) -> str:
    """Decodes HTML entities in a string.

    Args:
        text: The string to decode.

    Returns:
        The decoded string.
    """
    return html.unescape(text)


# *====[ Searching & Matching ]====*
def contains(text: str, substring: str) -> bool:
    """Checks if a string contains a specific substring.

    This is a simple wrapper for Python's `in` operator for API consistency.

    Args:
        text: The string to search within.
        substring: The substring to search for.

    Returns:
        True if the substring is found, False otherwise.
    """
    return substring in text


def regex_match(text: str, pattern: str) -> bool:
    """Checks if a string matches a regular expression pattern.

    Args:
        text: The string to check.
        pattern: The regular expression pattern.

    Returns:
        True if the pattern matches, False otherwise.
    """
    return re.search(pattern, text) is not None


def regex_capture(text: str, pattern: str) -> list[str]:
    """Finds all non-overlapping matches of a pattern in a string.

    Args:
        text: The string to search within.
        pattern: The regular expression pattern.

    Returns:
        A list of all matches found.
    """
    return re.findall(pattern, text)


# *====[ Demonstration ]====*
def demo() -> None:
    # TODO(@jonathantsilva): [#1] Migrate this demo to a test suite using pytest
    try:
        from . import cli
    except ImportError:
        sys.exit("This demo requires the 'cli' module to be available.")

    cli.setup_logging(default_level="DEBUG")
    cli.section("ScriptizePy Strings Demo")

    # --- Trimming & Cleaning ---
    cli.header("Trimming & Cleaning")
    original_str = "   extra   spaces   "
    cli.info(f"Original: '{original_str}'")
    cli.info(f"trim(): '{trim(original_str)}'")
    cli.info(f"clean_string(): '{clean_string(original_str)}'")
    ansi_str = "\x1b[1;34mHello\x1b[0m, \x1b[1;31mWorld\x1b[0m!"
    cli.info(f"Original ANSI: '{ansi_str}'")
    cli.info(f"strip_ansi(): '{strip_ansi(ansi_str)}'")

    # --- Case Conversion ---
    cli.header("Case Conversion")
    case_str = "Hello World"
    cli.info(f"Original: '{case_str}'")
    cli.info(f"to_lower(): '{to_lower(case_str)}'")
    cli.info(f"to_upper(): '{to_upper(case_str)}'")

    # --- Encoding & Decoding ---
    cli.header("Encoding & Decoding")
    url_str = "a string with spaces & special/chars"
    encoded_url = encode_url(url_str)
    cli.info(f"Original URL string: '{url_str}'")
    cli.info(f"encode_url(): '{encoded_url}'")
    cli.info(f"decode_url(): '{decode_url(encoded_url)}'")

    html_str = "<h1>'Hello & Welcome!'</h1>"
    encoded_html = encode_html(html_str)
    cli.info(f"Original HTML string: {html_str}")
    cli.info(f"encode_html(): {encoded_html}")
    cli.info(f"decode_html(): {decode_html(encoded_html)}")

    # --- Searching & Matching ---
    cli.header("Searching & Matching")
    search_text = "The quick brown fox jumps over the lazy dog."
    cli.info(f"Text: '{search_text}'")
    cli.info(f"contains('fox'): {contains(search_text, 'fox')}")
    cli.info(f"contains('cat'): {contains(search_text, 'cat')}")
    # FIX: regex operations is not working here
    cli.info(f"regex_match(r'\\bfox\\b'): {regex_match(search_text, r'\\bfox\\b')}")
    cli.info(f"regex_capture(r'\\b\\w*o\\w*\\b'): {regex_capture(search_text, r'\\b\\w*o\\w*\\b')}")


if __name__ == "__main__":
    demo()
