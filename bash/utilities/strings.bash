#=============================================================================
# @file strings.bash
# @brief A utility library for advanced string manipulation and transformation.
# @description
#   This script provides a collection of functions for cleaning, encoding,
#   decoding, trimming, splitting, and matching strings using various
#   methods including pure Bash, `sed`, `awk`, and `tr`.
#
# @see [bashful](https://github.com/jmcantrell/bashful)
#=============================================================================

# @description Cleans a string by trimming whitespace, removing duplicate spaces, and applying various transformations.
#
# @option -l | -L Forces all text to lowercase.
# @option -u | -U Forces all text to uppercase.
# @option -a | -A Removes all non-alphanumeric characters except spaces, dashes, and underscores.
# @option -s In combination with `-a`, replaces removed characters with a space instead of deleting them.
# @option -p <from,to> Replaces one character or pattern with another. The argument must be a comma-separated string (e.g., `"_, "`).
#
# @arg $1 string (required) The input string to be cleaned.
# @arg $2 string (optional) A comma-separated list of specific characters to be removed from the string.
#
# @stdout The cleaned string.
#
# @note This function always performs the following cleaning steps:
#   - Trims leading and trailing whitespace.
#   - Squeezes multiple spaces into a single space.
#   - Removes spaces around dashes and underscores.
#
# @example
#   _cleanString_ "  --Some text__ with extra    stuff--  " # -> --Some text_ with extra stuff--
#   _cleanString_ -l "  HELLO- WORLD  " # -> hello-world
#   _cleanString_ -a "foo!@#$%bar" # -> foobar
#   _cleanString_ -p " ,-" "foo, bar-baz" # -> foobarbaz
#
_cleanString_() {
    local opt
    local _lc=false
    local _uc=false
    local _alphanumeric=false
    local _replace=false
    local _us=false

    local OPTIND=1
    while getopts ":lLuUaAsSpP" opt; do
        case ${opt} in
        l | L) _lc=true ;;
        u | U) _uc=true ;;
        a | A) _alphanumeric=true ;;
        s | S) _us=true ;;
        p | P)
            shift
            declare -a _pairs=()
            IFS=',' read -r -a _pairs <<<"$1"
            _replace=true
            ;;
        *)
            {
                error "Unrecognized option '$1' passed to _execute. Exiting."
                return 1
            }
            ;;
        esac
    done
    shift $((OPTIND - 1))

    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _string="${1}"
    local _userChars="${2:-}"

    declare -a _arrayToClean=()
    IFS=',' read -r -a _arrayToClean <<<"${_userChars}"

    # trim trailing/leading white space and duplicate spaces/tabs
    _string="$(printf "%s" "${_string}" | awk '{$1=$1};1')"

    local i
    for i in "${_arrayToClean[@]}"; do
        debug "cleaning: ${i}"
        _string="$(printf "%s" "${_string}" | sed "s/${i}//g")"
    done

    ("${_lc}") &&
        _string="$(printf "%s" "${_string}" | tr '[:upper:]' '[:lower:]')"

    ("${_uc}") &&
        _string="$(printf "%s" "${_string}" | tr '[:lower:]' '[:upper:]')"

    if "${_alphanumeric}" && "${_us}"; then
        _string="$(printf "%s" "${_string}" | tr -c '[:alnum:]_ -' ' ')"
    elif "${_alphanumeric}"; then
        _string="$(printf "%s" "${_string}" | sed "s/[^a-zA-Z0-9_ \-]//g")"
    fi

    if "${_replace}"; then
        _string="$(printf "%s" "${_string}" | sed -E "s/${_pairs[0]}/${_pairs[1]}/g")"
    fi

    # trim trailing/leading white space and duplicate dashes & spaces
    _string="$(printf "%s" "${_string}" | tr -s '-' | tr -s '_')"
    _string="$(printf "%s" "${_string}" | sed -E 's/([_\-]) /\1/g' | sed -E 's/ ([_\-])/\1/g')"
    _string="$(printf "%s" "${_string}" | awk '{$1=$1};1')"

    printf "%s\n" "${_string}"

}

# @description Decodes HTML entities in a string (e.g., `&amp;` becomes `&`).
#
# @arg $1 string (required) The string to be decoded.
#
# @stdout The decoded string.
# @exitcode 1 If the required `sed` definitions file is not found.
#
# @note This function requires a predefined `sed` file for replacements, expected at `~/.sed/html_decode.sed`.
#
# @example
#   _decodeHTML_ "Bash&amp;apos;s great!" # -> Bash's great!
#
_decodeHTML_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _sedFile
    _sedFile="${HOME}/.sed/html_decode.sed"

    [ -f "${_sedFile}" ] &&
        { printf "%s\n" "${1}" | sed -f "${_sedFile}"; } ||
        return 1
}

# @description Decodes a URL-encoded (percent-encoded) string.
#
# @arg $1 string (required) The URL-encoded string to be decoded.
#
# @stdout The decoded string.
#
# @example
#   _decodeURL_ "hello%20world%21" # -> hello world!
#
_decodeURL_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _url_encoded="${1//+/ }"
    printf '%b' "${_url_encoded//%/\\x}"
}

# @description Encodes special HTML characters into their corresponding entities (e.g., `&` becomes `&amp;`).
#
# @arg $1 string (required) The string to be encoded.
#
# @stdout The encoded string.
# @exitcode 1 If the required `sed` definitions file is not found.
#
# @note This function requires a predefined `sed` file for replacements, expected at `~/.sed/html_encode.sed`.
#
# @example
#   _encodeHTML_ "<p>Tags & stuff</p>" # -> &lt;p&gt;Tags &amp; stuff&lt;/p&gt;
#
_encodeHTML_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _sedFile
    _sedFile="${HOME}/.sed/html_encode.sed"

    [ -f "${_sedFile}" ] &&
        { printf "%s" "${1}" | sed -f "${_sedFile}"; } ||
        return 1
}

# @description URL-encodes a string (percent-encoding).
#
# @arg $1 string (required) The string to be encoded.
#
# @stdout The URL-encoded string.
#
# @example
#   _encodeURL_ "a key=a value" # -> a%20key%3Da%20value
#
# @see [Gist by cdown](https://gist.github.com/cdown/1163649)
_encodeURL_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local LANG=C
    local i

    for ((i = 0; i < ${#1}; i++)); do
        if [[ ${1:i:1} =~ ^[a-zA-Z0-9\.\~_-]$ ]]; then
            printf "%s" "${1:i:1}"
        else
            printf '%%%02X' "'${1:i:1}"
        fi
    done
}

# @description Escapes special regex characters in a string by prepending a backslash (`\`).
#
# @arg $@ string (required) The string to be escaped.
#
# @stdout The escaped string.
#
# @example
#   _escapeString_ "var.$1" # -> var\.\$1
#
_escapeString_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    printf "%s\n" "${@}" | sed 's/[]\.|$[ (){}?+*^]/\\&/g'
}

# @description Converts a string from stdin to lowercase.
#
# @stdin The input string.
# @stdout The lowercased string.
#
# @example
#   echo "HELLO WORLD" | _lower_ # -> hello world
#   lower_var=$(_lower_ <<<"SOME TEXT")
#
_lower_() {
    tr '[:upper:]' '[:lower:]'
}

# @description Removes leading whitespace (or a specified character) from a string provided via stdin.
#
# @arg $1 string (optional) The character class to trim. Defaults to `[:space:]`.
#
# @stdin The input string.
# @stdout The string with leading characters trimmed.
#
# @example
#   echo "   hello" | _ltrim_ # -> "hello"
#   echo "___hello" | _ltrim_ "_" # -> "hello"
#
_ltrim_() {
    local _char=${1:-[:space:]}
    sed "s%^[${_char//%/\\%}]*%%"
}

# @description Captures the first matching group from a string using a regex pattern.
#
# @option -i | -I Ignore case during the regex match.
#
# @arg $1 string (required) The input string to search.
# @arg $2 string (required) The regex pattern with a capture group.
#
# @stdout The content of the first captured group (`BASH_REMATCH[1]`).
# @exitcode 0 If the regex matched.
# @exitcode 1 If the regex did not match.
#
# @note This uses Bash's `=~` operator and the `BASH_REMATCH` array.
#
# @example
#   HEXCODE=$(_regexCapture_ "color: #AABBCC;" "(#[a-fA-F0-9]{6})")
#   # HEXCODE is now "#AABBCC"
#
# @see [pure-bash-bible](https://github.com/dylanaraps/pure-bash-bible)
_regexCapture_() {
    local opt
    local OPTIND=1
    while getopts ":iI" opt; do
        case ${opt} in
        i | I)
            #shellcheck disable=SC2064
            trap '$(shopt -p nocasematch)' RETURN # reset nocasematch when function exits
            shopt -s nocasematch                  # Use case-insensitive regex
            ;;
        *) fatal "Unrecognized option '${1}' passed to ${FUNCNAME[0]}. Exiting." ;;
        esac
    done
    shift $((OPTIND - 1))

    [[ $# -lt 2 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    if [[ $1 =~ $2 ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    else
        return 1
    fi
}

# @description Removes trailing whitespace (or a specified character) from a string provided via stdin.
#
# @arg $1 string (optional) The character class to trim. Defaults to `[:space:]`.
#
# @stdin The input string.
# @stdout The string with trailing characters trimmed.
#
# @example
#   echo "hello   " | _rtrim_ # -> "hello"
#   echo "hello___" | _rtrim_ "_" # -> "hello"
#
_rtrim_() {
    local _char=${1:-[:space:]}
    sed "s%[${_char//%/\\%}]*$%%"
}

# @description Splits a string into an array based on a given delimiter.
#
# @arg $1 string (required) The string to be split.
# @arg $2 string (required) The delimiter character.
#
# @stdout The resulting elements, each on a new line.
#
# @example
#   # To populate an array:
#   mapfile -t my_array < <(_splitString_ "apple,banana,cherry" ",")
#   echo ${my_array[1]} # -> banana
#
_splitString_() (
    [[ $# -lt 2 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    declare -a _arr=()
    local _input="${1}"
    local _delimiter="${2}"

    IFS="${_delimiter}" read -r -a _arr <<<"${_input}"

    printf '%s\n' "${_arr[@]}"
)

# @description Tests whether a string contains a given substring.
#
# @option -i | -I Ignore case during the search.
#
# @arg $1 string (required) The haystack (the string to search within).
# @arg $2 string (required) The needle (the substring to search for).
#
# @exitcode 0 If the substring is found.
# @exitcode 1 If the substring is not found.
#
# @example
#   if _stringContains_ "Hello World" "World"; then echo "Found."; fi
#   if _stringContains_ -i "Hello World" "world"; then echo "Found case-insensitively."; fi
#
_stringContains_() {
    local opt
    local OPTIND=1
    while getopts ":iI" opt; do
        case ${opt} in
        i | I)
            #shellcheck disable=SC2064
            trap '$(shopt -p nocasematch)' RETURN # reset nocasematch when function exits
            shopt -s nocasematch                  # Use case-insensitive searching
            ;;
        *) fatal "Unrecognized option '${1}' passed to ${FUNCNAME[0]}. Exiting." ;;
        esac
    done
    shift $((OPTIND - 1))

    [[ $# -lt 2 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    if [[ ${1} == *${2}* ]]; then
        return 0
    else
        return 1
    fi
}

# @description Tests whether a string contains a given substring.
#
# @option -i | -I Ignore case during the search.
#
# @arg $1 string (required) The haystack (the string to search within).
# @arg $2 string (required) The needle (the substring to search for).
#
# @exitcode 0 If the substring is found.
# @exitcode 1 If the substring is not found.
#
# @example
#   if _stringContains_ "Hello World" "World"; then echo "Found."; fi
#   if _stringContains_ -i "Hello World" "world"; then echo "Found case-insensitively."; fi
#
_stringRegex_() {
    local opt
    local OPTIND=1
    while getopts ":iI" opt; do
        case ${opt} in
        i | I)
            #shellcheck disable=SC2064
            trap '$(shopt -p nocasematch)' RETURN # reset nocasematch when function exits
            shopt -s nocasematch                  # Use case-insensitive regex
            ;;
        *) fatal "Unrecognized option '${1}' passed to ${FUNCNAME[0]}. Exiting." ;;
        esac
    done
    shift $((OPTIND - 1))

    [[ $# -lt 2 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    if [[ ${1} =~ ${2} ]]; then
        return 0
    else
        return 1
    fi
}

# @description Removes common English stopwords from a string.
#
# @arg $1 string (required) The string to parse.
# @arg $2 string (optional) A comma-separated list of additional stopwords to remove.
#
# @stdout The string with stopwords removed.
#
# @note Requires GNU `sed`.
# @note Requires a predefined `sed` file for the main stopword list, expected at `~/.sed/stopwords.sed`.
#
# @example
#   _stripStopwords_ "this is a test sentence" # -> "test sentence"
#
_stripStopwords_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    if ! sed --version | grep GNU &>/dev/null; then
        fatal "_stripStopwords_: Required GNU sed not found. Exiting."
    fi

    local _string="${1}"
    local _sedFile="${HOME}/.sed/stopwords.sed"
    local _w

    if [ -f "${_sedFile}" ]; then
        _string="$(printf "%s" "${_string}" | sed -f "${_sedFile}")"
    else
        fatal "_stripStopwords_: Missing sedfile expected at: ${_sedFile}"
    fi

    declare -a _localStopWords=()
    IFS=',' read -r -a _localStopWords <<<"${2:-}"

    if [[ ${#_localStopWords[@]} -gt 0 ]]; then
        for _w in "${_localStopWords[@]}"; do
            _string="$(printf "%s" "${_string}" | sed -E "s/\b${_w}\b//gI")"
        done
    fi

    # Remove double spaces and trim left/right
    _string="$(printf "%s" "${_string}" | sed -E 's/[ ]{2,}/ /g' | _trim_)"

    printf "%s\n" "${_string}"

}

# @description Strips all ANSI escape sequences (color codes, etc.) from a string.
#
# @arg $1 string (required) The string containing ANSI codes.
#
# @stdout The clean string with all ANSI sequences removed.
#
# @example
#   clean_text=$(_stripANSI_ $'\e[1;31mHello\e[0m')
#   # clean_text is now "Hello"
#
_stripANSI_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"
    local _tmp
    local _esc
    local _tpa
    local _re
    _tmp="${1}"
    _esc=$(printf "\x1b")
    _tpa=$(printf "\x28")
    _re="(.*)${_esc}[\[${_tpa}][0-9]*;*[mKB](.*)"
    while [[ ${_tmp} =~ ${_re} ]]; do
        _tmp="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
    done
    printf "%s" "${_tmp}"
}

# @description Removes all leading/trailing whitespace and reduces internal duplicate spaces to a single space.
#
# @stdin The input string.
# @stdout The trimmed string.
#
# @example
#   echo "  hello   world  " | _trim_ # -> "hello world"
#   trimmed_var=$(_trim_ <<<"  some text  ")
#
_trim_() {
    awk '{$1=$1;print}'
}

# @description Converts a string from stdin to uppercase.
#
# @stdin The input string.
# @stdout The uppercased string.
#
# @example
#   echo "hello world" | _upper_ # -> HELLO WORLD
#   upper_var=$(_upper_ <<<"some text")
#
_upper_() {
    tr '[:lower:]' '[:upper:]'
}
