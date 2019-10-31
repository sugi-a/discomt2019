import sys
import numpy as np

lines = sys.stdin.readlines()
nfiles = int(lines[0])

assert (len(lines) - 1) % nfiles == 0

# reshape -> [l/f, nfiles]
lines = [lines[i: i+nfiles] for i in range(1, len(lines), nfiles)]

# shuffle
np.random.shuffle(lines)

# output
print(nfiles)
for ls in lines:
    sys.stdout.writelines(ls)

# info
sys.stderr.write('Shuffle done\n')
