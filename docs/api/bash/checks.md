# checks.bash

A utility library for common validation and check functions.

## Overview

This script provides a robust collection of functions to validate common
data types and environmental states. It includes checks for commands, data
formats (like IP addresses and emails), file system objects, and system
states (like internet connectivity and root access).

## Index

* [`_commandExists_`](#commandexists)
* [`_functionExists_`](#functionexists)
* [`_isAlpha_`](#isalpha)
* [`_isAlphaNum_`](#isalphanum)
* [`_isAlphaDash_`](#isalphadash)
* [`_isEmail_`](#isemail)
* [`_isFQDN_`](#isfqdn)
* [`_isInternetAvailable_`](#isinternetavailable)
* [`_isIPv4_`](#isipv4)
* [`_isFile_`](#isfile)
* [`_isDir_`](#isdir)
* [`_isNum_`](#isnum)
* [`_isTerminal_`](#isterminal)
* [`_rootAvailable_`](#rootavailable)
* [`_varIsTrue_`](#varistrue)
* [`_varIsFalse_`](#varisfalse)
* [`_varIsEmpty_`](#varisempty)
* [`_isIPv6_`](#isipv6)

## Shellcheck

- Disable: SC2206

### `_commandExists_` {#commandexists}

Checks if a command or binary exists in the system's PATH.

#### Example

```bash
if _commandExists_ "git"; then
  echo "Git is installed."
else
  echo "Error: Git is not installed."
fi
```

#### Arguments

- **\$1** (string): (required) Name of the command or binary to check for.

#### Exit codes

- **0**: If the command exists in the PATH.
- **1**: If the command does not exist.

### `_functionExists_` {#functionexists}

Tests if a function is defined in the current script scope.

#### Example

```bash
if _functionExists_ "_commandExists_"; then
  echo "Function exists."
fi
```

#### Arguments

- **\$1** (string): (required) The name of the function to check.

#### Exit codes

- **0**: If the function is defined.
- **1**: If the function is not defined.

### `_isAlpha_` {#isalpha}

Validates that a given input contains only alphabetic characters (a-z, A-Z).

#### Example

```bash
_isAlpha_ "HelloWorld" # returns 0
_isAlpha_ "Hello World" # returns 1
```

#### Arguments

- **\$1** (string): (required) The input string to validate.

#### Exit codes

- **0**: If the input contains only alphabetic characters.
- **1**: If the input contains non-alphabetic characters.

### `_isAlphaNum_` {#isalphanum}

Validates that a given input contains only alpha-numeric characters (a-z, A-Z, 0-9).

#### Example

```bash
_isAlphaNum_ "Test123" # returns 0
_isAlphaNum_ "Test-123" # returns 1
```

#### Arguments

- **\$1** (string): (required) The input string to validate.

#### Exit codes

- **0**: If the input contains only alpha-numeric characters.
- **1**: If the input contains other characters.

### `_isAlphaDash_` {#isalphadash}

Validates that a given input contains only alpha-numeric characters, underscores, or dashes.

#### Example

```bash
_isAlphaDash_ "my-variable_name-1" # returns 0
_isAlphaDash_ "my-variable!" # returns 1
```

#### Arguments

- **\$1** (string): (required) The input string to validate.

#### Exit codes

- **0**: If the input is valid.
- **1**: If the input contains other characters.

### `_isEmail_` {#isemail}

Validates that a string is a valid email address format.

#### Example

```bash
if _isEmail_ "test@example.com"; then
  echo "Valid email."
fi
```

#### Arguments

- **\$1** (string): (required) The email address to validate.

#### Exit codes

- **0**: If the string is a valid email format.
- **1**: If the string is not a valid email format.

### `_isFQDN_` {#isfqdn}

Determines if a given input is a fully qualified domain name (FQDN).

#### Example

```bash
_isFQDN_ "google.com" # returns 0
_isFQDN_ "localhost" # returns 1
```

#### Arguments

- **\$1** (string): (required) The domain name to validate.

#### Exit codes

- **0**: If the string is a valid FQDN.
- **1**: If the string is not a valid FQDN.

### `_isInternetAvailable_` {#isinternetavailable}

Checks if an internet connection is available by attempting to contact google.com.

#### Example

```bash
if _isInternetAvailable_; then
  echo "Internet is up."
fi
```

#### Exit codes

- **0**: If an internet connection to google.com is established.
- **1**: If the connection fails.

### `_isIPv4_` {#isipv4}

Validates that a string is a structurally valid IPv4 address.

#### Example

```bash
_isIPv4_ "192.168.1.1" # returns 0
_isIPv4_ "999.0.0.1" # returns 1
```

#### Arguments

- **\$1** (string): (required) The IPv4 address to validate.

#### Exit codes

- **0**: If the string is a valid IPv4 address.
- **1**: If the string is not a valid IPv4 address.

### `_isFile_` {#isfile}

Validates that a given path exists and is a regular file.

#### Example

```bash
if _isFile_ "/etc/hosts"; then
  echo "It's a file."
fi
```

#### Arguments

- **\$1** (path): (required) The path to check.

#### Exit codes

- **0**: If the path exists and is a regular file.
- **1**: Otherwise.

### `_isDir_` {#isdir}

Validates that a given path exists and is a directory.

#### Example

```bash
if _isDir_ "/etc/"; then
  echo "It's a directory."
fi
```

#### Arguments

- **\$1** (path): (required) The path to check.

#### Exit codes

- **0**: If the path exists and is a directory.
- **1**: Otherwise.

### `_isNum_` {#isnum}

Validates that a given input contains only numeric digits (0-9).

#### Example

```bash
_isNum_ "12345" # returns 0
_isNum_ "123a"  # returns 1
```

#### Arguments

- **\$1** (string): (required) The input string to validate.

#### Exit codes

- **0**: If the input contains only numeric digits.
- **1**: If the input contains non-numeric characters.

### `_isTerminal_` {#isterminal}

Checks if the script is running in an interactive terminal.

#### Example

```bash
if _isTerminal_; then
  echo "We can use interactive prompts."
fi
```

#### Exit codes

- **0**: If the script is running in an interactive terminal.
- **1**: If the script is not (e.g., piped, in a cron job).

### `_rootAvailable_` {#rootavailable}

Validates if superuser (root) privileges are available.

#### Example

```bash
if _rootAvailable_; then
  echo "Running tasks that require root..."
else
  echo "Cannot run root tasks."
fi
```

#### Arguments

- **\$1** (any): (optional) If set to any value, will not attempt to use `sudo`.

#### Exit codes

- **0**: If superuser privileges are available.
- **1**: If superuser privileges could not be obtained.

#### See also

- [ralish/bash-script-template](https://github.com/ralish/bash-script-template)

### `_varIsTrue_` {#varistrue}

Checks if a given variable is considered "true".
True values are "true" (case-insensitive) or "0".

#### Example

```bash
_varIsTrue_ "true" # returns 0
_varIsTrue_ "0"    # returns 0
_varIsTrue_ "yes"  # returns 1
```

#### Arguments

- **\$1** (string): (required) The variable's value to check.

#### Exit codes

- **0**: If the value is considered true.
- **1**: Otherwise.

### `_varIsFalse_` {#varisfalse}

Checks if a given variable is considered "false".
False values are "false" (case-insensitive) or "1".

#### Example

```bash
_varIsFalse_ "false" # returns 0
_varIsFalse_ "1"     # returns 0
_varIsFalse_ "no"    # returns 1
```

#### Arguments

- **\$1** (string): (required) The variable's value to check.

#### Exit codes

- **0**: If the value is considered false.
- **1**: Otherwise.

### `_varIsEmpty_` {#varisempty}

Checks if a given variable is empty or the literal string "null".

#### Example

```bash
_varIsEmpty_ ""       # returns 0
_varIsEmpty_ "null"   # returns 0
_varIsEmpty_ " "      # returns 1
```

#### Arguments

- **\$1** (string): (required) The variable's value to check.

#### Exit codes

- **0**: If the variable is empty or "null".
- **1**: Otherwise.

### `_isIPv6_` {#isipv6}

Validates that a string is a valid IPv6 address.

#### Example

```bash
_isIPv6_ "2001:db8:85a3:8d3:1319:8a2e:370:7348" # returns 0
_isIPv6_ "not-an-ip" # returns 1
```

#### Arguments

- **\$1** (string): (required) The IPv6 address to validate.

#### Exit codes

- **0**: If the string is a valid IPv6 address.
- **1**: If the string is not a valid IPv6 address.

