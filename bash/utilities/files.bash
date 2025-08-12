#=============================================================================
# @file files.bash
# @brief A utility library for common file and filesystem operations.
# @description
#   This script provides a collection of functions for file manipulation,
#   including creating backups, encrypting/decrypting, extracting archives,
#   parsing file paths, and converting between data formats like YAML and JSON.
#=============================================================================

# @description Creates a backup of a file or directory.
#   Can create a `.bak` file in place or copy/move the source to a backup directory.
#
# @option -d | -D Use a backup directory instead of creating a `.bak` file in the same location.
# @option -m | -M Move the source file (rename) instead of copying it. This removes the original.
#
# @arg $1 path (required) The source file or directory to back up.
# @arg $2 path (optional) The destination directory path to use with the `-d` flag. Defaults to `./backup`.
#
# @exitcode 0 On success.
# @exitcode 1 On error (e.g., source not found, unrecognized option).
#
# @note This function requires the `_execute_` and `_createUniqueFilename_` functions.
# @note Dotfiles (e.g., `.bashrc`) will have the leading dot removed in their backup filename (e.g., `bashrc`).
#
# @example
#   # Create a backup of file.txt as file.txt.bak
#   _backupFile_ "file.txt"
#
#   # Move file.txt to a backup directory
#   _backupFile_ -d -m "file.txt" "safe/location"
#
# @see _execute_()
# @see _createUniqueFilename_()
_backupFile_() {
    local opt
    local OPTIND=1
    local _useDirectory=false
    local _moveFile=false

    while getopts ":dDmM" opt; do
        case ${opt} in
        d | D) _useDirectory=true ;;
        m | M) _moveFile=true ;;
        *)
            {
                error "Unrecognized option '${1}' passed to _backupFile_" "${LINENO}"
                return 1
            }
            ;;
        esac
    done
    shift $((OPTIND - 1))

    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _fileToBackup="${1}"
    local _backupDir="${2:-backup}"
    local _newFilename

    # Error handling
    declare -f _execute_ &>/dev/null || fatal "_backupFile_ needs function _execute_"
    declare -f _createUniqueFilename_ &>/dev/null || fatal "_backupFile_ needs function _createUniqueFilename_"

    [[ ! -e "${_fileToBackup}" ]] &&
        {
            debug "Source '${_fileToBackup}' not found"
            return 1
        }

    if [[ ${_useDirectory} == true ]]; then

        [[ ! -d "${_backupDir}" ]] &&
            _execute_ "mkdir -p \"${_backupDir}\"" "Creating backup directory"

        _newFilename="$(_createUniqueFilename_ "${_backupDir}/${_fileToBackup#.}")"
        if [[ ${_moveFile} == true ]]; then
            _execute_ "mv \"${_fileToBackup}\" \"${_backupDir}/${_newFilename##*/}\"" "Moving: '${_fileToBackup}' to '${_backupDir}/${_newFilename##*/}'"
        else
            _execute_ "cp -R \"${_fileToBackup}\" \"${_backupDir}/${_newFilename##*/}\"" "Backing up: '${_fileToBackup}' to '${_backupDir}/${_newFilename##*/}'"
        fi
    else
        _newFilename="$(_createUniqueFilename_ "${_fileToBackup}.bak")"
        if [[ ${_moveFile} == true ]]; then
            _execute_ "mv \"${_fileToBackup}\" \"${_newFilename}\"" "Moving '${_fileToBackup}' to '${_newFilename}'"
        else
            _execute_ "cp -R \"${_fileToBackup}\" \"${_newFilename}\"" "Backing up '${_fileToBackup}' to '${_newFilename}'"
        fi
    fi
}

# @description Generates a unique filename by appending an incrementing number if the file already exists.
#
# @option -i | -I Places the unique number *before* the file extension instead of at the very end.
#
# @arg $1 path (required) The desired filename.
# @arg $2 string (optional) The separator character to use before the number. Defaults to `.`.
#
# @stdout The new, unique filename path.
# @exitcode 0 On success.
# @exitcode 1 On error.
#
# @example
#   # Assuming "file.txt" exists:
#   _createUniqueFilename_ "/data/file.txt" # -> /data/file.txt.1
#
#   # Assuming "file.txt" and "file-1.txt" exist:
#   _createUniqueFilename_ -i "/data/file.txt" "-" # -> /data/file-2.txt
#
_createUniqueFilename_() {
    [[ $# -lt 1 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local opt
    local OPTIND=1
    local _internalInteger=false
    while getopts ":iI" opt; do
        case ${opt} in
        i | I) _internalInteger=true ;;
        *)
            error "Unrecognized option '${1}' passed to ${FUNCNAME[0]}" "${LINENO}"
            return 1
            ;;
        esac
    done
    shift $((OPTIND - 1))

    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _fullFile="${1}"
    local _spacer="${2:-.}"
    local _filePath
    local _originalFile
    local _extension
    local _newFilename
    local _num
    local _levels
    local _fn
    local _ext
    local i

    # Find directories with realpath if input is an actual file
    if [[ -e "${_fullFile}" ]]; then
        _fullFile="$(realpath "${_fullFile}")"
    fi

    _filePath="$(dirname "${_fullFile}")"
    _originalFile="$(basename "${_fullFile}")"

    #shellcheck disable=SC2064
    trap '$(shopt -p nocasematch)' RETURN # reset nocasematch when function exits
    shopt -s nocasematch                  # Use case-insensitive regex

    # Detect some common multi-extensions
    case $(tr '[:upper:]' '[:lower:]' <<<"${_originalFile}") in
    *.tar.gz | *.tar.bz2) _levels=2 ;;
    *) _levels=1 ;;
    esac

    # Find Extension
    _fn="${_originalFile}"
    for ((i = 0; i < _levels; i++)); do
        _ext=${_fn##*.}
        if [[ ${i} == 0 ]]; then
            _extension=${_ext}${_extension:-}
        else
            _extension=${_ext}.${_extension:-}
        fi
        _fn=${_fn%."${_ext}"}
    done

    if [[ ${_extension} == "${_originalFile}" ]]; then
        _extension=""
    else
        _originalFile="${_originalFile%."${_extension}"}"
        _extension=".${_extension}"
    fi

    _newFilename="${_filePath}/${_originalFile}${_extension:-}"

    if [[ -e "${_newFilename}" ]]; then
        _num=1
        if [[ "${_internalInteger}" == true ]]; then
            while [[ -e "${_filePath}/${_originalFile}${_spacer}${_num}${_extension:-}" ]]; do
                ((_num++))
            done
            _newFilename="${_filePath}/${_originalFile}${_spacer}${_num}${_extension:-}"
        else
            while [[ -e "${_filePath}/${_originalFile}${_extension:-}${_spacer}${_num}" ]]; do
                ((_num++))
            done
            _newFilename="${_filePath}/${_originalFile}${_extension:-}${_spacer}${_num}"
        fi
    fi

    printf "%s\n" "${_newFilename}"
    return 0
}

# @description Decrypts a file using OpenSSL (aes-256-cbc).
#
# @arg $1 path (required) The encrypted file to decrypt (e.g., `file.enc`).
# @arg $2 path (optional) The name for the decrypted output file. Defaults to the input filename without `.enc`.
#
# @exitcode 0 On success.
# @exitcode 1 If the source file does not exist.
#
# @note This function requires `openssl` to be installed and the `_execute_` function to be available.
# @note If the global variable `$PASS` is set, it will be used as the decryption key. Otherwise, `openssl` will prompt for it.
#
# @example
#   _decryptFile_ "secret.txt.enc" "secret.txt"
#
# @see _execute_()
_decryptFile_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _fileToDecrypt="${1:?_decryptFile_ needs a file}"
    local _defaultName="${_fileToDecrypt%.enc}"
    local _decryptedFile="${2:-${_defaultName}.decrypt}"

    declare -f _execute_ &>/dev/null || fatal "${FUNCNAME[0]} needs function _execute_"

    if ! command -v openssl &>/dev/null; then
        fatal "openssl not found"
    fi

    [[ ! -f "${_fileToDecrypt}" ]] && return 1

    if [[ -z "${PASS:-}" ]]; then
        _execute_ "openssl enc -aes-256-cbc -d -in \"${_fileToDecrypt}\" -out \"${_decryptedFile}\"" "Decrypt ${_fileToDecrypt}"
    else
        _execute_ "openssl enc -aes-256-cbc -d -in \"${_fileToDecrypt}\" -out \"${_decryptedFile}\" -k \"${PASS}\"" "Decrypt ${_fileToDecrypt}"
    fi
}

# @description Encrypts a file using OpenSSL (aes-256-cbc).
#
# @arg $1 path (required) The file to encrypt.
# @arg $2 path (optional) The name for the encrypted output file. Defaults to the input filename with `.enc` appended.
#
# @note This function requires `openssl` to be installed and the `_execute_` function to be available.
# @note If the global variable `$PASS` is set, it will be used as the encryption key. Otherwise, `openssl` will prompt for it.
#
# @example
#   _encryptFile_ "important.docx"
#
# @see _execute_()
_encryptFile_() {
    local _fileToEncrypt="${1:?_encodeFile_ needs a file}"
    local _defaultName="${_fileToEncrypt%.decrypt}"
    local _encryptedFile="${2:-${_defaultName}.enc}"

    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    [[ ! -f "${_fileToEncrypt}" ]] && return 1

    declare -f _execute_ &>/dev/null || fatal "${FUNCNAME[0]} needs function _execute_"

    if ! command -v openssl &>/dev/null; then
        fatal "openssl not found"
    fi

    if [[ -z "${PASS:-}" ]]; then
        _execute_ "openssl enc -aes-256-cbc -salt -in \"${_fileToEncrypt}\" -out \"${_encryptedFile}\"" "Encrypt ${_fileToEncrypt}"
    else
        _execute_ "openssl enc -aes-256-cbc -salt -in \"${_fileToEncrypt}\" -out \"${_encryptedFile}\" -k \"${PASS}\"" "Encrypt ${_fileToEncrypt}"
    fi
}

# @description Extracts a wide variety of archive types using available system commands.
#   Supported formats include: .tar.bz2, .tbz, .tar.gz, .tgz, .tar.xz, .tar, .bz2, .gz, .xz, .zip, .rar, .7z, .deb, and more.
#
# @arg $1 path (required) The archive file to extract.
# @arg $2 string (optional) Pass 'v' to enable verbose output for commands that support it.
#
# @exitcode 0 On success.
# @exitcode 1 If the file does not exist or the archive type is unsupported.
#
# @example
#   _extractArchive_ "my_project.tar.gz"
#
_extractArchive_() {
    local _vv

    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    [[ ${2:-} == "v" ]] && _vv="v"

    if [[ -f "$1" ]]; then
        case "$1" in
        *.tar.bz2 | *.tbz | *.tbz2) tar "x${_vv}jf" "$1" ;;
        *.tar.gz | *.tgz) tar "x${_vv}zf" "$1" ;;
        *.tar.xz)
            xz --decompress "$1"
            set -- "$@" "${1:0:-3}"
            ;;
        *.tar.Z)
            uncompress "$1"
            set -- "$@" "${1:0:-2}"
            ;;
        *.bz2) bunzip2 "$1" ;;
        *.deb) dpkg-deb -x"${_vv}" "$1" "${1:0:-4}" ;;
        *.pax.gz)
            gunzip "$1"
            set -- "$@" "${1:0:-3}"
            ;;
        *.gz) gunzip "$1" ;;
        *.pax) pax -r -f "$1" ;;
        *.pkg) pkgutil --expand "$1" "${1:0:-4}" ;;
        *.rar) unrar x "$1" ;;
        *.rpm)
            local _rpm_output
            _rpm_output=$(rpm2cpio "$1")
            printf "%s\n" "${_rpm_output}" | cpio -idm"${_vv}"
            ;;
        *.tar) tar "x${_vv}f" "$1" ;;
        *.txz)
            mv "$1" "${1:0:-4}.tar.xz"
            set -- "$@" "${1:0:-4}.tar.xz"
            ;;
        *.xz) xz --decompress "$1" ;;
        *.zip | *.war | *.jar) unzip "$1" ;;
        *.Z) uncompress "$1" ;;
        *.7z) 7za x "$1" ;;
        *) return 1 ;;
        esac
    else
        return 1
    fi
}

# @description Gets the filename (including extension) from a full path.
#
# @arg $1 path (required) The input path string.
#
# @stdout The filename with its extension.
#
# @example
#   _fileName_ "/var/log/syslog.log" # -> syslog.log
#
_fileName_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"
    printf "%s\n" "${1##*/}"
}

# @description Gets the basename of a file (filename without extension) from a path.
#
# @arg $1 path (required) The input path string.
#
# @stdout The filename without its path or extension.
#
# @example
#   _fileBasename_ "some/path/to/archive.tar.gz" # -> archive.tar
#
_fileBasename_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _file
    local _basename
    _file="${1##*/}"
    _basename="${_file%.*}"

    printf "%s" "${_basename}"
}

# @description Gets the extension from a filename.
#   It can detect common double extensions like `.tar.gz`.
#
# @arg $1 path (required) The input path string.
#
# @stdout The file extension, without the leading dot.
# @exitcode 1 If no extension is found.
#
# @example
#   _fileExtension_ "archive.tar.gz" # -> tar.gz
#   _fileExtension_ "document.pdf"   # -> pdf
#
_fileExtension_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _file
    local _extension
    local _levels
    local _ext
    local _exts
    _file="${1##*/}"

    # Detect some common multi-extensions
    if [[ -z ${_levels:-} ]]; then
        case $(tr '[:upper:]' '[:lower:]' <<<"${_file}") in
        *.tar.gz | *.tar.bz2 | *.log.[0-9]) _levels=2 ;;
        *) _levels=1 ;;
        esac
    fi

    _fn="${_file}"
    for ((i = 0; i < _levels; i++)); do
        _ext=${_fn##*.}
        if [[ ${i} == 0 ]]; then
            _exts=${_ext}${_exts:-}
        else
            _exts=${_ext}.${_exts:-}
        fi
        _fn=${_fn%."${_ext}"}
    done
    [[ ${_file} == "${_exts}" ]] && return 1

    printf "%s" "${_exts}"

}

# @description Gets the directory name from a full file path.
#   If the path exists, it returns the absolute (real) path to the directory.
#
# @arg $1 path (required) The input path string.
#
# @stdout The directory path.
#
# @example
#   _filePath_ "/var/log/syslog.log" # -> /var/log
#
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility/)
_filePath_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _tmp=${1}

    if [[ -e "${_tmp}" ]]; then
        local _realpath
        _realpath=$(realpath "${_tmp}")
        _tmp="$(dirname "${_realpath}")"
    else
        [[ ${_tmp} != *[!/]* ]] && { printf '/\n' && return; }
        _tmp="${_tmp%%"${_tmp##*[!/]}"}"

        [[ ${_tmp} != */* ]] && { printf '.\n' && return; }
        _tmp=${_tmp%/*} && _tmp="${_tmp%%"${_tmp##*[!/]}"}"
    fi
    printf '%s' "${_tmp:-/}"
}

# @description Searches a file for a given grep pattern.
#
# @arg $1 path (required) The file to search within.
# @arg $2 string (required) The grep pattern to search for.
#
# @exitcode 0 If the pattern is found in the file.
# @exitcode 1 If the pattern is not found.
#
# @example
#   if _fileContains_ "/etc/hosts" "localhost"; then
#     echo "localhost is defined in hosts file."
#   fi
#
_fileContains_() {
    [[ $# -lt 2 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _file="$1"
    local _text="$2"
    grep -q "${_text}" "${_file}"
}

# @description Converts a JSON file to YAML format.
#
# @arg $1 path (required) The input JSON file.
#
# @stdout The converted content in YAML format.
#
# @note This function requires `python` and the `pyyaml` library to be installed. (`pip install pyyaml`)
#
# @example
#   _json2yaml_ "data.json" > "data.yml"
#
_json2yaml_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    python -c 'import sys, yaml, json; yaml.safe_dump(json.load(sys.stdin), sys.stdout, default_flow_style=False)' <"${1}"
}

# @description Finds files in a directory using either glob or regex patterns.
#
# @arg $1 string (required) The search type: 'glob' (or 'g') or 'regex' (or 'r').
# @arg $2 string (required) The search pattern (case-insensitive). Must be quoted.
# @arg $3 path (optional) The directory to search in. Defaults to the current directory (`.`).
#
# @stdout A list of matching absolute file paths, one per line.
# @exitcode 0 If files are found.
# @exitcode 1 If no files are found.
#
# @example
#   _listFiles_ glob "*.log" "/var/log"
#   mapfile -t txt_files < <(_listFiles_ g "*.txt")
#
_listFiles_() {
    [[ $# -lt 2 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _searchType="${1}"
    local _pattern="${2}"
    local _directory="${3:-.}"
    local _fileMatch
    declare -a _matchedFiles=()
    local _find_output

    case "${_searchType}" in
    [Gg]*)
        _find_output=$(find "${_directory}" -maxdepth 1 -iname "${_pattern}" -type f)
        _sorted_output=$(printf "%s\n" "${_find_output}" | sort) || true
        while read -r _fileMatch; do
            _matchedFiles+=("$(realpath "${_fileMatch}")")
        done <<<"${_sorted_output}"
        ;;
    [Rr]*)
        _find_output=$(find "${_directory}" -maxdepth 1 -regextype posix-extended -iregex "${_pattern}" -type f)
        _sorted_output=$(printf "%s\n" "${_find_output}" | sort) || true
        while read -r _fileMatch; do
            _matchedFiles+=("$(realpath "${_fileMatch}")")
        done <<<"${_sorted_output}"
        ;;
    *)
        fatal "_listFiles_: Could not determine if search was glob or regex"
        ;;
    esac

    if [[ ${#_matchedFiles[@]} -gt 0 ]]; then
        printf "%s\n" "${_matchedFiles[@]}"
        return 0
    else
        return 1
    fi
}

# @description Creates a symlink, safely backing up any existing file or symlink at the destination.
#
# @option -c | -C Quiet mode. Only report on new or changed symlinks.
# @option -n | -N No backup. Overwrites the destination without creating a backup.
# @option -s | -S Use `sudo` when removing the destination file/symlink.
#
# @arg $1 path (required) The source file/directory for the symlink.
# @arg $2 path (required) The destination path for the new symlink.
#
# @exitcode 0 On success.
# @exitcode 1 On error.
#
# @example
#   _makeSymlink_ "~/dotfiles/.bashrc" "~/.bashrc"
#
_makeSymlink_() {
    local opt
    local OPTIND=1
    local _backupOriginal=true
    local _useSudo=false
    local _onlyShowChanged=false

    while getopts ":cCnNsS" opt; do
        case ${opt} in
        n | N) _backupOriginal=false ;;
        s | S) _useSudo=true ;;
        c | C) _onlyShowChanged=true ;;
        *) fatal "Missing required argument to ${FUNCNAME[0]}" ;;
        esac
    done
    shift $((OPTIND - 1))

    declare -f _execute_ &>/dev/null || fatal "${FUNCNAME[0]} needs function _execute_"
    declare -f _backupFile_ &>/dev/null || fatal "${FUNCNAME[0]} needs function _backupFile_"

    if ! command -v realpath >/dev/null 2>&1; then
        error "We must have 'realpath' installed and available in \$PATH to run."
        if [[ ${OSTYPE} == "darwin"* ]]; then
            notice "Install coreutils using homebrew and rerun this script."
            info "\t$ brew install coreutils"
        fi
        _safeExit_ 1
    fi

    [[ $# -lt 2 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _sourceFile="$1"
    local _destinationFile="$2"
    local _originalFile

    # Fix files where $HOME is written as '~'
    _destinationFile="${_destinationFile/\~/${HOME}}"
    _sourceFile="${_sourceFile/\~/${HOME}}"

    [[ ! -e "${_sourceFile}" ]] &&
        {
            error "'${_sourceFile}' not found"
            return 1
        }
    [[ -z "${_destinationFile}" ]] &&
        {
            error "'${_destinationFile}' not specified"
            return 1
        }

    # Create destination directory if needed
    [[ ! -d "${_destinationFile%/*}" ]] &&
        _execute_ "mkdir -p \"${_destinationFile%/*}\""

    if [[ ! -e "${_destinationFile}" ]]; then
        _execute_ "ln -fs \"${_sourceFile}\" \"${_destinationFile}\"" "symlink ${_sourceFile} → ${_destinationFile}"
    elif [[ -h "${_destinationFile}" ]]; then
        _originalFile="$(realpath "${_destinationFile}")"

        [[ ${_originalFile} == "${_sourceFile}" ]] && {
            if [[ ${_onlyShowChanged} == true ]]; then
                debug "Symlink already exists: ${_sourceFile} → ${_destinationFile}"
            elif [[ ${DRYRUN:-} == true ]]; then
                dryrun "Symlink already exists: ${_sourceFile} → ${_destinationFile}"
            else
                info "Symlink already exists: ${_sourceFile} → ${_destinationFile}"
            fi
            return 0
        }

        if [[ ${_backupOriginal} == true ]]; then
            _backupFile_ "${_destinationFile}"
        fi
        if [[ ${DRYRUN} == false ]]; then
            if [[ ${_useSudo} == true ]]; then
                command rm -rf "${_destinationFile}"
            else
                command rm -rf "${_destinationFile}"
            fi
        fi
        _execute_ "ln -fs \"${_sourceFile}\" \"${_destinationFile}\"" "symlink ${_sourceFile} → ${_destinationFile}"
    elif [[ -e "${_destinationFile}" ]]; then
        if [[ ${_backupOriginal} == true ]]; then
            _backupFile_ "${_destinationFile}"
        fi
        if [[ ${DRYRUN} == false ]]; then
            if [[ ${_useSudo} == true ]]; then
                sudo command rm -rf "${_destinationFile}"
            else
                command rm -rf "${_destinationFile}"
            fi
        fi
        _execute_ "ln -fs \"${_sourceFile}\" \"${_destinationFile}\"" "symlink ${_sourceFile} → ${_destinationFile}"
    else
        warning "Error linking: ${_sourceFile} → ${_destinationFile}"
        return 1
    fi
    return 0
}

# @description Parses a YAML file and converts its structure into Bash variable assignments.
#
# @arg $1 path (required) The source YAML file.
# @arg $2 string (required) A prefix to add to all generated variable names to prevent collisions.
#
# @stdout A series of Bash variable and array assignments that can be sourced.
#
# @example
#   # Given sample.yml:
#   # user: admin
#   # hosts:
#   #   - web1
#   #   - web2
#
#   eval "$(_parseYAML_ "sample.yml" "CONF_")"
#   echo $CONF_user # -> admin
#   echo ${CONF_hosts[0]} # -> web1
#
# @see [DinoChiesa's Gist](https://gist.github.com/DinoChiesa/3e3c3866b51290f31243)
# @see [epiloque's Gist](https://gist.github.com/epiloque/8cf512c6d64641bde388)
_parseYAML_() {
    [[ $# -lt 2 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _yamlFile="${1}"
    local _prefix="${2:-}"

    [[ ! -s "${_yamlFile}" ]] && return 1

    local _s='[[:space:]]*'
    local _w='[a-zA-Z0-9_]*'
    local _fs
    _fs="$(printf @ | tr @ '\034')"

    local _sed_output _awk_output _parsed_yaml
    _sed_output=$(sed -ne "s|^\(${_s}\)\(${_w}\)${_s}:${_s}\"\(.*\)\"${_s}\$|\1${_fs}\2${_fs}\3|p" \
        -e "s|^\(${_s}\)\(${_w}\)${_s}[:-]${_s}\(.*\)${_s}\$|\1${_fs}\2${_fs}\3|p" "${_yamlFile}")

    _awk_output=$(printf "%s\n" "${_sed_output}" | awk -F"${_fs}" '{
    indent = length($1)/2;
    if (length($2) == 0) { conj[indent]="+";} else {conj[indent]="";}
    vname[indent] = $2;
    for (i in vname) {if (i > indent) {delete vname[i]}}
    if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s%s=(\"%s\")\n", "'"${_prefix}"'",vn, $2, conj[indent-1],$3);
    }
  }')
    _parsed_yaml=$(printf "%s\n" "${_awk_output}" | sed 's/__=/+=/g')
    _parsed_yaml=$(printf "%s\n" "${_parsed_yaml}" | sed 's/_=/+=/g')
    _parsed_yaml=$(printf "%s\n" "${_parsed_yaml}" | sed 's/[[:space:]]*#.*"/"/g')
    _parsed_yaml=$(printf "%s\n" "${_parsed_yaml}" | sed 's/=("--")//g')
    printf "%s\n" "${_parsed_yaml}"
}

# @description Prints the block of text from a file that is between two regex patterns.
#
# @option -i | -I Use case-insensitive regex matching.
# @option -r | -R Remove the first and last lines (the lines matching the patterns) from the output.
# @option -g | -G Greedy mode. If multiple start/end blocks exist, match from the first start to the last end.
#
# @arg $1 string (required) The starting regex pattern.
# @arg $2 string (required) The ending regex pattern.
# @arg $3 path (required) The input file path.
#
# @stdout The block of text found between the patterns.
# @exitcode 0 On success.
# @exitcode 1 If no matching block is found.
#
# @example
#   _printFileBetween_ "^START$" "^END$" "my_log_file.txt"
#
_printFileBetween_() (
    [[ $# -lt 3 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _removeLines=false
    local _greedy=false
    local _caseInsensitive=false
    local opt
    local OPTIND=1
    while getopts ":iIrRgG" opt; do
        case ${opt} in
        i | I) _caseInsensitive=true ;;
        r | R) _removeLines=true ;;
        g | G) _greedy=true ;;
        *) fatal "Unrecognized option '${1}' passed to ${FUNCNAME[0]}. Exiting." ;;
        esac
    done
    shift $((OPTIND - 1))

    local _startRegex="${1}"
    local _endRegex="${2}"
    local _input="${3}"
    local _output
    local _sed_output
    local _intermediate_output

    if [[ ${_removeLines} == true ]]; then
        if [[ ${_greedy} == true ]]; then
            if [[ ${_caseInsensitive} == true ]]; then
                _sed_output=$(sed -nE "/${_startRegex}/I,/${_endRegex}/Ip" "${_input}")
                _intermediate_output=$(printf "%s\n" "${_sed_output}" | sed -n '2,$p')
                _output=$(printf "%s\n" "${_intermediate_output}" | sed '$d')
            else
                _sed_output=$(sed -nE "/${_startRegex}/,/${_endRegex}/p" "${_input}")
                _intermediate_output=$(printf "%s\n" "${_sed_output}" | sed -n '2,$p')
                _output=$(printf "%s\n" "${_intermediate_output}" | sed '$d')
            fi
        else
            if [[ ${_caseInsensitive} == true ]]; then
                _sed_output=$(sed -nE "/${_startRegex}/I,/${_endRegex}/I{p;/${_endRegex}/Iq}" "${_input}")
                _intermediate_output=$(printf "%s\n" "${_sed_output}" | sed -n '2,$p')
                _output=$(printf "%s\n" "${_intermediate_output}" | sed '$d')
            else
                _sed_output=$(sed -nE "/${_startRegex}/,/${_endRegex}/{p;/${_endRegex}/q}" "${_input}")
                _intermediate_output=$(printf "%s\n" "${_sed_output}" | sed -n '2,$p')
                _output=$(printf "%s\n" "${_intermediate_output}" | sed '$d')
            fi
        fi
    else
        if [[ ${_greedy} == true ]]; then
            if [[ ${_caseInsensitive} == true ]]; then
                _output=$(sed -nE "/${_startRegex}/I,/${_endRegex}/Ip" "${_input}")
            else
                _output=$(sed -nE "/${_startRegex}/,/${_endRegex}/p" "${_input}")
            fi
        else
            if [[ ${_caseInsensitive} == true ]]; then
                _output=$(sed -nE "/${_startRegex}/I,/${_endRegex}/I{p;/${_endRegex}/Iq}" "${_input}")
            else
                _output=$(sed -nE "/${_startRegex}/,/${_endRegex}/{p;/${_endRegex}/q}" "${_input}")
            fi
        fi
    fi

    if [[ -n ${_output:-} ]]; then
        printf "%s\n" "${_output}"
        return 0
    else
        return 1
    fi
)

# @description Returns a single random line from a given file.
#
# @arg $1 path (required) The input file.
#
# @stdout A single random line from the file.
# @exitcode 1 If the file is not found.
#
# @example
#   random_quote=$(_randomLineFromFile_ "quotes.txt")
#
_randomLineFromFile_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _fileToRead="$1"
    local _rnd

    [[ ! -f "${_fileToRead}" ]] &&
        {
            error "'${_fileToRead}' not found"
            return 1
        }

    _rnd=$((1 + RANDOM % $(wc -l <"${_fileToRead}")))
    sed -n "${_rnd}p" "${_fileToRead}"
}

# @description Prints each line of a file to stdout.
#
# @arg $1 path (required) The input file.
#
# @stdout The entire content of the file.
# @exitcode 1 If the file is not found.
#
# @example
#   _readFile_ "/etc/hosts"
#
_readFile_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _result
    local _fileToRead="$1"

    [[ ! -f "${_fileToRead}" ]] &&
        {
            error "'${_fileToRead}' not found"
            return 1
        }

    while read -r _result; do
        printf "%s\n" "${_result}"
    done <"${_fileToRead}"
}

# @description Safely sources a file into the current script.
#   Exits with a fatal error if the file does not exist or fails to be sourced.
#
# @arg $1 path (required) The file to be sourced.
#
# @exitcode 0 If the file is sourced successfully.
#
# @example
#   _sourceFile_ "my_config.conf"
#
_sourceFile_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _fileToSource="$1"

    [[ ! -f "${_fileToSource}" ]] && fatal "Attempted to source '${_fileToSource}'. Not found"
    # shellcheck disable=SC1090
    if source "${_fileToSource}"; then
        return 0
    else
        fatal "Failed to source: ${_fileToSource}"
    fi
}

# @description Converts a YAML file to JSON format.
#
# @arg $1 path (required) The input YAML file.
#
# @stdout The converted content in JSON format.
#
# @note This function requires `python` and the `pyyaml` library to be installed. (`pip install pyyaml`)
#
# @example
#   _yaml2json_ "config.yml" > "config.json"
#
_yaml2json_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    python -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout, indent=4)' <"${1:?_yaml2json_ needs a file}"
}
