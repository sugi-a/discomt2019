#!/bin/bash -e

LANGS=(fr de)

cd $(dirname $0)/..

mkdir -p data

cd ./data

echo 'Donwloading Europarl' >&2
wget https://www.statmt.org/europarl/v7/europarl.tgz
tar -xzvf europarl.tgz

cd ../

for l in ${LANGS[@]}; do
    echo "Making $l corpus" >&2
    cat ./data/txt/$l/* | python ./scripts/txt_to_lines.py > ./data/${l}_all
done
