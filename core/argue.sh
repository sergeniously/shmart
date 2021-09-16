#!/bin/bash

# About:
#  parse, input, print or complete arguments like name[=value];
# Right:
#  (C) 2021, Belenkov Sergei <https://github.com/sergeniously/shmart>
# Usage:
#  argue -- "$@" # initialize internal array to parse
#  argue required|optional|internal argname [...] [of measure] [to|at|@ varname[[]]] \
#        [[? checker] [~ pattern]] | [[= certain] [: fetcher]] [or default] \
#        [do command] [as comment] | [// comment...]
#  .....
#  argue %% "{}" # print unparsed arguments at {} and return their number
# Where:
#  @argname: a pattern of an argument name(s), e.g. "-a|--arg"
#   * required: makes an argument required to specify
#   * optional: makes an argument optional to specify
#   * internal: describes arguments to enable embedded features depended on @measure
#   ** @measure=guide: causes printing an argument's guide
#   ** @measure=usage: causes printing an argument's usage
#   ** @measure=offer: causes printing an argument's variants for auto completion
#   ** another value describes custom internal feature
#   ** also, internal arguments are not available for input
#   * adding ... after it makes an argument multiple
#  @varname: a name of a variable to store a value
#   * adding [] at the end of it tells to treat a variable as an array
#  @checker: a validator for checking a value in following formats:
#   * /pattern/ - describes a regular expression
#   * (command) - describes a command, e.g. test -f {}, where {} is replaced by a provided value
#   ** if a command succeeds its non-empty echo will be considered as a corrected value
#   ** if a command fails its echo will be displayed as an error
#   * {one,two,...} - describes a list of possible values separated by comma
#   * [min..max] - describes a minimum and a maximum number of a value
#  @pattern: a regular expression to validate a value (alias for ? /pattern/)
#  @certain: a certain value which will be stored if an argument is specified
#   * it is used only if no checker was specified
#  @fetcher: a command to get a certain value for an argument
#  @default: a default value which will be stored if an argument is not specified
#  @measure: a unit/type of an argument value
#   * set it as PASSWORD to mask a value with asterisks on input
#  @command: a command which will be performed if an argument is specified
#  @comment: a description of an argument which will be printed for help
# Return:
#  200 if an argument's guide was printed
#  201 if an argument's usage was printed
#  202 if an argument's completion caused
#  100 if there left unparsed arguments
#  0 if everything is alright
# Examples:
#  argue -- "$@"
#  argue internal "-h|--help|help" of guide do guide as 'Print this guide'
#  argue internal "--usage|usage" of usage as 'Print short usage'
#  argue required --username of USERNAME to username ~ "[a-zA-Z0-9_]{3,16}" as 'Make up a username'
#  argue required --password of PASSWORD to password ~ ".{6,32}" as 'Make up a password'
#  argue optional --gender to gender ~ "(male|female)" or 'unknown' as 'How do you identify yourself?'
#  argue optional --language ... of LANGUAGE to languages[] ~ "[a-z]+" as 'Which laguages do you speak?'
#  argue optional --robot to robot = yes or no as 'Are you a robot?'
# TODO:
#  + implement [if request] option to specify a conditional command to enable argument
#  + implement [eg example] option to print it on usage instead of varname

declare -A ARGUE_INNER # array of internal features
declare -a ARGUE_TASKS # array of commands to launch
declare -a ARGUE_ARRAY # array of arguments to parse
declare -i ARGUE_COUNT # initial number of arguments
declare -g ARGUE_FIRST # the first argument to parse

argue() {
	local meaning argname several measure
	local varname certain default command
	local checkers=() comment # enabled=true
	while (("$#")); do case $1 in
		--) shift
			ARGUE_FIRST=$1; ARGUE_COUNT=$#
			ARGUE_ARRAY=("$@"); return 0;;
		%%) shift; local remains=${#ARGUE_ARRAY[@]}
			(($remains && "$#")) && echo "${@//\{\}/${ARGUE_ARRAY[@]}}"
			return $remains;;
		@@) for command in "${ARGUE_TASKS[@]}"; do
				eval "$command"
			done; return 0;;
		optional|required|internal)
			meaning=$1; argname=$2; shift 2
			[[ $1 == ... ]] && several=$1 && shift;;
		 ~) checkers+=("/$2/"); shift 2;;
		\?) checkers+=("$2"); shift 2;;
		to|at|@) varname=$2; shift 2;;
		=|:) certain="$1$2"; shift 2;;
		of) measure=$2; shift 2;;
		or) default=$2; shift 2;;
		do) command=$2; shift 2;;
		as) comment=$2; shift 2;;
		//) shift; comment="$@"; break;;
		# if) ($2 &> /dev/null) || enabled=false; shift 2;;
		 *) echo "argue: invalid parsing option $1"; exit 1;;
	esac done
	if [[ $meaning == internal ]]; then
		ARGUE_INNER[$measure]="$argname"
	fi
	argue-guide() { # print argument guide
		printf "%2s${argname//|/, }${checkers[@]+=${measure-$varname}}${several}${default+ (default: '$default')}\n"
		printf "%6s*${meaning/internal/optional}* ${comment}\n"
		return 200
	}
	argue-usage() { # print argument usage
		if [[ $meaning != internal ]]; then
			printf "$([[ $meaning == required ]] && echo "%s" || echo "[%s]" ) " \
				"${argname/|*/}${checkers[@]+=${measure-$varname}}$several"
		elif [[ $measure == usage ]]; then
			echo -n "$(basename $0) "
		fi
		return 201
	}
	argue-offer() { # print auto completion variants for $1
		if [[ $measure != offer ]]; then
			local variant && for variant in ${argname//|/ }; do
				if [[ $variant =~ ^$1 ]]; then
					printf -- "$variant"; ((${#checkers[@]})) && echo '=' || echo ' '
				elif [[ $1 =~ ^$variant=(.*)$ ]] && local written=${BASH_REMATCH[1]} checker; then
					for checker in "${checkers[@]}"; do [[ $checker =~ ^\{(.+)\}$ ]] && break; done
					((${#BASH_REMATCH[1]})) && for variant in ${BASH_REMATCH[1]//,/ }; do
						[[ $variant =~ ^$written ]] && echo "$variant " || true
					done || echo "$written "
				fi
			done
		fi
		return 202
	}
	if ((${#ARGUE_FIRST})); then
		local feature && for feature in ${!ARGUE_INNER[@]}; do
			[[ $ARGUE_FIRST =~ ^(${ARGUE_INNER[$feature]})$ ]] || continue
			[[ $measure == $feature && -n $command ]] && eval "$command"
			case $feature in guide|usage|offer)
				argue-$feature ${ARGUE_ARRAY[1]};;
			esac; return $?
		done
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
		checked=''; local checker
		for checker in "${checkers[@]}"; do
			if [[ $checker =~ ^/(.+)/$ ]]; then
				if ! [[ $1 =~ ^${BASH_REMATCH[1]}$ ]]; then
					checked="invalid value; expected a pattern $checker"
					return 1
				fi
			elif [[ $checker =~ ^\{(.+)\}$ ]]; then
				if ! [[ $1 =~ ^(${BASH_REMATCH[1]//,/|})$ ]]; then
					checked="invalid value; expected one of $checker"
					return 1
				fi
			elif [[ $checker =~ ^\((.+)\)$ ]]; then
				if ! checked=$(eval ${BASH_REMATCH[1]//\{\}/\'$1\'} 2>&1); then
					checked=${checked:-'failed to check a value'}
					return 1
				fi
			elif [[ $checker =~ ^\[(-?[0-9]+)\.+(-?[0-9]+)\]$ ]]; then
				local minimum=${BASH_REMATCH[1]} maximum=${BASH_REMATCH[2]}
				if ! [[ $1 =~ ^-?[0-9]+$ && $1 -ge $minimum && $1 -le $maximum ]]; then
					checked="invalid value; expected a number in interval $checker"
					return 1
				fi
			fi
		done
		checked="${checked:-$1}"
	}
	local entered
	argue-enter() {
		entered=''; local snippet=''
		while read -p "$snippet" -rsN1 snippet && [[ $snippet != $'\n' ]]; do
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
	local fetched
	argue-fetch() { # $1 - argument
		case ${certain:0:1} in
			:) if ! fetched=$(${certain:1}} 2>&1); then
					fetched=${fetched:-'failed to fetch a value'}
					return 1
				fi;;
			=) fetched=${certain:1};;
		esac
		fetched=${fetched:-$1}
	}
	local counter=0
	argue-input() {
		local consent="y|yes" dissent="n|no"
		echo -n "${comment-${varname-$argname}}${measure+ <$measure>:} "
		((${#checkers})) && echo "${checkers[@]#(*)}${default+ (default: '$default')}" \
			|| echo "($consent|$dissent) (default: ${dissent##*|})"
		while printf "%3s$meaning > " && argue-enter; do
			if ((${#entered})); then
				if ((${#checkers[@]})); then
					if ! argue-check "$entered"; then
						echo " # $checked!" && continue
					fi
					argue-store "$checked"; (( counter++ ))
				elif [[ ! $entered =~ ^($consent|$dissent)$ ]]; then
					echo " # invalid value; expected ($consent|$dissent)"; continue
				elif [[ $entered =~ ^($consent)$ ]]; then
					if ! argue-fetch; then
						echo " # $fetched!"; exit 1
					fi
					argue-store "$fetched"; (( counter++ ))
				elif [[ ${default+x} == x ]]; then
					argue-store "$default"
				fi
			elif [[ $counter -eq 0 ]]; then
				if [[ $meaning == required ]]; then
					echo "# empty value of required argument"; continue
				elif [[ ${default+x} == x ]]; then
					argue-store "$default"
				fi
			fi
			meaning=optional; echo "${entered:+ # OK}"
			[[ -z $entered || -z $several ]] && break
		done; echo
	}
	argue-parse() {
		ARGUE_ARRAY=()
		while (("$#")); do
			if [[ $1 =~ ^($argname)(=(.*))?$ ]]; then
				if [[ -z $several && $counter -gt 0 ]]; then
					echo "$1 # duplicate argument!"; exit 1
				fi
				if !((${#checkers[@]})); then
					if ! argue-fetch $1; then
						echo "$1 # $fetched!"; exit 1
					fi
					argue-store "$fetched"
				elif [[ ${BASH_REMATCH[2]:0:1} != '=' ]]; then
					echo "$1 # argument needs a value!"; exit 1
				elif ! argue-check "${BASH_REMATCH[3]}"; then
					echo "$1 # $checked!"; exit 1
				else
					argue-store "$checked"
				fi
				(( counter++ ))
			else
				ARGUE_ARRAY+=("$1")
			fi
			shift
		done
	}
	if (($ARGUE_COUNT)); then
		argue-parse "${ARGUE_ARRAY[@]}"
	elif [[ $meaning != internal ]]; then
		argue-input
	fi
	if !(($counter)); then
		if [[ $meaning == required ]]; then
			echo "${argname//|/, } # missed required argument!" && exit 1
		elif [[ ${default+x} == x ]]; then
			argue-store "$default"
		fi
	elif ((${#command})); then
		ARGUE_TASKS+=("$command")
	fi
	if ((${#ARGUE_ARRAY[@]})); then
		# there are unparsed arguments
		return 100
	fi
	return 0
}

# install auto completion
argue-setup()
{
if [[ -z ${ARGUE_INNER[offer]} ]]; then
	echo 'Unable to install auto completion: feature is disabled!'
	echo 'Please, declare: argue internal offer of offer'
	exit 1
fi
local command=$(basename $0)
local handler="_${command//[[:punct:]]/_}_completion"
local path="${HOME}/bash_completion.d" file="${command}.bash"
if  [[ ! -d $path ]] && ! mkdir -p $path; then
	echo 'Unable to install auto completion: cannot create directory!'
	echo 'Please, try to run with sudo.'
	exit 1
fi
if ! [[ -f $path/$file && -w $path/$file || -w $path ]]; then
	echo 'Unable to install auto completion: permission denied!'
	echo 'Please, run with sudo.'
	exit 1
fi
cat > $path/$file << EOT
$handler() {
  local IFS=\$'\n' cur
  _get_comp_words_by_ref -n = cur
  COMPREPLY=(\$($(readlink -f $0) ${ARGUE_INNER[offer]/|*} \$cur))
}
complete -o nospace -F $handler $command
EOT
echo "Auto completion successfully installed!"
exit 0
}
