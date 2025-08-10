#!/usr/bin/env bash

srcdir=$(dirname $(readlink -f $0))
source $srcdir/core/argue.sh
source $srcdir/core/log.sh

about() {
cat << HELP
Translate empty messages in Gettext (*.po) or Qt (*.ts) translation files using external translator.
Mark translated messages with fuzzy or unfinished lable to make them easy to find and review.
Author: Belenkov Sergei, 2025.07, https://github.com/sergeniously/shmart
TODO:
 + Support Qt TS plural (numerus) messages.

HELP
}

offer_files() {
	local file
	while read file; do
		if [[ -d $file ]]; then
			echo "$file/"
		elif [[ $file =~ \.(po|ts)$ ]]; then
			echo "$file "
		fi
	done < <(compgen -f $1)
}

offer_translators() {
	local variant=${1//["'\""]}
	local translator translators=(
		'translight --stdin --language={LANG}'
		'trans --brief en:{LANG}'
	)
	for translator in "${translators[@]}"; do
		if [[ $translator =~ ^$variant && $(which ${translator%% *}) ]]; then
			echo "\"$translator\" "
		fi
	done
}

default_translator() {
	local translators=()
	readarray -t translators < <(offer_translators)
	echo ${translators[0]//["'\""]}
}

argue initiate "$@"
argue defaults offer guide usage setup
argue required -input=".+\.(po|ts)" of FILE at input_file ? '(readlink -ve {})' @ offer_files \
	as 'Input PO or TS file to read messages'
argue optional -output=".+\.(po|ts)" of FILE at output_file ? '(readlink -vf {})' or "${input_file:-@INPUT}" @ offer_files \
	as 'Output PO or TS file to write messages (if not specified, the input file is used)'
argue optional -stdout at output_file = /dev/stdout \
	as 'Use standard output to write messages'
argue optional -translator=.+ of COMMAND or "$(default_translator)" at translator @ offer_translators \
	as 'Command to translate message from stdin (with {LANG} substitution)'
argue optional -no-fuzzy,-no-unfinished at do_fuzzy = false or true \
	as 'Do not mark modified messages with fuzzy or unfinished label'
argue optional -quite,-silent at LOG_LEVEL = 1 or 4 \
	as 'Do not output modifications logs'
argue optional -verbose at LOG_TITLE = true or false \
	as 'Print detailed information'
argue optional -debug at LOG_LEVEL = 5 \
	as 'Print debug infomration'
argue finalize

if [[ $output_file =~ ^/dev/ ]]; then
	LOG_LEVEL=1
fi
target_file=$output_file
if [[ $output_file == $input_file ]]; then
	if ! target_file=$(mktemp -q $output_file.XXX); then
		log error "Failed to create a temporary file"
	fi
fi

parse_po() {
	if [[ $1 =~ ^"#"(.*)$ ]]; then
		log debug "Parsed PO comment: $1"
		COMMENTS+=("${BASH_REMATCH[1]}")
	elif [[ $1 =~ ^msg(ctxt|id|id_plural|str(\[[0-9]+\])?)[\ \t]+\"(.*)\"$ ]]; then
		MEANINGS+=("${BASH_REMATCH[1]}")
		MESSAGES[${MEANINGS[@]: -1}]+="${BASH_REMATCH[3]}"
		log debug "Parsed initial PO message: ${MEANINGS[@]: -1}: ${BASH_REMATCH[3]}"
	elif [[ $1 =~ \"(.+)\" && ${MEANINGS[@]} ]]; then
		MESSAGES[${MEANINGS[@]: -1}]+="${BASH_REMATCH[1]}"
		log debug "Parsed partial PO message: ${MEANINGS[@]: -1}: ${BASH_REMATCH[1]}"
		if [[ ${MEANINGS[@]: -1} == str && ${MESSAGES[id]} == '' ]]; then
			if [[ ${BASH_REMATCH[1]} =~ ^Language:[\ \t]*([a-z]{2}) ]]; then
				set_language ${BASH_REMATCH[1]}
			fi
		fi
	elif [[ ${#MEANINGS[@]} -gt 0 ]]; then
		return 2
	else
		return 1
	fi
	# consume
	return 0
}

fuzzy_po() {
	local label=', fuzzy'
	if [[ ${#COMMENTS[@]} -gt 0 ]]; then
		COMMENTS[-1]="${label}${COMMENTS[-1]//$label}"
	else
		COMMENTS+=("$label")
	fi
}

write_po() {
	local messages=() message
	local comment meaning counter

	for comment in "${COMMENTS[@]}"; do
		echo "#$comment"
	done
	for meaning in "${MEANINGS[@]}"; do
		if [[ ${MESSAGES[$meaning]+x} ]]; then
			IFS=$'\n' read -d '' -a messages < <(echo "${MESSAGES[$meaning]//\\n/\\\\n$'\n'}")
			if [[ ${#messages[@]} -gt 1 ]]; then
				echo "msg${meaning} \"\""
				for message in "${messages[@]}"; do
					echo "\"$message\""
				done
			else
				echo msg${meaning} \"${messages[*]}\"
			fi
		fi
	done
	echo
}

parse_ts() {
	if [[ $1 =~ \<TS(.+)\> ]]; then
		if eval "${BASH_REMATCH[1]}" && [[ $language ]]; then
			set_language $language
			return 1
		fi
	elif [[ $1 =~ ^[\ \t]*\<(source|translation)([^\>]*)\>(.*)$ ]]; then
		TSINDENT=${1%%<*}
		local meaning=${BASH_REMATCH[1]}; MEANINGS+=($meaning)
		local comment=${BASH_REMATCH[2]}; COMMENTS+=("$comment")
		local message=${BASH_REMATCH[3]%</*}; MESSAGES[$meaning]=$message
		if [[ ${BASH_REMATCH[3]} == *"</$meaning>"* ]]; then
			log debug "Match oneline TS message: <$meaning$comment>: '$message'"
			if [[ $meaning == translation ]]; then
				log debug "Extract TS message: '${MESSAGES[source]}' => '${MESSAGES[translation]}'"
				return 2 # ready to be processed
			fi
		else
			log debug "Match opening TS message: <$meaning$comment>: '$message'"
			MESSAGES[$meaning]+="\n"
		fi
	elif [[ $1 =~ ^(.*)\</(source|translation)\> ]]; then
		log debug "Match closing TS message: <${BASH_REMATCH[2]}>: '${BASH_REMATCH[1]}'"
		MESSAGES[${BASH_REMATCH[2]}]+="${BASH_REMATCH[1]}"
		if [[ ${BASH_REMATCH[2]} == translation ]]; then
			log debug "Extract TS message: '${MESSAGES[source]}' => '${MESSAGES[translation]}'"
			return 2 # ready to be processed
		fi
	elif [[ ${#MEANINGS[@]} -gt 0 ]]; then
		log debug "Match partial TS message: <${MEANINGS[-1]}>: '$1'"
		MESSAGES[${MEANINGS[-1]}]+="$1\n"
	else # ignore
		return 1
	fi
	return 0
}

fuzzy_ts() {
	local label="type=\"unfinished\""
	if [[ ${#COMMENTS[@]} -eq 2 ]]; then
		COMMENTS[1]="${label} ${COMMENTS[1]//$label}"
	fi
}

write_ts() {
	for ((i = 0; i < 2; ++i)); do
		local meaning=${MEANINGS[$i]}
		local attributes=($meaning ${COMMENTS[$i]})
		echo "$TSINDENT<${attributes[*]}>${MESSAGES[$meaning]//\\n/$'\n'}</$meaning>"
	done
}

set_language() {
	translator=${translator//\{LANG\}/$1}
	log info "Use translator: $translator"
}

translate_messages() {
	local counter=0 meaning
	for meaning in "${MEANINGS[@]}"; do
		if [[ $meaning =~ ^(id|source)$ ]]; then
			local message=${MESSAGES[$meaning]}
			continue
		elif [[ ${MESSAGES[$meaning]} ]]; then
			continue
		fi
		local translation=''
		if [[ $translator && $message ]]; then
			#translation="Translated<$message>" # DEBUG
			translation=$(echo "${message//\\n/<n>}" | $translator); translation=${translation//<n>/\\n}
			log notice "$input_file:$line_number: translate message '${message//\\n/\\\\n}' => '${translation//\\n/\\\\n}'"
			MESSAGES[$meaning]="$translation"
			((++counter))
		elif false; then # TODO: do_echo
			MESSAGES[$meaning]="$message"
			((++counter))
		fi
	done
	((counter))
}

#
# parsing
#
declare -a COMMENTS
declare -a MEANINGS
declare -A MESSAGES
TYPE=${input_file: -2}

# clear target file
echo -n > $target_file
while IFS= read -r line; do
	(( ++line_number ))

	parse_$TYPE "$line"
	case $? in
		0) continue;;
		2) if [[ $? -eq 2 ]]; then
				if translate_messages && $do_fuzzy; then
					fuzzy_$TYPE
				fi
				write_$TYPE >> $target_file
				COMMENTS=()
				MESSAGES=()
				MEANINGS=()
				continue
			fi;;
	esac
	echo "$line" >> $target_file

done < <(cat $input_file)

if [[ $target_file != $output_file ]]; then
	if [[ $(log_count notice) -gt 0 ]]; then
		mv -f $target_file $output_file
	else
		rm -f $target_file
	fi
fi

log info $(log_count notice) "modification(s) have been made in ${output_file}."
