#!/bin/bash

# About:
#  parse, enter or print arguments like argument[=value];
# Usage:
#  argue required|optional argname[...] [to varname[[]] [~ pattern |= certain] [or default] [of measure]] [do command] [as comment] -- $@
# Where:
#  @argname: a pattern of an argument name, e.g. "-a|--arg"
#   * adding ... at the end of it makes an argument multiple
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
argue() {
	local _meaning _argname _several _varname _vartype _measure
	local _pattern _certain _default _command _comment
	while (( "$#" )); do case $1 in
		optional|required)
			_meaning=$1
			_argname=${2%...}
			_several=${2#$_argname}
			shift 2;;
		to) _varname=${2%[]}
			_vartype=${2#$_varname}
			shift 2;;
		 ~) _pattern=$2; shift 2;;
		 =) _certain=$2; shift 2;;
		of) _measure=$2; shift 2;;
		or) _default=$2; shift 2;;
		do) _command=$2; shift 2;;
		as) _comment=$2; shift 2;;
		--) shift; break;;
		 *) echo "argue: invalid parsing option $1"; exit 1;;
	esac done
	# print argument
	if [[ $1 =~ ^(-h|--help|help)$ ]]; then
		[[ $1 =~ ^($_argname)$ && -n $_command ]] && eval "$_command"
		printf "%2s${_argname//|/, }${_pattern+=${_measure-$_pattern}${_several}${_default+ (default: '$_default')}}\n"
		printf "%6s*${_meaning}* ${_comment}\n"
		return 202 # aka sos
	fi

	argue_store() {
		if ((${#1})); then
			eval $(printf $([[ $_vartype == '[]' ]] && echo "%s+=('%s')" || echo "%s='%s'") "$_varname" "$1")
		elif [[ ! -v $_varname ]]; then
			eval $(printf $([[ $_vartype == '[]' ]] && echo "%s=()" || echo "%s=''") "$_varname")
		fi
	}
	# enter argument
	if !(("$#")) && [[ -n $_varname ]]; then
		local _consent="y|yes" _dissent="n|no"
		local _ex_pattern=${_pattern-($_consent|$_dissent)} _counter=0
		echo "${_comment-${_varname-$_argname}} ${_measure+$_measure=}${_ex_pattern}${_default+ (default: $_default)}"
		while printf "%3s$_meaning > "; do
			local _entered='' _content=''
			while read -p "$_content" -r -s -N1 _content && [[ $_content != $'\n' ]]; do
				if [[ $_content == $'\177' || $_content == $'\010' ]]; then
					[[ -n $_entered ]] && _content=$'\b \b' || _content=''
					_entered=${_entered%?}
					continue
				elif [[ $(printf '%d' "'$_content") -lt 32 ]]; then
					# swallow control-character sequences
					read -rs -t 0.001; _content=''
					continue
				fi
				_entered="${_entered}${_content}"
				if [[ ${_measure^^} == PASSWORD ]]; then
					_content='*'
				fi
			done
			if [[ -n $_entered ]]; then
				[[ ! $_entered =~ ^$_ex_pattern$ ]] && echo " # invalid value; expected $_ex_pattern" && continue
				if [[ -z $_pattern ]]; then
					argue_store $([[ $_entered =~ ^($_consent)$ ]] && echo "$_certain" || echo "$_default")
				else
					argue_store "$_entered"
				fi
			elif [[ $_counter -eq 0 ]]; then
				[[ $_meaning == required ]] && echo "# empty value of required argument" && continue
				argue_store "$_default"
			fi
			(( _counter++ )); _meaning=optional; echo "${_entered:+ # OK}"
			[[ -z $_entered || -z $_several ]] && break
		done; return 0
	fi
	# parse argument
	local _counter=0
	while (("$#")); do
		if [[ $1 =~ ^($_argname) ]]; then
			if [[ -n $_varname ]]; then
				if [[ -z $_several && $_counter -gt 0 ]]; then
					echo "Error: duplicate argument '$1'"; exit 1
				fi
				if [[ -n $_pattern ]]; then
					[[ ! $1 =~ ^.+=.+$ ]] && echo "Error: missed value for argument '$1'" && exit 1
					[[ ! ${1#*=} =~ ^$_pattern$ ]] && echo "Error: invalid value of argument '$1'; expected $_pattern" && exit 1
					argue_store "${1#*=}"
				else
					argue_store "${_certain-$1}"
				fi
			fi
			(( _counter++ ))
		fi
		shift
	done
	if !(( $_counter )); then
		[[ $_meaning == required ]] && echo "Error: missed required argument ${_argname//|/, }" && exit 1
		[[ -n $_varname ]] && argue_store "$_default" && return 0
		return 1
	else
		[[ -n $_command ]] && eval "$_command"
	fi
	return 0
}
