#!/bin/bash

source $(dirname $0)/../argue.sh

guide() {
    echo 'About: test script for argue function'
    echo "Usage: $(basename $0) [options] # run without options to input"
    echo 'Guide:'
}

check-date() {
	date +%s --date ${1:6}-${1:3:2}-${1:0:2}
}

argue internal "-h|--help|help|guide|sos|how|\?" of guide do guide \
	as 'Print this guide' -- "$@"
argue internal "--usage|usage" of usage \
	as 'Print short usage' -- "$@"
argue required --username of USERNAME to username ~ "[a-zA-Z0-9_]{3,16}" \
	as 'Make up a username' -- "$@"
argue required --password of PASSWORD to password ~ ".{6,32}" \
	as 'Make up a password' -- "$@"
argue optional --realname of STRING to realname ~ "[[:alnum:]\ ]{3,32}" or "$username" \
	as 'What is your real name?' -- "$@"
argue required --birthdate of DD.MM.YYYY to birthdate ~ "[0-9]{2}[ ./-]?[0-9]{2}[ ./-]?[1-9]{4}" ? 'check-date {}' \
	as 'When were you born?' -- "$@"
argue optional --gender to gender ~ "(male|female)" or 'unknown' \
	as 'How do you identify yourself?' -- "$@"
argue required "--lang|--language" ... of LANGUAGE to languages[] ~ "[a-z]+" \
	as 'Which languages do you speak?' -- "$@"
argue optional --books to interests[] = books \
	as 'Do you like reading books?' -- "$@"
argue optional --music to interests[] = music \
	as 'Do you like listening music?' -- "$@"
argue optional --show-password to show_password = yes or no \
	as 'Do you wanna see password?' -- "$@"
argue optional --show-datetime do date \
	as 'Do you wanna see datetime?' -- "$@"
[[ $? -ge 200 ]] && echo && exit

# normalize birthdate
if (( ${#birthdate} == 8 )); then
	birthdate="${birthdate:0:2}.${birthdate:2:2}.${birthdate:4:4}"
fi

age() {
	if seconds=$(date +%s --date ${1:6}-${1:3:2}-${1:0:2} 2> /dev/null); then
		echo $(( ($(date +%s) - $seconds) / (86400*365) ))
	else
		echo unknown
	fi
}

echo
echo "Check your profile"
printf "%10s: %s\n" \
	'Username' "$username" \
	'Password' "$([[ $show_password == yes ]] && echo "$password" || echo "${password//?/*}")" \
	'Real name' "$realname" \
	'Birthdate' "$birthdate" \
	'Age' "~ $(age "$birthdate") y.o." \
	'Gender' "$gender" \
	"Languages" "${languages[*]}" \
	"Interests" "${interests[*]}"
