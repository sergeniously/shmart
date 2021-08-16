#!/bin/bash

# Commands runner with natural interface which:
#  - prints comments of what is going to be done and how it has done;
#  - measures and prints the time of performed commands;
#  - can additionally trap multiple commands;
#  - can store output into a variable or a file;
#  - can perform exceptional command when main command fails.
# Usage:
#  proceed to "comment | command" [do command]... [on handler | or perfect] [at varname] [in journal]
#   @comment: a description of what will be done (if there was no @command, @comment is expected to be a command)
#   @command: a command that will be done
#   @handler: a signal type which @command will be done on (EXIT, ERR, ...)
#   @perfect: a command that will be done if @command fails (use 'die' alias to exit 1)
#   @varname: a variable name which output of @command will be stored to
#   @journal: a location to output proceeding logs (default: /dev/null)
# Examples:
#   proceed to "create directory" do "mkdir /tmp/dir" or die
#   proceed to "rm -rf /tmp/dir" on EXIT
#   proceed to 'create temp directory' do "mktemp -d dir.XXX" at temp_dir
#   proceed to "echo 'Hello, world!'" in /tmp/dir/file or 'exit 1'
#   proceed to "pack directory" do "tar -vcf /tmp/dir.tar /tmp/dir"
proceed() {
	local _comment _commands _perfect _handler
	local _varname _vardata _journal=/dev/null
	while (( "$#" )); do case $1 in
		to) _comment=$2; shift 2 ;;
		do) _commands+=("$2"); shift 2 ;;
		or) _perfect=$2; shift 2 ;;
		on) _handler=$2; shift 2 ;;
		at) _varname=$2; shift 2 ;;
		in) _journal=$2; shift 2 ;;
		*) shift ;;
	esac done
	# if no command was specified
	# assume comment as a command
	if ! (( ${#_commands[@]} )); then
		_commands+=("$_comment")
	fi
	if [[ -z $(trap -p INT) ]]; then
		# set a hook to catch cancelation
		trap '_managed=canceled' INT
	fi

	if [[ -n $_handler ]]; then
		# parse already trapped commands
		local _trapped=$(trap -p $_handler)
		_trapped=${_trapped%\'*}; _trapped=${_trapped/#*\'/}
		# insert new commands into the beginning of the trap
		_commands="echo Proceeding to $_comment on $_handler ...;${_commands[@]/%/ &>> $_journal;}echo Done.;echo;"
		trap "${_commands} ${_trapped}" $_handler
		return $?
	fi

	echo "Proceeding to $_comment ..."
	local _managed=succeeded _started=$(date +%s) _command
	for _command in "${_commands[@]}"; do
		if [[ -n $_varname ]]; then
			_vardata="${_vardata}$($_command 2>> $_journal)"
		else
			$_command &>> $_journal
		fi
		if [[ $? -ne 0 ]]; then
			_managed=${_managed/succeeded/failed}; break
		fi
	done
	local _elapsed=$(($(date +%s) - $_started))
	echo -e "\r${_managed^} to ${_comment} (took $_elapsed seconds)!\n"
	if [[ $_managed == succeeded ]]; then
		[[ -n $_varname ]] && declare -g "$_varname=$_vardata"
		return 0
	fi
	# if no exception command was specified nothing will happen
	${_perfect/die/exit 1}
	return 1
}
