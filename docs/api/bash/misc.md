# misc.bash

A library of miscellaneous and foundational utility functions.

## Overview

This script provides a collection of miscellaneous helper functions that serve
as a foundation for other scripts. It includes OS detection, process management
(spinners, progress bars), user interaction, and safe command execution wrappers.

## Index

* [`_checkTerminalSize_`](#checkterminalsize)
* [`_detectOS_`](#detectos)
* [`_detectLinuxDistro_`](#detectlinuxdistro)
* [`_detectMacOSVersion_`](#detectmacosversion)
* [`_execute_`](#execute)
* [`_findBaseDir_`](#findbasedir)
* [`_generateUUID_`](#generateuuid)
* [`_progressBar_`](#progressbar)
* [`_spinner_`](#spinner)
* [`_endspin_`](#endspin)
* [`_runAsRoot_`](#runasroot)
* [`_seekConfirmation_`](#seekconfirmation)

## Shellcheck

- Disable: SC1091, SC2154

### `_checkTerminalSize_` {#checkterminalsize}

Enables terminal window size checking.
On supported systems, this causes the `$LINES` and `$COLUMNS` variables to be
updated automatically when the terminal window is resized.

#### Example

```bash
# Call this at the beginning of an interactive script.
_checkTerminalSize_
```

#### See also

- [labbots/bash-utility](https://github.com/labbots/bash-utility)

### `_detectOS_` {#detectos}

Identifies the current operating system.

#### Example

```bash
os_name=$(_detectOS_)
echo "Running on: ${os_name}"
```

#### Exit codes

- **1**: If the OS could not be determined.

#### Output on stdout

- The name of the OS in lowercase: 'mac', 'linux', or 'windows'.

#### See also

- [labbots/bash-utility](https://github.com/labbots/bash-utility)

### `_detectLinuxDistro_` {#detectlinuxdistro}

Detects the specific Linux distribution.

#### Example

```bash
if [[ $(_detectOS_) == "linux" ]]; then
  distro=$(_detectLinuxDistro_)
  echo "Linux distro is: ${distro}"
fi
```

#### Exit codes

- **1**: If not running on Linux or if the distribution cannot be determined.

#### Output on stdout

- The name of the Linux distribution in lowercase (e.g., 'ubuntu', 'centos', 'arch').

#### See also

- [labbots/bash-utility](https://github.com/labbots/bash-utility)

### `_detectMacOSVersion_` {#detectmacosversion}

Detects the product version of macOS.

#### Example

```bash
if [[ $(_detectOS_) == "mac" ]]; then
  mac_version=$(_detectMacOSVersion_)
  echo "macOS version: ${mac_version}"
fi
```

#### Exit codes

- **1**: If not running on macOS.

#### Output on stdout

- The version number of macOS (e.g., '12.5.1').

#### See also

- [`_detectOS_()`](#detectos)
- [labbots/bash-utility](https://github.com/labbots/bash-utility)

### `_execute_` {#execute}

A safe command execution wrapper.
It respects global flags like `$DRYRUN`, `$VERBOSE`, and `$QUIET`, and provides
options for customizing output and error handling.

#### Example

```bash
_execute_ "mkdir -p '/tmp/my-new-dir'" "Created temporary directory"
_execute_ -s "rm -f '/tmp/some-file'" "Successfully removed file"
```

#### Options

* **-v** | **-V**

  Force verbose output for this command, printing the command's native stdout/stderr.

* **-n** | **-N**

  Use 'notice' level alerting for the status message instead of 'info'.

* **-p** | **-P**

  Pass failures. If the command fails, return 0 instead of 1. Bypasses `set -e`.

* **-e** | **-E**

  Echo result. Use `printf` for the status message instead of an alert function.

* **-s** | **-S**

  On success, use 'success' level alerting for the status message.

* **-q** | **-Q**

  Quiet mode. Do not print any status message.

#### Arguments

- **\$1** (string): (required) The command to be executed. Must be properly quoted.
- **\$2** (string): (optional) A custom message to display instead of the command itself.

#### Exit codes

- **0**: On success, or if `-p` is used on failure.
- **1**: On failure.

#### Output on stdout

- The native output of the command if in verbose mode, or the status message.

### `_findBaseDir_` {#findbasedir}

Locates the real, absolute directory of the script being run.
It correctly resolves symlinks.

#### Example

```bash
# If this is in a script at /usr/local/bin/myscript
baseDir="$(_findBaseDir_)"
# baseDir is now "/usr/local/bin"
```

#### Output on stdout

- Prints the absolute path to the script's directory.

### `_generateUUID_` {#generateuuid}

Generates a random UUID (Universally Unique Identifier).

#### Example

```bash
request_id=$(_generateUUID_)
```

#### Output on stdout

- A version 4 UUID string (e.g., `f3b4a2d1-e9c8-4b7a-8f6e-1d5c3b2a1f0e`).

#### See also

- [labbots/bash-utility](https://github.com/labbots/bash-utility)

### `_progressBar_` {#progressbar}

Renders a simple progress bar for loops with a known number of iterations.

#### Example

```bash
total_files=100
for i in $(seq 1 ${total_files}); do
  _progressBar_ "${total_files}" "Processing files"
  sleep 0.05
done
echo " Done."
```

#### Arguments

- **\$1** (integer): (required) The total number of items in the loop.
- **\$2** (string): (optional) The title to display next to the progress bar.

#### Output on stdout

- A progress bar that updates on the same line.

#### See also

- [`_spinner_()`](#spinner)

### `_spinner_` {#spinner}

Renders a simple text-based spinner for long-running operations.

#### Example

```bash
_spinner_ "Waiting for connection"
sleep 5
_endspin_ "Connected."
```

#### Arguments

- **\$1** (string): (optional) The message to display next to the spinner.

#### Output on stdout

- A spinner that updates on the same line.

#### See also

- [`_endspin_()`](#endspin)

### `_endspin_` {#endspin}

Clears the line used by `_spinner_` and restores the cursor.
Should be called after a loop that uses `_spinner_`.

#### Example

```bash
# See example for _spinner_()
```

#### See also

- [`_spinner_()`](#spinner)

### `_runAsRoot_` {#runasroot}

Runs a command with root privileges.

#### Example

```bash
_runAsRoot_ "apt-get" "update"
```

#### Arguments

- **...** (\any): (required) The command and its arguments to execute as root.

#### See also

- [ralish/bash-script-template](https://github.com/ralish/bash-script-template)

### `_seekConfirmation_` {#seekconfirmation}

Prompts the user for a yes/no confirmation.

#### Example

```bash
if _seekConfirmation_ "Are you sure you want to delete all files?"; then
  echo "Deleting files..."
else
  echo "Operation cancelled."
fi
```

#### Arguments

- **\$1** (string): (required) The question to ask the user.

#### Exit codes

- **0**: If the user answers "yes" (y/Y).
- **1**: If the user answers "no" (n/N).
