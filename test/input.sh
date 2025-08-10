#!/usr/bin/env bash

source $(dirname $0)/../core/input.sh

offer-gender() {
	local gender
	for gender in male female; do
		[[ $gender =~ ^$1 ]] && echo $gender
	done
}

input // 'Enter username > ' \
	at username as "[a-zA-Z0-9_]*" ! 'invalid username' or 'anonym'
input // 'Enter password > ' \
	at password as "[a-zA-Z0-9_]+" by '*'
input // 'Enter a gender > ' \
	at gender as "(male|female)" @ offer-gender
input // 'Enter somewhat > ' \
	at somewhat = 'hello, world!' no "'\""

echo
echo "Username: $username"
echo "Password: $password"
echo "  Gender: $gender"
echo "Somewhat: $somewhat"
