#!/bin/bash -e

cd $(dirname $0)

echo 'Downloading Europarl' >&2

./europarl_monolingual/scripts/download_and_extract.sh


echo 'Donwloading IWSLT2017' >&2

./iwslt2017/scripts/download_and_extract.sh


echo 'Downloading Japanese Diet Corpus' >&2

./ja_diet_corpus/scripts/download_and_extract.sh


echo 'Downloading Bookcorpus' >&2

./bookcorpus/scripts/download_data_and_extract_documents.sh


