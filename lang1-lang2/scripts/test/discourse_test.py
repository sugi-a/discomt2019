import sys, os, codecs, json, argparse, subprocess
import tensorflow as tf

from calc_trans_score import Calculator, prepro_src, prepro_trg

ROOTP = os.getenv('CMTBT_ROOT'); assert len(ROOTP) > 0; ROOTP = ROOTP + '/'
# CONC symbol
with codecs.open(ROOTP + '/global_config.json') as f:
    gconf = json.load(f)
    CONC = gconf["spm"]["CONC"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('testdata', type=str)
    parser.add_argument('--model_dir', type=str, required=True)
    parser.add_argument('--n_gpus', type=int, default=1)
    parser.add_argument('--target_context', action='store_true', default=False)
    args = parser.parse_args()

    calculator = Calculator(args.model_dir, args.n_gpus)

    datapath = args.testdata
    test_name = os.path.splitext(os.path.basename(datapath))[0]

    with codecs.open(datapath) as f:
        tests = [line.strip() for line in f]

        src_ctxs = prepro_src(tests[1::6])
        srcs     = prepro_src(tests[2::6])
        trg_ctxs = prepro_trg(tests[3::6])
        answers1 = prepro_trg(tests[4::6])
        answers2 = prepro_trg(tests[5::6])

    if args.target_context:
        srcs = ['{} {} {}'.format(a, CONC, b) for a, b in zip(src_ctxs, srcs)]
        trgs1 = ['{} {} {}'.format(a, CONC, b) for a, b in zip(trg_ctxs, answers1)]
        trgs2 = ['{} {} {}'.format(a, CONC, b) for a, b in zip(trg_ctxs, answers2)]
    else:
        srcs = ['{} {} {}'.format(a, CONC, b) for a, b in zip(src_ctxs, srcs)]
        trgs1 = answers1
        trgs2 = answers2

    res1 = calculator.compute_tokenized(srcs, trgs1)
    res2 = calculator.compute_tokenized(srcs, trgs2)

    score = [a >= b for a, b in zip(res1, res2)].count(True) / len(res1)
    print(score)

    logdir = args.model_dir + '/log/eval/discourse'; os.makedirs(logdir, exist_ok=True)
    with open('{}/{}_acc'.format(logdir, test_name), 'w') as f:
        f.write(str(score) + '\n')

    with open('{}/{}_scores'.format(logdir, test_name), 'w') as f:
        f.writelines(['{}\t{}\t{}\n'.format(a>=b, a, b) for a,b in zip(res1, res2)])

    with open('{}/{}_texts'.format(logdir, test_name), 'w') as f:
        f.writelines(['{}\n{}\n{}\n{}\n'.format(i,a,b,c)
            for i, (a,b,c) in enumerate(zip(srcs, trgs1, trgs2))])




if __name__ == '__main__':
    main()
