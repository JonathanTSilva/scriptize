# test/utils/test_new_script.py

# ruff: noqa: S101, S603, S607
"""Tests for the new-script helper that scaffolds Bash and Python scripts."""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
NEW_SCRIPT = REPO_ROOT / "scriptize" / "utils" / "new-script"

pytestmark = pytest.mark.skipif(shutil.which("bash") is None, reason="bash is required")


def _run(tmp_path: Path, *args: str) -> subprocess.CompletedProcess[str]:
    """Run new-script in tmp_path, pointing it at this checkout instead of /etc."""
    config = tmp_path / "config"
    config.write_text(f"TEMPLATE_REPO_PATH={REPO_ROOT}\n", encoding="utf-8")
    env = {**os.environ, "SCRIPTIZE_CONFIG": str(config)}
    return subprocess.run(
        ["bash", str(NEW_SCRIPT), *args],
        cwd=tmp_path,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


def test_bash_scaffold(tmp_path: Path) -> None:
    """A Bash project gets an executable script and a utilities link."""
    result = _run(tmp_path, "bash", "demo")

    assert result.returncode == 0, result.stderr
    script = tmp_path / "demo" / "demo.sh"
    assert script.is_file()
    assert os.access(script, os.X_OK)
    assert (tmp_path / "demo" / "utilities" / "alerts.bash").is_file()


def test_python_scaffold(tmp_path: Path) -> None:
    """A Python project gets an executable script and a utilities link."""
    result = _run(tmp_path, "python", "demo")

    assert result.returncode == 0, result.stderr
    script = tmp_path / "demo" / "demo.py"
    assert script.is_file()
    assert os.access(script, os.X_OK)
    assert (tmp_path / "demo" / "utilities" / "shell.py").is_file()


def test_generated_bash_script_runs(tmp_path: Path) -> None:
    """The generated Bash script sources its utilities and runs to the end."""
    assert _run(tmp_path, "bash", "demo").returncode == 0

    result = subprocess.run(
        [str(tmp_path / "demo" / "demo.sh"), f"--logfile={tmp_path / 'log.txt'}"],
        cwd=tmp_path / "demo",
        env={**os.environ, "TERM": "xterm-256color"},
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    assert "This is success text" in result.stdout + result.stderr


def test_unknown_type_is_rejected_and_cleaned_up(tmp_path: Path) -> None:
    """An invalid type fails and leaves no directory behind."""
    result = _run(tmp_path, "ruby", "demo")

    assert result.returncode == 1
    assert "Invalid type" in result.stderr
    assert not (tmp_path / "demo").exists()


def test_existing_directory_is_refused(tmp_path: Path) -> None:
    """new-script never overwrites an existing directory."""
    (tmp_path / "demo").mkdir()

    result = _run(tmp_path, "bash", "demo")

    assert result.returncode == 1
    assert "already exists" in result.stdout + result.stderr
