# Extract sentences to be used in this project, from the data file produced by https://github.com/soskek/bookcorpus
# Usage
# python ./make_dataset.py < all.txt > outfile
import sys, codecs, subprocess, os, json
from collections import deque

MIN_SENTS = 30
MIN_LEN = 1
MAX_LEN = 128

nblocks = 0
nsents = 0

stack = None

for i, line in enumerate(sys.stdin):
    if i % 1000000 == 0:
        sys.stderr.write('{}\t\t\r'.format(i))

    if len(line.strip()) == 0:
        if stack and len(stack) >= MIN_SENTS:
            sys.stdout.writelines(stack)
            print('')
            nblocks += 1
            nsents += len(stack)
        stack = None
    else:
        nwords = len(line.split())
        if (MIN_LEN <= nwords <= MAX_LEN) and len(line) <= nwords * 7.5:
            if not stack:
                stack = deque()
            stack.append(line)
        else:
            stack = None


sys.stderr.write('\n{}, {}, {}\n'.format(nblocks, nsents, nblocks/nsents))
