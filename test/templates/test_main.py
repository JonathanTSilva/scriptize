# ruff: noqa: S101
"""Tests for the generated Python script template (`assets/python/main.py`)."""

import logging
import runpy
from pathlib import Path

import pytest

from scriptize.assets.python import main as template_main
from scriptize.logger import log_manager


class TestMain:
    """Tests for the template's `main()`."""

    def test_main_configures_logging_and_logs(
        self, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
    ) -> None:
        """main() points logging at the template-local config and emits its messages."""
        seen: list[Path] = []
        monkeypatch.setattr(
            template_main,
            "setup_logging",
            lambda config_path: seen.append(config_path),  # noqa: PLW0108
        )

        with caplog.at_level(logging.DEBUG):
            template_main.main()

        assert seen == [template_main.BASE_DIR / "logging_config.json"]
        assert "Python script started successfully." in caplog.text
        assert "Script finished." in caplog.text
        error = next(r for r in caplog.records if r.levelno == logging.ERROR)
        assert error.extra_data == {"code": 123}  # type: ignore[attr-defined]

    def test_runs_as_script(self, monkeypatch: pytest.MonkeyPatch) -> None:
        """Executing the file as `__main__` invokes `main()`."""
        calls: list[Path] = []
        monkeypatch.setattr(
            log_manager,
            "setup_logging",
            lambda config_path: calls.append(config_path),  # noqa: PLW0108
        )

        runpy.run_path(str(Path(template_main.__file__)), run_name="__main__")

        assert len(calls) == 1
