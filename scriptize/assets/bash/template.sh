#!/usr/bin/env bash
#=============================================================================
# @file template.sh
# @brief A robust, boilerplate template for creating powerful and safe Bash scripts.
# @description
#   This script serves as a foundational template for developing new command-line
#   tools. It provides a standard structure, a rich set of utility functions,
#   and best practices for error handling, argument parsing, and logging.
#
#   The script is organized into three main sections:
#     1. **MAIN:** The `_mainScript_` function at the top is the primary entry point for your custom logic.
#     2. **BASE FUNCTIONS:** The middle section contains the core framework functions for argument parsing, help text, error handling, etc.
#     3. **HUB:** The bottom section initializes the script environment (e.g., `set -e`) and runs the main logic.
#=============================================================================

# shellcheck source-path=SCRIPTDIR/utilities
# shellcheck source-path=SCRIPTDIR/../utilities

#=============================================================================
#----------------------------------- MAIN ------------------------------------
#=============================================================================
# @description
#   This is the main entry point for the script's logic.
#   Replace the content of this function with your own code.
_mainScript_() {

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

#=============================================================================
#---------------------------- FLAGS AND DEFAULTS -----------------------------
#=============================================================================
#--------- Required variables ---------
LOGFILE="${HOME}/logs/$(basename "$0").log"
QUIET=false
LOGLEVEL=ERROR
VERBOSE=false
FORCE=false
DRYRUN=false
declare -a ARGS=()

#=============================================================================
#------------------------------ BASE FUNCTIONS -------------------------------
#=============================================================================

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

# @description Locates the real, absolute directory of the script being run.
#   It correctly resolves symlinks to find the true script path.
#
# @stdout The absolute path to the directory containing the script.
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

    while [[ -h "${_source}" ]]; do # Resolve $SOURCE until the file is no longer a symlink
        _dir="$(cd -P "$(dirname "${_source}")" && pwd)"
        _source="$(readlink "${_source}")"
        [[ ${_source} != /* ]] && _source="${_dir}/${_source}" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    _dir="$(cd -P "$(dirname "${_source}")" && pwd)"
    printf "%s\n" "${_dir}"
}

# @description Sources all utility function files from a specified directory.
#   The script will exit if any of the required utility files are not found.
#
# @arg $1 path (required) The absolute path to the 'utilities' directory.
#
# @exitcode 0 On success.
# @exitcode 1 If any of the utility files cannot be found and sourced.
#
# @example
#   _sourceUtilities_ "$(_findBaseDir_)/utilities"
#
_sourceUtilities_() {
    local _utilsPath
    _utilsPath="${1}"

    if [[ -f "${_utilsPath}/alerts.bash" ]]; then
        source "${_utilsPath}/alerts.bash"
    else
        printf "%s\n" "ERROR: ${_utilsPath}/alerts.bash not found"
        exit 1
    fi

    if [[ -f "${_utilsPath}/arrays.bash" ]]; then
        source "${_utilsPath}/arrays.bash"
    else
        printf "%s\n" "ERROR: ${_utilsPath}/arrays.bash not found"
        exit 1
    fi

    if [[ -f "${_utilsPath}/checks.bash" ]]; then
        source "${_utilsPath}/checks.bash"
    else
        printf "%s\n" "ERROR: ${_utilsPath}/checks.bash not found"
        exit 1
    fi

    if [[ -f "${_utilsPath}/dates.bash" ]]; then
        source "${_utilsPath}/dates.bash"
    else
        printf "%s\n" "ERROR: ${_utilsPath}/dates.bash not found"
        exit 1
    fi

    if [[ -f "${_utilsPath}/debug.bash" ]]; then
        source "${_utilsPath}/debug.bash"
    else
        printf "%s\n" "ERROR: ${_utilsPath}/debug.bash not found"
        exit 1
    fi

    if [[ -f "${_utilsPath}/files.bash" ]]; then
        source "${_utilsPath}/files.bash"
    else
        printf "%s\n" "ERROR: ${_utilsPath}/files.bash not found"
        exit 1
    fi

    if [[ -f "${_utilsPath}/macOS.bash" ]]; then
        source "${_utilsPath}/macOS.bash"
    else
        printf "%s\n" "ERROR: ${_utilsPath}/macOS.bash not found"
        exit 1
    fi

    if [[ -f "${_utilsPath}/misc.bash" ]]; then
        source "${_utilsPath}/misc.bash"
    else
        printf "%s\n" "ERROR: ${_utilsPath}/misc.bash not found"
        exit 1
    fi

    if [[ -f "${_utilsPath}/services.bash" ]]; then
        source "${_utilsPath}/services.bash"
    else
        printf "%s\n" "ERROR: ${_utilsPath}/services.bash not found"
        exit 1
    fi

    if [[ -f "${_utilsPath}/strings.bash" ]]; then
        source "${_utilsPath}/strings.bash"
    else
        printf "%s\n" "ERROR: ${_utilsPath}/strings.bash not found"
        exit 1
    fi

    if [[ -f "${_utilsPath}/template_utils.bash" ]]; then
        source "${_utilsPath}/template_utils.bash"
    else
        printf "%s\n" "ERROR: ${_utilsPath}/template_utils.bash not found"
        exit 1
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

# Set a trap for any error or interrupt signal. Calls the _trapCleanup_ function.
trap '_trapCleanup_ ${LINENO} ${BASH_LINENO} "${BASH_COMMAND}" "${FUNCNAME[*]}" "${0}" "${BASH_SOURCE[0]}"' EXIT INT TERM SIGINT SIGQUIT SIGTERM

# Trap errors in subshells and functions
set -o errtrace

# Exit on error. Append '|| true' to a command if you expect an error
set -o errexit

# Use last non-zero exit code in a pipeline
set -o pipefail

# Confirm we have BASH version 4 or greater
[[ "${BASH_VERSINFO:-0}" -ge 4 ]] || {
    printf "%s\n" "ERROR: BASH_VERSINFO is '${BASH_VERSINFO:-0}'.  This script requires BASH v4 or greater."
    exit 1
}

# Make `for f in *.txt` work when `*.txt` matches zero files
shopt -s nullglob globstar

# Set IFS to a saner default
IFS=$' \n\t'

# Run in debug mode, printing each command
# set -o xtrace

# Source all utility functions from the 'utilities' directory
_base_dir="$(_findBaseDir_)"
_sourceUtilities_ "${_base_dir}/utilities"

# Initialize color constants
_setColors_

# Disallow expansion of unset variables
set -o nounset

# Force arguments when invoking the script. If no arguments are passed, show usage.
# [[ $# -eq 0 ]] && _parseOptions_ "-h"

# Parse all command-line arguments
_parseOptions_ "$@"

# Create a temporary directory in '$TMP_DIR'
# _makeTempDir_ "$(basename "$0")"

# Acquire a script lock to prevent concurrent execution
# _acquireScriptLock_

# Add Homebrew binary directory to PATH (macOS-specific)
# _homebrewPath_

# Prepend paths to GNU utilities from Homebrew (macOS-specific)
# _useGNUutils_

# Run the main logic of the script
_mainScript_

# Exit cleanly (removes temp files and script lock)
_safeExit_
