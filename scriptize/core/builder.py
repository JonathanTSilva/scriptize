"""Core builder module for the Scriptize application.

This module is responsible for scaffolding new Bash and/or Python projects
from the bundled templates. It handles directory creation, template copying,
and the generation of project-specific logging configurations.
"""

import json
import logging
import shutil
import stat
from pathlib import Path

# Import the centralized path constants.
from . import paths

# Use a logger specific to this module.
_logger = logging.getLogger(__name__)


def create_project_logging_config(project_dir: Path, project_name: str) -> None:
    """Creates a project-specific logging_config.json in the new project's directory.

    This configuration file directs all log output from the generated scripts
    to a dedicated, project-named .jsonl file inside its own 'logs' directory.

    Args:
        project_dir: The root directory of the new project.
        project_name: The name of the new project, used for the log filename.
    """
    log_filename = f"logs/{project_name}.log.jsonl"
    config_path = project_dir / "logging_config.json"

    # Define the configuration structure for the new project.
    logging_config = {
        "version": 1,
        "disable_existing_loggers": False,
        "formatters": {
            "json_file_formatter": {
                "()": "scriptize.logger.log_manager.JSONFormatter",
                "datefmt": "%Y-%m-%dT%H:%M:%S%z",
            },
            "console_formatter": {"format": "%(message)s"},
        },
        "handlers": {
            "file": {
                "class": "logging.handlers.RotatingFileHandler",
                "level": "DEBUG",
                "formatter": "json_file_formatter",
                "filename": log_filename,
                "maxBytes": 10485760,  # 10 MB
                "backupCount": 5,
                "encoding": "utf8",
            },
            "console": {
                "class": "rich.logging.RichHandler",
                "level": "INFO",
                "formatter": "console_formatter",
                "rich_tracebacks": True,
                "show_path": False,
                "show_time": False,
                "show_level": False,
                "markup": True,
            },
        },
        "root": {"level": "DEBUG", "handlers": ["console", "file"]},
    }

    _logger.info("Generating project-specific logging config at '%s'", config_path)
    try:
        # Create the directory and write the config file atomically.
        config_path.parent.mkdir(parents=True, exist_ok=True)
        with config_path.open("w", encoding="utf-8") as f:
            json.dump(logging_config, f, indent=4)
    except OSError:
        _logger.exception("Failed to create logging configuration")
        # Re-raise to halt the build process if logging can't be set up.
        raise


def _make_executable(file_path: Path) -> None:
    """Makes a file executable by adding the user execute permission."""
    try:
        # Get current permissions and add the execute bit for the owner.
        current_permissions = file_path.stat().st_mode
        file_path.chmod(current_permissions | stat.S_IXUSR)
        _logger.debug("Made file executable: %s", file_path)
    except OSError as e:
        _logger.warning("Could not set executable permission on '%s': %s", file_path, e)


def build_project(
    project_name: str,
    destination: Path,
    *,
    include_bash: bool = True,
    include_python: bool = True,
) -> None:
    """Scaffolds a new scripting project in the specified destination directory.

    Args:
        project_name: The name for the new project. This will be the directory name.
        destination: The parent directory where the project will be created.
        include_bash: Whether to include the Bash script template and utilities.
        include_python: Whether to include the Python script template.

    Raises:
        FileExistsError: If the target project directory already exists.
        IOError: If there is a problem creating directories or writing files.
    """
    project_dir = destination / project_name
    _logger.info("Starting new project build: '%s' at '%s'", project_name, project_dir)

    # 1. Pre-flight Check: Ensure the destination does not already exist.
    if project_dir.exists():
        # Assign the error message to a variable first to satisfy linters.
        error_msg = (
            f"The directory '{project_dir}' already exists. "
            "Please choose a different name or location."
        )
        raise FileExistsError(error_msg)

    try:
        # 2. Create the main project directory.
        project_dir.mkdir(parents=True)
        _logger.debug("Created project root directory: %s", project_dir)

        # 3. Generate the centralized logging configuration for the new project.
        create_project_logging_config(project_dir, project_name)

        # 4. Scaffold Bash components if requested.
        if include_bash:
            _logger.info("Adding Bash components...")
            bash_dest = project_dir / "bash"
            # Use the imported constant for the source path
            shutil.copytree(paths.BASH_TEMPLATE_DIR, bash_dest)

            # Rename the main template file to the project name
            template_sh = bash_dest / "template.sh"
            project_sh = bash_dest / f"{project_name}.sh"
            template_sh.rename(project_sh)

            # Make the main script and utilities executable
            _make_executable(project_sh)
            _logger.debug("Bash setup complete.")

        # 5. Scaffold Python components if requested.
        if include_python:
            _logger.info("Adding Python components...")
            python_dest = project_dir / "python"
            # Use the imported constant for the source path
            shutil.copytree(paths.PYTHON_TEMPLATE_DIR, python_dest)

            # Rename the main template file to the project name
            template_py = python_dest / "main.py"
            project_py = python_dest / f"{project_name}.py"
            template_py.rename(project_py)
            _logger.debug("Python setup complete.")

        _logger.info("✅ Project '%s' created successfully!", project_name)
        # These print statements are intentional for direct user feedback in a CLI.
        # We silence the linter warning for this specific, deliberate use case.
        print(f"\n🚀 Your new project is ready at: {project_dir}")  # noqa: T201
        print("To get started, run:")  # noqa: T201
        print(f"  cd {project_dir}")  # noqa: T201

    except (OSError, FileExistsError):
        _logger.exception("Build failed for project '%s'", project_name)
        # Clean up the partially created directory on failure.
        if project_dir.exists():
            _logger.warning("Cleaning up failed build directory: %s", project_dir)
            shutil.rmtree(project_dir)
        # Re-raise the exception to be handled by the CLI layer.
        raise
