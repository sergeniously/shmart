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
	local comment commands perfect handler
	local varname vardata journal=/dev/null
	while (( "$#" )); do case $1 in
		to) comment=$2; shift 2 ;;
		do) commands+=("$2"); shift 2 ;;
		or) perfect=$2; shift 2 ;;
		on) handler=$2; shift 2 ;;
		at) varname=$2; shift 2 ;;
		in) journal=$2; shift 2 ;;
		*) shift ;;
	esac done
	# if no command was specified
	# assume comment as a command
	if ! (( ${#commands[@]} )); then
		commands+=("$comment")
	fi
	if [[ -z $(trap -p INT) ]]; then
		# set a hook to catch cancelation
		trap 'managed=canceled' INT
	fi

	if [[ -n $handler ]]; then
		# parse already trapped commands
		local trapped=$(trap -p $handler)
		trapped=${trapped%\'*}; trapped=${trapped/#*\'/}
		# insert new commands into the beginning of the trap
		commands="echo Proceeding to $comment on $handler ...;${commands[@]/%/ &>> $journal;}echo Done.;echo;"
		trap "${commands} ${trapped}" $handler
		return $?
	fi

	echo "Proceeding to $comment ..."
	local managed=succeeded started=$(date +%s) command
	for command in "${commands[@]}"; do
		if [[ -n $varname ]]; then
			vardata="${vardata}$($command 2>> $journal)"
		else
			$command &>> $journal
		fi
		if [[ $? -ne 0 ]]; then
			managed=${managed/succeeded/failed}; break
		fi
	done
	local elapsed=$(($(date +%s) - $started))
	echo -e "\r${managed^} to ${comment} (took $elapsed seconds)!\n"
	if [[ $managed == succeeded ]]; then
		[[ -n $varname ]] && declare -g "$varname=$vardata"
		return 0
	fi
	# if no exception command was specified nothing will happen
	${perfect/die/exit 1}
	return 1
}
