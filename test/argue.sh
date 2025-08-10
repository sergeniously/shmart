#!/usr/bin/env bash

srcdir=$(dirname $(readlink -f $0))
source $srcdir/../core/argue.sh

about() {
	echo 'Demonstration script for argue module.'
	echo -e "\ua9 Belenkov Sergey, 2025."
}

date2secs() {
	local seconds
	if ! seconds=$(date +%s --date ${1:6}-${1:3:2}-${1:0:2} 2> /dev/null); then
		if ! seconds=$(date -j -f %d.%m.%Y +%s $1 2> /dev/null); then
			echo 0; return 1
		fi
	fi
	echo $seconds
}

check_date() {
	local date="$1"
	# normalize date
	if ((${#date} == 8)); then
		date="${date:0:2}.${date:2:2}.${date:4:4}"
	fi
	if ! date2secs $date &> /dev/null; then
		echo "impossible date"; return 1
	else
		echo $date
	fi
}

compute_age() {
	if [[ $birthday && $birthday != unknown ]]; then
		local seconds=$(date2secs $birthday)
		echo $((($EPOCHSECONDS - $seconds) / 31557600))
	else echo unknown
	fi
}

offer_languages() {
	local most_spoken_languages=(
		russian english mandarin hindi
		spanish french arabic bengali
		portuguese indonesian
	)
	compgen -S ' ' -W "${most_spoken_languages[*]}" $1
}

argue initiate "$@"
argue terminal //
argue defaults offer guide usage input setup
argue required -username="[[:alnum:]._]+" ? '<3..16>' of USERNAME at username \
	as 'Make up a username'
argue optional -password=.+ ? '<6..32>' of PASSWORD at password \
	as 'Make up a password'
argue optional -realname="[[:alnum:]\ -]+" ? '<3..32>' of STRING at realname or "${username-@USERNAME}" \
	as 'What is your real name?'
argue optional -birthday="[0-9.]{8,10}" ? '(check_date {})' or unknown of DD.MM.YYYY at birthday \
	as 'When were you born?'
argue optional -language=[a-z]+ ... or "${LANG:0:2}" or unknown of LANGUAGE at languages[] @ offer_languages \
	as 'Which languages do you speak?'
argue optional -telephone=.+ of NUMBER at telephone ? '|+7(DDD)DDDDDDD|' or unknown \
	as 'What is your telephone number?'
argue optional -sex="(male|female)" of GENDER or unknown at gender \
	as 'How do you identify yourself?'
argue optional -age=[0-9]+ ? [1..100] or $(compute_age) of years at age = '{} y.o.' \
	as 'How old are you?'
argue optional -height=[0-9]+ ? '[50..300]' of centimeters at height = '{} cm' \
	as 'How long is your body?'
argue optional -weight=[0-9]+ ? '[30..200]' of kilograms at weight = '{} kg' \
	as 'How heavy is your body?'

argue optional -like-books at interests[] = books \
	as 'Do you like reading books?'
argue optional -like-games at interests[] = games \
	as 'Do you like playing games?'
argue optional -like-music at interests[] = music \
	as 'Do you like listening music?'

argue optional -show-password at show_password = true or false \
	as 'Do you wanna see password?'
argue optional -show-platform do 'uname -s -m' \
	as 'Do you wanna see platform?'
argue optional -show-datetime do date \
	as 'Do you wanna see datetime?'

argue optional -numbers ? /[0-9]+/ of VALUE ... or 0 at numbers[] \
	as 'Specify some numbers'
argue optional -D"([A-Z]+)" ... of OPTION at options[] \
	as 'Specify some options'
argue optional // ? /.+/ of COMMENTS ... or 'no comment' at comments[] \
	as 'Specify any comments'
argue finalize

printf "%12s: %s\n" \
	'Your profile' '' \
	'Username' "$username" \
	'Password' "$($show_password && echo "$password" || echo "${password//?/*}")" \
	'Birthday' "$birthday ($age)" \
	'Real name' "$realname" \
	'Languages' "${languages[*]}" \
	'Telephone' "$telephone" \
	'Gender' "$gender" \
	'Height' "${height:-unknown}" \
	'Weight' "${weight:-unknown}" \
	'Interests' "${interests[*]:-unknown}" \
	'Numbers' "${numbers[*]:-nothing}" \
	'Options' "${options[*]:-nothing}" \
	'Comment' "${comments[*]:-nothing}" \
	'End' '.'
