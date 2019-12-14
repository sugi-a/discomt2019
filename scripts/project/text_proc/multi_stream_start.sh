#!/bin/sh

[ "$#" -gt 0 ] || { echo 'file not found' >&2 ; exit 1; }

a=$(wc -l < $1)

echo 'Checking number of lines' >&2
for f in "$@"; do
    nl=$(wc -l < $f)
    echo "$f : $nl" >&2
    [ "$nl" -eq "$a" ] || { echo '#lines does not match' >&2; exit 1; }
done

echo $#
paste -d "\n" "$@"
