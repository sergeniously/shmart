
# About:
#  Native Bash JSON parser source module to use in other scripts.
#  Parses JSON from stdin and stores values into JSON associative array with JSON paths.
# Author:
#  Belenkov Sergei, 2025.07
# Usage:
#  > json parse [.json.path]...
#    * parse everything [or only specific JSON paths]
#  > json value .json.path ...
#    * print specific parsed values for specific JSON paths
#  > json count .json.path
#    * count specific parsed JSON paths
#  > json error
#    * print what happend and where (if failed):
# Where:
#  @.json.path: JSON path or its wildcard pattern
# TODO:
#  + json format "{P}={V}" .json.path ...

# Public variables:
# callback to save a value (can be overrided)
# by default stores a value to JSON ass-array
# should return 1 to stop the parse procedure
JSON_SAVE=json_save # (type, path, value)
# associative array to store values
declare -A JSON
JSON_KEYS=() # parsed JSON paths in order

# Private variables:
JSON_NOTE='' # JSON parsing note
JSON_CHAR='' # current char for parsing
JSON_PATH='' # current path for parsing
JSON_LINE=0  # current read line number
JSON_STEP=0  # current read position
# the only JSON paths to be stored:
JSON_SIFT=()

json() {
	case $1 in
		parse) shift
			json_reset "$@"
			json_value
			return $?;;

		value) shift
			local path
			while (("$#")); do
				if [[ ${1//\*} != "$1" ]]; then
					for path in "${JSON_KEYS[@]}"; do
						if json_match $path "$1"; then
							printf -- "${JSON[$path]}\n"
						fi
					done
				else
					printf -- "${JSON[$1]-null}\n"
				fi
				shift
			done;;

		count) shift
			local path count=0
			for path in "${JSON_KEYS[@]}"; do
				if json_match $path "$1"; then
					((++count))
				fi
			done
			echo $count
			return 0;;

		error) # TODO: support $2 format
			echo "json error: ${JSON_NOTE}" \
				"but not '${JSON_CHAR}'" \
				at $JSON_LINE:$JSON_STEP
			return 0;;

		*) echo "json: invalid action: $1"
			return 1;;
	esac
}

# Match json path with wildcard pattern
json_match() {
	wild=${2//\[/\\[}
	wild=${wild//\]/\\]}
	wild=${wild//\*/[^.]+}
	[[ $1 =~ ^$wild$ ]]
}

# Reset json internals before parsing
json_reset() {
	JSON_SIFT=("$@")
	JSON_KEYS=()
	JSON_PATH=''
	JSON_LINE=1
	JSON_STEP=0
	JSON=()
}

json_blank() {
	[[ $JSON_CHAR =~ [[:space:]] ]]
}

json_read() {
	if read -rN1 JSON_CHAR; then
		((++JSON_STEP))
		if [[ $JSON_CHAR == $'\n' ]]; then
			((++JSON_LINE))
			JSON_STEP=0
		fi
		return 0
	fi
	return 1
}

# Callback to store json value
json_save() {
	#type=$1 path=$2 value=$3
	if ((${#JSON_SIFT[@]})); then
		local wildcard; for wildcard in "${JSON_SIFT[@]}"; do
			if json_match $2 "$wildcard"; then
				JSON_KEYS+=($2)
				JSON[$2]=$3
			fi
		done
	else
		JSON_KEYS+=($2)
		JSON[$2]=$3
	fi
}

json_name() {
	while json_read; do
		if json_blank; then
			continue
		elif [[ $JSON_CHAR == '"' ]]; then
			break
		else
			JSON_NOTE='expected JSON keyid'
			return 1
		fi
	done
	JSON_NAME=''
	while json_read; do
		if [[ $JSON_CHAR == '"' ]]; then
			break
		elif [[ ! $JSON_CHAR =~ [\$0-9A-Za-z/_.-] ]]; then
			JSON_NOTE='expected key id character'
			return 1
		fi
		JSON_NAME+=$JSON_CHAR
	done
	# consume the rest blanks
	while json_read; do
		if ! json_blank; then
			break
		fi
	done
}

json_value() {
	while json_read; do
		if json_blank; then
			continue
		elif [[ $JSON_CHAR == '[' ]]; then
			json_array || return 1; json_read
		elif [[ $JSON_CHAR == '{' ]]; then
			json_object || return 1; json_read
		elif [[ $JSON_CHAR == '"' ]]; then
			json_string || return 1; json_read
		elif [[ $JSON_CHAR =~ [a-z] ]]; then
			json_keyword || return 1
		elif [[ $JSON_CHAR =~ [0-9+-] ]]; then
			json_number || return 1
		else
			JSON_NOTE='expected JSON value'
			return 1
		fi
		break
	done
	# consume the rest blanks
	while json_blank; do
		json_read
	done
	return 0
}

json_array() {
	local suffix
	local index=0
	while true; do
		suffix=[$index]
		JSON_PATH+=$suffix
		if ! json_value && [[ $JSON_CHAR != ']' ]]; then
			return 1
		fi
		JSON_PATH=${JSON_PATH%"$suffix"}
		if [[ $JSON_CHAR == ',' ]]; then
			((++index))
			continue
		elif [[ $JSON_CHAR == ']' ]]; then
			return 0
		else
			JSON_NOTE="expected ',' or ']'"
			return 1
		fi
	done
}

json_object() {
	local name
	while true; do
		if ! json_name; then
			[[ $JSON_CHAR == '}' ]]
			return $?
		elif [[ $JSON_CHAR != ':' ]]; then
			JSON_NOTE="expected ':'"
			return 1
		fi
		name=$JSON_NAME
		JSON_PATH+=.$name
		if ! json_value; then
			return 1
		fi
		JSON_PATH=${JSON_PATH%.$name}
		if [[ $JSON_CHAR == ',' ]]; then
			continue
		elif [[ $JSON_CHAR == '}' ]]; then
			return 0
		else
			JSON_NOTE="expected ',' or '}'"
			return 1
		fi
	done
}

json_string() {
	local value
	while json_read; do
		if [[ $JSON_CHAR == '"' ]]; then
			if [[ ${value: -1} != '\' ]]; then
				$JSON_SAVE string "$JSON_PATH" "$value"
				return $?
			fi
		fi
		value+=$JSON_CHAR
	done
}

json_number() {
	local value=$JSON_CHAR
	while json_read; do
		if [[ ! $JSON_CHAR =~ [0-9.] ]]; then
			if [[ ! $value =~ ^[+-]?[0-9]+(\.[0-9]+)?$ ]]; then
				JSON_NOTE='expected JSON number'
				return 1
			fi
			$JSON_SAVE number "$JSON_PATH" "$value"
			return $?
		fi
		value+=$JSON_CHAR
	done
}

json_keyword() {
	local value=$JSON_CHAR
	while json_read; do
		if [[ ! $JSON_CHAR =~ [a-z] ]]; then
			if [[ ! $value =~ ^(null|true|false)$ ]]; then
				JSON_NOTE='expected one of JSON keyword: true, false, null'
				return 1
			else
				$JSON_SAVE keyword "$JSON_PATH" "$value"
				return $?
			fi
		fi
		value+=$JSON_CHAR
	done
}
