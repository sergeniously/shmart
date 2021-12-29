#!/bin/bash

# About:
#  input text in smart way supporting: password masking, value completion & validation and default assignment
# Usage:
#  input [at @varname] [= @initial] [as @pattern [! @trouble]] [no @exclude] \
#        [or @default] [by @masking] [of @suggest] [// @comment]
# Where:
#  @varname: a name of variable to store the inputed value;
#  @initial: an initial string for the inputed value;
#  @pattern: a regular expression to validate the inputed value;
#  @trouble: a message to print if validation of the inputed value fails;
#  @exclude: characters which are not allowed for input;
#  @default: a default value for variable in case the inputed value is empty;
#  @masking: a character to print instead of the inputed characters;
#  @suggest: a command to get completion variants for a value;
#  @comment: an output text to print before inputing;
# Examples:
#  input // 'Username: ' at username as "[a-z0-9]*" ! 'invalid username' or anonym
#  input // 'Password: ' at password as ".{3,32}" by '*'
#  input // 'Somewhat: ' at somewhat = 'Hello!' or 'Hello!' no "\'\""

input() {
	local varname initial pattern
	local trouble default masking
	local exclude suggest comment
	while (( $# )); do case $1 in
		at) varname=$2; shift 2;;
		 =) initial=$2; shift 2;;
		as) pattern=$2; shift 2;;
		 !) trouble=$2; shift 2;;
		no) exclude=$2; shift 2;;
		or) default=$2; shift 2;;
		by) masking=$2; shift 2;;
		of) suggest=$2; shift 2;;
		//) comment=$2; shift 2;;
		*) shift;;
	esac done

	local entered="$initial"
	while echo -ne "$comment"; do
		local snippet="$entered" control
		[[ $masking ]] && snippet=${snippet//?/$masking}
		# FIX: a problem when <double/triple/or more> press of different keys occurs
		# read function (or somewhat else) prints overflown characters despite on -s option
		while read -p "$snippet" -rsN1 snippet && [[ $snippet != $'\n' ]]; do
			if [[ $snippet == $'\177' || $snippet == $'\010' ]]; then
				[[ $entered ]] && snippet=$'\b \b' || snippet=''
				entered=${entered%?} # remove the last char
				continue
			elif [[ $(printf '%d' "'$snippet") -lt 32 ]]; then
				read -rs -t 0.001 control # swallow control sequence
				control="$snippet$control"; snippet=''
				case $control in
					$'\011') # tab: complete entered text if there is a suggest function
						if [[ $suggest ]] && local choices=($($suggest $entered)) && ((${#choices[@]} == 1)); then
							snippet=${choices#$entered}; entered=${choices}
						fi;;
					$'\033') # esc: erase entered text
						snippet=${entered//?/$'\b \b'}; entered='';;
					# $'\033\133\104') # left # TODO
					# $'\033\133\103') # right # TODO
					# $'\033\133\063\176') # delete # TODO
					# *) # print sequence for debug purpose
					# 	snippet+="\$'"; for ((i = 0; i < ${#control}; i++)); do
					# 		snippet+=$(printf '\\%03o' "'${control:$i:1}")
					# 	done; snippet+="'";;
				esac
				continue
			elif [[ $exclude =~ $snippet ]]; then
				echo -ne '\007' > /dev/stdout # make a sound
				snippet=''
				continue
			fi
			entered="${entered}${snippet}"
			snippet="${masking:-$snippet}"
		done
		if (($? == 0)); then
			if [[ $pattern && ! $entered =~ ^$pattern$ ]]; then
				echo "${entered:+ }# ${trouble-invalid value; expected: /$pattern/}!"
				continue
			else
				[[ $comment ]] && echo
				if [[ $varname ]]; then
					eval "$varname='${entered:-$default}'"
				fi
			fi
		fi
		return $?
	done
}
