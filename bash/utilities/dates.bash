#=============================================================================
# @file dates.bash
# @brief A utility library for date and time manipulation and conversion.
# @description
#   This script provides a collection of functions to handle common date and
#   time operations. It supports converting between various date formats,
#   calculating with Unix timestamps, and parsing dates from strings.
#=============================================================================

# @description Converts a human-readable date string into a Unix timestamp.
#   Relies on the `date -d` command for parsing.
#
# @arg $1 string (required) A date string that the `date -d` command can understand (e.g., "Jan 10, 2019", "2025-06-30").
#
# @stdout The Unix timestamp corresponding to the input date.
# @exitcode 0 On successful conversion.
# @exitcode 1 If the `date` command fails to parse the input string.
#
# @example
#   ts=$(_convertToUnixTimestamp_ "2025-07-01 12:00:00")
#   echo "Timestamp: ${ts}"
#
_convertToUnixTimestamp_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _date
    _date=$(date -d "${1}" +"%s") || return 1
    printf "%s\n" "${_date}"
}

# @description Displays a countdown timer for a specified duration.
#   Prints a message at each interval. Uses the `info` alert function if available.
#
# @arg $1 integer (optional) Total seconds to count down from. Defaults to 10.
# @arg $2 integer (optional) The sleep interval in seconds between messages. Defaults to 1.
# @arg $3 string (optional) The message to print at each interval. Defaults to "...".
#
# @stdout The countdown message at each interval.
#
# @example
#   _countdown_ 5 1 "Restarting in"
#   # Output (one line per second):
#   # [   INFO] Restarting in 5
#   # [   INFO] Restarting in 4
#   # ...
#
_countdown_() {
    local i ii t
    local _n=${1:-10}
    local _sleepTime=${2:-1}
    local _message="${3:-...}"
    ((t = _n + 1))

    for ((i = 1; i <= _n; i++)); do
        ((ii = t - i))
        if declare -f "info" &>/dev/null 2>&1; then
            info "${_message} ${ii}"
        else
            echo "${_message} ${ii}"
        fi
        sleep "${_sleepTime}"
    done
}

# @description Gets the current time as a Unix timestamp (seconds since epoch, UTC).
#
# @stdout The current Unix timestamp (e.g., `1751352022`).
# @exitcode 0 On success.
# @exitcode 1 If the `date` command fails.
#
# @example
#   current_timestamp=$(_dateUnixTimestamp_)
#
_dateUnixTimestamp_() {
    local _now
    _now="$(date --universal +%s)" || return 1
    printf "%s\n" "${_now}"
}

# @description Reformats a date string into a user-specified format.
#
# @arg $1 string (required) The input date string (e.g., "Jan 10, 2019").
# @arg $2 string (optional) The output format for `date`. Defaults to `%F` (YYYY-MM-DD).
#
#   Examples:
#
#     - `%F` -> YYYY-MM-DD
#     - `%D` -> MM/DD/YY
#     - `%a` -> Mon
#     - `%A` -> Monday
#     - `'+%m %d, %Y'` -> 12 27, 2019
#
# @stdout The formatted date string.
#
# @example
#   _formatDate_ "Jan 10, 2022" "%A, %B %d, %Y"
#   # Output: Monday, January 10, 2022
#
_formatDate_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _d="${1}"
    local _format="${2:-%F}"
    _format="${_format//+/}"

    date -d "${_d}" "+${_format}"
}

# @description Converts a total number of seconds into HH:MM:SS format.
#
# @arg $1 integer (required) The total number of seconds.
#
# @stdout The time formatted as a zero-padded HH:MM:SS string.
#
# @example
#   STARTTIME=$(date +"%s")
#   sleep 3
#   ENDTIME=$(date +"%s")
#   TOTALTIME=$((ENDTIME - STARTTIME))
#   _fromSeconds_ "${TOTALTIME}" # -> 00:00:03
#
_fromSeconds_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _h _m _s
    ((_h = ${1} / 3600))
    ((_m = (${1} % 3600) / 60))
    ((_s = ${1} % 60))
    printf "%02d:%02d:%02d\n" "${_h}" "${_m}" "${_s}"
}

# @description Converts a month name (full or abbreviated) to its corresponding number.
#
# @arg $1 string (required) The month name (case-insensitive).
#
# @stdout The corresponding month number (1-12).
# @exitcode 1 If the month name is not recognized.
#
# @example
#   _monthToNumber_ "January" # -> 1
#   _monthToNumber_ "sep"     # -> 9
#
_monthToNumber_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _mon
    _mon="$(echo "$1" | tr '[:upper:]' '[:lower:]')"

    case "${_mon}" in
    january | jan | ja) echo 1 ;;
    february | feb | fe) echo 2 ;;
    march | mar | ma) echo 3 ;;
    april | apr | ap) echo 4 ;;
    may) echo 5 ;;
    june | jun | ju) echo 6 ;;
    july | jul) echo 7 ;;
    august | aug | au) echo 8 ;;
    september | sep | se) echo 9 ;;
    october | oct | oc) echo 10 ;;
    november | nov | no) echo 11 ;;
    december | dec | de) echo 12 ;;
    *)
        warning "_monthToNumber_: Bad month name: ${_mon}"
        return 1
        ;;
    esac
}

# @description Converts a month number to its full English name.
#
# @arg $1 integer (required) The month number (1-12).
#
# @stdout The full English name of the month.
# @exitcode 1 If the number is not between 1 and 12.
#
# @example
#   _numberToMonth_ 11 # -> November
#
_numberToMonth_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _mon="$1"
    case "${_mon}" in
    1 | 01) echo January ;;
    2 | 02) echo February ;;
    3 | 03) echo March ;;
    4 | 04) echo April ;;
    5 | 05) echo May ;;
    6 | 06) echo June ;;
    7 | 07) echo July ;;
    8 | 08) echo August ;;
    9 | 09) echo September ;;
    10) echo October ;;
    11) echo November ;;
    12) echo December ;;
    *)
        warning "_numberToMonth_: Bad month number: ${_mon}"
        return 1
        ;;
    esac
}

# @description Parses a string to find and extract date components.
#   This function is very complex and uses multiple regular expressions to find a date.
#   If a date is found, it sets several global variables.
#
# @arg $1 string (required) A string containing a date.
#
# @set PARSE_DATE_FOUND The full date string found in the input.
# @set PARSE_DATE_YEAR The four-digit year.
# @set PARSE_DATE_MONTH The month as a number (1-12).
# @set PARSE_DATE_MONTH_NAME The full name of the month.
# @set PARSE_DATE_DAY The day of the month.
# @set PARSE_DATE_HOUR The hour (0-23), if available.
# @set PARSE_DATE_MINUTE The minute (0-59), if available.
#
# @exitcode 0 If a date is successfully found and parsed.
# @exitcode 1 If no recognizable date is found.
#
# @note This function only recognizes dates from the year 2000 to 2029.
# @note Recognized formats (separated by '-', '_', '.', '/', or space):
#   - YYYY-MM-DD
#   - Month DD, YYYY
#   - DD Month, YYYY
#   - Month, YYYY
#   - Month, DD YY
#   - MM-DD-YYYY
#   - MMDDYYYY
#   - YYYYMMDD
#   - DDMMYYYY
#   - YYYYMMDDHHMM
#   - YYYYMMDDHH
#   - DD MM YY
#   - MM DD YY
#
# @example
#   if _parseDate_ "An event on Jan 10, 2025 at 8pm"; then
#     echo "Found: ${PARSE_DATE_MONTH_NAME} ${PARSE_DATE_DAY}, ${PARSE_DATE_YEAR}"
#   fi
#
# TODO: Implement the following date formats: MMDDYY, YYMMDD, mon-DD-YY
# TODO: Simplify and reduce the number of regex checks
_parseDate_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _stringToTest="${1}"
    local _pat

    PARSE_DATE_FOUND="" PARSE_DATE_YEAR="" PARSE_DATE_MONTH="" PARSE_DATE_MONTH_NAME=""
    PARSE_DATE_DAY="" PARSE_DATE_HOUR="" PARSE_DATE_MINUTE=""

    #shellcheck disable=SC2064
    trap '$(shopt -p nocasematch)' RETURN # reset nocasematch when function exits
    shopt -s nocasematch                  # Use case-insensitive regex

    debug "_parseDate_() input: ${_stringToTest}"

    # YYYY MM DD or YYYY-MM-DD
    _pat="(.*[^0-9]|^)((20[0-2][0-9])[-\.\/_ ]+([0-9]{1,2})[-\.\/_ ]+([0-9]{1,2}))([^0-9].*|$)"
    if [[ ${_stringToTest} =~ ${_pat} ]]; then
        PARSE_DATE_FOUND="${BASH_REMATCH[2]}"
        PARSE_DATE_YEAR=$((10#${BASH_REMATCH[3]}))
        PARSE_DATE_MONTH=$((10#${BASH_REMATCH[4]}))
        PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH}")"
        PARSE_DATE_DAY=$((10#${BASH_REMATCH[5]}))
        debug "regex match: YYYY-MM-DD "

    # Month DD, YYYY
    elif [[ ${_stringToTest} =~ ((january|jan|ja|february|feb|fe|march|mar|ma|april|apr|ap|may|june|jun|july|jul|ju|august|aug|september|sep|october|oct|november|nov|december|dec)[-\./_ ]+([0-9]{1,2})(nd|rd|th|st)?,?[-\./_ ]+(20[0-2][0-9]))([^0-9].*|$) ]]; then
        PARSE_DATE_FOUND="${BASH_REMATCH[1]:-}"
        PARSE_DATE_MONTH=$(_monthToNumber_ "${BASH_REMATCH[2]:-}")
        PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH:-}")"
        PARSE_DATE_DAY=$((10#${BASH_REMATCH[3]:-}))
        PARSE_DATE_YEAR=$((10#${BASH_REMATCH[5]:-}))
        debug "regex match: Month DD, YYYY"

    # Month DD, YY
    elif [[ ${_stringToTest} =~ ((january|jan|ja|february|feb|fe|march|mar|ma|april|apr|ap|may|june|jun|july|jul|ju|august|aug|september|sep|october|oct|november|nov|december|dec)[-\./_ ]+([0-9]{1,2})(nd|rd|th|st)?,?[-\./_ ]+([0-9]{2}))([^0-9].*|$) ]]; then
        PARSE_DATE_FOUND="${BASH_REMATCH[1]}"
        PARSE_DATE_MONTH=$(_monthToNumber_ "${BASH_REMATCH[2]}")
        PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH}")"
        PARSE_DATE_DAY=$((10#${BASH_REMATCH[3]}))
        PARSE_DATE_YEAR="20$((10#${BASH_REMATCH[5]}))"
        debug "regex match: Month DD, YY"

    #  DD Month YYYY
    elif [[ ${_stringToTest} =~ (.*[^0-9]|^)(([0-9]{2})[-\./_ ]+(january|jan|ja|february|feb|fe|march|mar|ma|april|apr|ap|may|june|jun|july|jul|ju|august|aug|september|sep|october|oct|november|nov|december|dec),?[-\./_ ]+(20[0-2][0-9]))([^0-9].*|$) ]]; then
        PARSE_DATE_FOUND="${BASH_REMATCH[2]}"
        PARSE_DATE_DAY=$((10#${BASH_REMATCH[3]}))
        PARSE_DATE_MONTH="$(_monthToNumber_ "${BASH_REMATCH[4]}")"
        PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH}")"
        PARSE_DATE_YEAR=$((10#${BASH_REMATCH[5]}))
        debug "regex match: DD Month, YYYY"

    # MM-DD-YYYY  or  DD-MM-YYYY
    elif [[ ${_stringToTest} =~ (.*[^0-9]|^)(([0-9]{1,2})[-\.\/_ ]+([0-9]{1,2})[-\.\/_ ]+(20[0-2][0-9]))([^0-9].*|$) ]]; then

        if [[ $((10#${BASH_REMATCH[3]})) -lt 13 &&
            $((10#${BASH_REMATCH[4]})) -gt 12 &&
            $((10#${BASH_REMATCH[4]})) -lt 32 ]] \
            ; then
            PARSE_DATE_FOUND="${BASH_REMATCH[2]}"
            PARSE_DATE_YEAR=$((10#${BASH_REMATCH[5]}))
            PARSE_DATE_MONTH=$((10#${BASH_REMATCH[3]}))
            PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH}")"
            PARSE_DATE_DAY=$((10#${BASH_REMATCH[4]}))
            debug "regex match: MM-DD-YYYY"
        elif [[ $((10#${BASH_REMATCH[3]})) -gt 12 &&
            $((10#${BASH_REMATCH[3]})) -lt 32 &&
            $((10#${BASH_REMATCH[4]})) -lt 13 ]] \
            ; then
            PARSE_DATE_FOUND="${BASH_REMATCH[2]}"
            PARSE_DATE_YEAR=$((10#${BASH_REMATCH[5]}))
            PARSE_DATE_MONTH=$((10#${BASH_REMATCH[4]}))
            PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH}")"
            PARSE_DATE_DAY=$((10#${BASH_REMATCH[3]}))
            debug "regex match: DD-MM-YYYY"
        elif [[ $((10#${BASH_REMATCH[3]})) -lt 32 &&
            $((10#${BASH_REMATCH[4]})) -lt 13 ]] \
            ; then
            PARSE_DATE_FOUND="${BASH_REMATCH[2]}"
            PARSE_DATE_YEAR=$((10#${BASH_REMATCH[5]}))
            PARSE_DATE_MONTH=$((10#${BASH_REMATCH[3]}))
            PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH}")"
            PARSE_DATE_DAY=$((10#${BASH_REMATCH[4]}))
            debug "regex match: MM-DD-YYYY"
        else
            shopt -u nocasematch
            return 1
        fi

    elif [[ ${_stringToTest} =~ (.*[^0-9]|^)(([0-9]{1,2})[-\.\/_ ]+([0-9]{1,2})[-\.\/_ ]+([0-9]{2}))([^0-9].*|$) ]]; then

        if [[ $((10#${BASH_REMATCH[3]})) -lt 13 &&
            $((10#${BASH_REMATCH[4]})) -gt 12 &&
            $((10#${BASH_REMATCH[4]})) -lt 32 ]] \
            ; then
            PARSE_DATE_FOUND="${BASH_REMATCH[2]}"
            PARSE_DATE_YEAR="20$((10#${BASH_REMATCH[5]}))"
            PARSE_DATE_MONTH=$((10#${BASH_REMATCH[3]}))
            PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH}")"
            PARSE_DATE_DAY=$((10#${BASH_REMATCH[4]}))
            debug "regex match: MM-DD-YYYY"
        elif [[ $((10#${BASH_REMATCH[3]})) -gt 12 &&
            $((10#${BASH_REMATCH[3]})) -lt 32 &&
            $((10#${BASH_REMATCH[4]})) -lt 13 ]] \
            ; then
            PARSE_DATE_FOUND="${BASH_REMATCH[2]}"
            PARSE_DATE_YEAR="20$((10#${BASH_REMATCH[5]}))"
            PARSE_DATE_MONTH=$((10#${BASH_REMATCH[4]}))
            PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH}")"
            PARSE_DATE_DAY=$((10#${BASH_REMATCH[3]}))
            debug "regex match: DD-MM-YYYY"
        elif [[ $((10#${BASH_REMATCH[3]})) -lt 32 &&
            $((10#${BASH_REMATCH[4]})) -lt 13 ]] \
            ; then
            PARSE_DATE_FOUND="${BASH_REMATCH[2]}"
            PARSE_DATE_YEAR="20$((10#${BASH_REMATCH[5]}))"
            PARSE_DATE_MONTH=$((10#${BASH_REMATCH[3]}))
            PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH}")"
            PARSE_DATE_DAY=$((10#${BASH_REMATCH[4]}))
            debug "regex match: MM-DD-YYYY"
        else
            shopt -u nocasematch
            return 1
        fi

    # Month, YYYY
    elif [[ ${_stringToTest} =~ ((january|jan|ja|february|feb|fe|march|mar|ma|april|apr|ap|may|june|jun|july|jul|ju|august|aug|september|sep|october|oct|november|nov|december|dec),?[-\./_ ]+(20[0-2][0-9]))([^0-9].*|$) ]]; then
        PARSE_DATE_FOUND="${BASH_REMATCH[1]}"
        PARSE_DATE_DAY="1"
        PARSE_DATE_MONTH="$(_monthToNumber_ "${BASH_REMATCH[2]}")"
        PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH}")"
        PARSE_DATE_YEAR="$((10#${BASH_REMATCH[3]}))"
        debug "regex match: Month, YYYY"

    # YYYYMMDDHHMM
    elif [[ ${_stringToTest} =~ (.*[^0-9]|^)((20[0-2][0-9])([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2}))([^0-9].*|$) ]]; then
        PARSE_DATE_FOUND="${BASH_REMATCH[2]}"
        PARSE_DATE_DAY="$((10#${BASH_REMATCH[5]}))"
        PARSE_DATE_MONTH="$((10#${BASH_REMATCH[4]}))"
        PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH}")"
        PARSE_DATE_YEAR="$((10#${BASH_REMATCH[3]}))"
        PARSE_DATE_HOUR="$((10#${BASH_REMATCH[6]}))"
        PARSE_DATE_MINUTE="$((10#${BASH_REMATCH[7]}))"
        debug "regex match: YYYYMMDDHHMM"

    # YYYYMMDDHH            1      2        3         4         5         6
    elif [[ ${_stringToTest} =~ (.*[^0-9]|^)((20[0-2][0-9])([0-9]{2})([0-9]{2})([0-9]{2}))([^0-9].*|$) ]]; then
        PARSE_DATE_FOUND="${BASH_REMATCH[2]}"
        PARSE_DATE_DAY="$((10#${BASH_REMATCH[5]}))"
        PARSE_DATE_MONTH="$((10#${BASH_REMATCH[4]}))"
        PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH}")"
        PARSE_DATE_YEAR="$((10#${BASH_REMATCH[3]}))"
        PARSE_DATE_HOUR="${BASH_REMATCH[6]}"
        PARSE_DATE_MINUTE="00"
        debug "regex match: YYYYMMDDHHMM"

    # MMDDYYYY or YYYYMMDD or DDMMYYYY
    #                        1     2    3         4         5         6
    elif [[ ${_stringToTest} =~ (.*[^0-9]|^)(([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2}))([^0-9].*|$) ]]; then

        # MMDDYYYY
        if [[ $((10#${BASH_REMATCH[5]})) -eq 20 &&
            $((10#${BASH_REMATCH[3]})) -lt 13 &&
            $((10#${BASH_REMATCH[4]})) -lt 32 ]] \
            ; then
            PARSE_DATE_FOUND="${BASH_REMATCH[2]}"
            PARSE_DATE_DAY="$((10#${BASH_REMATCH[4]}))"
            PARSE_DATE_MONTH="$((10#${BASH_REMATCH[3]}))"
            PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH}")"
            PARSE_DATE_YEAR="${BASH_REMATCH[5]}${BASH_REMATCH[6]}"
            debug "regex match: MMDDYYYY"
        # DDMMYYYY
        elif [[ $((10#${BASH_REMATCH[5]})) -eq 20 &&
            $((10#${BASH_REMATCH[3]})) -gt 12 &&
            $((10#${BASH_REMATCH[3]})) -lt 32 &&
            $((10#${BASH_REMATCH[4]})) -lt 13 ]] \
            ; then
            PARSE_DATE_FOUND="${BASH_REMATCH[2]}"
            PARSE_DATE_DAY="$((10#${BASH_REMATCH[3]}))"
            PARSE_DATE_MONTH="$((10#${BASH_REMATCH[4]}))"
            PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH}")"
            PARSE_DATE_YEAR="${BASH_REMATCH[5]}${BASH_REMATCH[6]}"
            debug "regex match: DDMMYYYY"
        # YYYYMMDD
        elif [[ $((10#${BASH_REMATCH[3]})) -eq 20 &&
            $((10#${BASH_REMATCH[6]})) -gt 12 &&
            $((10#${BASH_REMATCH[6]})) -lt 32 &&
            $((10#${BASH_REMATCH[5]})) -lt 13 ]] \
            ; then
            PARSE_DATE_FOUND="${BASH_REMATCH[2]}"
            PARSE_DATE_DAY="$((10#${BASH_REMATCH[6]}))"
            PARSE_DATE_MONTH="$((10#${BASH_REMATCH[5]}))"
            PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH}")"
            PARSE_DATE_YEAR="${BASH_REMATCH[3]}${BASH_REMATCH[4]}"
            debug "regex match: YYYYMMDD"
        # YYYYDDMM
        elif [[ $((10#${BASH_REMATCH[3]})) -eq 20 &&
            $((10#${BASH_REMATCH[5]})) -gt 12 &&
            $((10#${BASH_REMATCH[5]})) -lt 32 &&
            $((10#${BASH_REMATCH[6]})) -lt 13 ]] \
            ; then
            PARSE_DATE_FOUND="${BASH_REMATCH[2]}"
            PARSE_DATE_DAY="$((10#${BASH_REMATCH[5]}))"
            PARSE_DATE_MONTH="$((10#${BASH_REMATCH[6]}))"
            PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH}")"
            PARSE_DATE_YEAR="${BASH_REMATCH[3]}${BASH_REMATCH[4]}"
            debug "regex match: YYYYMMDD"
        # Assume YYYMMDD
        elif [[ $((10#${BASH_REMATCH[3]})) -eq 20 &&
            $((10#${BASH_REMATCH[6]})) -lt 32 &&
            $((10#${BASH_REMATCH[5]})) -lt 13 ]] \
            ; then
            PARSE_DATE_FOUND="${BASH_REMATCH[2]}"
            PARSE_DATE_DAY="$((10#${BASH_REMATCH[6]}))"
            PARSE_DATE_MONTH="$((10#${BASH_REMATCH[5]}))"
            PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH}")"
            PARSE_DATE_YEAR="${BASH_REMATCH[3]}${BASH_REMATCH[4]}"
            debug "regex match: YYYYMMDD"
        else
            shopt -u nocasematch
            return 1
        fi

    # # MMDD or DDYY
    # elif [[ "${_stringToTest}" =~ .*(([0-9]{2})([0-9]{2})).* ]]; then
    #     debug "regex match: MMDD or DDMM"
    #     PARSE_DATE_FOUND="${BASH_REMATCH[1]}"

    #    # Figure out if days are months or vice versa
    #     if [[ $(( 10#${BASH_REMATCH[2]} )) -gt 12 \
    #        && $(( 10#${BASH_REMATCH[2]} )) -lt 32 \
    #        && $(( 10#${BASH_REMATCH[3]} )) -lt 13 \
    #       ]]; then
    #             PARSE_DATE_DAY="$(( 10#${BASH_REMATCH[2]} ))"
    #             PARSE_DATE_MONTH="$(( 10#${BASH_REMATCH[3]} ))"
    #             PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH}")"
    #             PARSE_DATE_YEAR="$(date +%Y )"
    #     elif [[ $(( 10#${BASH_REMATCH[2]} )) -lt 13 \
    #          && $(( 10#${BASH_REMATCH[3]} )) -lt 32 \
    #          ]]; then
    #             PARSE_DATE_DAY="$(( 10#${BASH_REMATCH[3]} ))"
    #             PARSE_DATE_MONTH="$(( 10#${BASH_REMATCH[2]} ))"
    #             PARSE_DATE_MONTH_NAME="$(_numberToMonth_ "${PARSE_DATE_MONTH}")"
    #             PARSE_DATE_YEAR="$(date +%Y )"
    #     else
    #       shopt -u nocasematch
    #       return 1
    #     fi
    else
        shopt -u nocasematch
        return 1
    fi

    [[ -z ${PARSE_DATE_YEAR:-} ]] && {
        shopt -u nocasematch
        return 1
    }
    ((PARSE_DATE_MONTH >= 1 && PARSE_DATE_MONTH <= 12)) || {
        shopt -u nocasematch
        return 1
    }
    ((PARSE_DATE_DAY >= 1 && PARSE_DATE_DAY <= 31)) || {
        shopt -u nocasematch
        return 1
    }

    debug "\$PARSE_DATE_FOUND:     ${PARSE_DATE_FOUND}"
    debug "\$PARSE_DATE_YEAR:      ${PARSE_DATE_YEAR}"
    debug "\$PARSE_DATE_MONTH:     ${PARSE_DATE_MONTH}"
    debug "\$PARSE_DATE_MONTH_NAME: ${PARSE_DATE_MONTH_NAME}"
    debug "\$PARSE_DATE_DAY:       ${PARSE_DATE_DAY}"
    [[ -z ${PARSE_DATE_HOUR:-} ]] || debug "\$PARSE_DATE_HOUR:     ${PARSE_DATE_HOUR}"
    [[ -z ${PARSE_DATE_MINUTE:-} ]] || debug "\$PARSE_DATE_MINUTE:   ${PARSE_DATE_MINUTE}"

    shopt -u nocasematch
}

# @description Formats a Unix timestamp into a human-readable date/time string.
#
# @arg $1 integer (required) The Unix timestamp to format.
# @arg $2 string (optional) The output format string for 'date'. Defaults to "%F %T" (e.g., "2025-07-01 12:30:00").
#
# @stdout The formatted date and time string.
# @exitcode 0 On success.
# @exitcode 1 If the 'date' command fails.
#
# @example
#   _readableUnixTimestamp_ "1751352022" # -> 2025-07-01 12:00:22
#   _readableUnixTimestamp_ "1751352022" "%D" # -> 07/01/25
#
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility/blob/master/src/date.sh)
_readableUnixTimestamp_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"
    local _timestamp="${1}"
    local _format="${2:-"%F %T"}"
    local _out
    _out="$(date -d "@${_timestamp}" +"${_format}")" || return 1
    printf "%s\n" "${_out}"
}

# @description Converts a time string in HH:MM:SS format to the total number of seconds.
#
# @arg $1 string (required) The time string to convert.
# @arg $2 integer (optional) Minutes, if providing H M S as separate arguments.
# @arg $3 integer (optional) Seconds, if providing H M S as separate arguments.
#
# @stdout The total number of seconds.
#
# @note Acceptable Input Formats for a single string argument:
#   - 12:12:09 (and with other separators: ',', '-', '_', space)
#   - 12H12M09S (case-insensitive)
#
# @example
#   _toSeconds_ "01:02:03" # -> 3723
#   _toSeconds_ 1 2 3      # -> 3723
#
_toSeconds_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _saveIFS
    local _h _m _s

    if [[ $1 =~ [0-9]{1,2}(:|,|-|_|,| |[hHmMsS])[0-9]{1,2}(:|,|-|_|,| |[hHmMsS])[0-9]{1,2} ]]; then
        _saveIFS="${IFS}"
        IFS=":,;-_, HhMmSs" read -r _h _m _s <<<"$1"
        IFS="${_saveIFS}"
    else
        _h="$1"
        _m="$2"
        _s="$3"
    fi

    printf "%s\n" "$((10#${_h} * 3600 + 10#${_m} * 60 + 10#${_s}))"
}
