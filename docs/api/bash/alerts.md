# alerts.bash

A library of functions for providing colorful, leveled alerts and logging them to a file.

## Overview

This library provides a set of functions to print standardized messages
to the screen and to a log file. It supports multiple alert levels,
color-coded output, and automatic detection of terminal capabilities.

Global variables used by this library:

- QUIET:    (true/false) Suppresses all screen output if true.
- VERBOSE:  (true/false) Enables DEBUG level messages on screen if true.
- LOGLEVEL: (string) Sets the logging verbosity (e.g., ERROR, INFO, DEBUG).
- LOGFILE:  (path) The full path to the log file.
- COLUMNS:  (integer) The width of the terminal.

## Index

* [`_setColors_`](#setcolors)
* [`_alert_`](#alert)
* [`error`](#error)
* [`warning`](#warning)
* [`notice`](#notice)
* [`info`](#info)
* [`success`](#success)
* [`dryrun`](#dryrun)
* [`input`](#input)
* [`header`](#header)
* [`debug`](#debug)
* [`fatal`](#fatal)
* [`_printFuncStack_`](#printfuncstack)
* [`_centerOutput_`](#centeroutput)
* [`_columns_`](#columns)

## Shellcheck

- Disable: SC2034, SC2154

### `_setColors_` {#setcolors}

Sets global color variables for use in alerts.
It auto-detects if the terminal supports 256 colors and falls back gracefully.

#### Example

```bash
_setColors_
printf "%s\n" "${blue}Some blue text${reset}"
```

### `_alert_` {#alert}

The core engine for all alerts. Controls printing of messages to stdout and log files.
This function is typically not called directly, but through its wrappers (error, info, etc.).

#### Example

```bash
_alert_ "success" "The operation was completed." "${LINENO}"
```

#### Arguments

- **\$1** (string): (required) The type of alert: success, header, notice, dryrun, debug, warning, error, fatal, info, input.
- **\$2** (string): (required) The message to be printed.
- **\$3** (integer): (optional) The line number, passed via `${LINENO}` to show where the alert was triggered.

#### Output on stdout

- The formatted and colorized message.

#### Output on stderr

- Nothing is printed to stderr.

#### See also

- [`error()`](#error)
- [`info()`](#info)
- [`fatal()`](#fatal)

### `error` {#error}

Prints an error message. A wrapper for `_alert_`.

#### Arguments

- **\$1** (string): (required) The message to print.
- **\$2** (integer): (optional) The line number (`${LINENO}`).

#### See also

- [`_alert_`](#alert)

### `warning` {#warning}

Prints a warning message. A wrapper for `_alert_`.

#### Arguments

- **\$1** (string): (required) The message to print.
- **\$2** (integer): (optional) The line number (`${LINENO}`).

#### See also

- [`_alert_`](#alert)

### `notice` {#notice}

Prints a notice message (bold). A wrapper for `_alert_`.

#### Arguments

- **\$1** (string): (required) The message to print.
- **\$2** (integer): (optional) The line number (`${LINENO}`).

#### See also

- [`_alert_`](#alert)

### `info` {#info}

Prints an informational message (gray). A wrapper for `_alert_`.

#### Arguments

- **\$1** (string): (required) The message to print.
- **\$2** (integer): (optional) The line number (`${LINENO}`).

#### See also

- [`_alert_`](#alert)

### `success` {#success}

Prints a success message (green). A wrapper for `_alert_`.

#### Arguments

- **\$1** (string): (required) The message to print.
- **\$2** (integer): (optional) The line number (`${LINENO}`).

#### See also

- [`_alert_`](#alert)

### `dryrun` {#dryrun}

Prints a dryrun message (blue). A wrapper for `_alert_`.

#### Arguments

- **\$1** (string): (required) The message to print.
- **\$2** (integer): (optional) The line number (`${LINENO}`).

#### See also

- [`_alert_`](#alert)

### `input` {#input}

Prints an input prompt message (bold/underline). A wrapper for `_alert_`.

#### Arguments

- **\$1** (string): (required) The message to print.
- **\$2** (integer): (optional) The line number (`${LINENO}`).

#### See also

- [`_alert_`](#alert)

### `header` {#header}

Prints a header message (bold/white/underline). A wrapper for `_alert_`.

#### Arguments

- **\$1** (string): (required) The message to print.
- **\$2** (integer): (optional) The line number (`${LINENO}`).

#### See also

- [`_alert_`](#alert)

### `debug` {#debug}

Prints a debug message (purple). A wrapper for `_alert_`.

#### Arguments

- **\$1** (string): (required) The message to print.
- **\$2** (integer): (optional) The line number (`${LINENO}`).

#### See also

- [`_alert_`](#alert)

### `fatal` {#fatal}

Prints a fatal error message and exits the script with code 1. A wrapper for `_alert_`.

#### Arguments

- **\$1** (string): (required) The message to print.
- **\$2** (integer): (optional) The line number (`${LINENO}`).

#### Exit codes

- **1**: Always returns 1 to signify an error.

#### See also

- [`_alert_`](#alert)

### `_printFuncStack_` {#printfuncstack}

Prints the current function stack. Used for debugging and error reporting.

#### Output on stdout

- Prints the stack trace in the format `( [function1]:[file1]:[line1] < [function2]:[file2]:[line2] )`.

### `_centerOutput_` {#centeroutput}

Prints text centered in the terminal window.

#### Example

```bash
_centerOutput_ "--- Main Menu ---" "-"
```

#### Arguments

- **\$1** (string): (required) Text to center.
- **\$2** (char): (optional) Fill character to use for padding. Defaults to a space.

#### Exit codes

- **1**: If no arguments are provided.

#### Output on stdout

- The centered text, padded with the fill character.

#### See also

- [Credit](https://github.com/labbots/bash-utility)

### `_columns_` {#columns}

Prints output in two columns with fixed widths and text wrapping.

#### Example

```bash
_columns_ -b "Status" "All systems are operational and running at peak performance."
```

#### Options

* **-b** | **-B**

  Bold the left column.

* **-u** | **-U**

  Underline the left column.

* **-r** | **-R**

  Reverse colors for the left column.

#### Arguments

- **\$1** (string): (required) Key name (Left column text).
- **\$2** (string): (required) Long value (Right column text. Wraps if too long).
- **\$3** (integer): (optional) Number of 2-space tabs to indent the output. Default is 0.
- **\$4** (integer): (optional) Total character width of the left column. Default is 35.

#### Exit codes

- **1**: If required arguments are missing or an unrecognized option is passed.

#### Output on stdout

- The formatted two-column output.
