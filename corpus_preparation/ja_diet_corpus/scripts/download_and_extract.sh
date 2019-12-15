#!/bin/bash -e

cd $(dirname $0)/..

mkdir -p ./data

cd ./data

wget "https://csd.ninjal.ac.jp/archives/Kokkai/kokkaiHimawari_yosan_rev20170612.zip"
unzip "kokkaiHimawari_yosan_rev20170612.zip"
rm "kokkaiHimawari_yosan_rev20170612.zip"

# Extract
originals=("corpus_sangiin_yosan04.xml" "corpus_syugiin_yosan04.xml")

echo > ./all
for bn in "${originals[@]}"; do
    python ./scripts/extract.py < ./KokkaiHimawari_yosan/Corpora/Kokkai/yosan/$bn >> ./all
done
