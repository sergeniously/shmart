
GIT_BRANCH=$(git branch --show-current 2> /dev/null)
GIT_ROOT=$(git rev-parse --show-toplevel 2> /dev/null)
GIT_DIR=$(git rev-parse --absolute-git-dir 2>/dev/null)

git-offer-branch() {
	local branch
	while read branch; do
		branch=${branch#\* }
		if [[ $branch =~ ^$1 ]]; then
			echo "$branch "
		fi
	done < <(git branch --list 2>/dev/null)
}
