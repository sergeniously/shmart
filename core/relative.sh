
# About:
#  calculate a path relative to another path
# Author:
#  Belenkov Sergey, 2023
# Usage:
#  relative path1 path2
# Examples:
#  see test/relative.sh

relative() {
	local path1=(${1//\// })
	local path2=(${2//\// })
	local index=0 rpath

	while [[ ${path1[$index]} && ${path1[$index]} == ${path2[$index]} ]]; do
		# skip equal elements of paths
		((index++)); done

	while [[ ${path1[$index]} || ${path2[$index]} ]]; do
		if [[ ${path1[$index]} ]]; then
			rpath+="${path1[$index]}/"
		fi
		if [[ ${path2[$index]} ]]; then
			rpath="../${rpath}"
		fi
		((index++))
	done
	# delete last slash
	echo ${rpath%/}
}
