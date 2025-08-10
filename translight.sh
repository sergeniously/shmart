#!/usr/bin/env bash

srcdir=$(dirname $(readlink -f $0))
source $srcdir/core/argue.sh
source $srcdir/core/json.sh

about() {
	echo 'Translate somewhere selected text or particularly supplied text by Google Translate.'
	echo 'Optionally show translation as a system notification and save translated word to vocabulary file.'
	echo -e '\ua9 Belenkov Sergei, 2021-2025 <https://github.com/sergeniously/shmart>'
}

install() {
	if [[ $(command -v apt) ]]; then
		sudo apt install -y wget xsel libnotify-bin
	elif [[ $(command -v brew) ]]; then
		brew install wget xsel terminal-notifier
	fi
	if [[ $(command -v wget) ]]; then
		wget https://translate.google.ru/favicon.ico -O $icon_path
	fi
	exit $?
}

get_selection() {
	expression=$(xsel -o 2> /dev/null)
}

read_expression() {
	readarray -t expression
	expression=$(IFS=$'\n'; echo "${expression[*]}")
	return 0
}

directory=$HOME/.translight
icon_path=$directory/icon.ico
vocabulary=$directory/vocabulary.txt
mkdir -p $directory

argue initiate "$@"
argue defaults offer guide usage setup
argue internal install do install as 'Install dependencies'
argue optional -selection to get_selection if 'command -v xsel' ! 'required xsel' \
	as 'Translate selected expression'
argue optional -text,-expression=.+ of EXPRESSION at expression \
	as 'Translate supplied expression'
argue optional -stdin to read_expression \
	as 'Translate expression from stdin'
argue optional -context="(noun|verb|adverb|adjective|preposition)" at context \
	as 'Part of speech'
argue optional -language="[a-z]{2}" of LANGUAGE at language or ru \
	as 'Target language to translate'
argue optional -notify at do_notify = true or false \
	if 'command -v notify-send terminal-notifier' \
	! 'required notify-send or terminal-notifier' \
	as 'Show translation as a system notification?'
argue optional -memorize at do_memorize = true or false \
	as 'Memorize translated word to vocabulary?'
argue optional -format at do_format = true or false \
	as 'Consider an expression as a c-format string'
argue optional -verbose at do_verbose = true or false \
	as 'Show additional information'
argue finalize


if [[ -z $expression ]]; then
	echo "Nothing to translate" >&2
	exit 1
fi

notify() {
	local title message
	while (($#)); do case $1 in
		-title) title=$2; shift; shift;;
		-message) message=$2; shift; shift;;
	esac done
	if [[ $(command -v terminal-notifier) ]]; then
		terminal-notifier -contentImage "$icon_path" -title "$title" -message "$message" -sound default
	elif [[ $(command -v notify-send) ]]; then
		local read_speed=100 # ms per character
		local timeout=$((read_speed * ${#message}))
		notify-send --expire-time=$timeout --icon="$icon_path" "$title" "$message"
	fi
}

join() {
	local word=0 splitter=$1; shift
	while (($#)); do
		((word++ > 0)) && printf "$splitter"
		printf "$1"; shift
	done
}

# convert c-format strings into <HASH> strings (to avoid their translation)
encode_format() {
	local string=$1 format length number index
	while [[ $string =~ (%[0-9a-zA-Z.]+|(\\.)+) ]]; do
		format=${BASH_REMATCH[1]}; length=${#format}; number=''
		for ((index = 0; index < length; index++)); do
			number+=$(printf '%02X' "'${format:$index:1}")
		done
		string=${string/"$format"/[$number]}
	done
	echo -n "$string"
}

# restore c-format strings from <HASH> strings
decode_format() {
	local string=$1 format number length index
	while [[ $string =~ \[([0-9A-Fa-f]+)\] ]]; do
		number=${BASH_REMATCH[1]}; length=${#number}; format=''
		for ((index = 0; index < length; index += 2)); do
			format+=$(printf "\x${number:$index:2}")
		done
		string=${string/\[$number\]/"$format"}
	done
	echo -n "$string"
}

make_translate_api() {
	echo -n "http://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$language&dt=t&dt=qca&dt=bd&dj=1&q="
	$do_format && encode_format "$expression" || echo -n "$expression"
}

api=$(make_translate_api)
if ! response=$(wget -U "Mozilla/5.0" -qO - "$api" 2> /dev/null); then
	echo 'Cannot connect to Google Translate server' >&2
	exit 1
fi

if ! json parse < <(echo "$response"); then
	echo "$response" >&2
	json error
	exit 1
fi

readarray -t corrections < <(json value ".sentences[*].orig")
readarray -t translations < <(json value ".sentences[*].trans")

expression=${expression//$'\n'/\\n}
correction=$(IFS=''; echo "${corrections[*]}")
translation=$(IFS=''; echo "${translations[*]}")

declare -A dictionary; index=0
for part in $(json value ".dict[*].pos"); do
	readarray -t terms < <(json value ".dict[$index].terms[*]")
	dictionary[$part]=$(join ', ' "${terms[@]}")
	((++index))
done

if [[ $context && ${dictionary[$context]} ]]; then
	translation=${dictionary[$context]%%,*}
fi

if $do_format; then
	correction=$(decode_format "$correction")
	translation=$(decode_format "$translation")
fi

if $do_memorize && [[ $(echo "$correction" | wc -w) -eq 1 && ${#correction} -gt 2 ]]; then
	echo "${correction,,}: ${translation,,}" >> $vocabulary
	sort $vocabulary --unique --output=$vocabulary
fi

if $do_verbose; then
	echo "Expression: '${expression//\\n/ }'"
	if [[ $correction != "$expression" ]]; then
		echo "Did you mean: '${correction//\\n/ }'?"
	fi
	echo "Translation: '${translation//\\n/ }'"
	if [[ ${#dictionary[@]} -gt 0 ]]; then
		echo "Alternatives:"
		for part in ${!dictionary[@]}; do
			echo "  $part: [${dictionary[$part]}]"
		done
	fi
else
	echo -ne "$translation"
fi

if $do_notify; then
	if [[ ${#dictionary[@]} -gt 0 && ! $context ]]; then
		translation=$(join ', ' "${dictionary[@]%%,*}")
	fi
	[[ $expression != "$correction" ]] && correction="* $correction"
	notify -title "${correction//\\n/ }" -message "${translation//\\n/ }"
fi
