# template_utils.bash

Foundational functions required by the script templates and core utilities.

## Overview

This script provides essential functions that form the backbone of the script
template system. It handles script locking to prevent concurrent execution,
manages temporary directories, ensures safe script cleanup and exit, and
modifies the system `$PATH`.

## Index

* [`_acquireScriptLock_`](#acquirescriptlock)
* [`_makeTempDir_`](#maketempdir)
* [`_safeExit_`](#safeexit)
* [`_setPATH_`](#setpath)

## Shellcheck

- Disable: #, Color, SC2120, SC2154, alerts.bash, are, from, sourced, variables

### `_acquireScriptLock_` {#acquirescriptlock}

Acquires a script lock to prevent multiple instances from running simultaneously.
The lock is an empty directory created in `/tmp`. The script will exit if the lock
cannot be acquired.

#### Example

```bash
# Acquire a lock unique to the current user
_acquireScriptLock_
```

#### Arguments

- **\$1** (string): (optional) The scope of the lock. Can be 'system' for a system-wide lock,

#### Variables set

- **SCRIPT_LOCK** (The): path to the created lock directory. This variable is exported as readonly.

#### See also

- [`_safeExit_()`](#safeexit)

### `_makeTempDir_` {#maketempdir}

Creates a unique temporary directory for the script to use.

#### Example

```bash
_makeTempDir_ "my-script-session"
touch "${TMP_DIR}/my-file.tmp"
```

#### Arguments

- **\$1** (string): (optional) A prefix for the temporary directory's name. Defaults to the script's basename.

#### Variables set

- **TMP_DIR** (The): absolute path to the newly created temporary directory.

#### See also

- [`_safeExit_()`](#safeexit)

### `_safeExit_` {#safeexit}

Performs cleanup tasks and exits the script with a given code.
This function is intended to be called by a `trap` at the start of a script.

#### Example

```bash
# Set trap at the beginning of a script
trap '_safeExit_' EXIT INT TERM
```

#### Arguments

- **\$1** (integer): (optional) The exit code to use. Defaults to 0 (success).

#### See also

- [`_acquireScriptLock_()`](#acquirescriptlock)
- [`_makeTempDir_()`](#maketempdir)

### `_setPATH_` {#setpath}

Prepends one or more directories to the session's `$PATH` environment variable.

#### Example

```bash
# Add local bin directories to the PATH
_setPATH_ "/usr/local/bin" "${HOME}/.local/bin"
```

#### Options

* **-x** | **-X**

  Fail with an error code if any of the specified directories are not found.

#### Arguments

- **...** (\path): (required) One or more directory paths to add to the `$PATH`.

#### Variables set

- **PATH** (The): modified `$PATH` environment variable.

#### Exit codes

- **0**: On success.
- **1**: If `-x` is used and a directory does not exist.
