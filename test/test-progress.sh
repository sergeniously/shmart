#!/bin/bash

source $(dirname $0)/../progress.sh

timer=10
for (( sec=1; sec <= $timer; sec++ )); do
    progress in "sleeping" is $sec of $timer as '#' on 80
    sleep 1
done

progress in scanning is 50 of 100
echo
progress in watching is 70%
echo
progress in training is 7 of 13 as '*'
echo
