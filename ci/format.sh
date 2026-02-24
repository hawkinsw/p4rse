#!/bin/bash

# Format
swift format --recursive -i Sources/ 2>&1 >/dev/null

# Modified count
mc=`git status . | grep modified | wc -l | sed 's/ //g'`

if [ ${mc} -ne 0 ]; then
    exit 1
fi

exit 0