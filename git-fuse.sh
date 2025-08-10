#!/usr/bin/env bash

srcdir=$(dirname $(readlink -f $0))
source $srcdir/core/git.sh
source $srcdir/core/argue.sh
source $srcdir/core/input.sh
source $srcdir/core/proceed.sh

about() {
	echo "Merge changes from one branch into another."
	echo -e '\ua9 Belenkov Sergei, 2021-2025 <https://github.com/sergeniously/shmart>'
}

branch_pattern='[0-9A-Za-z/_.-]+'

argue initiate "$@"
argue defaults offer guide usage setup
argue optional from=$branch_pattern of BRANCH at source_branch or "$GIT_BRANCH" @ git-offer-branch \
	as 'Source branch'
argue required into=$branch_pattern of BRANCH at target_branch @ git-offer-branch \
	as 'Target branch'
argue finalize

if [[ $target_branch == $source_branch ]]; then
	echo "Target branch must differ from source branch!"
	exit 1
fi

proceed to "checkout $target_branch branch" \
	do { git checkout origin/$target_branch } or die

proceed to "merge $source_branch into $target_branch" \
	do { git merge --no-ff --no-commit origin/$source_branch } or die

input // "Confirm or modify commit message:\n > " no "'\"" as ".+" ! 'bad message' \
	at commit_message = "merge remote-tracking branch origin/$source_branch into $target_branch"
echo

proceed to 'commit merged changes' \
	do { git commit -m "$commit_message" } or die

input // "It seems everything is alright. Do you want to upload the commit? (yes/no): " \
	at confirmation as "(yes|no)" ! 'do not understand'
echo

if [[ $confirmation == yes ]]; then
	proceed to 'upload the commit' \
		do { git push origin HEAD:refs/for/$target_branch } \
		do { git checkout $target_branch }
fi
