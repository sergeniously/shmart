#!/bin/bash

# About:
#  parse, enter or print arguments like argument[=value];
# Usage:
#  argue required|optional|internal argname [...] [of measure] [to varname[[]] [[~ pattern] [? checker]] | [= certain] [or default]] [do command] [as comment] -- "$@"
# Where:
#  @argname: a pattern of an argument name, e.g. "-a|--arg"
#   * required: makes an argument required to specify
#   * optional: makes an argument optional to specify
#   * internal: describes arguments of guide and usage modes
#   * adding ... after it makes an argument multiple
#  @varname: a name of a variable to store a value
#   * adding [] at the end of it tells to treat a variable as an array
#  @pattern: a regular expression to validate a value
#  @checker: a command line to validate a value, e.g. 'test -f {}'
#   * the string {} is replaced by a value which is supposed to be checked
#  @certain: a certain value which will be stored if an argument is specified
#   * it is used only if a  validation pattern is not specified
#  @default: a default value which will be stored if an argument is not specified
#  @measure: a unit of an argument value
#   * set it as PASSWORD to mask a value with asterisks on input
#  @command: a command which will be performed if an argument is specified
#  @comment: a description of an argument
# Examples:
#  argue internal "-h|--help|help" of guide do guide as 'Print this guide' -- $@
#  argue internal "--usage|usage" of usage as 'Print short usage' -- $@
#  argue required --username of USERNAME to username ~ "[a-zA-Z0-9_]{3,16}" as 'Make up a username' -- $@
#  argue required --password of PASSWORD to password ~ ".{6,32}" as 'Make up a password' -- $@
#  argue optional --gender to gender ~ "(male|female)" or 'unknown' as 'How do you identify yourself?' -- $@
#  argue optional --language... of LANGUAGE to languages[] ~ "[a-z]+" as 'Which laguages do you speak?' -- $@
#  argue optional --robot to robot = yes or no as 'Are you a robot?' -- $@
# TODO:
#  + substitute @default value with 'no' for arguments without @pattern during input
#  + implement [eg example] option to print it on usage instead of varname

argue() {
	local meaning argname several varname measure
	local pattern certain default command comment
	local checker trouble counter=0
	while (("$#")); do case $1 in
		optional|required|internal)
			meaning=$1; argname=$2; shift 2;;
		to) varname=$2; shift 2;;
		 ~) pattern=$2; shift 2;;
		\?) checker=$2; shift 2;;
		 =) certain=$2; shift 2;;
		of) measure=$2; shift 2;;
		or) default=$2; shift 2;;
		do) command=$2; shift 2;;
		as) comment=$2; shift 2;;
		...) several=$1; shift;;
		--) shift; break;;
		 *) echo "argue: invalid parsing option $1"; exit 1;;
	esac done
	if [[ $meaning == internal ]]; then
		case $measure in
			guide) argue_guide="$argname";;
			usage) argue_usage="$argname";;
		esac
	fi
	# print argument
	if [[ -n $argue_guide && $1 =~ ^($argue_guide)$ ]]; then
		[[ $1 =~ ^($argname)$ && -n $command ]] && eval "$command"
		printf "%2s${argname//|/, }${pattern+=${measure-$pattern}${several}${default+ (default: '$default')}}\n"
		printf "%6s*${meaning}* ${comment}\n"
		return 200
	fi
	# usage argument
	if [[ -n $argue_usage && $1 =~ ^($argue_usage)$ ]]; then
		if [[ $meaning != internal ]]; then
			printf "$([[ $meaning == required ]] && echo "%s" || echo "[%s]" ) " \
				"${argname/|*/}${pattern+=${measure-$varname}}$several"
		elif [[ $measure == usage ]]; then
			echo -n "$(basename $0) "
		fi
		return 201
	fi
	argue-store() { # $1 - value
		if ((${#varname})); then
			if [[ ${varname//[^\[\]]/} == '[]' ]]; then
				((${#1})) && eval "${varname%[]}+=('$1')"
			else
				eval "${varname%[]}='$1'"
			fi
			return 0
		fi
		return 1
	}
	argue-check() { # $1 - value
		if ((${#pattern})) && [[ ! $1 =~ ^$pattern$ ]]; then
			trouble="invalid value; expected $pattern"
			return 1
		fi
		if ((${#checker})); then
			trouble=$(${checker//\{\}/$1} 2>&1)
			return $?
		fi
	}
	local entered
	argue-enter() {
		local snippet=''; entered=''
		while read -p "$snippet" -r -s -n1 snippet && ((${#snippet})); do
			if [[ $snippet == $'\177' || $snippet == $'\010' ]]; then
				((${#entered})) && snippet=$'\b \b' || snippet=''
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
	}
	# enter argument
	if !(("$#")) && [[ $meaning != internal ]]; then
		local consent="y|yes" dissent="n|no"
		echo "${comment-${varname-$argname}} <${measure-${pattern-($consent|$dissent)}}>${default+ (default: $default)}"
		while printf "%3s$meaning > " && argue-enter; do
			if ((${#entered})); then
				if ((${#pattern})); then
					if ! argue-check "$entered"; then
						echo " # $trouble!" && continue
					fi
					argue-store "$entered"; (( counter++ ))
				elif [[ ! $entered =~ ^($consent|$dissent)$ ]]; then
					echo " # invalid value; expected ($consent|$dissent)" && continue
				elif [[ $entered =~ ^($consent)$ ]]; then
					argue-store "$certain"; (( counter++ ))
				else
					argue-store "$default"
				fi
			elif [[ $counter -eq 0 ]]; then
				[[ $meaning == required ]] && echo "# empty value of required argument" && continue
				argue-store "$default"
			fi
			meaning=optional; echo "${entered:+ # OK}"
			[[ -z $entered || -z $several ]] && break
		done; echo
	fi
	# parse argument
	while (("$#")); do
		if [[ $1 =~ ^($argname) ]]; then
			if [[ -z $several && $counter -gt 0 ]]; then
				echo "$1 # duplicate argument!"; exit 1
			fi
			if ((${#pattern})); then
				[[ ! $1 =~ ^.+=(.+)$ ]] && echo "$1 # argument needs a value!" && exit 1
				if ! argue-check "${BASH_REMATCH[1]}"; then
					echo "$1 # $trouble!"; exit 1
				fi
				argue-store "${BASH_REMATCH[0]}"
			else
				argue-store "${certain-$1}"
			fi
			(( counter++ ))
		fi
		shift
	done
	if !(($counter)); then
		[[ $meaning == required ]] && echo "${argname//|/, } # missed required argument!" && exit 1
		argue-store "$default"
		return $?
	elif ((${#command})); then
		eval "$command"
	fi
	return 0
}
