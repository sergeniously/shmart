#!/bin/bash

# About:
#  input text in smart way supporting: password masking, value validation and default assignment
# Usage:
#  input [at @varname] [= @initial] [as @pattern [no @trouble]] [or @default] [by @masking] [// @comment]
# Where:
#  @varname: a name of variable to store the inputed value;
#  @initial: an initial string for the inputed value;
#  @pattern: a regular expression to validate the inputed value;
#  @trouble: a message to print if validation of the inputed value fails;
#  @default: a default value for variable in case the inputed value is empty;
#  @masking: a character to print instead of the inputed characters;
#  @comment: an output text to print before inputing;
# Examples:
#  input // 'Username: ' at username as "[a-z0-9]*" no 'invalid username' or anonym
#  input // 'Password: ' at password as ".{3,32}" by '*'
#  input // 'Somewhat: ' at somewhat = 'Hello!' or 'Hello!'

input() {
	local varname initial pattern
	local trouble default masking comment
	while (("$#")); do case $1 in
		at) varname=$2; shift 2;;
		 =) initial=$2; shift 2;;
		as) pattern=$2; shift 2;;
		no) trouble=$2; shift 2;;
		or) default=$2; shift 2;;
		by) masking=$2; shift 2;;
		//) comment=$2; shift 2;;
		*) shift;;
	esac done

	comment="$comment$([[ -n $masking ]] && echo "${initial//?/$masking}" || echo "$initial")"
	while echo -ne "$comment"; do
		local entered="$initial" snippet=''
		# FIX: there is a problem when <double/triple/or more> press of different keys occurs
		# read function (or somewhat else) prints overflown characters despite on -s option
		while read -p "$snippet" -rsn1 snippet && (( ${#snippet} )); do
			if [[ $snippet == $'\177' || $snippet == $'\010' ]]; then
				[[ -n $entered ]] && snippet=$'\b \b' || snippet=''
				entered=${entered%?} # remove the last char
				continue
			elif [[ $(printf '%d' "'$snippet") -lt 32 ]]; then
				# TODO: support left, right, home, end, delete keys
				# swallow control-character sequences
				read -rs -t 0.001; snippet=''
				continue
			fi
			entered="${entered}${snippet}"
			snippet="${masking:-$snippet}"
		done
		if [[ $? -eq 0 ]]; then
			if [[ -n $pattern && ! $entered =~ ^$pattern$ ]]; then
				echo "${entered:+ }# ${trouble-invalid value; expected: /$pattern/}!"
				continue
			else
				echo
				if [[ -n $varname ]]; then
					declare -g "$varname=${entered:-$default}"
				fi
			fi
		fi
		return $?
	done
}
