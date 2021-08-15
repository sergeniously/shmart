#!/bin/bash

source $(dirname $0)/../argue.sh

argue optional "-h|--help|help" do 'echo Options:' \
    as 'Print this usage' -- $@
argue required --language ... of LANGUAGE to languages ~ "[a-z]+" \
    as 'Which languages do you speak?' -- $@
argue optional --udp to protocols = UDP \
    as 'Use UDP protocol?' -- $@
argue optional --tcp to protocols = TCP \
    as 'Use TCP protocol?' -- $@
argue required --username of USERNAME to username ~ "[a-zA-Z0-9_]{3,16}" \
    as 'Make up a username' -- $@
argue required --password of PASSWORD to password ~ ".{6,32}" \
    as 'Make up a password' -- $@
argue optional --realname of STRING to realname ~ "[[:alnum:]\ ]{3,32}" or "$username" \
    as 'What is your real name?' -- $@
argue required --age of NUMBER to age ~ "[1-9][0-9]{0,2}" \
    as 'How old are you?' -- $@
argue optional --gender to gender ~ "(male|female)" or 'unknown' \
    as 'How do you identify yourself?' -- $@
argue optional --show-password to show_password = yes or no \
    as 'Do you wanna see password?' -- $@
[[ $? -eq 202 ]] && exit

echo
echo "Your registration info"
printf "%10s: %s\n" \
    'Username' $username \
    'Password' "$([[ $show_password == yes ]] && echo "$password" || echo "${password//?/*}")" \
    'Real name' "$realname" \
    'Age' $age \
    'Gender' $gender \
    'Languages' "${languages[*]}"
