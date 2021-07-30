#!/bin/bash

# Shows progress of any number of any amount
# Usage:
#  progress [in comment] is portion [of content] [as filling] [on breadth]
# Where:
#  @comment: a description of what is going on
#  @portion: a number of completed parts of content or percentage (X%)
#  @content: a number of total amount
#  @filling: a character or a string for filling a progress bar
#  @breadth: a width of progress bar
# Examples:
#  progress in scanning is 50 of 100
#  progress in watching is 70%
#  progress in training is 7 of 13
#  progress in sleeping is 3 of 10 as '#' on 100
progress() {
	local comment portion=0 content=100
	local percent=0 breadth=80 filling=.
	while (( "$#" )); do case $1 in
		in) comment=$2; shift 2;;
		is) portion=$2; shift 2;;
		of) content=$2; shift 2;;
		as) filling=$2; shift 2;;
		on) breadth=$2; shift 2;;
		*) shift 1;;
	esac done
	if [[ ! $portion =~ ^[0-9]{1,2}%$ ]]; then
		percent=$((( $portion * 100 / $content )))
	else
		percent=${portion%\%}
	fi

	local display
	printf -v display "%*s" "$(( $percent * $breadth / 100 ))" ""
	display=${display// /$filling}
	printf "\r%s [%-*s] %3d%%" "$comment" "$breadth" "$display" "$percent"
	if [[ $percent -eq 100 ]]; then
		echo
	fi
}
