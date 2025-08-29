"""Configuration file for pytest specifies patterns of files to ignore during test collection.

The 'collect_ignore_glob' variable lists file paths or glob patterns that pytest will skip,
preventing the specified files from being collected as test modules.
"""

# A list of file patterns to ignore during test collection.
collect_ignore_glob = ["scriptize/assets/python/utilities/cli.py"]
