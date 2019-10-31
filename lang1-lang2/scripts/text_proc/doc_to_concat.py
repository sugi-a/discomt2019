# make a concatenated-style corpus from a document-style (sentence per line + blank line as a document boundary)
import sys, argparse
from collections import deque

parser = argparse.ArgumentParser()
parser.add_argument('nconc', type=int)
parser.add_argument('conc', nargs='?', default=None)
args = parser.parse_args()

nconc = args.nconc

if nconc == 0:
    for line in sys.stdin:
        line = line.strip()
        if len(line) > 0: print(line)
else:
    CONC = args.conc ; assert CONC

    q = deque(('',) * (nconc - 1))
    for line in sys.stdin:
        line = line.strip()
        if len(line) == 0:
            # reset queue
            q = deque(('',) * (nconc - 1))
        else:
            print('{} {} {}'.format(' '.join(q), CONC, line))

            q.append(line)
            q.popleft()
