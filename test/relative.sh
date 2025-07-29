#!/usr/bin/env bash

source $(dirname $0)/../core/relative.sh

if (("$#")); then
	pairs=("$@")
else
	pairs=(
		install/usr/share/cts/lib install/usr/share/cts/bin
		install/usr/share/cts/lib install/usr/share/cts/lib/engine
		install/usr/share/cts/lib install/usr/share/cts/plugins/bearer
		install/usr/share/cts/lib install/usr/share/cts/lib
		install/usr/share/cts/lib install/usr/share/cts
		'' ''
	)
fi

while read path1 path2; do
	echo "test relative '$path1' '$path2' => " $(relative "$path1" "$path2")
done < <(printf "%s %s\n" ${pairs[@]})
