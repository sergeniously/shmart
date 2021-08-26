#!/bin/bash

# About:
#  parse, enter or print arguments like name[=value];
# Right:
#  (C) 2021, Belenkov Sergei <https://github.com/sergeniously/shmart>
# Usage:
#  argue required|optional|internal argname [of measure] [...] [to varname[[]]
#        [[~ pattern] [? checker]] | [= certain]] [or default] [do command] [as comment] -- "$@"
# Where:
#  @argname: a pattern of an argument name(s), e.g. "-a|--arg"
#   * required: makes an argument required to specify
#   * optional: makes an argument optional to specify
#   * internal: describes arguments to cause embedded features depended on @measure
#    * @measure=guide: causes printing an argument's guide
#    * @measure=usage: causes printing an argument's usage
#    * @measure=offer: causes printing an argument's variants for auto completion
#   * adding ... after it makes an argument multiple
#  @varname: a name of a variable to store a value
#   * adding [] at the end of it tells to treat a variable as an array
#  @pattern: a regular expression to validate a value
#  @checker: a command to validate a value, e.g. 'test -f {}'
#   * the string {} is replaced by a specified value of an argument
#   * if a command succeeds its non-empty echo will be considered as a corrected value
#   * if a command fails its echo will be displayed as en error
#  @certain: a certain value which will be stored if an argument is specified
#   * it is used only if a  validation pattern is not specified
#  @default: a default value which will be stored if an argument is not specified
#  @measure: a unit/type of an argument value
#   * set it as PASSWORD to mask a value with asterisks on input
#  @command: a command which will be performed if an argument is specified
#  @comment: a description of an argument
# Return:
#  200 if an argument's guide was printed
#  201 if an argument's usage was printed
#  202 if an argument's completion variants were printed
#  203 if auto completion was installed
#  1 on failure; 0 on success
# Examples:
#  argue internal "-h|--help|help" of guide do guide as 'Print this guide' -- $@
#  argue internal "--usage|usage" of usage as 'Print short usage' -- $@
#  argue required --username of USERNAME to username ~ "[a-zA-Z0-9_]{3,16}" as 'Make up a username' -- $@
#  argue required --password of PASSWORD to password ~ ".{6,32}" as 'Make up a password' -- $@
#  argue optional --gender to gender ~ "(male|female)" or 'unknown' as 'How do you identify yourself?' -- $@
#  argue optional --language ... of LANGUAGE to languages[] ~ "[a-z]+" as 'Which laguages do you speak?' -- $@
#  argue optional --robot to robot = yes or no as 'Are you a robot?' -- $@
# TODO:
#  + support specifying a set of checkers by ?, where /../ - regular expression, (..) - command, [] - list, etc
#  + substitute @default value with 'no' for arguments without @pattern during input
#  + implement [eg example] option to print it on usage instead of varname
#  + try to detect redundant arguments and store them into argue_trash

argue() {
	local meaning argname several measure
	local varname pattern checker certain
	local default command comment
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
			guide) ARGUE_GUIDE="$argname";;
			usage) ARGUE_USAGE="$argname";;
			offer) ARGUE_OFFER="$argname";;
			setup) ARGUE_SETUP="$argname";;
		esac
	fi
	# print argument guide
	if [[ -n $ARGUE_GUIDE && $1 =~ ^($ARGUE_GUIDE)$ ]]; then
		[[ $1 =~ ^($argname)$ && -n $command ]] && eval "$command"
		printf "%2s${argname//|/, }${pattern+=${measure-$pattern}${several}${default+ (default: '$default')}}\n"
		printf "%6s*${meaning/internal/optional}* ${comment}\n"
		return 200
	fi
	# print argument usage
	if [[ -n $ARGUE_USAGE && $1 =~ ^($ARGUE_USAGE)$ ]]; then
		if [[ $meaning != internal ]]; then
			printf "$([[ $meaning == required ]] && echo "%s" || echo "[%s]" ) " \
				"${argname/|*/}${pattern+=${measure-$varname}}$several"
		elif [[ $measure == usage ]]; then
			echo -n "$(basename $0) "
		fi
		return 201
	fi
	# print auto completion variants for $2
	if [[ -n $ARGUE_OFFER && $1 =~ ^($ARGUE_OFFER)$ ]]; then
		if [[ $measure != offer ]]; then
			for argword in ${argname//|/ }; do
				if [[ $argword =~ ^$2 ]]; then
					printf -- "$argword"; ((${#pattern}||${#checker})) && echo '=' || echo ' '
				elif [[ $2 =~ ^$argword=(.*)$ ]]; then
					local payload=${BASH_REMATCH[1]} variant
					if [[ $pattern =~ ^\([|[:alnum:]]+\)$ ]]; then
						for variant in ${pattern//[(|)]/ }; do
							[[ $variant =~ ^$payload ]] && echo "$variant "
						done
					else
						echo "$payload "
					fi
				fi
			done
		fi
		return 202
	fi
	# install auto completion and run additional command
	if [[ -n $ARGUE_SETUP && $1 =~ ^($ARGUE_SETUP)$ ]]; then
		if [[ $measure == setup ]] && argue-setup && [[ -n $command ]]; then
			eval "$command"
		fi
		return 203
	fi
	argue-store() { # $1 - value
		if ((${#varname})); then
			if [[ ${varname: -2} == '[]' ]]; then
				((${#1})) && eval "${varname%[]}+=('$1')"
			else
				eval "${varname%[]}='$1'"
			fi
			return 0
		fi
		return 1
	}
	local checked
	argue-check() { # $1 - value
		checked=''
		if ((${#pattern})) && [[ ! $1 =~ ^$pattern$ ]]; then
			checked="invalid value; expected ${measure+$measure=}/$pattern/"
			return 1
		fi
		if ((${#checker})); then
			checked=$(${checker//\{\}/$1} 2>&1)
			return $?
		fi
		checked="${checked:-$1}"
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
	local counter=0
	# enter argument
	if !(("$#")) && [[ $meaning != internal ]]; then
		local consent="y|yes" dissent="n|no"
		echo "${comment-${varname-$argname}} <${measure-${pattern-($consent|$dissent)}}>${default+ (default: $default)}"
		while printf "%3s$meaning > " && argue-enter; do
			if ((${#entered})); then
				if ((${#pattern}||${#checker})); then
					if ! argue-check "$entered"; then
						echo " # $checked!" && continue
					fi
					argue-store "$checked"; (( counter++ ))
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
		if [[ $1 =~ ^($argname)(=(.*))?$ ]]; then
			if [[ -z $several && $counter -gt 0 ]]; then
				echo "$1 # duplicate argument!"; exit 1
			fi
			if !((${#pattern}||${#checker})); then
				argue-store "${certain-$1}"
			elif [[ ${BASH_REMATCH[2]:0:1} != '=' ]]; then
				echo "$1 # argument needs a value!"; exit 1
			elif ! argue-check "${BASH_REMATCH[3]}"; then
				echo "$1 # $checked!"; exit 1
			else
				argue-store "$checked"
			fi
			(( counter++ ))
		fi
		shift
	done
	if !(($counter)); then
		if [[ $meaning == required ]]; then
			echo "${argname//|/, } # missed required argument!" && exit 1
		fi
		argue-store "$default"
		return $?
	elif ((${#command})); then
		eval "$command"
	fi
	return 0
}

# install auto completion
argue-setup()
{
if [[ -z $ARGUE_OFFER ]]; then
	echo 'Unable to install auto completion: feature is disabled!'
	echo 'Please, declare: argue internal --offer or offer.'
	return 1
fi
local command=$(basename $0)
local handler="_${command//[[:punct:]]/_}_completion"
local include="/usr/share/bash-completion/completions/$command"
if ! [[ -f $include && -w $include || -w $(dirname $include) ]]; then
	echo 'Unable to install auto completion: permission denied!'
	echo 'Please, run with sudo.'
	return 1
fi
cat > $include << EOT
$handler() {
  local IFS=\$'\n' cur
  _get_comp_words_by_ref -n = cur
  COMPREPLY=(\$($(readlink -f $0) ${ARGUE_OFFER/|*} \$cur))
}
complete -o nospace -F $handler $command
EOT
echo "Auto completion successfully installed!"
return 0
}
