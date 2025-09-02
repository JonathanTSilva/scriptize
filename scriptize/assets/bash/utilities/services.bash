#=============================================================================
# @file services.bash
# @brief A utility library for interacting with external network services.
# @description
#   This script provides wrapper functions for common network tasks, such as
#   checking the HTTP status of a URL and sending push notifications via the
#   Pushover service. These functions depend on the `curl` command-line tool.
#=============================================================================

# @description Reports the HTTP status of a specified URL using `curl`.
#
# @arg $1 string (required) The URL to check. The 'https://' prefix is optional.
# @arg $2 integer (optional) The connection timeout in seconds. Defaults to 3.
# @arg $3 string (optional) Output mode. Use '--code' or '-c' for the numeric code only, or '--status' or '-s' for the code and message. Defaults to '--status'.
# @arg $@ string (optional) Additional options to pass directly to the `curl` command (e.g., `-L` to follow redirects).
#
# @stdout The HTTP status code, or the code followed by the status message, depending on the output mode.
#
# @note This function requires `curl` to be installed.
#
# @example
#   # Get the status message for a redirection
#   _httpStatus_ "bit.ly"
#   # Output: 301 Redirection: Moved Permanently
#
#   # Get just the status code for a successful site
#   _httpStatus_ "www.google.com" 5 --code
#   # Output: 200
#
#   # Follow redirects and get the final status code
#   _httpStatus_ "http://google.com" 5 --code -L
#   # Output: 200
#
# @see [Gist by rsvp](https://gist.github.com/rsvp/1171304)
_httpStatus_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _saveIFS=${IFS}
    IFS=$' \n\t'

    local _url=${1}
    local _timeout=${2:-3}
    local _flag=${3:---status}
    local _arg4=${4:-}
    local _arg5=${5:-}
    local _arg6=${6:-}
    local _arg7=${7:-}
    local _curlops="${_arg4} ${_arg5} ${_arg6} ${_arg7}"
    local _code
    local _status

    #      __________ get the CODE which is numeric:
    # shellcheck disable=SC1083
    _code=$(curl --write-out %{http_code} --silent --connect-timeout "${_timeout}" \
        --no-keepalive "${_curlops}" --output /dev/null "${_url}")

    #      __________ get the STATUS (from code) which is human interpretable:
    case ${_code} in
    000) _status="Not responding within ${_timeout} seconds" ;;
    100) _status="Informational: Continue" ;;
    101) _status="Informational: Switching Protocols" ;;
    200) _status="Successful: OK within ${_timeout} seconds" ;;
    201) _status="Successful: Created" ;;
    202) _status="Successful: Accepted" ;;
    203) _status="Successful: Non-Authoritative Information" ;;
    204) _status="Successful: No Content" ;;
    205) _status="Successful: Reset Content" ;;
    206) _status="Successful: Partial Content" ;;
    300) _status="Redirection: Multiple Choices" ;;
    301) _status="Redirection: Moved Permanently" ;;
    302) _status="Redirection: Found residing temporarily under different URI" ;;
    303) _status="Redirection: See Other" ;;
    304) _status="Redirection: Not Modified" ;;
    305) _status="Redirection: Use Proxy" ;;
    306) _status="Redirection: status not defined" ;;
    307) _status="Redirection: Temporary Redirect" ;;
    400) _status="Client Error: Bad Request" ;;
    401) _status="Client Error: Unauthorized" ;;
    402) _status="Client Error: Payment Required" ;;
    403) _status="Client Error: Forbidden" ;;
    404) _status="Client Error: Not Found" ;;
    405) _status="Client Error: Method Not Allowed" ;;
    406) _status="Client Error: Not Acceptable" ;;
    407) _status="Client Error: Proxy Authentication Required" ;;
    408) _status="Client Error: Request Timeout within ${_timeout} seconds" ;;
    409) _status="Client Error: Conflict" ;;
    410) _status="Client Error: Gone" ;;
    411) _status="Client Error: Length Required" ;;
    412) _status="Client Error: Precondition Failed" ;;
    413) _status="Client Error: Request Entity Too Large" ;;
    414) _status="Client Error: Request-URI Too Long" ;;
    415) _status="Client Error: Unsupported Media Type" ;;
    416) _status="Client Error: Requested Range Not Satisfiable" ;;
    417) _status="Client Error: Expectation Failed" ;;
    500) _status="Server Error: Internal Server Error" ;;
    501) _status="Server Error: Not Implemented" ;;
    502) _status="Server Error: Bad Gateway" ;;
    503) _status="Server Error: Service Unavailable" ;;
    504) _status="Server Error: Gateway Timeout within ${_timeout} seconds" ;;
    505) _status="Server Error: HTTP Version Not Supported" ;;
    *) fatal "httpstatus: status not defined." ;;
    esac

    case ${_flag} in
    --status) printf "%s %s\n" "${_code}" "${_status}" ;;
    -s) printf "%s %s\n" "${_code}" "${_status}" ;;
    --code) printf "%s\n" "${_code}" ;;
    -c) printf "%s\n" "${_code}" ;;
    *) printf "%s\n" "_httpStatus_: bad flag" && _safeExit_ ;;
    esac

    IFS="${_saveIFS}"
}

# @description Sends a push notification via the Pushover service.
#
# @arg $1 string (required) The title of the notification.
# @arg $2 string (required) The main message body of the notification.
# @arg $3 string (required) Your Pushover Application API Token.
# @arg $4 string (required) Your Pushover User/Group Key.
# @arg $5 string (optional) The name of a specific device to send the notification to.
#
# @exitcode 0 If the notification was sent successfully (HTTP 200 OK).
# @exitcode 1 If the `curl` command fails.
#
# @note This function requires `curl` to be installed.
#
# @example
#   PUSHOVER_TOKEN="azG...s3"
#   PUSHOVER_USER="uQ...4s"
#   if ! _pushover_ "Job Complete" "The backup script finished." "${PUSHOVER_TOKEN}" "${PUSHOVER_USER}"; then
#     error "Failed to send Pushover notification."
#   fi
#
# @see [Credit](http://ryonsherman.blogspot.com/2012/10/shell-script-to-send-pushover.html)
_pushover_() {
    [[ $# -lt 4 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _pushoverURL="https://api.pushover.net/1/messages.json"
    local _messageTitle="${1}"
    local _message="${2}"
    local _apiKey="${3}"  # This is the Application API Token
    local _userKey="${4}" # This is the User/Group Key
    local _device="${5:-}"

    if curl \
        -F "token=${_apiKey}" \
        -F "user=${_userKey}" \
        -F "device=${_device}" \
        -F "title=${_messageTitle}" \
        -F "message=${_message}" \
        "${_pushoverURL}" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}
