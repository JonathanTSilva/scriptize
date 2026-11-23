# ruff: noqa: S101, SLF001
"""Tests for the project scaffolding builder."""

import json
import stat
from pathlib import Path

import pytest

from scriptize.core import builder, paths


class TestCreateProjectLoggingConfig:
    """Tests for `create_project_logging_config()`."""

    def test_writes_project_named_config(self, tmp_path: Path) -> None:
        """The config file points the file handler at the project's own log."""
        builder.create_project_logging_config(tmp_path, "demo")

        config = json.loads((tmp_path / "logging_config.json").read_text(encoding="utf-8"))
        assert config["version"] == 1
        assert config["handlers"]["file"]["filename"] == "logs/demo.log.jsonl"
        assert config["root"]["handlers"] == ["console", "file"]

    def test_creates_missing_parent_directory(self, tmp_path: Path) -> None:
        """A project directory that does not exist yet is created."""
        project_dir = tmp_path / "a" / "b"
        builder.create_project_logging_config(project_dir, "demo")
        assert (project_dir / "logging_config.json").is_file()

    def test_oserror_is_logged_and_reraised(
        self, tmp_path: Path, caplog: pytest.LogCaptureFixture
    ) -> None:
        """A write failure is logged and propagates so the build halts."""
        blocker = tmp_path / "not_a_dir"
        blocker.write_text("file", encoding="utf-8")

        with pytest.raises(OSError):  # noqa: PT011
            builder.create_project_logging_config(blocker, "demo")
        assert "Failed to create logging configuration" in caplog.text


class TestMakeExecutable:
    """Tests for `_make_executable()`."""

    def test_adds_user_execute_bit(self, tmp_path: Path) -> None:
        """The owner execute bit is set and other bits are kept."""
        script = tmp_path / "run.sh"
        script.write_text("#!/bin/sh\n", encoding="utf-8")
        script.chmod(0o644)

        builder._make_executable(script)

        mode = script.stat().st_mode
        assert mode & stat.S_IXUSR
        assert mode & stat.S_IRGRP

    def test_missing_file_only_warns(
        self, tmp_path: Path, caplog: pytest.LogCaptureFixture
    ) -> None:
        """A chmod failure is downgraded to a warning."""
        builder._make_executable(tmp_path / "missing.sh")
        assert "Could not set executable permission" in caplog.text


class TestBuildProject:
    """Tests for `build_project()`."""

    def test_builds_bash_and_python(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        """By default both template flavours are scaffolded and renamed."""
        builder.build_project("demo", tmp_path)

        project = tmp_path / "demo"
        assert (project / "logging_config.json").is_file()
        script = project / "bash" / "demo.sh"
        assert script.is_file()
        assert script.stat().st_mode & stat.S_IXUSR
        assert not (project / "bash" / "template.sh").exists()
        assert (project / "python" / "demo.py").is_file()
        assert not (project / "python" / "main.py").exists()

        out = capsys.readouterr().out
        assert "Your new project is ready" in out
        assert f"cd {project}" in out

    def test_bash_only(self, tmp_path: Path) -> None:
        """Skipping Python leaves only the Bash template."""
        builder.build_project("demo", tmp_path, include_python=False)
        assert (tmp_path / "demo" / "bash").is_dir()
        assert not (tmp_path / "demo" / "python").exists()

    def test_python_only(self, tmp_path: Path) -> None:
        """Skipping Bash leaves only the Python template."""
        builder.build_project("demo", tmp_path, include_bash=False)
        assert (tmp_path / "demo" / "python").is_dir()
        assert not (tmp_path / "demo" / "bash").exists()

    def test_existing_directory_is_rejected_untouched(self, tmp_path: Path) -> None:
        """An existing target is never overwritten or cleaned up."""
        existing = tmp_path / "demo"
        existing.mkdir()
        (existing / "keep.txt").write_text("keep", encoding="utf-8")

        with pytest.raises(FileExistsError, match="already exists"):
            builder.build_project("demo", tmp_path)
        assert (existing / "keep.txt").read_text(encoding="utf-8") == "keep"

    def test_failure_cleans_up_partial_project(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        """A failing copy removes the half-built directory and re-raises."""
        missing_template = tmp_path / "no-such-template"
        monkeypatch.setattr(paths, "BASH_TEMPLATE_DIR", missing_template)

        with pytest.raises(OSError):  # noqa: PT011
            builder.build_project("demo", tmp_path)

        assert not (tmp_path / "demo").exists()
        assert "Cleaning up failed build directory" in caplog.text
