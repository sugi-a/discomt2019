#!/bin/bash -e

SRC_DIR=${1:?'specify source directory'}
DEST_DIR=${2:?'specify destination directory'}
mkdir -p $DEST_DIR
SCRIPT=$(dirname $0)/extract.py

for f in $SRC_DIR/train.*; do
    python $SCRIPT 'train' < $f > $DEST_DIR/$(basename $f)
done

for f in $SRC_DIR/IWSLT17.TED.dev*; do
    python $SCRIPT 'dev' < $f > $DEST_DIR/$(basename $f)
done

for f in $SRC_DIR/IWSLT17.TED.tst*; do
    python $SCRIPT 'test' < $f > $DEST_DIR/$(basename $f)
done
