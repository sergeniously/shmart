#!/bin/bash

source ../validate.sh

for path in '/tmp/dir' 'tmp/dir' '/path/to/+' ''; do
    (validate required path by "(/\w+)+")
    [[ $? -eq 0 ]] && echo "'$path' is ok"
done

for file in 'file.ext' 'file' '^.^' ''; do
    (validate optional file by "\w*(\.\w+)?" or file.def)
    [[ $? -eq 0 ]] && echo "'$file' is ok"
done
