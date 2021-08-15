#!/bin/bash

source $(dirname $0)/../input.sh

input // 'Enter username > ' \
	at username as "[a-zA-Z0-9_]*" no 'invalid username' or 'anonym'
input // 'Enter password > ' \
	at password as "[a-zA-Z0-9_]+" by '*'
input // 'Enter somewhat > ' \
	at somewhat = 'hello, world!' or 'hello, kitty!'

echo
echo "Username: $username"
echo "Password: $password"
echo "Somewhat: $somewhat"
