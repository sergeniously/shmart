
# Shows progress of any number of any amount
# Usage:
#  progress [in comment] is portion [of summary] [as pattern] [on breadth] [// comment...]
# Where:
#  @comment: a description of what is going on (default: progress)
#  @portion: a number of completed parts of total amount or percentage (X%)
#  @summary: a number of total amount (required if portion is not percentage)
#  @pattern: a format string of progress bar (default: '[#.]'), where:
#   - 1st char: opening brace of progress bar
#   - 2nd char: filling char of progress bar
#   - 3rd char: spacing char of progress bar
#   - 4th char: closing brace of progress bar
#  @breadth: a width of progress bar (default: 100)
# Examples:
#  progress in scanning is 50 of 100
#  progress in watching is 70%
#  progress in training is 7 of 13
#  progress in sleeping is 3 of 10 as '(# )' on 100
progress() {
	local comment portion=0 summary=0
	local breadth=100 pattern='[#.]'
	while (( "$#" )); do case $1 in
		in) comment=$2; shift 2;;
		is) portion=$2; shift 2;;
		of) summary=$2; shift 2;;
		as) pattern=$2; shift 2;;
		on) breadth=$2; shift 2;;
		//) shift; comment="$@";
			shift $#;;
		*) shift 1;;
	esac done
	if [[ $portion =~ ^[0-9]+%$ ]]; then
		portion=${portion%\%}; summary=100
	fi
	if [[ $portion -gt $summary || $summary -eq 0 ]]; then
		echo -en "\rInvalid progress: $portion of $summary"
		return 1
	fi

	local percent=$(( $portion * 100 / $summary ))
	local filling=$(( $percent * $breadth / 100 ))
	local spacing=$(( $breadth - $filling))
	printf -v filling '%*s' $filling; filling=${filling// /${pattern:1:1}}
	printf -v spacing '%*s' $spacing; spacing=${spacing// /${pattern:2:1}}
	printf "\r%s ${pattern:0:1}%s%s${pattern:3:1} %3d%%" \
		"$comment" "$filling" "$spacing" "$percent"
}
