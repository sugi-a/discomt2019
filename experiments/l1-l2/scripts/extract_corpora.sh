#!/bin/bash -e

GCONF="./global_config.json"
[ -e $GCONF ]

SRC_DIR="./data/original"
DEST_DIR="./data/extracted"
EXT_BEFORE=("en" "ja")
EXT_AFTER=("src" "trg")


# IWSLT2017 English-Japanese. Make sure to insert blank lines between documents.
EXTRACTOR="python ${CMTBT_GROOT:?not found}/scripts/corpus_formatters/iwslt17/extract.py --doc-sep-line"

for i in 0 1; do
    l=${EXT_BEFORE[$i]}
    role=${EXT_AFTER[$i]}

    for f in $SRC_DIR/parallel/IWSLT17.TED.dev2010.ja-en.$l.xml; do
        $EXTRACTOR dev < $f > $DEST_DIR/parallel/dev2010.$role
    done

    for f in $SRC_DIR/parallel/*.tst*.$l.xml; do
        $EXTRACTOR test < $f > $DEST_DIR/parallel/$(echo $f | grep -o 'tst201.').$role
    done

    for f in $SRC_DIR/parallel/train.*.$l; do
        $EXTRACTOR train < $f > $DEST_DIR/parallel/train.$role
    done
done


# Monolingual
EXTRACTOR="${CMTBT_GROOT}/scripts/corpus_formatters/kokkai_corpus/extract.py"
originals=("corpus_sangiin_yosan04.xml" "corpus_syugiin_yosan04.xml")
dest=$DEST_DIR/monolingual/all.trg

echo > $dest
for bn in "${originals[@]}"; do
    $EXTRACTOR < $SRC_DIR/monolingual/$bn >> $dest
done
