#=============================================================================
# @file arrays.bash
# @brief A utility library for common array manipulations in Bash.
# @description
#   This script provides a collection of portable and robust functions for
#   working with Bash arrays. It includes functions for sorting, filtering,
#   joining, de-duplicating, and iterating over array elements.
#
#   Many functions leverage standard input (stdin) for receiving array elements,
#   allowing for flexible use with pipelines.
#=============================================================================

# @description Removes duplicate elements from an array.
#   Maintains the order of the first occurrence of each unique element.
#
# @arg $@ any (required) The input array elements to be de-duplicated.
#
# @stdout Prints the unique elements, one per line.
#
# @note The original list order of unique elements is preserved.
#
# @example
#   local my_array=("a" "c" "b" "a" "c")
#   local new_array
#   mapfile -t new_array < <(_dedupeArray_ "${my_array[@]}")
#   # new_array will contain ("a" "c" "b")
#
# @see [pure-bash-bible](https://github.com/dylanaraps/pure-bash-bible)
_dedupeArray_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"
    declare -A _tmpArray
    declare -a _uniqueArray
    local _i
    for _i in "$@"; do
        { [[ -z ${_i} || -n ${_tmpArray[${_i}]:-} ]]; } && continue
        _uniqueArray+=("${_i}") && _tmpArray[${_i}]=x
    done
    printf '%s\n' "${_uniqueArray[@]}"
}

# @description Iterates over elements from stdin and executes a callback function for each one.
#
# @arg $1 string (required) The name of the function to execute for each item.
#
# @stdin any The elements to iterate over, one per line.
#
# @stdout The combined output of all commands executed by the callback function.
# @exitcode 0 On full successful iteration.
# @exitcode N The exit code of the first failing command from the callback function.
#
# @example
#   test_func() { echo "Processing: $1"; }
#   printf "%s\n" "apple" "banana" | _forEachDo_ "test_func"
#
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility)
_forEachDo_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _func="${1}"
    local IFS=$'\n'
    local _it

    while read -r _it; do
        if [[ ${_func} == *"$"* ]]; then
            eval "${_func}"
        else
            if declare -f "${_func}" &>/dev/null; then
                eval "${_func}" "'${_it}'"
            else
                fatal "${FUNCNAME[0]} could not find function ${_func}"
            fi
        fi
        declare -i _ret="$?"

        if [[ ${_ret} -ne 0 ]]; then
            return "${_ret}"
        fi
    done
}

# @description Iterates over elements from stdin, passing each to a validation function.
#   The iteration stops as soon as any element fails validation.
#
# @arg $1 string (required) The validation function to call for each item.
#
# @stdin any The elements to iterate over, one per line.
#
# @exitcode 0 If all elements are successfully validated.
# @exitcode 1 If any element fails validation.
#
# @example
#   # Assuming _isNum_ is a function that checks if input is numeric.
#   printf "1\n2\n3\n" | _forEachValidate_ "_isNum_" # returns 0
#   printf "1\n_a_\n3\n" | _forEachValidate_ "_isNum_" # returns 1
#
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility)
_forEachValidate_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _func="${1}"
    local IFS=$'\n'
    local _it

    while read -r _it; do
        if [[ ${_func} == *"$"* ]]; then
            eval "${_func}"
        else
            if ! declare -f "${_func}"; then
                fatal "${FUNCNAME[0]} could not find function ${_func}"
            else
                eval "${_func}" "'${_it}'"
            fi
        fi
        declare -i _ret="$?"

        if [[ ${_ret} -ne 0 ]]; then
            return 1
        fi
    done
}

# @description Iterates over elements from stdin, returning the first value that is validated by a function.
#
# @arg $1 string (required) The validation function to call for each item.
#
# @stdin any The elements to iterate over, one per line.
#
# @stdout The first element that successfully passes the validation function.
# @exitcode 0 If a matching element is found.
# @exitcode 1 If no element matches the validation.
#
# @example
#   local array=("a" "b" "3" "d")
#   first_num=$(printf "%s\n" "${array[@]}" | _forEachFind_ "_isNum_")
#   # first_num will be "3"
#
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility)
_forEachFind_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    declare _func="${1}"
    declare IFS=$'\n'
    while read -r _it; do

        if [[ ${_func} == *"$"* ]]; then
            eval "${_func}"
        else
            eval "${_func}" "'${_it}'"
        fi
        declare -i _ret="$?"
        if [[ ${_ret} == 0 ]]; then
            printf "%s" "${_it}"
            return 0
        fi
    done

    return 1
}

# @description Iterates over elements from stdin, returning only those that are validated by a function.
#
# @arg $1 string (required) The validation function to call for each item.
#
# @stdin any The elements to iterate over, one per line.
#
# @stdout A list of all elements that successfully pass the validation function, one per line.
#
# @example
#   local array=("a" "1" "b" "2")
#   mapfile -t numbers < <(printf "%s\n" "${array[@]}" | _forEachFilter_ "_isNum_")
#   # numbers will contain ("1" "2")
#
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility)
_forEachFilter_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _func="${1}"
    local IFS=$'\n'
    while read -r _it; do
        if [[ ${_func} == *"$"* ]]; then
            eval "${_func}"
        else
            eval "${_func}" "'${_it}'"
        fi
        declare -i _ret="$?"
        if [[ ${_ret} == 0 ]]; then
            printf "%s\n" "${_it}"
        fi
    done
}

# @description The opposite of `_forEachFilter_`. Iterates over elements, returning only those that are NOT validated by a function.
#
# @arg $1 string (required) The validation function to call for each item.
#
# @stdin any The elements to iterate over, one per line.
#
# @stdout A list of all elements that fail the validation function, one per line.
#
# @example
#   local array=("a" "1" "b" "2")
#   mapfile -t letters < <(printf "%s\n" "${array[@]}" | _forEachReject_ "_isNum_")
#   # letters will contain ("a" "b")
#
# @see _forEachFilter_()
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility)
_forEachReject_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _func="${1}"
    local IFS=$'\n'
    while read -r _it; do
        if [[ ${_func} == *"$"* ]]; then
            eval "${_func}"
        else
            eval "${_func}" "'${_it}'"
        fi
        declare -i _ret=$?
        if [[ ${_ret} -ne 0 ]]; then
            printf "%s\n" "${_it}"
        fi
    done
}

# @description Iterates over elements from stdin, returning successfully if any element validates as true.
#
# @arg $1 string (required) The validation function to call for each item.
#
# @stdin any The elements to iterate over, one per line.
#
# @exitcode 0 If at least one element passes validation.
# @exitcode 1 If no elements pass validation.
#
# @example
#   local array=("a" "b" "c")
#   if printf "%s\n" "${array[@]}" | _forEachSome_ "_isNum_"; then
#     echo "Array contains a number."
#   else
#     echo "Array does not contain a number."
#   fi
#
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility)
_forEachSome_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"
    local _func="${1}"
    local IFS=$'\n'
    while read -r _it; do

        if [[ ${_func} == *"$"* ]]; then
            eval "${_func}"
        else
            eval "${_func}" "'${_it}'"
        fi

        declare -i _ret=$?
        if [[ ${_ret} -eq 0 ]]; then
            return 0
        fi
    done

    return 1
}

# @description Determine if a value exists in an array. Supports case-insensitive matching.
#
# @option -i | -I Ignore case during the match.
#
# @arg $1 string (required) The value or regex pattern to search for.
# @arg $@ any (required) The array elements to search within.
#
# @exitcode 0 If the value is found in the array.
# @exitcode 1 If the value is not found.
#
# @example
#   local my_array=("apple" "banana" "ORANGE")
#   if _inArray_ "banana" "${my_array[@]}"; then echo "Found banana"; fi
#   if _inArray_ -i "orange" "${my_array[@]}"; then echo "Found orange (case-insensitive)"; fi
#
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility)
_inArray_() {
    [[ $# -lt 2 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local opt
    local OPTIND=1
    while getopts ":iI" opt; do
        case ${opt} in
        i | I)
            #shellcheck disable=SC2064
            trap '$(shopt -p nocasematch)' RETURN # reset nocasematch when function exits
            shopt -s nocasematch                  # Use case-insensitive regex
            ;;
        *) fatal "Unrecognized option '${1}' passed to ${FUNCNAME[0]}. Exiting." ;;
        esac
    done
    shift $((OPTIND - 1))

    local _array_item
    local _value="${1}"
    shift
    for _array_item in "$@"; do
        [[ ${_array_item} =~ ^${_value}$ ]] && return 0
    done
    return 1
}

# @description Checks if an array is empty.
#
# @arg $@ any The array elements to check.
#
# @exitcode 0 If the array is empty (no arguments passed).
# @exitcode 1 If the array is not empty.
#
# @example
#   local empty_array=()
#   local full_array=("a")
#   _isEmptyArray_ "${empty_array[@]}" # returns 0
#   _isEmptyArray_ "${full_array[@]}"  # returns 1
#
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility)
_isEmptyArray_() {
    [[ ${#@} -eq 0 ]]
}

# @description Joins array elements into a single string with a specified separator.
#
# @arg $1 string (required) The separator/delimiter to use.
# @arg $@ string (required) The elements to join.
#
# @stdout The joined string.
#
# @example
#   _joinArray_ "," "a" "b" "c" # -> a,b,c
#   local my_array=("var" "log" "app.log")
#   _joinArray_ "/" "${my_array[@]}" # -> var/log/app.log
#
# @see [Stack Overflow](http://stackoverflow.com/questions/1527049/bash-join-elements-of-an-array)
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility)
_joinArray_() {
    [[ $# -lt 2 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _delimiter="${1}"
    shift
    printf "%s" "${1}"
    shift
    printf "%s" "${@/#/${_delimiter}}"
}

# @description Merges two arrays together.
#
# @arg $1 string (required) The name of the first array variable (e.g., `"array1[@]"`).
# @arg $2 string (required) The name of the second array variable (e.g., `"array2[@]"`).
#
# @stdout The elements of both arrays combined, one per line.
#
# @note This function uses indirect expansion, so the array names must be passed as strings.
#
# @example
#   local arr1=("a" "b")
#   local arr2=("c" "d")
#   local merged
#   mapfile -t merged < <(_mergeArrays_ "arr1[@]" "arr2[@]")
#   # merged will contain ("a" "b" "c" "d")
#
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility)
_mergeArrays_() {
    [[ $# -ne 2 ]] && fatal 'Missing required argument to _mergeArrays_'
    declare -a _arr1=("${!1}")
    declare -a _arr2=("${!2}")
    declare _outputArray=("${_arr1[@]}" "${_arr2[@]}")
    printf "%s\n" "${_outputArray[@]}"
}

# @description Sorts an array in reverse alphabetical and numerical order (z-a, 9-0).
#
# @arg $@ any (required) The array elements to sort.
#
# @stdout The sorted elements, one per line.
#
# @example
#   local input=("c" "b" "4" "1" "2" "3" "a")
#   _reverseSortArray_ "${input[@]}"
#   # Output:
#   > c
#   > b
#   > a
#   > 4
#   > 3
#   > 2
#   > 1
#
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility)
_reverseSortArray_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"
    declare -a _array=("$@")
    declare -a _sortedArray
    local _sorted_output
    _sorted_output=$(printf '%s\n' "${_array[@]}" | sort -r)
    mapfile -t _sortedArray <<< "${_sorted_output}"
    printf "%s\n" "${_sortedArray[@]}"
}

# @description Selects a single random element from an array.
#
# @arg $@ any (required) The array elements to choose from.
#
# @stdout A single, randomly selected element from the input.
#
# @example
#   local fruits=("apple" "banana" "cherry")
#   local random_fruit=$(_randomArrayElement_ "${fruits[@]}")
#
# @see [pure-bash-bible](https://github.com/dylanaraps/pure-bash-bible)
_randomArrayElement_() {
    [[ $# == 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    declare -a _array
    local _array=("$@")
    printf '%s\n' "${_array[RANDOM % $#]}"
}

# @description Calculates the set difference, returning items that exist in the first array but not in the second.
#
# @arg $1 string (required) The name of the first array variable (e.g., `"array1[@]"`).
# @arg $2 string (required) The name of the second array variable (e.g., `"array2[@]"`).
#
# @stdout The elements present in the first array but not in the second, one per line.
# @exitcode 0 If a non-empty set difference is found.
# @exitcode 1 If the arrays are identical or the difference is empty.
#
# @note This function uses indirect expansion, so the array names must be passed as strings.
#
# @example
#   local A=("a" "b" "c")
#   local B=("b" "d")
#   mapfile -t C < <(_setDiff_ "A[@]" "B[@]")
#   # C will contain ("a" "c")
#
# @see [Stack Overflow](http://stackoverflow.com/a/1617303/142339)
_setDiff_() {
    [[ $# -lt 2 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"

    local _skip
    local _a
    local _b
    declare -a _setdiffA=("${!1}")
    declare -a _setdiffB=("${!2}")
    declare -a _setdiffC=()

    for _a in "${_setdiffA[@]}"; do
        _skip=0
        for _b in "${_setdiffB[@]}"; do
            if [[ ${_a} == "${_b}" ]]; then
                _skip=1
                break
            fi
        done
        [[ ${_skip} -eq 1 ]] || _setdiffC=("${_setdiffC[@]}" "${_a}")
    done

    if [[ ${#_setdiffC[@]} == 0 ]]; then
        return 1
    else
        printf "%s\n" "${_setdiffC[@]}"
    fi
}

# @description Sorts an array in standard alphabetical and numerical order (0-9, a-z).
#
# @arg $@ any (required) The array elements to sort.
#
# @stdout The sorted elements, one per line.
#
# @example
#   local input=("c" "b" "4" "1" "2" "3" "a")
#   _sortArray_ "${input[@]}"
#   # Output:
#   > 1
#   > 2
#   > 3
#   > 4
#   > a
#   > b
#   > c
#
# @see [labbots/bash-utility](https://github.com/labbots/bash-utility)
_sortArray_() {
    [[ $# -eq 0 ]] && fatal "Missing required argument to ${FUNCNAME[0]}"
    declare -a _array=("$@")
    declare -a _sortedArray
    local _sorted_output
    _sorted_output=$(printf '%s\n' "${_array[@]}" | sort)
    mapfile -t _sortedArray <<< "${_sorted_output}"
    printf "%s\n" "${_sortedArray[@]}"
}
