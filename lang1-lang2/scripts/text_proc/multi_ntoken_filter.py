import sys, os, argparse, codecs
from collections import deque

parser = argparse.ArgumentParser()
parser.add_argument('--maxlens', type=int, nargs='+', required=True)
parser.add_argument('--minlens', type=int, nargs='+', default=None)
args = parser.parse_args()

nfiles = int(sys.stdin.readline())
maxlens = args.maxlens
minlens = args.minlens or [0]*len(maxlens) # minlens defaults 0
assert nfiles == len(maxlens) == len(minlens)

print(nfiles)

nlines, left = 0, 0
a = [None] * nfiles
while True:
    for i in range(nfiles):
        a[i] = sys.stdin.readline()
        if len(a[i]) == 0:
            assert i == 0
            break
    if i == 0:
        break
    nlines += 1
    if all(minlens[i] <= len(a[i].split()) <= maxlens[i] for i in range(nfiles)):
        sys.stdout.writelines(a)
        left += 1

# info
sys.stderr.write('Before: {}, After: {}\n'.format(nlines, left))

