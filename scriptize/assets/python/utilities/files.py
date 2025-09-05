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
import tempfile
from collections.abc import Iterator
from pathlib import Path
from typing import cast

try:
    import yaml  # type: ignore[import-untyped]
except ImportError:
    yaml = None

# A recursive type hint for representing complex JSON or YAML data structures.
type DataType = dict[str, "DataType"] | list["DataType"] | str | int | float | bool | None


# *====[ Path Information ]====*
def get_name(path: str | Path) -> str:
    """Extracts the filename from a path, including extensions.

    Args:
        path: The file or directory path.

    Returns:
        The final component of the path (e.g., 'document.txt').

    Examples:
        >>> get_name("/home/user/document.txt")
        'document.txt'
        >>> from pathlib import Path
        >>> get_name(Path("archive.tar.gz"))
        'archive.tar.gz'
    """
    return Path(path).name


def get_basename(path: str | Path) -> str:
    """Extracts the filename without its final extension.

    For names with multiple extensions (e.g., '.tar.gz'), only the last is removed.

    Args:
        path: The file path.

    Returns:
        The filename without its final suffix (e.g., 'document').

    Examples:
        >>> get_basename("/home/user/document.txt")
        'document'
        >>> get_basename("archive.tar.gz")
        'archive.tar'
    """
    return Path(path).stem


def get_extension(path: str | Path) -> str:
    """Extracts the final file extension, including the dot.

    Args:
        path: The file path.

    Returns:
        The file extension (e.g., '.txt') or an empty string if none exists.

    Examples:
        >>> get_extension("image.jpeg")
        '.jpeg'
        >>> get_extension("archive.tar.gz")
        '.gz'
        >>> get_extension("README")
        ''
    """
    return Path(path).suffix


def get_parent(path: str | Path) -> Path:
    """Gets the parent directory of a path as a Path object.

    Args:
        path: The file or directory path.

    Returns:
        A `pathlib.Path` object representing the parent directory.

    Examples:
        >>> from pathlib import Path
        >>> get_parent("/home/user/document.txt") == Path("/home/user")
        True
        >>> get_parent("file.txt") == Path(".")
        True
    """
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

    Examples:
        >>> from pathlib import Path
        >>> p = Path("test_read.txt")
        >>> _ = p.write_text("Hello, World!")
        >>> read_file(p)
        'Hello, World!'
        >>> p.unlink()
    """
    return Path(path).read_text(encoding="utf-8")


def write_file(path: str | Path, content: str) -> None:
    """Writes content to a file, creating or overwriting it.

    Args:
        path: The path to the file.
        content: The string content to write.

    Raises:
        IOError: If there is an error writing the file.

    Examples:
        >>> from pathlib import Path
        >>> p = Path("test_write.txt")
        >>> write_file(p, "Hello Again")
        >>> p.read_text()
        'Hello Again'
        >>> p.unlink()
    """
    Path(path).write_text(content, encoding="utf-8")


def read_json(path: str | Path) -> DataType:
    """Reads and parses a JSON file into a Python object.

    Args:
        path: The path to the JSON file.

    Returns:
        The parsed Python object (dict, list, etc.) from the JSON file.

    Examples:
        >>> from pathlib import Path
        >>> p = Path("test.json")
        >>> _ = p.write_text('{"user": "test", "active": true}')
        >>> data = read_json(p)
        >>> data["user"]
        'test'
        >>> p.unlink()
    """
    content = read_file(path)
    return cast("DataType", json.loads(content))


def write_json(path: str | Path, data: DataType, indent: int = 2) -> None:
    """Writes a Python object to a file in indented JSON format.

    Args:
        path: The path to the output JSON file.
        data: The Python object to serialize.
        indent: The number of spaces to use for indentation.

    Examples:
        >>> from pathlib import Path
        >>> p = Path("test_write.json")
        >>> data = {"id": 123, "items": ["a", "b"]}
        >>> write_json(p, data)
        >>> read_json(p) == data
        True
        >>> p.unlink()
    """
    with Path(path).open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=indent, ensure_ascii=False)


def read_yaml(path: str | Path) -> DataType:
    r"""Reads and parses a YAML file into a Python object.

    Args:
        path: The path to the YAML file.

    Returns:
        The parsed Python object from the YAML file.

    Raises:
        ImportError: If the `PyYAML` library is not installed.

    Examples:
        >>> from pathlib import Path
        >>> if yaml:
        ...     p = Path("test.yaml")
        ...     _ = p.write_text("user: test\nactive: true")
        ...     data = read_yaml(p)
        ...     data["user"]
        ...     p.unlink()
        'test'
    """
    if yaml is None:
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

    Raises:
        ImportError: If the `PyYAML` library is not installed.

    Examples:
        >>> from pathlib import Path
        >>> if yaml:
        ...     p = Path("test_write.yaml")
        ...     data = {"id": 123, "items": ["a", "b"]}
        ...     write_yaml(p, data)
        ...     read_yaml(p) == data
        ...     p.unlink()
        True
    """
    if yaml is None:
        error_msg = "PyYAML is required for YAML operations but is not installed."
        raise ImportError(error_msg)
    with Path(path).open("w", encoding="utf-8") as f:
        yaml.dump(data, f, allow_unicode=True)


# *====[ File & Directory Operations ]====*
def backup_file(path: str | Path, suffix: str | None = None) -> Path:
    """Creates a backup of a file by copying it with a new suffix.

    Args:
        path: The path to the file to back up.
        suffix: An optional custom suffix. If None, a UTC timestamp is used.

    Returns:
        The path to the newly created backup file.

    Raises:
        FileNotFoundError: If the source file does not exist.

    Examples:
        >>> from pathlib import Path
        >>> p = Path("original.txt")
        >>> _ = p.write_text("data")
        >>> backup = backup_file(p, suffix=".bak")
        >>> backup.name
        'original.txt.bak'
        >>> backup.read_text()
        'data'
        >>> p.unlink()
        >>> backup.unlink()
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
        overwrite: If True, remove an existing file or link at `link_path`.

    Raises:
        FileNotFoundError: If the `target` path does not exist.
        FileExistsError: If `link_path` exists and `overwrite` is False.

    Examples:
        >>> from pathlib import Path
        >>> target = Path("target_file.txt")
        >>> _ = target.write_text("data")
        >>> link = Path("link_file.txt")
        >>> create_symlink(target, link)
        >>> link.is_symlink()
        True
        >>> link.read_text()
        'data'
        >>> target.unlink()
        >>> link.unlink()
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
        pattern: The glob pattern to match files against (e.g., `"*.txt"`).

    Yields:
        `pathlib.Path` objects for each matching file.

    Examples:
        >>> from pathlib import Path
        >>> d = Path("test_dir_list")
        >>> d.mkdir()
        >>> (d / "a.txt").touch()
        >>> (d / "b.log").touch()
        >>> (d / "c.txt").touch()
        >>> (d / "sub").mkdir()
        >>> (d / "sub" / "d.txt").touch()
        >>> names = sorted([p.name for p in list_files(d, "*.txt")])
        >>> names
        ['a.txt', 'c.txt']
        >>> shutil.rmtree(d)
    """
    for item in Path(directory).glob(pattern):
        if item.is_file():
            yield item


def extract_archive(archive_path: str | Path, extract_to: str | Path | None = None) -> None:
    """Extracts a compressed archive (e.g., .zip, .tar.gz).

    Args:
        archive_path: The path to the archive file.
        extract_to: The directory to extract files into. Defaults to the
            directory containing the archive.

    Examples:
        >>> from pathlib import Path
        >>> import shutil
        >>>
        >>> # --- Setup ---
        >>> src_dir = Path("src_for_archive")
        >>> dest_dir = Path("dest_for_archive")
        >>> archive_file = Path("test_archive.zip")
        >>> if src_dir.exists():
        ...     shutil.rmtree(src_dir)
        >>> if dest_dir.exists():
        ...     shutil.rmtree(dest_dir)
        >>> if archive_file.exists():
        ...     archive_file.unlink()
        >>>
        >>> # --- Test Execution ---
        >>> src_dir.mkdir()
        >>> _ = (src_dir / "content.txt").write_text("archive data")
        >>> archive_path_str = shutil.make_archive("test_archive", "zip", src_dir)
        >>> dest_dir.mkdir()
        >>> extract_archive(archive_path_str, dest_dir)
        >>> (dest_dir / "content.txt").read_text()
        'archive data'
        >>>
        >>> # --- Teardown ---
        >>> shutil.rmtree(src_dir)
        >>> shutil.rmtree(dest_dir)
        >>> Path(archive_path_str).unlink()
    """
    if extract_to is None:
        extract_to = Path(archive_path).parent
    shutil.unpack_archive(archive_path, extract_to)


def create_temp_file(prefix: str = "tmp_", suffix: str = ".tmp") -> Path:
    """Safely creates a temporary file that is not automatically deleted.

    The caller is responsible for deleting the file when it's no longer needed.

    Args:
        prefix: A prefix for the temporary filename.
        suffix: A suffix for the temporary filename.

    Returns:
        A `pathlib.Path` object pointing to the created temporary file.

    Examples:
        >>> temp_file = create_temp_file(suffix=".log")
        >>> temp_file.exists()
        True
        >>> temp_file.name.endswith(".log")
        True
        >>> temp_file.unlink()
    """
    fd, path_str = tempfile.mkstemp(suffix=suffix, prefix=prefix)
    os.close(fd)  # Close the file descriptor immediately
    return Path(path_str)


# *====[ File Content Analysis ]====*
def file_contains(path: str | Path, text: str) -> bool:
    r"""Checks if a text file contains a specific substring.

    Args:
        path: The path to the file.
        text: The string to search for.

    Returns:
        `True` if the text is found, `False` otherwise.

    Examples:
        >>> from pathlib import Path
        >>> p = Path("test_contains.txt")
        >>> _ = p.write_text("line one\nline two\nline three")
        >>> file_contains(p, "two")
        True
        >>> file_contains(p, "four")
        False
        >>> p.unlink()
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
    r"""Selects a random line from a text file efficiently.

    This method reads the file only once, making it suitable for large files.

    Args:
        path: The path to the file.

    Returns:
        A random line from the file, or `None` if the file is empty.

    Examples:
        >>> from pathlib import Path
        >>> import random
        >>> p = Path("test_random.txt")
        >>> _ = p.write_text("one\ntwo\nthree")
        >>> random.seed(42)
        >>> random_line(p)
        'three'
        >>> p.unlink()
        >>> empty_file = Path("empty.txt")
        >>> _ = empty_file.write_text("")
        >>> random_line(empty_file) is None
        True
        >>> empty_file.unlink()
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
