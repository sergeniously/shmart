#!/bin/bash

# Parse, enter or print arguments like argument[=value];
# Usage:
#  argue required|optional argname [to varname [~ pattern |= certain] [or default] [of measure]] [do command] [as comment] -- $@
#   @argname: a name pattern of an argument, e.g. "-a|--arg"
#   @varname: a name of a variable a value will be stored to
#   @pattern: a regular expression a value will be validated by
#   @certain: a certain value which will be stored if an argument is present
#   @default: a default value which will be stored if an argument is not present
#   @measure: an unit of an argument value
#   @command: a command which will be performed if an argument is present
#   @comment: a description of an argument
argue() {
	local _meaning _argname _varname _measure
	local _pattern _certain _default _command _comment
	while (( "$#" )); do case $1 in
		optional|required)
			_meaning=$1
			_argname=$2 ; shift 2 ;;
		of) _measure=$2 ; shift 2 ;;
		as) _comment=$2 ; shift 2 ;;
		to) _varname=$2 ; shift 2 ;;
		 ~) _pattern=$2 ; shift 2 ;;
		 =) _certain=$2 ; shift 2 ;;
		or) _default=$2 ; shift 2 ;;
		do) _command=$2 ; shift 2 ;;
		--) shift ; break ;;
		 *) echo "Argue: invalid parsing option $1" ; exit 1 ;;
	esac done
	# print argument
	if [[ $1 =~ ^(-h|--help|help)$ && ! $1 =~ ^($_argname)$ ]]; then
		echo "  ${_argname//|/, }${_pattern+=${_measure-$_pattern}${_default+ (default: '$_default')}}"
		echo "      *${_meaning}* ${_comment}"
		return 202 # aka sos
	fi
	# enter argument
	if !(("$#")) && [[ -n $_varname ]]; then
		local _yesorno="(y|n)" _entered
		read -p "${_comment-${_varname-$_argname}} ${_measure+$_measure=}${_pattern-$_yesorno}: " -e _entered
		if [[ -n $_pattern ]]; then
			if [[ -n $_entered ]]; then
				[[ ! $_entered =~ ^$_pattern$ ]] && echo "Error: invalid entered value; expected $_pattern" && exit 1
				declare -g "$_varname=$_entered"
			else 
				[[ $_meaning == required ]] && echo "Error: empty value of required argument" && exit 1
				declare -g "$_varname=$_default"
			fi
		else
			declare -g "$_varname=$([[ $_entered == y ]] && echo $_certain || echo $_default)"
		fi
		return 0
	fi
	# parse argument
	while (("$#")) && [[ ! $1 =~ ^($_argname) ]]; do shift ; done
	if !(("$#")); then
		[[ $_meaning == required ]] && echo "Error: missed required argument ${_argname//|/, }" && exit 1
		[[ -n $_varname ]] && declare -g "$_varname=$_default" && return 0
		return 1
	fi
	if [[ -n $_varname ]]; then
		if [[ -n $_pattern ]]; then
			[[ ! $1 =~ ^.+=.+$ ]] && echo "Error: missed value for argument $1" && exit 1
			[[ ! ${1/*=/} =~ ^$_pattern$ ]] && echo "Error: invalid value of argument '$1'; expected $_pattern" && exit 1
			declare -g "$_varname=${1/*=/}"
		else
			declare -g "$_varname=${_certain-$1}"
		fi
	fi
	[[ -n $_command ]] && eval "$_command"
	return 0
}
