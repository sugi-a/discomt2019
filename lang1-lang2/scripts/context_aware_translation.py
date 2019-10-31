import sys, os, codecs, time, argparse, json
from logging import getLogger, INFO, basicConfig; logger = getLogger(__name__); basicConfig(level=INFO)
import tensorflow as tf

ROOTP = os.getenv('CMTBT_ROOT'); assert len(ROOTP) > 0; ROOTP = ROOTP + '/'

sys.path.append(ROOTP + 'scripts/transformer')
from inference import Inference

def translate_with_oracle_context(Config, sources, targets, inference, CONCAT, beam_size, session=None):
    """
    Args:
        sources: list of str. source sentences. must be in subword format.
        targets: target sentences. each sentence consists of a context sentence and a sentence
            concat with <concat>
        inference: Inference object
        session: session to be used to compute graphs
    Returns:
        translations ([#samples: str])
        """

    # extract oracle contexts from the targets
    contexts = [line.split(CONCAT)[0] + CONCAT for line in targets]

    # translate
    translations = inference.translate_sentences(sources, beam_size, session=session, init_y_texts=contexts)
    # get the target part which is after the first appearence of <concat>
    translations = [''.join(line.split(CONCAT)[1:]) for line in translations]

    return translations

def translate_with_context(sources, inference, CONCAT, beam_size, session=None):
    """cf. BLEU_with_oracle_context
    Args:
        sources: list of str. source sentences. must be in subword format.
        targets: target sentences. each sentence consists of a context sentence and a sentence
            concat with <concat>
        inference: Inference object
        session: session to be used to compute graphs
    Returns:
        translations. ([#samples: str])
        """

    ctx_snt = [line.split(CONCAT) for line in sources]
    contexts, sentences = zip(*[(ctx.strip(), snt.strip()) for ctx,snt in ctx_snt])
    toks_contexts = [ctx.split() for ctx in contexts]
    toks_sentences = [snt.split() for snt in sentences]

    paragraphs = []
    paragraph = None
    for i, source in enumerate(sources):
        #if i == 0 or sentences[i - 1] != contexts[i]:
        _l = len(toks_contexts[i])
        if i == 0 or toks_contexts[i] != (toks_contexts[i - 1] + toks_sentences[i - 1])[-_l:]:
            paragraph = []
            paragraphs.append(paragraph)
        paragraph.append(source)

    max_paragraph_len = max(map(len, paragraphs));
    sys.stderr.write('aiueo \n')
    logger.info('#paragraphs: {}'.format(len(paragraphs)))
    sys.stderr.write('aiueo \n')

    pos_groups = [
        list(zip(*[(ind, paragraph[i])
            for ind,paragraph in enumerate(paragraphs) if len(paragraph) > i]))
        for i in range(max_paragraph_len)]

    translations = [[] for i in range(len(paragraphs))]

    # Translation start
    start_time = time.time()
    for i, (indices, group) in enumerate(pos_groups):
        if i == 0:
            contexts = [CONCAT] * len(group)
        else:
            contexts = ['{} {}'.format(translations[ind][i - 1], CONCAT) for ind in indices]
        outputs = inference.translate_sentences(group, beam_size, init_y_texts=contexts)
        outputs = [output.split(CONCAT)[-1].strip() for output in outputs]
        for output,ind in zip(outputs, indices):
            translations[ind].append(output)
        logger.info('Translation {}/{}. {} sec/step'.format(i, len(pos_groups),
            (time.time() - start_time) / (i+1)))

    translations = sum(translations, [])
    assert len(translations) == len(sources)

    logger.info('Translated {} sentences, {} of which were translated without context.'.format(
        len(sources), len(paragraphs)))
    return translations


def main():
    # arguments
    parser = argparse.ArgumentParser()
    parser.add_argument('--model_dir', type=str, required=True)
    parser.add_argument('--n_gpus', type=int, default=1)
    parser.add_argument('--checkpoint', type=str, default=None)
    parser.add_argument('--batch_capacity', type=int, default=None)
    parser.add_argument('--beam_size', type=int, default=1)
    args = parser.parse_args()
    
    sys.path.insert(0, args.model_dir)
    import model_config
    params = model_config.params
    
    # checkpoint
    checkpoint = args.checkpoint or tf.train.latest_checkpoint(args.model_dir + '/log/sup_checkpoint')
    assert checkpoint is not None; logger.debug('checkpoint', checkpoint)

    # batch_capacity (specified or decided according to n_gpus)
    batch_capacity = args.batch_capacity or 64*128*args.n_gpus

    inference = Inference(
        model_config, checkpoint=checkpoint, n_gpus=args.n_gpus,
        batch_capacity=args.batch_capacity)
    inference.make_session()

    sources = sys.stdin.readlines()

    # CONC symbol
    with codecs.open(ROOTP + '/global_config.json') as f:
        gconf = json.load(f)
        CONC = gconf["spm"]["CONC"]


    translations = translate_with_context(sources, inference, CONC, args.beam_size)
    for line in translations:
        print(line)

if __name__ == '__main__':
    main()
else:
    assert False

