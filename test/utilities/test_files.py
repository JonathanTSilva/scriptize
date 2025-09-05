# ruff: noqa: S101
"""Tests for the files utility module.

This test suite covers path manipulation, file I/O for plain text and
structured data (JSON, YAML), file system operations, and content analysis.
It uses fixtures for clean, isolated test execution in a temporary directory.
"""

import random
import shutil
import sys
from importlib import reload
from pathlib import Path
from typing import TYPE_CHECKING
from unittest.mock import MagicMock, patch

import pytest

from scriptize.assets.python.utilities import files

if TYPE_CHECKING:
    from scriptize.assets.python.utilities.files import DataType


class TestPathInformation:
    """Tests for path information helper functions."""

    def test_get_name(self) -> None:
        """Verify get_name() extracts the full filename."""
        assert files.get_name("/home/user/archive.tar.gz") == "archive.tar.gz"
        assert files.get_name("README") == "README"

    def test_get_basename(self) -> None:
        """Verify get_basename() extracts the filename without the final extension."""
        assert files.get_basename("/home/user/document.txt") == "document"
        assert files.get_basename("archive.tar.gz") == "archive.tar"

    def test_get_extension(self) -> None:
        """Verify get_extension() extracts the final file extension."""
        assert files.get_extension("image.jpeg") == ".jpeg"
        assert files.get_extension("archive.tar.gz") == ".gz"
        assert files.get_extension("README") == ""

    def test_get_parent(self) -> None:
        """Verify get_parent() returns the parent directory as a Path object."""
        assert files.get_parent("/home/user/document.txt") == Path("/home/user")
        assert files.get_parent("local_file.txt") == Path()


class TestFileIO:
    """Tests for reading and writing files (text, JSON, YAML)."""

    def test_read_write_file(self, tmp_path: Path) -> None:
        """Verify that file content can be written and read back correctly."""
        file_path = tmp_path / "test.txt"
        content = "Hello, World!\n你好, 世界"
        files.write_file(file_path, content)
        assert file_path.read_text("utf-8") == content
        assert files.read_file(file_path) == content

    def test_read_file_not_found(self) -> None:
        """Verify read_file() raises FileNotFoundError for non-existent files."""
        with pytest.raises(FileNotFoundError):
            files.read_file("non_existent_file_12345.tmp")

    def test_read_write_json(self, tmp_path: Path) -> None:
        """Verify that JSON data can be written and read back correctly."""
        file_path = tmp_path / "data.json"
        data: DataType = {"user": "test", "id": 123, "settings": ["a", "b"]}
        files.write_json(file_path, data)
        read_data = files.read_json(file_path)
        assert read_data == data

    @pytest.mark.skipif(files.yaml is None, reason="PyYAML is not installed")
    def test_read_write_yaml(self, tmp_path: Path) -> None:
        """Verify that YAML data can be written and read back correctly."""
        file_path = tmp_path / "config.yaml"
        data: DataType = {"user": "test", "id": 123, "settings": ["a", "b"]}
        files.write_yaml(file_path, data)
        read_data = files.read_yaml(file_path)
        assert read_data == data

    def test_yaml_functions_raise_importerror_if_missing(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Verify YAML functions raise ImportError if PyYAML is not available."""
        monkeypatch.setattr(files, "yaml", None)
        with pytest.raises(ImportError, match="PyYAML is required"):
            files.read_yaml("dummy.yaml")
        with pytest.raises(ImportError, match="PyYAML is required"):
            files.write_yaml("dummy.yaml", {})

    def test_yaml_module_is_none_on_import_error(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        """Verify the module-level 'yaml' is None if PyYAML can't be imported."""
        # Simulate the 'yaml' module not being installed
        monkeypatch.setitem(sys.modules, "yaml", None)

        # Reload the 'files' module to trigger its top-level import logic
        reload(files)

        # Assert that the module correctly set its internal 'yaml' variable to None
        assert files.yaml is None

        # Restore the module's original state for other tests
        monkeypatch.undo()
        reload(files)


class TestFileOperations:
    """Tests for file system operations like backup, symlink, and listing."""

    def test_backup_file_with_suffix(self, tmp_path: Path) -> None:
        """Verify backup_file() creates a backup with a custom suffix."""
        original_file = tmp_path / "original.txt"
        original_file.write_text("data")
        backup_path = files.backup_file(original_file, suffix=".bak")
        assert backup_path.name == "original.txt.bak"
        assert backup_path.read_text() == "data"
        assert backup_path.exists()

    def test_backup_file_with_timestamp(self, tmp_path: Path) -> None:
        """Verify backup_file() creates a backup with a timestamp."""
        original_file = tmp_path / "report.log"
        original_file.write_text("log data")
        backup_path = files.backup_file(original_file)
        assert backup_path.name.startswith("report.log.")
        assert backup_path.name.endswith(".bak")
        assert backup_path.exists()

    def test_backup_file_not_found(self) -> None:
        """Verify backup_file() raises FileNotFoundError for non-existent files."""
        with pytest.raises(FileNotFoundError):
            files.backup_file("non_existent_file_12345.tmp")

    pytest.mark.skipif(sys.platform == "win32", reason="Symlink tests flaky on Windows")

    def test_create_symlink(self, tmp_path: Path) -> None:
        """Verify symlink creation, overwrite, and error handling."""
        target = tmp_path / "target.txt"
        target.write_text("target data")
        link = tmp_path / "link.txt"
        files.create_symlink(target, link)
        assert link.is_symlink()
        assert link.read_text() == "target data"
        with pytest.raises(FileExistsError):
            files.create_symlink(target, link, overwrite=False)

        link.unlink()  # Clean up the symlink
        file_as_link = tmp_path / "link.txt"
        file_as_link.write_text("i am a file")
        files.create_symlink(target, file_as_link, overwrite=True)
        assert file_as_link.is_symlink()
        assert file_as_link.read_text() == "target data"

        # Test overwriting a directory
        link.unlink()
        dir_as_link = tmp_path / "link.txt"
        dir_as_link.mkdir()
        files.create_symlink(target, dir_as_link, overwrite=True)
        assert dir_as_link.is_symlink()
        assert not dir_as_link.is_dir()

    def test_create_symlink_missing_target(self, tmp_path: Path) -> None:
        """Verify create_symlink() raises FileNotFoundError for a missing target."""
        with pytest.raises(FileNotFoundError):
            files.create_symlink("missing_target.txt", tmp_path / "link.txt")

    def test_list_files(self, tmp_path: Path) -> None:
        """Verify list_files() finds correct files and ignores subdirectories."""
        (tmp_path / "a.txt").touch()
        (tmp_path / "b.log").touch()
        (tmp_path / "c.txt").touch()
        sub_dir = tmp_path / "sub"
        sub_dir.mkdir()
        (sub_dir / "d.txt").touch()

        # Find all .txt files non-recursively
        found_files = sorted([p.name for p in files.list_files(tmp_path, "*.txt")])
        assert found_files == ["a.txt", "c.txt"]

    def test_extract_archive_to_default_location(self, tmp_path: Path) -> None:
        """Verify extract_archive() extracts to the parent dir when no dest is given."""
        src_dir = tmp_path / "source"
        src_dir.mkdir()
        (src_dir / "content.txt").write_text("default data")

        # Create the archive inside the temp path
        archive_path_str = shutil.make_archive(
            str(tmp_path / "archive"),
            "zip",
            root_dir=src_dir,
        )

        # Call the function WITHOUT a destination
        files.extract_archive(archive_path_str)

        # The content should be in the archive's parent folder (tmp_path)
        extracted_file = tmp_path / "content.txt"
        assert extracted_file.is_file()
        assert extracted_file.read_text() == "default data"

    def test_create_temp_file(self) -> None:
        """Verify create_temp_file() creates a persistent temporary file."""
        temp_file = files.create_temp_file(prefix="test_", suffix=".log")
        assert temp_file.exists()
        assert temp_file.name.startswith("test_")
        assert temp_file.name.endswith(".log")
        # Clean up the manually managed temp file
        temp_file.unlink()


class TestFileContentAnalysis:
    """Tests for functions that analyze the content of files."""

    def test_file_contains(self, tmp_path: Path) -> None:
        """Verify file_contains() correctly finds or misses substrings."""
        file_path = tmp_path / "test.txt"
        file_path.write_text("line one\nline two\nline three")
        assert files.file_contains(file_path, "two")
        assert not files.file_contains(file_path, "four")
        # Test edge case where file does not exist
        assert not files.file_contains("non_existent_file.xyz", "text")

        # Test for UnicodeDecodeError
        invalid_utf8_file = tmp_path / "invalid.txt"
        invalid_utf8_file.write_bytes(b"\x80abc")  # Invalid start byte for UTF-8
        assert not files.file_contains(invalid_utf8_file, "abc")

    def test_random_line(self, tmp_path: Path) -> None:
        """Verify random_line() selects a predictable line with a fixed seed."""
        file_path = tmp_path / "lines.txt"
        file_path.write_text("one\ntwo\nthree")
        # Seeding random makes the choice deterministic for the test
        random.seed(42)
        assert files.random_line(file_path) == "three"

        # Test empty file
        empty_file = tmp_path / "empty.txt"
        empty_file.touch()
        assert files.random_line(empty_file) is None
        assert files.random_line("non_existent_file.xyz") is None

    @patch("random.randrange", return_value=1)
    def test_random_line_branch_coverage(
        self,
        _mock_randrange: "MagicMock",  # noqa: PT019
        tmp_path: Path,
    ) -> None:
        """Verify the 'continue' branch in random_line() is covered."""
        file_path = tmp_path / "lines.txt"
        file_path.write_text("one\ntwo\nthree")
        # With randrange always returning a truthy value, the first line is kept.
        assert files.random_line(file_path) == "one"
