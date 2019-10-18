import sys, os, subprocess, re, argparse
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('source', type=str)
parser.add_argument('target', type=str)
args = parser.parse_args()

src = args.source
dst = args.target

if os.path.exists(dst):
    sys.stderr.write('log exists\n')
    exit(1)

os.makedirs(dst)

# eval, summary
for d in ('eval', 'summary'):
    subprocess.run(['cp', '-r', src + '/' + d, dst])

# checkpoints
for d in ('checkpoint', 'sup_checkpoint'):
    p = Path(src + '/' + d)
    _dst = dst + '/' + d
    os.makedirs(_dst)

    # checkpoint
    subprocess.run(['cp', str(p) + '/checkpoint', _dst])

    # model files
    cps = list(p.glob('model-*.index'))
    steps = [int(re.search(r'model-(\d+)', str(cp)).group(1)) for cp in cps]
    print(steps)
    step = max(steps)

    # validation
    with open(str(p) + '/checkpoint') as f:
        lines = f.read()
        _step = re.match(r'^model_checkpoint_path: ".*?model-(\d+)"', lines).groups()[0]
        print(_step)
        assert step == int(_step)

    subprocess.run('cp -r {}/model-{}.* {}'.format(str(p), step, _dst), shell=True)


print('done')
        

