#!/bin/bash

source $(dirname $0)/../argue.sh

about() {
	echo 'About: a demonstration script for argue function'
	echo -e "Right: \ua9 Sergeniously, 2021."
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
	local seconds
	if seconds=$(date +%s --date ${1:6}-${1:3:2}-${1:0:2} 2> /dev/null); then
		echo '~' $(( ($(date +%s) - $seconds) / (86400*365) )) y.o.
	else
		echo unknown
	fi
}

argue initiate "$@"
argue internal offer of offer                             // Display auto completion
argue internal guide,help,-h,--help,\\? of guide do about // Print this guide
argue internal usage of usage                             // Print short usage
argue internal complement do argue-setup	              // Install bash completion
argue required --username of USERNAME to username ~ "[a-zA-Z0-9_]{3,16}" \
	as 'Make up a username'
argue required --password of PASSWORD to password ~ ".{6,32}" \
	as 'Make up a password'
argue required --birthdate of DDMMYYYY to birthdate \
	? "/[0-9]{2}[ ./-]?[0-9]{2}[ ./-]?[1-9]{4}/" ? '(check-date {})' \
	as 'When were you born?'
argue required --language ... of LANGUAGE to languages[] ~ "[a-z]+" \
	as 'Which languages do you speak?'
argue optional --realname of STRING to realname ~ "[[:alnum:]\ ]{3,32}" or "${username-@USERNAME}" \
	as 'What is your real name?'
argue optional --gender to gender of GENDER ? "{male,female}" or unknown \
	as 'How do you identify yourself?'
argue optional --telephone of NUMBER to telephone ? '|+7(DDD)DDDDDDD|' or unknown \
	as 'What is your telephone number?'
argue optional --height of centimeters to height ? '[50..300]' \
	as 'How long is your body?'
argue optional --weight of kilograms to weight ? '[30..200]' \
	as 'How heavy are you?'
argue optional --like-books to interests[] = books \
	as 'Do you like reading books?'
argue optional --like-games to interests[] = games \
	as 'Do you like playing games?'
argue optional --like-music to interests[] = music \
	as 'Do you like listening music?'
argue optional --show-password to show_password = true or false \
	as 'Do you wanna see password?'
argue optional --show-platform do 'uname -s -m' \
	as 'Do you wanna see platform?'
argue optional --show-datetime do date \
	as 'Do you wanna see datetime?'
argue finalize

echo
echo "Check your profile"
printf "%10s: %s\n" \
	'Username' "$username" \
	'Password' "$($show_password && echo "$password" || echo "${password//?/*}")" \
	'Real name' "$realname" \
	'Gender' "$gender" \
	'Birthdate' "$birthdate" \
	'Age' "$(age "$birthdate")" \
	'Telephone' "$telephone" \
	'Height' "${height:-unknown}${height:+ cm}" \
	'Weight' "${weight:-unknown}${weight:+ kg}" \
	'Languages' "${languages[*]}" \
	'Interests' "${interests[*]:-none}"
