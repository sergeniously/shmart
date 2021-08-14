#!/bin/bash

# Parse, enter or print arguments like argument[=value];
# Usage:
#  argue required|optional argname [...] [to varname [~ pattern |= certain] [or default] [of measure]] [do command] [as comment] -- $@
#   @argname: a name pattern of an argument, e.g. "-a|--arg"
#   @varname: a name of a variable a value will be stored to
#   @pattern: a regular expression a value will be validated by
#   @certain: a certain value which will be stored if an argument is present
#   @default: a default value which will be stored if an argument is not present
#   @measure: an unit of an argument value
#   @command: a command which will be performed if an argument is present
#   @comment: a description of an argument
#   '...': tells that argument is multiple
# Examples:
#  argue required --username of USERNAME to username ~ "[a-zA-Z0-9_]{3,16}" as 'Make up a username' -- $@
#  argue required --password of PASSWORD to password ~ ".{6,32}" as 'Make up a password' -- $@
#  argue optional --gender to gender ~ "(male|female)" or 'unknown' as 'How do you identify yourself?' -- $@
#  argue optional --language ... of LANGUAGE to languages ~ "[a-z]+" as 'Which laguages do you speak?' -- $@
#  argue optional --robot to robot = yes or no as 'Are you a robot?' -- $@
argue() {
	local _meaning _argname _varname _measure _several
	local _pattern _certain _default _command _comment
	while (( "$#" )); do case $1 in
		optional|required)
			_meaning=$1
			_argname=$2; shift 2;;
		of) _measure=$2; shift 2;;
		as) _comment=$2; shift 2;;
		to) _varname=$2; shift 2;;
		 ~) _pattern=$2; shift 2;;
		 =) _certain=$2; shift 2;;
		or) _default=$2; shift 2;;
		do) _command=$2; shift 2;;
		...) _several=$1; shift;;
		--) shift; break;;
		 *) echo "Argue: invalid parsing option $1"; exit 1;;
	esac done
	# print argument
	if [[ $1 =~ ^(-h|--help|help)$ && ! $1 =~ ^($_argname)$ ]]; then
		printf "%2s${_argname//|/, }${_pattern+=${_measure-$_pattern}${_several}${_default+ (default: '$_default')}}\n"
		printf "%6s*${_meaning}* ${_comment}\n"
		return 202 # aka sos
	fi
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
				fi
				_entered="$_entered$_content"
				if [[ ${_measure^^} == PASSWORD ]]; then
					_content='*'
				fi
			done
			if [[ -n $_entered ]]; then
				[[ ! $_entered =~ ^$_ex_pattern$ ]] && echo " # invalid value; expected $_ex_pattern" && continue
				if [[ -z $_pattern ]]; then
					declare -g "$_varname=$([[ $_entered =~ ^($_consent)$ ]] && echo $_certain || echo $_default)"
				else
					declare -g "$_varname=$_entered"
				fi
			elif [[ $_counter -eq 0 ]]; then
				[[ $_meaning == required ]] && echo "# empty value of required argument" && continue
				declare -g "$_varname=$_default"
			fi
			(( _counter++ )); _meaning=optional; echo
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
					[[ -n $_several ]] && eval "$_varname+=('${1#*=}')" || declare -g "$_varname=${1#*=}"
				else
					[[ -n $_several ]] && eval "$_varname+=('${_certain-$1}')" || declare -g "$_varname=${_certain-$1}"
				fi
			fi
			(( _counter++ ))
		fi
		shift
	done
	if !(( $_counter )); then
		[[ $_meaning == required ]] && echo "Error: missed required argument ${_argname//|/, }" && exit 1
		[[ -n $_varname ]] && declare -g "$_varname=$_default" && return 0
		return 1
	else
		[[ -n $_command ]] && eval "$_command"
	fi
	return 0
}
