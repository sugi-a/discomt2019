import sys, os, re

import sys, os, codecs, json, argparse, subprocess
import tensorflow as tf

ROOTP = os.getenv('CMTBT_ROOT'); assert len(ROOTP) > 0; ROOTP = ROOTP + '/'

sys.path.append(ROOTP + 'scripts/transformer')
from inference import Inference

def prepro(_texts, lang):
    sys.stderr.write(str(_texts) + '\n')
    assert lang == 'source' or lang == 'target'
    texts = ''.join([text.strip() + '\n' for text in _texts])
    proc = subprocess.run(
        ROOTP + 'scripts/preprocess.sh ' + ('source' if lang=='source' else 'target'),
        shell=True, input=texts.encode(), stdout=subprocess.PIPE)
    ret = proc.stdout.decode('utf8').strip().split('\n')
    sys.stderr.write(str(ret) + '\n\n')
    assert len(ret) == len(_texts)
    return ret

def prepro_src(texts):
    return prepro(texts, 'source')

def prepro_trg(texts):
    return prepro(texts, 'target')

class Calculator:
    def __init__(self, model_dir, n_gpus=1, checkpoint=None):
        sys.path.insert(0, model_dir)
        import model_config
        params = model_config.params

        # checkpoint
        checkpoint = checkpoint or tf.train.latest_checkpoint(model_dir + '/log/sup_checkpoint')
        assert checkpoint

        inference = Inference(model_config, n_gpus=n_gpus, checkpoint=checkpoint)
        inference.make_session()

        # CONC symbol
        with codecs.open(ROOTP + '/global_config.json') as f:
            gconf = json.load(f)
            CONC = gconf["spm"]["CONC"]

        
        self.inference = inference

    def compute(self, sources, targets):
        if type(sources) == str:
            sources = [sources]
        if type(targets) == str:
            targets = [targets]

        sources = prepro_src(sources) ; targets = prepro_trg(targets)

        return self.compute_tokenized(sources, targets), sources, targets

    def compute_tokenized(self, sources, targets):
        if type(sources) == str:
            sources = [sources]
        if type(targets) == str:
            targets = [targets]

        if len(sources) == 1:
            sources = sources * len(targets)
        elif len(targets) == 1:
            targets = targets * len(sources)

        results = self.inference.calculate_perplexity(sources, targets, trans_score=True)
        
        return results
