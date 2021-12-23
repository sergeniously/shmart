#!/bin/bash

# About:
#  parse, input, print or complete arguments like key[[=]value];
# Right:
#  (C) 2021, Belenkov Sergei <https://github.com/sergeniously/shmart>
# Usage:
#  argue initiate "$@" # initialize internal array for parsing
#  argue required|optional|internal argkeys [...] [of measure] [to|at varname[[]]] \
#        [[? checker] [~ pattern]] | [[= certain] [: fetcher]] [or default] \
#        [do command] [if request [! warning]] [@ suggest] \
#        [as comment] | [// comment...]
#  .....
#  argue finalize # do three following statements by default
#  argue finalize guide usage offer && exit # exit if one of internal feature was done
#  argue finalize extra && argue-extra 'there are unknown arguments: {}' && exit 1 # print unparsed arguments at {} and exit
#  argue finalize run # run parsed commands
# Where:
#  @argkeys: keys of an argument separated by commas, e.g. "--arg,-a"
#   * required: makes an argument required to specify
#   * optional: makes an argument optional to specify
#   * internal: describes arguments to enable internal features depended on @measure:
#   ** @measure=guide: enables printing an argument's guide
#   ** @measure=usage: enables printing an argument's usage
#   ** @measure=offer: enables printing an argument's completion variants
#   ** @measure=input: enables to input arguments from stdin
#   ** internal arguments are not available for input
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
#   * |mask| - describes a value template with special mask characters:
#   ** A - expects alphabet character [a-zA-Z]
#   ** B - expects binary character [0-1]
#   ** D - expects decimal character [0-9]
#   ** H - expects hexadecimal character [a-zA-Z0-9]
#   ** P - expects punctuation character [,.:;!?]
#  @pattern: a regular expression to validate a value (alias for ? /pattern/)
#  @certain: a certain value which will be stored if an argument is specified
#   * it is used only if no checker was specified
#  @fetcher: a command to get a certain value for an argument
#  @default: a default value which will be stored if an argument is not specified
#  @measure: a unit/type of an argument value
#   * set it as PASSWORD to mask a value with asterisks on input
#  @command: a command which will be performed if an argument is specified
#  @request: a command whose exit status enables or disables argument
#  @warning: a message to display if argument is disabled
#  @suggest: a command to get completion variants for a value
#  @comment: a description of an argument which will be printed for help
# Return:
#  1 if argument is not encountered
#  0 if argument is processed
# Examples:
#  argue initiate "$@"
#  argue internal -h,--help,help of guide do guide as 'Print this guide'
#  argue internal --usage,usage of usage as 'Print short usage'
#  argue required --username of USERNAME to username ~ "[a-zA-Z0-9_]{3,16}" as 'Make up a username'
#  argue required --password of PASSWORD to password ~ ".{6,32}" as 'Make up a password'
#  argue optional --gender to gender ? '{male,female}' or 'unknown' as 'How do you identify yourself?'
#  argue optional --language ... of LANGUAGE to languages[] ~ "[a-z]+" as 'Which laguages do you speak?'
#  argue optional --robot to robot = yes or no as 'Are you a robot?'
#  argue finalize
# TODO:
#  + implement pattern arguments like optional "" ~ ".+"
#  + implement a checker-command which returns a list of possible values: ? <command>
#  + implement positional arguments by option: at <position>
#  + implement internal features by default

declare -A ARGUE_INNER # array of internal features
declare -a ARGUE_TASKS # array of commands to launch
declare -a ARGUE_ARRAY # array of arguments to parse
declare -i ARGUE_COUNT # initial number of arguments
declare -g ARGUE_FIRST # the first argument to parse
declare -g ARGUE_STATE # a final state of the parser
declare -A ARGUE_MASKS # array of masking characters
ARGUE_MASKS[A]="[a-zA-Z]" # alphabet characters
ARGUE_MASKS[P]="[,.:;!?]" # general punctuation
ARGUE_MASKS[H]="[a-fA-F0-9]" # hex characters
ARGUE_MASKS[D]="[0-9]" # decimal characters
ARGUE_MASKS[B]="[0-1]" # binary characters

argue() {
	case $1 in
		initiate) shift
			ARGUE_FIRST=$1; ARGUE_COUNT=$#
			ARGUE_ARRAY=("$@"); return 0;;
		finalize) shift
			if (($#)); then
				argue-final "$@"
			else # do by default
				argue-final guide usage offer && echo && exit 0
				argue-final extra && argue-extra 'there are unknown arguments: {}' && exit 1
				argue-final run # perform parsed commands
			fi; return $?;;
	esac
	local meaning argkeys several measure varname
	local certain default command warning comment
	local checkers=() enabled=true suggest
	while (($#)); do case $1 in
		optional|required|internal)
			meaning=$1; argkeys=$2; shift 2;;
		 ~) checkers+=("/$2/"); shift 2;;
		\?) checkers+=("$2"); shift 2;;
		to|at) varname=$2; shift 2;;
		=|:) certain=$1$2; shift 2;;
		...) several=...; shift;;
		of) measure=$2; shift 2;;
		or) default=$2; shift 2;;
		do) command=$2; shift 2;;
		as) comment=$2; shift 2;;
		 @) suggest=$2; shift 2;;
		//) shift; comment="$@"; break;;
		if) ($2 &> /dev/null) || enabled=false; shift 2;;
		 !) $enabled || warning=$2; shift 2;;
		 *) argue-error "argue: unexpected parsing option '$1'";;
	esac done
	$enabled || meaning=disabled
	if [[ $meaning == internal ]]; then
		case $measure in guide|usage|offer|input)
			ARGUE_INNER[$measure]="${argkeys//,/|}";;
		esac
	fi
	local checked entered fetched counter=0
	argue-guide() { # print argument guide
		[[ $measure == guide ]] && echo 'Guide:'
		printf "%2s${argkeys//,/, }${checkers[@]+=${measure-$varname}${default+ (default: '$default')}}${several}\n"
		printf "%6s*${meaning/internal/optional}* $comment ${warning:+($warning)}\n"
	}
	argue-usage() { # print argument usage
		if $enabled && [[ $meaning != internal ]]; then
			printf "$([[ $meaning == required ]] && echo "%s" || echo "[%s]" ) " \
				"${argkeys//,/|}${checkers[@]+=${measure-$varname}}$several"
		elif [[ $measure == usage ]]; then
			echo -n "$(basename $0) "
		fi
	}
	argue-offer() { # print completion variants for $1
		[[ $measure == offer ]] && return
		local variant && for variant in ${argkeys//,/ }; do
			if [[ $variant =~ ^$1 ]]; then
				printf -- "$variant"; ((${#checkers[@]})) && echo '=' || echo ' '
			elif [[ $1 =~ ^$variant=(.*)$ ]] && local written=${BASH_REMATCH[1]}; then
				if [[ $suggest ]]; then
					$suggest $written
				elif argue-check "$written"; then
					echo "$written "
				elif [[ $checked =~ \{(.+)\}$ ]]; then
					for variant in ${BASH_REMATCH[1]//,/ }; do
						[[ $variant =~ ^$written ]] && echo "$variant "
					done
				fi
			fi
		done
	}
	argue-store() { # $1 - value
		if ((${#varname})); then
			if [[ ${varname: -2} == '[]' ]]; then
				[[ $1 ]] && eval "${varname%[]}+=('$1')"
			else
				eval "$varname='$1'"
			fi
		fi
	}
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
			elif [[ $checker =~ ^\|(.+)\|$ ]]; then
				local masking=${BASH_REMATCH[1]} index=0
				for ((; index <= ${#masking}; index++)); do
					local char=${1:$index:1} mask=${masking:$index:1} pattern=''
					if ((${#mask})) && pattern=${ARGUE_MASKS[$mask]} && ((${#pattern}))
						then [[ $char =~ ^$pattern$ ]]; else [[ $char == $mask ]]; fi
					if [[ $? -ne 0 ]]; then
						((${#char})) && checked="invalid character '$char'" || checked="unexpected end of string"
						checked="$checked at position $index; expected ${pattern:-'${mask:-<end of string>}'}"
						return 1
					fi
				done
			fi
		done
		checked="${checked:-$1}"
	}
	argue-enter() {
		entered=''; local snippet=''
		while read -p "$snippet" -rsN1 snippet && [[ $snippet != $'\n' ]]; do
			if [[ $snippet == $'\177' || $snippet == $'\010' ]]; then
				[[ $entered ]] && snippet=$'\b \b' || snippet=''
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
	argue-fetch() { # $1 - argument
		fetched=''
		case ${certain:0:1} in
			:) if ! fetched=$(${certain:1} 2>&1); then
					fetched=${fetched:-'failed to fetch a value'}
					return 1
				fi;;
			=) fetched=${certain:1};;
		esac
		fetched=${fetched:-$1}
	}
	argue-input() { # input argument from stdin
		if ! $enabled || [[ $meaning == internal ]]; then
			return 1
		fi
		local consent="y|yes" dissent="n|no"
		echo -n "${comment-${varname-$argkeys}}${measure+ <$measure>:} "
		((${#checkers[@]})) && echo "${checkers[@]#(*)}${default+ (default: '$default')} $several" \
			|| echo "($consent|$dissent) (default: ${dissent##*|})"
		while printf "%3s$meaning > " && argue-enter; do
			if [[ $entered ]]; then
				if ((${#checkers[@]})); then
					if ! argue-check "$entered"; then
						echo " # $checked!" && continue
					fi
					argue-store "$checked"; ((counter++))
				elif [[ ! $entered =~ ^($consent|$dissent)$ ]]; then
					echo " # invalid value; expected ($consent|$dissent)"; continue
				elif [[ $entered =~ ^($consent)$ ]]; then
					if ! argue-fetch; then
						echo " # $fetched!"; exit 1
					fi
					argue-store "$fetched"
					((counter++))
				fi
			elif (($counter == 0)) && [[ $meaning == required ]]; then
				echo "# empty value of required argument"; continue
			fi
			meaning=optional; echo "${entered:+ # OK}"
			[[ ! $entered || ! $several ]] && break
		done; echo
	}
	argue-parse() {
		ARGUE_ARRAY=()
		while (($#)); do
			if ! [[ $1 =~ ^(${argkeys//,/|})(=(.*))?$ ]]; then
				ARGUE_ARRAY+=("$1"); shift; continue
			fi
			if ! $enabled; then
				argue-error "$1 # argument is disabled ${warning:+($warning)}"
			elif [[ ! $several && $counter -gt 0 ]]; then
				argue-error "$1 # duplicate argument!"
			fi
			if !((${#checkers[@]})); then
				if ! argue-fetch $1; then
					argue-error "$1 # $fetched!"
				fi
				argue-store "$fetched"
			else
				if [[ ${BASH_REMATCH[2]:0:1} == '=' ]]; then
					argue-check "${BASH_REMATCH[3]}"
				elif [[ $# -gt 1 ]]; then
					shift; argue-check "$1"
				else
					argue-error "$1 # argument needs a value!"
				fi
				if (($? != 0)); then
					argue-error "$1 # $checked!"
				else
					argue-store "$checked"
				fi
			fi
			((counter++)); shift
		done
		if (($counter == 0)) && [[ $meaning == required ]]; then
			argue-error "${argkeys//,/, } # missed required argument!"
		fi
	}
	local feature
	for feature in ${!ARGUE_INNER[@]}; do
		[[ $ARGUE_FIRST =~ ^(${ARGUE_INNER[$feature]})$ ]] || continue
		[[ $measure == $feature && $command ]] && eval "$command"
		argue-$feature ${ARGUE_ARRAY[1]}; ARGUE_STATE=$feature
		[[ $feature != input ]] && return 0
	done
	if [[ $ARGUE_STATE != input ]]; then
		argue-parse "${ARGUE_ARRAY[@]}"
		if ((${#ARGUE_ARRAY[@]})); then
			# there are extra arguments
			ARGUE_STATE=extra
		else
			ARGUE_STATE=ready
		fi
	fi
	if (($counter == 0)); then
		if [[ ${default+x} == x ]]; then
			argue-store "$default"
		fi
		return 1
	elif [[ $command ]]; then
		if [[ $meaning != internal ]]; then
			ARGUE_TASKS+=("$command")
		else # run instantly
			eval "$command"
		fi
	fi
	return 0
}

# print error and exit badly
argue-error() {
	echo "$(basename $0): $@" > /dev/stderr
	exit 1
}

# print unknown arguments instead of {}
argue-extra() {
	if ((${#ARGUE_ARRAY[@]} && $#)); then
		local garbage=${ARGUE_ARRAY[@]}
		local warning="${@//\{\}/${garbage// /, }}"
		echo "$(basename $0): $warning" > /dev/stderr
	fi
}

# perform final operations
argue-final() {
	local state
	for state in $@; do
		if [[ $state == run ]]; then
			local command
			for command in "${ARGUE_TASKS[@]}"; do
				eval "$command" || return 1
			done
			return 0
		fi
		if [[ $ARGUE_STATE == $state ]]; then
			return 0
		fi
	done
	return 1
}

# install bash completion
argue-setup()
{
local utility=$(basename $0)
local feature=${ARGUE_INNER[offer]/|*}
local problem=''

if [[ ! $feature ]]; then
	problem='offer feature is disabled'
else
	local catalog=${BASH_COMPLETION_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion}/completions
	if [[ ! -d $catalog ]]; then
		mkdir -p $catalog || problem='cannot create completion directory'
	elif [[ -f $catalog/$utility ]]; then
		test -w $catalog/$utility || problem='cannot access existent completion file'
	else
		test -w $catalog || problem='cannot access completion directory'
	fi
fi
if [[ $problem ]]; then
	argue-error "unable to install bash completion: $problem!"
fi

local handler="_${utility//[[:punct:]]/_}_completion"
cat > $catalog/$utility << EOT
$handler() {
  local IFS=\$'\n' cur
  _get_comp_words_by_ref -n = cur
  COMPREPLY=(\$($(readlink -f $0) $feature \$cur 2> /dev/null))
}
complete -o nospace -F $handler $utility
EOT
echo "$utility: bash completion successfully installed!"
exit 0
}
