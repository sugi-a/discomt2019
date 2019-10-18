#!/bin/bash

#python -c "import json; q='''$1'''; c=json.load(open('global_config.json')); print(eval('c'+q))"
cd $(dirname $0)
python -c \
"import json
q = '''$1'''
c = json.load(open('global_config.json'))
a = eval('c'+q)
if type(a) == list:
    print(' '.join(str(w) for w in a))
else:
    print(a)"
