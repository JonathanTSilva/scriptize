#=============================================================================
# @file checks.bash
# @brief A utility library for common validation and check functions.
# @description
#   This script provides a robust collection of functions to validate common data
#   types and environmental states. It includes checks for commands, data formats
#   (like IP addresses and emails), file system objects, and system states
#   (like internet connectivity and root access).
#=============================================================================

# @description Checks if a command or binary exists in the system's PATH.
#
# @arg $1 string (required) Name of the command or binary to check for.
#
# @exitcode 0 If the command exists in the PATH.
# @exitcode 1 If the command does not exist.
#
# @example
#   if _commandExists_ "git"; then
#     echo "Git is installed."
#   else
#     echo "Error: Git is not installed."
#   fi
#
_commandExists_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    if ! command -v "$1" >/dev/null 2>&1; then
        debug "Did not find dependency: '${1}'"
        return 1
    fi
    return 0
}

# @description Tests if a function is defined in the current script scope.
#
# @arg $1 string (required) The name of the function to check.
#
# @exitcode 0 If the function is defined.
# @exitcode 1 If the function is not defined.
#
# @example
#   if _functionExists_ "_commandExists_"; then
#     echo "Function exists."
#   fi
#
_functionExists_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _testFunction
    _testFunction="${1}"

    if declare -f "${_testFunction}" &>/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# @description Validates that a given input contains only alphabetic characters (a-z, A-Z).
#
# @arg $1 string (required) The input string to validate.
#
# @exitcode 0 If the input contains only alphabetic characters.
# @exitcode 1 If the input contains non-alphabetic characters.
#
# @example
#   _isAlpha_ "HelloWorld" # returns 0
#   _isAlpha_ "Hello World" # returns 1
#
_isAlpha_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"
    local _re='^[[:alpha:]]+$'
    if [[ ${1} =~ ${_re} ]]; then
        return 0
    fi
    return 1
}

# @description Validates that a given input contains only alpha-numeric characters (a-z, A-Z, 0-9).
#
# @arg $1 string (required) The input string to validate.
#
# @exitcode 0 If the input contains only alpha-numeric characters.
# @exitcode 1 If the input contains other characters.
#
# @example
#   _isAlphaNum_ "Test123" # returns 0
#   _isAlphaNum_ "Test-123" # returns 1
#
_isAlphaNum_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"
    local _re='^[[:alnum:]]+$'
    if [[ ${1} =~ ${_re} ]]; then
        return 0
    fi
    return 1
}

# @description Validates that a given input contains only alpha-numeric characters, underscores, or dashes.
#
# @arg $1 string (required) The input string to validate.
#
# @exitcode 0 If the input is valid.
# @exitcode 1 If the input contains other characters.
#
# @example
#   _isAlphaDash_ "my-variable_name-1" # returns 0
#   _isAlphaDash_ "my-variable!" # returns 1
#
_isAlphaDash_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"
    local _re='^[[:alnum:]_-]+$'
    if [[ ${1} =~ ${_re} ]]; then
        return 0
    fi
    return 1
}

# @description Validates that a string is a valid email address format.
#
# @arg $1 string (required) The email address to validate.
#
# @exitcode 0 If the string is a valid email format.
# @exitcode 1 If the string is not a valid email format.
#
# @example
#   if _isEmail_ "test@example.com"; then
#     echo "Valid email."
#   fi
#
_isEmail_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    #shellcheck disable=SC2064
    trap '$(shopt -p nocasematch)' RETURN # reset nocasematch when function exits
    shopt -s nocasematch                  # Use case-insensitive regex

    local _emailRegex
    _emailRegex="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
    [[ ${1} =~ ${_emailRegex} ]] && return 0 || return 1
}

# @description Determines if a given input is a fully qualified domain name (FQDN).
#
# @arg $1 string (required) The domain name to validate.
#
# @exitcode 0 If the string is a valid FQDN.
# @exitcode 1 If the string is not a valid FQDN.
#
# @note This function requires GNU `grep` with PCRE support (`-P`). It may not work on all systems (e.g., default macOS).
#
# @example
#   _isFQDN_ "google.com" # returns 0
#   _isFQDN_ "localhost" # returns 1
#
_isFQDN_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _input="${1}"

    if printf "%s" "${_input}" | grep -Pq '(?=^.{4,253}$)(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9])?\.)+([a-zA-Z]{2,}|xn--[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])$)'; then
        return 0
    else
        return 1
    fi
}

# @description Checks if an internet connection is available by attempting to contact google.com.
#
# @exitcode 0 If an internet connection to google.com is established.
# @exitcode 1 If the connection fails.
#
# @example
#   if _isInternetAvailable_; then
#     echo "Internet is up."
#   fi
#
_isInternetAvailable_() {
    local _checkInternet
    if [[ -t 1 || -z ${TERM} ]]; then
        _checkInternet="$(sh -ic 'exec 3>&1 2>/dev/null; { curl --compressed -Is google.com 1>&3; kill 0; } | { sleep 10; kill 0; }' || :)"
    else
        _checkInternet="$(curl --compressed -Is google.com -m 10)"
    fi
    if [[ -z ${_checkInternet-} ]]; then
        return 1
    fi
}

# @description Validates that a string is a structurally valid IPv4 address.
#
# @arg $1 string (required) The IPv4 address to validate.
#
# @exitcode 0 If the string is a valid IPv4 address.
# @exitcode 1 If the string is not a valid IPv4 address.
#
# @example
#   _isIPv4_ "192.168.1.1" # returns 0
#   _isIPv4_ "999.0.0.1" # returns 1
#
_isIPv4_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"
    local _ip="${1}"
    local IFS=.
    # shellcheck disable=SC2206
    declare -a _a=(${_ip})
    [[ ${_ip} =~ ^[0-9]+(\.[0-9]+){3}$ ]] || return 1
    # Test values of quads
    local _quad
    for _quad in {0..3}; do
        [[ ${_a[${_quad}]} -gt 255 ]] && return 1
    done
    return 0
}

# @description Validates that a given path exists and is a regular file.
#
# @arg $1 path (required) The path to check.
#
# @exitcode 0 If the path exists and is a regular file.
# @exitcode 1 Otherwise.
#
# @example
#   if _isFile_ "/etc/hosts"; then
#     echo "It's a file."
#   fi
#
_isFile_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    [[ -f ${1} ]] && return 0 || return 1
}

# @description Validates that a given path exists and is a directory.
#
# @arg $1 path (required) The path to check.
#
# @exitcode 0 If the path exists and is a directory.
# @exitcode 1 Otherwise.
#
# @example
#   if _isDir_ "/etc/"; then
#     echo "It's a directory."
#   fi
#
_isDir_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    [[ -d ${1} ]] && return 0 || return 1
}

# @description Validates that a given input contains only numeric digits (0-9).
#
# @arg $1 string (required) The input string to validate.
#
# @exitcode 0 If the input contains only numeric digits.
# @exitcode 1 If the input contains non-numeric characters.
#
# @example
#   _isNum_ "12345" # returns 0
#   _isNum_ "123a"  # returns 1
#
_isNum_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"
    local _re='^[[:digit:]]+$'
    if [[ ${1} =~ ${_re} ]]; then
        return 0
    fi
    return 1
}

# @description Checks if the script is running in an interactive terminal.
#
# @exitcode 0 If the script is running in an interactive terminal.
# @exitcode 1 If the script is not (e.g., piped, in a cron job).
#
# @example
#   if _isTerminal_; then
#     echo "We can use interactive prompts."
#   fi
#
_isTerminal_() {
    [[ -t 1 || -z ${TERM} ]] && return 0 || return 1
}

# @description Validates if superuser (root) privileges are available.
#
# @arg $1 any (optional) If set to any value, will not attempt to use `sudo`.
#
# @exitcode 0 If superuser privileges are available.
# @exitcode 1 If superuser privileges could not be obtained.
#
# @see [ralish/bash-script-template](https://github.com/ralish/bash-script-template)
#
# @example
#   if _rootAvailable_; then
#     echo "Running tasks that require root..."
#   else
#     echo "Cannot run root tasks."
#   fi
#
_rootAvailable_() {
    local _superuser

    if [[ ${EUID} -eq 0 ]]; then
        _superuser=true
    elif [[ -z ${1-} ]]; then
        debug 'Sudo: Updating cached credentials ...'
        if sudo -v; then
            if [[ $(sudo -H -- "${BASH}" -c 'printf "%s" "$EUID"') -eq 0 ]]; then
                _superuser=true
            else
                _superuser=false
            fi
        else
            _superuser=false
        fi
    fi

    if [[ ${_superuser} == true ]]; then
        debug 'Successfully acquired superuser credentials.'
        return 0
    else
        debug 'Unable to acquire superuser credentials.'
        return 1
    fi
}

# @description Checks if a given variable is considered "true".
#   True values are "true" (case-insensitive) or "0".
#
# @arg $1 string (required) The variable's value to check.
#
# @exitcode 0 If the value is considered true.
# @exitcode 1 Otherwise.
#
# @example
#   _varIsTrue_ "true" # returns 0
#   _varIsTrue_ "0"    # returns 0
#   _varIsTrue_ "yes"  # returns 1
#
_varIsTrue_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    [[ ${1,,} == "true" || ${1} == 0 ]] && return 0 || return 1
}

# @description Checks if a given variable is considered "false".
#   False values are "false" (case-insensitive) or "1".
#
# @arg $1 string (required) The variable's value to check.
#
# @exitcode 0 If the value is considered false.
# @exitcode 1 Otherwise.
#
# @example
#   _varIsFalse_ "false" # returns 0
#   _varIsFalse_ "1"     # returns 0
#   _varIsFalse_ "no"    # returns 1
#
_varIsFalse_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    [[ ${1,,} == "false" || ${1} == 1 ]] && return 0 || return 1
}

# @description Checks if a given variable is empty or the literal string "null".
#
# @arg $1 string (required) The variable's value to check.
#
# @exitcode 0 If the variable is empty or "null".
# @exitcode 1 Otherwise.
#
# @example
#   _varIsEmpty_ ""       # returns 0
#   _varIsEmpty_ "null"   # returns 0
#   _varIsEmpty_ " "      # returns 1
#
_varIsEmpty_() {
    [[ -z ${1-} || ${1-} == "null" ]] && return 0 || return 1
}

# @description Validates that a string is a valid IPv6 address.
#
# @arg $1 string (required) The IPv6 address to validate.
#
# @exitcode 0 If the string is a valid IPv6 address.
# @exitcode 1 If the string is not a valid IPv6 address.
#
# @example
#   _isIPv6_ "2001:db8:85a3:8d3:1319:8a2e:370:7348" # returns 0
#   _isIPv6_ "not-an-ip" # returns 1
#
_isIPv6_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _ip="${1}"
    local _re="^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|\
([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|\
([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|\
([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|\
:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|\
::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|\
(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|\
(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$"

    [[ ${_ip} =~ ${_re} ]] && return 0 || return 1
}
