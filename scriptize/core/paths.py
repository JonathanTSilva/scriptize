"""Centralized path management for the Scriptize application.

This module defines constant paths to key directories and files used throughout
the application, ensuring that path logic is not duplicated and can be easily
updated from a single location.
"""

from pathlib import Path
from typing import Final

# This list explicitly defines the public API of this module.
# Only these names will be imported with 'from .paths import *'.
__all__ = [
    "ASSETS_DIR",
    "BASH_LOGGER_SCRIPT",
    "BASH_TEMPLATE_DIR",
    "LOGGER_DIR",
    "PACKAGE_ROOT",
    "PYTHON_TEMPLATE_DIR",
]

# *====[ Core Application Paths ]====*

# The absolute path to the root directory of the entire 'scriptize' package.
# We find it by getting the directory of this file (`core`) and going one level up.
PACKAGE_ROOT: Final[Path] = Path(__file__).resolve().parent.parent

# *====[ Asset and Template Paths ]====*

# The main directory containing all template assets.
ASSETS_DIR: Final[Path] = PACKAGE_ROOT / "assets"

# Specific template paths for each supported language.
BASH_TEMPLATE_DIR: Final[Path] = ASSETS_DIR / "bash"
PYTHON_TEMPLATE_DIR: Final[Path] = ASSETS_DIR / "python"

# *====[ Logger Paths ]====*

# The directory containing the core logging configuration and scripts.
LOGGER_DIR: Final[Path] = PACKAGE_ROOT / "logger"

# The specific path to the Bash logger bridge script.
BASH_LOGGER_SCRIPT: Final[Path] = LOGGER_DIR / "bash_logger.py"
