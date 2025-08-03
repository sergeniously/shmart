#!/usr/bin/env bash

srcdir=$(dirname $(readlink -f $0))
source $srcdir/core/argue.sh
source $srcdir/core/input.sh
source $srcdir/core/progress.sh

about() {
	echo 'Find personal computer IP addresses by their MAC addresses'
	echo -e '\ua9 Belenkov Sergei, 2021 <https://github.com/sergeniously/shmart>'
}

argue initiate "$@"
argue defaults offer input guide usage setup
argue required -mac=.+ ... of MAC at macs[] ? '|HH:HH:HH:HH:HH:HH|' \
	as 'MAC addresses to find'
argue optional -net="[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" of IP at net or '192.168.111' \
	as 'IP prefix of network to scan'
argue optional -min=.+ ? '[0..255]' of number at min or 0 \
	as 'Minimal position to start'
argue optional -max=.+ ? '[0..255]' of number at max or 255 \
	as 'Maximal position to stop'
argue optional -no-scan at do_scan = false or true \
	as 'Proceed without scanning?'
argue finalize

if $do_scan; then
	for (( ip = $min; ip <= $max; ip++ )); do
		progress in 'Scanning IP addresses' is $(( $ip - $min )) of $(( $max - $min )) as '[!.]'
		ping -c 1 -W 1 -q $net.$ip &> /dev/null
	done; echo
fi

pcs=()
while read line; do
	for mac in ${macs[*]}; do
		if [[ $line =~ ^.*\(([0-9.]+)\)\ at\ $mac.*$ ]]; then
			ip=${BASH_REMATCH[1]}
			pcs+=("$ip $mac")
		fi
	done
done < <(arp -a)

if (( ${#pcs[@]} )); then
	printf "Found a computer IP %s with MAC %s\n" ${pcs[*]}
	exit 0
fi

echo "No computer has been found"
exit 1
