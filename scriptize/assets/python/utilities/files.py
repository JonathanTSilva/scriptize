"""A collection of high-level, robust file and directory manipulation utilities.

This module simplifies common file system operations such as reading/writing
structured data (JSON, YAML), creating backups, listing files, and safely
handling paths using the modern `pathlib` library.
"""

import datetime
import json
import os
import random
import shutil
import sys
import tempfile
from collections.abc import Iterator
from pathlib import Path
from typing import cast

# For handling YAML files.
# This should be added to your pyproject.toml dependencies.
# poetry add PyYAML / uv pip install PyYAML
try:
    import yaml  # type: ignore[import-untyped]
except ImportError:
    sys.stderr.write(
        "Error: The 'PyYAML' library is required for YAML operations. "
        "Please install it by running 'pip install PyYAML'\n"
    )
    # We don't exit here, as other functions might still be usable.

# A recursive type hint for representing complex JSON or YAML data structures.
type DataType = dict[str, "DataType"] | list["DataType"] | str | int | float | bool | None


# *====[ Path Information ]====*
def get_name(path: str | Path) -> str:
    """Extracts the filename from a path (e.g., 'document.txt')."""
    return Path(path).name


def get_basename(path: str | Path) -> str:
    """Extracts the filename without its final extension (e.g., 'document')."""
    return Path(path).stem


def get_extension(path: str | Path) -> str:
    """Extracts the file extension (e.g., '.txt')."""
    return Path(path).suffix


def get_parent(path: str | Path) -> Path:
    """Extracts the parent directory of a path."""
    return Path(path).parent


# *====[ File Reading & Writing ]====*
def read_file(path: str | Path) -> str:
    """Reads the entire content of a text file.

    Args:
        path: The path to the file.

    Returns:
        The content of the file as a string.

    Raises:
        FileNotFoundError: If the file does not exist.
        IOError: If there is an error reading the file.
    """
    # No try/except needed; let exceptions bubble up naturally.
    return Path(path).read_text(encoding="utf-8")


def write_file(path: str | Path, content: str) -> None:
    """Writes content to a file, overwriting it if it exists.

    Args:
        path: The path to the file.
        content: The string content to write.

    Raises:
        IOError: If there is an error writing the file.
    """
    # No try/except needed; let exceptions bubble up naturally.
    Path(path).write_text(content, encoding="utf-8")


def read_json(path: str | Path) -> DataType:
    """Reads and parses a JSON file.

    Args:
        path: The path to the JSON file.

    Returns:
        The parsed Python object from the JSON file.
    """
    content = read_file(path)
    return cast("DataType", json.loads(content))


def write_json(path: str | Path, data: DataType, indent: int = 2) -> None:
    """Writes a Python object to a file in JSON format.

    Args:
        path: The path to the output JSON file.
        data: The Python object to serialize.
        indent: The number of spaces to use for indentation.
    """
    with Path(path).open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=indent, ensure_ascii=False)


def read_yaml(path: str | Path) -> DataType:
    """Reads and parses a YAML file.

    Requires the PyYAML library to be installed.

    Args:
        path: The path to the YAML file.

    Returns:
        The parsed Python object from the YAML file.
    """
    if "yaml" not in sys.modules:
        error_msg = "PyYAML is required for YAML operations but is not installed."
        raise ImportError(error_msg)
    with Path(path).open("r", encoding="utf-8") as f:
        return cast("DataType", yaml.safe_load(f))


def write_yaml(path: str | Path, data: DataType) -> None:
    """Writes a Python object to a file in YAML format.

    Requires the PyYAML library to be installed.

    Args:
        path: The path to the output YAML file.
        data: The Python object to serialize.
    """
    if "yaml" not in sys.modules:
        error_msg = "PyYAML is required for YAML operations but is not installed."
        raise ImportError(error_msg)
    with Path(path).open("w", encoding="utf-8") as f:
        yaml.dump(data, f, allow_unicode=True)


# *====[ File & Directory Operations ]====*
def backup_file(path: str | Path, suffix: str | None = None) -> Path:
    """Creates a backup of a file.

    The backup will be named with a timestamp or a custom suffix.
    Example: 'file.txt' -> 'file.txt.2023-10-27_10-30-00.bak'

    Args:
        path: The path to the file to back up.
        suffix: An optional custom suffix. If None, a timestamp is used.

    Returns:
        The path to the newly created backup file.
    """
    source_path = Path(path)
    if not source_path.is_file():
        error_msg = f"Source file not found: {source_path}"
        raise FileNotFoundError(error_msg)

    if suffix is None:
        # Use timezone-aware datetime to avoid ambiguity.
        now = datetime.datetime.now(datetime.UTC)
        timestamp = now.strftime("%Y-%m-%d_%H-%M-%S")
        backup_suffix = f".{timestamp}.bak"
    else:
        backup_suffix = suffix

    backup_path = source_path.with_name(f"{source_path.name}{backup_suffix}")
    shutil.copy2(source_path, backup_path)
    return backup_path


def create_symlink(target: str | Path, link_path: str | Path, *, overwrite: bool = False) -> None:
    """Creates a symbolic link pointing to a target.

    Args:
        target: The path the link should point to.
        link_path: The path where the link should be created.
        overwrite: If True, remove an existing file or link at link_path.
    """
    target_path = Path(target)
    link = Path(link_path)

    if not target_path.exists():
        error_msg = f"Symlink target does not exist: {target_path}"
        raise FileNotFoundError(error_msg)

    if link.exists() or link.is_symlink():
        if overwrite:
            if link.is_dir():
                shutil.rmtree(link)
            else:
                link.unlink()
        else:
            error_msg = f"Link path already exists: {link}"
            raise FileExistsError(error_msg)

    # Use resolve() to get the absolute path of the target. This ensures
    # the symlink is always valid, regardless of its location.
    link.symlink_to(target_path.resolve())


def list_files(directory: str | Path, pattern: str = "*") -> Iterator[Path]:
    """Lists files in a directory matching a glob pattern, non-recursively.

    Args:
        directory: The directory to search in.
        pattern: The glob pattern to match files against (e.g., "*.txt").

    Returns:
        An iterator of Path objects for matching files.
    """
    for item in Path(directory).glob(pattern):
        if item.is_file():
            yield item


def extract_archive(archive_path: str | Path, extract_to: str | Path | None = None) -> None:
    """Extracts a compressed archive (e.g., .zip, .tar.gz).

    Args:
        archive_path: The path to the archive file.
        extract_to: The directory to extract files to. Defaults to the
                    directory containing the archive.
    """
    if extract_to is None:
        extract_to = Path(archive_path).parent
    shutil.unpack_archive(archive_path, extract_to)


def create_temp_file(prefix: str = "tmp_", suffix: str = ".tmp") -> Path:
    """Safely creates a temporary file.

    The file is created with a unique name and is guaranteed to be secure.
    The caller is responsible for deleting the file when done.

    Args:
        prefix: A prefix for the temporary filename.
        suffix: A suffix for the temporary filename.

    Returns:
        A Path object pointing to the created temporary file.
    """
    # Using delete=False means the file is not deleted on close,
    # allowing the caller to manage its lifecycle.
    fd, path_str = tempfile.mkstemp(suffix=suffix, prefix=prefix)
    os.close(fd)  # Close the file descriptor immediately
    return Path(path_str)


# *====[ File Content Analysis ]====*
def file_contains(path: str | Path, text: str) -> bool:
    """Checks if a text file contains a specific string.

    Args:
        path: The path to the file.
        text: The string to search for.

    Returns:
        True if the text is found, False otherwise.
    """
    try:
        with Path(path).open("r", encoding="utf-8") as f:
            for line in f:
                if text in line:
                    return True
    except (FileNotFoundError, UnicodeDecodeError):
        return False
    return False


def random_line(path: str | Path) -> str | None:
    """Selects a random line from a text file.

    This method is memory-efficient for large files.

    Args:
        path: The path to the file.

    Returns:
        A random line from the file, or None if the file is empty.
    """
    try:
        with Path(path).open("r", encoding="utf-8") as f:
            line = next(f)
            # S311 is disabled because this function is for non-cryptographic
            # random selection, where `random` is appropriate.
            for num, aline in enumerate(f, 2):
                if random.randrange(num):  # noqa: S311
                    continue
                line = aline
        return line.strip()
    except (StopIteration, FileNotFoundError):
        # StopIteration if file is empty, FileNotFoundError if it doesn't exist
        return None


# *====[ Demonstration ]====*
if __name__ == "__main__":
    # TODO(@jonathantsilva): Migrate this demo to a test suite using pytest (#2)
    try:
        from . import cli
    except ImportError:
        sys.exit("This demo requires the 'alerts' module to be available.")

    cli.section("ScriptizePy Files Demo")

    # A simple helper to format boolean checks for the demo output.
    def format_check(*, check: bool) -> str:
        """Formats a boolean value into a colored Yes/No string."""
        return "[bold green]✔ Yes[/]" if check else "[bold red]✖ No[/]"

    # --- Setup Demo Environment ---
    demo_dir = Path("./scriptize_files_demo")
    if demo_dir.exists():
        shutil.rmtree(demo_dir)
    demo_dir.mkdir()

    test_file = demo_dir / "report.txt"
    test_json = demo_dir / "data.json"
    test_yaml = demo_dir / "config.yaml"

    cli.setup_logging(default_level="INFO")
    # --- Path Info ---
    cli.header("Path Information")
    cli.info(f"Full path: {test_file.resolve()}")
    cli.info(f"Name: {get_name(test_file)}")
    cli.info(f"Basename: {get_basename(test_file)}")
    cli.info(f"Extension: {get_extension(test_file)}")
    cli.info(f"Parent: {get_parent(test_file)}")

    # --- File Writing & Reading ---
    cli.header("File I/O")
    write_file(test_file, "Line 1: Hello\nLine 2: World\nLine 3: Test")
    cli.success(f"Wrote content to {test_file}")
    content = read_file(test_file)
    cli.info(f"Read back {len(content)} characters.")

    # --- JSON & YAML ---
    cli.header("Structured Data (JSON/YAML)")
    py_data: DataType = {"user": "scriptize", "settings": {"theme": "dark", "version": 1}}
    write_json(test_json, py_data)
    cli.success(f"Wrote JSON to {test_json}")
    json_data = read_json(test_json)
    if isinstance(json_data, dict):
        cli.info(f"Read user from JSON: {json_data.get('user')}")

    write_yaml(test_yaml, py_data)
    cli.success(f"Wrote YAML to {test_yaml}")
    yaml_data = read_yaml(test_yaml)
    if isinstance(yaml_data, dict):
        settings = yaml_data.get("settings")
        if isinstance(settings, dict):
            theme = settings.get("theme")
            cli.info(f"Read theme from YAML: {theme}")

    # --- File Operations ---
    cli.header("File Operations")
    backup_path = backup_file(test_file)
    cli.success(f"Created backup: {backup_path.name}")
    symlink_path = demo_dir / "report_link.txt"
    create_symlink(test_file, symlink_path, overwrite=True)
    cli.success(f"Created symlink: {symlink_path.name}")
    is_same = symlink_path.read_text() == test_file.read_text()
    cli.info(f"Symlink points to original: {format_check(check=is_same)}")

    # --- Listing & Content ---
    cli.header("Listing & Content Analysis")
    (demo_dir / "image.jpg").touch()
    file_list = list(list_files(demo_dir, "*.txt"))
    cli.info(f"Found {len(file_list)} '.txt' file(s): {[f.name for f in file_list]}")
    cli.info(f"File contains 'World': {format_check(check=file_contains(test_file, 'World'))}")
    cli.info(
        f"File contains 'Planet': {format_check(check=not file_contains(test_file, 'Planet'))}"
    )
    cli.info(f"Random line from file: '{random_line(test_file)}'")

    # --- Cleanup ---
    cli.header("Cleanup")
    shutil.rmtree(demo_dir)
    cli.success(f"Removed demo directory: {demo_dir}")
