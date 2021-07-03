#!/bin/bash

# proceed to "comment | command" [do command]... [on handler | or perfect] [at varname] [in journal]
#   @comment: a description of what will be done (if there was no @command, @comment is expected to be a command)
#   @command: a command that will be done
#   @handler: a signal type which @command will be done on (EXIT, ERR, ...)
#   @perfect: a command that will be done if @command fails (use 'die' alias to exit 1)
#   @varname: a variable name which output of @command will be stored to
#   @journal: a location to output proceeding logs (default: /dev/null)
# examples:
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
	if ! (( ${#_commands[@]} )); then
		_commands+=("$_comment")
	fi
	
	if [[ -n $_handler ]]; then
		local _handler_commands=$(trap -p $_handler)
		_handler_commands=${_handler_commands%\'*}
		_handler_commands=${_handler_commands/#*\'/}
		_commands="echo Proceeding to $_comment on $_handler ...; ${_commands[@]/%/ &>> $_journal;} echo ... Done.;"
		trap "${_commands} ${_handler_commands}" $_handler
		return $?
	fi

	echo "Proceeding to $_comment ..."
	local _managed=succeed _started=$(date +%s) _command
	for _command in "${_commands[@]}"; do
		if [[ -n $_varname ]]; then
			_vardata="${_vardata}$($_command 2>> $_journal)"
		else
			$_command &>> $_journal
		fi
		if [[ $? -ne 0 ]]; then
			_managed=failed ; break
		fi
	done
	local _elapsed=$(($(date +%s) - $_started))
	echo "... ${_managed^} to ${_comment}! (took $_elapsed seconds)"; echo
	if [[ $_managed == succeed ]]; then
		[[ -n $_varname ]] && declare -g "$_varname=$_vardata"
		return 0
	fi
	${_perfect/die/exit 1}
	return 1
}

# More examples:

#proceed to 'clean up' do "rm -f one" do "rm -f two" on EXIT
#proceed to 'break up' do 'bla bla car' on EXIT in /dev/stdout

#dir=/tmp/dir
#if proceed to "make directory $dir" do "mkdir -vp $dir" do "chmod -v 755 $dir" in /dev/stdout ; then
#	proceed do 'echo cleaning up' do "rm -vrf $dir" on EXIT in /dev/stdout
#fi

#if proceed to 'make temp dir' do "mktemp -d -p /tmp/ serg.XXXX" at temp_dir; then
#	proceed to "rm -vrf $temp_dir" on EXIT in /dev/stdout
#fi

#for file in '/tmp/file' '/etc/file' "${HOME}/file"; do
#	if proceed to "create $file" do "touch $file" ; then
#		proceed to "rm -vf $file" on EXIT in /dev/stdout
#	fi
#done
