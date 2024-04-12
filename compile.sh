#!/bin/bash
FILE=mgeme

if [ ! -d "scripting" ] || [ ! -d "plugins" ]; then
    echo "sourcemod plugin folders not found"
    exit 1
fi

echo "${FILE}.sp compile `date`" > compile.log

./scripting/spcomp64 -D./scripting/ ${FILE}.sp --show-stats -h -z9 _DEBUG= --use-stderr >> compile.log

if [ -f ./scripting/${FILE}.smx ]; then
    if [ -f ./plugins/${FILE}.smx ]; then
        mv --backup=numbered ./plugins/${FILE}.smx ./plugins/disabled/
    fi
    mv ./scripting/${FILE}.smx ./plugins/
else
    echo "spcomp64 failed"
fi
