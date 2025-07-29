#!/usr/bin/env bash

source $(dirname $0)/../core/compver.sh

# 'ver1 ver2 expected'
test_cases=(
    '1.2.3-1 1.2.3 greater'
    '1.2.3 1.2.3-1 less'
    '1.2.3-1 1.2.3-1 equal'

    '4.20.206-2 4.19.206-2 greater'
    '4.19.206-2 4.20.206-2 less'
    '4.19.206-2 4.19.206-2 equal'

    '4.0-RC2 4.0-RC1 greater'
    '4.0-RC1 4.0-RC2 less'
    '4.0-RC1 4.0-RC1 equal'

    '3.002 3.003.3 less'
    '3.003.3 3.002 greater'
    '3.003.3 3.003.3 equal'

    '3.04.2b 3.04.3 less'
    '3.04.3 3.04.2b greater'
    '3.04.2b 3.04.2b equal'
)

for test_case in "${test_cases[@]}"; do
    given=($test_case)
    version1=${given[0]}
    version2=${given[1]}
    expected=${given[2]}
    received=$(compver $version1 with $version2)
    [[ $received == $expected ]] && echo -n "[SUCCESS] " || echo -n "[FAILURE] "
    echo "compver $version1 with $version2: $received == $expected ?"
done
