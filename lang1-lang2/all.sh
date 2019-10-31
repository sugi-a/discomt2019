#!/bin/bash -e

flags=()
for i in $@ ; do
    flags[$i]=1
done

# move to the root dir
cd $(dirname $0) ; [ "$CMTBT_ROOT" == $(pwd) ] || { echo '$CMTBT_ROOT not found' ; exit 1 ; }


if [ -n "${flags[1]}" ]; then
    # prepare the original corpora
    mkdir -p data/original/monolingual data/original/parallel
    ./lang/prepare_data.sh || exit 1
    echo '1 done' 1>&2
fi

if [ -n "${flags[2]}" ] ; then
    # train preprocessing pipelines

    mkdir -p ./data/preprocessed/monolingual ./data/preprocessed/parallel
    
    echo 'Training pre-sentencepiece preprocessors' >&2
    # train pre-sp-preprocessor
    ./lang/preprocess.sh train

    echo 'Pre-sentencepiece preprocessing'
    # pre-spm-preprocessing (src)
    TRAIN_BNAME=$(./get_gc.sh '["iwslt17"]["file_name_prefix"]["train"]')
    SRC_TRAIN=./data/original/parallel/${TRAIN_BNAME}.src
    TRG_TRAIN=./data/original/parallel/${TRAIN_BNAME}.trg
    TMPD=$(mktemp -d)

    ./lang/preprocess.sh source < $SRC_TRAIN > $TMPD/__src &
    ./lang/preprocess.sh target < $TRG_TRAIN > $TMPD/__trg; wait

    echo 'Training sentence peice' >&2
    # train smp
    spm_train \
        --input=$TMPD/__src,$TMPD/__trg \
        --model_prefix=$(./get_gc.sh '["spm"]["model_prefix"]') \
        --vocab_size=$(./get_gc.sh '["spm"]["vocab_size"]') \
        --character_coverage=0.9995 \
        --pad_id=$(./get_gc.sh '["spm"]["PAD_ID"]') \
        --bos_id=$(./get_gc.sh '["spm"]["SOS_ID"]') \
        --eos_id=$(./get_gc.sh '["spm"]["EOS_ID"]') \
        --unk_id=$(./get_gc.sh '["spm"]["UNK_ID"]') \
        --user_defined_symbols=$(./get_gc.sh '["spm"]["CONC"]') || exit 1

    rm -r $TMPD; echo 'Done' 1>&2
fi

if [ -n "${flags[3]}" ]; then
    # preprocess

    echo 'Preprocessing monolingual' 1>&2
    PREPRO="./scripts/preprocess.sh"

    # monolingual. preprocess in parallel
    {
        tmpd=$(mktemp -d)
        split -n l/4 ./data/original/monolingual/all $tmpd/__
        for f in $tmpd/__*; do
            $PREPRO target < $f > $tmpd/x$(basename $f) &
        done; wait
        cat $tmpd/x__* > ./data/preprocessed/monolingual/all
    # $PREPRO target < ./data/original/monolingual/all > ./data/preprocessed/monolingual/all &
    }

    echo 'Preprocessing parallel' 1>&2
    for f in ./data/original/parallel/*.trg ; do
        $PREPRO target < $f > ./data/preprocessed/parallel/$(basename $f) &
    done
    for f in ./data/original/parallel/*.src ; do
        $PREPRO source < $f > ./data/preprocessed/parallel/$(basename $f) &
    done
    wait

    echo '3 done' 1>&2
fi

if [ -n "${flags[4]}" ]; then
    # make concatenated dataset
    
    mkdir -p ./data/concat/monolingual ./data/concat/parallel

    S_DOC_CONC='python ./scripts/text_proc/doc_to_concat.py'
    CONC=$(./get_gc.sh '["spm"]["CONC"]')

    echo 'make conc data of monolingual corpus' 1>&2
    _SOURCE=./data/preprocessed/monolingual/all
    $S_DOC_CONC 0 < $_SOURCE > ./data/concat/monolingual/all
    $S_DOC_CONC 1 $CONC < $_SOURCE > ./data/concat/monolingual/all.1
    $S_DOC_CONC 2 $CONC < $_SOURCE > ./data/concat/monolingual/all.2

    echo 'make conc data of parallel corpus' 1>&2
    for f in ./data/preprocessed/parallel/* ; do
        _t_prefix=./data/concat/parallel/$(basename $f)
        $S_DOC_CONC 0 < $f > ${_t_prefix}
        $S_DOC_CONC 1 $CONC < $f > ${_t_prefix}.1
        $S_DOC_CONC 2 $CONC < $f > ${_t_prefix}.2
    done

    # length-filtering on train files of the parallel corpus
    echo 'length filtering on parallel train' >&2

    {
        MAX1=$(./get_gc.sh '["forward_model"]["data"]["maxlen"][0]')
        MAX2=$(./get_gc.sh '["forward_model"]["data"]["maxlen"][1]')
        BNAME=$(./get_gc.sh '["iwslt17"]["file_name_prefix"]["train"]')
    } || { exit 1 ; }

    mkdir -p ./data/concat/parallel/unfiltered
    mv ./data/concat/parallel/$BNAME.* ./data/concat/parallel/unfiltered
    P="./data/concat/parallel/unfiltered/$BNAME"
    Q="./data/concat/parallel/$BNAME"

    ./scripts/text_proc/multi_stream_start.sh $P.src $P.src.1 $P.src.2 $P.trg $P.trg.1 $P.trg.2 | \
        python ./scripts/text_proc/multi_ntoken_filter.py \
            --maxlens $MAX1 $MAX1 $MAX2 $MAX1 $MAX1 $MAX2 | \
        python ./scripts/text_proc/multi_write.py \
            $Q.src $Q.src.1 $Q.src.2 $Q.trg $Q.trg.1 $Q.trg.2

    echo 'Done' >&2
fi

# 11-19 back-translation
if [ -n "${flags[11]}" ]; then
    echo 'Create directory for back-translation model.' >&2

    [ -e ./backward/model_config.py ] && { echo 'model already exists'; exit 1; }
    mkdir -p ./backward

    # Distribute the Transformer configuration file
    cp ./scripts/model_config/model_config_template.py ./backward/model_config.py

    # Distribute the model-dependent setting file
    {
        CAPACITY=$(./get_gc.sh '["backward_model"]["batch_capacity"]')
        BEAM_SIZE=$(./get_gc.sh '["backward_model"]["beam_size"]')
        PARA_TRAIN_BNAME=$(./get_gc.sh '["iwslt17"]["file_name_prefix"]["train"]')
        PARA_DEV_BNAME=$(./get_gc.sh '["iwslt17"]["file_name_prefix"]["dev"]')
        CONTEXT=$(./get_gc.sh '["backward_model"]["context"]')
    } || exit 1
    [ "$CONTEXT" = "1-to-1" ] && { src_suffix=""; trg_suffix=""; }
    [ "$CONTEXT" = "2-to-1" ] && { src_suffix=".2"; trg_suffix=""; }
    [ "$CONTEXT" = "2-to-2" ] && { src_suffix=".2"; trg_suffix=".2"; }
    echo \
"capacity $CAPACITY
source_train ./data/concat/parallel/${PARA_TRAIN_BNAME}.trg$src_suffix
target_train ./data/concat/parallel/${PARA_TRAIN_BNAME}.src$trg_suffix
source_dev ./data/concat/parallel/${PARA_DEV_BNAME}.trg$src_suffix
target_dev ./data/concat/parallel/${PARA_DEV_BNAME}.src$trg_suffix
" > ./backward/train_data.conf

    echo \
"source_suffix .trg${src_suffix}
target_suffix .src
beam_size $BEAM_SIZE" > ./backward/test.conf

    echo 'Done' >&2
fi

if [ -n "${flags[12]}" ]; then
    echo 'Train back-translation model
- You must mannually run commands to train the model.
- Example command
    - CUDA_VISIBLE_DEVICES=0 python ./scripts/transformer/train.py --model_dir ./backward
    - CUDA_VISIBLE_DEVICES=0 python ./scripts/BLEU_evaluation.py --model_dir ./backward
- This shell script is terminated here.
' >&2
    exit 0
fi

if [ -n "${flags[13]}" ]; then
    echo 'Back-translation
- You must mannually run commands to back-translate the monolingual corpus
- Back-translated monolingual data must be written into ./data/back_translated/all
- This shell script is terminated here
' >&2
    mkdir ./data/back_translated
    exit 0
fi


# 21-29 forward-translation
if [ -n "${flags[21]}" ]; then
    # make pseudo corpus
    # all_500.1
    mkdir -p ./data/concat/pseudo
    tmpd1=$(mktemp -d)
    tmpd2=$(mktemp -d)

    {
        CONC=$(./get_gc.sh '["spm"]["CONC"]')
        monolingual_size=($(./get_gc.sh '["forward_model"]["data"]["monolingual_size"]'))
        MAX1=$(./get_gc.sh '["forward_model"]["data"]["maxlen"][0]')
        MAX2=$(./get_gc.sh '["forward_model"]["data"]["maxlen"][1]')
    } || exit 1

    echo 'make concatenated dataset of the generated data' >&2

    S_DOC_CONC='python ./scripts/text_proc/concat_w_leader.py'
    LEADER='./data/concat/monolingual/all.2'
    _SOURCE="./data/back_translated/all"
    cp $_SOURCE $tmpd1/all.src
    $S_DOC_CONC $LEADER 1 $CONC < $_SOURCE > $tmpd1/all.src.1
    $S_DOC_CONC $LEADER 2 $CONC < $_SOURCE > $tmpd1/all.src.2


    echo 'filter & shuffle' >&2
    SRC="$tmpd1/all.src"
    TRG="./data/concat/monolingual/all"
    ./scripts/text_proc/multi_stream_start.sh $SRC $SRC.1 $SRC.2 $TRG $TRG.1 $TRG.2 | \
        python ./scripts/text_proc/multi_ntoken_filter.py \
            --maxlens $MAX1 $MAX1 $MAX2 $MAX1 $MAX1 $MAX2 | \
        python ./scripts/text_proc/multi_shuffle.py | \
        python ./scripts/text_proc/multi_write.py \
            all.src all.src.1 all.src.2 all.trg all.trg.1 all.trg.2 --prefix $tmpd2/

    echo 'split' >&2
    for role in ".src" ".trg"; do
        for ctx in "" ".1" ".2" ; do
            for size in ${monolingual_size[@]} ; do
                head -n $((size * 1000)) $tmpd2/all${role}${ctx} \
                    > ./data/concat/pseudo/all.${size}${role}${ctx}
            done
        done
    done

    rm -r $tmpd1 $tmpd2; echo 'Done' >&2
fi

if [ -n "${flags[22]}" ]; then
    # distribute model_config.py , train_data.conf , test.conf
# train_data.conf
#capacity 16384
#maxlen 128
#source_train ...
#target_train ...
#source_dev ...
#target_dev ...

# test.conf
#source_suffix .src.2
#target_suffix .trg
#beam_size 5

    {
        monolingual_size=(0 $(./get_gc.sh '["forward_model"]["data"]["monolingual_size"]'))
        CAPACITY=$(./get_gc.sh '["forward_model"]["batch_capacity"]')
        BEAM_SIZE=$(./get_gc.sh '["forward_model"]["beam_size"]')
        PARA_TRAIN_BNAME=$(./get_gc.sh '["iwslt17"]["file_name_prefix"]["train"]')
        PARA_DEV_BNAME=$(./get_gc.sh '["iwslt17"]["file_name_prefix"]["dev"]')
    } || exit 1
    
    for model in 1-to-1 2-to-1 2-to-2 ; do
        [ "$model" = "1-to-1" ] && { src_suffix=""; trg_suffix=""; }
        [ "$model" = "2-to-1" ] && { src_suffix=".2"; trg_suffix=""; }
        [ "$model" = "2-to-2" ] && { src_suffix=".2"; trg_suffix=".2"; }

        for size in ${monolingual_size[@]} ; do
            if [ "$size" == "0" ]; then
                mono_source=""
                mono_target=""
            else
                mono_source="./data/concat/pseudo/all.${size}.src${src_suffix}"
                mono_target="./data/concat/pseudo/all.${size}.trg${trg_suffix}"
            fi
            prefix="forward/$model/$size/"
            mkdir -p $prefix
            if [ ! -e ${prefix}model_config.py ]; then
                cp ./scripts/model_config/model_config_template.py ${prefix}model_config.py
                echo \
"capacity $CAPACITY
source_train ./data/concat/parallel/${PARA_TRAIN_BNAME}.src$src_suffix $mono_source
target_train ./data/concat/parallel/${PARA_TRAIN_BNAME}.trg$trg_suffix $mono_target
source_dev ./data/concat/parallel/${PARA_DEV_BNAME}.src$src_suffix
target_dev ./data/concat/parallel/${PARA_DEV_BNAME}.trg$trg_suffix" > ${prefix}train_data.conf

                echo \
"source_suffix .src${src_suffix}
target_suffix .trg
beam_size $BEAM_SIZE" > ${prefix}test.conf
            else
                echo "Ignoring ${prefix}. model_config already exists." >&2
            fi
        done
    done
fi

if [ -n "${flags[23]}" ]; then
    echo 'Training of the forward models.
- You must mannually run commands to train the forward models
- This shellScript is terminated here' >&2
    exit 0
fi

if [ -n "${flags[24]}" ]; then
    echo 'Tests'
fi
