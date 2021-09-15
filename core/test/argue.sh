#!/bin/bash

source $(dirname $0)/../argue.sh

guide() {
    echo 'About: a demonstration script for argue function'
    echo "Usage: $(basename $0) [options] # run without options to input"
    echo 'Options:'
}

check-date() {
	local date="$1"
	# normalize date
	if (( ${#date} == 8 )); then
		date="${date:0:2}.${date:2:2}.${date:4:4}"
	fi
	if ! date +%s --date ${date:6}-${date:3:2}-${date:0:2} &> /dev/null; then
		echo "impossible date"; return 1
	else
		echo $date
	fi
}

age() {
	if seconds=$(date +%s --date ${1:6}-${1:3:2}-${1:0:2} 2> /dev/null); then
		echo $(( ($(date +%s) - $seconds) / (86400*365) ))
	else
		echo unknown
	fi
}

argue -- "$@"
argue internal offer of offer								// Display auto completion
argue internal "guide|help|-h|--help|\?" of guide do guide	// Print this guide
argue internal usage of usage								// Print short usage
argue internal setup do argue-setup							// Install auto completion
argue required --username of USERNAME to username ~ "[a-zA-Z0-9_]{3,16}" \
	as 'Make up a username'
argue required --password of PASSWORD to password ~ ".{6,32}" \
	as 'Make up a password'
argue optional --realname of STRING to realname ~ "[[:alnum:]\ ]{3,32}" or "${username-@USERNAME}" \
	as 'What is your real name?'
argue optional --gender to gender of GENDER ? "{male,female}" or unknown \
	as 'How do you identify yourself?'
argue required --birthdate of 'DD.MM.YYYY|DDMMYYYY' to birthdate \
	? "/[0-9]{2}[ ./-]?[0-9]{2}[ ./-]?[1-9]{4}/" ? '(check-date {})' \
	as 'When were you born?'
argue optional --height of centimeters to height ? '[50..300]' or unknown \
	as 'How long is your body?'
argue optional --weight of kilograms to weight ? '[30..200]' or unknown \
	as 'How heavy are you?'
argue required --language ... of LANGUAGE to languages[] ~ "[a-z]+" \
	as 'Which languages do you speak?'
argue optional --books to interests[] = books \
	as 'Do you like reading books?'
argue optional --music to interests[] = music \
	as 'Do you like listening music?'
argue optional --show-password to show_password = true or false \
	as 'Do you wanna see password?'
argue optional --show-datetime do date \
	as 'Do you wanna see datetime?'

case $? in
	100) argue %% 'There are unknown arguments: {}'; exit 1;;
	2??) echo; exit 0;;
esac

echo
echo "Check your profile"
printf "%10s: %s\n" \
	'Username' "$username" \
	'Password' "$($show_password && echo "$password" || echo "${password//?/*}")" \
	'Real name' "$realname" \
	'Gender' "$gender" \
	'Birthdate' "$birthdate" \
	'Age' "~ $(age "$birthdate") y.o." \
	'Height' "$height cm" \
	'Weight' "$weight kg" \
	'Languages' "${languages[*]}" \
	'Interests' "${interests[*]}"
