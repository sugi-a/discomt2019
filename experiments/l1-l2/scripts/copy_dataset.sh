#!/bin/bash -e
echo "
This script copies the parallel and monolingual corpora from global_root/corpus_preparation/* into ./data/raw/{parallel,monolingual}

The copied (newly saved) files must be named following the rules below

- Parallel Corpus
    - Stem (prefix) of the file names: follow ../global_config.json (.iwslt17.file_name_prefix.*)
    - Extention (suffix):
        - ".src" for the source language files
        - ".trg" for the target language files
- Monolingual Corpus
    - The monolingual corpus file name must be "all.trg"
"

# Below is an example of copying files for the en->ja experiment.

GCONF="./global_config.json"
[ -e $GCONF ] || { echo './global_config.json not found.' >&2; exit 1; }
[ -n "$CMTBT_GROOT" ] || { echo '$CMTBT_GROOT is not defined. Run  `source ./activate`.' >&2; exit 1; }

# Parallel
echo 'Copying parallel corpus' >&2

SRC_DIR="$CMTBT_GROOT/corpus_preparation/iwslt2017/data/extracted/en-ja"
DEST_DIR="./data/raw/parallel"
EXT_BEFORE=("en" "ja")
EXT_AFTER=("src" "trg")

for i in 0 1; do
    l=${EXT_BEFORE[$i]}
    role=${EXT_AFTER[$i]}

    for f in $SRC_DIR/IWSLT17.TED.dev2010.en-ja.$l; do
        cp $f $DEST_DIR/dev2010.$role
    done

    for f in $SRC_DIR/*.tst*.$l; do
        cp $f $DEST_DIR/$(echo $f | grep -o 'tst201.').$role
    done

    for f in $SRC_DIR/train.tags.*.$l; do
        cp $f $DEST_DIR/train.$role
    done
done


# Monolingual
echo 'Copying monolingual corpus' >&2
cp $CMTBT_GROOT/corpus_preparation/ja_diet_corpus/data/all ./data/raw/monolingual/all.trg
