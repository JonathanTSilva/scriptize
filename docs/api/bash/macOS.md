# macOS.bash

A utility library with functions specific to the macOS operating system.

## Overview

This script provides a collection of functions designed exclusively for use
on macOS. It handles interactions with the macOS GUI (Finder, osascript)
and environment (Homebrew paths, GNU utilities).

These functions are not portable and will fail on other operating systems like Linux.

## Index

* [`_haveScriptableFinder_`](#havescriptablefinder)
* [`_guiInput_`](#guiinput)
* [`_useGNUutils_`](#usegnuutils)
* [`_homebrewPath_`](#homebrewpath)

### `_haveScriptableFinder_` {#havescriptablefinder}

Determines whether the script is running in a context where the Finder is scriptable.
This is useful for checking if a GUI interaction is possible.

#### Example

```bash
if _haveScriptableFinder_; then
  echo "GUI is available."
else
  echo "Running in a non-GUI environment."
fi
```

#### Exit codes

- **0**: If the Finder process is running in a scriptable context (e.g., a standard GUI session).
- **1**: If not (e.g., in an SSH session or if Finder is not running).

### `_guiInput_` {#guiinput}

Displays a native macOS dialog box to ask for user input.
Ideal for securely requesting passwords or other sensitive information in a GUI context.

#### Example

```bash
api_key=$(_guiInput_ "Please enter your API Key:")
```

#### Arguments

- **\$1** (string): (optional) The prompt message to display in the dialog box. Defaults to "Password:".

#### Exit codes

- **1**: If the script is not running in a scriptable GUI environment.

#### Output on stdout

- The text entered by the user.

#### See also

- [`_haveScriptableFinder_()`](#havescriptablefinder)
- [awesome-osx-command-line](https://github.com/herrbischoff/awesome-osx-command-line/blob/master/functions.md)

### `_useGNUutils_` {#usegnuutils}

Prepends paths to GNU utilities to the session `$PATH`.
This allows for consistent script behavior by using GNU versions of `sed`, `grep`, `tar`, etc.,
instead of the default BSD versions on macOS.

#### Example

```bash
# Call at the beginning of a script to ensure GNU tools are used.
_useGNUUtils_
# Now 'sed' will refer to gsed, 'grep' to ggrep, etc.
sed -i 's/foo/bar/' file.txt
```

#### Exit codes

- **0**: On success.
- **1**: If the underlying `_setPATH_` function fails.

#### See also

- [`_setPATH_()`](#setpath)

### `_homebrewPath_` {#homebrewpath}

Prepends the Homebrew binary directory to the session `$PATH`.
This ensures that any tools installed via Homebrew are found by the script.
It correctly handles paths for both Intel (`/usr/local/bin`) and Apple Silicon (`/opt/homebrew/bin`).

#### Example

```bash
# Ensure Homebrew executables are available.
_homebrewPath_
```

#### Exit codes

- **0**: On success.
- **1**: If the underlying `_setPATH_` function fails.

#### See also

- [`_setPATH_()`](#setpath)
