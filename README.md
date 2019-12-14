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
scripts/ # language-pair-independent scripts
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
        original/ # Original corpora
        extracted/ # Sentences extracted from the original corpora
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

## 1. Run the activation script in the global root directory
```
source ./activate
```

## 2. Move to the root directory for a language pair (ja-en in this example)
```
cd ./experiments/ja-en # move to the ja-en root dir
```

global_config.json is placed in every language pair's root directory.
You can edit it to modify settings like vocabulary size, variation in pseudo data size etc.

Note: by default, batch capacity (maximum number of tokens in a batch) is 16384, which is compatible with GPUs with 24GB RAM in total (e.g. two Titan X GPUs).

## 3. Run `all.sh`
```
pwd
output: /path/to/global_root/experiments/ja-en
```
### 1. Prepare dataset
```
../../scripts/project/all.sh 1
```
In this process,

- The original corpora are downloaded into ./data/original
- Sentences are extracted and saved into ./data/extracted
    - Blank lines should be inserted at the document boundaries

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
