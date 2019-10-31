import sys, os, codecs, json, argparse, subprocess

ANAPHORA_TEST_SET = './discourse-mt-test-sets/test-sets/anaphora.json'
LEXICAL_TEST_SET =  './discourse-mt-test-sets/test-sets/lexical-choice.json'

def main():
# test sets
    with codecs.open(ANAPHORA_TEST_SET) as f:
        anaphora_tests = json.load(f)
    with codecs.open(LEXICAL_TEST_SET) as f:
        lexical_tests = json.load(f)

    # anaphora test
    q_corr_s, q_corr_t, q_semc_s, q_semc_t = [], [], [], []

    corr_out = []
    semi_out = []
    for i in range(50):
        test = anaphora_tests[str(i + 1)]
        srcs = test['src']
        trgs = test['trg']

        assert trgs[0]['correct'][0] == trgs[0]['incorrect'][0]
        corr_out.append(srcs + trgs[0]['correct'] + trgs[0]['incorrect'][1:])
        corr_out.append(srcs + trgs[1]['correct'] + trgs[1]['incorrect'][1:])

        semi_out.append(srcs + trgs[2]['semi-correct'] + trgs[2]['incorrect'][1:])
        semi_out.append(srcs + trgs[3]['semi-correct'] + trgs[3]['incorrect'][1:])

    # lex test
    lex_out = []
    for i in range(100):
        tests = lexical_tests[str(i + 1)]['examples']
        for t in tests:
            assert t['trg']['correct'][0] == t['trg']['incorrect'][0]
            lex_out.append(t['src'] + t['trg']['correct'] + t['trg']['incorrect'][1:])

    # error check
    for qs in (corr_out , semi_out , lex_out):
        error = []
        for t1, t2 in zip(qs[0::2], qs[1::2]):
            assert t1[1] == t2[1]
            if t1[3] == t2[3] and t1[4] == t2[4]:
                error.append(t1[1])
        print(error)
        print(len(error))

    # output
    os.makedirs('extracted', exist_ok=True)
    for fname, questions in (('anaphora_corr.txt', corr_out), ('anaphora_semi.txt', semi_out),
        ('lexical-choice.txt', lex_out)):
        with open('extracted/' + fname, 'w') as f:
            for i, out in enumerate(questions):
                f.write('{}\n{}\n'.format(i, '\n'.join(out)))


if __name__ == '__main__':
    main()
