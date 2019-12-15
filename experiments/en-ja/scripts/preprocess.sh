#!/bin/bash -e

# This script performs preprocessing on raw texts.
#
# ./this.sh (source|target|train)
#
# - preprocessing
#   stdin: texts
#   stdout: texts (preprocessed)
# - training
#   stdin/stdout: None

# The following is an example for en->ja

ROOT=$(dirname $0)/..
GROOT=$ROOT/../..
GCONF="$ROOT/global_config.json"

export MOSES="$GROOT/scripts/mosesdecoder/scripts"
export TRUECASE_MODEL="$ROOT/data/truecase_model"

SPM="$(jq -r '.spm.model_file' < $GCONF)"

if [ "$1" == "source" ]; then
    # Preprocess English texts
    $GROOT/scripts/preprocess-scripts/eu_moses.sh en | spm_encode --model $SPM
elif [ "$1" == "target" ]; then
    # Preprocess Japanese texts
    mecab -O wakati | spm_encode --model $SPM
elif [ "$1" == "_source" ]; then
    # Preprocess English texts
    $GROOT/scripts/preprocess-scripts/eu_moses.sh en
elif [ "$1" == "_target" ]; then
    # Preprocess Japanese texts
    mecab -O wakati
elif [ "$1" == "train" ]; then
    # Train moses truecaser for English
    EN_TRAIN="./data/raw/parallel/$(jq -r '.iwslt17.file_name_prefix.train' < $GCONF).src"
    $GROOT/scripts/preprocess-scripts/eu_moses.sh en train < $EN_TRAIN

    # No training is needed for the Japanese tokenizer
else
    exit 1
fi

