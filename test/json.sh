#!/usr/bin/env bash

source $(dirname ${0})/../core/log.sh
source $(dirname ${0})/../core/json.sh

json_print() {
	local color
	case $1 in
		string) color=red;;
		number) color=yellow;;
		keyword) color=purple;;
	esac
	if [[ $1 == string ]]; then
		log $1 %clr:bold,blue "$2" = %clr:bold,$color "\"$3\""
	else
		log $1 %clr:bold,blue "$2" = %clr:bold,$color "$3"
	fi
}

if [[ "$#" -eq 0 ]]; then
	JSON_SAVE=json_print
	LOG_TITLE=false
fi

if ! json parse; then
	json error
	exit 1
fi

if [[ "$#" -gt 0 ]]; then
	json value "$@"
fi
