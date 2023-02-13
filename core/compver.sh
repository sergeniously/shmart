
# About:
#  compare any kinds of versions
#  * splits version strings to number arrays deleting non-digit characters
#  * checks numbers of one array against numbers of another array
#  * returns 0 if condition succeeds, otherwise 1
# Usage:
#  compver <ver1> <greater|less|equal|with> <ver2>
# Examples:
#  compare_version 4.20.206-2 greater 4.19.206-2 # return 0 (true)
#  compare_version 1.2.3-4 less 1.2.3 # return 1 (false)
#  compare_version 4.0-RC2 equal 4.0-RC1 # return 1 (false)
#  compare_version 3.04.2b with 3.04.3 # echo less
compver() {
    local left=(${1//[^[:digit:]]/ })
    local right=(${3//[^[:digit:]]/ })
    local comparison=$2 conclusion=equal
    local number count=$((${#left[@]} > ${#right[@]} ? ${#left[@]} : ${#right[@]}))
    for ((number = 0; number < count; number++)); do
        if [[ ${left[$number]} -gt ${right[$number]} ]]; then
            conclusion=greater; break
        elif [[ ${left[$number]} -lt ${right[$number]} ]]; then
            conclusion=less; break
        fi
    done
    [[ $comparison == with ]] && echo $conclusion || \
        test $conclusion == $comparison
}
