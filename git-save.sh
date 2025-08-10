#!/usr/bin/env bash

srcdir=$(dirname $(readlink -f $0))
source $srcdir/core/proceed.sh
source $srcdir/core/argue.sh
source $srcdir/core/json.sh

PROCEED_LOG_TO=/dev/stdout

about() {
	echo 'Create or update commits with specific messages and problems checking.'
	echo -e '\ua9 Belenkov Sergei, 2021-2025 <https://github.com/sergeniously/shmart>'
	echo
}

get_tfs_api() {
	local url=$(git config tfs.api 2>/dev/null)
	if [[ ! $url && $(git config remote.origin.url 2>/dev/null) =~ ^(ssh|https)://([^:/]+)(:[0-9]+)?/(tfs/[^/]+) ]]; then
		url="https://${BASH_REMATCH[2]}/${BASH_REMATCH[4]}"
	fi
	echo -n "$url"
}

get_tfs_username() {
	local email=$(git config user.email 2>/dev/null)
	echo -n ${email%%@*}
}

get_tfs_password() {
	if [[ $tfs_api && $tfs_username ]]; then
		local tfs_hostname=${tfs_api#*//}; tfs_hostname=${tfs_hostname%%/*}
		if read -es -p "Enter a password for $tfs_username@$tfs_hostname: " tfs_password; then
			[[ $tfs_password ]]
		fi
	fi
	return $?
}

argue initiate "$@"
argue terminal '//'
argue defaults offer guide usage setup
argue optional -tfs-api=https://.+ of URL or "$(get_tfs_api)" at tfs_api \
	as 'TFS REST API prefix to download TFS items details'
argue optional -tfs-username=.+ of NAME or "$(get_tfs_username)" at tfs_username \
	as 'TFS username to authenticate on TFS REST API service'
argue optional all,changed at content_type or changed \
	as 'Which files must be staged for a commit?'
argue optional new at should_create = true or false \
	as 'Create a new commit?'
argue optional old at should_update = true or false \
	as 'Update a previous commit?'
argue optional force at should_check = false or true \
	as 'Do not check for conflicts or whitespace errors'
argue optional tfs ? /[0-9]+/ of ID ... at tfs_items[] \
	as 'TFS item IDs to get a message for a commit'
argue optional message=.+ of TEXT ... at messages[] \
	as 'Separate commit messages'
argue optional // ? /.+/ of MESSAGE ... at comments[] \
	as 'Absolute commit message'
argue finalize

if ((${#comments[@]})); then
	messages+=("${comments[*]}")
fi

download_tfs_items() {
	local wget_options=(
		-q --content-on-error -O- --no-proxy
		--http-user=$tfs_username --http-password="$tfs_password"
	)
	for tfs_item in ${tfs_items[@]}; do
		if json parse < <(wget "${wget_options[@]}" "$tfs_api/_apis/wit/workitems/$tfs_item"); then
			if [[ ${JSON[.id]} ]]; then
				local type=${JSON[.fields.System.WorkItemType]/Bug/Bugfix}
				type=${type/Product Backlog Item/PBI}
				local title=${JSON[.fields.System.Title]}
				messages+=("$type #$tfs_item: $title")
				echo "${messages[-1]}"
				continue
			fi
			echo "${JSON[.message]}"
		fi
		return 1
	done
}

has_changes() {
	local changes
	case $content_type in
		changed)
			changes=$(git status --short --untracked-files=no);;
		all)
			changes=$(git status --short);;
	esac
	[[ $changes ]]
}

add_changes() {
	case $content_type in
		changed)
			git add -u;;
		all)
			git add -A;;
		*)
			return 1;;
	esac
}

has_commits() {
	[[ $(git cherry -v 2>/dev/null) ]]
}

restore_change_id() {
	if [[ ${#messages[@]} -gt 0 ]]; then
		local line; while read -r line; do
			if [[ $line =~ (Change-Id:\ I[0-9A-Fa-f]+) ]]; then
				messages+=("${BASH_REMATCH[1]}")
			fi
		done < <(git log -1 --pretty=%B)
	fi
}

if ((${#tfs_items[@]} > 0)) && get_tfs_password; then
	proceed to "download TFS items: ${tfs_items[*]/#/#}" or die do { download_tfs_items }
fi

if ! has_changes && ! ((${#messages[@]})); then
	echo "There are no suitable changes to commit."
	exit 0
fi

if $should_check; then
	proceed to 'check changes' do { git diff --check } or die
fi

proceed to 'stage changes' do add_changes or die

options=()

if $should_create; then
	if !((${#messages[@]})); then
		while ! read -ep 'Input a message for a new commit: ' message || [[ ! $message ]]; do
			printf "Message is required for a new commit!\n\n"
		done
		messages+=("$message")
	fi
elif $should_update || has_commits; then
	# update the last local commit
	options+=(--amend --no-edit)
	restore_change_id
else
	echo "There are no unpushed commits to update!"
	echo "Run again with 'new' or 'old' option."
	exit 1
fi

for message in "${messages[@]}"; do
	options+=(-m "${message//[\'\"]}")
done

proceed to 'commit changes' do { git commit "${options[@]}" }
