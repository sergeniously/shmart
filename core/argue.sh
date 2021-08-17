#!/bin/bash

# About:
#  parse, enter or print arguments like argument[=value];
# Usage:
#  argue required|optional argname [...] [to varname[[]] [~ pattern |= certain] [or default] [of measure]] [do command] [as comment] -- "$@"
# Where:
#  @argname: a pattern of an argument name, e.g. "-a|--arg"
#   * adding ... after it makes an argument multiple
#  @varname: a name of a variable to store a value
#   * adding [] at the end of it tells to treat a variable as an array
#  @pattern: a regular expression to validate a value
#  @certain: a certain value which will be stored if an argument is specified
#   * it is used only if a  validation pattern is not specified
#  @default: a default value which will be stored if an argument is not specified
#  @measure: a unit of an argument value
#   * set it as PASSWORD to mask a value with asterisks on input
#  @command: a command which will be performed if an argument is specified
#  @comment: a description of an argument
# Examples:
#  argue required --username of USERNAME to username ~ "[a-zA-Z0-9_]{3,16}" as 'Make up a username' -- $@
#  argue required --password of PASSWORD to password ~ ".{6,32}" as 'Make up a password' -- $@
#  argue optional --gender to gender ~ "(male|female)" or 'unknown' as 'How do you identify yourself?' -- $@
#  argue optional --language... of LANGUAGE to languages[] ~ "[a-z]+" as 'Which laguages do you speak?' -- $@
#  argue optional --robot to robot = yes or no as 'Are you a robot?' -- $@
# TODO:
#  + implement an ability to check values by function using @pattern with different syntaxes: /regexp/ or (method)
#  + substitute @default value with 'no' for arguments without @pattern during input
#  + implement [eg example] option to print it on usage instead of varname

argue() {
	local meaning argname several varname measure
	local pattern certain default command comment
	while (( "$#" )); do case $1 in
		optional|required)
			meaning=$1
			argname=$2; shift 2;;
		...) several=$1; shift ;;
		to) varname=$2; shift 2;;
		 ~) pattern=$2; shift 2;;
		 =) certain=$2; shift 2;;
		of) measure=$2; shift 2;;
		or) default=$2; shift 2;;
		do) command=$2; shift 2;;
		as) comment=$2; shift 2;;
		--) shift; break;;
		 *) echo "argue: invalid parsing option $1"; exit 1;;
	esac done
	# print argument
	if [[ $1 =~ ^(-h|--help|help)$ ]]; then
		[[ $1 =~ ^($argname)$ && -n $command ]] && eval "$command"
		printf "%2s${argname//|/, }${pattern+=${measure-$pattern}${several}${default+ (default: '$default')}}\n"
		printf "%6s*${meaning}* ${comment}\n"
		return 200
	fi
	# usage argument
	if [[ $1 =~ ^(--usage|usage)$ ]]; then
		if [[ $argname == "-h|--help|help" ]]; then
			echo -n "Usage: $(basename $0) "
		else
			printf "$([[ $meaning == required ]] && echo "%s" || echo "[%s]" ) " \
				"${argname/|*/}${pattern+=${measure-$varname}}$several"
		fi
		return 201
	fi

	argue_store() {
		if ((${#varname})); then
			if [[ ${varname//[^\[\]]/} == '[]' ]]; then
				((${#1})) && eval "${varname%[]}+=('$1')"
			else
				eval "${varname%[]}='$1'"
			fi
		fi
	}
	local counter=0
	# enter argument
	if !(("$#")); then
		local consent="y|yes" dissent="n|no"
		local ex_pattern=${pattern-($consent|$dissent)}
		echo "${comment-${varname-$argname}} ${measure+$measure=}${ex_pattern}${default+ (default: $default)}"
		while printf "%3s$meaning > "; do
			local entered='' snippet=''
			while read -p "$snippet" -r -s -N1 snippet && [[ $snippet != $'\n' ]]; do
				if [[ $snippet == $'\177' || $snippet == $'\010' ]]; then
					[[ -n $entered ]] && snippet=$'\b \b' || snippet=''
					entered=${entered%?}
					continue
				elif [[ $(printf '%d' "'$snippet") -lt 32 ]]; then
					# swallow control-character sequences
					read -rs -t 0.001; snippet=''
					continue
				fi
				entered="${entered}${snippet}"
				if [[ ${measure^^} == PASSWORD ]]; then
					snippet='*'
				fi
			done
			if [[ -n $entered ]]; then
				[[ ! $entered =~ ^$ex_pattern$ ]] && echo " # invalid value; expected $ex_pattern" && continue
				if [[ -n $pattern ]]; then
					argue_store "$entered"; (( counter++ ))
				elif [[ $entered =~ ^($consent)$ ]]; then
					argue_store "$certain"; (( counter++ ))
				else
					argue_store "$default"
				fi
			elif [[ $counter -eq 0 ]]; then
				[[ $meaning == required ]] && echo "# empty value of required argument" && continue
				argue_store "$default"
			fi
			meaning=optional; echo "${entered:+ # OK}"
			[[ -z $entered || -z $several ]] && break
		done
	fi
	# parse argument
	while (("$#")); do
		if [[ $1 =~ ^($argname) ]]; then
			if [[ -z $several && $counter -gt 0 ]]; then
				echo "Error: duplicate argument '$1'"; exit 1
			fi
			if [[ -n $pattern ]]; then
				[[ ! $1 =~ ^.+=(.+)$ ]] && echo "Error: missed value for argument '$1'" && exit 1
				if [[ ! ${BASH_REMATCH[1]} =~ ^$pattern$ ]]; then
					echo "Error: invalid value of argument '$1'; expected $pattern" && exit 1
				fi
				argue_store "${BASH_REMATCH[0]}"
			else
				argue_store "${certain-$1}"
			fi
			(( counter++ ))
		fi
		shift
	done
	if !(($counter)); then
		[[ $meaning == required ]] && echo "Error: missed required argument ${argname//|/, }" && exit 1
		[[ -n $varname ]] && argue_store "$default" && return 0
		return 1
	elif ((${#command})); then
		eval "$command"
	fi
	return 0
}
