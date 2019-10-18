#!/bin/bash

for c in ./*/*/log/*checkpoint/checkpoint; do
    kept=$(sed -n -r -e 's/^model_checkpoint_path: "(.+?)"$/\1/p' < $c | head -n 1)
    dname=$(dirname $c)
    [ ! -e "$dname/${kept}.index" ] && { echo "Not found: $dname"; continue; }
    rm $(find $dname -name 'model-*' -and -not -name "$(basename $kept)*") >& /dev/null \
        || echo "Failed: $dname"
done
