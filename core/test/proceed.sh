#!/bin/bash

source $(dirname $0)/../proceed.sh

proceed to 'count down' do 'echo three' do "echo two" do "echo one" on EXIT in /dev/stderr

dir=/tmp/dir
if proceed to "make directory $dir" do "mkdir -vp $dir" do "chmod -v 755 $dir"; then
    proceed to 'clean up' do "rm -vrf $dir" on EXIT
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

sleep_for() (
    for ((sec = 1; sec <= $1; sec++)); do
        echo sleeping $sec second; sleep 1
    done
)

proceed to 'sleep for 10 seconds' do 'sleep_for 10'
