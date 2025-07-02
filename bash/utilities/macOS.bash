#=============================================================================
# @file macOS.bash
# @brief A utility library with functions specific to the macOS operating system.
# @description
#   This script provides a collection of functions designed exclusively for use
#   on macOS. It handles interactions with the macOS GUI (Finder, osascript)
#   and environment (Homebrew paths, GNU utilities).
#
#   These functions are not portable and will fail on other operating systems like Linux.
#=============================================================================

# @description Determines whether the script is running in a context where the Finder is scriptable.
#   This is useful for checking if a GUI interaction is possible.
#
# @exitcode 0 If the Finder process is running in a scriptable context (e.g., a standard GUI session).
# @exitcode 1 If not (e.g., in an SSH session or if Finder is not running).
#
# @example
#   if _haveScriptableFinder_; then
#     echo "GUI is available."
#   else
#     echo "Running in a non-GUI environment."
#   fi
#
_haveScriptableFinder_() {
    local _finder_pid
    _finder_pid="$(pgrep -f /System/Library/CoreServices/Finder.app | head -n 1)"

    if [[ (${_finder_pid} -gt 1) && (${STY-} == "") ]]; then
        return 0
    else
        return 1
    fi
}

# @description Displays a native macOS dialog box to ask for user input.
#   Ideal for securely requesting passwords or other sensitive information in a GUI context.
#
# @arg $1 string (optional) The prompt message to display in the dialog box. Defaults to "Password:".
#
# @stdout The text entered by the user.
# @exitcode 1 If the script is not running in a scriptable GUI environment.
#
# @note This function uses `osascript` and will only work in a macOS GUI session.
#
# @example
#   api_key=$(_guiInput_ "Please enter your API Key:")
#
# @see _haveScriptableFinder_()
# @see [awesome-osx-command-line](https://github.com/herrbischoff/awesome-osx-command-line/blob/master/functions.md)
_guiInput_() {
    if _haveScriptableFinder_; then
        local _guiPrompt="${1:-Password:}"
        local _guiInput
        _guiInput=$(
            osascript &>/dev/null <<GUI_INPUT_MESSAGE
      tell application "System Events"
          activate
          text returned of (display dialog "${_guiPrompt}" default answer "" with hidden answer)
      end tell
GUI_INPUT_MESSAGE
        )
        printf "%s\n" "${_guiInput}"
    else
        error "No GUI input without macOS"
        return 1
    fi
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
#   # Now 'sed' will refer to gsed, 'grep' to ggrep, etc.
#   sed -i 's/foo/bar/' file.txt
#
# @see _setPATH_()
_useGNUutils_() {
    ! declare -f "_setPATH_" &>/dev/null && fatal "${FUNCNAME[0]} needs function _setPATH_"

    if _setPATH_ \
        "/usr/local/opt/gnu-tar/libexec/gnubin" \
        "/usr/local/opt/coreutils/libexec/gnubin" \
        "/usr/local/opt/gnu-sed/libexec/gnubin" \
        "/usr/local/opt/grep/libexec/gnubin" \
        "/usr/local/opt/findutils/libexec/gnubin" \
        "/opt/homebrew/opt/findutils/libexec/gnubin" \
        "/opt/homebrew/opt/gnu-sed/libexec/gnubin" \
        "/opt/homebrew/opt/grep/libexec/gnubin" \
        "/opt/homebrew/opt/coreutils/libexec/gnubin" \
        "/opt/homebrew/opt/gnu-tar/libexec/gnubin"; then
        return 0
    else
        return 1
    fi
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
        if "${_uname}" | tr '[:upper:]' '[:lower:]' | grep -q 'darwin'; then
            if _setPATH_ "/usr/local/bin" "/opt/homebrew/bin"; then
                return 0
            else
                return 1
            fi
        fi
    else
        if _setPATH_ "/usr/local/bin" "/opt/homebrew/bin"; then
            return 0
        else
            return 1
        fi
    fi
}
