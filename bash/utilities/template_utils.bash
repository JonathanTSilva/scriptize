#=============================================================================
# @file template_utils.bash
# @brief Foundational functions required by the script templates and core utilities.
# @description
#   This script provides essential functions that form the backbone of the script
#   template system. It handles script locking to prevent concurrent execution,
#   manages temporary directories, ensures safe script cleanup and exit, and
#   modifies the system `$PATH`.
#=============================================================================

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
        # shellcheck disable=SC2154 # Color variables are sourced from alerts.bash
        debug "Acquired script lock: ${yellow}${SCRIPT_LOCK}${purple}"
    else
        if declare -f "_safeExit_" &>/dev/null; then
            # shellcheck disable=SC2154 # Color variables are sourced from alerts.bash
            error "Unable to acquire script lock: ${yellow}${_lockDir}${red}"
            fatal "If you trust the script isn't running, delete the lock dir"
        else
            printf "%s\n" "ERROR: Could not acquire script lock. If you trust the script isn't running, delete: ${_lockDir}"
            exit 1
        fi
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
            # shellcheck disable=SC2154 # Color variables are sourced from alerts.bash
            warning "Script lock could not be removed. Try manually deleting ${yellow}'${SCRIPT_LOCK}'"
        fi
    fi

    if [[ -n ${TMP_DIR:-} && -d ${TMP_DIR:-} ]]; then
        # The logic here seems to remove the temp dir regardless of the exit code.
        # The original `if/else` was identical.
        command rm -r "${TMP_DIR}"
        debug "Removing temp directory"
    fi

    trap - INT TERM EXIT
    exit "${1:-0}"
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
                # Corrected error message to reference the right function
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
                    # This branch is unlikely to be hit
                    debug "'${_newPath}' could not be added to PATH"
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
