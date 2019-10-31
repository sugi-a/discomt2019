#!/bin/bash

# This script performs pre-subword-segmentation preprocessing on raw texts.
# ./this.sh (source|target|train)
#
# - preprocessing
#   stdin: texts
#   stdout: texts (preprocessed)
# - training
#   stdin/stdout: None

ROOT=$(dirname $0)/..

MDS="$(dirname $0)/mosesdecoder/scripts"
TRUECASE_MODEL="truecase.model"
function punc_norm_tokenize (){
    $MDS/tokenizer/normalize-punctuation.perl -l en | \
        $MDS/tokenizer/tokenizer.perl \
            -l en -protected $MDS/tokenizer/basic-protected-patterns -no-escape
}

if [ "$1" == "source" ]; then
    # tokenize en texts
    punc_norm_tokenize | $MDS/recaser/truecase.perl --model $TRUECASE_MODEL
elif [ "$1" == "target" ]; then
    # tokenize ja texts
    mecab -O wakati
elif [ "$1" == "train" ]; then
    # train moses truecaser
    TRAIN_FILE=$ROOT/data/original/parallel/$($ROOT/get_gc.sh '["iwslt17"]["file_name_prefix"]["train"]').src || exit 1
    TMPF=$(mktemp)
    
    echo 'training truecaser' >&2
    cat $TRAIN_FILE | punc_norm_tokenize > $TMPF
    $MDS/recaser/train-truecaser.perl --corpus $TMPF --model $TRUECASE_MODEL
    rm $TMPF; echo 'done' >&2
else
    exit 1
fi

