# This script extracts raw sentences from the IWSLT2017 dataset
# documents are separated by a blank line
# usage:
# ./this.py (train|dev|test)
# stdin: xml (incomplete xml for train) data
# stdout: extracted data

import sys, os, codecs, re, argparse
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser()
parser.add_argument('mode', type=str, choices=['train', 'dev', 'test'])
args = parser.parse_args()

if args.mode == 'train':
    data = sys.stdin.read()
    data = re.sub('</description>', '</description><content>', data)
    data = re.sub('<reviewer', '</content><reviewer', data)
    data = '<whole>' + data + '</whole>'
    root = ET.fromstring(data)
    texts = [content.text for content in root.iterfind('.//content')]
    for text in texts:
        for line in text.split('\n'):
            line = line.strip()
            if len(line) > 0:
                print(line)
        print('')

elif args.mode == 'dev' or args.mode == 'test':
    data = sys.stdin.read()
    root = ET.fromstring(data)
    for doc in root.iterfind('.//doc'):
        for seg in doc.iterfind('./seg'):
            line = seg.text.strip()
            if len(line) > 0:
                print(line)
        print('')
else:
    assert False
