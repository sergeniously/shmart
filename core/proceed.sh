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
	local varname vardata journal=/dev/stdout
	while (($#)); do case $1 in
		to) comment=$2; shift 2;;
		do) commands+=("$2"); shift 2;;
		or) perfect=$2; shift 2;;
		on) handler=$2; shift 2;;
		at) varname=$2; shift 2;;
		in) journal=$2; shift 2;;
		 *) shift;;
	esac done
	# if no command was specified
	# assume comment as a command
	if ! ((${#commands[@]})); then
		commands+=("$comment")
	fi
	if [[ ! $(trap -p INT) ]]; then
		# set a hook to catch cancelation
		trap 'managed=canceled' INT
	fi

	if [[ $handler ]]; then
		local trapped # parse already trapped commands
		if [[ $(trap -p $handler) =~ \'(.*)\' ]]; then
			trapped=${BASH_REMATCH[1]}
		fi
		# insert new commands into the beginning of the trap
		commands="echo Proceeding to $comment on $handler ...;${commands[@]/%/ | proceed_log $journal;}echo Done.;echo;"
		trap "${commands} ${trapped}" $handler
		return $?
	fi

	proceed_log() {
		local journal=$1 message
		while read -r message; do
			echo "   $message" >> $journal
		done
	}

	proceed_run() {
		local command
		for command in "${commands[@]}"; do
			if [[ -n $varname ]]; then
				$command 2> >(proceed_log $journal)
			else
				$command &> >(proceed_log $journal)
			fi
			if (($?)); then
				return 1
			fi
		done
	}

	echo "Proceeding to $comment ..."
	local managed=succeeded started=$(date +%s)
	[[ $varname ]] && vardata=$(proceed_run) || proceed_run
	if (($? != 0)); then
		managed=${managed/succeeded/failed}
	fi
	local elapsed=$(($(date +%s) - $started))
	echo -e "\r${managed^} to ${comment} (took $elapsed seconds)!\n"
	if [[ $managed == succeeded ]]; then
		[[ $varname ]] && declare -g "$varname=$vardata"
		return 0
	fi
	# if no exception command was specified nothing will happen
	${perfect/die/exit 1}
	return 1
}
