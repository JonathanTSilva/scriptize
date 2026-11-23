# ruff: noqa: S101, SLF001
"""Tests for the logging setup shared by the tool and the generated Python template.

The tool (`scriptize.logger.log_manager`) and the template copy
(`scriptize.assets.python.utilities.log_manager`) only differ in their default
log file name, so every test runs against both.
"""

import atexit
import json
import logging
from collections.abc import Iterator
from logging.handlers import QueueHandler
from pathlib import Path
from types import ModuleType

import pytest

from scriptize.assets.python.utilities import log_manager as template_log_manager
from scriptize.logger import log_manager as tool_log_manager

MODULES = [
    pytest.param(tool_log_manager, id="tool"),
    pytest.param(template_log_manager, id="template"),
]


@pytest.fixture(params=MODULES)
def lm(request: pytest.FixtureRequest) -> ModuleType:
    """Provide each log_manager module in turn."""
    return request.param


@pytest.fixture
def isolated_logging(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Iterator[list[object]]:
    """Run in a temp cwd, restore the root logger, and capture atexit registrations."""
    monkeypatch.chdir(tmp_path)
    registered: list[object] = []
    monkeypatch.setattr(atexit, "register", lambda func, *_a, **_k: registered.append(func))

    root = logging.getLogger()
    saved_handlers = list(root.handlers)
    saved_level = root.level
    yield registered
    for handler in list(root.handlers):
        root.removeHandler(handler)
    for handler in saved_handlers:
        root.addHandler(handler)
    root.setLevel(saved_level)
    # Stop any listener started by the test so no thread outlives it.
    for func in registered:
        func()  # type: ignore[operator]


def _record(**kwargs: object) -> logging.LogRecord:
    record = logging.LogRecord("t", logging.INFO, __file__, 10, "msg", None, None)
    for key, value in kwargs.items():
        setattr(record, key, value)
    return record


class TestFormatters:
    """Tests for the console and JSON formatters."""

    def test_rich_console_formatter_keeps_markup(self, lm: ModuleType) -> None:
        """The message is passed through untouched, markup included."""
        record = logging.LogRecord("t", logging.INFO, "f", 1, "[bold]%s[/]", ("x",), None)
        assert lm.RichConsoleFormatter().format(record) == "[bold]x[/]"

    def test_json_formatter_core_fields(self, lm: ModuleType) -> None:
        """Rich markup is stripped and the standard fields are present."""
        record = _record(msg="[red]boom[/red]")
        data = json.loads(lm.JSONFormatter().format(record))
        assert data["message"] == "boom"
        assert data["level"] == "INFO"
        assert data["line"] == 10  # noqa: PLR2004
        assert data["function"] == record.funcName
        assert "timestamp" in data
        assert data["process"] == record.process
        assert "exception" not in data

    def test_json_formatter_skips_missing_optional_fields(self, lm: ModuleType) -> None:
        """Optional fields that are None are left out."""
        record = _record(taskName=None)
        assert "taskName" not in json.loads(lm.JSONFormatter().format(record))

    def test_json_formatter_merges_extra_data(self, lm: ModuleType) -> None:
        """`extra_data` is merged into the top-level object."""
        record = _record(extra_data={"code": 123})
        assert json.loads(lm.JSONFormatter().format(record))["code"] == 123  # noqa: PLR2004

    def test_json_formatter_includes_exception(self, lm: ModuleType) -> None:
        """Exception details are serialised under `exception`."""
        try:
            msg = "bad"
            raise ValueError(msg)  # noqa: TRY301
        except ValueError:
            import sys  # noqa: PLC0415

            record = _record(exc_info=sys.exc_info())
        data = json.loads(lm.JSONFormatter().format(record))
        assert "ValueError: bad" in data["exception"]

    @pytest.mark.parametrize(("flag", "expected"), [(True, False), (False, True)])
    def test_console_only_filter(self, lm: ModuleType, flag: bool, expected: bool) -> None:  # noqa: FBT001
        """Records flagged console_only are dropped, others pass."""
        assert lm.ConsoleOnlyFilter().filter(_record(console_only=flag)) is expected

    def test_console_only_filter_default_passes(self, lm: ModuleType) -> None:
        """Records without the flag are kept."""
        assert lm.ConsoleOnlyFilter().filter(_record()) is True


class TestEnsureLogDir:
    """Tests for the path-traversal guard in `_ensure_log_dir()`."""

    def test_creates_directory_inside_cwd(
        self, lm: ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """A relative log directory is created under the working directory."""
        monkeypatch.chdir(tmp_path)
        lm._ensure_log_dir(Path("logs/app.log"))
        assert (tmp_path / "logs").is_dir()

    def test_does_not_create_directory_outside_cwd(
        self,
        lm: ModuleType,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        """A missing directory outside the cwd is left alone and a warning is logged."""
        cwd = tmp_path / "work"
        cwd.mkdir()
        monkeypatch.chdir(cwd)
        outside = tmp_path / "elsewhere" / "app.log"

        lm._ensure_log_dir(outside)

        assert not outside.parent.exists()
        assert "outside the working directory" in caplog.text

    def test_existing_directory_outside_cwd_is_accepted(
        self,
        lm: ModuleType,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        """An existing external directory produces no warning."""
        cwd = tmp_path / "work"
        cwd.mkdir()
        external = tmp_path / "external"
        external.mkdir()
        monkeypatch.chdir(cwd)

        lm._ensure_log_dir(external / "app.log")

        assert "outside the working directory" not in caplog.text


class TestSetupLogging:
    """Tests for `setup_logging()`."""

    def test_default_config_writes_json_log(
        self, lm: ModuleType, isolated_logging: list[object], tmp_path: Path
    ) -> None:
        """Without a config file the defaults log through a queue to a JSON file."""
        lm.setup_logging(default_level="debug")

        root = logging.getLogger()
        assert len(root.handlers) == 1
        assert isinstance(root.handlers[0], QueueHandler)
        assert len(isolated_logging) == 1

        logging.getLogger("demo").info("hello", extra={"extra_data": {"k": "v"}})
        logging.getLogger("demo").info("hidden", extra={"console_only": True})
        isolated_logging[0]()  # type: ignore[operator]  # stop the listener to flush

        logs = list((tmp_path / "logs").glob("*.jsonl")) + list((tmp_path / "logs").glob("*.json"))
        assert len(logs) == 1
        messages = [json.loads(line)["message"] for line in logs[0].read_text().splitlines()]
        assert "hello" in messages
        assert "hidden" not in messages

    def test_default_log_file_names_differ(self, lm: ModuleType) -> None:
        """Documents the one intended difference between the two copies."""
        filename = lm.DEFAULT_LOGGING_CONFIG["handlers"]["file"]["filename"]
        expected = "logs/scriptize.log.jsonl" if lm is tool_log_manager else "logs/app.log.json"
        assert filename == expected

    def test_console_level_is_overridden(
        self, lm: ModuleType, isolated_logging: list[object]
    ) -> None:
        """`default_level` sets the console handler level (upper-cased)."""
        lm.setup_logging(default_level="warning")
        listener = isolated_logging[0].__self__  # type: ignore[attr-defined]
        console = [h for h in listener.handlers if h.get_name() == "console"]
        assert console[0].level == logging.WARNING

    def test_loads_config_file(
        self, lm: ModuleType, isolated_logging: list[object], tmp_path: Path
    ) -> None:
        """A valid JSON config replaces the defaults, including the log file."""
        config = json.loads(json.dumps(lm.DEFAULT_LOGGING_CONFIG, default=str))
        config["formatters"] = {"plain": {"format": "%(message)s"}}
        config["filters"] = {}
        config["handlers"]["console"]["formatter"] = "plain"
        config["handlers"]["file"]["formatter"] = "plain"
        config["handlers"]["file"].pop("filters")
        config["handlers"]["file"]["filename"] = "custom/out.log"
        config_path = tmp_path / "cfg.json"
        config_path.write_text(json.dumps(config), encoding="utf-8")

        lm.setup_logging(config_path=str(config_path))

        assert (tmp_path / "custom").is_dir()
        assert isolated_logging

    def test_missing_config_falls_back_to_defaults(
        self,
        lm: ModuleType,
        isolated_logging: list[object],
        tmp_path: Path,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        """A missing config file only warns and the defaults are used."""
        lm.setup_logging(config_path=tmp_path / "nope.json")
        assert "not found" in caplog.text
        assert (tmp_path / "logs").is_dir()
        assert isolated_logging

    def test_invalid_json_falls_back_to_defaults(
        self,
        lm: ModuleType,
        isolated_logging: list[object],
        tmp_path: Path,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        """A config file that is not valid JSON is logged and the defaults are used."""
        bad = tmp_path / "bad.json"
        bad.write_text("{not json", encoding="utf-8")

        lm.setup_logging(config_path=bad)

        assert "Failed to parse config file" in caplog.text
        assert (tmp_path / "logs").is_dir()
        assert isolated_logging

    def test_config_without_handlers_is_accepted(
        self, lm: ModuleType, isolated_logging: list[object], tmp_path: Path
    ) -> None:
        """A config with no console/file handlers skips the level and directory steps."""
        config_path = tmp_path / "minimal.json"
        config_path.write_text(
            json.dumps({"version": 1, "disable_existing_loggers": False}), encoding="utf-8"
        )

        lm.setup_logging(config_path=config_path)

        assert not (tmp_path / "logs").exists()
        assert isolated_logging
