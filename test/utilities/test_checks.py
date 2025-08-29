# test/utilities/test_checks.py

# ruff: noqa: S101, FBT001
"""Tests for the checks utility module."""

import io
import os
import shutil
import sys
from collections.abc import Iterator
from importlib import reload
from pathlib import Path
from unittest.mock import MagicMock

import pytest

# Platform-specific import for the is_root test
if sys.platform == "win32":
    import ctypes

from scriptize.assets.python.utilities import checks


@pytest.fixture(scope="module")
def temp_fs() -> Iterator[dict[str, Path]]:
    """Pytest fixture to create a temporary directory and file for testing."""
    temp_dir = Path("test_temp_dir")
    temp_file = temp_dir / "test_temp_file.txt"

    # Setup: Create directory and file
    temp_dir.mkdir(exist_ok=True)
    temp_file.touch()

    yield {"dir": temp_dir, "file": temp_file}

    # Teardown: Clean up the created directory and its contents
    shutil.rmtree(temp_dir)


class TestSystemChecks:
    """Tests for system and command validation functions."""

    def test_command_exists(self) -> None:
        """Verify command existence check."""
        assert checks.command_exists("python")
        assert not checks.command_exists("nonexistent_command_12345")

    def test_is_root(self) -> None:
        """Verify root/admin privilege check matches the OS's report."""
        if sys.platform == "win32":
            expected = ctypes.windll.shell32.IsUserAnAdmin() != 0
        else:
            expected = os.geteuid() == 0
        assert checks.is_root() == expected

    def test_is_internet_available(self) -> None:
        """Verify internet connectivity check (only tests the failure case reliably)."""
        # This test should always fail as it points to a reserved, non-routable address.
        assert not checks.is_internet_available(host="192.0.2.0", timeout=1)

    def test_is_terminal(self) -> None:
        """Verify terminal/TTY check matches the system's report."""
        # When run via pytest, this is typically False.
        assert checks.is_terminal() == sys.stdout.isatty()


class TestFileSystemChecks:
    """Tests for file system path validation functions."""

    def test_is_file(self, temp_fs: dict[str, Path]) -> None:
        """Verify file identification."""
        assert checks.is_file(temp_fs["file"])
        assert not checks.is_file(temp_fs["dir"])
        assert not checks.is_file("non_existent_path.xyz")

    def test_is_dir(self, temp_fs: dict[str, Path]) -> None:
        """Verify directory identification."""
        assert checks.is_dir(temp_fs["dir"])
        assert not checks.is_dir(temp_fs["file"])
        assert not checks.is_dir("non_existent_dir/")


class TestDataFormatValidation:
    """Tests for data format and type validation functions."""

    @pytest.mark.parametrize(
        ("email", "expected"),
        [
            ("test@example.com", True),
            ("not-an-email", False),
            ("test@localhost", False),
        ],
    )
    def test_is_email(self, email: str, expected: bool) -> None:
        """Test the is_email function with various inputs."""
        assert checks.is_email(email) == expected

    @pytest.mark.parametrize(
        ("ip", "expected"),
        [
            ("192.168.1.1", True),
            ("256.0.0.0", False),
            ("not-an-ip", False),
        ],
    )
    def test_is_ipv4(self, ip: str, expected: bool) -> None:
        """Test the is_ipv4 function with various inputs."""
        assert checks.is_ipv4(ip) == expected

    @pytest.mark.parametrize(
        ("ip", "expected"),
        [
            ("2001:0db8:85a3:0000:0000:8a2e:0370:7334", True),
            ("::1", True),
            ("not-an-ipv6", False),
            ("1234::5678::9abc", False),  # Invalid double colon
        ],
    )
    def test_is_ipv6(self, ip: str, expected: bool) -> None:
        """Test the is_ipv6 function with various inputs."""
        assert checks.is_ipv6(ip) == expected

    @pytest.mark.parametrize(
        ("domain", "expected"),
        [
            ("google.com", True),
            ("a.b.c.co.uk", True),
            ("not_a_domain", False),
        ],
    )
    def test_is_fqdn(self, domain: str, expected: bool) -> None:
        """Test the is_fqdn function with various inputs."""
        assert checks.is_fqdn(domain) == expected

    @pytest.mark.parametrize(
        ("value", "expected"),
        [
            (123, True),
            (-45.67, True),
            ("99.9", True),
            ("-20", True),
            ("abc", False),
            (None, False),
            ([1, 2], False),
        ],
    )
    def test_is_numeric(self, value: checks.AcceptableTypes, expected: bool) -> None:
        """Test the is_numeric function with various inputs."""
        assert checks.is_numeric(value) == expected


class TestBooleanValueChecks:
    """Tests for boolean and emptiness value checks."""

    @pytest.mark.parametrize(
        ("value", "expected"),
        [
            ("true", True),
            ("Yes", True),
            ("1", True),
            (1, True),
            (True, True),
            ("false", False),
            (0, False),
            (None, False),
            ([], False),
        ],
    )
    def test_is_true(self, value: checks.AcceptableTypes, expected: bool) -> None:
        """Test the is_true function with various inputs."""
        assert checks.is_true(value) == expected

    @pytest.mark.parametrize(
        ("value", "expected"),
        [
            (None, True),
            ("", True),
            ([], True),
            ({}, True),
            (set(), True),
            ("hello", False),
            ([1, 2, 3], False),
            (0, False),
            (False, False),
        ],
    )
    def test_is_empty(self, value: checks.AcceptableTypes, expected: bool) -> None:
        """Test the is_empty function with various inputs."""
        assert checks.is_empty(value) == expected


class TestMockedAndEdgeCases:
    """Tests for edge cases requiring mocking, such as platform or dependency issues."""

    def test_is_root_on_windows(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """Test the is_root function by simulating a Windows environment."""
        monkeypatch.setattr(sys, "platform", "win32")
        mock_ctypes = MagicMock()
        monkeypatch.setitem(sys.modules, "ctypes", mock_ctypes)

        reload(checks)
        # Simulate being an admin
        mock_ctypes.windll.shell32.IsUserAnAdmin.return_value = 1
        assert checks.is_root()

        # Simulate not being an admin
        mock_ctypes.windll.shell32.IsUserAnAdmin.return_value = 0
        assert not checks.is_root()

        monkeypatch.undo()

        reload(checks)

    def test_internet_available_success(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """Test the success path of is_internet_available by mocking the socket."""
        mock_socket = MagicMock()
        monkeypatch.setattr(checks.socket, "socket", mock_socket)
        # Ensure the connect call on the socket instance does nothing (succeeds)
        mock_socket.return_value.__enter__.return_value.connect.return_value = None

        assert checks.is_internet_available()

    def test_missing_validators_dependency(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """Test the applications exits if the 'validators' library is missing."""
        # Hide the real 'validators' module
        monkeypatch.setitem(sys.modules, "validators", None)

        mock_stderr = io.StringIO()
        monkeypatch.setattr(sys, "stderr", mock_stderr)

        with pytest.raises(SystemExit) as excinfo:
            reload(checks)  # Re-run the module's import logic

        assert excinfo.value.code == 1
        assert "'validators' library is required" in mock_stderr.getvalue()
