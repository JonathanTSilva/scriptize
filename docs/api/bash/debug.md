# debug.bash

A utility library of functions to aid in debugging Bash scripts.

## Overview

This script provides functions to help with common debugging tasks,
such as pausing script execution, inspecting the contents of arrays,
and visualizing raw ANSI escape codes within a string.

## Index

* [`_pauseScript_`](#pausescript)
* [`_printAnsi_`](#printansi)
* [`_printArray_`](#printarray)

### `_pauseScript_` {#pausescript}

Pauses script execution and waits for user confirmation to continue.
If the user does not confirm, the script exits via `_safeExit_`.

#### Example

```bash
echo "About to perform a critical step."
_pauseScript_ "Check resources and press 'y' to proceed."
echo "Critical step complete."
```

#### Arguments

- **\$1** (string): (optional) A custom message to display in the confirmation prompt. Defaults to "Paused. Ready to continue?".

#### See also

- [`_seekConfirmation_()`](#seekconfirmation)
- [`_safeExit_()`](#safeexit)

### `_printAnsi_` {#printansi}

Helps debug ANSI escape sequences by making the ESC character visible as `\e`.

#### Example

```bash
color_string="$(tput bold)$(tput setaf 9)Some Text$(tput sgr0)"
_printAnsi_ "${color_string}"
# Output: \e[1m\e[31mSome Text\e[0m
```

#### Arguments

- **\$1** (string): (required) An input string containing raw ANSI escape sequences.

#### Output on stdout

- The input string with the non-printable ESC character replaced by the literal string `\e`.

#### See also

- [labbots/bash-utility](https://github.com/labbots/bash-utility/blob/master/src/debug.sh)

### `_printArray_` {#printarray}

Prints the contents of an array as key-value pairs for easier debugging.
By default, it only prints if the global `$VERBOSE` variable is true.

#### Example

```bash
# In verbose mode (-v), this will print the array contents.
testArray=("a" "b" "c")
_printArray_ "testArray" ${LINENO}
```

#### Options

* **-v** | **-V**

  Force printing of the array even if `$VERBOSE` is false. Output will use 'info' alerts instead of 'debug'.

#### Arguments

- **\$1** (string): (required) The name of the array variable to print.
- **\$2** (integer): (optional) The line number where the function is called, typically passed as `${LINENO}`.

#### Output on stdout

- The array's name followed by each key-value pair, one per line, via the `debug` or `info` alert functions.

#### See also

- [labbots/bash-utility](https://github.com/labbots/bash-utility/blob/master/src/debug.sh)
