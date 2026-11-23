# ruff: noqa: S101
"""Tests for the strings utility module."""

import runpy

import pytest

from scriptize.assets.python.utilities import strings


class TestTrimming:
    """Tests for the trimming and cleaning helpers."""

    def test_trim_variants(self) -> None:
        """trim, ltrim and rtrim remove whitespace from the right sides."""
        assert strings.trim("  a b  ") == "a b"
        assert strings.ltrim("  a b  ") == "a b  "
        assert strings.rtrim("  a b  ") == "  a b"

    def test_strip_ansi(self) -> None:
        """Colour and style escape codes are removed."""
        assert (
            strings.strip_ansi("\x1b[1;34mHello\x1b[0m, \x1b[31mWorld\x1b[0m!") == "Hello, World!"
        )

    def test_strip_ansi_plain_text_unchanged(self) -> None:
        """Text without escape codes is returned as is."""
        assert strings.strip_ansi("plain") == "plain"

    def test_clean_string(self) -> None:
        """Outer whitespace is trimmed and inner runs collapse to one space."""
        assert strings.clean_string("   extra \t\n  spaces   ") == "extra spaces"


class TestCase:
    """Tests for case conversion."""

    def test_to_lower_and_upper(self) -> None:
        """Both conversions change only the case."""
        assert strings.to_lower("Hello World") == "hello world"
        assert strings.to_upper("Hello World") == "HELLO WORLD"


class TestEncoding:
    """Tests for URL and HTML encoding."""

    def test_url_round_trip(self) -> None:
        """Encoding then decoding returns the original string."""
        original = "a string with spaces & special/chars"
        encoded = strings.encode_url(original)
        assert encoded == "a%20string%20with%20spaces%20%26%20special/chars"
        assert strings.decode_url(encoded) == original

    def test_html_round_trip(self) -> None:
        """Special characters become entities and back."""
        original = "<h1>'Hello & Welcome!'</h1>"
        encoded = strings.encode_html(original)
        assert "<" not in encoded
        assert "&amp;" in encoded
        assert strings.decode_html(encoded) == original


class TestSearching:
    """Tests for substring and regex helpers."""

    def test_contains(self) -> None:
        """Substring presence is reported."""
        assert strings.contains("the quick fox", "quick") is True
        assert strings.contains("the quick fox", "cat") is False

    def test_regex_match(self) -> None:
        """A pattern is searched anywhere in the text."""
        assert strings.regex_match("the quick fox", r"\bfox\b") is True
        assert strings.regex_match("the quick fox", r"\bcat\b") is False

    def test_regex_capture(self) -> None:
        """All non-overlapping matches are returned."""
        text = "The quick brown fox jumps over the lazy dog."
        assert strings.regex_capture(text, r"\b\w*o\w*\b") == ["brown", "fox", "over", "dog"]
        assert strings.regex_capture(text, r"\d+") == []


class TestDemo:
    """Tests for the `demo()` function."""

    def test_demo_runs_with_cli(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """The demo exercises every helper through the cli module."""
        calls: list[str] = []
        fake_cli = type(
            "FakeCli",
            (),
            {
                "setup_logging": staticmethod(lambda **_kw: calls.append("setup")),
                "section": staticmethod(lambda msg: calls.append(f"section:{msg}")),
                "header": staticmethod(lambda msg: calls.append(f"header:{msg}")),
                "info": staticmethod(lambda msg: calls.append(f"info:{msg}")),
            },
        )
        monkeypatch.setattr(strings, "cli", fake_cli)

        strings.demo()

        assert calls[0] == "setup"
        assert "section:ScriptizePy Strings Demo" in calls
        assert "info:trim(): 'extra   spaces'" in calls
        assert "info:contains('fox'): True" in calls
        assert sum(c.startswith("header:") for c in calls) == 4  # noqa: PLR2004

    def test_demo_without_cli_exits(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """Without the optional cli module the demo exits with a message."""
        monkeypatch.setattr(strings, "cli", None)
        with pytest.raises(SystemExit) as exc_info:
            strings.demo()
        assert "requires the 'cli' module" in str(exc_info.value)

    def test_runs_as_script(self) -> None:
        """Executing the file as `__main__` calls `demo()`.

        run_path has no parent package, so the optional relative `cli` import fails
        and the demo exits with its explanatory message.
        """
        with pytest.raises(SystemExit) as exc_info:
            runpy.run_path(strings.__file__, run_name="__main__")
        assert "requires the 'cli' module" in str(exc_info.value)
