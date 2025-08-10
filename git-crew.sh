#!/usr/bin/env bash

srcdir=$(dirname $(readlink -f $0))
source $srcdir/core/git.sh
source $srcdir/core/argue.sh
source $srcdir/core/proceed.sh

about() {
	echo 'Push local commits to Gerrit code review with specific topics.'
	echo -e '\ua9 Belenkov Sergei, 2021 <https://github.com/sergeniously/shmart>'
}

install-topics() {
	if [[ ${#topics[@]} -gt 0 && $GIT_DIR ]]; then
		if printf "%s\n" "${topics[@]}" >> $GIT_DIR/topics && \
			LC_ALL=C sort -u -o $GIT_DIR/topics $GIT_DIR/topics
		then
			local IFS=/
			echo "Topics {${topics[*]}} are known now for the current repository."
		fi
	else
		echo "Nothing or nowhere to install."
		false
	fi
	exit $?
}

if [[ $GIT_DIR && -f $GIT_DIR/topics ]]; then
	readarray -t known_topics < <(cat $GIT_DIR/topics)
fi

argue initiate "$@"
argue defaults offer guide usage setup
argue optional install ? /.+/ of TOPICS ... do install-topics at topics[] \
	as 'Make topics known for the repository'
argue optional -branch=.+ of BRANCH at branch or "$GIT_BRANCH" @ git-offer-branch \
	as 'Branch to push commits for'
for topic in ${known_topics[@]}; do
	argue optional /$topic at topics[] = $topic \
		as 'Additional preset topic to push commits with'
done
argue optional "/([0-9A-Za-z_-]+)" of TOPIC ... at topics[] \
	as 'Additional custom topic to push commits with'
argue finalize

if [[ ! $GIT_DIR ]]; then
	echo "It seems you are not in a git repository."
	exit 1
elif [[ ! $(git config remote.origin.url) =~ @gerrit ]]; then
	echo "It only works with Gerrit repositories."
	exit 1
fi

while [[ ! $branch || $branch == HEAD ]]; do
	read -p "Input target branch: " -e branch
done

topics=$(IFS=/; echo "${topics[*]}")

if [[ $GIT_BRANCH && $GIT_BRANCH != HEAD ]]; then
	proceed to 'update local branch' do { git pull --rebase } or die
fi

proceed to 'push commits for review' \
	do { git push origin HEAD:refs/for/${branch}${topics:+%topic=$topics} }
