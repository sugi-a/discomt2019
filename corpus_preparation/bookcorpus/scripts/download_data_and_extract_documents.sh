#!/bin/bash -e

cd $(dirname $0)/..

source ./bookcorpus_venv/bin/activate

f=()
for i in "$@"; do
    f[$i]=1
done
[ ${#f[@]} -eq 0 ] && f=(1 1 1 1 1 1 1)

if [ -n "${f[1]}" ]; then
    echo 'Downloading data' >&2

    mkdir -p ./data
    [ -e "./data/out_txts" ] && rm -r ./data/out_txts

    python ./bookcorpus/download_files.py --list ./bookcorpus/url_list.jsonl --out ./data/out_txts --trash-bad-count
fi

if [ -n "${f[2]}" ]; then
    echo 'Concatenating the original data files' >&2

    python ./bookcorpus/make_sentlines.py out_txts > ./original_all.txt
fi

if [ -n "${f[3]}" ]; then
    echo 'Extracting documents' >&2

    python ./scripts/extract_sentences_from_original_bookcorpus.py < ./original_all.txt > all
fi
