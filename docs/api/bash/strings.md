# strings.bash

A utility library for advanced string manipulation and transformation.

## Overview

This script provides a collection of functions for cleaning, encoding,
decoding, trimming, splitting, and matching strings using various
methods including pure Bash, `sed`, `awk`, and `tr`.

## Index

* [`_cleanString_`](#cleanstring)
* [`_decodeHTML_`](#decodehtml)
* [`_decodeURL_`](#decodeurl)
* [`_encodeHTML_`](#encodehtml)
* [`_encodeURL_`](#encodeurl)
* [`_escapeString_`](#escapestring)
* [`_lower_`](#lower)
* [`_ltrim_`](#ltrim)
* [`_regexCapture_`](#regexcapture)
* [`_rtrim_`](#rtrim)
* [`_stringContains_`](#stringcontains)
* [`_stringRegex_`](#stringregex)
* [`_stripStopwords_`](#stripstopwords)
* [`_stripANSI_`](#stripansi)
* [`_trim_`](#trim)
* [`_upper_`](#upper)

### `_cleanString_` {#cleanstring}

Cleans a string by trimming whitespace, removing duplicate spaces, and applying various transformations.

#### Example

```bash
_cleanString_ "  --Some text__ with extra    stuff--  " # -> --Some text_ with extra stuff--
_cleanString_ -l "  HELLO- WORLD  " # -> hello-world
_cleanString_ -a "foo!@#$%bar" # -> foobar
_cleanString_ -p " ,-" "foo, bar-baz" # -> foobarbaz
```

#### Options

* **-l** | **-L**

  Forces all text to lowercase.

* **-u** | **-U**

  Forces all text to uppercase.

* **-a** | **-A**

  Removes all non-alphanumeric characters except spaces, dashes, and underscores.

* **-s**

  In combination with `-a`, replaces removed characters with a space instead of deleting them.

* **-p \<from,to\>**

  Replaces one character or pattern with another. The argument must be a comma-separated string (e.g., `"_, "`).

#### Arguments

- **\$1** (string): (required) The input string to be cleaned.
- **\$2** (string): (optional) A comma-separated list of specific characters to be removed from the string.

#### Output on stdout

- The cleaned string.

### `_decodeHTML_` {#decodehtml}

Decodes HTML entities in a string (e.g., `&amp;` becomes `&`).

#### Example

```bash
_decodeHTML_ "Bash&amp;apos;s great!" # -> Bash's great!
```

#### Arguments

- **\$1** (string): (required) The string to be decoded.

#### Exit codes

- **1**: If the required `sed` definitions file is not found.

#### Output on stdout

- The decoded string.

### `_decodeURL_` {#decodeurl}

Decodes a URL-encoded (percent-encoded) string.

#### Example

```bash
_decodeURL_ "hello%20world%21" # -> hello world!
```

#### Arguments

- **\$1** (string): (required) The URL-encoded string to be decoded.

#### Output on stdout

- The decoded string.

### `_encodeHTML_` {#encodehtml}

Encodes special HTML characters into their corresponding entities (e.g., `&` becomes `&amp;`).

#### Example

```bash
_encodeHTML_ "<p>Tags & stuff</p>" # -> &lt;p&gt;Tags &amp; stuff&lt;/p&gt;
```

#### Arguments

- **\$1** (string): (required) The string to be encoded.

#### Exit codes

- **1**: If the required `sed` definitions file is not found.

#### Output on stdout

- The encoded string.

### `_encodeURL_` {#encodeurl}

URL-encodes a string (percent-encoding).

#### Example

```bash
_encodeURL_ "a key=a value" # -> a%20key%3Da%20value
```

#### Arguments

- **\$1** (string): (required) The string to be encoded.

#### Output on stdout

- The URL-encoded string.

#### See also

- [Gist by cdown](https://gist.github.com/cdown/1163649)

### `_escapeString_` {#escapestring}

Escapes special regex characters in a string by prepending a backslash (`\`).

#### Example

```bash
_escapeString_ "var.$1" # -> var\.\$1
```

#### Arguments

- **...** (\string): (required) The string to be escaped.

#### Output on stdout

- The escaped string.

### `_lower_` {#lower}

Converts a string from stdin to lowercase.

#### Example

```bash
echo "HELLO WORLD" | _lower_ # -> hello world
lower_var=$(_lower_ <<<"SOME TEXT")
```

#### Input on stdin

- The input string.

#### Output on stdout

- The lowercased string.

### `_ltrim_` {#ltrim}

Removes leading whitespace (or a specified character) from a string provided via stdin.

#### Example

```bash
echo "   hello" | _ltrim_ # -> "hello"
echo "___hello" | _ltrim_ "_" # -> "hello"
```

#### Arguments

- **\$1** (string): (optional) The character class to trim. Defaults to `[:space:]`.

#### Input on stdin

- The input string.

#### Output on stdout

- The string with leading characters trimmed.

### `_regexCapture_` {#regexcapture}

Captures the first matching group from a string using a regex pattern.

#### Example

```bash
HEXCODE=$(_regexCapture_ "color: #AABBCC;" "(#[a-fA-F0-9]{6})")
# HEXCODE is now "#AABBCC"
```

#### Options

* **-i** | **-I**

  Ignore case during the regex match.

#### Arguments

- **\$1** (string): (required) The input string to search.
- **\$2** (string): (required) The regex pattern with a capture group.

#### Exit codes

- **0**: If the regex matched.
- **1**: If the regex did not match.

#### Output on stdout

- The content of the first captured group (`BASH_REMATCH[1]`).

#### See also

- [pure-bash-bible](https://github.com/dylanaraps/pure-bash-bible)

### `_rtrim_` {#rtrim}

Removes trailing whitespace (or a specified character) from a string provided via stdin.

#### Example

```bash
echo "hello   " | _rtrim_ # -> "hello"
echo "hello___" | _rtrim_ "_" # -> "hello"
```

#### Arguments

- **\$1** (string): (optional) The character class to trim. Defaults to `[:space:]`.

#### Input on stdin

- The input string.

#### Output on stdout

- The string with trailing characters trimmed.

### `_stringContains_` {#stringcontains}

Tests whether a string contains a given substring.

#### Example

```bash
if _stringContains_ "Hello World" "World"; then echo "Found."; fi
if _stringContains_ -i "Hello World" "world"; then echo "Found case-insensitively."; fi
```

#### Options

* **-i** | **-I**

  Ignore case during the search.

#### Arguments

- **\$1** (string): (required) The haystack (the string to search within).
- **\$2** (string): (required) The needle (the substring to search for).

#### Exit codes

- **0**: If the substring is found.
- **1**: If the substring is not found.

### `_stringRegex_` {#stringregex}

Tests whether a string contains a given substring.

#### Example

```bash
if _stringContains_ "Hello World" "World"; then echo "Found."; fi
if _stringContains_ -i "Hello World" "world"; then echo "Found case-insensitively."; fi
```

#### Options

* **-i** | **-I**

  Ignore case during the search.

#### Arguments

- **\$1** (string): (required) The haystack (the string to search within).
- **\$2** (string): (required) The needle (the substring to search for).

#### Exit codes

- **0**: If the substring is found.
- **1**: If the substring is not found.

### `_stripStopwords_` {#stripstopwords}

Removes common English stopwords from a string.

#### Example

```bash
_stripStopwords_ "this is a test sentence" # -> "test sentence"
```

#### Arguments

- **\$1** (string): (required) The string to parse.
- **\$2** (string): (optional) A comma-separated list of additional stopwords to remove.

#### Output on stdout

- The string with stopwords removed.

### `_stripANSI_` {#stripansi}

Strips all ANSI escape sequences (color codes, etc.) from a string.

#### Example

```bash
clean_text=$(_stripANSI_ $'\e[1;31mHello\e[0m')
# clean_text is now "Hello"
```

#### Arguments

- **\$1** (string): (required) The string containing ANSI codes.

#### Output on stdout

- The clean string with all ANSI sequences removed.

### `_trim_` {#trim}

Removes all leading/trailing whitespace and reduces internal duplicate spaces to a single space.

#### Example

```bash
echo "  hello   world  " | _trim_ # -> "hello world"
trimmed_var=$(_trim_ <<<"  some text  ")
```

#### Input on stdin

- The input string.

#### Output on stdout

- The trimmed string.

### `_upper_` {#upper}

Converts a string from stdin to uppercase.

#### Example

```bash
echo "hello world" | _upper_ # -> HELLO WORLD
upper_var=$(_upper_ <<<"some text")
```

#### Input on stdin

- The input string.

#### Output on stdout

- The uppercased string.

