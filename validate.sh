#!/bin/bash

# validate required|optional varname by pattern [or default]
# examples:
#   validate required var1 by "pattern"
#   validate optional var2 by "pattern" or 'default'
validate() {
	local _meaning _varname _argname
	local _pattern _default
	while (( $# )); do case $1 in
		optional|required)
			_meaning=$1 ; _varname=$2
			_argname="--${2/_/-}" ; shift 2 ;;
		by) _pattern=$2 ; shift 2 ;;
		or) _default=$2 ; shift 2 ;;
		*) echo "Error: invalid validation option $1"; exit 1 ;;
	esac done

	if [[ ! -v $_varname ]]; then
		if [[ $_meaning == required ]]; then
			echo "Error: missed required argument $_argname"
			exit 1
		fi
		declare -g "$_varname=$_default"
	elif [[ ! ${!_varname} =~ ^$_pattern$ ]]; then
		echo "Error: invalid value '${!_varname}' of argument $_argname; expected $_pattern"
		exit 1
	fi
}

#validate optional file by "(/\w+)+" or '/tmp/file'
