#!/bin/bash -e

flags=()
for i in $@ ; do
    flags[$i]=1
done

# Check global_config.json
GCONF="./global_config.json"
[ -e $GCONF ] || { echo './global_config.json not found' >&2; exit 1; }

# Check if the global root dir is registered
echo "Global root dir: ${CMTBT_GROOT?not found. You must call \`source ./activate\` in the global root directory}"

# Directory of the global scripts (scripts shared among different experiments for different language pairs)
GSCRIPTS=${CMTBT_GROOT?not found}/scripts


# Copy datasets
if [ -n "${flags[1]}" ]; then
    mkdir -p ./data/raw/{monolingual,parallel}
    ./scripts/copy_dataset.sh
fi

# Train preprocessing pipelines
if [ -n "${flags[2]}" ] ; then
    mkdir -p ./data/preprocessed/{monolingual,parallel}
    
    echo 'Training pre-sentencepiece preprocessors' >&2
    ./scripts/preprocess.sh train

    echo 'Pre-sentencepiece preprocessing'

    # pre-spm-preprocessing (src)
    TRAIN_BNAME=$(jq -r '.iwslt17.file_name_prefix.train' < $GCONF)
    SRC_TRAIN=./data/raw/parallel/${TRAIN_BNAME}.src
    TRG_TRAIN=./data/raw/parallel/${TRAIN_BNAME}.trg
    TMPD=$(mktemp -d __XXXXXX)

    ./scripts/preprocess.sh _source < $SRC_TRAIN > $TMPD/__src &
    ./scripts/preprocess.sh _target < $TRG_TRAIN > $TMPD/__trg; wait

    spm_train \
        --input=$TMPD/__src,$TMPD/__trg \
        --model_prefix=$(jq -r '.spm.model_prefix' < $GCONF) \
        --vocab_size=$(jq -r '.spm.vocab_size' < $GCONF) \
        --character_coverage=0.9995 \
        --pad_id=$(jq -r '.spm.PAD_ID' < $GCONF) \
        --bos_id=$(jq -r '.spm.SOS_ID' < $GCONF) \
        --eos_id=$(jq -r '.spm.EOS_ID' < $GCONF) \
        --unk_id=$(jq -r '.spm.UNK_ID' < $GCONF) \
        --user_defined_symbols=$(jq -r '.spm.CONC' < $GCONF) || exit 1

    rm -r $TMPD
    echo '2 done' >&2
fi

# Preprocess
if [ -n "${flags[3]}" ]; then
    echo 'Preprocessing monolingual' 1>&2
    PREPRO="./scripts/preprocess.sh"

    # Preprocess the monolingual corpus in parallel
    {
        tmpd=$(mktemp -d)
        split -n l/4 ./data/raw/monolingual/all.trg $tmpd/__
        for f in $tmpd/__*; do
            $PREPRO target < $f > $tmpd/x$(basename $f) &
        done; wait
        cat $tmpd/x__* > ./data/preprocessed/monolingual/all.trg
        rm -r $tmpd
    }

    echo 'Preprocessing parallel corpus' 1>&2
    for f in ./data/raw/parallel/*.trg ; do
        $PREPRO target < $f > ./data/preprocessed/parallel/$(basename $f) &
    done
    for f in ./data/raw/parallel/*.src ; do
        $PREPRO source < $f > ./data/preprocessed/parallel/$(basename $f) &
    done
    wait

    echo '3 done' 1>&2
fi

if [ -n "${flags[4]}" ]; then
    # make concatenated dataset
    
    mkdir -p ./data/concat/monolingual ./data/concat/parallel

    S_DOC_CONC="python $GSCRIPTS/project/text_proc/doc_to_concat.py"
    CONC=$(jq -r '.spm.CONC' < $GCONF)

    echo 'make conc data of monolingual corpus' 1>&2
    _SOURCE=./data/preprocessed/monolingual/all.trg
    $S_DOC_CONC 0 < $_SOURCE > ./data/concat/monolingual/all.trg
    $S_DOC_CONC 1 $CONC < $_SOURCE > ./data/concat/monolingual/all.trg.1
    $S_DOC_CONC 2 $CONC < $_SOURCE > ./data/concat/monolingual/all.trg.2

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
        MAX1=$(jq -r '.forward_model.data.maxlen[0]' < $GCONF)
        MAX2=$(jq -r '.forward_model.data.maxlen[1]' < $GCONF)
        BNAME=$(jq -r '.iwslt17.file_name_prefix.train' < $GCONF)
    } || { exit 1 ; }

    mkdir -p ./data/concat/parallel/unfiltered
    mv ./data/concat/parallel/$BNAME.* ./data/concat/parallel/unfiltered
    P="./data/concat/parallel/unfiltered/$BNAME"
    Q="./data/concat/parallel/$BNAME"

    $GSCRIPTS/project/text_proc/multi_stream_start.sh $P.{src,trg}{,.1,.2} | \
        python $GSCRIPTS/project/text_proc/multi_ntoken_filter.py \
            --maxlens $MAX1 $MAX1 $MAX2 $MAX1 $MAX1 $MAX2 | \
        python $GSCRIPTS/project/text_proc/multi_write.py $Q.{src,trg}{,.1,.2}

    echo 'Done' >&2
fi

# 11-19 back-translation
if [ -n "${flags[11]}" ]; then
    echo 'Create directory for back-translation model.' >&2

    [ -e ./backward/model_config.py ] && { echo 'model already exists'; exit 1; }
    mkdir -p ./backward

    # Distribute the model-dependent setting file
    {
        CAPACITY=$(jq -r '.backward_model.batch_capacity' < $GCONF)
        BEAM_SIZE=$(jq -r '.backward_model.beam_size' < $GCONF)
        PARA_TRAIN_BNAME=$(jq -r '.iwslt17.file_name_prefix.train' < $GCONF)
        PARA_DEV_BNAME=$(jq -r '.iwslt17.file_name_prefix.dev' < $GCONF)
        CONTEXT=$(jq -r '.backward_model.context' < $GCONF)
        VOCAB_FILE=$(jq -r '.spm.model_prefix' < $GCONF).vocab
    } || exit 1
    [ "$CONTEXT" = "1-to-1" ] && { src_suffix=""; trg_suffix=""; target_ctx="false"; }
    [ "$CONTEXT" = "2-to-1" ] && { src_suffix=".2"; trg_suffix=""; target_ctx="false"; }
    [ "$CONTEXT" = "2-to-2" ] && { src_suffix=".2"; trg_suffix=".2"; target_ctx="true"; }
    echo \

    cat $GSCRIPTS/transformer/templates/model_config.json \
        | jq ".basedir = \"$(pwd)\"" \
        | jq ".train.batch.capacity = $CAPACITY" \
        | jq ".train.data.source_train = [\"./data/concat/parallel/${PARA_TRAIN_BNAME}.trg$src_suffix\"]" \
        | jq ".train.data.target_train = [\"./data/concat/parallel/${PARA_TRAIN_BNAME}.src$trg_suffix\"]" \
        | jq ".train.data.source_dev = \"./data/concat/parallel/${PARA_DEV_BNAME}.trg$src_suffix\"" \
        | jq ".train.data.target_dev = \"./data/concat/parallel/${PARA_DEV_BNAME}.src$trg_suffix\"" \
        | jq ".source_suffix = \".trg${src_suffix}\"" \
        | jq ".target_suffix = \".src\"" \
        | jq ".beam_size = $BEAM_SIZE" \
        | jq ".target_context = $target_ctx" \
        | jq ".vocab.source_dict = \"$VOCAB_FILE\"" \
        | jq ".vocab.target_dict = \"$VOCAB_FILE\"" \
        > ./backward/model_config.json

    cp $GSCRIPTS/project/templates/model_config.py ./backward/model_config.py

    echo 'Done' >&2
fi

if [ -n "${flags[12]}" ]; then
    echo """
Training of the back-translation model

Start training with the GPU No.0? (y/n)

If you want to use other GPU(s), you have to mannually run the command to train the back-translation model.

You can run training by the following command.
\`CUDA_VISIBLE_DEVICES=0 python $CMTBT_GROOT/scripts/transformer/train.py -d ./backward\`
Or if you want to train the model with multiple GPUs, you can do it by, for example,
\`CUDA_VISIBLE_DEVICES=0,1 python $CMTBT_GROOT/scripts/transformer/train.py -d ./backward --n_gpus 2\`

Optionally, after the training is finished, evaluation can be executed by
\`CUDA_VISIBLE_DEVICES=0 $CMTBT_GROOT/scripts/project/BLEU_evaluation_for_model.sh ./backward\`
and the results are stored in ./backward/log/eval/eval_YYYYMMDD-HHMMSS/

Again, start training with the GPU No.0? (y/n)
""" >&2
    
    while read -n 1 -p '>' ans; do
        if [ "$ans" = "y" ]; then
            break
        elif [ "$ans" = "n" ]; then
            echo -e '\nThis shell script is terminated here.' >&2
            exit 0
        fi
        echo -e '\nInput y or n' >&2
    done
    echo -e '\nTraining start.' >&2
fi

if [ -n "${flags[13]}" ]; then
    mkdir -p ./data/back_translated
    echo "
Back-translation of the monolingual corpus.

You have to mannually run the command to back-translate the monolingual corpus.
(This is for you to use the GPUs available just at this moment.)

We provide a shellscript to do the back-translation. Simply run the following:
\`CUDA_VISIBLE_DEVICES=0 $CMTBT_GROOT/scripts/project/partial_automation/back_trans.sh\`
Or if you want to use multiple GPUs, for example, gpu0-5, run the following
\`CUDA_VISIBLE_DEVICES=0,1,2,3,4,5 $CMTBT_GROOT/scripts/project/partial_automation/back_trans.sh\`

This shell script is terminated here.
" >&2
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
        CONC=$(jq -r '.spm.CONC' < $GCONF)
        monolingual_size=($(jq -r '.forward_model.data.monolingual_size[]' < $GCONF))
        MAX1=$(jq -r '.forward_model.data.maxlen[0]' < $GCONF)
        MAX2=$(jq -r '.forward_model.data.maxlen[1]' < $GCONF)
    } || exit 1

    echo 'make concatenated dataset of the generated data' >&2

    S_DOC_CONC="python $GSCRIPTS/project/text_proc/concat_w_leader.py"
    LEADER='./data/concat/monolingual/all.trg.2'
    _SOURCE="./data/back_translated/all.src"
    cp $_SOURCE $tmpd1/all.src
    $S_DOC_CONC $LEADER 1 $CONC < $_SOURCE > $tmpd1/all.src.1
    $S_DOC_CONC $LEADER 2 $CONC < $_SOURCE > $tmpd1/all.src.2


    echo 'filter & shuffle' >&2
    SRC="$tmpd1/all.src"
    TRG="./data/concat/monolingual/all.trg"
    $GSCRIPTS/project/text_proc/multi_stream_start.sh {$SRC,$TRG}{,.1,.2} | \
        python $GSCRIPTS/project/text_proc/multi_ntoken_filter.py \
            --maxlens $MAX1 $MAX1 $MAX2 $MAX1 $MAX1 $MAX2 | \
        python $GSCRIPTS/project/text_proc/multi_shuffle.py | \
        python $GSCRIPTS/project/text_proc/multi_write.py all.{src,trg}{,.1,.2} --prefix $tmpd2/

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
        monolingual_size=(0 $(jq -r '.forward_model.data.monolingual_size[]' < $GCONF))
        CAPACITY=$(jq -r '.forward_model.batch_capacity' < $GCONF)
        BEAM_SIZE=$(jq -r '.forward_model.beam_size' < $GCONF)
        PARA_TRAIN_BNAME=$(jq -r '.iwslt17.file_name_prefix.train' < $GCONF)
        PARA_DEV_BNAME=$(jq -r '.iwslt17.file_name_prefix.dev' < $GCONF)
        VOCAB_FILE=$(jq -r '.spm.model_prefix' < $GCONF).vocab
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
                cat $GSCRIPTS/transformer/templates/model_config.json \
                    | jq ".basedir = \"$(pwd)\"" \
                    | jq ".train.batch.capacity = $CAPACITY" \
                    | jq ".train.data.source_train = [\"./data/concat/parallel/${PARA_TRAIN_BNAME}.src$src_suffix\", \"$mono_source\"]" \
                    | jq ".train.data.target_train = [\"./data/concat/parallel/${PARA_TRAIN_BNAME}.trg$trg_suffix\", \"$mono_target\"]" \
                    | jq ".train.data.source_dev = \"./data/concat/parallel/${PARA_DEV_BNAME}.src$src_suffix\"" \
                    | jq ".train.data.target_dev = \"./data/concat/parallel/${PARA_DEV_BNAME}.trg$trg_suffix\"" \
                    | jq ".source_suffix = \".src${src_suffix}\"" \
                    | jq ".target_suffix = \".trg\"" \
                    | jq ".beam_size = $BEAM_SIZE" \
                    | jq ".vocab.source_dict = \"$VOCAB_FILE\"" \
                    | jq ".vocab.target_dict = \"$VOCAB_FILE\"" \
                    > ${prefix}model_config.json

                cp $GSCRIPTS/project/templates/model_config.py ${prefix}model_config.py
            else
                echo "Ignoring ${prefix}. model_config already exists." >&2
            fi
        done
    done
fi

if [ -n "${flags[23]}" ]; then
    echo "Training of the forward models.

You have to mannually run commands to train the forward models.
(This is for you to optimally schedule training using multiple GPUs)

Forward models can be identified by two factors:
Context: 1-to-1, 2-to-1 and 2-to-2
#Pseudo sents pairs: 0, 500k, 1000k, ...

And the directories, ./forward/{1-to-1,2-to-1,2-to-2}/{0,500,...} corresponds to the models.

To train a model, for example 2-to-1 with 500k pseudo sent pairs using GPU No.0 and No.1, run the following command
\`CUDA_VISIBLE_DEVICES=0,1 python $CMTBT_GROOT/scripts/transformer/train.py -d ./forward/2-to-1/500 --n_gpus 2\`

To evaluate the model, run the following command
\`CUDA_VISIBLE_DEVICES=0 python $CMTBT_GROOT/scripts/project/test/BLEU_evaluation_for_model.sh ./forward/2-to-1/500\`
Results are stored in ./forward/2-to-1/500/log/eval/

This shellScript is terminated here" >&2
    exit 0
fi

