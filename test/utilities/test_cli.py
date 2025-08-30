# ruff: noqa: S101, SLF001
"""Comprehensive tests for the CLI utility module.

This test suite uses extensive mocking to achieve full coverage by simulating
OS-specific behavior, error conditions, and interactive user input.
"""

import logging
import sys
from importlib import reload
from unittest.mock import MagicMock, patch

import pytest
import typer
from rich.prompt import Confirm, Prompt
from rich.text import Text

from scriptize.assets.python.utilities import cli


@patch("scriptize.assets.python.utilities.cli._logger")
class TestAlertFunctions:
    """Tests for the primary alert logging functions."""

    def test_info(self, mock_logger: MagicMock) -> None:
        """Verify that info() logs at the INFO level with the correct marker."""
        cli.info("test message", context={"data": 1})
        mock_logger.log.assert_called_once()
        args, kwargs = mock_logger.log.call_args
        assert args[0] == logging.INFO
        assert "[*]" in args[1]
        assert "test message" in args[1]
        assert kwargs["extra"]["extra_data"]["data"] == 1

    def test_success(self, mock_logger: MagicMock) -> None:
        """Verify that success() logs at the INFO level with the correct marker."""
        cli.success("it worked")
        args, _ = mock_logger.log.call_args
        assert args[0] == logging.INFO
        assert "[+]" in args[1]

    def test_warning(self, mock_logger: MagicMock) -> None:
        """Verify that warning() logs at the WARNING level."""
        cli.warning("be careful")
        args, _ = mock_logger.log.call_args
        assert args[0] == logging.WARNING
        assert "[!]" in args[1]

    def test_error_without_traceback(self, mock_logger: MagicMock) -> None:
        """Verify error() logs at the ERROR level without a traceback."""
        cli.error("something broke")
        args, _ = mock_logger.log.call_args
        assert args[0] == logging.ERROR
        assert "[x]" in args[1]

    def _raise_test_exception(self) -> None:
        """Helper to predictably raise an exception for testing tracebacks."""
        error_msg = "A test error"
        raise ValueError(error_msg)

    @patch("scriptize.assets.python.utilities.cli.console.print")
    def test_error_with_traceback(
        self,
        mock_print: MagicMock,
        mock_logger: MagicMock,
    ) -> None:
        """Verify that error() with exc_info=True prints a traceback."""
        try:
            self._raise_test_exception()
        except ValueError:
            cli.error("An exception occurred", exc_info=True)

        mock_logger.log.assert_called_once()
        mock_print.assert_called_once()

    def test_fatal(self, mock_logger: MagicMock) -> None:
        """Verify that fatal() logs at CRITICAL and raises typer.Exit."""
        with pytest.raises(typer.Exit) as exc_info:
            cli.fatal("cannot continue")
        assert exc_info.value.exit_code == 1
        mock_logger.log.assert_called_once()
        args, _ = mock_logger.log.call_args
        assert args[0] == logging.CRITICAL
        assert "FATAL: cannot continue" in args[1]

    def test_debug(self, mock_logger: MagicMock) -> None:
        """Verify that debug() logs at the DEBUG level."""
        cli.debug("debug info")
        args, _ = mock_logger.log.call_args
        assert args[0] == logging.DEBUG
        assert "[>]" in args[1]


@patch("scriptize.assets.python.utilities.cli.console", new_callable=MagicMock)
class TestUIElements:
    """Tests for non-interactive UI elements."""

    @patch("scriptize.assets.python.utilities.cli.get_terminal_size")
    @patch("scriptize.assets.python.utilities.cli._logger")
    def test_section_and_header_os_error(
        self,
        mock_logger: MagicMock,
        mock_get_terminal_size: MagicMock,
        _: MagicMock,  # noqa: PT019
    ) -> None:
        """Verify section() and header() fall back to a default width on OSError."""
        mock_get_terminal_size.side_effect = OSError
        cli.section("Test Section")
        cli.header("Test Header")
        expected_call_count = 4
        assert mock_logger.info.call_count == expected_call_count

    @patch("scriptize.assets.python.utilities.cli.Panel")
    def test_panel_content_types(self, mock_panel: MagicMock, _: MagicMock) -> None:  # noqa: PT019
        """Verify panel() handles both str and Renderable content."""
        cli.panel("string content")
        assert isinstance(mock_panel.call_args[0][0], Text)

        renderable = Text("renderable content")
        cli.panel(renderable)
        assert mock_panel.call_args[0][0] is renderable

    @pytest.mark.parametrize(
        ("style", "expected_border_style"),
        [("success", "green"), ("invalid_style", "bright_black")],
    )
    @patch("scriptize.assets.python.utilities.cli.panel")
    def test_framed_box_styles(
        self,
        mock_panel: MagicMock,
        _: MagicMock,  # noqa: PT019
        style: str,
        expected_border_style: str,
    ) -> None:
        """Verify framed_box() uses correct and fallback styles."""
        cli.framed_box("content", title="My Box", style=style)  # type: ignore[arg-type]
        mock_panel.assert_called_with(
            "content",
            title="My Box",
            style=expected_border_style,
            title_align="left",
        )

    def test_spinner(self, mock_console: MagicMock) -> None:
        """Verify the spinner context manager calls console.status."""
        with cli.spinner("working..."):
            pass
        mock_console.status.assert_called_once_with(
            cli.Text("working...", style="cyan"),
            spinner="dots",
        )


class TestInteractivePrompts:
    """Tests for interactive prompts, simulating user input."""

    def test_confirm_no(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """Verify confirm() returns False for 'no'."""
        monkeypatch.setattr(Confirm, "ask", lambda *_, **__: False)
        assert cli.confirm("Proceed?") is False

    def test_prompt_with_default(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """Verify prompt() returns the default value."""
        monkeypatch.setattr(Prompt, "ask", lambda *_, **kwargs: kwargs.get("default"))
        result = cli.prompt("Enter value:", default="default_val")
        assert result == "default_val"

    def test_selection_raises_on_empty_choices(self) -> None:
        """Verify selection() raises ValueError for an empty choice list."""
        with pytest.raises(ValueError, match="empty list of choices"):
            cli.selection("Choose one:", [])

    @patch("scriptize.assets.python.utilities.cli.console")
    @patch("scriptize.assets.python.utilities.cli.fatal")
    @patch("scriptize.assets.python.utilities.cli.Live")
    @patch("scriptize.assets.python.utilities.cli._get_key")
    def test_selection_keyboard_interrupt(
        self,
        mock_get_key: MagicMock,  # From @patch("..._get_key")
        _mock_live: MagicMock,  # noqa: PT019, from @patch("...Live")
        mock_fatal: MagicMock,  # From @patch("...fatal")
        mock_console: MagicMock,  # From @patch("...console")
    ) -> None:
        """Verify selection() calls fatal() and show_cursor() on KeyboardInterrupt."""
        mock_get_key.side_effect = KeyboardInterrupt
        cli.selection("Choose one:", ["a", "b"])
        mock_console.show_cursor.assert_called_once_with(show=True)
        mock_fatal.assert_called_once_with("User cancelled operation.", exit_code=0)

    @patch("scriptize.assets.python.utilities.cli.Live")
    @patch("scriptize.assets.python.utilities.cli._logger")
    def test_selection_navigation(
        self,
        mock_logger: MagicMock,
        _mock_live: MagicMock,  # noqa: PT019
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Verify selection() navigates up and down correctly."""
        # Simulate user pressing DOWN, DOWN, UP, ENTER
        keys = ["DOWN", "DOWN", "UP", "ENTER"]
        mock_get_key = MagicMock(side_effect=keys)
        monkeypatch.setattr(cli, "_get_key", mock_get_key)

        choices = ["apple", "banana", "cherry", "date"]
        result = cli.selection("Choose a fruit:", choices)

        assert result == "banana"
        assert mock_logger.log.call_count > 0


class TestInternalHelpers:
    """Tests for internal, non-public helper functions."""

    def test_import_on_windows(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """Verify the 'msvcrt' module is imported on Windows."""
        monkeypatch.setattr(sys, "platform", "win32")
        monkeypatch.setitem(sys.modules, "termios", None)
        monkeypatch.setitem(sys.modules, "tty", None)
        monkeypatch.setitem(sys.modules, "msvcrt", MagicMock())
        reload(cli)

    @patch("sys.stdin")
    @patch("termios.tcsetattr")
    @patch("termios.tcgetattr")
    @patch("tty.setraw")
    def test_get_key_unix(self, *_: MagicMock) -> None:
        """Verify _get_key_unix for all key types."""
        keys = ["\r", "\x1b", "[", "A", "\x1b", "[", "B", "a", "\x03"]
        with patch("sys.stdin.read", side_effect=keys):
            assert cli._get_key_unix() == "ENTER"
            assert cli._get_key_unix() == "UP"
            assert cli._get_key_unix() == "DOWN"
            assert cli._get_key_unix() == ""  # Unhandled key
            with pytest.raises(KeyboardInterrupt):
                cli._get_key_unix()

    def test_get_key_windows_mocked(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """Verify _get_key_windows logic by mocking platform and msvcrt."""
        mock_msvcrt = MagicMock()
        keys = [b"\r", b"\xe0", b"H", b"\xe0", b"P", b"a", b"\x03"]
        mock_msvcrt.getch.side_effect = keys

        monkeypatch.setattr(sys, "platform", "win32")
        monkeypatch.setitem(sys.modules, "msvcrt", mock_msvcrt)

        # FIX: Temporarily hide non-Windows modules to force the ImportError
        monkeypatch.setitem(sys.modules, "termios", None)
        monkeypatch.setitem(sys.modules, "tty", None)

        reload(cli)

        assert cli._get_key_windows() == "ENTER"
        assert cli._get_key_windows() == "UP"
        assert cli._get_key_windows() == "DOWN"
        assert cli._get_key_windows() == ""  # Unhandled key
        with pytest.raises(KeyboardInterrupt):
            cli._get_key_windows()

        # Clean up by undoing patches and reloading the module
        monkeypatch.undo()
        reload(cli)

    @patch("scriptize.assets.python.utilities.cli._get_key_unix")
    @patch("scriptize.assets.python.utilities.cli._get_key_windows")
    def test_get_key_dispatcher(
        self,
        mock_get_key_windows: MagicMock,
        mock_get_key_unix: MagicMock,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Verify _get_key() dispatches to the correct OS-specific function."""
        monkeypatch.setitem(sys.modules, "msvcrt", MagicMock())
        cli._get_key()
        mock_get_key_windows.assert_called_once()
        mock_get_key_unix.assert_not_called()

        monkeypatch.delitem(sys.modules, "msvcrt")
        cli._get_key()
        mock_get_key_unix.assert_called_once()
