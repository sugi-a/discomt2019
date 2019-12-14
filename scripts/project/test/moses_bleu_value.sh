#!/bin/sh

SAMPLE='BLEU = 6.16, 43.6/13.8/5.3/2.1 (BP=0.675, ratio=0.718, hyp_len=27198, ref_len=37877)'

/home/sugi/ubuntu16/mosesdecoder/scripts/generic/multi-bleu.perl "$@" | sed -r 's/^.*BLEU\s=\s([^,]+),.*$/\1/'
