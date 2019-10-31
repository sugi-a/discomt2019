import sys, os, codecs, json, argparse, subprocess

ROOT = os.getenv('CMTBT_ROOT') ; assert ROOT; ROOT += '/'

with codecs.open(ROOT + 'global_config.json') as f:
    config = json.load(f)

parser = argparse.ArgumentParser()
parser.add_argument('--model_dir', type=str, required=True)
parser.add_argument('--n_gpus', type=int, default=1)
parser.add_argument('--gpu_capacity', type=int, default=64*128)
parser.add_argument('--target_context', action='store_true', default=False)
args = parser.parse_args()

with codecs.open(args.model_dir + '/test.conf') as f:
    test_conf = {words[0]: words[1:] for words in [line.split() for line in f]}

for test_case in config['iwslt17']['file_name_prefix']['test']:
    src_fname = ROOT + 'data/concat/parallel/' + test_case + test_conf['source_suffix'][0]
    trg_fname = ROOT + 'data/concat/parallel/' + test_case + test_conf['target_suffix'][0]

    logdir = args.model_dir + '/log/eval'; os.makedirs(logdir, exist_ok=True)
    src, out, ref, score = ('{}/{}.{}'.format(logdir, test_case, w)
        for w in ('src', 'out', 'ref', 'score'))

    # translate source
    subprocess.run(r'''
# model output (translate + spm_decode)
python {translator} --model_dir={model_dir} --beam_size={beam_size} --n_gpus={n_gpus} --batch_capacity={batch_capacity}\
    < {source} | spm_decode --model={sp_model_file} > {out} || exit 1

# source (just spm decode)
spm_decode --model={sp_model_file} < {source} > {src}

# reference (target)
spm_decode --model={sp_model_file} < {target} > {ref}

# BLEU
/home/sugi/nlp/corpora_processor/common/metrics/moses_bleu_value.sh {ref} \
    < {out} > {score}

        '''.format(
        model_dir=args.model_dir,
        beam_size=int(test_conf['beam_size'][0]),
        source=src_fname,
        target=trg_fname,
        sp_model_file=ROOT + config["spm"]["model_file"],
        src=src,
        out=out,
        ref=ref,
        score=score,
        n_gpus=args.n_gpus,
        batch_capacity=args.n_gpus * args.gpu_capacity,
        translator=ROOT + ('scripts/transformer/inference.py' if not args.target_context
            else 'scripts/context_aware_translation.py')
        ), shell=True)


