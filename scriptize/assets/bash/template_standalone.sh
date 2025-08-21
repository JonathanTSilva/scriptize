#!/usr/bin/env bash
#=============================================================================
# @file template_standalone.sh
# @brief A robust, self-contained boilerplate for creating powerful and safe Bash scripts.
# @description
#   This script is a standalone version of the script template, with all essential
#   utility functions included directly in the file. It provides a standard
#   structure and best practices for error handling, argument parsing, and logging,
#   without any external dependencies on other utility files.
#=============================================================================

#=============================================================================
#----------------------------------- MAIN ------------------------------------
#=============================================================================
# @description
#   This is the main entry point for the script's logic.
#   Replace the content of this function with your own code.
_mainScript_() {

    # Replace everything in _mainScript_() with your script's code
    header "Showing alert colors"
    debug "This is debug text"
    info "This is info text"
    notice "This is notice text"
    dryrun "This is dryrun text"
    warning "This is warning text"
    error "This is error text"
    success "This is success text"
    input "This is input text"

}
# end _mainScript_

# ################################## Flags and defaults
# Required variables
LOGFILE="${HOME}/logs/$(basename "$0").log"
QUIET=false
LOGLEVEL=ERROR
VERBOSE=false
FORCE=false
DRYRUN=false
declare -a ARGS=()

# Script specific

# ################################## Custom utility functions (Pasted from repository)

# ################################## Functions required for this template to work

# @description Sets global color variables for use in alerts.
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

        local colors
        colors=$(tput colors 2>/dev/null)
        if [[ -n "${colors}" && ${colors} -ge 256 ]]; then
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
#
# @note For `fatal` and `error` alerts, the function stack is automatically printed.
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
        local _func_stack_string
        _func_stack_string=$(_printFuncStack_)
        _message="${_message} ${gray}(line: ${_line}) ${_func_stack_string}"
    elif [[ -n ${_line} && ${FUNCNAME[2]} != "_trapCleanup_" ]]; then
        _message="${_message} ${gray}(line: ${_line})"
    elif [[ -z ${_line} && ${_alertType} =~ ^(fatal|error) && ${FUNCNAME[2]} != "_trapCleanup_" ]]; then
        local _func_stack_string
        _func_stack_string=$(_printFuncStack_)
        _message="${_message} ${gray}${_func_stack_string}"
    fi

    if [[ ${_alertType} =~ ^(error|fatal) ]]; then
        _color="${bold}${red}"
    elif [[ "${_alertType}" == "info" ]]; then
        _color="${gray}"
    elif [[ "${_alertType}" == "warning" ]]; then
        _color="${red}"
    elif [[ "${_alertType}" == "success" ]]; then
        _color="${green}"
    elif [[ "${_alertType}" == "debug" ]]; then
        _color="${purple}"
    elif [[ "${_alertType}" == "header" ]]; then
        _color="${bold}${white}${underline}"
    elif [[ "${_alertType}" == "notice" ]]; then
        _color="${bold}"
    elif [[ "${_alertType}" == "input" ]]; then
        _color="${bold}${underline}"
    elif [[ "${_alertType}" == "dryrun" ]]; then
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
        if [[ -z "${LOGFILE:-}" ]]; then
            local _pwd
            _pwd=$(pwd)
            LOGFILE="${_pwd}/$(basename "$0").log"
        fi
        local _log_dir
        _log_dir=$(dirname "${LOGFILE}")
        [[ ! -d "${_log_dir}" ]] && mkdir -p "${_log_dir}"
        [[ ! -f ${LOGFILE} ]] && touch "${LOGFILE}"

        # Don't use colors in logs
        local _cleanmessage
        _cleanmessage="$(printf "%s" "${_message}" | sed -E 's/(\x1b)?\[(([0-9]{1,2})(;[0-9]{1,3}){0,2})?[mGK]//g')"
        # Print message to log file
        local _timestamp _hostname
        _timestamp=$(date +"%b %d %R:%S")
        _hostname=$(/bin/hostname)
        printf "%s [%7s] %s %s\n" "${_timestamp}" "${_alertType}" "[${_hostname}]" "${_cleanmessage}" >>"${LOGFILE}"
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

error() { _alert_ error "${1}" "${2:-}"; }
warning() { _alert_ warning "${1}" "${2:-}"; }
notice() { _alert_ notice "${1}" "${2:-}"; }
info() { _alert_ info "${1}" "${2:-}"; }
success() { _alert_ success "${1}" "${2:-}"; }
dryrun() { _alert_ dryrun "${1}" "${2:-}"; }
input() { _alert_ input "${1}" "${2:-}"; }
header() { _alert_ header "${1}" "${2:-}"; }
debug() { _alert_ debug "${1}" "${2:-}"; }
fatal() {
    _alert_ fatal "${1}" "${2:-}"
    _safeExit_ "1"
}

# @description Prints the current function stack. Used for debugging and error reporting.
#
# @stdout Prints the stack trace in the format `( [function1]:[file1]:[line1] < [function2]:[file2]:[line2] )`.
#
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

# @description Performs cleanup tasks and exits the script with a given code.
#   This function is intended to be called by a `trap` at the start of a script.
#
# @arg $1 integer (optional) The exit code to use. Defaults to 0 (success).
#
# @note This function automatically removes the script lock (if set by `_acquireScriptLock_`)
#   and the temporary directory (if set by `_makeTempDir_`).
#
# @example
#   # Set trap at the beginning of a script
#   trap '_safeExit_' EXIT INT TERM
#
#   # Exit with an error code
#   _safeExit_ 1
#
# @see _acquireScriptLock_()
# @see _makeTempDir_()
_safeExit_() {
    if [[ -d ${SCRIPT_LOCK:-} ]]; then
        if command rm -rf "${SCRIPT_LOCK}"; then
            debug "Removing script lock"
        else
            # shellcheck disable=SC2154
            warning "Script lock could not be removed. Try manually deleting ${yellow}'${SCRIPT_LOCK}'"
        fi
    fi

    if [[ -n ${TMP_DIR:-} && -d ${TMP_DIR:-} ]]; then
        local _ls_tmp
        _ls_tmp=$(ls "${TMP_DIR}")
        if [[ ${1:-} == 1 && -n "${_ls_tmp}" ]]; then
            command rm -r "${TMP_DIR}"
        else
            command rm -r "${TMP_DIR}"
            debug "Removing temp directory"
        fi
    fi

    trap - INT TERM EXIT
    exit "${1:-0}"
}

# @description The script's main error handler and cleanup function.
#   This function is called by the `trap` command on any error, interrupt, or exit signal.
#   It logs the error details and ensures a safe exit.
#
# @arg $1 integer (required) The line number where the error was trapped (`${LINENO}`).
# @arg $2 integer (required) The line number in the function where the error occurred (`${BASH_LINENO}`).
# @arg $3 string (required) The command that was executing at the time of the trap (`${BASH_COMMAND}`).
# @arg $4 string (required) The shell function call stack (`${FUNCNAME[*]}`).
# @arg $5 string (required) The name of the script (`${0}`).
# @arg $6 string (required) The source of the script (`${BASH_SOURCE[0]}`).
#
# @exitcode 1 Always exits the script with status 1 after logging the fatal error.
#
# @example
#   trap '_trapCleanup_ ${LINENO} ${BASH_LINENO} "${BASH_COMMAND}" "${FUNCNAME[*]}" "${0}" "${BASH_SOURCE[0]}"' EXIT INT TERM SIGINT SIGQUIT SIGTERM
#
_trapCleanup_() {
    local _line=${1:-} # LINENO
    local _linecallfunc=${2:-}
    local _command="${3:-}"
    local _funcstack="${4:-}"
    local _script="${5:-}"
    local _sourced="${6:-}"

    # Replace the cursor in-case 'tput civis' has been used
    tput cnorm

    if declare -f "fatal" &>/dev/null && declare -f "_printFuncStack_" &>/dev/null; then

        _funcstack="'$(printf "%s" "${_funcstack}" | sed -E 's/ / < /g')'"

        if [[ ${_script##*/} == "${_sourced##*/}" ]]; then
            local _func_stack_string
            _func_stack_string=$(_printFuncStack_)
            fatal "${7:-} command: '${_command}' (line: ${_line}) [func: ${_func_stack_string}]"
        else
            fatal "${7:-} command: '${_command}' (func: ${_funcstack} called at line ${_linecallfunc} of '${_script##*/}') (line: ${_line} of '${_sourced##*/}') "
        fi
    else
        printf "%s\n" "Fatal error trapped. Exiting..."
    fi

    if declare -f _safeExit_ &>/dev/null; then
        _safeExit_ 1
    else
        exit 1
    fi
}

# @description Creates a unique temporary directory for the script to use.
#
# @arg $1 string (optional) A prefix for the temporary directory's name. Defaults to the script's basename.
#
# @set TMP_DIR The absolute path to the newly created temporary directory.
#
# @note The temporary directory is automatically removed by `_safeExit_`.
#
# @example
#   _makeTempDir_ "my-script-session"
#   touch "${TMP_DIR}/my-file.tmp"
#
# @see _safeExit_()
_makeTempDir_() {
    [[ -d "${TMP_DIR:-}" ]] && return 0

    if [[ -n "${1:-}" ]]; then
        TMP_DIR="${TMPDIR:-/tmp/}${1}.${RANDOM}.${RANDOM}.$$"
    else
        TMP_DIR="${TMPDIR:-/tmp/}$(basename "$0").${RANDOM}.${RANDOM}.${RANDOM}.$$"
    fi
    (umask 077 && mkdir "${TMP_DIR}") || {
        fatal "Could not create temporary directory! Exiting."
    }
    debug "\$TMP_DIR=${TMP_DIR}"
}

# @description Acquires a script lock to prevent multiple instances from running simultaneously.
#   The lock is an empty directory created in `/tmp`. The script will exit if the lock
#   cannot be acquired.
#
# @arg $1 string (optional) The scope of the lock. Can be 'system' for a system-wide lock,
#   or defaults to a user-specific lock (based on `$UID`).
#
# @set SCRIPT_LOCK The path to the created lock directory. This variable is exported as readonly.
#
# @note The lock is automatically released by the `_safeExit_` function upon script termination.
#
# @example
#   # Acquire a lock unique to the current user
#   _acquireScriptLock_
#
#   # Acquire a system-wide lock
#   _acquireScriptLock_ "system"
#
# @see _safeExit_()
_acquireScriptLock_() {
    # shellcheck disable=SC2120
    local _lockDir
    if [[ ${1:-} == 'system' ]]; then
        _lockDir="${TMPDIR:-/tmp/}$(basename "$0").lock"
    else
        _lockDir="${TMPDIR:-/tmp/}$(basename "$0").${UID}.lock"
    fi

    if command mkdir "${_lockDir}" 2>/dev/null; then
        readonly SCRIPT_LOCK="${_lockDir}"
        # shellcheck disable=SC2154
        debug "Acquired script lock: ${yellow}${SCRIPT_LOCK}${purple}"
    else
        if declare -f "_safeExit_" &>/dev/null; then
            # shellcheck disable=SC2154
            error "Unable to acquire script lock: ${yellow}${_lockDir}${red}"
            fatal "If you trust the script isn't running, delete the lock dir"
        else
            printf "%s\n" "ERROR: Could not acquire script lock. If you trust the script isn't running, delete: ${_lockDir}"
            exit 1
        fi

    fi
}

# @description Prepends one or more directories to the session's `$PATH` environment variable.
#
# @option -x | -X Fail with an error code if any of the specified directories are not found.
#
# @arg $@ path (required) One or more directory paths to add to the `$PATH`.
#
# @set PATH The modified `$PATH` environment variable.
# @exitcode 0 On success.
# @exitcode 1 If `-x` is used and a directory does not exist.
#
# @example
#   # Add local bin directories to the PATH
#   _setPATH_ "/usr/local/bin" "${HOME}/.local/bin"
#
#   # Add a path and exit if it's not found
#   _setPATH_ -x "/opt/my-app/bin" || exit 1
#
_setPATH_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local opt
    local OPTIND=1
    local _failIfNotFound=false

    while getopts ":xX" opt; do
        case ${opt} in
        x | X) _failIfNotFound=true ;;
        *)
            {
                error "Unrecognized option '${1}' passed to _setPATH_" "${LINENO}"
                return 1
            }
            ;;
        esac
    done
    shift $((OPTIND - 1))

    local _newPath

    for _newPath in "$@"; do
        if [[ -d "${_newPath}" ]]; then
            if ! printf "%s" "${PATH}" | grep -Eq "(^|:)${_newPath}($|:)"; then
                if PATH="${_newPath}:${PATH}"; then
                    debug "Added '${_newPath}' to PATH"
                else
                    debug "'${_newPath}' already in PATH"
                fi
            else
                debug "_setPATH_: '${_newPath}' already exists in PATH"
            fi
        else
            debug "_setPATH_: can not find: ${_newPath}"
            if [[ ${_failIfNotFound} == true ]]; then
                return 1
            fi
            continue
        fi
    done
    return 0
}

# @description Prepends paths to GNU utilities to the session `$PATH`.
#   This allows for consistent script behavior by using GNU versions of `sed`, `grep`, `tar`, etc.,
#   instead of the default BSD versions on macOS.
#
# @exitcode 0 On success.
# @exitcode 1 If the underlying `_setPATH_` function fails.
#
# @note This function assumes GNU utilities have been installed via Homebrew (e.g., `brew install coreutils gnu-sed`).
# @note It requires the `_setPATH_` function to be available.
#
# @example
#   # Call at the beginning of a script to ensure GNU tools are used.
#   _useGNUUtils_
#
# @see _setPATH_()
_useGNUutils_() {
    ! declare -f "_setPATH_" &>/dev/null && fatal "${FUNCNAME[0]} needs function _setPATH_"

    _setPATH_ \
        "/usr/local/opt/gnu-tar/libexec/gnubin" \
        "/usr/local/opt/coreutils/libexec/gnubin" \
        "/usr/local/opt/gnu-sed/libexec/gnubin" \
        "/usr/local/opt/grep/libexec/gnubin" \
        "/usr/local/opt/findutils/libexec/gnubin" \
        "/opt/homebrew/opt/findutils/libexec/gnubin" \
        "/opt/homebrew/opt/gnu-sed/libexec/gnubin" \
        "/opt/homebrew/opt/grep/libexec/gnubin" \
        "/opt/homebrew/opt/coreutils/libexec/gnubin" \
        "/opt/homebrew/opt/gnu-tar/libexec/gnubin"
    return $?

}

# @description Prepends the Homebrew binary directory to the session `$PATH`.
#   This ensures that any tools installed via Homebrew are found by the script.
#   It correctly handles paths for both Intel (`/usr/local/bin`) and Apple Silicon (`/opt/homebrew/bin`).
#
# @exitcode 0 On success.
# @exitcode 1 If the underlying `_setPATH_` function fails.
#
# @note This function is intended for macOS but may work on Linux with Homebrew.
# @note It requires the `_setPATH_` function to be available.
#
# @example
#   # Ensure Homebrew executables are available.
#   _homebrewPath_
#
# @see _setPATH_()
_homebrewPath_() {
    ! declare -f "_setPATH_" &>/dev/null && fatal "${FUNCNAME[0]} needs function _setPATH_"

    if _uname=$(command -v uname); then
        # Check if the OS is macOS ('darwin')
        if "${_uname}" | tr '[:upper:]' '[:lower:]' | grep -q 'darwin'; then
            _setPATH_ "/usr/local/bin" "/opt/homebrew/bin"
            return $?
        fi
    else
        # Fallback if 'uname' command isn't found
        _setPATH_ "/usr/local/bin" "/opt/homebrew/bin"
        return $?
    fi
}

# @description Parses command-line options and arguments passed to the script.
#   It handles combined short options (e.g., `-vn`), long options with equals
#   (e.g., `--logfile=/path/to.log`), and populates the global `$ARGS` array
#   with any remaining non-option arguments.
#
# @arg $@ string (required) The command-line arguments passed to the script (`"$@"`).
#
# @set ARGS An array containing all non-option arguments.
# @set LOGFILE The path to the log file, if specified with `--logfile`.
# @set LOGLEVEL The logging verbosity, if specified with `--loglevel`.
# @set DRYRUN Boolean `true` if `-n` or `--dryrun` is passed.
# @set VERBOSE Boolean `true` if `-v` or `--verbose` is passed.
# @set QUIET Boolean `true` if `-q` or `--quiet` is passed.
# @set FORCE Boolean `true` if `--force` is passed.
#
# @example
#   _parseOptions_ "$@"
#
_parseOptions_() {
    # Iterate over options
    local _optstring=h
    declare -a _options
    local _c
    local i
    while (($#)); do
        case $1 in
        # If option is of type -ab
        -[!-]?*)
            # Loop over each character starting with the second
            for ((i = 1; i < ${#1}; i++)); do
                _c=${1:i:1}
                _options+=("-${_c}") # Add current char to options
                # If option takes a required argument, and it's not the last char make
                # the rest of the string its argument
                if [[ ${_optstring} == *"${_c}:"* && -n ${1:i+1} ]]; then
                    _options+=("${1:i+1}")
                    break
                fi
            done
            ;;
        # If option is of type --foo=bar
        --?*=*) _options+=("${1%%=*}" "${1#*=}") ;;
        # add --endopts for --
        --) _options+=(--endopts) ;;
        # Otherwise, nothing special
        *) _options+=("$1") ;;
        esac
        shift
    done
    set -- "${_options[@]:-}"
    unset _options

    # Read the options and set stuff
    # shellcheck disable=SC2034
    while [[ ${1:-} == -?* ]]; do
        case $1 in
        # Custom options

        # Common options
        -h | --help)
            _usage_
            _safeExit_
            ;;
        --loglevel)
            shift
            LOGLEVEL=${1}
            ;;
        --logfile)
            shift
            LOGFILE="${1}"
            ;;
        -n | --dryrun) DRYRUN=true ;;
        -v | --verbose) VERBOSE=true ;;
        -q | --quiet) QUIET=true ;;
        --force) FORCE=true ;;
        --endopts)
            shift
            break
            ;;
        *)
            if declare -f _safeExit_ &>/dev/null; then
                fatal "invalid option: $1"
            else
                printf "%s\n" "ERROR: Invalid option: $1"
                exit 1
            fi
            ;;
        esac
        shift
    done

    if [[ -z ${*} || ${*} == null ]]; then
        ARGS=()
    else
        ARGS+=("$@") # Store the remaining user input as arguments.
    fi
}

# @description Prints output in two columns with fixed widths and text wrapping.
#
# @option -b | -B Bold the left column.
# @option -u | -U Underline the left column.
# @option -r | -R Reverse colors for the left column.
#
# @arg $1 string (required) Key name (Left column text).
# @arg $2 string (required) Long value (Right column text. Wraps if too long).
# @arg $3 integer (optional) Number of 2-space tabs to indent the output. Default is 0.
#
# @stdout The formatted two-column output.
#
# @note Long text or ANSI colors in the first column may create display issues.
#
# @example
#   _columns_ -b "Status" "All systems are operational."
#
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
    local _tabLevel="${3-}"
    local _tabSize=2
    local _line
    local _rightIndent
    local _leftIndent
    if [[ -z ${3-} ]]; then
        _tabLevel=0
    fi

    _leftIndent="$((_tabLevel * _tabSize))"

    local _leftColumnWidth="$((30 + _leftIndent))"

    local _term_cols
    _term_cols=$(tput cols)

    if [[ "${_term_cols}" -gt 180 ]]; then
        _rightIndent=110
    elif [[ "${_term_cols}" -gt 160 ]]; then
        _rightIndent=90
    elif [[ "${_term_cols}" -gt 130 ]]; then
        _rightIndent=60
    elif [[ "${_term_cols}" -gt 120 ]]; then
        _rightIndent=50
    elif [[ "${_term_cols}" -gt 110 ]]; then
        _rightIndent=40
    elif [[ "${_term_cols}" -gt 100 ]]; then
        _rightIndent=30
    elif [[ "${_term_cols}" -gt 90 ]]; then
        _rightIndent=20
    elif [[ "${_term_cols}" -gt 80 ]]; then
        _rightIndent=10
    else
        _rightIndent=0
    fi

    local _rightWrapLength
    _rightWrapLength=$((_term_cols - _leftColumnWidth - _leftIndent - _rightIndent))

    local _first_line=0
    local _folded_output
    _folded_output=$(fold -w "${_rightWrapLength}" -s <<<"${_value}")
    while read -r _line; do
        if [[ ${_first_line} -eq 0 ]]; then
            _first_line=1
        else
            _key=" "
        fi
        printf "%-${_leftIndent}s${_style}%-${_leftColumnWidth}b${reset} %b\n" "" "${_key}${reset}" "${_line}"
    done <<<"${_folded_output}"
}

# @description Displays the script's help message and usage information.
#
# @stdout The formatted help text.
# @note The content of this function should be edited by the developer to describe their specific script.
#
_usage_() {
    cat <<USAGE_TEXT

  ${bold}$(basename "$0") [OPTION]... [FILE]...${reset}

  This is a script template.  Edit this description to print help to users.

  ${bold}${underline}Options:${reset}
USAGE_TEXT
    _columns_ -b -- '-h, --help' "Display this help and exit" 2
    _columns_ -b -- "--loglevel [LEVEL]" "One of: FATAL, ERROR (default), WARN, INFO, NOTICE, DEBUG, ALL, OFF" 2
    _columns_ -b -- "--logfile [FILE]" "Full PATH to logfile.  (Default is '\${HOME}/logs/$(basename "$0").log')" 2
    _columns_ -b -- "-n, --dryrun" "Non-destructive. Makes no permanent changes." 2
    _columns_ -b -- "-q, --quiet" "Quiet (no output)" 2
    _columns_ -b -- "-v, --verbose" "Output more information. (Items echoed to 'verbose')" 2
    _columns_ -b -- "--force" "Skip all user interaction.  Implied 'Yes' to all actions." 2
    cat <<USAGE_TEXT

  ${bold}${underline}Example Usage:${reset}

    ${gray}# Run the script and specify log level and log file.${reset}
    $(basename "$0") -vn --logfile "/path/to/file.log" --loglevel 'WARN'
USAGE_TEXT
}

#=============================================================================
#----------------------------------- HUB -------------------------------------
#=============================================================================
#----------------------- INITIALIZE AND RUN THE SCRIPT -----------------------
#---- Comment or uncomment the lines below to customize script behavior ------

trap '_trapCleanup_ ${LINENO} ${BASH_LINENO} "${BASH_COMMAND}" "${FUNCNAME[*]}" "${0}" "${BASH_SOURCE[0]}"' EXIT INT TERM SIGINT SIGQUIT SIGTERM

# Trap errors in subshells and functions
set -o errtrace

# Exit on error. Append '||true' if you expect an error
set -o errexit

# Use last non-zero exit code in a pipeline
set -o pipefail

# Confirm we have BASH greater than v4
[[ "${BASH_VERSINFO:-0}" -ge 4 ]] || {
    printf "%s\n" "ERROR: BASH_VERSINFO is '${BASH_VERSINFO:-0}'.  This script requires BASH v4 or greater."
    exit 1
}

# Make `for f in *.txt` work when `*.txt` matches zero files
shopt -s nullglob globstar

# Set IFS to preferred implementation
IFS=$' \n\t'

# Run in debug mode
# set -o xtrace

# Initialize color constants
_setColors_

# Disallow expansion of unset variables
set -o nounset

# Force arguments when invoking the script
# [[ $# -eq 0 ]] && _parseOptions_ "-h"

# Parse arguments passed to script
_parseOptions_ "$@"

# Create a temp directory '$TMP_DIR'
# _makeTempDir_ "$(basename "$0")"

# Acquire script lock
# _acquireScriptLock_

# Add Homebrew bin directory to PATH (MacOS)
# _homebrewPath_

# Source GNU utilities from Homebrew (MacOS)
# _useGNUutils_

# Run the main logic script
_mainScript_

# Exit cleanly
_safeExit_
