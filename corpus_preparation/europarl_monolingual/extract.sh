#!/bin/bash -e

echo "Source dir: ${1:?not found}"

cat $1/* | python ./txt_to_lines.py > $(basename $1)_extracted
