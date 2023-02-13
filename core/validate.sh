
# validate required|optional varname by pattern [or default]
# examples:
#   validate required var1 by "pattern"
#   validate optional var2 by "pattern" or 'default'
validate() {
	local meaning varname pattern default
	while (( $# )); do case $1 in
		optional|required)
			meaning=$1 ; varname=$2 ; shift 2 ;;
		by) pattern=$2 ; shift 2 ;;
		or) default=$2 ; shift 2 ;;
		*) echo "Error: invalid validation option $1"; exit 1 ;;
	esac done

	if [[ ! -v $varname ]]; then
		if [[ $meaning == required ]]; then
			echo "Error: missed required variable $varname"
			exit 1
		fi
		declare -g "$varname=$default"
	elif [[ ! ${!varname} =~ ^$pattern$ ]]; then
		echo "Error: invalid value '${!varname}' of variable $varname; expected $pattern"
		exit 1
	fi
}
