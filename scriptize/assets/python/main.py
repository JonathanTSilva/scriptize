"""This module serves as the entry point for the application.

It initializes the necessary components, parses command-line arguments, and orchestrates the main
execution flow. The module may include functions for configuration, logging setup, and invoking the
core logic of the application.
"""

import logging
from pathlib import Path

# This assumes the generated project has access to the scriptize library
from scriptize.logger.log_manager import setup_logging

# Best practice: create a logger for this specific module.
_logger = logging.getLogger(__name__)

# This makes the script runnable from any location
BASE_DIR = Path(__file__).resolve().parent


def main() -> None:
    """Main entry point for the generated Python script."""
    # Configure logging using the project's local config file
    log_config_path = BASE_DIR / "logging_config.json"
    setup_logging(config_path=log_config_path)

    _logger.info("Python script started successfully.")
    _logger.debug("This is a debug message from the generated script.")
    _logger.error("This is an error message.", extra={"extra_data": {"code": 123}})
    _logger.info("Script finished.")


if __name__ == "__main__":
    main()
