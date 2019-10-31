#!/bin/bash

echo '
Preparation of the dataset

You must make the following files
- In ./data/original/parallel/
    - (parallel train prefix).src
        - The SOURCE-side train data of the PARALLEL corpus
    - (parallel train prefix).trg
        - The TARGET-side train data of the PARALLEL corpus
    - (parallel dev prefix).src
        - The SOURCE-side validation data of the PARALLEL corpus
    - (parallel dev prefix).trg
        - The TARGET-side validation data of the PARALLEL corpus
    - (parallel test prefix).src
        - The SOURCE-side validation data of the PARALLEL corpus
        - Multiple test files can be placed
    - (parallel test prefix).trg
        - The TARGET-side validation data of the PARALLEL corpus
        - Multiple test files can be placed
- In ./data/original/monolingual/
    - all
        - The monolingual data

Format:
- Basically one sentence per line
- A blank line must be inserted between documents (document=block of contiguous sentences)
' >&2


echo 'copy original monolingual corpus' 1>&2
cat /disk/sugi/kyoto/dataset/KokkaiHimawari_yosan/extracted/corpus_sangiin_yosan04 \
    /disk/sugi/kyoto/dataset/KokkaiHimawari_yosan/extracted/corpus_syugiin_yosan04 \
    > data/original/monolingual/all || exit 1

echo 'copy original parallel corpus' 1>&2
cp /disk/sugi/kyoto/dataset/iwslt2017/ja-en/extracted/* ./data/original/parallel/ || exit 1
# replace language extention by src/trg. en->src, ja->trg
(
    cd ./data/original/parallel
    for f in ./*.xml ; do
        mv $f $(basename $f .xml)
    done
    for f in ./*.en ; do mv $f $(basename $f .en).src ; done
    for f in ./*.ja ; do mv $f $(basename $f .ja).trg ; done
)

