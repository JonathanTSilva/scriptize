# dates.bash

A utility library for date and time manipulation and conversion.

## Overview

This script provides a collection of functions to handle common date and
time operations. It supports converting between various date formats,
calculating with Unix timestamps, and parsing dates from strings.

## Index

* [`_convertToUnixTimestamp_`](#converttounixtimestamp)
* [`_countdown_`](#countdown)
* [`_dateUnixTimestamp_`](#dateunixtimestamp)
* [`_formatDate_`](#formatdate)
* [`_fromSeconds_`](#fromseconds)
* [`_monthToNumber_`](#monthtonumber)
* [`_numberToMonth_`](#numbertomonth)
* [`_parseDate_`](#parsedate)
* [`_readableUnixTimestamp_`](#readableunixtimestamp)
* [`_toSeconds_`](#toseconds)

### `_convertToUnixTimestamp_` {#converttounixtimestamp}

Converts a human-readable date string into a Unix timestamp.
Relies on the `date -d` command for parsing.

#### Example

```bash
ts=$(_convertToUnixTimestamp_ "2025-07-01 12:00:00")
echo "Timestamp: ${ts}"
```

#### Arguments

- **\$1** (string): (required) A date string that the `date -d` command can understand (e.g., "Jan 10, 2019", "2025-06-30").

#### Exit codes

- **0**: On successful conversion.
- **1**: If the `date` command fails to parse the input string.

#### Output on stdout

- The Unix timestamp corresponding to the input date.

### `_countdown_` {#countdown}

Displays a countdown timer for a specified duration.
Prints a message at each interval. Uses the `info` alert function if available.

#### Example

```bash
_countdown_ 5 1 "Restarting in"
# Output (one line per second):
# [   INFO] Restarting in 5
# [   INFO] Restarting in 4
# ...
```

#### Arguments

- **\$1** (integer): (optional) Total seconds to count down from. Defaults to 10.
- **\$2** (integer): (optional) The sleep interval in seconds between messages. Defaults to 1.
- **\$3** (string): (optional) The message to print at each interval. Defaults to "...".

#### Output on stdout

- The countdown message at each interval.

### `_dateUnixTimestamp_` {#dateunixtimestamp}

Gets the current time as a Unix timestamp (seconds since epoch, UTC).

#### Example

```bash
current_timestamp=$(_dateUnixTimestamp_)
```

#### Exit codes

- **0**: On success.
- **1**: If the `date` command fails.

#### Output on stdout

- The current Unix timestamp (e.g., `1751352022`).

### `_formatDate_` {#formatdate}

Reformats a date string into a user-specified format.

#### Example

```bash
_formatDate_ "Jan 10, 2022" "%A, %B %d, %Y"
# Output: Monday, January 10, 2022
```

#### Arguments

- **\$1** (string): (required) The input date string (e.g., "Jan 10, 2019").
- **\$2** (string): (optional) The output format for `date`. Defaults to `%F` (YYYY-MM-DD).

#### Output on stdout

- The formatted date string.

### `_fromSeconds_` {#fromseconds}

Converts a total number of seconds into HH:MM:SS format.

#### Example

```bash
STARTTIME=$(date +"%s")
sleep 3
ENDTIME=$(date +"%s")
TOTALTIME=$((ENDTIME - STARTTIME))
_fromSeconds_ "${TOTALTIME}" # -> 00:00:03
```

#### Arguments

- **\$1** (integer): (required) The total number of seconds.

#### Output on stdout

- The time formatted as a zero-padded HH:MM:SS string.

### `_monthToNumber_` {#monthtonumber}

Converts a month name (full or abbreviated) to its corresponding number.

#### Example

```bash
_monthToNumber_ "January" # -> 1
_monthToNumber_ "sep"     # -> 9
```

#### Arguments

- **\$1** (string): (required) The month name (case-insensitive).

#### Exit codes

- **1**: If the month name is not recognized.

#### Output on stdout

- The corresponding month number (1-12).

### `_numberToMonth_` {#numbertomonth}

Converts a month number to its full English name.

#### Example

```bash
_numberToMonth_ 11 # -> November
```

#### Arguments

- **\$1** (integer): (required) The month number (1-12).

#### Exit codes

- **1**: If the number is not between 1 and 12.

#### Output on stdout

- The full English name of the month.

### `_parseDate_` {#parsedate}

Parses a string to find and extract date components.
This function is very complex and uses multiple regular expressions to find a date.
If a date is found, it sets several global variables.

#### Example

```bash
if _parseDate_ "An event on Jan 10, 2025 at 8pm"; then
  echo "Found: ${PARSE_DATE_MONTH_NAME} ${PARSE_DATE_DAY}, ${PARSE_DATE_YEAR}"
fi
```

#### Arguments

- **\$1** (string): (required) A string containing a date.

#### Variables set

- **PARSE_DATE_FOUND** (The): full date string found in the input.
- **PARSE_DATE_YEAR** (The): four-digit year.
- **PARSE_DATE_MONTH** (The): month as a number (1-12).
- **PARSE_DATE_MONTH_NAME** (The): full name of the month.
- **PARSE_DATE_DAY** (The): day of the month.
- **PARSE_DATE_HOUR** (The): hour (0-23), if available.
- **PARSE_DATE_MINUTE** (The): minute (0-59), if available.

#### Exit codes

- **0**: If a date is successfully found and parsed.
- **1**: If no recognizable date is found.

### `_readableUnixTimestamp_` {#readableunixtimestamp}

Formats a Unix timestamp into a human-readable date/time string.

#### Example

```bash
_readableUnixTimestamp_ "1751352022" # -> 2025-07-01 12:00:22
_readableUnixTimestamp_ "1751352022" "%D" # -> 07/01/25
```

#### Arguments

- **\$1** (integer): (required) The Unix timestamp to format.
- **\$2** (string): (optional) The output format string for 'date'. Defaults to "%F %T" (e.g., "2025-07-01 12:30:00").

#### Exit codes

- **0**: On success.
- **1**: If the 'date' command fails.

#### Output on stdout

- The formatted date and time string.

#### See also

- [labbots/bash-utility](https://github.com/labbots/bash-utility/blob/master/src/date.sh)

### `_toSeconds_` {#toseconds}

Converts a time string in HH:MM:SS format to the total number of seconds.

#### Example

```bash
_toSeconds_ "01:02:03" # -> 3723
_toSeconds_ 1 2 3      # -> 3723
```

#### Arguments

- **\$1** (string): (required) The time string to convert.
- **\$2** (integer): (optional) Minutes, if providing H M S as separate arguments.
- **\$3** (integer): (optional) Seconds, if providing H M S as separate arguments.

#### Output on stdout

- The total number of seconds.

