#!/bin/bash

cd ${CMTBT_ROOT:?'not found'}

PRE_SP_PP=./lang/preprocess.sh
SPM=$(./get_gc.sh '["spm"]["model_file"]')

if [ "$1" == "source" ]; then
    $PRE_SP_PP source | spm_encode --model $SPM || exit 1
elif [ "$1" == "target" ]; then
    $PRE_SP_PP target | spm_encode --model $SPM || exit 1
fi
