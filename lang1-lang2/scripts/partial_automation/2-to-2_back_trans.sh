#!/bin/bash -e

cd ${CMTBT_ROOT:?not found}

echo "Source: ${SOURCE:?not found}" >&2
echo "Destination: ${DEST_DIR:?not found}" >&2
echo "Batch capacity: ${BATCH_CAPACITY:=8192}"
echo "GPUs: $@"

mkdir -p $DEST_DIR

MODEL_DIR="./backward"

tmpd=$(mktemp -d)
gpus=($@)

split -n l/${#gpus[@]} $SOURCE ${tmpd}/__

i=0
for f in $tmpd/__* ; do
    CUDA_VISIBLE_DEVICES=${gpus[i]} python ./scripts/test/context_aware_translation.py \
        --model_dir ./backward --beam_size 5 --batch_capacity $BATCH_CAPACITY \
        < $f > $tmpd/trans_$(basename $f) &
    i=$((i + 1))
done
wait

cat $tmpd/trans_* > $DEST_DIR/$(basename $SOURCE)
rm -r $tmpd

