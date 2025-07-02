#=============================================================================
# @file alerts.bash
# @brief A library of functions for providing colorful, leveled alerts and logging them to a file.
# @description
#   This library provides a set of functions to print standardized messages
#   to the screen and to a log file. It supports multiple alert levels,
#   color-coded output, and automatic detection of terminal capabilities.
#
#   Global variables used by this library:
#     - QUIET:    (true/false) Suppresses all screen output if true.
#     - VERBOSE:  (true/false) Enables DEBUG level messages on screen if true.
#     - LOGLEVEL: (string) Sets the logging verbosity (e.g., ERROR, INFO, DEBUG).
#     - LOGFILE:  (path) The full path to the log file.
#     - COLUMNS:  (integer) The width of the terminal.
#
#=============================================================================
# shellcheck disable=SC2034,SC2154

# @description Sets global color variables for use52 in alerts.
#   It auto-detects if the terminal supports 256 colors and falls back gracefully.
#
# @example
#   _setColors_
#   printf "%s\n" "${blue}Some blue text${reset}"
_setColors_() {
    if tput setaf 1 >/dev/null 2>&1; then
        bold=$(tput bold)
        underline=$(tput smul)
        reverse=$(tput rev)
        reset=$(tput sgr0)

        if [[ $(tput colors) -ge 256 ]] >/dev/null 2>&1; then
            white=$(tput setaf 231)
            blue=$(tput setaf 38)
            yellow=$(tput setaf 11)
            green=$(tput setaf 82)
            red=$(tput setaf 9)
            purple=$(tput setaf 171)
            gray=$(tput setaf 250)
        else
            white=$(tput setaf 7)
            blue=$(tput setaf 38)
            yellow=$(tput setaf 3)
            green=$(tput setaf 2)
            red=$(tput setaf 9)
            purple=$(tput setaf 13)
            gray=$(tput setaf 7)
        fi
    else
        bold="\033[4;37m"
        reset="\033[0m"
        underline="\033[4;37m"
        # shellcheck disable=SC2034
        reverse=""
        white="\033[0;37m"
        blue="\033[0;34m"
        yellow="\033[0;33m"
        green="\033[1;32m"
        red="\033[0;31m"
        purple="\033[0;35m"
        gray="\033[0;37m"
    fi
}

# @description The core engine for all alerts. Controls printing of messages to stdout and log files.
#   This function is typically not called directly, but through its wrappers (error, info, etc.).
#
# @arg $1 string (required) The type of alert: success, header, notice, dryrun, debug, warning, error, fatal, info, input.
# @arg $2 string (required) The message to be printed.
# @arg $3 integer (optional) The line number, passed via `${LINENO}` to show where the alert was triggered.
#
# @stdout The formatted and colorized message.
# @stderr Nothing is printed to stderr.
#
# @note The colors for each alert type are defined within this function.
# @note For `fatal` and `error` alerts, the function stack is automatically printed.
#
# @see error()
# @see info()
# @see fatal()
#
# @example
#   _alert_ "success" "The operation was completed." "${LINENO}"
_alert_() {
    local _color
    local _alertType="${1}"
    local _message="${2}"
    local _line="${3:-}" # Optional line number

    [[ $# -lt 2 ]] && fatal 'Missing required argument to _alert_'

    if [[ -n ${_line} && ${_alertType} =~ ^(fatal|error) && ${FUNCNAME[2]} != "_trapCleanup_" ]]; then
        _message="${_message} ${gray}(line: ${_line}) $(_printFuncStack_)"
    elif [[ -n ${_line} && ${FUNCNAME[2]} != "_trapCleanup_" ]]; then
        _message="${_message} ${gray}(line: ${_line})"
    elif [[ -z ${_line} && ${_alertType} =~ ^(fatal|error) && ${FUNCNAME[2]} != "_trapCleanup_" ]]; then
        _message="${_message} ${gray}$(_printFuncStack_)"
    fi

    if [[ ${_alertType} =~ ^(error|fatal) ]]; then
        _color="${bold}${red}"
    elif [ "${_alertType}" == "info" ]; then
        _color="${gray}"
    elif [ "${_alertType}" == "warning" ]; then
        _color="${red}"
    elif [ "${_alertType}" == "success" ]; then
        _color="${green}"
    elif [ "${_alertType}" == "debug" ]; then
        _color="${purple}"
    elif [ "${_alertType}" == "header" ]; then
        _color="${bold}${white}${underline}"
    elif [ "${_alertType}" == "notice" ]; then
        _color="${bold}"
    elif [ "${_alertType}" == "input" ]; then
        _color="${bold}${underline}"
    elif [ "${_alertType}" = "dryrun" ]; then
        _color="${blue}"
    else
        _color=""
    fi

    _writeToScreen_() {
        [[ ${QUIET} == true ]] && return 0 # Print to console when script is not 'quiet'
        [[ ${VERBOSE} == false && ${_alertType} =~ ^(debug|verbose) ]] && return 0

        if ! [[ -t 1 || -z ${TERM:-} ]]; then # Don't use colors on non-recognized terminals
            _color=""
            reset=""
        fi

        if [[ ${_alertType} == header ]]; then
            printf "${_color}%s${reset}\n" "${_message}"
        else
            printf "${_color}[%7s] %s${reset}\n" "${_alertType}" "${_message}"
        fi
    }
    _writeToScreen_

    _writeToLog_() {
        [[ ${_alertType} == "input" ]] && return 0
        [[ ${LOGLEVEL} =~ (off|OFF|Off) ]] && return 0
        if [ -z "${LOGFILE:-}" ]; then
            LOGFILE="$(pwd)/$(basename "$0").log"
        fi
        [ ! -d "$(dirname "${LOGFILE}")" ] && mkdir -p "$(dirname "${LOGFILE}")"
        [[ ! -f ${LOGFILE} ]] && touch "${LOGFILE}"

        # Don't use colors in logs
        local _cleanmessage
        _cleanmessage="$(printf "%s" "${_message}" | sed -E 's/(\x1b)?\[(([0-9]{1,2})(;[0-9]{1,3}){0,2})?[mGK]//g')"
        # Print message to log file
        printf "%s [%7s] %s %s\n" "$(date +"%b %d %R:%S")" "${_alertType}" "[$(/bin/hostname)]" "${_cleanmessage}" >>"${LOGFILE}"
    }

    # Write specified log level data to logfile
    case "${LOGLEVEL:-ERROR}" in
    ALL | all | All)
        _writeToLog_
        ;;
    DEBUG | debug | Debug)
        _writeToLog_
        ;;
    INFO | info | Info)
        if [[ ${_alertType} =~ ^(error|fatal|warning|info|notice|success) ]]; then
            _writeToLog_
        fi
        ;;
    NOTICE | notice | Notice)
        if [[ ${_alertType} =~ ^(error|fatal|warning|notice|success) ]]; then
            _writeToLog_
        fi
        ;;
    WARN | warn | Warn)
        if [[ ${_alertType} =~ ^(error|fatal|warning) ]]; then
            _writeToLog_
        fi
        ;;
    ERROR | error | Error)
        if [[ ${_alertType} =~ ^(error|fatal) ]]; then
            _writeToLog_
        fi
        ;;
    FATAL | fatal | Fatal)
        if [[ ${_alertType} =~ ^fatal ]]; then
            _writeToLog_
        fi
        ;;
    OFF | off)
        return 0
        ;;
    *)
        if [[ ${_alertType} =~ ^(error|fatal) ]]; then
            _writeToLog_
        fi
        ;;
    esac

} # /_alert_

# @description Prints an error message. A wrapper for `_alert_`.
# @arg $1 string (required) The message to print.
# @arg $2 integer (optional) The line number (`${LINENO}`).
# @see _alert_
error() { _alert_ error "${1}" "${2:-}"; }

# @description Prints a warning message. A wrapper for `_alert_`.
# @arg $1 string (required) The message to print.
# @arg $2 integer (optional) The line number (`${LINENO}`).
# @see _alert_
warning() { _alert_ warning "${1}" "${2:-}"; }

# @description Prints a notice message (bold). A wrapper for `_alert_`.
# @arg $1 string (required) The message to print.
# @arg $2 integer (optional) The line number (`${LINENO}`).
# @see _alert_
notice() { _alert_ notice "${1}" "${2:-}"; }

# @description Prints an informational message (gray). A wrapper for `_alert_`.
# @arg $1 string (required) The message to print.
# @arg $2 integer (optional) The line number (`${LINENO}`).
# @see _alert_
info() { _alert_ info "${1}" "${2:-}"; }

# @description Prints a success message (green). A wrapper for `_alert_`.
# @arg $1 string (required) The message to print.
# @arg $2 integer (optional) The line number (`${LINENO}`).
# @see _alert_
success() { _alert_ success "${1}" "${2:-}"; }

# @description Prints a dryrun message (blue). A wrapper for `_alert_`.
# @arg $1 string (required) The message to print.
# @arg $2 integer (optional) The line number (`${LINENO}`).
# @see _alert_
dryrun() { _alert_ dryrun "${1}" "${2:-}"; }

# @description Prints an input prompt message (bold/underline). A wrapper for `_alert_`.
# @arg $1 string (required) The message to print.
# @arg $2 integer (optional) The line number (`${LINENO}`).
# @see _alert_
input() { _alert_ input "${1}" "${2:-}"; }

# @description Prints a header message (bold/white/underline). A wrapper for `_alert_`.
# @arg $1 string (required) The message to print.
# @arg $2 integer (optional) The line number (`${LINENO}`).
# @see _alert_
header() { _alert_ header "${1}" "${2:-}"; }

# @description Prints a debug message (purple). A wrapper for `_alert_`.
# @arg $1 string (required) The message to print.
# @arg $2 integer (optional) The line number (`${LINENO}`).
# @see _alert_
debug() { _alert_ debug "${1}" "${2:-}"; }

# @description Prints a fatal error message and exits the script with code 1. A wrapper for `_alert_`.
# @arg $1 string (required) The message to print.
# @arg $2 integer (optional) The line number (`${LINENO}`).
# @exitcode 1 Always returns 1 to signify an error.
# @see _alert_
fatal() {
    _alert_ fatal "${1}" "${2:-}"
    return 1
}

# @description Prints the current function stack. Used for debugging and error reporting.
# @stdout Prints the stack trace in the format `( [function1]:[file1]:[line1] < [function2]:[file2]:[line2] )`.
# @note This function intelligently omits functions from this library to avoid noise.
_printFuncStack_() {
    local _i
    declare -a _funcStackResponse=()
    for ((_i = 1; _i < ${#BASH_SOURCE[@]}; _i++)); do
        case "${FUNCNAME[${_i}]}" in
        _alert_ | _trapCleanup_ | fatal | error | warning | notice | info | debug | dryrun | header | success)
            continue
            ;;
        *)
            _funcStackResponse+=("${FUNCNAME[${_i}]}:$(basename "${BASH_SOURCE[${_i}]}"):${BASH_LINENO[_i - 1]}")
            ;;
        esac

    done
    printf "( "
    printf %s "${_funcStackResponse[0]}"
    printf ' < %s' "${_funcStackResponse[@]:1}"
    printf ' )\n'
}

# @description Prints text centered in the terminal window.
# @arg $1 string (required) Text to center.
# @arg $2 char (optional) Fill character to use for padding. Defaults to a space.
# @stdout The centered text, padded with the fill character.
# @exitcode 1 If no arguments are provided.
# @see [Credit](https://github.com/labbots/bash-utility)
# @example
#   _centerOutput_ "--- Main Menu ---" "-"
_centerOutput_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"
    local _input="${1}"
    local _symbol="${2:- }"
    local _filler
    local _out
    local _no_ansi_out
    local i

    _no_ansi_out=$(_stripANSI_ "${_input}")
    declare -i _str_len=${#_no_ansi_out}
    declare -i _filler_len="$(((COLUMNS - _str_len) / 2))"

    [[ -n ${_symbol} ]] && _symbol="${_symbol:0:1}"
    for ((i = 0; i < _filler_len; i++)); do
        _filler+="${_symbol}"
    done

    _out="${_filler}${_input}${_filler}"
    [[ $(((COLUMNS - _str_len) % 2)) -ne 0 ]] && _out+="${_symbol}"
    printf "%s\n" "${_out}"
}

# @description Clears a specified number of lines in the terminal above the current cursor position.
# @arg $1 integer (optional) The number of lines to clear. Defaults to 1.
# @note This function requires `_isTerminal_()` to be available.
# @see _isTerminal_
# @example
#   echo "This line will be cleared."
#   sleep 2
#   _clearLine_ 1
_clearLine_() (
    ! declare -f _isTerminal_ &>/dev/null && fatal "${FUNCNAME[0]} needs function _isTerminal_"

    local _num="${1:-1}"
    local i

    if _isTerminal_; then
        for ((i = 0; i < _num; i++)); do
            printf "\033[A\033[2K"
        done
    fi
)

# @description Prints output in two columns with fixed widths and text wrapping.
# @option -b | -B Bold the left column.
# @option -u | -U Underline the left column.
# @option -r | -R Reverse colors for the left column.
# @arg $1 string (required) Key name (Left column text).
# @arg $2 string (required) Long value (Right column text. Wraps if too long).
# @arg $3 integer (optional) Number of 2-space tabs to indent the output. Default is 0.
# @arg $4 integer (optional) Total character width of the left column. Default is 35.
# @stdout The formatted two-column output.
# @exitcode 1 If required arguments are missing or an unrecognized option is passed.
# @note Long text or ANSI colors in the first column may create display issues.
# @example
#   _columns_ -b "Status" "All systems are operational and running at peak performance."
_columns_() {
    [[ $# -lt 2 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local opt
    local OPTIND=1
    local _style=""
    while getopts ":bBuUrR" opt; do
        case ${opt} in
        b | B) _style="${_style}${bold}" ;;
        u | U) _style="${_style}${underline}" ;;
        r | R) _style="${_style}${reverse}" ;;
        *) fatal "Unrecognized option '${1}' passed to ${FUNCNAME[0]}. Exiting." ;;
        esac
    done
    shift $((OPTIND - 1))

    local _key="${1}"
    local _value="${2}"
    local _tabLevel="${3:-0}"
    local _leftColumnWidth="${4:-35}"
    local _tabSize=2
    local _line
    local _rightIndent
    local _leftIndent

    _leftIndent="$((_tabLevel * _tabSize))"

    local _leftColumnWidth="$((_leftColumnWidth - _leftIndent))"

    if [ "$(tput cols)" -gt 180 ]; then
        _rightIndent=110
    elif [ "$(tput cols)" -gt 160 ]; then
        _rightIndent=90
    elif [ "$(tput cols)" -gt 130 ]; then
        _rightIndent=60
    elif [ "$(tput cols)" -gt 120 ]; then
        _rightIndent=50
    elif [ "$(tput cols)" -gt 110 ]; then
        _rightIndent=40
    elif [ "$(tput cols)" -gt 100 ]; then
        _rightIndent=30
    elif [ "$(tput cols)" -gt 90 ]; then
        _rightIndent=20
    elif [ "$(tput cols)" -gt 80 ]; then
        _rightIndent=10
    else
        _rightIndent=0
    fi

    local _rightWrapLength=$(($(tput cols) - _leftColumnWidth - _leftIndent - _rightIndent))

    local _first_line=0
    while read -r _line; do
        if [[ ${_first_line} -eq 0 ]]; then
            _first_line=1
        else
            _key=" "
        fi
        printf "%-${_leftIndent}s${_style}%-${_leftColumnWidth}b${reset} %b\n" "" "${_key}${reset}" "${_line}"
    done <<<"$(fold -w${_rightWrapLength} -s <<<"${_value}")"
}

# Simple comments (do not show in the section)
# * Highlited comment
# ! Attention comment (Error, Warning...)
# ? Question comment
# TODO: todo item

#   [ ] todo: some entry
# - [ ] todo: some list entry
# ! [ ] BUG: important thing
# ? [ ] MARK: still todo?
# - [x] FIX: we already have fixed that
# ? [x] FIX: should be fixed already
