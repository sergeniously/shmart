#!/bin/bash

source ../argue.sh

argue optional "-h|--help|help" do 'echo Options:' \
    as 'Print this usage' -- $@
argue required --name of STRING to name ~ "[a-zA-Z_\\-]{3,16}" \
    as 'What is your name?' -- $@
argue required --age of NUMBER to age ~ "[0-9]{1,3}" \
    as 'How old are you?' -- $@
argue optional --gender to gender ~ "(male|female)" or 'unknown' \
    as 'How do you identify yourself?' -- $@
argue optional --happy to happy = yes or no \
    as 'Are you happy?' -- $@
[[ $? -eq 202 ]] && exit

echo "Name: $name"
echo "Age: $age"
echo "Gender: $gender"
echo "Happy: $happy"
