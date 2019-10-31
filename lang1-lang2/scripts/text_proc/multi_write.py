# python ./this.py file_names
import sys, argparse

parser = argparse.ArgumentParser()
parser.add_argument('fnames', nargs='*', type=str)
parser.add_argument('--prefix', type=str, default='')
args = parser.parse_args()

fnames = args.fnames
prefix = args.prefix

nfiles = int(sys.stdin.readline())
assert nfiles == len(fnames)

fs = [open(prefix + fn, 'w') for fn in fnames]

while True:
    for i in range(nfiles):
        l = sys.stdin.readline()
        if len(l) == 0:
            assert i == 0
            break
        fs[i].write(l)
    if i == 0:
        break
