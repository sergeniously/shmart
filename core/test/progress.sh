#!/bin/bash

source $(dirname $0)/../progress.sh

# show forward progress with different patterns
for pattern in '[#_]' '(!.)' '<+->' '{| }' '|> |' ; do
	for (( percent = 0; percent <= 100; percent++ )); do
		progress in sleeping is $percent% as "$pattern" on 100
		sleep 0.05
	done
	echo
done

# show backward progress (e.g. uninstalling)
for (( percent = 100; percent >= 0; percent-- )); do
	progress in uninstalling is $percent% as '>= <' on 96
	sleep 0.1
done
echo

progress in scanning is 170 of 360
echo
progress in watching is 60 of 240
echo
progress in training is 7 of 13 as '(#_)' on 50
echo
progress is 100 of 50
echo
progress is 1000%
echo