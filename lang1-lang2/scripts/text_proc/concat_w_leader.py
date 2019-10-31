import sys, argparse
from collections import deque

parser = argparse.ArgumentParser()
parser.add_argument('lead', type=str)
parser.add_argument('nconc', type=int, choices=[1,2])
parser.add_argument('conc', type=str)
args = parser.parse_args()

if args.nconc == 1:
    for l in sys.stdin:
        sys.stdout.write(args.conc + ' ' + l)
else:
    ndocs = 0
    with open(args.lead) as lead:
        prev = ''
        for l in sys.stdin:
            lead_l = lead.readline()
            assert len(lead_l) > 0

            if len(lead_l.split(args.conc)[0].strip()) == 0:
                sys.stdout.write(args.conc + ' ' + l)
                ndocs += 1
            else:
                sys.stdout.write('{} {} {}'.format(prev.strip(), args.conc, l))
            prev = l
    sys.stderr.write('Number of documents: {}\n'.format(ndocs))
