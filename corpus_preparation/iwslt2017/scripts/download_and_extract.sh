#!/bin/bash -e

cd $(dirname $0)/..
mkdir -p data

[ -n "$CMTBT_GROOT" ] || { echo '$CMTBT_GROOT not found' >&2; exit 1; }

echo 'Downloading IWSLT2017 en-fr' >&2

#(
#mkdir -p ./data/original
#cd ./data/original
#wget "https://wit3.fbk.eu/archive/2017-01-trnted//texts/en/fr/en-fr.tgz" -O en-fr.tgz
#tar -xzvf en-fr.tgz
#)
#
#echo 'Downloading IWSLT2017 en-ja' >&2
#(
#mkdir -p ./data/original
#cd ./data/original
#wget "https://wit3.fbk.eu/archive/2017-01-trnted//texts/en/ja/en-ja.tgz" -O en-ja.tgz
#tar -xzvf en-ja.tgz
#)


echo 'Extracting sentences' >&2
EXTRACTOR="python ${CMTBT_GROOT}/scripts/corpus_formatters/iwslt17/extract.py"

for lp in en-fr en-ja; do
    SRC_DIR=./data/original/$lp
    DEST_DIR=./data/extracted/$lp

    mkdir -p $DEST_DIR

    for f in $SRC_DIR/train.tags.*; do
        $EXTRACTOR 'train' --doc-sep-line < $f > $DEST_DIR/$(basename $f)
    done

    for f in $SRC_DIR/IWSLT17.TED.dev*; do
        $EXTRACTOR 'dev' --doc-sep-line < $f > $DEST_DIR/$(basename $f .xml)
    done

    for f in $SRC_DIR/IWSLT17.TED.tst*; do
        $EXTRACTOR 'test' --doc-sep-line < $f > $DEST_DIR/$(basename $f .xml)
    done
done
