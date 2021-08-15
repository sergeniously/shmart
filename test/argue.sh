#!/bin/bash

source $(dirname $0)/../argue.sh

usage() {
    echo 'About: test script for argue function'
    echo "Usage: $(basename $0) [options]"
    echo " * run without options to input them"
    echo 'Options:'
}

argue optional "-h|--help|help" do usage \
	as 'Print this usage' -- $@
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
argue required --language... of LANGUAGE to languages[] ~ "[a-z]+" \
	as 'Which languages do you speak?' -- $@
argue optional --books to interests[] = books \
	as 'Do you like reading books?' -- $@
argue optional --music to interests[] = music \
	as 'Do you like listening music?' -- $@
[[ $? -eq 202 ]] && exit

echo
echo "Your registration info"
printf "%10s: %s\n" \
	'Username' "$username" \
	'Password' "$([[ $show_password == yes ]] && echo "$password" || echo "${password//?/*}")" \
	'Real name' "$realname" \
	'Age' "$age" \
	'Gender' "$gender" \
	"Languages" "${languages[*]}" \
    "Interests" "${interests[*]}"
