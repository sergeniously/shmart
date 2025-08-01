# About:
#  print colorful log with specific priority and exit on error
# Usage:
#  log priority messages ...
#  log priority %clr:words "message1" %clr:[mask] "message2" ...
# Where:
#  @priority:
#   error   (level 1): error conditions
#   warning (level 2): warning conditions
#   notice  (level 3): normal but significant condition
#   info    (level 4): informational
#   debug   (level 5): debug-level messages
#   <other> (level 5): another user defined type (e.g: todo)
#  %clr:words: color format in words/comma (e.g: %clr:bold,red) *
#  %clr:[mask]: color format mask characters (e.g: %clr:[!r]) *
#    * see color.sh for details.
# Author:
#  Belenkov Sergey, 2023-2025
# TODO:
#  + API to configure preset or custom priority with custom level and color
#  + option LOG_TIMES=true|false to optionally print date and time

source ${BASH_SOURCE[0]%/*}/color.sh

# external options (could be changed outside):
declare LOG_PANIC=true # exit 1 immediately on error
declare LOG_TITLE=true # print basename and priority
declare -i LOG_LEVEL=5 # default log level: print everything

# internal variables (DO NOT changed outside):
declare -a LOG_COLOR # array of colors by levels
declare -A LOG_COUNT # array of priority counters
declare -A LOG_ORDER # array of levels by priorities

LOG_ORDER[error]=1
LOG_ORDER[warning]=2
LOG_ORDER[notice]=3
LOG_ORDER[info]=4
LOG_ORDER[debug]=5

LOG_COLOR=(
	none
	red
	yellow
	cyan
	green
	white
)

log_count() {
	local priorities=($@)
	local priority count=0
	if [[ "$#" -eq 0 ]]; then
		priorities=(${!LOG_ORDER[@]})
	fi
	for priority in ${priorities[@]}; do
		((count+=${LOG_COUNT[$priority]-0}))
	done
	echo $count
}

log () {
	local level=${LOG_ORDER[$1]:-5}
	if [[ "$#" -lt 2 || $level -gt $LOG_LEVEL ]]; then
		return # do not print empty log or which is out of level
	fi

	local utility=${0##*/}
	local priority=$1; shift

	if $LOG_TITLE; then
		color purple ${LOG_COLOR[$level]}
		printf "${COLORS[1]}%s ${COLORS[2]}%7s${COLORS[0]}: " \
			"$utility" "${priority^^}"
	fi

	while (("$#")); do case $1 in
		%clr:*) color ${1#\%clr:}
			echo -ne "${COLORS[1]}${2}${COLOR0} "
			shift; shift;;
		*) [[ "$#" -eq 1 && $1 == \\ ]] && break
			echo -ne "$1 ";
			shift;;
	esac done
	[[ $1 == \\ ]] || echo

	LOG_COUNT[$priority]=$((${LOG_COUNT[$priority]:-0}+1))

	if $LOG_PANIC && [[ $level -eq 1 ]]; then
		exit 1
	fi
}
