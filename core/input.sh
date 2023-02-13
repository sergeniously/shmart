
# About:
#  input text in smart way supporting: password masking, value completion & validation and default assignment
# Usage:
#  input [at @varname] [= @initial] [as @pattern [! @trouble]] [no @exclude] \
#        [or @default] [by @masking | password] [@ @suggest] [of @choices] [// @comment]
# Where:
#  @varname: a name of variable to store the input value;
#  @initial: an initial string for the inputed value;
#  @pattern: a regular expression to validate the inputed value;
#  @trouble: a message to print if validation of the inputed value fails;
#  @exclude: characters which are not allowed for input;
#  @default: a default value for variable in case the inputed value is empty;
#  @masking: a character to print instead of the inputed characters (use 'password' instead of by '*');
#  @suggest: a command to get completion variants for a value;
#  @choices: a list of possible values separated by comma;
#  @comment: an output text to print before inputing;
# Examples:
#  input // 'Username: ' at username as "[a-z0-9]*" ! 'invalid username' or anonym
#  input // 'Password: ' at password as ".{3,32}" by '*'
#  input // 'Somewhat: ' at somewhat = 'Hello!' or 'Hello!' no "\'\""

declare -g INPUT_VALUE # default variable to store input

input() {
	local varname initial pattern trouble default
	local masking exclude suggest choices comment
	while (( $# )); do case $1 in
		at) varname=$2; shift 2;;
		 =) initial=$2; shift 2;;
		as) pattern=$2; shift 2;;
		 !) trouble=$2; shift 2;;
		no) exclude=$2; shift 2;;
		or) default=$2; shift 2;;
		by) masking=$2; shift 2;;
		of) choices=$2; shift 2;;
		 @) suggest=$2; shift 2;;
		//) comment=$2; shift 2;;
		password)
			masking='*'; shift;;
		*) shift;;
	esac done

	input-offer() {
		if [[ $suggest ]]; then
			$suggest $1
		elif [[ $choices ]]; then
			local variant
			for variant in ${choices//,/ }; do
				[[ $variant =~ ^$1 ]] && echo "$variant"
			done
		fi
	}

	local display=false
	local entered="$initial"
	while echo -ne "$comment"; do
		local snippet="$entered" control
		[[ $masking ]] && snippet=${snippet//?/$masking}
		# FIX: a problem when <double/triple/or more> press of different keys occurs
		# read function (or somewhat else) prints overflown characters despite on -s option
		while read -p "$snippet" -rsN1 snippet && [[ $snippet != $'\n' ]]; do
			if [[ $snippet == $'\177' || $snippet == $'\010' ]]; then
				[[ $entered ]] && snippet=$'\b \b' || snippet=''
				entered=${entered%?} # remove the last char
				continue
			elif [[ $(printf '%d' "'$snippet") -lt 32 ]]; then
				read -rs -t 0.001 control # swallow control sequence
				control="$snippet$control"; snippet=''
				case $control in
					$'\011') # TAB: show/hide password or complete entered text
						if [[ $masking ]]; then
							snippet=${entered//?/$'\b'}
							$display && display=false || display=true
							$display && snippet+=$entered || snippet+=${entered//?/$masking}
						elif local variety=($(input-offer $entered)) && ((${#variety[@]} == 1)); then
							snippet=${variety#$entered}; entered=$variety
						fi;;
					$'\033') # ESC: erase entered text
						snippet=${entered//?/$'\b \b'}; entered='';;
					# $'\033\133\104') # left # TODO
					# $'\033\133\103') # right # TODO
					# $'\033\133\063\176') # delete # TODO
					# *) # print sequence for debug purpose
					# 	snippet+="\$'"; for ((i = 0; i < ${#control}; i++)); do
					# 		snippet+=$(printf '\\%03o' "'${control:$i:1}")
					# 	done; snippet+="'";;
				esac
				continue
			elif [[ $exclude && $exclude =~ $snippet ]]; then
				echo -ne '\007' > /dev/stdout # make a sound
				snippet=''
				continue
			fi
			entered="${entered}${snippet}"
			if [[ $masking ]] && ! $display; then
				snippet=$masking
			fi
		done
		if (($? == 0)); then
			if [[ $pattern && ! $entered =~ ^$pattern$ ]]; then
				echo "${entered:+ }# ${trouble-invalid value; expected: /$pattern/}!"
				continue
			else
				INPUT_VALUE=${entered:-$default}
				[[ $varname ]] && eval "$varname=${INPUT_VALUE@Q}"
				$display && echo -n "${entered//?/$'\b'}${entered//?/$masking}"
				[[ $comment ]] && echo
			fi
		fi
		return $?
	done
}
