#!/bin/bash -e

GCONF="./global_config.json"

[ -e "$GCONF" ] || { 'You have to run this script from the directory where global_config.json is placed.' >&2; exit 1; }
[ -n "$CUDA_VISIBLE_DEVICES" ] || { echo 'You have to set the env var $CUDA_VISIBLE_DEVICES' >&2; exit 1; }
echo ${CMTBT_GROOT?Not found} > /dev/null

gpus=($(echo $CUDA_VISIBLE_DEVICES | tr ',' ' '))
ngpus=${#gpus[@]}
bt_context=$(jq -r '.backward_model.context' < $GCONF)
beam_size=$(jq -r '.backward_model.beam_size' < $GCONF)

if [ "$bt_context" = "1-to-1" ]; then
    SOURCE="./data/concat/monolingual/all.trg"
    TRANSLATOR="python $CMTBT_GROOT/scripts/transformer/inference.py"
elif [ "$bt_context" = "2-to-1" ]; then
    SOURCE="./data/concat/monolingual/all.trg.2"
    TRANSLATOR="python $CMTBT_GROOT/scripts/transformer/inference.py"
elif [ "$bt_context" = "2-to-2" ]; then
    SOURCE="./data/concat/monolingual/all.trg.2"
    TRANSLATOR="python $CMTBT_GROOT/scripts/project/context_aware_translation.py"
else
    exit 1
fi

DEST_DIR="./data/back_translated"
DEST=$DEST_DIR/all.src
mkdir -p $DEST_DIR

echo """Back-translate:
$SOURCE
into:
$DEST

Back-translation model: $bt_context

Batch capacity: ${BATCH_CAPACITY:=8192}
(You can specify it via the env var BATCH_CAPACITY=)
(For GPUs with 12GB RAM like Titan X, BATCH_CAPACITY=8192 is recommended)

GPUs: ${gpus[@]}

Beam size: $beam_size
""" >&2

echo 'Continue? (y/n)' >&2
while read -n 1 -p '>' ans; do
    if [ "$ans" = "y" ]; then
        break
    elif [ "$ans" = "n" ]; then
        echo -e '\nCancelled' >&2
        exit 0
    fi
    echo -e '\nInput y or n. Continue? (y/n)'
done

tmpd=$(mktemp -d __XXXXXX)
split -n l/$ngpus $SOURCE  ${tmpd}/__
i=0

for f in $tmpd/__*; do
    CUDA_VISIBLE_DEVICES=${gpus[i]} $TRANSLATOR \
        --model_dir ./backward \
        --beam_size $beam_size \
        --batch_capacity $BATCH_CAPACITY \
        < $f > $tmpd/trans_$(basename $f) 2>> ./data/back_translated/bt_log_$(basename $f) &
    i=$((i+1))
done
wait

cat $tmpd/trans_* > $DEST
rm -r $tmpd
