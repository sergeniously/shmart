#!/bin/bash

if ! git rev-parse --is-inside-work-tree &> /dev/null; then
	echo "It seems to be not a git repository (or any of the parent directories)" > /dev/stderr
	exit 1
fi

GIT_BRANCH=`git rev-parse --abbrev-ref HEAD 2> /dev/null`
if [[ $GIT_BRANCH =~ ^(.*)$ ]]; then
	GIT_BRANCH=${BASH_REMATCH[1]}
fi

GIT_ROOT=`git rev-parse --show-toplevel 2> /dev/null`
GIT_DIR=$GIT_ROOT/.git
