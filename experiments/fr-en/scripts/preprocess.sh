#!/bin/bash -e

# This script performs preprocessing on raw texts.
#
# ./this.sh (source|target|train|_source|_target)
#
# - preprocessing
#   stdin: texts
#   stdout: texts (preprocessed)
# - training
#   stdin/stdout: None


# fr->en

ROOT=$(dirname $0)/..
GCONF="$ROOT/global_config.json"

export MOSES="${CMTBT_GROOT?not found}/scripts/mosesdecoder/scripts"
en_tcm="$ROOT/data/truecase_model_en"
fr_tcm="$ROOT/data/truecase_model_fr"

SPENC="spm_encode --model $(jq -r '.spm.model_file' < $GCONF)"

if [ "$1" == "source" ]; then
    # Preprocess English texts
    TRUECASE_MODEL=$fr_tcm $CMTBT_GROOT/scripts/preprocess-scripts/eu_moses.sh fr | $SPENC
elif [ "$1" == "target" ]; then
    # Preprocess French texts
    TRUECASE_MODEL=$en_tcm $CMTBT_GROOT/scripts/preprocess-scripts/eu_moses.sh en | $SPENC
elif [ "$1" == "_source" ]; then
    # Preprocess English texts
    TRUECASE_MODEL=$fr_tcm $CMTBT_GROOT/scripts/preprocess-scripts/eu_moses.sh fr
elif [ "$1" == "_target" ]; then
    # Preprocess French texts
    TRUECASE_MODEL=$en_tcm $CMTBT_GROOT/scripts/preprocess-scripts/eu_moses.sh en
elif [ "$1" == "train" ]; then
    _TRAIN_PREFIX="./data/raw/parallel/$(jq -r '.iwslt17.file_name_prefix.train' < $GCONF)"

    # Train moses truecaser for English
    EN_TRAIN="${_TRAIN_PREFIX}.trg"
    TRUECASE_MODEL=$en_tcm $CMTBT_GROOT/scripts/preprocess-scripts/eu_moses.sh en train < $EN_TRAIN

    # Train moses trucaser for French
    FR_TRAIN="${_TRAIN_PREFIX}.src"
    TRUECASE_MODEL=$fr_tcm $CMTBT_GROOT/scripts/preprocess-scripts/eu_moses.sh fr train < $FR_TRAIN
else
    exit 1
fi

