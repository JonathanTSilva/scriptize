# files.bash

A utility library for common file and filesystem operations.

## Overview

This script provides a collection of functions for file manipulation,
including creating backups, encrypting/decrypting, extracting archives,
parsing file paths, and converting between data formats like YAML and JSON.

## Index

* [`_backupFile_`](#backupfile)
* [`_createUniqueFilename_`](#createuniquefilename)
* [`_decryptFile_`](#decryptfile)
* [`_encryptFile_`](#encryptfile)
* [`_extractArchive_`](#extractarchive)
* [`_fileName_`](#filename)
* [`_fileBasename_`](#filebasename)
* [`_fileExtension_`](#fileextension)
* [`_filePath_`](#filepath)
* [`_fileContains_`](#filecontains)
* [`_json2yaml_`](#json2yaml)
* [`_listFiles_`](#listfiles)
* [`_makeSymlink_`](#makesymlink)
* [`_parseYAML_`](#parseyaml)
* [`_randomLineFromFile_`](#randomlinefromfile)
* [`_readFile_`](#readfile)
* [`_sourceFile_`](#sourcefile)
* [`_yaml2json_`](#yaml2json)

## Shellcheck

- Disable: SC1090

### `_backupFile_` {#backupfile}

Creates a backup of a file or directory.
Can create a `.bak` file in place or copy/move the source to a backup directory.

#### Example

```bash
# Create a backup of file.txt as file.txt.bak
_backupFile_ "file.txt"
```

#### Options

* **-d** | **-D**

  Use a backup directory instead of creating a `.bak` file in the same location.

* **-m** | **-M**

  Move the source file (rename) instead of copying it. This removes the original.

#### Arguments

- **\$1** (path): (required) The source file or directory to back up.
- **\$2** (path): (optional) The destination directory path to use with the `-d` flag. Defaults to `./backup`.

#### Exit codes

- **0**: On success.
- **1**: On error (e.g., source not found, unrecognized option).

#### See also

- [`_execute_()`](#execute)
- [`_createUniqueFilename_()`](#createuniquefilename)

### `_createUniqueFilename_` {#createuniquefilename}

Generates a unique filename by appending an incrementing number if the file already exists.

#### Example

```bash
# Assuming "file.txt" exists:
_createUniqueFilename_ "/data/file.txt" # -> /data/file.txt.1
```

#### Options

* **-i** | **-I**

  Places the unique number *before* the file extension instead of at the very end.

#### Arguments

- **\$1** (path): (required) The desired filename.
- **\$2** (string): (optional) The separator character to use before the number. Defaults to `.`.

#### Exit codes

- **0**: On success.
- **1**: On error.

#### Output on stdout

- The new, unique filename path.

### `_decryptFile_` {#decryptfile}

Decrypts a file using OpenSSL (aes-256-cbc).

#### Example

```bash
_decryptFile_ "secret.txt.enc" "secret.txt"
```

#### Arguments

- **\$1** (path): (required) The encrypted file to decrypt (e.g., `file.enc`).
- **\$2** (path): (optional) The name for the decrypted output file. Defaults to the input filename without `.enc`.

#### Exit codes

- **0**: On success.
- **1**: If the source file does not exist.

#### See also

- [`_execute_()`](#execute)

### `_encryptFile_` {#encryptfile}

Encrypts a file using OpenSSL (aes-256-cbc).

#### Example

```bash
_encryptFile_ "important.docx"
```

#### Arguments

- **\$1** (path): (required) The file to encrypt.
- **\$2** (path): (optional) The name for the encrypted output file. Defaults to the input filename with `.enc` appended.

#### See also

- [`_execute_()`](#execute)

### `_extractArchive_` {#extractarchive}

Extracts a wide variety of archive types using available system commands.
Supported formats include: .tar.bz2, .tbz, .tar.gz, .tgz, .tar.xz, .tar, .bz2, .gz, .xz, .zip, .rar, .7z, .deb, and more.

#### Example

```bash
_extractArchive_ "my_project.tar.gz"
```

#### Arguments

- **\$1** (path): (required) The archive file to extract.
- **\$2** (string): (optional) Pass 'v' to enable verbose output for commands that support it.

#### Exit codes

- **0**: On success.
- **1**: If the file does not exist or the archive type is unsupported.

### `_fileName_` {#filename}

Gets the filename (including extension) from a full path.

#### Example

```bash
_fileName_ "/var/log/syslog.log" # -> syslog.log
```

#### Arguments

- **\$1** (path): (required) The input path string.

#### Output on stdout

- The filename with its extension.

### `_fileBasename_` {#filebasename}

Gets the basename of a file (filename without extension) from a path.

#### Example

```bash
_fileBasename_ "some/path/to/archive.tar.gz" # -> archive.tar
```

#### Arguments

- **\$1** (path): (required) The input path string.

#### Output on stdout

- The filename without its path or extension.

### `_fileExtension_` {#fileextension}

Gets the extension from a filename.
It can detect common double extensions like `.tar.gz`.

#### Example

```bash
_fileExtension_ "archive.tar.gz" # -> tar.gz
_fileExtension_ "document.pdf"   # -> pdf
```

#### Arguments

- **\$1** (path): (required) The input path string.

#### Exit codes

- **1**: If no extension is found.

#### Output on stdout

- The file extension, without the leading dot.

### `_filePath_` {#filepath}

Gets the directory name from a full file path.
If the path exists, it returns the absolute (real) path to the directory.

#### Example

```bash
_filePath_ "/var/log/syslog.log" # -> /var/log
```

#### Arguments

- **\$1** (path): (required) The input path string.

#### Output on stdout

- The directory path.

#### See also

- [labbots/bash-utility](https://github.com/labbots/bash-utility/)

### `_fileContains_` {#filecontains}

Searches a file for a given grep pattern.

#### Example

```bash
if _fileContains_ "/etc/hosts" "localhost"; then
  echo "localhost is defined in hosts file."
fi
```

#### Arguments

- **\$1** (path): (required) The file to search within.
- **\$2** (string): (required) The grep pattern to search for.

#### Exit codes

- **0**: If the pattern is found in the file.
- **1**: If the pattern is not found.

### `_json2yaml_` {#json2yaml}

Converts a JSON file to YAML format.

#### Example

```bash
_json2yaml_ "data.json" > "data.yml"
```

#### Arguments

- **\$1** (path): (required) The input JSON file.

#### Output on stdout

- The converted content in YAML format.

### `_listFiles_` {#listfiles}

Finds files in a directory using either glob or regex patterns.

#### Example

```bash
_listFiles_ glob "*.log" "/var/log"
mapfile -t txt_files < <(_listFiles_ g "*.txt")
```

#### Arguments

- **\$1** (string): (required) The search type: 'glob' (or 'g') or 'regex' (or 'r').
- **\$2** (string): (required) The search pattern (case-insensitive). Must be quoted.
- **\$3** (path): (optional) The directory to search in. Defaults to the current directory (`.`).

#### Exit codes

- **0**: If files are found.
- **1**: If no files are found.

#### Output on stdout

- A list of matching absolute file paths, one per line.

### `_makeSymlink_` {#makesymlink}

Creates a symlink, safely backing up any existing file or symlink at the destination.

#### Example

```bash
_makeSymlink_ "~/dotfiles/.bashrc" "~/.bashrc"
```

#### Options

* **-c** | **-C**

  Quiet mode. Only report on new or changed symlinks.

* **-n** | **-N**

  No backup. Overwrites the destination without creating a backup.

* **-s** | **-S**

  Use `sudo` when removing the destination file/symlink.

#### Arguments

- **\$1** (path): (required) The source file/directory for the symlink.
- **\$2** (path): (required) The destination path for the new symlink.

#### Exit codes

- **0**: On success.
- **1**: On error.

### `_parseYAML_` {#parseyaml}

Parses a YAML file and converts its structure into Bash variable assignments.

#### Example

```bash
# Given sample.yml:
# user: admin
# hosts:
#   - web1
#   - web2
```

#### Arguments

- **\$1** (path): (required) The source YAML file.
- **\$2** (string): (required) A prefix to add to all generated variable names to prevent collisions.

#### Output on stdout

- A series of Bash variable and array assignments that can be sourced.

#### See also

- [DinoChiesa's Gist](https://gist.github.com/DinoChiesa/3e3c3866b51290f31243)
- [epiloque's Gist](https://gist.github.com/epiloque/8cf512c6d64641bde388)

### `_randomLineFromFile_` {#randomlinefromfile}

Returns a single random line from a given file.

#### Example

```bash
random_quote=$(_randomLineFromFile_ "quotes.txt")
```

#### Arguments

- **\$1** (path): (required) The input file.

#### Exit codes

- **1**: If the file is not found.

#### Output on stdout

- A single random line from the file.

### `_readFile_` {#readfile}

Prints each line of a file to stdout.

#### Example

```bash
_readFile_ "/etc/hosts"
```

#### Arguments

- **\$1** (path): (required) The input file.

#### Exit codes

- **1**: If the file is not found.

#### Output on stdout

- The entire content of the file.

### `_sourceFile_` {#sourcefile}

Safely sources a file into the current script.
Exits with a fatal error if the file does not exist or fails to be sourced.

#### Example

```bash
_sourceFile_ "my_config.conf"
```

#### Arguments

- **\$1** (path): (required) The file to be sourced.

#### Exit codes

- **0**: If the file is sourced successfully.

### `_yaml2json_` {#yaml2json}

Converts a YAML file to JSON format.

#### Example

```bash
_yaml2json_ "config.yml" > "config.json"
```

#### Arguments

- **\$1** (path): (required) The input YAML file.

#### Output on stdout

- The converted content in JSON format.

