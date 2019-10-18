#!/bin/bash

for c in ./*/*/log/*checkpoint/checkpoint; do
    sed -i -r -e 's/checkpoint_path(s?): ".+\/(.+?)"/checkpoint_path\1: "\2"/' $c
done

