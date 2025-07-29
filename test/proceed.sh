#!/usr/bin/env bash

source $(dirname $0)/../core/proceed.sh

PROCEED_DEBUG=true
PROCEED_LOG_TO=/dev/stdout

proceed to hello do cat from stdin < <(echo Hello, World!)

sleep_for() {(
    for ((sec = 1; sec <= $1; sec++)); do
        echo sleeping $sec second; sleep 1
    done
)}

proceed to 'sleep for 3 seconds' \
	do 'sleep_for 3' in /dev/stdout

proceed to 'count down' \
    do 'echo three' do 'sleep 1' \
    do 'echo two' do 'sleep 1' \
    do 'echo one' do 'sleep 1' \
    on EXIT in /dev/stderr

dir='/tmp/dir 123'
if proceed to "make directory $dir" do { mkdir -vp "$dir" } do { chmod -v 755 "$dir" }; then
    proceed to 'clean up' do { rm -vrf "$dir" } on EXIT
fi

for dir in /tmp /etc; do
	if proceed to "make temp dir in $dir" do "mktemp -d $dir/serg.XXXX" at temp_dir; then
		proceed to "rm -vrf $temp_dir" on EXIT
	fi
done

for file in '/tmp/file' '/etc/file' "${HOME}/file"; do
    if proceed to "create $file" do "touch $file"; then
        proceed to "rm -vf $file" on EXIT
    fi
done

echo "Trapped commands:"
trap -p EXIT
echo
