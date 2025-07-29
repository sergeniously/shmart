
# About:
#  commands runner with natural interface which:
#  - prints comments of what is going to be done and how it has done;
#  - measures and prints the time of performed commands;
#  - can additionally trap multiple commands;
#  - can store output into a variable or a file;
#  - can perform exceptional command when main command fails.
# Author:
#  Belenkov Sergei, 2023-2025
# Usage:
#  proceed to "comment | command" \
#   [do "command" | do { command ... }]... \
#   [on handler | or perfect] [at varname] [in journal]
# Where:
#   @comment: a description of what will be done (if there was no @command, @comment is expected to be a command)
#   @command: a command that will be done
#   @handler: a signal type which @command will be done on (EXIT, ERR, ...)
#   @perfect: a command that will be done if @command fails (use 'die' alias to exit 1)
#   @varname: a variable name which output of @command will be stored to
#   @journal: a location to output proceeding logs (default: /dev/null)
# Examples:
#   proceed to "mkdir /tmp/dir" or die
#   proceed to "delete directory" do "rm -rf /tmp/dir" on EXIT
#   proceed to 'create temporary directory' do "mktemp -d dir.XXX" at temp_dir
#   proceed to "pack directory" do { tar -vcf /tmp/dir.tar /tmp/dir } do "chmod +x /tmp/dir.tar"

declare -g PROCEED_CANCEL=false # whether a command is cancelled
declare -g PROCEED_TIMING=true # TODO whether to echo execution time
declare -g PROCEED_DEBUG=false # whether to echo running commands
declare -g PROCEED_LOG_TO=/dev/null # default target to output logs
declare -g PROCEED_LOG_BY=echo # default command to output logs
declare -g PROCEED_PREP='' # function to preprocess a command

if [[ ! $(trap -p INT) ]]; then
	# set a hook to catch cancellation
	trap 'PROCEED_CANCEL=true' INT
fi

proceed-log() {
	local journal=$1 message prefix
	if [[ $journal =~ ^/dev/ ]]; then
		prefix='... '
	elif [[ -f $journal ]]; then
		# clear previous logs
		echo -n > $journal
	fi
	while read -r message; do
		$PROCEED_LOG_BY "${prefix}$message" >> $journal
	done
}

proceed-trap() {
	local handler=$1 command="$2"
	# parse already trapped commands
	local trapped=$(trap -p $handler)
	trapped=${trapped%\'*}; trapped=${trapped#*\'}
	trap "${trapped:+$trapped;}${command}" $handler
}

proceed() {
	PROCEED_CANCEL=false
	local comment commands perfect handler caterer
	local varname vardata journal=$PROCEED_LOG_TO
	while (("$#")); do case $1 in
		to) comment=$2; shift 2;;
		do) if [[ $2 == '{' ]]; then
				while shift; do
					commands+=("$1")
					if [[ $1 == '}' ]]; then
						shift; break
					fi
				done
			else
				commands+=('{' $2 '}');
				shift 2
			fi;;
		from) caterer=$2; shift 2;;
		or) perfect=$2; shift 2;;
		on) handler=$2; shift 2;;
		in) journal=$2; shift 2;;
		at) varname=$2; shift 2;;
		*) shift ;;
	esac done
	# if no command was specified
	# assume comment as a command
	if ! ((${#commands[@]})); then
		commands+=('{' $comment '}')
	fi

	if [[ $handler ]]; then
		local command=() argument
		proceed-trap $handler "echo Proceeding to $comment on $handler..."
		for argument in "${commands[@]}"; do
			if [[ $argument == '{' ]]; then
				command=(); continue
			elif [[ $argument != '}' ]]; then
				command+=("\"$argument\"")
				continue
			fi
			proceed-trap $handler "${command[*]} | proceed-log $journal"
		done
		proceed-trap $handler 'echo Done.;echo'
		return
	fi

	proceed-run() {
		local command=() argument
		for argument in "${commands[@]}"; do
			if [[ $argument == '{' ]]; then
				command=(); continue
			elif [[ $argument != '}' ]]; then
				command+=("$argument")
				continue
			fi

			if [[ $PROCEED_PREP ]]; then
				local new_command=()
				while read -r argument; do
					new_command+=("$argument")
				done < <($PROCEED_PREP "${command[@]}")
				command=("${new_command[@]}")
			fi

			if $PROCEED_DEBUG; then
				echo " > ${command[*]}" ${caterer:+from $caterer} >> /dev/stdout
			fi
			if [[ $varname ]]; then
				vardata+=$("${command[@]}" 2> >(proceed-log /dev/stderr))
			else
				"${command[@]}" &> >(proceed-log $journal)
			fi
			if (($? != 0)); then
				return 1
			fi
		done
	}

	echo "Proceeding to $comment ..." >> /dev/stdout
	local managed=succeeded started=$(date +%s)
	if [[ $caterer ]]; then
		cat ${caterer/stdin/} | proceed-run
	else proceed-run; fi
	if [[ $? -ne 0 ]]; then
		if $PROCEED_CANCEL; then
			printf "\b\b" # remove ^C trace
			managed=cancelled
		else
			if [[ -f $journal && ! $journal =~ ^/dev/ ]]; then
				# if journal is a regular file dump its content to see errors
				cat $journal | proceed-log /dev/stdout
			fi
			managed=failed
		fi
	fi
	local elapsed=$(($(date +%s) - $started))
	printf "${managed^} to $comment (took $elapsed seconds)!\n\n" >> /dev/stdout
	if [[ $managed != succeeded ]]; then
		# if no exception command was passed nothing will happen
		${perfect/die/exit 1} # replace die with exit 1 command
		return 1
	elif [[ $varname ]]; then
		eval "$varname='$vardata'"
	fi
	return 0
}
