# About:
#  Powerful command-line parser with natural interface.
#  Supported features:
#   - Auto completions for bash, zsh.
#   - Enter arguments from standard input.
#   - Full help and short usage instructions.
#   - Ariphmetical operations for numbers and strings.
#   - Flexible parameters validation.
# Author:
#  Belenkov Sergey, 2021 - 2025, https://github.com/sergeniously/shmart
# Usage:
#  argue initiate "$@" # initialize internal array for parsing
#  argue terminal arguments ... # define terminal @arguments which consume everything
#  argue defaults offer usage guide input setup # initialize default internal arguments
#  argue required|optional --argkeys[=pattern]|(pattern) [? control] [...] [or default] [of measure] \
#    [at varname] [to functor] [= certain] [editors ...] [if request [! warning]] [@ suggest] \
#    [do command] [as comment | // comment ...]
#  ...
#  argue finalize # check state and unknown arguments, run commands
# Where:
#  @argkeys: keys of an argument separated by commas, e.g. -a,--arg
#  @pattern: a regular expression to match an argument value
#  @control: an additional format to check a value; supports following formats:
#    /regular/ - a regular expression to match a value with
#    {one,two,...} - a list of possible values separated by comma
#    [min..max] - a minimum and a maximum value of a number
#    <min..max> - a minimum and a maximum length of a string
#    (checker {}) - a command to check/fix an argument value {}
#    |MASK| - a template with special mask characters:
#      A - expects alphabet character [a-zA-Z]
#      B - expects binary character [0-1]
#      D - expects decimal character [0-9]
#      H - expects hexadecimal character [a-zA-Z0-9]
#      P - expects punctuation character [,.:;!?]
#  @...: ellipsis makes an argument available to be specified multiple times
#  @default: a default value in case an argument is not specified
#  @measure: a unit/type of an argument value, e.g. FILE, seconds (*)
#   (*) set it as PASSWORD to mask a value with asterisks on input
#  @varname: a name of a variable to store a value (*)
#   (*) if it starts with env. a variable will be exported to the environment
#   (*) if it ends with [] a variable will be treated as an array
#  @functor: a command or a function to apply a value
#  @certain: a certain value to be applied if an argument is specified (*)
#   (*) all occurrences of {} in it will be replaced by an argument value (if there it is)
#  @editors: specifies modification operations in the next forms:
#   - value: decrease numbers or remove @value substring;
#   + value: increase numbers or append @value substring;
#   / value: divide numbers or cut a left part of a string by @value;
#   % value: give a remainder of a division or cut a right part of a string by @value.
#  @command: a command to be run if an argument is specified
#  @comment: a description of an argument which will be printed for help
#  @request: a command whose exit status enables or disables an argument
#  @warning: a message to display if an argument is disabled
#  @suggest: a command to get completion variants for a value
# TODO:
#  offer with descriptions (remove description if only one match)
#  specify default value for required arguments (maybe)
#  support fish auto completions
#  support multiline comments

declare -A ARGUE_INNER # array of internal features
declare -a ARGUE_ARRAY # array of arguments to parse
declare -i ARGUE_COUNT # initial number of arguments
declare    ARGUE_FIRST # the first argument to parse
declare    ARGUE_STATE # a final state of the parser
declare -a ARGUE_TORUN # array of commands to be run
declare -g ARGUE_BREAK # group of terminal arguments
declare -A ARGUE_MASKS=( # array of masking characters
	[A]="[a-zA-Z]" # alphabet characters
	[P]="[,.:;!?]" # general punctuation
	[H]="[a-fA-F0-9]" # hex characters
	[D]="[0-9]" # decimal characters
	[B]="[0-1]" # binary characters
)

# print an error to stderr
argue-error() {
	echo "$(basename $0):" "$@" >&2
}
# print an error and exit
argue-abort() {
	argue-error "$@"
	exit 1
}

# print unknown arguments instead of {}
argue-extra() {
	if ((${#ARGUE_ARRAY[@]} && "$#")); then
		local garbage=${ARGUE_ARRAY[@]}
		local warning="${@//\{\}/${garbage// /, }}"
		echo "$(basename $0): $warning" > /dev/stderr
	fi
}

argue() {
	case $1 in
		initiate) shift
			ARGUE_FIRST=$1; ARGUE_COUNT=$#
			ARGUE_ARRAY=("$@"); return 0;;
		terminal) shift
			ARGUE_BREAK="$*"; return 0;;
		defaults) # implement default arguments
			while shift && (("$#")); do case $1 in
				offer) argue internal offer,complete of offer // Print completion variants;;
				guide) argue internal guide,help,--help,-h,\\? of guide do about // Print full guide;;
				usage) argue internal usage,how of usage // Print short usage;;
				input) argue internal input of input // Input options from stdin;;
				setup) argue internal setup,complement of setup // Setup auto completion;;
			esac done; return 0;;
		finalize) shift
			if !(("$#")); then
				# finalize by default
				argue finalize offer && exit 0
				argue finalize guide && echo && exit 0
				argue finalize usage && echo && exit 0
				argue finalize extra && argue-extra 'there are invalid arguments: {}' && exit 1
				argue finalize run; return $?
			fi
			case $1 in
				guide|usage|offer|extra)
					[[ $ARGUE_STATE == $1 ]] && return 0 || return 1;;
				run) local running
					for running in "${ARGUE_TORUN[@]}"; do
						eval "$running" || return 1
					done; return 0;;
				*) argue-abort "argue: $1 # unknown finalize state";;
			esac;;
	esac

	local meaning argkeys pattern
	local measure varname certain
	local default command comment
	local several functor warning
	local suggest control=() editors=()
	while (("$#")); do case $1 in
		optional|required|disabled|internal)
			case $2 in
				*=*)
					argkeys=${2%%=*}
					control+=("/${2#*=}/")
					pattern="(${argkeys//,/|})=(${2#*=})"
				;;
				*\(*) [[ $2 =~ ^([^\(]*)(.+)$ ]]
					argkeys=${BASH_REMATCH[1]}
					control+=("/${BASH_REMATCH[2]}/")
					pattern="(${argkeys})${BASH_REMATCH[2]}"
				;;
				*)
					argkeys=$2
					pattern="(${2//,/|})"
				;;
			esac
			meaning=$1 ; shift 2;;
		+|-|/|%)
			editors+=("$1$2"); shift 2;;
		\?) control+=("$2"); shift 2;;
	   ...) several=$1 ; shift ;;
		or) : ${default:=$2}; shift 2;;
		of) measure=$2 ; shift 2;;
		at) varname=$2 ; shift 2;;
		to) functor=$2 ; shift 2;;
		 =) certain=$2 ; shift 2;;
		do) command=$2 ; shift 2;;
		 @) suggest=$2 ; shift 2;;
		as) comment=$2 ; shift 2;;
		//) shift; comment="$@"; break;;
		if) ($2 &> /dev/null) || meaning=disabled; shift 2;;
		 !) [[ $meaning == disabled ]] && warning=$2; shift 2;;
		 *) argue-abort "argue: $1 # invalid parsing option";;
	esac done

	if [[ $meaning == internal ]]; then
		case $measure in offer|guide|usage|input|setup)
			ARGUE_INNER[$measure]="${argkeys//,/|}";;
		esac
	fi

	argue-guide() { # print full guide
		[[ $measure == guide ]] && echo 'Guide:'
		local argview=%s${pattern#*)}; argview=${argview%%(*}%s
		printf "%2s${argview} ${several}\n" '' "${argkeys//,/, }" \
			"${control:+${measure-${varname-VALUE}}${default+ (default: '$default')}}"
		printf "%6s%s\n" '' "*${meaning/internal/optional}* ${comment} ${warning:+($warning)}"
	}
	argue-usage() { # print short usage
		if [[ $meaning != internal ]]; then
			local argview=%s${pattern#*)}; argview="${argview%%(*}%s%s"
			if [[ $meaning != required ]]; then argview="[$argview]"; fi
			printf "$argview " "${argkeys//,/|}" "${control:+${measure-${varname-VALUE}}}" \
				"${several:+ ...}"
		elif [[ $measure == usage ]]; then
			echo -n "$0 "
		fi
	}
	argue-offer() { # print completion variants for $1
		if [[ $measure == offer ]]
			then return # dont offer itself
		fi
		local variant capture
		local pattern=${pattern#*)}
		for variant in ${argkeys//,/ }; do
			if [[ $variant =~ ^$1 ]]; then
				if [[ ! $control ]]; then echo "$variant "
				elif [[ ${pattern:0:1} == '=' ]]; then echo "$variant="
				elif [[ $variant == $1 && $pattern =~ ^\(([^"][)(.?+-"]+)\)$ ]]; then
					for capture in ${BASH_REMATCH[1]//|/ }; do
						echo "$variant$capture "
					done
				else echo "$variant"
				fi
			elif [[ $1 =~ ^$variant${pattern//(*)/(.*)}$ ]]; then
				local written=${BASH_REMATCH[1]}
				[[ ${pattern:0:1} == '=' ]] && variant=''
				if [[ $suggest ]]; then $suggest "$written"
				elif argue-check "${written:-$default}"; then
					echo "$variant$checked "
				elif [[ $checked =~ \{(.+)\}$ ]]; then
					for capture in ${BASH_REMATCH[1]//,/ }; do
						[[ $capture =~ ^$written ]] && echo "$variant$capture "
					done
				elif [[ $checked =~ /\(([^"][)(.?+-"]+)\)/$ ]]; then
					for capture in ${BASH_REMATCH[1]//|/ }; do
						[[ $capture =~ ^$written ]] && echo "$variant$capture "
					done
				fi
			fi
		done
	}
	argue-amend() {
		# amend a value ($1) by @editors
		local amended=$1 digital=false editor
		# TODO: use Bash built-in let function
		test "$1" -eq "$1" 2>/dev/null && digital=true
		for editor in "${editors[@]}"; do case ${editor:0:1} in
			+) $digital && ((amended+=${editor:1})) || amended+=${editor:1};;
			-) $digital && ((amended-=${editor:1})) || amended=${amended//${editor:1}};;
			/) $digital && ((amended/=${editor:1})) || amended=${amended%${editor:1}*};;
			%) $digital && ((amended%=${editor:1})) || amended=${amended#*${editor:1}};;
		esac done
		echo -n "$amended"
	}
	argue-apply() { # apply a value ($1) to @varname and @functor
		local value=$(argue-amend "$1")
		if [[ $certain && $control ]]; then
			value=${certain//\{\}/$value}
		fi
		if [[ $varname ]]; then
			if [[ ${varname:0:4} == 'env.' ]]; then
				export ${varname:4}=$value
			elif [[ ${varname: -2} != '[]' ]]; then
				eval "$varname='$value'"
			elif [[ $value ]]; then
				eval "${varname%[]}+=('$value')"
			fi
		fi
		if [[ $functor ]] && ! $functor "$value"; then
			argue-abort "$value # failed to apply the value"
		fi
	}
	local checked
	argue-check() { # check a value ($1) by @control
		checked=''; local checker
		for checker in "${control[@]}"; do
			if [[ $checker =~ ^/(.+)/$ ]]; then
				if ! [[ $1 =~ ^${BASH_REMATCH[1]}$ ]]; then
					checked="invalid value; expected a regular expression: $checker"
					return 1
				fi
			elif [[ $checker =~ ^\{(.+)\}$ ]]; then
				if ! [[ $1 =~ ^(${BASH_REMATCH[1]//,/|})$ ]]; then
					checked="invalid value; expected one of $checker"
					return 1
				fi
			elif [[ $checker =~ ^\[(-?[0-9]+)\.+(-?[0-9]+)\]$ ]]; then
				local minimum=${BASH_REMATCH[1]} maximum=${BASH_REMATCH[2]}
				if ! [[ $1 =~ ^-?[0-9]+$ && $1 -ge $minimum && $1 -le $maximum ]]; then
					checked="invalid value; expected a number in interval $checker"
					return 1
				fi
			elif [[ $checker =~ ^\<([0-9]+)\.+([0-9]+)\>$ ]]; then
				local minimum=${BASH_REMATCH[1]} maximum=${BASH_REMATCH[2]}
				if [[ ${#1} -lt $minimum ]]; then
					checked="too short; expected minimum $minimum characters"
					return 1
				elif [[ ${#1} -gt $maximum ]]; then
					checked="too long; expected maximum $maximum characters"
					return 1
				fi
			elif [[ $checker =~ ^\((.+)\)$ ]]; then
				if ! checked=$(eval ${BASH_REMATCH[1]//\{\}/\'$1\'} 2>&1); then
					return 1
				fi
			elif [[ $checker =~ ^\|(.+)\|$ ]]; then
				local masking=${BASH_REMATCH[1]} index=0
				for ((; index <= ${#masking}; index++)); do
					local char=${1:$index:1} mask=${masking:$index:1} regular=''
					if ((${#mask})) && regular=${ARGUE_MASKS[$mask]} && ((${#regular}))
						then [[ $char =~ ^$regular$ ]]; else [[ $char == $mask ]]; fi
					if [[ $? -ne 0 ]]; then
						((${#char})) && checked="invalid character '$char'" || checked="unexpected end of string"
						checked="$checked at position $index; expected ${regular:-'${mask:-<end of string>}'}"
						return 1
					fi
				done
			else
				argue-abort "unsupported value checker: $checker"
			fi
		done
		: ${checked:=$1}
	}
	argue-enter() {
		local options=(-e -p "$1" -i "$entered" entered)
		if [[ ${measure^^} == PASSWORD ]]
			then read -s "${options[@]}" && printf "\e[1A$1${entered//?/*}"
			else read "${options[@]}" && printf "\e[1A$1${entered}"
		fi
	}
	argue-input() { # input argument from stdin
		#if [[ $varname && ${!varname} ]]; then return; fi
		case $meaning in (disabled|internal) return 1;; esac
		local entered='' consent='y|yes' dissent='n|no' counter=0
		echo -n "${comment-${varname-$argkeys}}${measure+ <$measure>:} "
		if [[ ${pattern#*)} || $argkeys =~ ^${ARGUE_BREAK// /|}$ ]]; then
			echo "${control[@]#(*)}${default+ (default: '$default')} $several"
			local yesorno=false
		else
			echo "($consent|$dissent) (default: ${dissent##*|})"
			local yesorno=true
		fi
		while argue-enter "   $meaning > "; do
			if [[ $entered ]]; then
				if ! $yesorno; then
					if ! argue-check "$entered"; then
						echo " # $checked!" && continue
					fi
					argue-apply "$checked"; ((counter++))
				elif [[ ! $entered =~ ^($consent|$dissent)$ ]]; then
					echo " # invalid value; expected ($consent|$dissent)"; continue
				elif [[ $entered =~ ^($consent)$ ]]; then
					argue-apply "${certain:-$entered}"
					((counter++))
				fi
				if [[ $command ]] && ((counter)); then
					ARGUE_TORUN+=("$command")
				fi
				echo " # OK"
			elif (($counter == 0)); then
				if [[ $meaning == required ]]; then
					echo "# empty value of required argument!"; continue
				elif [[ ${default+x} ]]; then
					argue-apply "$default"
				fi
				if [[ $yesorno == true ]]; then
					echo "${dissent##*|} # by default"
				elif [[ ${default+x} ]]; then
					echo "$default # by default"
				else echo "# none"
				fi
			else echo "# done"
			fi
			meaning=optional
			[[ ! $entered || ! $several ]] && break
			entered=''
		done; echo
	}
	argue-parse() {
		ARGUE_ARRAY=()
		local counter=0
		while (("$#")); do
			# parse terminal arguments
			if [[ $1 =~ ^(${ARGUE_BREAK// /|}$) ]]; then
				if [[ $1 =~ ^(${argkeys//,/|})$ ]]; then
					while shift && (("$#")); do
						argue-apply "$1"
						((counter++))
					done
				else ARGUE_ARRAY+=("$@"); fi
				break
			elif [[ $1 =~ ^$pattern$ ]]; then
				local value=${BASH_REMATCH[2]}
				if [[ $meaning == disabled ]]; then
					argue-abort "$1 # argument is disabled ${warning:+($warning)}"
				elif [[ ! $several && $counter -gt 0 ]]; then
					argue-abort "$1 # duplication of a unique argument!"
				elif [[ ${#control[@]} -gt 0 ]]; then
					if ! argue-check "${value}"; then
						argue-abort "$1 # ${checked:-invalid value}"
					else
						argue-apply "$checked"
					fi
				else
					argue-apply "${certain-$1}"
				fi
				((counter++))
			else # put back unparsed argument
				ARGUE_ARRAY+=("$1")
			fi
			shift
		done
		if (($counter == 0)); then
			if [[ $meaning == required ]]; then
				argue-abort "${argkeys//,/, }" \
					"# required argument is missed or has invalid value"
			elif [[ ${default+x} ]]; then
				 argue-apply "$default"
				 return 1
			fi
		elif [[ $command ]]; then
			if [[ $meaning != internal ]]; then
				ARGUE_TORUN+=("$command")
			else # run instantly
				eval "$command"
			fi
		fi
	}

	local feature
	for feature in ${!ARGUE_INNER[@]}; do
		[[ $ARGUE_FIRST =~ ^(${ARGUE_INNER[$feature]})$ ]] || continue
		[[ $measure == $feature && $command ]] && eval "$command"
		argue-$feature "${ARGUE_ARRAY[1]}"
		ARGUE_STATE=$feature; return 0
	done

	argue-parse "${ARGUE_ARRAY[@]}"
	if ((${#ARGUE_ARRAY[@]})); then
		# there are extra arguments
		ARGUE_STATE=extra
	else
		ARGUE_STATE=ready
	fi
	return $?
}

# setup auto completion
argue-setup() {
	local utility=${1:-${0##*/}}
	local feature=${ARGUE_INNER[offer]/|*}

	if [[ ! $feature ]]; then
		argue-abort 'offer feature is disabled!'
	fi

	if [[ ! $(which $utility) ]]; then
		if [[ $PATH =~ (/usr/local/bin)(:|$) ]]
			then local linkdir=${BASH_REMATCH[1]}
			else local linkdir=${PATH%%:*}
		fi
		if [[ ! $linkdir || ! -w $linkdir ]]; then
			argue-abort "unable to create symbolic link for $utility in $linkdir (try with sudo)"
		fi
		# create symbolic link for utility to make it visible
		ln -sf "$(readlink -f $0)" $linkdir/$utility
	fi

	local shell message
	for shell in bash fish zsh; do
		if ! message=$(argue-setup-$shell $utility $feature); then
			argue-error "unable to set up ${shell^} completion: $message"
		else
			echo "${shell^} completion was successfully set up for $utility!"
		fi
	done

	exit 0
}

argue-setup-bash() {
	local utility=$1 feature=$2
	local catalog=${BASH_COMPLETION_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion}/completions
	if [[ ! -d $catalog ]]; then
		if ! mkdir -p $catalog ]]; then
			echo 'cannot create completion directory'
			return 1
		fi
	elif [[ -f $catalog/$utility ]]; then
		if [[ ! -w $catalog/$utility ]]; then 
			echo 'cannot access existent completion file'
			return 1
		fi
	elif [[ ! -w $catalog ]]; then
		echo 'cannot access completion directory'
		return 1
	fi
	local handler="_${utility//[[:punct:]]/_}_completion"
	cat > $catalog/$utility << EOT
$handler() {
  local cur
  _get_comp_words_by_ref -n = cur
  readarray -t COMPREPLY < <($(readlink -f $0) $feature \$cur 2> /dev/null)
}
complete -o nospace -F $handler $utility
EOT
}

argue-setup-fish() {
	local utility=$1 feature=$2
	if [[ ! $(command -v fish) ]]; then
		echo 'fish not installed'
		return 1
	fi
	local catalog="$HOME/.config/fish/completions"
	if [[ ! -d $catalog ]] && ! mkdir -p $cannot; then
		echo 'cannot create completion directory'
		return 1
	fi
	local handler="_complete_${utility//[[:punct:]]/_}"
	cat > $catalog/$utility.fish << EOT
function $handler
	set -l token (commandline --current-token)
	
	$(readlink -f $0) $feature \$token | read -z -l -a args

	if string match -q -- "*=*" "\$token"
		set token (string replace -r -- "=.*" "" "\$token")
		printf "\$token=%s\n" \$args
	else
		set -l arg
		for arg in \$args
			printf "\$arg\tdescription for \$arg\n"
		end
	end
end
complete -x -c $utility -a '($handler)'
EOT
}

argue-setup-zsh() {
	local utility=$1 feature=$2
	if [[ ! $(command -v zsh) ]]; then
		echo 'zsh not installed'
		return 1
	fi
	local catalog=$(zsh -c 'echo ${fpath[1]}' 2>/dev/null)
	if [[ ! $catalog ]]; then
		echo 'cannot determine a directory for completion functions'
		return 1
	elif [[ ! -d $catalog ]] && ! mkdir -p $catalog 2>/dev/null; then
		echo "cannot create completion directory: $catalog (try with sudo)"
		return 1
	elif [[ ! -w $catalog ]]; then
		echo "cannot access completion directory: $catalog (try with sudo)"
		return 1
	fi
	cat > $catalog/_$utility << EOT
#compdef $utility
local args=(\${(f)"\$($(readlink -f $0) $feature "\$PREFIX" 2>/dev/null)"})

if compset -P '*='; then
	compadd -- "\${args[@]% }"
else
	local arg
	for arg in "\${args[@]}"; do
		if [[ \${arg: -1} == '=' ]]; then
			compadd -S '' -- "\$arg"
		else
			compadd -- \${arg% }
		fi
	done
fi
EOT
}
