# Introduction
This directory contains our source codes and dataset for "Data Augmentation Using Back-translation for Context-aware Neural Machine Translation" presented in DiscoMT 2019.

# Prerequisite
- python 3.6.8
    - tensorflow 1.12.0
    - numpy 1.16.0
    - sentencepiece 
- jq
- mecab

# Directories
## Overall
```
README.md # This readme
activate
discourse_test_set/
corpus_preparation/
scripts/ # language-pair-independent scripts
corpus_preparation/ # Original corpus are downloaded here
experiments/
    l1-l2/ # Template of experiment on a directed language pair
        global_config.json # Config for this lang-pair
        data/
        scripts/ # lang-pair-specific scripts
        backward/ # The back-translation model
        forward/ # Forward-translation models

    en-ja # Instance of l1-l2 (same below)
    ja-en
    en-fr
    fr-en
```

## Detail
```
./scripts/
    transformer/ # Transformer scripts
    mosesdecoder/
    preprocess-scripts/
    corpus_formatters/ # scripts to extract sentences from raw corpus
    project/ # Scripts used in the experiments
        all.sh # Main shell script run from experiments/l1-l2
./experiments/l1-l2/
    data/
        raw/ # Sentences extracted from the original corpora
        preprocessed/ # Preprocessed corpora
        concat/ # Concatenated preprocessed corpora
        back_translated/ # Back-translated monolingual corpus
    backward/
        model_config.json # Config of the Transformer for back-trans
        model_config.py
        log/ # Log of train and test of this Transformer
    forward/
        1-to-1/ # Sentence-level models
            0/ # Transformer trained without data-augmentation
            500/ # trained with 500k pseudo data
            1000k/ # trained with 1000k pseudo data
            ...
        2-to-1/ 
        2-to-2/
```

# Run experiments

## Set the environment variables for the whole project
```
source ./activate
```
This sets the global root's path into an env var $CMTBT_GROOT.
You have to do this every time you open a new terminal window.

## Download datasets and extract sentences
```
./corpus_preparation/download_data.sh
```
By this command, the following corpora are downloaded and sentences are extracted (like removing xml tags and gathering sentences in multiple files into a single file)

1. IWSLT2017 en-ja and en-fr
1. Europarl v7
    - fr sentences are gathered into a single file
1. Japanese diet corpus
1. Bookcorpus
    - Download is done using https://github.com/soskek/bookcorpus
    - This would take much time

Note: Blank lines are inserted at the document boundaries

## Run experiments on a (directed) language pair


### Introduction
Procedure to conduct training and evaluation of back-translation and data-augmented forward translation models.

By default, environments for 4 language pairs are prepared:

- en->ja : ./experiments/en-ja
- ja->en : ./experiments/ja-en
- en->fr : ./experiments/en-fr
- fr->en : ./experiments/fr-en

You can make your own by copying

- ./experiments/l1-l2/global_config.json
- ./experiments/l1-l2/scripts/preprocess.sh
- ./experiments/l1-l2/scripts/copy_dataset.sh

into the new directory and modify them as you like.

----

### 0. Move to the lang pair's experiment dir
Move to the root directory for experiment of a language pair (ja-en in the following examples)
```
cd ./experiments/ja-en
```

global_config.json is placed in every language pair's root directory.
You can edit it to modify settings like vocabulary size, variation in pseudo data size etc.

Note: by default, batch capacity (maximum number of tokens in a batch) is 16384, which is compatible with GPUs with 24GB RAM in total (e.g. two Titan X GPUs).

```
pwd
#output: /path/to/global_root/experiments/ja-en
```
### 1. Copy dataset
```
../../scripts/project/all.sh 1
```
IWSLT2017 en-ja and Japanese diet corpus are copied from /global_root/corpus_preparation/

### 2. Train preprocessor
```
../../scripts/project/all.sh 2
```

### 3. Preprocess dataset
```
../../scripts/project/all.sh 3
```

### 4. Concatenate the context and the main sentence
```
../../scripts/project/all.sh 4
```

### 5. Train back-translation model
```
../../scripts/project/all.sh 11 12
```

### 5. Back-translate the monolingual corpus
```
../../scripts/project/all.sh 13
```

### 6. Make pseudo corpus
```
../../scripts/project/all.sh 21
```

### 7. Train forward translation models
```
../../scripts/project/all.sh 22 23
```
