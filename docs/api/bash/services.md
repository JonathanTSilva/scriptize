# services.bash

A utility library for interacting with external network services.

## Overview

This script provides wrapper functions for common network tasks, such as
checking the HTTP status of a URL and sending push notifications via the
Pushover service. These functions depend on the `curl` command-line tool.

## Index

* [`_httpStatus_`](#httpstatus)
* [`_pushover_`](#pushover)

## Shellcheck

- Disable: SC1083

### `_httpStatus_` {#httpstatus}

Reports the HTTP status of a specified URL using `curl`.

#### Example

```bash
# Get the status message for a redirection
_httpStatus_ "bit.ly"
# Output: 301 Redirection: Moved Permanently
```

#### Arguments

- **\$1** (string): (required) The URL to check. The 'https://' prefix is optional.
- **\$2** (integer): (optional) The connection timeout in seconds. Defaults to 3.
- **\$3** (string): (optional) Output mode. Use '--code' or '-c' for the numeric code only, or '--status' or '-s' for the code and message. Defaults to '--status'.
- **...** (\string): (optional) Additional options to pass directly to the `curl` command (e.g., `-L` to follow redirects).

#### Output on stdout

- The HTTP status code, or the code followed by the status message, depending on the output mode.

#### See also

- [Gist by rsvp](https://gist.github.com/rsvp/1171304)

### `_pushover_` {#pushover}

Sends a push notification via the Pushover service.

#### Example

```bash
PUSHOVER_TOKEN="azG...s3"
PUSHOVER_USER="uQ...4s"
if ! _pushover_ "Job Complete" "The backup script finished." "${PUSHOVER_TOKEN}" "${PUSHOVER_USER}"; then
  error "Failed to send Pushover notification."
fi
```

#### Arguments

- **\$1** (string): (required) The title of the notification.
- **\$2** (string): (required) The main message body of the notification.
- **\$3** (string): (required) Your Pushover Application API Token.
- **\$4** (string): (required) Your Pushover User/Group Key.
- **\$5** (string): (optional) The name of a specific device to send the notification to.

#### Exit codes

- **0**: If the notification was sent successfully (HTTP 200 OK).
- **1**: If the `curl` command fails.

#### See also

- [Credit](http://ryonsherman.blogspot.com/2012/10/shell-script-to-send-pushover.html)

