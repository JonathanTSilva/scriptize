#=============================================================================
# @file misc.bash
# @brief A library of miscellaneous and foundational utility functions.
# @description
#   This script provides a collection of miscellaneous helper functions that serve
#   as a foundation for other scripts. It includes OS detection, process management
#   (spinners, progress bars), user interaction, and safe command execution wrappers.
#=============================================================================

# @description Enables terminal window size checking.
#   On supported systems, this causes the `$LINES` and `$COLUMNS` variables to be
#   updated automatically when the terminal window is resized.
#
# @note This sets a `trap` on the `SIGWINCH` signal.
#
# @example
#   # Call this at the beginning of an interactive script.
#   _checkTerminalSize_
#
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility)
_checkTerminalSize_() {
    shopt -s checkwinsize && (: && :)
    trap 'shopt -s checkwinsize; (:;:)' SIGWINCH
}
# @description Identifies the current operating system.
#
# @stdout The name of the OS in lowercase: 'mac', 'linux', or 'windows'.
# @exitcode 1 If the OS could not be determined.
#
# @example
#   os_name=$(_detectOS_)
#   echo "Running on: ${os_name}"
#
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility)
_detectOS_() {
    local _uname
    local _os
    if _uname=$(command -v uname); then
        case $("${_uname}" | tr '[:upper:]' '[:lower:]') in
        linux*)
            _os="linux"
            ;;
        darwin*)
            _os="mac"
            ;;
        msys* | cygwin* | mingw* | nt | win*)
            # or possible 'bash on windows'
            _os="windows"
            ;;
        *)
            return 1
            ;;
        esac
    else
        return 1
    fi
    printf "%s" "${_os}"
}

# @description Detects the specific Linux distribution.
#
# @stdout The name of the Linux distribution in lowercase (e.g., 'ubuntu', 'centos', 'arch').
# @exitcode 1 If not running on Linux or if the distribution cannot be determined.
#
# @example
#   if [[ $(_detectOS_) == "linux" ]]; then
#     distro=$(_detectLinuxDistro_)
#     echo "Linux distro is: ${distro}"
#   fi
#
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility)
_detectLinuxDistro_() {
    local _distro
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091,SC2154
        . "/etc/os-release"
        _distro="${NAME}"
    elif type lsb_release >/dev/null 2>&1; then
        # linuxbase.org
        _distro=$(lsb_release -si)
    elif [[ -f /etc/lsb-release ]]; then
        # For some versions of Debian/Ubuntu without lsb_release command
        # shellcheck disable=SC1091,SC2154
        . /etc/lsb-release
        _distro="${DISTRIB_ID}"
    elif [[ -f /etc/debian_version ]]; then
        # Older Debian/Ubuntu/etc.
        _distro="debian"
    elif [[ -f /etc/SuSe-release ]]; then
        # Older SuSE/etc.
        _distro="suse"
    elif [[ -f /etc/redhat-release ]]; then
        # Older Red Hat, CentOS, etc.
        _distro="redhat"
    else
        return 1
    fi
    printf "%s" "${_distro}" | tr '[:upper:]' '[:lower:]'
}

# @description Detects the product version of macOS.
#
# @stdout The version number of macOS (e.g., '12.5.1').
# @exitcode 1 If not running on macOS.
#
# @note This function requires `_detectOS_` to be available.
#
# @example
#   if [[ $(_detectOS_) == "mac" ]]; then
#     mac_version=$(_detectMacOSVersion_)
#     echo "macOS version: ${mac_version}"
#   fi
#
# @see _detectOS_()
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility)
_detectMacOSVersion_() {
    declare -f _detectOS_ &>/dev/null || fatal "${FUNCNAME[0]} needs function _detectOS_"

    if [[ "$(_detectOS_)" == "mac" ]]; then
        local _mac_version
        _mac_version="$(sw_vers -productVersion)"
        printf "%s" "${_mac_version}"
    else
        return 1
    fi
}

# @description A safe command execution wrapper.
#   It respects global flags like `$DRYRUN`, `$VERBOSE`, and `$QUIET`, and provides
#   options for customizing output and error handling.
#
# @option -v | -V Force verbose output for this command, printing the command's native stdout/stderr.
# @option -n | -N Use 'notice' level alerting for the status message instead of 'info'.
# @option -p | -P Pass failures. If the command fails, return 0 instead of 1. Bypasses `set -e`.
# @option -e | -E Echo result. Use `printf` for the status message instead of an alert function.
# @option -s | -S On success, use 'success' level alerting for the status message.
# @option -q | -Q Quiet mode. Do not print any status message.
#
# @arg $1 string (required) The command to be executed. Must be properly quoted.
# @arg $2 string (optional) A custom message to display instead of the command itself.
#
# @stdout The native output of the command if in verbose mode, or the status message.
# @exitcode 0 On success, or if `-p` is used on failure.
# @exitcode 1 On failure.
#
# @note If `$DRYRUN` is true, it prints the command that would have been run and does not execute anything.
#
# @example
#   _execute_ "mkdir -p '/tmp/my-new-dir'" "Created temporary directory"
#   _execute_ -s "rm -f '/tmp/some-file'" "Successfully removed file"
#
_execute_() {
    local _localVerbose=false
    local _passFailures=false
    local _echoResult=false
    local _echoSuccessResult=false
    local _quietMode=false
    local _echoNoticeResult=false
    local opt

    local OPTIND=1
    while getopts ":vVpPeEsSqQnN" opt; do
        case ${opt} in
        v | V) _localVerbose=true ;;
        p | P) _passFailures=true ;;
        e | E) _echoResult=true ;;
        s | S) _echoSuccessResult=true ;;
        q | Q) _quietMode=true ;;
        n | N) _echoNoticeResult=true ;;
        *)
            {
                error "Unrecognized option '$1' passed to _execute_. Exiting."
                _safeExit_
            }
            ;;
        esac
    done
    shift $((OPTIND - 1))

    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _command="${1}"
    local _executeMessage="${2:-$1}"

    local _saveVerbose=${VERBOSE}
    if "${_localVerbose}"; then
        VERBOSE=true
    fi

    if "${DRYRUN:-}"; then
        if "${_quietMode}"; then
            VERBOSE=${_saveVerbose}
            return 0
        fi
        if [ -n "${2:-}" ]; then
            dryrun "${1} (${2})" "$(caller)"
        else
            dryrun "${1}" "$(caller)"
        fi
    elif ${VERBOSE:-}; then
        if eval "${_command}"; then
            if "${_quietMode}"; then
                VERBOSE=${_saveVerbose}
            elif "${_echoResult}"; then
                printf "%s\n" "${_executeMessage}"
            elif "${_echoSuccessResult}"; then
                success "${_executeMessage}"
            elif "${_echoNoticeResult}"; then
                notice "${_executeMessage}"
            else
                info "${_executeMessage}"
            fi
        else
            if "${_quietMode}"; then
                VERBOSE=${_saveVerbose}
            elif "${_echoResult}"; then
                printf "%s\n" "warning: ${_executeMessage}"
            else
                warning "${_executeMessage}"
            fi
            VERBOSE=${_saveVerbose}
            "${_passFailures}" && return 0 || return 1
        fi
    else
        if eval "${_command}" >/dev/null 2>&1; then
            if "${_quietMode}"; then
                VERBOSE=${_saveVerbose}
            elif "${_echoResult}"; then
                printf "%s\n" "${_executeMessage}"
            elif "${_echoSuccessResult}"; then
                success "${_executeMessage}"
            elif "${_echoNoticeResult}"; then
                notice "${_executeMessage}"
            else
                info "${_executeMessage}"
            fi
        else
            if "${_quietMode}"; then
                VERBOSE=${_saveVerbose}
            elif "${_echoResult}"; then
                printf "%s\n" "error: ${_executeMessage}"
            else
                warning "${_executeMessage}"
            fi
            VERBOSE=${_saveVerbose}
            "${_passFailures}" && return 0 || return 1
        fi
    fi
    VERBOSE=${_saveVerbose}
    return 0
}

# @description Locates the real, absolute directory of the script being run.
#   It correctly resolves symlinks.
#
# @stdout Prints the absolute path to the script's directory.
#
# @example
#   # If this is in a script at /usr/local/bin/myscript
#   baseDir="$(_findBaseDir_)"
#   # baseDir is now "/usr/local/bin"
#
_findBaseDir_() {
    local _source
    local _dir

    # Is file sourced?
    if [[ ${_} != "${0}" ]]; then
        _source="${BASH_SOURCE[1]}"
    else
        _source="${BASH_SOURCE[0]}"
    fi

    while [ -h "${_source}" ]; do # Resolve $SOURCE until the file is no longer a symlink
        _dir="$(cd -P "$(dirname "${_source}")" && pwd)"
        _source="$(readlink "${_source}")"
        [[ ${_source} != /* ]] && _source="${_dir}/${_source}" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    printf "%s\n" "$(cd -P "$(dirname "${_source}")" && pwd)"
}

# @description Generates a random UUID (Universally Unique Identifier).
#
# @stdout A version 4 UUID string (e.g., `f3b4a2d1-e9c8-4b7a-8f6e-1d5c3b2a1f0e`).
#
# @example
#   request_id=$(_generateUUID_)
#
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility)
_generateUUID_() {
    local _c
    local n
    local _b
    _c="89ab"

    for ((n = 0; n < 16; ++n)); do
        _b="$((RANDOM % 256))"

        case "${n}" in
        6) printf '4%x' "$((_b % 16))" ;;
        8) printf '%c%x' "${_c:${RANDOM}%${#_c}:1}" "$((_b % 16))" ;;

        3 | 5 | 7 | 9)
            printf '%02x-' "${_b}"
            ;;

        *)
            printf '%02x' "${_b}"
            ;;
        esac
    done

    printf '\n'
}

# @description Renders a simple progress bar for loops with a known number of iterations.
#
# @arg $1 integer (required) The total number of items in the loop.
# @arg $2 string (optional) The title to display next to the progress bar.
#
# @stdout A progress bar that updates on the same line.
#
# @note This function uses and unsets a global variable `PROGRESS_BAR_PROGRESS`.
# @note For loops with an unknown number of iterations, use `_spinner_` instead.
#
# @example
#   total_files=100
#   for i in $(seq 1 ${total_files}); do
#     _progressBar_ "${total_files}" "Processing files"
#     sleep 0.05
#   done
#   echo " Done."
#
# @see _spinner_()
_progressBar_() {
    [[ $# == 0 ]] && return   # Do nothing if no arguments are passed
    (${QUIET:-}) && return    # Do nothing in quiet mode
    (${VERBOSE:-}) && return  # Do nothing if verbose mode is enabled
    [ ! -t 1 ] && return      # Do nothing if the output is not a terminal
    [[ ${1} == 1 ]] && return # Do nothing with a single element

    local _n="${1}"
    local _width=30
    local _barCharacter="#"
    local _percentage
    local _num
    local _bar
    local _progressBarLine
    local _barTitle="${2:-Running Process}"

    ((_n = _n - 1))

    # Reset the count
    [ -z "${PROGRESS_BAR_PROGRESS:-}" ] && PROGRESS_BAR_PROGRESS=0

    # Hide the cursor
    tput civis

    if [[ ! ${PROGRESS_BAR_PROGRESS} -eq ${_n} ]]; then

        # Compute the percentage.
        _percentage=$((PROGRESS_BAR_PROGRESS * 100 / $1))

        # Compute the number of blocks to represent the percentage.
        _num=$((PROGRESS_BAR_PROGRESS * _width / $1))

        # Create the progress bar string.
        _bar=""
        if [[ ${_num} -gt 0 ]]; then
            _bar=$(printf "%0.s${_barCharacter}" $(seq 1 "${_num}"))
        fi

        # Print the progress bar.
        _progressBarLine=$(printf "%s [%-${_width}s] (%d%%)" "  ${_barTitle}" "${_bar}" "${_percentage}")
        printf "%s\r" "${_progressBarLine}"

        PROGRESS_BAR_PROGRESS=$((PROGRESS_BAR_PROGRESS + 1))

    else
        # Replace the cursor
        tput cnorm

        # Clear the progress bar when complete
        printf "\r\033[0K"

        unset PROGRESS_BAR_PROGRESS
    fi

}

# @description Renders a simple text-based spinner for long-running operations.
#
# @arg $1 string (optional) The message to display next to the spinner.
#
# @stdout A spinner that updates on the same line.
#
# @note The spinner must be cleared by calling `_endspin_` after the loop.
# @note This function uses and unsets a global variable `SPIN_NUM`.
#
# @example
#   _spinner_ "Waiting for connection"
#   sleep 5
#   _endspin_ "Connected."
#
# @see _endspin_()
_spinner_() {
    (${QUIET:-}) && return   # Do nothing in quiet mode
    (${VERBOSE:-}) && return # Do nothing in verbose mode
    [ ! -t 1 ] && return     # Do nothing if the output is not a terminal

    local _message
    _message="${1:-Running process}"

    # Hide the cursor
    tput civis

    [[ -z ${SPIN_NUM:-} ]] && SPIN_NUM=0

    case ${SPIN_NUM:-} in
    0) _glyph="█▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁" ;;
    1) _glyph="█▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁" ;;
    2) _glyph="██▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁" ;;
    3) _glyph="███▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁" ;;
    4) _glyph="████▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁" ;;
    5) _glyph="██████▁▁▁▁▁▁▁▁▁▁▁▁▁▁" ;;
    6) _glyph="██████▁▁▁▁▁▁▁▁▁▁▁▁▁▁" ;;
    7) _glyph="███████▁▁▁▁▁▁▁▁▁▁▁▁▁" ;;
    8) _glyph="████████▁▁▁▁▁▁▁▁▁▁▁▁" ;;
    9) _glyph="█████████▁▁▁▁▁▁▁▁▁▁▁" ;;
    10) _glyph="█████████▁▁▁▁▁▁▁▁▁▁▁" ;;
    11) _glyph="██████████▁▁▁▁▁▁▁▁▁▁" ;;
    12) _glyph="███████████▁▁▁▁▁▁▁▁▁" ;;
    13) _glyph="█████████████▁▁▁▁▁▁▁" ;;
    14) _glyph="██████████████▁▁▁▁▁▁" ;;
    15) _glyph="██████████████▁▁▁▁▁▁" ;;
    16) _glyph="███████████████▁▁▁▁▁" ;;
    17) _glyph="███████████████▁▁▁▁▁" ;;
    18) _glyph="███████████████▁▁▁▁▁" ;;
    19) _glyph="████████████████▁▁▁▁" ;;
    20) _glyph="█████████████████▁▁▁" ;;
    21) _glyph="█████████████████▁▁▁" ;;
    22) _glyph="██████████████████▁▁" ;;
    23) _glyph="██████████████████▁▁" ;;
    24) _glyph="███████████████████▁" ;;
    25) _glyph="███████████████████▁" ;;
    26) _glyph="███████████████████▁" ;;
    27) _glyph="████████████████████" ;;
    28) _glyph="████████████████████" ;;
    esac

    # shellcheck disable=SC2154
    printf "\r${gray}[   info] %s  %s...${reset}" "${_glyph}" "${_message}"
    if [[ ${SPIN_NUM} -lt 28 ]]; then
        ((SPIN_NUM = SPIN_NUM + 1))
    else
        SPIN_NUM=0
    fi
}

# @description Clears the line used by `_spinner_` and restores the cursor.
#   Should be called after a loop that uses `_spinner_`.
#
# @example
#   # See example for _spinner_()
#
# @see _spinner_()
_endspin_() {
    # Clear the spinner
    printf "\r\033[0K"

    # Replace the cursor
    tput cnorm

    unset SPIN_NUM
}

# @description Runs a command with root privileges.
#
# @arg $@ any (required) The command and its arguments to execute as root.
#
# @note This function will use `sudo` if the current user is not root.
#
# @see [ralish/bash-script-template](https://github.com/ralish/bash-script-template)
#
# @example
#   _runAsRoot_ "apt-get" "update"
#
_runAsRoot_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _skip_sudo=false

    if [[ ${1} =~ ^0$ ]]; then
        _skip_sudo=true
        shift
    fi

    if [[ ${EUID} -eq 0 ]]; then
        "$@"
    elif [[ -z ${_skip_sudo} ]]; then
        sudo -H -- "$@"
    else
        fatal "Unable to run requested command as root: $*"
    fi
}

# @description Prompts the user for a yes/no confirmation.
#
# @arg $1 string (required) The question to ask the user.
#
# @exitcode 0 If the user answers "yes" (y/Y).
# @exitcode 1 If the user answers "no" (n/N).
#
# @note If the global variable `$FORCE` is true, this function will automatically return 0 without prompting.
#
# @example
#   if _seekConfirmation_ "Are you sure you want to delete all files?"; then
#     echo "Deleting files..."
#   else
#     echo "Operation cancelled."
#   fi
#
_seekConfirmation_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _yesNo
    input "${1}"
    if "${FORCE:-}"; then
        debug "Forcing confirmation with '--force' flag set"
        printf "%s\n" " "
        return 0
    else
        while true; do
            read -r -p " (y/n) " _yesNo
            case ${_yesNo} in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) input "Please answer yes or no." ;;
            esac
        done
    fi
}
