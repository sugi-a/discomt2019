import os, sys, csv

os.chdir(os.path.dirname(os.path.abspath(__file__)))

with open('testset.csv') as f:
    reader = csv.reader(f)

    with open('testset.txt', 'w') as df:
        for i, (src, t1, cs1, ct1, t2, cs2, ct2) in enumerate(reader):
            if i == 0:
                continue
            df.write('{}\n{}\n{}\n{}\n{}\n{}\n'.format(i*2 - 1,  cs1, src, ct1, t1, t2))
            df.write('{}\n{}\n{}\n{}\n{}\n{}\n'.format(i*2,      cs2, src, ct2, t2, t1))
