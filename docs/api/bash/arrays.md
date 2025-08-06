# arrays.bash

A utility library for common array manipulations in Bash.

## Overview

This script provides a collection of portable and robust functions for
working with Bash arrays. It includes functions for sorting, filtering,
joining, de-duplicating, and iterating over array elements.

Many functions leverage standard input (stdin) for receiving array elements,
allowing for flexible use with pipelines.

## Index

* [`_dedupeArray_`](#dedupearray)
* [`_forEachDo_`](#foreachdo)
* [`_forEachValidate_`](#foreachvalidate)
* [`_forEachFind_`](#foreachfind)
* [`_forEachFilter_`](#foreachfilter)
* [`_forEachReject_`](#foreachreject)
* [`_forEachSome_`](#foreachsome)
* [`_inArray_`](#inarray)
* [`_isEmptyArray_`](#isemptyarray)
* [`_joinArray_`](#joinarray)
* [`_mergeArrays_`](#mergearrays)
* [`_reverseSortArray_`](#reversesortarray)
* [`_randomArrayElement_`](#randomarrayelement)
* [`_setDiff_`](#setdiff)
* [`_sortArray_`](#sortarray)

### `_dedupeArray_` {#dedupearray}

Removes duplicate elements from an array.
Maintains the order of the first occurrence of each unique element.

#### Example

```bash
local my_array=("a" "c" "b" "a" "c")
local new_array
mapfile -t new_array < <(_dedupeArray_ "${my_array[@]}")
# new_array will contain ("a" "c" "b")
```

#### Arguments

- **...** (\any): (required) The input array elements to be de-duplicated.

#### Output on stdout

- Prints the unique elements, one per line.

#### See also

- [pure-bash-bible](https://github.com/dylanaraps/pure-bash-bible)

### `_forEachDo_` {#foreachdo}

Iterates over elements from stdin and executes a callback function for each one.

#### Example

```bash
test_func() { echo "Processing: $1"; }
printf "%s\n" "apple" "banana" | _forEachDo_ "test_func"
```

#### Arguments

- **\$1** (string): (required) The name of the function to execute for each item.

#### Exit codes

- **0**: On full successful iteration.
- N The exit code of the first failing command from the callback function.

#### Input on stdin

- any The elements to iterate over, one per line.

#### Output on stdout

- The combined output of all commands executed by the callback function.

#### See also

- [labbots/bash-utility](https://github.com/labbots/bash-utility)

### `_forEachValidate_` {#foreachvalidate}

Iterates over elements from stdin, passing each to a validation function.
The iteration stops as soon as any element fails validation.

#### Example

```bash
# Assuming _isNum_ is a function that checks if input is numeric.
printf "1\n2\n3\n" | _forEachValidate_ "_isNum_" # returns 0
printf "1\n_a_\n3\n" | _forEachValidate_ "_isNum_" # returns 1
```

#### Arguments

- **\$1** (string): (required) The validation function to call for each item.

#### Exit codes

- **0**: If all elements are successfully validated.
- **1**: If any element fails validation.

#### Input on stdin

- any The elements to iterate over, one per line.

#### See also

- [labbots/bash-utility](https://github.com/labbots/bash-utility)

### `_forEachFind_` {#foreachfind}

Iterates over elements from stdin, returning the first value that is validated by a function.

#### Example

```bash
local array=("a" "b" "3" "d")
first_num=$(printf "%s\n" "${array[@]}" | _forEachFind_ "_isNum_")
# first_num will be "3"
```

#### Arguments

- **\$1** (string): (required) The validation function to call for each item.

#### Exit codes

- **0**: If a matching element is found.
- **1**: If no element matches the validation.

#### Input on stdin

- any The elements to iterate over, one per line.

#### Output on stdout

- The first element that successfully passes the validation function.

#### See also

- [labbots/bash-utility](https://github.com/labbots/bash-utility)

### `_forEachFilter_` {#foreachfilter}

Iterates over elements from stdin, returning only those that are validated by a function.

#### Example

```bash
local array=("a" "1" "b" "2")
mapfile -t numbers < <(printf "%s\n" "${array[@]}" | _forEachFilter_ "_isNum_")
# numbers will contain ("1" "2")
```

#### Arguments

- **\$1** (string): (required) The validation function to call for each item.

#### Input on stdin

- any The elements to iterate over, one per line.

#### Output on stdout

- A list of all elements that successfully pass the validation function, one per line.

#### See also

- [labbots/bash-utility](https://github.com/labbots/bash-utility)

### `_forEachReject_` {#foreachreject}

The opposite of `_forEachFilter_`. Iterates over elements, returning only those that are NOT validated by a function.

#### Example

```bash
local array=("a" "1" "b" "2")
mapfile -t letters < <(printf "%s\n" "${array[@]}" | _forEachReject_ "_isNum_")
# letters will contain ("a" "b")
```

#### Arguments

- **\$1** (string): (required) The validation function to call for each item.

#### Input on stdin

- any The elements to iterate over, one per line.

#### Output on stdout

- A list of all elements that fail the validation function, one per line.

#### See also

- [`_forEachFilter_()`](#foreachfilter)
- [labbots/bash-utility](https://github.com/labbots/bash-utility)

### `_forEachSome_` {#foreachsome}

Iterates over elements from stdin, returning successfully if any element validates as true.

#### Example

```bash
local array=("a" "b" "c")
if printf "%s\n" "${array[@]}" | _forEachSome_ "_isNum_"; then
  echo "Array contains a number."
else
  echo "Array does not contain a number."
fi
```

#### Arguments

- **\$1** (string): (required) The validation function to call for each item.

#### Exit codes

- **0**: If at least one element passes validation.
- **1**: If no elements pass validation.

#### Input on stdin

- any The elements to iterate over, one per line.

#### See also

- [labbots/bash-utility](https://github.com/labbots/bash-utility)

### `_inArray_` {#inarray}

Determine if a value exists in an array. Supports case-insensitive matching.

#### Example

```bash
local my_array=("apple" "banana" "ORANGE")
if _inArray_ "banana" "${my_array[@]}"; then echo "Found banana"; fi
if _inArray_ -i "orange" "${my_array[@]}"; then echo "Found orange (case-insensitive)"; fi
```

#### Options

* **-i** | **-I**

  Ignore case during the match.

#### Arguments

- **\$1** (string): (required) The value or regex pattern to search for.
- **...** (\any): (required) The array elements to search within.

#### Exit codes

- **0**: If the value is found in the array.
- **1**: If the value is not found.

#### See also

- [labbots/bash-utility](https://github.com/labbots/bash-utility)

### `_isEmptyArray_` {#isemptyarray}

Checks if an array is empty.

#### Example

```bash
local empty_array=()
local full_array=("a")
_isEmptyArray_ "${empty_array[@]}" # returns 0
_isEmptyArray_ "${full_array[@]}"  # returns 1
```

#### Arguments

- **...** (\any): The array elements to check.

#### Exit codes

- **0**: If the array is empty (no arguments passed).
- **1**: If the array is not empty.

#### See also

- [labbots/bash-utility](https://github.com/labbots/bash-utility)

### `_joinArray_` {#joinarray}

Joins array elements into a single string with a specified separator.

#### Example

```bash
_joinArray_ "," "a" "b" "c" # -> a,b,c
local my_array=("var" "log" "app.log")
_joinArray_ "/" "${my_array[@]}" # -> var/log/app.log
```

#### Arguments

- **\$1** (string): (required) The separator/delimiter to use.
- **...** (\string): (required) The elements to join.

#### Output on stdout

- The joined string.

#### See also

- [Stack Overflow](http://stackoverflow.com/questions/1527049/bash-join-elements-of-an-array)
- [labbots/bash-utility](https://github.com/labbots/bash-utility)

### `_mergeArrays_` {#mergearrays}

Merges two arrays together.

#### Example

```bash
local arr1=("a" "b")
local arr2=("c" "d")
local merged
mapfile -t merged < <(_mergeArrays_ "arr1[@]" "arr2[@]")
# merged will contain ("a" "b" "c" "d")
```

#### Arguments

- **\$1** (string): (required) The name of the first array variable (e.g., `"array1[@]"`).
- **\$2** (string): (required) The name of the second array variable (e.g., `"array2[@]"`).

#### Output on stdout

- The elements of both arrays combined, one per line.

#### See also

- [labbots/bash-utility](https://github.com/labbots/bash-utility)

### `_reverseSortArray_` {#reversesortarray}

Sorts an array in reverse alphabetical and numerical order (z-a, 9-0).

#### Example

```bash
local input=("c" "b" "4" "1" "2" "3" "a")
_reverseSortArray_ "${input[@]}"
# Output:
# c
# b
# a
# 4
# 3
# 2
# 1
```

#### Arguments

- **...** (\any): (required) The array elements to sort.

#### Output on stdout

- The sorted elements, one per line.

#### See also

- [labbots/bash-utility](https://github.com/labbots/bash-utility)

### `_randomArrayElement_` {#randomarrayelement}

Selects a single random element from an array.

#### Example

```bash
local fruits=("apple" "banana" "cherry")
local random_fruit=$(_randomArrayElement_ "${fruits[@]}")
```

#### Arguments

- **...** (\any): (required) The array elements to choose from.

#### Output on stdout

- A single, randomly selected element from the input.

#### See also

- [pure-bash-bible](https://github.com/dylanaraps/pure-bash-bible)

### `_setDiff_` {#setdiff}

Calculates the set difference, returning items that exist in the first array but not in the second.

#### Example

```bash
local A=("a" "b" "c")
local B=("b" "d")
mapfile -t C < <(_setDiff_ "A[@]" "B[@]")
# C will contain ("a" "c")
```

#### Arguments

- **\$1** (string): (required) The name of the first array variable (e.g., `"array1[@]"`).
- **\$2** (string): (required) The name of the second array variable (e.g., `"array2[@]"`).

#### Exit codes

- **0**: If a non-empty set difference is found.
- **1**: If the arrays are identical or the difference is empty.

#### Output on stdout

- The elements present in the first array but not in the second, one per line.

#### See also

- [Stack Overflow](http://stackoverflow.com/a/1617303/142339)

### `_sortArray_` {#sortarray}

Sorts an array in standard alphabetical and numerical order (0-9, a-z).

#### Example

```bash
local input=("c" "b" "4" "1" "2" "3" "a")
_sortArray_ "${input[@]}"
# Output:
# 1
# 2
# 3
# 4
# a
# b
# c
```

#### Arguments

- **...** (\any): (required) The array elements to sort.

#### Output on stdout

- The sorted elements, one per line.

#### See also

- [labbots/bash-utility](https://github.com/labbots/bash-utility)

