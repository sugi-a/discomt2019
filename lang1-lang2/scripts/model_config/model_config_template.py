import os, subprocess, codecs, json
from logging import getLogger, DEBUG, basicConfig; logger = getLogger(__name__)

ROOTP = os.getenv('CMTBT_ROOT'); assert ROOTP; ROOTP = ROOTP + '/'
with codecs.open(ROOTP + 'global_config.json') as f: config = json.load(f)

with codecs.open(os.path.dirname(__file__) + '/train_data.conf') as f:
    td_conf = {v[0]: v[1:] for v in (line.split() for line in f) if len(v) > 0}

"""
capacity 16384
source_train ...
target_train ...
source_dev ...
target_dev ...
"""

params = {
    "train": {
        "batch": {
            "fixed_capacity": True,
            "size": 128,
            "capacity": int(td_conf['capacity'][0]),
            "sort": True
        },
        "warm_up_step": 4000,
        "stop": {
            "limit":{
                "type": "step", # "step" or "epoch"
                "n": 300000
            },
            "early_stopping":{
                "type": "step", # "step" or "epoch"
                "n": 40000,
                "test_period": 4000
            }
        },
        "data": {
            "source_train": [ROOTP + p for p in td_conf['source_train']],
            "target_train": [ROOTP + p for p in td_conf['target_train']],
            "source_dev": ROOTP + td_conf['source_dev'][0],
            "target_dev": ROOTP + td_conf['target_dev'][0]
        },
    },
    "test": {
        "length_penalty_a": 1.0
    },
    "network": {
        "n_blocks": 6,
        "n_heads": 8,
        "attention_size": 512,
        "embed_size": 512,
        "dropout_rate": 0.1,
        "vocab_size": 16000,
        "share_embedding": True,
        "positional_embedding": False
    },
    "vocab": {
        "PAD_ID": config['spm']['PAD_ID'],
        "SOS_ID": config['spm']['SOS_ID'],
        "EOS_ID": config['spm']['EOS_ID'],
        "UNK_ID": config['spm']['UNK_ID'],
        "source_dict": ROOTP + config['spm']['model_prefix'] + '.vocab',
        "target_dict": ROOTP + config['spm']['model_prefix'] + '.vocab'
    }
    
}


import sentencepiece as spm
sp = spm.SentencePieceProcessor()
sp.Load(ROOTP + config['spm']['model_file'])
def IDs2tokens(IDs):
    '''IDs: list of list of int'''
    return [' '.join(sp.id_to_piece(id) for id in sent if not sp.is_control(id)) for sent in IDs]

# load dev file
with codecs.open(params["train"]["data"]["source_dev"]) as f:
    __src_lines = [line.strip() for line in f]
with codecs.open(params["train"]["data"]["target_dev"]) as f:
    __trg_lines = [line.strip() for line in f]

    # decode, split, wrap
    refs = [sp.decode_pieces(line.split()) for line in __trg_lines]
    refs = [line.split() for line in refs]
    refs = [[ref] for ref in refs]


from nltk.translate.bleu_score import corpus_bleu

def validation_metric(global_step, inference):
    # translate, decode, split
    outs = inference.translate_sentences(__src_lines, 1)
    outs = [sp.decode_pieces(line.split()) for line in outs]
    outs = [line.split() for line in outs]

    return corpus_bleu(refs, outs)



