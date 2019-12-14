import os, json
"""
Configuration for a model.

This file is loaded by python3
`exec(this_file_content, None, {'model_dir': dirname_of_this_file})`

This file must contain:
    params : a dict storing configuration of Transformer and training.
This file can contain:
    IDs2text: method to convert token IDs in the target language into sentences.
        Args:
            IDs: list of list of int
        Returns:
            List of str. Just replace indivisual IDs by tokens. (Do not spm_decode)
    validation_metric: validation method
"""


# -------- `params` --------
# By default, automatically built from `model_config.json`

with open(model_dir + '/' + 'model_config.json') as f:
    params = json.load(f)

# Add prefix to the dataset paths. Absolute prefix is recommended.
if 'basedir' in params: 
    _p = params["basedir"] + '/'
    for k in ["source_train", "target_train"]:
        for i in range(len(params["train"]["data"][k])):
            params["train"]["data"][k][i] = _p + params["train"]["data"][k][i]
    params["train"]["data"]["source_dev"] = _p + params["train"]["data"]["source_dev"]
    params["train"]["data"]["target_dev"] = _p + params["train"]["data"]["target_dev"]
    params["vocab"]["source_dict"] = _p + params["vocab"]["source_dict"]
    params["vocab"]["target_dict"] = _p + params["vocab"]["target_dict"]


# -------- methods --------
# Following two functions can be customly defined
"""
IDs2text(IDs)
validation_metric(global_step, inference)
"""

# Here is an example of the two methods

"""
import sentencepiece as spm
sp = spm.SentencePieceProcessor()
sp.Load(params["vocab"]["source_dict"][:-len("vocab")] + "model")

def IDs2text(IDs):
    '''
    IDs: list of list of int
    Returns: list of sentence'''
    return [' '.join(sp.id_to_piece(id) for id in sent if not sp.is_control(id)) for sent in IDs]


with open(params["train"]["data"]["source_dev"]) as f:
    __src_lines = [line.strip() for line in f]
with open(params["train"]["data"]["target_dev"]) as f:
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

"""
