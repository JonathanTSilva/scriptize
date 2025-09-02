#=============================================================================
# @file debug.bash
# @brief A utility library of functions to aid in debugging Bash scripts.
# @description
#   This script provides functions to help with common debugging tasks,
#   such as pausing script execution, inspecting the contents of arrays,
#   and visualizing raw ANSI escape codes within a string.
#=============================================================================

# @description Pauses script execution and waits for user confirmation to continue.
#   If the user does not confirm, the script exits via `_safeExit_`.
#
# @arg $1 string (optional) A custom message to display in the confirmation prompt. Defaults to "Paused. Ready to continue?".
#
# @note This function depends on the `_seekConfirmation_`, `_safeExit_`, `info`, and `notice` functions being available.
#
# @example
#   echo "About to perform a critical step."
#   _pauseScript_ "Check resources and press 'y' to proceed."
#   echo "Critical step complete."
#
# @see _seekConfirmation_()
# @see _safeExit_()
_pauseScript_() {
    local _pauseMessage
    _pauseMessage="${1:-Paused. Ready to continue?}"

    if _seekConfirmation_ "${_pauseMessage}"; then
        info "Continuing..."
    else
        notice "Exiting Script"
        _safeExit_
    fi
}

# @description Helps debug ANSI escape sequences by making the ESC character visible as `\e`.
#
# @arg $1 string (required) An input string containing raw ANSI escape sequences.
#
# @stdout The input string with the non-printable ESC character replaced by the literal string `\e`.
#
# @example
#   color_string="$(tput bold)$(tput setaf 9)Some Text$(tput sgr0)"
#   _printAnsi_ "${color_string}"
#   # Output: \e[1m\e[31mSome Text\e[0m
#
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility/blob/master/src/debug.sh)
_printAnsi_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    #printf "%s\n" "$(tr -dc '[:print:]'<<<$1)"
    printf "%s\n" "${1//$'\e'/\\e}"
}

# @description Prints the contents of an array as key-value pairs for easier debugging.
#   By default, it only prints if the global `$VERBOSE` variable is true.
#
# @option -v | -V Force printing of the array even if `$VERBOSE` is false. Output will use 'info' alerts instead of 'debug'.
#
# @arg $1 string (required) The name of the array variable to print.
# @arg $2 integer (optional) The line number where the function is called, typically passed as `${LINENO}`.
#
# @stdout The array's name followed by each key-value pair, one per line, via the `debug` or `info` alert functions.
#
# @note This function uses a nameref (`declare -n`), which requires Bash 4.3 or newer.
#
# @example
#   # In verbose mode (-v), this will print the array contents.
#   testArray=("a" "b" "c")
#   _printArray_ "testArray" ${LINENO}
#
#   # This will print the array contents regardless of verbose mode.
#   _printArray_ -v "testArray"
#
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility/blob/master/src/debug.sh)
_printArray_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _printNoVerbose=false
    local opt
    local OPTIND=1
    while getopts ":vV" opt; do
        case ${opt} in
        v | V) _printNoVerbose=true ;;
        *) fatal "Unrecognized option '${1}' passed to ${FUNCNAME[0]}. Exiting." ;;
        esac
    done
    shift $((OPTIND - 1))

    local _arrayName="${1}"
    local _lineNumber="${2:-}"
    declare -n _arr="${1}"

    if [[ ${_printNoVerbose} == "false" ]]; then

        [[ ${VERBOSE:-} != true ]] && return 0

        debug "Contents of \${${_arrayName}[@]}" "${_lineNumber}"

        for _k in "${!_arr[@]}"; do
            debug "${_k} = ${_arr[${_k}]}"
        done
    else
        info "Contents of \${${_arrayName}[@]}" "${_lineNumber}"

        for _k in "${!_arr[@]}"; do
            info "${_k} = ${_arr[${_k}]}"
        done
    fi
}
